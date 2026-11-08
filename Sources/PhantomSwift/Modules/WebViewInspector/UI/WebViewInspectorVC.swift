#if DEBUG
import UIKit
#if canImport(WebKit)
import WebKit

/// Dedicated inspector for WKWebView instances: console & bridge logs, DOM/HTML inspection, and JS REPL.
internal final class WebViewInspectorVC: UIViewController, PhantomEventObserver {

    // MARK: - Subviews
    internal let modeSegmentedControl = UISegmentedControl(items: ["Logs", "UI & DOM", "JS REPL"])
    internal let containerView = UIView()
    internal let emptyStateView = PhantomEmptyStateView(
        symbolName: "globe",
        title: "No WebView Active",
        message: "Load a webpage in WKWebView to inspect HTML, scripts, console logs, and JS-to-native messages."
    )

    // MARK: - Logs View Subviews
    internal let logsContainer = UIView()
    internal let logFilterControl = UISegmentedControl(items: ["All", "Console", "Bridge", "Errors"])
    internal let searchBar = UISearchBar()
    internal let logsTableView = UITableView(frame: .zero, style: .plain)

    // MARK: - DOM View Subviews
    internal let domContainer = UIView()
    internal let domHeaderCard = UIView()
    internal let domUrlLabel = UILabel()
    internal let domTitleLabel = UILabel()
    internal let domFetchButton = UIButton(type: .system)
    internal let domSubSegment = UISegmentedControl(items: ["HTML Source", "Scripts"])
    internal let domCodeView = PhantomCodeView()
    internal let domScriptsTableView = UITableView(frame: .zero, style: .plain)

    // MARK: - REPL View Subviews
    internal let replContainer = UIView()
    internal let replInputView = UITextView()
    internal let replRunButton = UIButton(type: .system)
    internal let replOutputView = PhantomCodeView()
    // MARK: - State
    private var allEntries: [PhantomWebViewLogEntry] = []
    private var filteredEntries: [PhantomWebViewLogEntry] = []
    private var scriptsList: [[String: String]] = []
    private var activeWebView: WKWebView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "WebView"
        view.backgroundColor = PhantomTheme.shared.backgroundColor

        setupNavigationItems()
        setupUI()
        setupTableViews()
        refreshActiveWebView()
        reloadLogs()

