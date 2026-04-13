#if DEBUG
import UIKit

/// Lists all loaded Objective-C classes with search and navigation to detail.
internal final class RuntimeBrowserVC: UIViewController {

    // MARK: - State

    private var allClassNames: [String] = []
    private var filteredClassNames: [String] = []
    private var isLoading = false

    // MARK: - UI

    private let tableView = UITableView(frame: .zero, style: .plain)

    // Custom dark search field — replaces UISearchBar to avoid default white background
    private let searchContainer = UIView()
    private let searchField     = UITextField()
    private let searchIconView  = UIImageView()
    private let clearButton     = UIButton(type: .system)

    private let activityIndicator: UIActivityIndicatorView = {
        if #available(iOS 13.0, *) {
            return UIActivityIndicatorView(style: .large)
        } else {
            return UIActivityIndicatorView(style: .whiteLarge)
        }
    }()
    private let statsLabel = UILabel()
    private let emptyView = PhantomEmptyStateView(
        emoji: "🔬",
        title: "No Classes Found",
        message: "Try a different search term."
    )

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        setupNavigationBar()
        setupSearch()
        setupStats()
        setupTable()
        setupEmpty()
        loadClassesAsync()
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        title = "Runtime Browser"
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = PhantomTheme.shared.backgroundColor
            appearance.shadowColor = .clear
            appearance.titleTextAttributes = [
                .foregroundColor: PhantomTheme.shared.textColor,
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
            ]
            navigationController?.navigationBar.standardAppearance   = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
            navigationController?.navigationBar.compactAppearance    = appearance
            navigationController?.navigationBar.tintColor = PhantomTheme.shared.primaryColor

            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "arrow.clockwise"),
                style: .plain, target: self, action: #selector(refresh)
            )
        } else {
            navigationController?.navigationBar.barTintColor = PhantomTheme.shared.backgroundColor
            navigationController?.navigationBar.tintColor    = PhantomTheme.shared.primaryColor
            navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: PhantomTheme.shared.textColor]
            navigationController?.navigationBar.shadowImage = UIImage()
            navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Refresh", style: .plain, target: self, action: #selector(refresh)
            )
        }
    }

    private func setupSearch() {
        // Container — pill-shaped dark card
        searchContainer.backgroundColor  = PhantomTheme.shared.surfaceColor
        searchContainer.layer.cornerRadius = 14
        if #available(iOS 13.0, *) { searchContainer.layer.cornerCurve = .continuous }
        searchContainer.layer.borderWidth = 1
        searchContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchContainer)

        // Magnifying glass icon
        if #available(iOS 13.0, *) {
            searchIconView.image = UIImage(systemName: "magnifyingglass")
        } else {
            searchIconView.image = nil
        }
        searchIconView.tintColor    = UIColor.white.withAlphaComponent(0.35)
        searchIconView.contentMode  = .scaleAspectFit
        searchIconView.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchIconView)

        // Text field — fully transparent, inherits container background
        searchField.font                  = .systemFont(ofSize: 15, weight: .regular)
        searchField.textColor             = PhantomTheme.shared.textColor
        searchField.backgroundColor       = .clear
        searchField.autocorrectionType    = .no
        searchField.autocapitalizationType = .none
        searchField.returnKeyType         = .search
        searchField.keyboardAppearance    = .dark
        searchField.attributedPlaceholder = NSAttributedString(
            string: "Search class name…",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.3)]
        )
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchField)

        // Clear button (× icon, hidden by default)
        if #available(iOS 13.0, *) {
            clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        } else {
            clearButton.setTitle("✕", for: .normal)
            clearButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        }
        clearButton.tintColor  = UIColor.white.withAlphaComponent(0.35)
        clearButton.isHidden   = true
        clearButton.addTarget(self, action: #selector(clearSearch), for: .touchUpInside)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(clearButton)

        // Activity spinner (centered on screen while loading)
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color            = PhantomTheme.shared.primaryColor
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            searchContainer.heightAnchor.constraint(equalToConstant: 48),

            searchIconView.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 14),
            searchIconView.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchIconView.widthAnchor.constraint(equalToConstant: 18),
            searchIconView.heightAnchor.constraint(equalToConstant: 18),

            searchField.leadingAnchor.constraint(equalTo: searchIconView.trailingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -6),
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 36),

            clearButton.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -12),
            clearButton.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 26),
            clearButton.heightAnchor.constraint(equalToConstant: 26),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func setupStats() {
        statsLabel.font          = .systemFont(ofSize: 11, weight: .semibold)
        statsLabel.textColor     = UIColor.white.withAlphaComponent(0.3)
        statsLabel.textAlignment = .center
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statsLabel)
    }

    private func setupTable() {
        tableView.backgroundColor   = .clear
        tableView.separatorColor    = UIColor.white.withAlphaComponent(0.06)
        tableView.separatorInset    = UIEdgeInsets(top: 0, left: 66, bottom: 0, right: 0)
        tableView.register(RuntimeClassCell.self, forCellReuseIdentifier: RuntimeClassCell.reuseID)
        tableView.dataSource        = self
        tableView.delegate          = self
        tableView.rowHeight         = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
        tableView.tableFooterView   = UIView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            statsLabel.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 8),
            statsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statsLabel.heightAnchor.constraint(equalToConstant: 16),

            tableView.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 6),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupEmpty() {
        emptyView.isHidden = true
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyView)
        NSLayoutConstraint.activate([
            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    // MARK: - Data Loading

    private func loadClassesAsync() {
        guard !isLoading else { return }
        isLoading = true
        activityIndicator.startAnimating()
        tableView.isHidden  = true
        statsLabel.isHidden = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let names = PhantomRuntimeInspector.shared.allClassNames()
            DispatchQueue.main.async {
                self.allClassNames      = names
                self.filteredClassNames = names
                self.isLoading = false
                self.activityIndicator.stopAnimating()
                self.tableView.isHidden  = false
                self.statsLabel.isHidden = false
                self.updateStats()
                self.tableView.reloadData()
                self.updateEmptyState()
                // Subtle fade-in
                self.tableView.alpha = 0
                UIView.animate(withDuration: 0.3) { self.tableView.alpha = 1 }
            }
        }
    }

    @objc private func refresh() {
        PhantomRuntimeInspector.shared.clearCache()
        allClassNames = []
        filteredClassNames = []
        tableView.reloadData()
        loadClassesAsync()
    }

    // MARK: - Search actions

    @objc private func searchChanged() {
        let query = searchField.text ?? ""
        clearButton.isHidden = query.isEmpty
        applyFilter(query)
    }

    @objc private func clearSearch() {
        searchField.text = ""
        clearButton.isHidden = true
        searchField.resignFirstResponder()
        applyFilter("")
    }

    // MARK: - Filtering

    private func applyFilter(_ query: String) {
        if query.isEmpty {
            filteredClassNames = allClassNames
        } else {
            let q = query.lowercased()
            filteredClassNames = allClassNames.filter { $0.lowercased().contains(q) }
        }
        updateStats()
        tableView.reloadData()
        updateEmptyState()
    }

    private func updateStats() {
        let total = allClassNames.count
        let shown = filteredClassNames.count
        if total == 0 {
            statsLabel.text = "Loading…"
        } else if shown == total {
            statsLabel.text = "\(total) classes loaded"
        } else {
            statsLabel.text = "\(shown) of \(total) classes"
        }
    }

    private func updateEmptyState() {
        emptyView.isHidden = !filteredClassNames.isEmpty || isLoading
    }
}

