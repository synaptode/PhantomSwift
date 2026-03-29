#if DEBUG
import UIKit

/// Shows all UIGestureRecognizers attached to the selected view and its superview chain.
internal final class GestureInspectorVC: UIViewController {

    private let targetView: UIView
    private var entries: [(viewName: String, isTarget: Bool, gestures: [UIGestureRecognizer])] = []
    private let tableView = UITableView(frame: .zero, style: .grouped)

    internal init(targetView: UIView) {
        self.targetView = targetView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Gesture Recognizers"
        setupAppearance()
        collectGestures()
        setupTableView()
    }

    private func setupAppearance() {
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = PhantomTheme.shared.backgroundColor
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        }
        navigationController?.navigationBar.tintColor = UIColor.Phantom.neonAzure
    }

    private func collectGestures() {
        var current: UIView? = targetView
        var isFirst = true
        while let v = current {
            if let gestures = v.gestureRecognizers, !gestures.isEmpty {
                entries.append((
                    viewName: String(describing: type(of: v)),
                    isTarget: isFirst,
                    gestures: gestures
                ))
            }
            isFirst = false
            current = v.superview
        }
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.08)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(GestureCell.self, forCellReuseIdentifier: GestureCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        if entries.isEmpty { showEmptyState() }
    }

    private func showEmptyState() {
        let label = UILabel()
        label.text = "No gesture recognizers found\nin this view or its ancestors"
        label.textColor = UIColor.white.withAlphaComponent(0.3)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    // MARK: - Helpers

    private func describeGesture(_ gr: UIGestureRecognizer) -> String {
        var desc = String(describing: type(of: gr))
        if let tap = gr as? UITapGestureRecognizer {
            desc += " (\(tap.numberOfTapsRequired) tap, \(tap.numberOfTouchesRequired) finger)"
        } else if let swipe = gr as? UISwipeGestureRecognizer {
            let dir: String
            switch swipe.direction {
            case .left:  dir = "← Left"
            case .right: dir = "→ Right"
            case .up:    dir = "↑ Up"
            case .down:  dir = "↓ Down"
            default:     dir = "Unknown"
            }
            desc += " (\(dir))"
        } else if let pan = gr as? UIPanGestureRecognizer {
            desc += " (min: \(pan.minimumNumberOfTouches), max: \(pan.maximumNumberOfTouches))"
        } else if let lp = gr as? UILongPressGestureRecognizer {
            desc += " (\(String(format: "%.2fs", lp.minimumPressDuration)))"
        }
        return desc
    }

    private func stateString(_ gr: UIGestureRecognizer) -> String {
        switch gr.state {
        case .possible:  return "Possible"
        case .began:     return "Began"
        case .changed:   return "Changed"
        case .ended:     return "Ended"
        case .cancelled: return "Cancelled"
        case .failed:    return "Failed"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - UITableViewDataSource / Delegate

extension GestureInspectorVC: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { entries.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries[section].gestures.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let entry = entries[section]
        let tag = entry.isTarget ? "(Selected View)" : "↑ Superview"
        return "\(entry.viewName) — \(tag)"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: GestureCell.reuseID, for: indexPath) as! GestureCell
        let gr = entries[indexPath.section].gestures[indexPath.row]
        cell.configure(
            type: describeGesture(gr),
            state: stateString(gr),
            isEnabled: gr.isEnabled,
            cancelsTouches: gr.cancelsTouchesInView
        )
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.textColor = UIColor.Phantom.neonAzure
        header.textLabel?.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold)
    }
}

// MARK: - GestureCell

private final class GestureCell: UITableViewCell {
    static let reuseID = "GestureCell"

    private let typeLabel = UILabel()
    private let stateLabel = UILabel()
    private let enabledBadge = UILabel()
    private let cancelsBadge = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = PhantomTheme.shared.surfaceColor
        selectionStyle = .none

        typeLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        typeLabel.textColor = .white
        typeLabel.numberOfLines = 2
        typeLabel.translatesAutoresizingMaskIntoConstraints = false

        stateLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        stateLabel.textColor = UIColor.Phantom.neonAzure
        stateLabel.translatesAutoresizingMaskIntoConstraints = false

        let badgeRow = UIStackView(arrangedSubviews: [enabledBadge, cancelsBadge])
        badgeRow.axis = .horizontal
        badgeRow.spacing = 6
        badgeRow.translatesAutoresizingMaskIntoConstraints = false

        [typeLabel, stateLabel, badgeRow].forEach { contentView.addSubview($0) }
        NSLayoutConstraint.activate([
            typeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            typeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            typeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stateLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 4),
            stateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            badgeRow.topAnchor.constraint(equalTo: stateLabel.bottomAnchor, constant: 6),
            badgeRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            badgeRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])

        for badge in [enabledBadge, cancelsBadge] {
            badge.font = .systemFont(ofSize: 9, weight: .bold)
            badge.layer.cornerRadius = 6
            badge.layer.masksToBounds = true
        }
    }

    func configure(type: String, state: String, isEnabled: Bool, cancelsTouches: Bool) {
        typeLabel.text = type
        stateLabel.text = "State: \(state)"

        styleBadge(enabledBadge, text: isEnabled ? "  Enabled  " : "  Disabled  ",
                   color: isEnabled ? UIColor.Phantom.vibrantGreen : UIColor.Phantom.vibrantRed)
        styleBadge(cancelsBadge, text: cancelsTouches ? "  Cancels Touches  " : "  Passes Touches  ",
                   color: cancelsTouches ? UIColor.Phantom.vibrantOrange : UIColor.Phantom.neonAzure)
    }

    private func styleBadge(_ label: UILabel, text: String, color: UIColor) {
        label.text = text
        label.textColor = color
        label.backgroundColor = color.withAlphaComponent(0.15)
    }
}
#endif
