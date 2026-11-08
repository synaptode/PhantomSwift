#if DEBUG
import UIKit
import PhantomSwiftNetworking

/// Displays detailed information about a specific network request.
internal final class RequestDetailVC: UIViewController {
    private let request: PhantomRequest
    private let headerView = PhantomNetworkHeaderView()
    private let segmentedControl = UISegmentedControl(items: ["Overview", "Headers", "Body"])
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let codeView = PhantomCodeView()

    private var sections: [(title: String, rows: [(key: String, value: String)])] = []

    init(request: PhantomRequest) {
        self.request = request
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigation()
        showOverview()
    }

    private func setupNavigation() {
        let actionItem: UIBarButtonItem
        if #available(iOS 14.0, *) {
            var children: [UIMenuElement] = [
                UIAction(title: "Copy to Clipboard", image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
                    self?.copyToClipboard()
                },
                UIAction(title: "Copy as cURL", image: UIImage(systemName: "terminal")) { [weak self] _ in
                    self?.copyAsCURL()
                },
                UIAction(title: "Export as HAR", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                    self?.exportAsHAR()
                },
                UIAction(title: "Edit & Mock", image: UIImage(systemName: "pencil.and.outline")) { [weak self] _ in
                    self?.editAndMock()
                }
            ]
            children.append(
                UIMenu(title: "Create Rule", options: .displayInline, children: quickRuleActions())
            )
            let menu = UIMenu(title: "Request Actions", children: children)
            actionItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
        } else {
            actionItem = UIBarButtonItem(
                image: UIImage(systemName: "ellipsis.circle"),
                style: .plain,
                target: self,
                action: #selector(showActionSheet)
            )
        }
        navigationItem.rightBarButtonItem = actionItem
    }

    private func setupUI() {
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        title = "Request Detail"

        headerView.configure(with: request)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.applyPhantomStyle()
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)
        if PhantomGraphQLParser.isGraphQL(request: request) {
            segmentedControl.insertSegment(withTitle: "GraphQL", at: 3, animated: false)
        }

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.05)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(DetailCell.self, forCellReuseIdentifier: "DetailCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        codeView.isHidden = true
        codeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(codeView)

        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 15),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),

            segmentedControl.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 15),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),

            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            codeView.topAnchor.constraint(equalTo: tableView.topAnchor),
            codeView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            codeView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            codeView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10)
        ])
    }

    @objc private func segmentChanged() {
        let isCode = segmentedControl.selectedSegmentIndex >= 2
        tableView.isHidden = isCode
        codeView.isHidden = !isCode

        switch segmentedControl.selectedSegmentIndex {
        case 0: showOverview()
        case 1: showHeaders()
        case 2: showBody()
        case 3: showGraphQL()
        default: break
        }
    }

    private func showOverview() {
        var rows: [(key: String, value: String)] = [
            ("URL", request.url.absoluteString),
            ("Method", request.method),
            ("Time", "\(request.timestamp)")
        ]

        if let response = request.response {
            rows.append(("Status", "\(response.statusCode)"))
            rows.append(("Duration", String(format: "%.3f s", response.duration)))
            let size = ByteCountFormatter.string(fromByteCount: Int64(response.body?.count ?? 0), countStyle: .file)
            rows.append(("Size", size))
        }

        var allSections = [("General", rows)]

        if let mockoonURL = request.mockoonRedirectedURL {
            let mockoonRows: [(key: String, value: String)] = [
                ("Status", "Active — request sent to Mockoon"),
                ("Original URL", request.url.absoluteString),
                ("Mockoon URL", mockoonURL.absoluteString)
            ]
            allSections.append(("Mockoon Redirect", mockoonRows))
        }

        if let gql = PhantomGraphQLParser.parse(request: request) {
            let gqlRows: [(key: String, value: String)] = [
                ("Operation", gql.displayName),
                ("Type", gql.operationType.rawValue),
                ("Errors", gql.hasErrors ? "\(gql.errors.count) error(s)" : "None")
            ]
            allSections.append(("GraphQL", gqlRows))
        }

        sections = allSections
        tableView.reloadData()
    }

    private func showHeaders() {
        var requestRows = request.headers.sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value) }
        if requestRows.isEmpty { requestRows = [("None", "")] }

        var allSections = [("Request Headers", requestRows)]

        if let response = request.response {
            var responseRows = response.headers.sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value) }
            if responseRows.isEmpty { responseRows = [("None", "")] }
            allSections.append(("Response Headers", responseRows))
        }

        sections = allSections
        tableView.reloadData()
    }

    private func showBody() {
        var text = "── REQUEST BODY ──\n\n"
        if let body = request.body {
            text += body.prettyJSON ?? "<Non-JSON Body>"
        } else {
            text += "<Empty>"
        }

        if let response = request.response {
            text += "\n\n── RESPONSE BODY ──\n\n"
            if let body = response.body {
                text += body.prettyJSON ?? "<Non-JSON Body>"
            } else {
                text += "<Empty>"
            }
        }
        codeView.text = text
    }

    private func showGraphQL() {
        guard let gql = PhantomGraphQLParser.parse(request: request) else {
            codeView.text = "Not a GraphQL request."
            return
        }

        var lines: [String] = []
        lines.append("── GRAPHQL OPERATION ──")
        lines.append("Type: \(gql.operationType.rawValue)")
        if let name = gql.operationName {
            lines.append("Name: \(name)")
        }
        if gql.hasErrors {
            lines.append("Status: ERRORS DETECTED (\(gql.errors.count))")
            lines.append("")
            lines.append("── GRAPHQL ERRORS ──")
            for (idx, err) in gql.errors.enumerated() {
                lines.append("\(idx + 1). \(err)")
            }
        } else {
            lines.append("Status: OK (No GraphQL errors)")
        }

        if let vars = gql.variablesString, !vars.isEmpty {
            lines.append("")
            lines.append("── VARIABLES ──")
            lines.append(vars)
        }

        if let query = gql.query, !query.isEmpty {
            lines.append("")
            lines.append("── QUERY / MUTATION ──")
            lines.append(query)
        }

        if let responseBody = request.response?.body,
           let pretty = responseBody.prettyJSON {
            lines.append("")
            lines.append("── RESPONSE DATA ──")
            lines.append(pretty)
        }

        codeView.text = lines.joined(separator: "\n")
    }

    private func openRuleEditor(with draft: PhantomInterceptorDraft) {
        let editor = RuleEditorVC(draft: draft)
        navigationController?.pushViewController(editor, animated: true)
    }
}

