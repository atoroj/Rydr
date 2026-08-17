import ActivityKit
import Foundation

/// Datos de la Live Activity / Dynamic Island mientras se graba una ruta.
/// Compartido de verdad entre dos targets — la app (`RydrNav`) y la
/// extensión de widgets (`RydrRideWidgets`) — porque WidgetKit exige que
/// quien arranca la actividad (`Activity.request`, en la app) y quien la
/// dibuja (`ActivityConfiguration`, en la extensión) usen exactamente el
/// mismo tipo `ActivityAttributes`; no es un archivo duplicado a mano.
///
/// `@available(iOS 16.2, *)`: Live Activities existen desde iOS 16.1, pero
/// `Activity.request(attributes:content:...)` con `ActivityContent` (la
/// forma que se usa aquí) es de 16.2 — la app da soporte desde iOS 15 en
/// cualquier caso, ver
/// `RydrRideLiveActivityController` para cómo se aísla esto del resto de
/// `RegisterViewController`.
@available(iOS 16.2, *)
struct RydrRideActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var km: Double
        var speedKmh: Double
    }

    let motorbikeName: String
}
