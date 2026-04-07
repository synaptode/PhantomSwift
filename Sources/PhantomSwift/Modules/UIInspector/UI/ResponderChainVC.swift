#if DEBUG
import UIKit

/// Visualizes the UIResponder chain from a selected view up to UIApplication.
internal final class ResponderChainVC: UIViewController {

    private let targetView: UIView
    private var chain: [UIResponder] = []
    private let tableView = UITableView(frame: .zero, style: .plain)

    internal init(targetView: UIView) {
        self.targetView = targetView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Responder Chain"
        setupPhantomAppearance()
        buildChain()
        setupTableView()
    }

    private func buildChain() {
        var current: UIResponder? = targetView
        while let responder = current {
            chain.append(responder)
            current = responder.next
        }
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.register(ResponderCell.self, forCellReuseIdentifier: ResponderCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        let header = UILabel()
        header.text = "  Selected View  →  UIApplication"
        header.font = .systemFont(ofSize: 11, weight: .medium)
        header.textColor = UIColor.white.withAlphaComponent(0.35)
        header.frame = CGRect(x: 0, y: 0, width: 0, height: 36)
        tableView.tableHeaderView = header

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func icon(for responder: UIResponder) -> String {
        switch responder {
        case is UIApplication:         return "📱"
        case is UIWindow:              return "⬜️"
        case is UINavigationController: return "↗️"
        case is UITabBarController:    return "▦"
        case is UIViewController:      return "📋"
        case is UIButton:              return "🔘"
        case is UILabel:               return "📝"
        case is UIImageView:           return "🖼"
        case is UIScrollView:          return "📜"
        case is UITextField:           return "⌨️"
        case is UITextView:            return "⌨️"
        case is UIView:                return "⬜️"
        default:                       return "◇"
        }
    }
}

// MARK: - UITableViewDataSource

extension ResponderChainVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { chain.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ResponderCell.reuseID, for: indexPath) as! ResponderCell
        let responder = chain[indexPath.row]
        cell.configure(
            index: indexPath.row,
            name: String(describing: type(of: responder)),
            icon: icon(for: responder),
            isStart: indexPath.row == 0,
            isEnd: indexPath.row == chain.count - 1,
            isApplication: responder is UIApplication
        )
        return cell
    }
}

// MARK: - ResponderCell

private final class ResponderCell: UITableViewCell {
    static let reuseID = "ResponderCell"

    private let iconLabel = UILabel()
    private let nameLabel = UILabel()
    private let tagLabel = UILabel()
    private let lineView = UIView()
    private let dotView = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none

        lineView.backgroundColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.25)
        lineView.translatesAutoresizingMaskIntoConstraints = false

        dotView.layer.cornerRadius = 6
        dotView.layer.borderWidth = 2
        dotView.translatesAutoresizingMaskIntoConstraints = false

        iconLabel.font = .systemFont(ofSize: 16)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        tagLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold)
        tagLabel.textColor = UIColor.white.withAlphaComponent(0.3)
        tagLabel.translatesAutoresizingMaskIntoConstraints = false

        [lineView, dotView, iconLabel, nameLabel, tagLabel].forEach { contentView.addSubview($0) }
        NSLayoutConstraint.activate([
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 54),
            lineView.centerXAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 36),
            lineView.topAnchor.constraint(equalTo: contentView.topAnchor),
            lineView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            lineView.widthAnchor.constraint(equalToConstant: 2),
            dotView.centerXAnchor.constraint(equalTo: lineView.centerXAnchor),
            dotView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            dotView.widthAnchor.constraint(equalToConstant: 12),
            dotView.heightAnchor.constraint(equalToConstant: 12),
            iconLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 54),
            iconLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -8),
            tagLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            tagLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
        ])
    }

    func configure(index: Int, name: String, icon: String, isStart: Bool, isEnd: Bool, isApplication: Bool) {
        iconLabel.text = icon
        nameLabel.text = name
        tagLabel.text = isStart ? "SELECTED VIEW" : (isApplication ? "UIApplication" : "↑ next responder")

        let color: UIColor
        if isStart {
            color = UIColor.Phantom.neonAzure
            nameLabel.font = .systemFont(ofSize: 13, weight: .black)
        } else if isApplication {
            color = UIColor.Phantom.vibrantGreen
            nameLabel.font = .systemFont(ofSize: 13, weight: .bold)
        } else {
            color = UIColor.white.withAlphaComponent(0.4)
            nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        }

        dotView.backgroundColor = color.withAlphaComponent(0.2)
        dotView.layer.borderColor = color.cgColor
        nameLabel.textColor = isStart ? .white : UIColor.white.withAlphaComponent(0.8)
        tagLabel.textColor = color.withAlphaComponent(0.7)
    }
}
#endif
