import UIKit

/// Tarjeta del garaje virtual: fotografía, marca, modelo y año — tal cual
/// pide el spec. Si es la moto marcada como actual lleva una insignia;
/// si no, un botón para marcarla.
final class MotorbikeCardCell: UICollectionViewCell {
    var onSetCurrentTapped: (() -> Void)?

    private let card = UIView()
    private let photoImage = RemoteImageView()
    private let currentBadge = UILabel()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let setCurrentButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setup() {
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        photoImage.backgroundColor = .tertiarySystemBackground
        photoImage.translatesAutoresizingMaskIntoConstraints = false

        currentBadge.text = "  Actual  "
        currentBadge.font = .boldSystemFont(ofSize: 12)
        currentBadge.textColor = .white
        currentBadge.backgroundColor = AppTheme.primary
        currentBadge.layer.cornerRadius = 8
        currentBadge.clipsToBounds = true
        currentBadge.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .boldSystemFont(ofSize: 17)
        detailLabel.font = .systemFont(ofSize: 13)
        detailLabel.textColor = .secondaryLabel

        setCurrentButton.setTitle("Marcar como actual", for: .normal)
        setCurrentButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        setCurrentButton.contentHorizontalAlignment = .leading
        setCurrentButton.addTarget(self, action: #selector(onTapSetCurrent), for: .touchUpInside)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, detailLabel, setCurrentButton])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(photoImage)
        card.addSubview(currentBadge)
        card.addSubview(textStack)
        NSLayoutConstraint.activate([
            photoImage.topAnchor.constraint(equalTo: card.topAnchor),
            photoImage.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            photoImage.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            photoImage.heightAnchor.constraint(equalToConstant: 140),

            currentBadge.topAnchor.constraint(equalTo: photoImage.topAnchor, constant: 8),
            currentBadge.leadingAnchor.constraint(equalTo: photoImage.leadingAnchor, constant: 8),
            currentBadge.heightAnchor.constraint(equalToConstant: 22),

            textStack.topAnchor.constraint(equalTo: photoImage.bottomAnchor, constant: 12),
            textStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            textStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])
    }

    func configure(with motorbike: MotorbikeModel) {
        nameLabel.text = motorbike.displayName
        var detail = "\(motorbike.type) · \(motorbike.cc) cc"
        if let year = motorbike.year { detail += " · \(year)" }
        detailLabel.text = detail
        photoImage.load(urlString: motorbike.photoUrl, placeholder: UIImage(systemName: "bicycle"))
        currentBadge.isHidden = !motorbike.isCurrent
        setCurrentButton.isHidden = motorbike.isCurrent
    }

    @objc private func onTapSetCurrent() {
        onSetCurrentTapped?()
    }
}
