import MapboxNavigationCore
import MapboxNavigationUIKit
import UIKit

/// Estilos día/noche de la pantalla de navegación con el naranja de marca de
/// Rydr (``AppTheme/primary``) en vez del azul por defecto del SDK.
///
/// Deliberadamente NO tocamos aquí lo que es señalización real de carretera
/// (límites de velocidad, escudos de carretera, colores de tráfico
/// moderado/denso/severo en la línea de ruta): eso sigue los estándares que
/// un motorista espera reconocer de un vistazo. Lo que rebrandeamos es el
/// "chrome" de la app — botones, flecha de giro, línea de ruta sin tráfico,
/// textos de tiempo/distancia — para que la navegación se sienta parte de
/// Rydr y no de una demo genérica de Mapbox.
private func applyRydrBrand(for traitCollection: UITraitCollection) {
    let brand = AppTheme.primary

    // Banner superior de instrucciones: fondo ámbar sólido a todo lo
    // ancho, como el "modo en marcha" de Claude Design (exploración
    // 1f-C, "banner de giro naranja completo") — el mismo naranja de
    // marca que el botón "Registrar" y la línea de la ruta, no un
    // acento aislado sobre el fondo oscuro/claro por defecto del SDK.
    // `TopBannerView`/`TopPaddingView` son el relleno de la zona segura
    // de arriba (notch/isla); sin colorearlos también queda una costura
    // oscura entre el borde de la pantalla y el propio banner.
    TopBannerView.appearance(for: traitCollection).backgroundColor = brand
    TopPaddingView.appearance(for: traitCollection).backgroundColor = brand
    InstructionsBannerView.appearance(for: traitCollection).backgroundColor = brand

    // Con el banner ahora en ámbar, el texto y el icono pasan a oscuro
    // (antes eran claros, pensados para un fondo oscuro) para mantener
    // el contraste — igual que en el mock, donde la flecha y las cifras
    // van en `#0B0C0E` sobre el naranja.
    ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsBannerView.self])
        .primaryColor = AppTheme.bg0
    DistanceLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsBannerView.self])
        .valueTextColor = AppTheme.bg0
    DistanceLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsBannerView.self])
        .unitTextColor = AppTheme.bg0.withAlphaComponent(0.7)
    PrimaryLabel.appearance(for: traitCollection).normalTextColor = AppTheme.bg0
    SecondaryLabel.appearance(for: traitCollection).normalTextColor = AppTheme.bg0.withAlphaComponent(0.7)

    // Fila de carriles justo debajo del banner — el SDK la deja con su
    // azul por defecto si no se toca, que es justo lo que se veía en
    // vez del oscuro de la app (capturas de prueba en dispositivo real).
    // Fondo oscuro (no ámbar — ya hay bastante ámbar en el banner de
    // arriba) con la flecha del carril que toca coger en ámbar y el
    // resto atenuadas, como cualquier app de navegación real.
    LanesView.appearance(for: traitCollection).backgroundColor = AppTheme.bg1
    LaneView.appearance(for: traitCollection).primaryColor = brand
    LaneView.appearance(for: traitCollection).secondaryColor = AppTheme.textSecondary(0.3)

    // La flecha de giro de la tarjeta de instrucciones (vista de pasos)
    // y del banner "Después: X" sigue sobre fondo oscuro, así que ahí
    // se queda en ámbar.
    ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsCardView.self])
        .primaryColor = brand
    ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [NextBannerView.self])
        .primaryColor = brand
    ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [StepInstructionsView.self])
        .primaryColor = brand
    // El propio banner "Después: X" — cristal oscuro con blur en el mock
    // (`rgba(11,12,14,.88)`); sin `UIVisualEffectView` de por medio, el
    // color plano más parecido es el mismo fondo elevado que usa el
    // resto de tarjetas de la app.
    NextBannerView.appearance(for: traitCollection).backgroundColor = AppTheme.bg1.withAlphaComponent(0.92)

    // "6 min" de tiempo restante en el banner inferior.
    TimeRemainingLabel.appearance(for: traitCollection).normalTextColor = brand
    DistanceRemainingLabel.appearance(for: traitCollection).normalTextColor = AppTheme.text
    ArrivalTimeLabel.appearance(for: traitCollection).normalTextColor = AppTheme.text
    BottomBannerView.appearance(for: traitCollection).backgroundColor = AppTheme.bg1
    BottomPaddingView.appearance(for: traitCollection).backgroundColor = AppTheme.bg1

    // Botón de cancelar/salir del banner inferior — cuadrado ámbar
    // translúcido con icono ámbar, como en el mock (en vez del círculo
    // blanco por defecto del SDK que salía en las pruebas).
    CancelButton.appearance(for: traitCollection).backgroundColor = brand.withAlphaComponent(0.14)
    CancelButton.appearance(for: traitCollection).cornerRadius = 14
    CancelButton.appearance(for: traitCollection).borderColor = brand.withAlphaComponent(0.4)
    CancelButton.appearance(for: traitCollection).borderWidth = 1
    CancelButton.appearance(for: traitCollection).tintColor = brand

    // Botones flotantes sobre el mapa (vista 3D, brújula, overview,
    // silenciar voz, reportar) — cristal oscuro con icono claro, como
    // los "3D"/brújula del mock, en vez de círculos de color por
    // defecto del SDK.
    FloatingButton.appearance(for: traitCollection).tintColor = AppTheme.text
    FloatingButton.appearance(for: traitCollection).backgroundColor = UIColor.black.withAlphaComponent(0.55)
    FloatingButton.appearance(for: traitCollection).cornerRadius = 13
    FloatingButton.appearance(for: traitCollection).borderColor = UIColor.white.withAlphaComponent(0.12)
    FloatingButton.appearance(for: traitCollection).borderWidth = 1

    // Botones de reanudar/volver que aparecen al arrastrar el mapa o
    // volver de la vista de pasos.
    ResumeButton.appearance(for: traitCollection).tintColor = brand
    BackButton.appearance(for: traitCollection).tintColor = brand
}

