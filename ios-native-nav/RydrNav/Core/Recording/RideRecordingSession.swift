import CoreLocation
import Foundation

/// Estado y lógica puros de una grabación de ruta — tramos, pausa,
/// distancia/desnivel acumulados y el cronómetro real (sin el tiempo en
/// pausa). Sin UIKit: extraído de `RegisterViewController` para que la
/// aritmética de grabar/pausar/reanudar no viva mezclada con la
/// construcción de la UI, y de paso quede en una clase simple que se
/// puede probar con XCTest sin simulador — hoy la única forma de
/// verificar este comportamiento era grabando una ruta a mano.
final class RideRecordingSession {
    /// Cada tramo por separado (un tramo nuevo se abre en cada
    /// `resume()`) — así ni el trazado ni las cifras conectan el hueco de
    /// una pausa como si fuera carretera recorrida. Sin pausas, sigue
    /// habiendo un único tramo con todos los puntos, igual que siempre.
    private(set) var trackSegments: [[CLLocationCoordinate2D]] = [[]]
    private(set) var totalDistanceMeters: CLLocationDistance = 0
    private(set) var totalElevationGainMeters: Double = 0
    private var lastAltitude: Double?

    private(set) var isPaused = false
    private var pauseStartDate: Date?
    private var pausedDurationTotal: TimeInterval = 0

    private(set) var rideStartDate: Date?

    var pointCount: Int { trackSegments.reduce(0) { $0 + $1.count } }

    // MARK: - Empezar / pausar / reanudar

    func start(at date: Date = Date()) {
        trackSegments = [[]]
        totalDistanceMeters = 0
        totalElevationGainMeters = 0
        lastAltitude = nil
        isPaused = false
        pauseStartDate = nil
        pausedDurationTotal = 0
        rideStartDate = date
    }

    func pause(at date: Date = Date()) {
        guard !isPaused else { return }
        isPaused = true
        pauseStartDate = date
    }

    func resume(at date: Date = Date()) {
        guard isPaused else { return }
        if let pauseStartDate {
            pausedDurationTotal += date.timeIntervalSince(pauseStartDate)
        }
        self.pauseStartDate = nil
        isPaused = false
        // Abre un tramo nuevo — el siguiente punto grabado será el
        // primero de ese tramo, sin conectar con una línea recta (ni
        // sumar como distancia real) el hueco que deja la pausa.
        trackSegments.append([])
    }

    // MARK: - Grabar un punto

    struct RecordedPoint {
        let isSegmentStart: Bool
    }

    /// `nil` si está pausado — no se graba nada mientras tanto (el
    /// llamador tampoco debe encolar el punto para sincronizar en ese
    /// caso, ver `RegisterViewController.locationManager(didUpdateLocations:)`).
    @discardableResult
    func record(coordinate: CLLocationCoordinate2D, altitude: Double) -> RecordedPoint? {
        guard !isPaused else { return nil }

        // ¿Primer punto de un tramo nuevo? (el arranque de la ruta, o
        // justo tras un `resume()`). Si lo es, no hay un "punto anterior"
        // real dentro de este tramo con el que comparar — ni distancia ni
        // desnivel se calculan contra el último punto de ANTES de la
        // pausa, para no contar como recorrido el salto que deja el hueco.
        let isNewSegment = trackSegments[trackSegments.count - 1].isEmpty
        if !isNewSegment, let previous = trackSegments[trackSegments.count - 1].last {
            totalDistanceMeters += CLLocation(latitude: previous.latitude, longitude: previous.longitude)
                .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
        }
        if isNewSegment {
            lastAltitude = altitude
        } else if altitude != 0 || lastAltitude != nil {
            if let previousAltitude = lastAltitude {
                let delta = altitude - previousAltitude
                if delta > 1 { totalElevationGainMeters += delta }
            }
            lastAltitude = altitude
        }
        trackSegments[trackSegments.count - 1].append(coordinate)
        return RecordedPoint(isSegmentStart: isNewSegment)
    }

    // MARK: - Cronómetro

