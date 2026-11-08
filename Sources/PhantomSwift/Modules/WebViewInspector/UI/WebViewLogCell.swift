#if DEBUG
import UIKit

/// Custom table cell for displaying WKWebView console and bridge logs.
internal final class WebViewLogCell: UITableViewCell {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let payloadLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = PhantomTheme.shared.textColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        timeLabel.font = UIFont.phantomMonospaced(size: 10, weight: .regular)
        timeLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(timeLabel)

        payloadLabel.font = UIFont.phantomMonospaced(size: 11, weight: .regular)
        payloadLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.85)
        payloadLabel.numberOfLines = 2
        payloadLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(payloadLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),

            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            timeLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            payloadLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            payloadLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            payloadLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            payloadLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    func configure(with entry: PhantomWebViewLogEntry) {
        titleLabel.text = entry.kind.title
        payloadLabel.text = entry.payload

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        timeLabel.text = formatter.string(from: entry.timestamp)

        switch entry.kind {
        case .console(let level):
            iconView.image = UIImage.phantomSymbol("terminal")
            if level.lowercased() == "error" {
                iconView.tintColor = UIColor.Phantom.vibrantRed
                titleLabel.textColor = UIColor.Phantom.vibrantRed
            } else if level.lowercased() == "warn" {
                iconView.tintColor = UIColor.Phantom.vibrantOrange
                titleLabel.textColor = UIColor.Phantom.vibrantOrange
            } else {
                iconView.tintColor = UIColor.Phantom.vibrantGreen
                titleLabel.textColor = PhantomTheme.shared.textColor
            }
        case .bridge:
            iconView.image = UIImage.phantomSymbol("arrow.left.arrow.right")
            iconView.tintColor = UIColor.Phantom.electricIndigo
            titleLabel.textColor = UIColor.Phantom.electricIndigo
        }
    }
}
#endif