// `Style.traitCollection` es `internal` al módulo del SDK y no es accesible
// desde aquí, así que recreamos la misma combinación (phone + pad) que usa
// internamente para aplicar su estilo por defecto.
private let phoneAndPadTraitCollection = UITraitCollection(traitsFrom: [
    UITraitCollection(userInterfaceIdiom: .phone),
    UITraitCollection(userInterfaceIdiom: .pad),
])

// `StandardDayStyle`/`StandardNightStyle` usan por defecto el estilo
// "Standard Navigation" de Mapbox (`mapbox://styles/mapbox-dash/standard-navigation`),
// que cambia de paleta según su "light preset" interno — de ahí el salto de
// blanquecino a azul oscuro justo al arrancar la guía que se veía antes.
// El mapa de "modo navegación" del prototipo de Claude Design es oscuro
// (`#0D1013`) igual que el resto de la app, así que aquí se usa `dark-v11`
// —el mismo estilo que ya usan las miniaturas de las tarjetas de ruta
// (`RouteMapSnapshot`)— y no `.outdoors` (claro, el que usan Rutas/
// Registrar/vista previa: ahí sí hace falta ver el terreno real).
private let navigationMapStyleURL = URL(string: "mapbox://styles/mapbox/dark-v11")!

final class RydrDayStyle: StandardDayStyle {
    override func apply() {
        mapStyleURL = navigationMapStyleURL
        previewMapStyleURL = navigationMapStyleURL
        super.apply()
        applyRydrBrand(for: phoneAndPadTraitCollection)
    }
}

final class RydrNightStyle: StandardNightStyle {
    override func apply() {
        mapStyleURL = navigationMapStyleURL
        previewMapStyleURL = navigationMapStyleURL
        super.apply()
        applyRydrBrand(for: phoneAndPadTraitCollection)
    }
}