// MARK: - UITableViewDataSource & Delegate

extension RuntimeBrowserVC: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredClassNames.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: RuntimeClassCell.reuseID, for: indexPath) as? RuntimeClassCell
        else { return UITableViewCell() }
        cell.configure(className: filteredClassNames[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let name = filteredClassNames[indexPath.row]
        let detailVC = ClassDetailVC(className: name)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension RuntimeBrowserVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - RuntimeClassCell

private final class RuntimeClassCell: UITableViewCell {
    static let reuseID = "RuntimeClassCell"

    private let prefixBadge  = UILabel()
    private let classLabel   = UILabel()   // simple class name (after last ".")
    private let moduleLabel  = UILabel()   // module prefix (before last "."), dimmed
    private let chevron      = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear
        selectionStyle  = .none

        let highlight = UIView()
        highlight.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        selectedBackgroundView = highlight

        // ── Prefix badge ───────────────────────────────────────────────────
        prefixBadge.font              = .systemFont(ofSize: 8, weight: .black)
        prefixBadge.textAlignment     = .center
        prefixBadge.layer.cornerRadius = 10
        prefixBadge.layer.masksToBounds = true
        prefixBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(prefixBadge)

        // ── Class name (main, bold) ────────────────────────────────────────
        classLabel.font          = UIFont.phantomMonospaced(size: 13, weight: .semibold)
        classLabel.textColor     = UIColor.white.withAlphaComponent(0.92)
        classLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(classLabel)

        // ── Module label (small, dimmed) ───────────────────────────────────
        moduleLabel.font          = .systemFont(ofSize: 10, weight: .regular)
        moduleLabel.textColor     = UIColor.white.withAlphaComponent(0.32)
        moduleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(moduleLabel)

        // ── Chevron ────────────────────────────────────────────────────────
        if #available(iOS 13.0, *) {
            let config = PhantomSymbolConfig(pointSize: 10, weight: .medium)
            chevron.image = UIImage.phantomSymbol("chevron.right", config: config)
        }
        chevron.tintColor   = UIColor.white.withAlphaComponent(0.18)
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(chevron)

        NSLayoutConstraint.activate([
            prefixBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            prefixBadge.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            prefixBadge.widthAnchor.constraint(equalToConstant: 40),
            prefixBadge.heightAnchor.constraint(equalToConstant: 22),

            chevron.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 10),

            classLabel.leadingAnchor.constraint(equalTo: prefixBadge.trailingAnchor, constant: 12),
            classLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            classLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),

            moduleLabel.leadingAnchor.constraint(equalTo: classLabel.leadingAnchor),
            moduleLabel.trailingAnchor.constraint(equalTo: classLabel.trailingAnchor),
            moduleLabel.topAnchor.constraint(equalTo: classLabel.bottomAnchor, constant: 2),
            moduleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    func configure(className: String) {
        // Split "Module.ClassName" → module / simple name
        let parts      = className.split(separator: ".", maxSplits: 1)
        let simpleName: String
        let moduleName: String

        if parts.count == 2 {
            moduleName = String(parts[0])
            simpleName = String(parts[1])
        } else {
            moduleName = ""
            simpleName = className
        }

        classLabel.text  = simpleName.isEmpty ? className : simpleName
        moduleLabel.text = moduleName
        moduleLabel.isHidden = moduleName.isEmpty

        let (prefix, color) = Self.prefixInfo(for: simpleName.isEmpty ? className : simpleName)
        prefixBadge.text            = prefix
        prefixBadge.backgroundColor = color.withAlphaComponent(0.18)
        prefixBadge.textColor       = color
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: 0.15) { self.contentView.alpha = highlighted ? 0.55 : 1 }
    }

    private static func prefixInfo(for name: String) -> (String, UIColor) {
        if name.hasPrefix("UI")      { return ("UI",  UIColor.Phantom.neonAzure) }
        if name.hasPrefix("NS")      { return ("NS",  UIColor.Phantom.vibrantOrange) }
        if name.hasPrefix("CA")      { return ("CA",  UIColor.Phantom.vibrantPurple) }
        if name.hasPrefix("CL")      { return ("CL",  UIColor.Phantom.vibrantGreen) }
        if name.hasPrefix("AV")      { return ("AV",  UIColor.Phantom.vibrantRed) }
        if name.hasPrefix("WK")      { return ("WK",  UIColor.Phantom.neonAzure) }
        if name.hasPrefix("SK")      { return ("SK",  UIColor.Phantom.vibrantPurple) }
        if name.hasPrefix("MK")      { return ("MK",  UIColor.Phantom.vibrantGreen) }
        if name.hasPrefix("Phantom") { return ("PH",  UIColor.Phantom.electricIndigo) }
        if name.hasPrefix("_")       { return ("PRV", UIColor.systemGray) }
        let prefix = String(name.prefix(2)).uppercased()
        return (prefix, UIColor.systemGray)
    }
}
#endif
