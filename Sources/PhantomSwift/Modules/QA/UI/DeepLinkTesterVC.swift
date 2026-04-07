#if DEBUG
import UIKit

// MARK: - DeepLinkEntry

private struct DeepLinkEntry {
    let urlString: String

    var url: URL? { URL(string: urlString) }
    var scheme: String? { url?.scheme }
    var host: String? { url?.host }

    var displayHost: String {
        if let h = host { return h }
        if let s = scheme { return "\(s)://" }
        return urlString
    }

    var displayPath: String? {
        guard let u = url else { return nil }
        var parts: [String] = []
        let p = u.path
        if !p.isEmpty, p != "/" { parts.append(p) }
        if let q = u.query     { parts.append("?\(q)") }
        if let f = u.fragment  { parts.append("#\(f)") }
        return parts.isEmpty ? nil : parts.joined()
    }

    var accentColor: UIColor {
        guard let s = scheme else { return UIColor.Phantom.neonAzure }
        switch s {
        case "https":                return UIColor.Phantom.neonAzure
        case "http":                 return UIColor.Phantom.vibrantOrange
        case "tel", "sms":          return UIColor.Phantom.vibrantGreen
        case "facetime", "mailto":  return UIColor.Phantom.vibrantGreen
        default:                    return UIColor.Phantom.vibrantPurple
        }
    }

    var sfSymbol: String {
        guard let s = scheme else { return "link" }
        switch s {
        case "https", "http":  return "globe"
        case "tel":            return "phone.fill"
        case "sms":            return "message.fill"
        case "facetime":       return "video.fill"
        case "mailto":         return "envelope.fill"
        case "maps":           return "map.fill"
        default:               return "arrow.up.right.square.fill"
        }
    }
}

// MARK: - DeepLinkTesterVC

internal final class DeepLinkTesterVC: UIViewController {

    private let historyKey = "com.phantomswift.deeplink.history"
    private let maxHistory = 100

    // MARK: State

    private var history:  [DeepLinkEntry] = []
    private var filtered: [DeepLinkEntry] = []
    private var isFiltering: Bool { !(searchController.searchBar.text?.isEmpty ?? true) }

    // MARK: UI

    private let tableView        = UITableView(frame: .zero, style: .plain)
    private let searchController = UISearchController(searchResultsController: nil)
    private let inputBar         = URLInputBar()
    private let emptyState       = DeepLinkEmptyState()
    private var inputBarBottom: NSLayoutConstraint!

    private static let cellID = "DLCell"

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Deep Link Tester"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        loadHistory()
        setupNav()
        setupSearch()
        setupTable()
        setupInputBar()
        setupEmptyState()
        registerKeyboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        phantomApplyNavBarAppearance(tintColor: UIColor.Phantom.neonAzure)
        updateEmptyState()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Appearance

    // MARK: Setup