    /// Tiempo de grabación real transcurrido — el reloj de pared menos
    /// todo el rato que ha estado en pausa, incluida la pausa en curso si
    /// la hay ahora mismo (así el cronómetro se queda congelado en vivo
    /// mientras `isPaused`, no solo al mirar las cifras finales).
    func currentElapsed(at date: Date = Date()) -> TimeInterval {
        guard let rideStartDate else { return 0 }
        var elapsed = date.timeIntervalSince(rideStartDate) - pausedDurationTotal
        if isPaused, let pauseStartDate {
            elapsed -= date.timeIntervalSince(pauseStartDate)
        }
        return max(0, elapsed)
    }

    // MARK: - Reconstruir una grabación a medias

    /// Punto mínimo común entre `TrackPointModel` (lo que ya sabe el
    /// backend) y `PendingTrackPoint` (lo que sigue en cola local) — para
    /// poder recalcular cifras sobre los dos juntos al reanudar una
    /// grabación a medias.
    struct RestorePoint {
        let coordinate: CLLocationCoordinate2D
        let altitude: Double?
        let isSegmentStart: Bool
        let timestamp: Date
    }

    /// Reconstruye el estado a partir de un historial ya grabado (backend
    /// + cola local sin sincronizar) — usado al recuperar una grabación a
    /// medias tras cerrar la app. Siempre añade un tramo nuevo vacío al
    /// final: da igual si la app se cerró en pausa o sin más, hay un
    /// hueco real de tiempo (y posiblemente de distancia) entre el último
    /// punto grabado y ahora mismo que no debe conectarse con una línea
    /// recta ni sumarse como recorrido — mismo mecanismo que `resume()`.
    func restore(from points: [RestorePoint], rideStartDate: Date, now: Date = Date()) {
        let segments = Self.groupIntoSegments(points)
        trackSegments = segments.map { $0.map(\.coordinate) } + [[]]
        self.rideStartDate = rideStartDate
        isPaused = false
        pauseStartDate = nil
        (totalDistanceMeters, totalElevationGainMeters) = Self.recomputeStats(from: segments)
        lastAltitude = nil

        // El tiempo de pared no cubierto por ningún tramo grabado
        // (pausas reales + el rato que la app pudo haber estado cerrada)
        // se cuenta como "pausado" a efectos del cronómetro — mismo
        // criterio que usa el backend para la duración de la ruta
        // publicada (ver `RouteService.create_route_from_ride`).
        let activeSoFar = segments.reduce(0.0) { total, segment in
            guard let first = segment.first?.timestamp, let last = segment.last?.timestamp else { return total }
            return total + max(0, last.timeIntervalSince(first))
        }
        pausedDurationTotal = max(0, now.timeIntervalSince(rideStartDate) - activeSoFar)
    }

    /// Trocea una lista plana y ordenada en tramos — un corte nuevo cada
    /// vez que `isSegmentStart` es `true` (salvo el primer punto, que no
    /// cuenta como corte: ya es el arranque del primer tramo). Mismo
    /// criterio que `split_into_segments` en el backend (`app/shared/geo.py`).
    static func groupIntoSegments(_ points: [RestorePoint]) -> [[RestorePoint]] {
        var segments: [[RestorePoint]] = []
        for (index, point) in points.enumerated() {
            if index == 0 || point.isSegmentStart {
                segments.append([])
            }
            segments[segments.count - 1].append(point)
        }
        return segments
    }

    /// Mismas reglas que al ir sumando en vivo (`record(coordinate:altitude:)`),
    /// pero aplicadas de una vez sobre un historial ya grabado, tramo a
    /// tramo — nunca se suma distancia/desnivel entre el último punto de
    /// un tramo y el primero del siguiente (el hueco de una pausa).
    static func recomputeStats(from segments: [[RestorePoint]]) -> (distance: CLLocationDistance, elevationGain: Double) {
        var distance: CLLocationDistance = 0
        var elevationGain: Double = 0
        for segment in segments {
            var lastAltitude: Double?
            for (index, point) in segment.enumerated() {
                if index > 0 {
                    let previous = segment[index - 1]
                    distance += CLLocation(latitude: previous.coordinate.latitude, longitude: previous.coordinate.longitude)
                        .distance(from: CLLocation(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude))
                }
                if let altitude = point.altitude {
                    if let last = lastAltitude {
                        let delta = altitude - last
                        if delta > 1 { elevationGain += delta }
                    }
                    lastAltitude = altitude
                }
            }
        }
        return (distance, elevationGain)
    }
}