// MARK: - Actions & Menus

extension RequestDetailVC {
    @objc internal func showActionSheet() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Copy to Clipboard", style: .default) { [weak self] _ in
            self?.copyToClipboard()
        })
        alert.addAction(UIAlertAction(title: "Copy as cURL", style: .default) { [weak self] _ in
            self?.copyAsCURL()
        })
        alert.addAction(UIAlertAction(title: "Export as HAR", style: .default) { [weak self] _ in
            self?.exportAsHAR()
        })
        alert.addAction(UIAlertAction(title: "Edit & Mock", style: .default) { [weak self] _ in
            self?.editAndMock()
        })
        alert.addAction(UIAlertAction(title: "Quick Block Rule", style: .default) { [weak self] _ in
            guard let self else { return }
            self.openRuleEditor(with: .block(for: self.request))
        })
        alert.addAction(UIAlertAction(title: "Quick Delay Rule", style: .default) { [weak self] _ in
            guard let self else { return }
            self.openRuleEditor(with: .delay(for: self.request))
        })
        alert.addAction(UIAlertAction(title: "Quick Redirect Rule", style: .default) { [weak self] _ in
            guard let self else { return }
            self.openRuleEditor(with: .redirect(for: self.request))
        })
        if request.response != nil {
            alert.addAction(UIAlertAction(title: "Quick Mock Rule", style: .default) { [weak self] _ in
                guard let self else { return }
                self.openRuleEditor(with: .mock(from: self.request))
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(alert, animated: true)
    }

    @objc internal func copyToClipboard() {
        let contentToCopy: String?
        if segmentedControl.selectedSegmentIndex >= 2 {
            contentToCopy = codeView.text
        } else {
            contentToCopy = sections.map { section in
                "\(section.title)\n" + section.rows.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            }.joined(separator: "\n\n")
        }

        UIPasteboard.general.string = contentToCopy
        let alert = UIAlertController(title: "Copied", message: "Content copied to clipboard", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc internal func copyAsCURL() {
        let curl = PhantomCURLExporter.export(from: request)
        UIPasteboard.general.string = curl
        let alert = UIAlertController(title: "Copied", message: "cURL command copied", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc internal func exportAsHAR() {
        PhantomHARExporter.shared.export(from: self, request: request)
    }

    @objc internal func editAndMock() {
        let editor = PhantomMockEditorVC(request: self.request)
        navigationController?.pushViewController(editor, animated: true)
    }

    @available(iOS 14.0, *)
    internal func quickRuleActions() -> [UIAction] {
        var actions: [UIAction] = [
            UIAction(title: "Block", image: UIImage(systemName: "hand.raised.fill")) { [weak self] _ in
                guard let self else { return }
                self.openRuleEditor(with: .block(for: self.request))
            },
            UIAction(title: "Delay", image: UIImage(systemName: "clock.badge.exclamationmark")) { [weak self] _ in
                guard let self else { return }
                self.openRuleEditor(with: .delay(for: self.request))
            },
            UIAction(title: "Redirect", image: UIImage(systemName: "arrow.triangle.swap")) { [weak self] _ in
                guard let self else { return }
                self.openRuleEditor(with: .redirect(for: self.request))
            }
        ]

        if request.response != nil {
            let mockAction = UIAction(
                title: "Mock Response",
                image: UIImage(systemName: "sparkles.rectangle.stack")
            ) { [weak self] _ in
                guard let self else { return }
                self.openRuleEditor(with: .mock(from: self.request))
            }
            actions.insert(mockAction, at: 2)
        }

        return actions
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension RequestDetailVC: UITableViewDataSource, UITableViewDelegate {
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
}
#endif