    private func setupNav() {
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "trash"),
                style: .plain, target: self, action: #selector(clearHistoryTapped)
            )
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Clear", style: .plain, target: self, action: #selector(clearHistoryTapped)
            )
        }
        navigationItem.rightBarButtonItem?.tintColor = UIColor.Phantom.vibrantRed
    }

    private func setupSearch() {
        searchController.searchResultsUpdater             = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder            = "Filter history\u{2026}"
        searchController.searchBar.tintColor              = UIColor.Phantom.neonAzure
        searchController.searchBar.barStyle               = .black
        if #available(iOS 13.0, *) {
            searchController.searchBar.searchTextField.backgroundColor = UIColor.white.withAlphaComponent(0.06)
            searchController.searchBar.searchTextField.textColor       = PhantomTheme.shared.textColor
            searchController.searchBar.searchTextField.leftView?.tintColor = UIColor.white.withAlphaComponent(0.3)
            searchController.searchBar.searchTextField.attributedPlaceholder = NSAttributedString(
                string: "Filter history\u{2026}",
                attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.3)]
            )
        }
        navigationItem.searchController        = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
        definesPresentationContext = true
    }

    private func setupTable() {
        tableView.backgroundColor   = .clear
        tableView.separatorStyle    = .none
        tableView.dataSource        = self
        tableView.delegate          = self
        tableView.register(DeepLinkCell.self, forCellReuseIdentifier: Self.cellID)
        tableView.rowHeight          = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        tableView.keyboardDismissMode = .interactive
        tableView.contentInset = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        if #available(iOS 15.0, *) { tableView.sectionHeaderTopPadding = 0 }
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupInputBar() {
        inputBar.onLaunch = { [weak self] urlString in self?.launch(urlString: urlString) }
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputBar)

        inputBarBottom = inputBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        NSLayoutConstraint.activate([
            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBar.heightAnchor.constraint(equalToConstant: 74),
            inputBarBottom,
            tableView.bottomAnchor.constraint(equalTo: inputBar.topAnchor),
        ])
    }

    private func setupEmptyState() {
        emptyState.translatesAutoresizingMaskIntoConstraints = false
        emptyState.isHidden = true
        view.addSubview(emptyState)
        NSLayoutConstraint.activate([
            emptyState.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyState.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            emptyState.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -80),
        ])
    }

    private func updateEmptyState() {
        let isEmpty = filtered.isEmpty
        emptyState.isHidden = !isEmpty
        tableView.isHidden  = isEmpty
        if isEmpty {
            emptyState.configure(
                icon:     isFiltering ? "magnifyingglass" : "link.badge.plus",
                title:    isFiltering ? "No Matches"      : "No History Yet",
                subtitle: isFiltering
                    ? "No entries match your filter query."
                    : "Paste or type any URL scheme above and tap Launch."
            )
        }
    }

    // MARK: Keyboard

    private func registerKeyboard() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(kbShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(kbHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }

    @objc private func kbShow(_ n: Notification) {
        guard let info     = n.userInfo,
              let kbFrame  = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        inputBarBottom.constant = -(kbFrame.height - view.safeAreaInsets.bottom)
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
    }

    @objc private func kbHide(_ n: Notification) {
        guard let duration = n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        inputBarBottom.constant = 0
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
    }

    // MARK: Launch

    private func launch(urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let hasScheme = trimmed.hasPrefix("http") || trimmed.contains("://")
        let resolved  = hasScheme ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: resolved) else {
            showAlert("Invalid URL", "\"" + trimmed + "\" is not a valid URL.")
            return
        }
        addToHistory(trimmed)
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { [weak self] success in
                if !success {
                    self?.showAlert("Cannot Open", "The URL was valid but could not be opened.\n\nCheck the target app is installed and its scheme is registered.")
                }
            }
        } else {
            showAlert("Cannot Open URL", "No app is registered to handle:\n" + url.absoluteString + "\n\nFor Universal Links, the app must be installed.")
        }
    }

    private func showAlert(_ title: String, _ message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    // MARK: History

    private func loadHistory() {
        let raw = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
        history  = raw.map { DeepLinkEntry(urlString: $0) }
        filtered = history
    }

    private func addToHistory(_ urlString: String) {
        history.removeAll { $0.urlString == urlString }
        history.insert(DeepLinkEntry(urlString: urlString), at: 0)
        if history.count > maxHistory { history = Array(history.prefix(maxHistory)) }
        UserDefaults.standard.set(history.map { $0.urlString }, forKey: historyKey)
        applyFilter(query: searchController.searchBar.text)
    }

    @objc private func clearHistoryTapped() {
        guard !history.isEmpty else { return }
        let a = UIAlertController(
            title: "Clear History",
            message: "Remove all \(history.count) saved links?",
            preferredStyle: .alert
        )
        a.addAction(UIAlertAction(title: "Clear All", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.history.removeAll()
            UserDefaults.standard.removeObject(forKey: self.historyKey)
            self.applyFilter(query: nil)
        })
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(a, animated: true)
    }

    private func applyFilter(query: String?) {
        let q = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        filtered = q.isEmpty
            ? history
            : history.filter { $0.urlString.localizedCaseInsensitiveContains(q) }
        tableView.reloadData()
        updateEmptyState()
    }
}

// MARK: - UISearchResultsUpdating

