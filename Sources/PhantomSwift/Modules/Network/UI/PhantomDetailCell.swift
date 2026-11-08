#if DEBUG
import UIKit

/// Reusable key-value row cell for request inspector tables.
internal final class DetailCell: UITableViewCell {
    private let keyLabel = UILabel()
    private let valueLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none

        keyLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        keyLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.7)
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(keyLabel)

        valueLabel.font = UIFont.phantomMonospaced(size: 11, weight: .medium)
        valueLabel.textColor = PhantomTheme.shared.textColor
        valueLabel.numberOfLines = 0
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            keyLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            keyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            keyLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),

            valueLabel.topAnchor.constraint(equalTo: keyLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: keyLabel.leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: keyLabel.trailingAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    func configure(key: String, value: String) {
        keyLabel.text = key.uppercased()
        valueLabel.text = value
    }
}
#endif
