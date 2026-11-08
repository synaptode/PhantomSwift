#if DEBUG
import UIKit

/// Displays full payload, metadata, and JSON inspection for a captured notification.
internal final class PushDetailVC: UIViewController {
    private let record: PhantomPushRecord
    private let segmentedControl = UISegmentedControl(items: ["Overview", "Payload JSON"])
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let codeView = PhantomCodeView()

    private var sections: [(title: String, rows: [(key: String, value: String)])] = []

    init(record: PhantomPushRecord) {
        self.record = record
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Notification Detail"
        view.backgroundColor = PhantomTheme.shared.backgroundColor

        setupNavigation()
        setupUI()
        setupSections()
    }

    private func setupNavigation() {
        let copyButton = UIBarButtonItem(
            title: "Copy JSON",
            style: .plain,
            target: self,
            action: #selector(didTapCopy)
        )
        let resendButton = UIBarButtonItem(
            image: UIImage.phantomSymbol("arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(didTapResend)
        )
        navigationItem.rightBarButtonItems = [copyButton, resendButton]
    }

    private func setupUI() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.applyPhantomStyle()
        segmentedControl.addTarget(self, action: #selector(didChangeSegment), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.06)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(DetailCell.self, forCellReuseIdentifier: "DetailCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        codeView.isHidden = true
        codeView.text = record.userInfoJSON
        codeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(codeView)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            codeView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 10),
            codeView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            codeView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            codeView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10)
        ])
    }

    private func setupSections() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        var generalRows: [(key: String, value: String)] = [
            ("Title", record.title),
            ("Body", record.body.isEmpty ? "(Empty)" : record.body),
            ("Source", record.source.rawValue),
            ("State", record.state.rawValue),
            ("Timestamp", formatter.string(from: record.timestamp)),
            ("Identifier", record.identifier)
        ]

        if !record.subtitle.isEmpty {
            generalRows.append(("Subtitle", record.subtitle))
        }
        if let badge = record.badge {
            generalRows.append(("Badge", "\(badge)"))
        }
        if let sound = record.sound {
            generalRows.append(("Sound", sound))
        }
        if !record.categoryIdentifier.isEmpty {
            generalRows.append(("Category", record.categoryIdentifier))
        }
        if let action = record.actionIdentifier {
            generalRows.append(("Action ID", action))
        }

        sections.append(("Notification Details", generalRows))

        // Parse key-value rows from userInfo
        if let data = record.userInfoJSON.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           !json.isEmpty {
            let userRows = json.map { key, val in
                (key: key, value: "\(val)")
            }.sorted { $0.key < $1.key }
            sections.append(("User Info Keys", userRows))
        }

        tableView.reloadData()
    }

    @objc private func didChangeSegment() {
        let showCode = segmentedControl.selectedSegmentIndex == 1
        tableView.isHidden = showCode
        codeView.isHidden = !showCode
    }

    @objc private func didTapCopy() {
        UIPasteboard.general.string = record.userInfoJSON
        let alert = UIAlertController(
            title: "Copied",
            message: "Payload JSON copied to clipboard",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func didTapResend() {
        let template = PushTemplate(
            id: UUID(),
            name: "Resend: \(record.title)",
            title: record.title,
            body: record.body,
            subtitle: record.subtitle,
            categoryIdentifier: record.categoryIdentifier,
            badge: record.badge,
            sound: record.sound ?? "default",
            userInfoJSON: record.userInfoJSON,
            delay: 0.5
        )

        PhantomPushSimulator.shared.fire(template) { [weak self] result in
            let message: String
            switch result {
            case .success: message = "Notification fired."
            case .permissionDenied: message = "Permission denied."
            case .error(let err): message = err
            }
            let alert = UIAlertController(title: "Simulator", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension PushDetailVC: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "DetailCell",
            for: indexPath
        ) as? DetailCell else {
            return UITableViewCell()
        }
        let row = sections[indexPath.section].rows[indexPath.row]
        cell.configure(key: row.key, value: row.value)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        UIPasteboard.general.string = row.value
        let alert = UIAlertController(title: "Copied", message: "\(row.key) copied", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
#endif