extension DeepLinkTesterVC: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        applyFilter(query: searchController.searchBar.text)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension DeepLinkTesterVC: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filtered.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !filtered.isEmpty else { return nil }
        let wrapper = UIView()
        wrapper.backgroundColor = PhantomTheme.shared.backgroundColor
        let label = UILabel()
        label.text      = isFiltering ? "RESULTS (\(filtered.count))" : "HISTORY (\(filtered.count))"
        label.font      = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = UIColor.white.withAlphaComponent(0.3)
        label.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 20),
            label.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
        ])
        return wrapper
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        filtered.isEmpty ? 0 : 32
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellID, for: indexPath) as? DeepLinkCell else {
            return UITableViewCell()
        }
        let entry = filtered[indexPath.row]
        cell.configure(entry: entry) { [weak self] in
            self?.launch(urlString: entry.urlString)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        inputBar.setText(filtered[indexPath.row].urlString)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let entry = filtered[indexPath.row]

        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            guard let self = self else { return done(false) }
            self.history.removeAll { $0.urlString == entry.urlString }
            UserDefaults.standard.set(self.history.map { $0.urlString }, forKey: self.historyKey)
            self.applyFilter(query: self.searchController.searchBar.text)
            done(true)
        }
        if #available(iOS 13.0, *) { delete.image = UIImage(systemName: "trash.fill") }

        let copy = UIContextualAction(style: .normal, title: "Copy") { _, _, done in
            UIPasteboard.general.string = entry.urlString
            done(true)
        }
        copy.backgroundColor = UIColor.Phantom.neonAzure
        if #available(iOS 13.0, *) { copy.image = UIImage(systemName: "doc.on.doc.fill") }

        let launch = UIContextualAction(style: .normal, title: "Launch") { [weak self] _, _, done in
            self?.launch(urlString: entry.urlString)
            done(true)
        }
        launch.backgroundColor = UIColor.Phantom.vibrantPurple
        if #available(iOS 13.0, *) { launch.image = UIImage(systemName: "paperplane.fill") }

        return UISwipeActionsConfiguration(actions: [delete, copy, launch])
    }
}

// MARK: - DeepLinkCell

private final class DeepLinkCell: UITableViewCell {

    private let card        = UIView()
    private let accentStrip = UIView()
    private let iconBg      = UIView()
    private let iconView    = UIImageView()
    private let schemePill  = UILabel()
    private let hostLabel   = UILabel()
    private let pathLabel   = UILabel()
    private let launchBtn   = UIButton(type: .system)
    private var onLaunch: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        buildLayout()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildLayout() {
        backgroundColor = .clear
        selectionStyle  = .none

        card.backgroundColor    = PhantomTheme.shared.surfaceColor
        card.layer.cornerRadius = 14
        card.clipsToBounds      = true
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        accentStrip.layer.cornerRadius = 2
        accentStrip.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(accentStrip)

        iconBg.layer.cornerRadius = 11
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconBg)

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

