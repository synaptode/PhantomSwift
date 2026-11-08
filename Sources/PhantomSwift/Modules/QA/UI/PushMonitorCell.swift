#if DEBUG
import UIKit

/// Custom table cell for displaying captured push and local notifications.
internal final class PushMonitorCell: UITableViewCell {
    private let cardView = UIView()
    private let sourceBadge = UILabel()
    private let stateBadge = UILabel()
    private let timeLabel = UILabel()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let badgeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        cardView.backgroundColor = PhantomTheme.shared.surfaceColor
        cardView.layer.cornerRadius = 10
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        sourceBadge.font = .systemFont(ofSize: 10, weight: .bold)
        sourceBadge.layer.cornerRadius = 4
        sourceBadge.clipsToBounds = true
        sourceBadge.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(sourceBadge)

        stateBadge.font = .systemFont(ofSize: 10, weight: .bold)
        stateBadge.layer.cornerRadius = 4
        stateBadge.clipsToBounds = true
        stateBadge.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(stateBadge)

        timeLabel.font = UIFont.phantomMonospaced(size: 10, weight: .regular)
        timeLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(timeLabel)

        titleLabel.font = .systemFont(ofSize: 14, weight: .bold)
        titleLabel.textColor = PhantomTheme.shared.textColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)

        bodyLabel.font = .systemFont(ofSize: 12, weight: .regular)
        bodyLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.7)
        bodyLabel.numberOfLines = 2
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(bodyLabel)

        badgeLabel.font = UIFont.phantomMonospaced(size: 10, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = UIColor.Phantom.vibrantRed
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.clipsToBounds = true
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(badgeLabel)

        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            sourceBadge.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),
            sourceBadge.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            sourceBadge.heightAnchor.constraint(equalToConstant: 18),

            stateBadge.centerYAnchor.constraint(equalTo: sourceBadge.centerYAnchor),
            stateBadge.leadingAnchor.constraint(equalTo: sourceBadge.trailingAnchor, constant: 6),
            stateBadge.heightAnchor.constraint(equalToConstant: 18),

            timeLabel.centerYAnchor.constraint(equalTo: sourceBadge.centerYAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),

            titleLabel.topAnchor.constraint(equalTo: sourceBadge.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeLabel.leadingAnchor, constant: -8),

            badgeLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            badgeLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),
            badgeLabel.heightAnchor.constraint(equalToConstant: 16),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            bodyLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            bodyLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            bodyLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -10)
        ])
    }

    func configure(with record: PhantomPushRecord) {
        titleLabel.text = record.title
        bodyLabel.text = record.body.isEmpty ? "(No Body)" : record.body

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        timeLabel.text = formatter.string(from: record.timestamp)

        switch record.source {
        case .remote:
            sourceBadge.text = " APNS "
            sourceBadge.textColor = .white
            sourceBadge.backgroundColor = UIColor.Phantom.vibrantPurple
        case .local:
            sourceBadge.text = " LOCAL "
            sourceBadge.textColor = .white
            sourceBadge.backgroundColor = UIColor.Phantom.neonAzure
        case .simulated:
            sourceBadge.text = " SIM "
            sourceBadge.textColor = .white
            sourceBadge.backgroundColor = UIColor.Phantom.vibrantOrange
        }

        switch record.state {
        case .receivedForeground:
            stateBadge.text = " FOREGROUND "
            stateBadge.textColor = .white
            stateBadge.backgroundColor = UIColor.Phantom.vibrantGreen
        case .openedByUser:
            stateBadge.text = " OPENED "
            stateBadge.textColor = .white
            stateBadge.backgroundColor = UIColor.Phantom.electricIndigo
        case .background:
            stateBadge.text = " BG "
            stateBadge.textColor = .white
            stateBadge.backgroundColor = .systemGray
        }

        if let badge = record.badge, badge > 0 {
            badgeLabel.text = " \(badge) "
            badgeLabel.isHidden = false
        } else {
            badgeLabel.isHidden = true
        }
    }
}
#endif
