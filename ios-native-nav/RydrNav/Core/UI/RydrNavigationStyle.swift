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

    // Botones flotantes (silenciar voz, overview, feedback...).
    FloatingButton.appearance(for: traitCollection).tintColor = brand

    // Botones de reanudar/volver que aparecen al arrastrar el mapa o
    // volver de la vista de pasos.
    ResumeButton.appearance(for: traitCollection).tintColor = brand
    BackButton.appearance(for: traitCollection).tintColor = brand

    // Icono de flecha de giro del banner superior, la tarjeta de
    // instrucciones y la lista de pasos.
    ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsBannerView.self])
        .primaryColor = brand
    ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsCardView.self])
        .primaryColor = brand
    ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [NextBannerView.self])
        .primaryColor = brand
    ManeuverView.appearance(for: traitCollection, whenContainedInInstancesOf: [StepInstructionsView.self])
        .primaryColor = brand

    // Número de distancia del banner superior ("50 m").
    DistanceLabel.appearance(for: traitCollection, whenContainedInInstancesOf: [InstructionsBannerView.self])
        .valueTextColor = brand

    // "6 min" de tiempo restante en el banner inferior.
    TimeRemainingLabel.appearance(for: traitCollection).normalTextColor = brand
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
// que no es el mismo que `.outdoors` (el que se usa en el resto de mapas de
// la app: Rutas, Registrar, vista previa...) y además cambia de paleta según
// su "light preset" interno — de ahí el salto de blanquecino a azul oscuro
// justo al arrancar la guía. Forzamos el mismo `.outdoors` aquí para que el
// mapa se vea consistente en toda la app, también durante la navegación.
private let outdoorsMapStyleURL = URL(string: "mapbox://styles/mapbox/outdoors-v12")!

final class RydrDayStyle: StandardDayStyle {
    override func apply() {
        mapStyleURL = outdoorsMapStyleURL
        previewMapStyleURL = outdoorsMapStyleURL
        super.apply()
        applyRydrBrand(for: phoneAndPadTraitCollection)
    }
}

final class RydrNightStyle: StandardNightStyle {
    override func apply() {
        mapStyleURL = outdoorsMapStyleURL
        previewMapStyleURL = outdoorsMapStyleURL
        super.apply()
        applyRydrBrand(for: phoneAndPadTraitCollection)
    }
}