        PhantomEventBus.shared.subscribe(self, to: PhantomWebViewStore.didUpdateNotification)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshActiveWebView()
    }

    deinit {
        PhantomEventBus.shared.unsubscribe(self, from: PhantomWebViewStore.didUpdateNotification)
    }

    // MARK: - UI Setup

    private func setupNavigationItems() {
        let clearButton = UIBarButtonItem(
            title: "Clear",
            style: .plain,
            target: self,
            action: #selector(didTapClear)
        )
        let storageButton = UIBarButtonItem(
            image: UIImage.phantomSymbol("tray.full"),
            style: .plain,
            target: self,
            action: #selector(didTapStorage)
        )
        let refreshButton = UIBarButtonItem(
            image: UIImage.phantomSymbol("arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(didTapRefresh)
        )
        navigationItem.rightBarButtonItems = [clearButton, storageButton, refreshButton]
    }

    // MARK: - State Management

    private func refreshActiveWebView() {
        let webViews = PhantomWebViewStore.shared.activeWebViews()
        activeWebView = webViews.first

        let hasWebView = (activeWebView != nil)
        emptyStateView.isHidden = hasWebView
        containerView.isHidden = !hasWebView

        if let currentWebView = activeWebView {
            domTitleLabel.text = currentWebView.title?.isEmpty == false ? currentWebView.title : "Untitled Document"
            domUrlLabel.text = currentWebView.url?.absoluteString ?? "about:blank"
        }
    }

    private func reloadLogs() {
        allEntries = PhantomWebViewStore.shared.allLogs
        applyFilter()
    }

    private func applyFilter() {
        let query = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let filterIndex = logFilterControl.selectedSegmentIndex

        filteredEntries = allEntries.reversed().filter { entry in
            let matchesFilter: Bool
            switch filterIndex {
            case 1:
                if case .console = entry.kind { matchesFilter = true } else { matchesFilter = false }
            case 2:
                if case .bridge = entry.kind { matchesFilter = true } else { matchesFilter = false }
            case 3:
                matchesFilter = entry.kind.isError
            default:
                matchesFilter = true
            }

            guard matchesFilter else { return false }
            guard !query.isEmpty else { return true }

            let textMatch = entry.payload.lowercased().contains(query)
                || entry.kind.title.lowercased().contains(query)
                || (entry.sourceURL?.lowercased().contains(query) ?? false)
            return textMatch
        }

        logsTableView.reloadData()
    }

    // MARK: - Actions

    @objc internal func didChangeMode() {
        updateModeVisibility()
    }

    @objc internal func didChangeLogFilter() {
        applyFilter()
    }

    @objc internal func didChangeDOMSubSegment() {
        updateDOMSubSegmentVisibility()
    }

    @objc private func didTapClear() {
        PhantomWebViewStore.shared.clear()
        reloadLogs()
    }

    @objc private func didTapRefresh() {
        refreshActiveWebView()
        reloadLogs()
        if modeSegmentedControl.selectedSegmentIndex == 1 {
            didTapFetchDOM()
        }
    }
    @objc private func didTapStorage() {
        let storageVC = WebViewStorageVC()
        navigationController?.pushViewController(storageVC, animated: true)
    }

    @objc internal func didTapFetchDOM() {
        guard let currentWebView = activeWebView else { return }
        domFetchButton.setTitle("Fetching...", for: .normal)

        currentWebView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, error in
            guard let self else { return }
            self.domFetchButton.setTitle("Fetch HTML", for: .normal)
            if let html = result as? String {
                self.domCodeView.text = html
            } else if let error {
                self.domCodeView.text = "Error reading HTML: \(error.localizedDescription)"
            }
        }

        let scriptExtraction = """
        Array.from(document.querySelectorAll('script')).map(function(s, idx) {
            return {
                src: s.src || '',
                type: s.type || 'text/javascript',
                inlineSnippet: s.src ? '' : (s.textContent || '').trim().substring(0, 300)
            };
        });
        """

        currentWebView.evaluateJavaScript(scriptExtraction) { [weak self] result, _ in
            guard let self else { return }
            if let rawArray = result as? [[String: Any]] {
                self.scriptsList = rawArray.map { dict in
                    [
                        "src": (dict["src"] as? String) ?? "",
                        "type": (dict["type"] as? String) ?? "text/javascript",
                        "inlineSnippet": (dict["inlineSnippet"] as? String) ?? ""
                    ]
                }
                self.domScriptsTableView.reloadData()
            }
        }
    }

    @objc internal func didTapRunREPL() {
        guard let currentWebView = activeWebView else { return }
        let script = replInputView.text ?? ""
        guard !script.isEmpty else { return }

        view.endEditing(true)
        replRunButton.setTitle("Running...", for: .normal)

        currentWebView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self else { return }
            self.replRunButton.setTitle("Evaluate Script", for: .normal)
            if let error {
                self.replOutputView.text = "Error:\n\(error.localizedDescription)"
            } else if let result {
                self.replOutputView.text = "Result:\n\(result)"
            } else {
                self.replOutputView.text = "Result:\nundefined"
            }
        }
    }
}

// MARK: - Event Bus Observer

extension WebViewInspectorVC {
    func onEvent(_ event: PhantomEvent) {
        if case .webViewUpdated = event {
            DispatchQueue.main.async { [weak self] in
                self?.refreshActiveWebView()
                self?.reloadLogs()
            }
        }
    }
}

// MARK: - UISearchBarDelegate

extension WebViewInspectorVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFilter()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension WebViewInspectorVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == logsTableView {
            return filteredEntries.count
        } else {
            return scriptsList.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == logsTableView {
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: "WebViewLogCell",
                for: indexPath
            ) as? WebViewLogCell else {
                return UITableViewCell()
            }
            cell.configure(with: filteredEntries[indexPath.row])
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ScriptCell", for: indexPath)
            cell.backgroundColor = .clear
            cell.textLabel?.textColor = PhantomTheme.shared.textColor
            cell.textLabel?.font = UIFont.phantomMonospaced(size: 12, weight: .regular)
            cell.detailTextLabel?.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.6)
            cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 11)

            let item = scriptsList[indexPath.row]
            let src = item["src"] ?? ""
            if !src.isEmpty {
                cell.textLabel?.text = "External: \(src)"
            } else {
                let snippet = item["inlineSnippet"] ?? ""
                let prefix = "Inline: "
                cell.textLabel?.text = snippet.isEmpty ? "<empty script>" : prefix + snippet
            }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if tableView == logsTableView {
            let entry = filteredEntries[indexPath.row]
            let detailVC = WebViewLogDetailVC(entry: entry)
            navigationController?.pushViewController(detailVC, animated: true)
        }
    }
}

#else
internal final class WebViewInspectorVC: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "WebView"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
    }
}
#endif
#endif