        if #available(iOS 13.0, *) {
            schemePill.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .semibold)
        } else {
            schemePill.font = UIFont(name: "Menlo", size: 10) ?? .systemFont(ofSize: 10, weight: .semibold)
        }
        schemePill.layer.cornerRadius = 5
        schemePill.clipsToBounds      = true
        schemePill.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(schemePill)

        hostLabel.font          = .systemFont(ofSize: 14, weight: .semibold)
        hostLabel.textColor     = UIColor.white.withAlphaComponent(0.92)
        hostLabel.numberOfLines = 1
        hostLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(hostLabel)

        if #available(iOS 13.0, *) {
            pathLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        } else {
            pathLabel.font = UIFont(name: "Menlo", size: 11) ?? .systemFont(ofSize: 11)
        }
        pathLabel.textColor     = UIColor.white.withAlphaComponent(0.36)
        pathLabel.numberOfLines = 1
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(pathLabel)

        if #available(iOS 13.0, *) {
            let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            launchBtn.setImage(UIImage(systemName: "paperplane.fill", withConfiguration: cfg), for: .normal)
        } else {
            launchBtn.setTitle("Go", for: .normal)
        }
        launchBtn.layer.cornerRadius = 14
        launchBtn.clipsToBounds      = true
        launchBtn.addTarget(self, action: #selector(launchTapped), for: .touchUpInside)
        launchBtn.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(launchBtn)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),

            accentStrip.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            accentStrip.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            accentStrip.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            accentStrip.widthAnchor.constraint(equalToConstant: 3),

            iconBg.leadingAnchor.constraint(equalTo: accentStrip.trailingAnchor, constant: 12),
            iconBg.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 38),
            iconBg.heightAnchor.constraint(equalToConstant: 38),

            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),

            launchBtn.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            launchBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            launchBtn.widthAnchor.constraint(equalToConstant: 40),
            launchBtn.heightAnchor.constraint(equalToConstant: 40),

            schemePill.topAnchor.constraint(equalTo: card.topAnchor, constant: 13),
            schemePill.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 10),

            hostLabel.leadingAnchor.constraint(equalTo: schemePill.trailingAnchor, constant: 6),
            hostLabel.centerYAnchor.constraint(equalTo: schemePill.centerYAnchor),
            hostLabel.trailingAnchor.constraint(lessThanOrEqualTo: launchBtn.leadingAnchor, constant: -10),

            pathLabel.topAnchor.constraint(equalTo: schemePill.bottomAnchor, constant: 4),
            pathLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 10),
            pathLabel.trailingAnchor.constraint(lessThanOrEqualTo: launchBtn.leadingAnchor, constant: -10),
            pathLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -13),
        ])
    }

    func configure(entry: DeepLinkEntry, onLaunch: @escaping () -> Void) {
        self.onLaunch = onLaunch
        let c = entry.accentColor

        accentStrip.backgroundColor = c.withAlphaComponent(0.8)
        iconBg.backgroundColor      = c.withAlphaComponent(0.12)

        if #available(iOS 13.0, *) {
            let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            iconView.image = UIImage(systemName: entry.sfSymbol, withConfiguration: cfg)
        }
        iconView.tintColor = c

        if let scheme = entry.scheme {
            schemePill.text            = " \(scheme) "
            schemePill.backgroundColor = c.withAlphaComponent(0.18)
            schemePill.textColor       = c
        } else {
            schemePill.text            = nil
            schemePill.backgroundColor = .clear
        }

        hostLabel.text = entry.displayHost

        if let path = entry.displayPath {
            pathLabel.text     = path
            pathLabel.isHidden = false
        } else {
            pathLabel.isHidden = true
        }

        launchBtn.tintColor       = c
        launchBtn.backgroundColor = c.withAlphaComponent(0.12)
    }

    @objc private func launchTapped() {
        UIView.animate(withDuration: 0.09, animations: {
            self.launchBtn.transform = CGAffineTransform(scaleX: 0.87, y: 0.87)
        }) { _ in
            UIView.animate(withDuration: 0.13) { self.launchBtn.transform = .identity }
        }
        onLaunch?()
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: 0.15) { self.card.alpha = highlighted ? 0.6 : 1 }
    }
}

// MARK: - DeepLinkEmptyState

private final class DeepLinkEmptyState: UIView {

    private let iconView      = UIImageView()
    private let titleLabel    = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor   = UIColor.Phantom.neonAzure.withAlphaComponent(0.35)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        titleLabel.font          = .systemFont(ofSize: 19, weight: .semibold)
        titleLabel.textColor     = UIColor.white.withAlphaComponent(0.5)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        subtitleLabel.font          = .systemFont(ofSize: 13)
        subtitleLabel.textColor     = UIColor.white.withAlphaComponent(0.25)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: topAnchor),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 60),
            iconView.heightAnchor.constraint(equalToConstant: 60),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func configure(icon: String, title: String, subtitle: String) {
        if #available(iOS 13.0, *) {
            let cfg = UIImage.SymbolConfiguration(pointSize: 38, weight: .thin)
            iconView.image = UIImage(systemName: icon, withConfiguration: cfg)
        }
        titleLabel.text    = title
        subtitleLabel.text = subtitle
    }
}

