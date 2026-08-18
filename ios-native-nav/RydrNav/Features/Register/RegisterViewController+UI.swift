import MapboxMaps
import UIKit

/// Construcción de las vistas de "Registrar" — separado de
/// `RegisterViewController.swift`, que se queda con el ciclo de vida, los
/// flujos de negocio (empezar/pausar/reanudar/terminar) y el delegado de
/// `CLLocationManager`. Nada aquí toca `RideRecordingSession` ni cifras de
/// grabación, solo construye/coloca vistas — separación mecánica, mismo
/// comportamiento que antes.
extension RegisterViewController {
    // MARK: - Mapa compartido

    func setupMap() {
        mapView = MapView(frame: .zero, mapInitOptions: MapInitOptions(styleURI: .outdoors))
        mapView.location.options = LocationOptions(
            puckType: .puck2D(Self.brandedPuck), puckBearing: .heading, puckBearingEnabled: true)
        polylineManager = mapView.annotations.makePolylineAnnotationManager()
        polylineManager?.lineCap = .round
        polylineManager?.lineJoin = .round
    }

    /// Punto de posición en el ámbar de marca (con anillo de precisión y
    /// pulso a juego) en vez del azul por defecto del SDK — mismo espíritu
    /// que `RydrNavigationStyle`, aplicado aquí también.
    private static let brandedPuck: Puck2DConfiguration = {
        var puck = Puck2DConfiguration(topImage: dotImage())
        puck.pulsing = .init(color: AppTheme.primary, radius: .accuracy)
        puck.showsAccuracyRing = true
        puck.accuracyRingColor = AppTheme.primary.withAlphaComponent(0.12)
        puck.accuracyRingBorderColor = AppTheme.primary.withAlphaComponent(0.3)
        return puck
    }()

