import ActivityKit
import Foundation

/// Envuelve toda la lógica de ActivityKit (arrancar/actualizar/terminar la
/// Live Activity que se ve en la pantalla de bloqueo/Dynamic Island
/// mientras se graba) en un único sitio, aislada tras `@available(iOS
/// 16.2, *)` — el resto de la app sigue dando soporte desde iOS 15, así
/// que ni la clase en sí ni `RegisterViewController` pueden asumir que
/// ActivityKit existe. La clase NO lleva `@available` a nivel de tipo
/// (para poder guardarla como propiedad normal en `RegisterViewController`
/// sin contagiar el `@available` a toda esa clase); solo la propiedad que
/// de verdad usa un tipo de ActivityKit lo lleva.
@MainActor
final class RydrRideLiveActivityController {
    @available(iOS 16.2, *)
    private var activity: Activity<RydrRideActivityAttributes>? {
        get { _activity as? Activity<RydrRideActivityAttributes> }
        set { _activity = newValue }
    }

    // Almacenamiento real sin tipar a ActivityKit — así la propiedad en sí
    // no necesita `@available`, solo el accessor tipado de arriba.
    private var _activity: Any?

    func start(motorbikeName: String) {
        guard #available(iOS 16.2, *) else { return }
        // El usuario puede haber desactivado las Live Activities en
        // Ajustes — sin esta comprobación, `Activity.request` lanza en
        // vez de simplemente no arrancar nada.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = RydrRideActivityAttributes(motorbikeName: motorbikeName)
        let state = RydrRideActivityAttributes.ContentState(elapsedSeconds: 0, km: 0, speedKmh: 0)
        activity = try? Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
    }

    func update(elapsedSeconds: Int, km: Double, speedKmh: Double) {
        guard #available(iOS 16.2, *), let activity else { return }
        let state = RydrRideActivityAttributes.ContentState(
            elapsedSeconds: elapsedSeconds, km: km, speedKmh: speedKmh)
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        guard #available(iOS 16.2, *), let activity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        self.activity = nil
    }
}