// MARK: - URLInputBar

private final class URLInputBar: UIView {

    var onLaunch: ((String) -> Void)?

    private let container    = UIView()
    private let textField    = UITextField()
    private let launchButton = UIButton(type: .system)
    private let pasteButton  = UIButton(type: .system)
    private let topSep       = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    func setText(_ text: String) {
        textField.text = text
        syncLaunchState()
    }

    private func setup() {
        backgroundColor = PhantomTheme.shared.backgroundColor

        topSep.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        topSep.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topSep)

        container.backgroundColor    = UIColor.white.withAlphaComponent(0.07)
        container.layer.cornerRadius = 16
        container.layer.borderWidth  = 1
        container.layer.borderColor  = UIColor.white.withAlphaComponent(0.1).cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        if #available(iOS 13.0, *) {
            let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            pasteButton.setImage(UIImage(systemName: "doc.on.clipboard", withConfiguration: cfg), for: .normal)
        } else {
            pasteButton.setTitle("Paste", for: .normal)
        }
        pasteButton.tintColor = UIColor.white.withAlphaComponent(0.35)
        pasteButton.addTarget(self, action: #selector(pasteTapped), for: .touchUpInside)
        pasteButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(pasteButton)

        if #available(iOS 13.0, *) {
            textField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        } else {
            textField.font = UIFont(name: "Menlo", size: 13) ?? .systemFont(ofSize: 13)
        }
        textField.autocapitalizationType = .none
        textField.autocorrectionType     = .no
        textField.keyboardType           = .URL
        textField.returnKeyType          = .go
        textField.keyboardAppearance     = .dark
        textField.clearButtonMode        = .whileEditing
        textField.textColor              = UIColor.white.withAlphaComponent(0.9)
        textField.attributedPlaceholder  = NSAttributedString(
            string: "myapp://path  or  https://example.com",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.22)]
        )
        textField.delegate = self
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        textField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(textField)

        launchButton.setTitle("Launch", for: .normal)
        launchButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        launchButton.backgroundColor  = UIColor.Phantom.neonAzure
        launchButton.setTitleColor(.white, for: .normal)
        launchButton.layer.cornerRadius = 12
        launchButton.alpha = 0.45
        launchButton.addTarget(self, action: #selector(launchTapped), for: .touchUpInside)
        launchButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(launchButton)

        NSLayoutConstraint.activate([
            topSep.topAnchor.constraint(equalTo: topAnchor),
            topSep.leadingAnchor.constraint(equalTo: leadingAnchor),
            topSep.trailingAnchor.constraint(equalTo: trailingAnchor),
            topSep.heightAnchor.constraint(equalToConstant: 1),

            container.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),

            pasteButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            pasteButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            pasteButton.widthAnchor.constraint(equalToConstant: 24),

            launchButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            launchButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            launchButton.heightAnchor.constraint(equalToConstant: 38),
            launchButton.widthAnchor.constraint(equalToConstant: 84),

            textField.leadingAnchor.constraint(equalTo: pasteButton.trailingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: launchButton.leadingAnchor, constant: -8),
            textField.topAnchor.constraint(equalTo: container.topAnchor),
            textField.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    private func syncLaunchState() {
        let hasText = !(textField.text?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
        UIView.animate(withDuration: 0.2) { self.launchButton.alpha = hasText ? 1.0 : 0.45 }
    }

    @objc private func textChanged() { syncLaunchState() }

    @objc private func pasteTapped() {
        guard let str = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !str.isEmpty else { return }
        textField.text = str
        syncLaunchState()
    }

    @objc private func launchTapped() {
        guard let text = textField.text, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        textField.resignFirstResponder()
        UIView.animate(withDuration: 0.08, animations: {
            self.launchButton.transform = CGAffineTransform(scaleX: 0.91, y: 0.91)
        }) { _ in
            UIView.animate(withDuration: 0.14) { self.launchButton.transform = .identity }
        }
        onLaunch?(text)
    }
}

extension URLInputBar: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        launchTapped()
        return true
    }
}
#endif
