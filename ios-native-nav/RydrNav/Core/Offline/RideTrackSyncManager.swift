import CoreLocation
import Foundation

/// Un punto GPS pendiente de mandar al backend — mismos campos que
/// `RideRepository.addTrackPoint`, pero guardable en disco. `Codable` con
/// `.secondsSince1970` para la fecha: esto es un formato puramente
/// interno (lo escribe y lee siempre la propia app), no tiene que
/// coincidir con lo que espera el backend — esa conversión vive en
/// `RideTrackSyncManager.requestBody(for:)`.
struct PendingTrackPoint: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let speed: Double?
    let timestamp: Date
    /// Primer punto de un tramo nuevo tras una pausa — ver
    /// `RegisterViewController.trackSegments`. Se manda al backend para
    /// que el trazado publicado no conecte el hueco con una línea recta.
    let isSegmentStart: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Cola local duradera de puntos GPS grabados que no se han podido mandar
/// al backend todavía — el caso de uso central de la app (carretera de
/// montaña) es precisamente quedarte sin cobertura a mitad de una ruta.
/// Antes, cada punto se mandaba con un `try?` que se tragaba el error en
/// silencio: sin cobertura, el punto se perdía para siempre, sin aviso ni
/// reintento. El trazado que ves mientras grabas
/// (`RegisterViewController.trackCoordinates`, en memoria) seguía bien,
/// pero el que queda guardado en el backend — y por tanto la ruta que se
/// publica al terminar — podía salir con huecos.
///
/// Cada punto se encola aquí primero (memoria + un espejo en disco, por
/// si la app se cierra a medias) y de ahí se intenta mandar — nunca al
/// revés, `enqueue` nunca toca la red. Sin monitor de conectividad
/// (`NWPathMonitor`): un reintento periódico (ver dónde se llama a
/// `attemptDrain`/`resumeAllPending` desde `RegisterViewController`) es
/// de sobra para este caso de uso — que no se pierda el dato importa; que
/// se mande al segundo exacto de recuperar cobertura no.
@MainActor
final class RideTrackSyncManager {
    static let shared = RideTrackSyncManager()

    private let repository = RideRepository()
    /// rideId → puntos sin mandar, en el orden en que se grabaron.
    private var queues: [Int: [PendingTrackPoint]] = [:]
    /// Evita solapar dos intentos de envío del mismo ride (el timer de
    /// 15s y "la app ha vuelto a primer plano" pueden coincidir).
    private var draining: Set<Int> = []