    private static func dotImage() -> UIImage {
        let size = CGSize(width: 22, height: 22)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
            AppTheme.bg0.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            AppTheme.primary.setFill()
            UIBezierPath(ovalIn: rect).fill()
        }
    }

    /// Traslada el mapa compartido al contenedor del estado que toca
    /// mostrar — así la cámara y el trazado dibujado no se reinician al
    /// pasar de reposo a grabando.
    private func moveMapView(to wrapper: UIView) {
        guard mapView.superview !== wrapper else { return }
        mapView.removeFromSuperview()
        mapView.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: wrapper.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
        ])
    }

    /// Botón de cerrar en cristal de verdad (Liquid Glass en iOS 26,
    /// esmerilado normal antes) en vez del círculo negro semitransparente
    /// de antes — aquí sí tiene sentido notarse, porque detrás siempre hay
    /// mapa en movimiento, a diferencia de la barra inferior (fondo plano)
    /// donde lo probamos primero.
    func setupCloseButton() {
        let effect: UIVisualEffect
        if #available(iOS 26.0, *) {
            effect = UIGlassEffect(style: .regular)
        } else {
            effect = UIBlurEffect(style: .systemChromeMaterial)
        }
        let glass = UIVisualEffectView(effect: effect)
        glass.layer.cornerRadius = 18
        glass.clipsToBounds = true
        glass.translatesAutoresizingMaskIntoConstraints = false

        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(onCloseTapped), for: .touchUpInside)
        glass.contentView.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: glass.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: glass.centerYAnchor),
        ])

        view.addSubview(glass)
        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            glass.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            glass.widthAnchor.constraint(equalToConstant: 36),
            glass.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    // MARK: - Estado "en reposo" (is.recIdle)

    func setupIdleContainer() {
        idleContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(idleContainer)
        NSLayoutConstraint.activate([
            idleContainer.topAnchor.constraint(equalTo: view.topAnchor),
            idleContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            idleContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            idleContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        idleMapWrapper.translatesAutoresizingMaskIntoConstraints = false
        idleMapWrapper.clipsToBounds = true

        gpsChipDot.backgroundColor = AppTheme.textSecondary(0.3)
        gpsChipDot.layer.cornerRadius = 3.5
        gpsChipDot.translatesAutoresizingMaskIntoConstraints = false
        gpsChipDot.widthAnchor.constraint(equalToConstant: 7).isActive = true
        gpsChipDot.heightAnchor.constraint(equalToConstant: 7).isActive = true

        gpsChipLabel.styleAsLabel("Buscando GPS…", size: 12, medium: true, color: AppTheme.textSecondary(0.75), tracking: 0.7)

        let gpsChip = UIStackView(arrangedSubviews: [gpsChipDot, gpsChipLabel])
        gpsChip.axis = .horizontal
        gpsChip.spacing = 9
        gpsChip.alignment = .center
        gpsChip.isLayoutMarginsRelativeArrangement = true
        gpsChip.layoutMargins = UIEdgeInsets(top: 9, left: 12, bottom: 9, right: 12)
        gpsChip.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        gpsChip.layer.cornerRadius = 11
        gpsChip.clipsToBounds = true
        gpsChip.translatesAutoresizingMaskIntoConstraints = false

        idleMapWrapper.addSubview(gpsChip)
        NSLayoutConstraint.activate([
            gpsChip.topAnchor.constraint(equalTo: idleMapWrapper.safeAreaLayoutGuide.topAnchor, constant: 8),
            gpsChip.leadingAnchor.constraint(equalTo: idleMapWrapper.leadingAnchor, constant: 54),
            gpsChip.trailingAnchor.constraint(lessThanOrEqualTo: idleMapWrapper.trailingAnchor, constant: -14),
        ])

        let bikeCard = buildBikeSelectorCard()

        startButton.backgroundColor = AppTheme.primary
        startButton.layer.cornerRadius = 22
        startButton.layer.shadowColor = AppTheme.primary.cgColor
        startButton.layer.shadowOpacity = 0.35
        startButton.layer.shadowRadius = 14
        startButton.layer.shadowOffset = CGSize(width: 0, height: 8)
        startButton.heightAnchor.constraint(equalToConstant: 88).isActive = true
        startButton.addTarget(self, action: #selector(onStartTapped), for: .touchUpInside)

        let startTitle = UILabel()
        startTitle.styleAsLabel("Empezar ruta", size: 24, color: AppTheme.bg0, tracking: 2)
        let startSubtitle = UILabel()
        startSubtitle.styleAsLabel("se graba en segundo plano", size: 11.5, medium: true, color: AppTheme.bg0.withAlphaComponent(0.6), tracking: 0.8)
        let startTextStack = UIStackView(arrangedSubviews: [startTitle, startSubtitle])
        startTextStack.axis = .vertical
        startTextStack.spacing = 2
        startTextStack.alignment = .center
        startTextStack.isUserInteractionEnabled = false
        startTextStack.translatesAutoresizingMaskIntoConstraints = false
        startButton.addSubview(startTextStack)
        NSLayoutConstraint.activate([
            startTextStack.centerXAnchor.constraint(equalTo: startButton.centerXAnchor),
            startTextStack.centerYAnchor.constraint(equalTo: startButton.centerYAnchor),
        ])

        let contentStack = UIStackView(arrangedSubviews: [bikeCard, startButton])
        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        idleContainer.addSubview(idleMapWrapper)
        idleContainer.addSubview(contentStack)
        NSLayoutConstraint.activate([
            idleMapWrapper.topAnchor.constraint(equalTo: idleContainer.topAnchor),
            idleMapWrapper.leadingAnchor.constraint(equalTo: idleContainer.leadingAnchor),
            idleMapWrapper.trailingAnchor.constraint(equalTo: idleContainer.trailingAnchor),
            // Ya no una altura fija — el mapa ocupa todo lo que sobra por
            // encima de la tarjeta de moto + botón de empezar (que ahora,
            // sin los dos botones secundarios que había debajo, también
            // dejan más hueco libre).
            idleMapWrapper.bottomAnchor.constraint(equalTo: contentStack.topAnchor, constant: -16),

            contentStack.leadingAnchor.constraint(equalTo: idleContainer.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: idleContainer.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(
                equalTo: idleContainer.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    private func buildBikeSelectorCard() -> UIView {
        let card = UIView()
        card.backgroundColor = AppTheme.cardBackground
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 1
        card.layer.borderColor = AppTheme.cardBorder.cgColor
        card.isUserInteractionEnabled = true
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onChangeBikeTapped)))

        let swatch = UIView()
        swatch.backgroundColor = AppTheme.bg3
        swatch.layer.cornerRadius = 8
        swatch.translatesAutoresizingMaskIntoConstraints = false
        swatch.widthAnchor.constraint(equalToConstant: 44).isActive = true
        swatch.heightAnchor.constraint(equalToConstant: 34).isActive = true

        bikeCardLabel.font = AppFont.body(14.5, .semibold)
        bikeCardLabel.textColor = AppTheme.text
        bikeCardLabel.text = "Cargando tus motos…"

        bikeCardCaption.styleAsLabel("Moto actual · cambiar", size: 11.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.6)

        let textStack = UIStackView(arrangedSubviews: [bikeCardLabel, bikeCardCaption])
        textStack.axis = .vertical
        textStack.spacing = 2

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = AppTheme.textSecondary(0.5)
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.widthAnchor.constraint(equalToConstant: 14).isActive = true

        let row = UIStackView(arrangedSubviews: [swatch, textStack, chevron])
        row.axis = .horizontal
        row.spacing = 11
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 13),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -13),
        ])
        return card
    }

    // MARK: - Estado "grabando" (is.recActive)

    func setupActiveContainer() {
        activeContainer.translatesAutoresizingMaskIntoConstraints = false
        activeContainer.backgroundColor = AppTheme.bg1
        view.addSubview(activeContainer)
        NSLayoutConstraint.activate([
            activeContainer.topAnchor.constraint(equalTo: view.topAnchor),
            activeContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            activeContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            activeContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        recDot.backgroundColor = AppTheme.primary
        recDot.layer.cornerRadius = 4.5
        recDot.translatesAutoresizingMaskIntoConstraints = false
        recDot.widthAnchor.constraint(equalToConstant: 9).isActive = true
        recDot.heightAnchor.constraint(equalToConstant: 9).isActive = true
        addPulseAnimation(to: recDot)

        stateLabel.styleAsLabel("Grabando", size: 12.5, medium: true, color: AppTheme.primary, tracking: 1.4)
        activeBikeLabel.styleAsLabel(size: 12.5, medium: true, color: AppTheme.textSecondary(0.45), tracking: 0.9)

        let headerRow = UIStackView(arrangedSubviews: [recDot, stateLabel, UIView(), activeBikeLabel])
        headerRow.axis = .horizontal
        headerRow.spacing = 9
        headerRow.alignment = .center
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        // Más pequeño que antes (era 70pt a toda plana, empujando el mapa
        // hacia abajo) — ahora vive dentro de una tarjeta flotante sobre el
        // mapa a pantalla completa, así que no necesita tanto peso visual;
        // el trazado en vivo es el protagonista, no el cronómetro.
        timeLabel.font = AppFont.data(46)
        timeLabel.textColor = AppTheme.text
        timeLabel.text = "00:00"

        let timeCaption = UILabel()
        timeCaption.styleAsLabel("en marcha", size: 11, color: AppTheme.textSecondary(0.42), tracking: 1.6)

        let statsRow = UIStackView(arrangedSubviews: [
            activeStatCard(valueLabel: kmValueLabel, caption: "km"),
            activeStatCard(valueLabel: speedValueLabel, caption: "km/h med"),
            activeStatCard(valueLabel: elevationValueLabel, caption: "m+"),
        ])
        statsRow.axis = .horizontal
        statsRow.spacing = 10
        statsRow.distribution = .fillEqually

        let infoStack = UIStackView(arrangedSubviews: [headerRow, timeLabel, timeCaption, statsRow])
        infoStack.axis = .vertical
        // .fill (no .leading): headerRow necesita estirarse a todo el
        // ancho para que su spacer empuje `activeBikeLabel` al borde
        // derecho, y statsRow para que las 3 tarjetas repartan el ancho
        // completo — con `.leading` ambos se quedaban encogidos a su
        // tamaño intrínseco. timeLabel/timeCaption son texto normal, con
        // `.fill` simplemente ocupan el ancho de más sin cambiar cómo se
        // ven (siguen alineados a la izquierda).
        infoStack.alignment = .fill
        infoStack.spacing = 4
        infoStack.setCustomSpacing(14, after: timeCaption)
        infoStack.translatesAutoresizingMaskIntoConstraints = false

        // Tarjeta flotante (cristal oscuro semitransparente + sombra) en
        // vez del bloque opaco de antes que ocupaba su propia franja fija
        // encima del mapa — ahora el mapa va a pantalla completa por
        // detrás y esta tarjeta flota sobre él, dejando mucho más mapa (y
        // trazado) visible, como se pidió.
        let infoCard = UIView()
        infoCard.backgroundColor = AppTheme.bg1.withAlphaComponent(0.88)
        infoCard.layer.cornerRadius = 18
        infoCard.layer.borderWidth = 1
        infoCard.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        infoCard.layer.shadowColor = UIColor.black.cgColor
        infoCard.layer.shadowOpacity = 0.35
        infoCard.layer.shadowRadius = 16
        infoCard.layer.shadowOffset = CGSize(width: 0, height: 8)
        infoCard.translatesAutoresizingMaskIntoConstraints = false
        infoCard.addSubview(infoStack)
        NSLayoutConstraint.activate([
            infoStack.topAnchor.constraint(equalTo: infoCard.topAnchor, constant: 14),
            infoStack.bottomAnchor.constraint(equalTo: infoCard.bottomAnchor, constant: -14),
            infoStack.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor, constant: 14),
            infoStack.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor, constant: -14),
        ])

        activeMapWrapper.translatesAutoresizingMaskIntoConstraints = false
        activeMapWrapper.clipsToBounds = true

        // Pausar/Reanudar — secundario (fondo `bg2`, sin el ámbar sólido
        // del de Fin) para no competir visualmente con él, pero mismo
        // alto (72pt) para pulsarse igual de fácil con guantes.
        pauseIcon.tintColor = AppTheme.text
        pauseIcon.contentMode = .scaleAspectFit
        pauseIcon.translatesAutoresizingMaskIntoConstraints = false
        pauseIcon.widthAnchor.constraint(equalToConstant: 16).isActive = true

        let pauseContent = UIStackView(arrangedSubviews: [pauseIcon, pauseLabelView])
        pauseContent.axis = .horizontal
        pauseContent.spacing = 8
        pauseContent.alignment = .center
        pauseContent.isUserInteractionEnabled = false
        pauseContent.translatesAutoresizingMaskIntoConstraints = false

        pauseButton.backgroundColor = AppTheme.bg2
        pauseButton.layer.cornerRadius = 18
        pauseButton.layer.borderWidth = 1
        pauseButton.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        pauseButton.translatesAutoresizingMaskIntoConstraints = false
        pauseButton.heightAnchor.constraint(equalToConstant: 72).isActive = true
        pauseButton.addTarget(self, action: #selector(onPauseTapped), for: .touchUpInside)
        pauseButton.addSubview(pauseContent)
        NSLayoutConstraint.activate([
            pauseContent.centerXAnchor.constraint(equalTo: pauseButton.centerXAnchor),
            pauseContent.centerYAnchor.constraint(equalTo: pauseButton.centerYAnchor),
        ])
        updatePauseButton()

        // Fin — ámbar, alto (72pt) para pulsarse con guantes. Reparte el
        // ancho con "Pausar" en vez de ocupar toda la barra él solo.
        let finishIcon = UIImageView(image: UIImage(systemName: "stop.fill"))
        finishIcon.tintColor = AppTheme.bg0
        finishIcon.contentMode = .scaleAspectFit
        finishIcon.translatesAutoresizingMaskIntoConstraints = false
        finishIcon.widthAnchor.constraint(equalToConstant: 16).isActive = true

        let finishLabel = UILabel()
        finishLabel.styleAsLabel("Fin", size: 15, color: AppTheme.bg0, tracking: 1.2)

        let finishContent = UIStackView(arrangedSubviews: [finishIcon, finishLabel])
        finishContent.axis = .horizontal
        finishContent.spacing = 8
        finishContent.alignment = .center
        finishContent.isUserInteractionEnabled = false
        finishContent.translatesAutoresizingMaskIntoConstraints = false

        let finishButton = UIButton(type: .system)
        finishButton.backgroundColor = AppTheme.primary
        finishButton.layer.cornerRadius = 18
        finishButton.layer.shadowColor = AppTheme.primary.cgColor
        finishButton.layer.shadowOpacity = 0.3
        finishButton.layer.shadowRadius = 10
        finishButton.layer.shadowOffset = CGSize(width: 0, height: 6)
        finishButton.translatesAutoresizingMaskIntoConstraints = false
        finishButton.heightAnchor.constraint(equalToConstant: 72).isActive = true
        finishButton.addTarget(self, action: #selector(onFinishTapped), for: .touchUpInside)
        finishButton.addSubview(finishContent)
        NSLayoutConstraint.activate([
            finishContent.centerXAnchor.constraint(equalTo: finishButton.centerXAnchor),
            finishContent.centerYAnchor.constraint(equalTo: finishButton.centerYAnchor),
        ])

        let bottomBar = UIView()
        bottomBar.backgroundColor = AppTheme.bg1
        bottomBar.layer.borderWidth = 1
        bottomBar.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        // Pausar/Reanudar más estrecho que Fin (2:3) — el gesto de
        // terminar es el que se pulsa una vez y de forma decidida; pausar
        // se usa varias veces por ruta y no necesita tanto peso.
        let buttonsRow = UIStackView(arrangedSubviews: [pauseButton, finishButton])
        buttonsRow.axis = .horizontal
        buttonsRow.spacing = 10
        buttonsRow.distribution = .fill
        pauseButton.widthAnchor.constraint(equalTo: finishButton.widthAnchor, multiplier: 2.0 / 3.0).isActive = true
        buttonsRow.translatesAutoresizingMaskIntoConstraints = false

        bottomBar.addSubview(buttonsRow)
        NSLayoutConstraint.activate([
            buttonsRow.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 14),
            buttonsRow.bottomAnchor.constraint(equalTo: bottomBar.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            buttonsRow.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            buttonsRow.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),
        ])

        // Orden de capas: mapa primero (a pantalla completa, de fondo),
        // tarjeta de cifras y barra inferior encima flotando — antes el
        // mapa era un hermano más, encajado en el hueco que dejaban las
        // otras dos franjas.
        activeContainer.addSubview(activeMapWrapper)
        activeContainer.addSubview(infoCard)
        activeContainer.addSubview(bottomBar)
        NSLayoutConstraint.activate([
            activeMapWrapper.topAnchor.constraint(equalTo: activeContainer.topAnchor),
            activeMapWrapper.leadingAnchor.constraint(equalTo: activeContainer.leadingAnchor),
            activeMapWrapper.trailingAnchor.constraint(equalTo: activeContainer.trailingAnchor),
            activeMapWrapper.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            infoCard.topAnchor.constraint(equalTo: activeContainer.safeAreaLayoutGuide.topAnchor, constant: 8),
            infoCard.leadingAnchor.constraint(equalTo: activeContainer.leadingAnchor, constant: 12),
            infoCard.trailingAnchor.constraint(equalTo: activeContainer.trailingAnchor, constant: -12),

            bottomBar.leadingAnchor.constraint(equalTo: activeContainer.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: activeContainer.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: activeContainer.bottomAnchor),
        ])
    }

    private func activeStatCard(valueLabel: UILabel, caption: String) -> UIView {
        let container = UIView()
        container.backgroundColor = AppTheme.cardBackground
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 1
        container.layer.borderColor = AppTheme.cardBorder.cgColor

        valueLabel.font = AppFont.data(28)
        valueLabel.textColor = AppTheme.text
        valueLabel.text = "0"

        let captionLabel = UILabel()
        captionLabel.styleAsLabel(caption, size: 10, color: AppTheme.textSecondary(0.42), tracking: 1.2)

        let stack = UIStackView(arrangedSubviews: [valueLabel, captionLabel])
        stack.axis = .vertical
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 11),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -6),
        ])
        return container
    }

    func addPulseAnimation(to view: UIView) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0.25
        animation.duration = 0.8
        animation.autoreverses = true
        animation.repeatCount = .infinity
        view.layer.add(animation, forKey: "pulse")
    }

    // MARK: - Cambiar entre reposo/grabando

    func switchToIdle(animated: Bool) {
        moveMapView(to: idleMapWrapper)
        idleContainer.isHidden = false
        activeContainer.isHidden = true
    }

    func switchToActive() {
        moveMapView(to: activeMapWrapper)
        idleContainer.isHidden = true
        activeContainer.isHidden = false
    }
}