    private let fileEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()
    private let fileDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    // Mismo formato que ya usa `RideRepository` para el timestamp al
    // mandarlo al backend — repetido aquí porque ese formateador es
    // privado a esa struct, mismo patrón que ya sigue cada repositorio de
    // la app (cada uno con el suyo, no uno compartido).
    private let requestTimestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return f
    }()

    private init() {}

    // MARK: - Carpeta de la cola en disco

    // `Application Support`, no `Caches` — el sistema puede purgar
    // `Caches` bajo presión de espacio, y esto es dato real de una ruta
    // grabada, no una caché reconstruible.
    private lazy var outboxDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("PendingTrackPoints", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private func fileURL(forRide rideId: Int) -> URL {
        outboxDirectory.appendingPathComponent("ride_\(rideId).jsonl")
    }

    // MARK: - Encolar

    /// Nunca falla, nunca espera a la red — el punto queda a salvo (en
    /// memoria y en disco) en cuanto vuelve esta llamada.
    func enqueue(rideId: Int, point: PendingTrackPoint) {
        queues[rideId, default: []].append(point)
        appendToDisk(point, rideId: rideId)
    }

    private func appendToDisk(_ point: PendingTrackPoint, rideId: Int) {
        guard let line = try? fileEncoder.encode(point) else { return }
        let url = fileURL(forRide: rideId)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        handle.seekToEndOfFile()
        handle.write(line)
        handle.write("\n".data(using: .utf8)!)
    }

    /// Puntos que sigan sin mandar para un ride — `RegisterViewController`
    /// los suma al reconstruir un trazado reanudado (si no, tanto el
    /// trazado como las cifras se verían con un hueco al final aunque
    /// esos puntos estén a salvo localmente, solo que todavía no le han
    /// llegado al backend).
    func pendingPoints(forRide rideId: Int) -> [PendingTrackPoint] {
        queues[rideId] ?? []
    }

    // MARK: - Vaciar la cola

    // Por si acaso tras una desconexión muy larga hay miles de puntos en
    // cola — a este volumen no debería hacer falta, pero mejor no mandar
    // un único cuerpo de petición sin límite.
    private static let maxPointsPerRequest = 500

    /// Intenta mandar lo que haya en cola para un ride. Si falla (sigue
    /// sin haber cobertura, o el backend no responde), la cola se queda
    /// tal cual para el siguiente intento — no se pierde nada.
    func attemptDrain(rideId: Int) {
        guard !draining.contains(rideId), let queued = queues[rideId], !queued.isEmpty else { return }
        draining.insert(rideId)
        let chunk = Array(queued.prefix(Self.maxPointsPerRequest))
        let bodies = chunk.map(requestBody)

        Task {
            defer { draining.remove(rideId) }
            do {
                try await repository.addTrackPointsBatch(rideId: rideId, points: bodies)
                // Solo se quitan los que de verdad se mandaron — si han
                // llegado puntos nuevos mientras tanto (se sigue grabando
                // en paralelo), se quedan en la cola para el siguiente
                // intento, no se pierden ni se duplican.
                let currentCount = queues[rideId]?.count ?? 0
                queues[rideId]?.removeFirst(min(chunk.count, currentCount))
                rewriteDisk(rideId: rideId)
            } catch {
                // Nada que hacer aquí: la cola en memoria y en disco no se
                // ha tocado, así que el próximo `attemptDrain` lo volverá
                // a intentar con lo mismo.
            }
        }
    }

    private func requestBody(for point: PendingTrackPoint) -> [String: Any] {
        var body: [String: Any] = [
            "latitude": point.latitude, "longitude": point.longitude,
            "timestamp": requestTimestampFormatter.string(from: point.timestamp),
            "is_segment_start": point.isSegmentStart,
        ]
        if let altitude = point.altitude { body["altitude"] = altitude }
        if let speed = point.speed { body["speed"] = speed }
        return body
    }

    /// Reescribe el archivo entero con lo que quede sin mandar — solo
    /// pasa al vaciar la cola con éxito (cada ~15s mientras se graba, o
    /// una vez al recuperar cobertura tras un tramo largo sin ella), no
    /// en cada punto nuevo (eso lo hace `appendToDisk`, mucho más barato).
    private func rewriteDisk(rideId: Int) {
        let remaining = queues[rideId] ?? []
        let url = fileURL(forRide: rideId)
        guard !remaining.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            queues.removeValue(forKey: rideId)
            return
        }
        var data = Data()
        for point in remaining {
            guard let line = try? fileEncoder.encode(point) else { continue }
            data.append(line)
            data.append("\n".data(using: .utf8)!)
        }
        try? data.write(to: url, options: .atomic)
    }

    /// Se borra la cola de un ride sin intentar mandarla — para una
    /// grabación descartada por tener muy pocos puntos.
    func discard(rideId: Int) {
        queues.removeValue(forKey: rideId)
        try? FileManager.default.removeItem(at: fileURL(forRide: rideId))
    }

    // MARK: - Recuperar lo pendiente de sesiones anteriores

    /// Recorre lo que haya en disco de CUALQUIER ride, no solo el activo
    /// — cubre "terminé una ruta sin cobertura, cerré la app, hoy sí hay
    /// señal". Mejor esfuerzo: si un intento falla, se queda ahí para la
    /// próxima llamada (arrancar la app otra vez, o volver a primer
    /// plano).
    func resumeAllPending() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: outboxDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files {
            guard let rideId = Self.rideId(fromFileName: file.lastPathComponent) else { continue }
            if queues[rideId] == nil {
                queues[rideId] = loadFromDisk(rideId: rideId)
            }
            attemptDrain(rideId: rideId)
        }
    }

    private func loadFromDisk(rideId: Int) -> [PendingTrackPoint] {
        guard let data = try? Data(contentsOf: fileURL(forRide: rideId)) else { return [] }
        return data.split(separator: UInt8(ascii: "\n"))
            .compactMap { try? fileDecoder.decode(PendingTrackPoint.self, from: Data($0)) }
    }

    private static func rideId(fromFileName name: String) -> Int? {
        guard name.hasPrefix("ride_"), name.hasSuffix(".jsonl") else { return nil }
        return Int(name.dropFirst("ride_".count).dropLast(".jsonl".count))
    }
}
