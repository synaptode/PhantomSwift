#if DEBUG
import UIKit

// MARK: - UserDefaultsInspectorVC

/// Full read/write/delete inspector for UserDefaults.standard.
/// Groups entries by type, supports search, tap-to-edit, swipe-to-delete, and JSON export.
internal final class UserDefaultsInspectorVC: PhantomTableVC {

    private var allGroups: [(title: String, entries: [UDEntry])] = []
    private var filteredGroups: [(title: String, entries: [UDEntry])] = []

    private enum UDGroup: String {
        case boolean = "BOOLEAN"
        case string  = "STRING"
        case number  = "NUMBER"
        case array   = "ARRAY"
        case dict    = "DICTIONARY"
        case other   = "OTHER"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UserDefaults Inspector"

        if #available(iOS 13.0, *) {
            let app = UINavigationBarAppearance()
            app.configureWithOpaqueBackground()
            app.backgroundColor = PhantomTheme.shared.backgroundColor
            app.titleTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold)
            ]
            navigationController?.navigationBar.standardAppearance = app
            navigationController?.navigationBar.scrollEdgeAppearance = app
        }
        navigationController?.navigationBar.tintColor = UIColor.Phantom.neonAzure

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Done", style: .done, target: self, action: #selector(close))

        let exportBtn: UIBarButtonItem
        if #available(iOS 13.0, *) {
            exportBtn = UIBarButtonItem(
                image: UIImage(systemName: "square.and.arrow.up"),
                style: .plain, target: self, action: #selector(exportJSON))
        }
        else {
            exportBtn = UIBarButtonItem(title: "Export", style: .plain, target: self, action: #selector(exportJSON))
        }
        let addBtn: UIBarButtonItem
        if #available(iOS 13.0, *) {
            addBtn = UIBarButtonItem(
                image: UIImage(systemName: "plus.circle.fill"),
                style: .plain, target: self, action: #selector(addKey))
            addBtn.tintColor = UIColor.Phantom.vibrantGreen
        }
        else {
            addBtn = UIBarButtonItem(title: "+", style: .plain, target: self, action: #selector(addKey))
        }

        navigationItem.rightBarButtonItems = [exportBtn, addBtn]

        tableView.register(UDToggleCell.self, forCellReuseIdentifier: "UDToggleCell")
        tableView.register(UDValueCell.self, forCellReuseIdentifier: "UDValueCell")
        searchBar.placeholder = "Search keys…"
        searchBar.delegate = self

        loadDefaults()
    }

    // MARK: - Data Loading

    private func loadDefaults() {
        let dict = UserDefaults.standard.dictionaryRepresentation()
        var booleans: [UDEntry] = []
        var strings: [UDEntry] = []
        var numbers: [UDEntry] = []
        var arrays: [UDEntry] = []
        var dicts: [UDEntry] = []
        var others: [UDEntry] = []

        for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
            let entry = UDEntry(key: key, value: value)
            switch entry.type {
            case .boolean:    booleans.append(entry)
            case .string:     strings.append(entry)
            case .number:     numbers.append(entry)
            case .array:      arrays.append(entry)
            case .dictionary: dicts.append(entry)
            case .other:      others.append(entry)
            }
        }

        allGroups = [
            (UDGroup.boolean.rawValue, booleans),
            (UDGroup.string.rawValue, strings),
            (UDGroup.number.rawValue, numbers),
            (UDGroup.array.rawValue, arrays),
            (UDGroup.dict.rawValue, dicts),
            (UDGroup.other.rawValue, others),
        ].filter { !$0.entries.isEmpty }

        applySearch(query: currentSearchQuery)
    }

    private var currentSearchQuery: String = ""

    private func applySearch(query: String) {
        currentSearchQuery = query
        if query.isEmpty {
            filteredGroups = allGroups
        } else {
            filteredGroups = allGroups.compactMap { group in
                let matched = group.entries.filter {
                    $0.key.localizedCaseInsensitiveContains(query) ||
                    $0.displayValue.localizedCaseInsensitiveContains(query)
                }
                return matched.isEmpty ? nil : (group.title, matched)
            }
        }
        tableView.reloadData()
    }

    // MARK: - UITableView DataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        filteredGroups.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredGroups[section].entries.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let group = filteredGroups[section]
        return "\(group.title)  (\(group.entries.count))"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let entry = filteredGroups[indexPath.section].entries[indexPath.row]
        if entry.type == .boolean {
            let cell = tableView.dequeueReusableCell(withIdentifier: "UDToggleCell", for: indexPath) as! UDToggleCell
            cell.configure(entry: entry) { newValue in
                UserDefaults.standard.set(newValue, forKey: entry.key)
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "UDValueCell", for: indexPath) as! UDValueCell
            cell.configure(entry: entry)
            return cell
        }
    }

    // MARK: - UITableView Delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let entry = filteredGroups[indexPath.section].entries[indexPath.row]
        guard entry.type == .string || entry.type == .number else {
            // Copy for non-editable types
            UIPasteboard.general.string = entry.displayValue
            showToast("Copied!")
            return
        }
        showEditAlert(for: entry)
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let entry = filteredGroups[indexPath.section].entries[indexPath.row]

        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            UserDefaults.standard.removeObject(forKey: entry.key)
            self?.loadDefaults()
            done(true)
        }
        if #available(iOS 13.0, *) {
            delete.image = UIImage(systemName: "trash.fill")
        }

        let copy = UIContextualAction(style: .normal, title: "Copy") { [weak self] _, _, done in
            UIPasteboard.general.string = entry.displayValue
            self?.showToast("Copied!")
            done(true)
        }
        copy.backgroundColor = UIColor.Phantom.neonAzure
        if #available(iOS 13.0, *) {
            copy.image = UIImage(systemName: "doc.on.doc.fill")
        }

        return UISwipeActionsConfiguration(actions: [delete, copy])
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    // MARK: - Actions

    @objc private func close() { dismiss(animated: true) }

    @objc private func exportJSON() {
        let dict = UserDefaults.standard.dictionaryRepresentation()
        // Convert to JSON-serializable form
        var jsonDict: [String: Any] = [:]
        for (k, v) in dict {
            if JSONSerialization.isValidJSONObject([k: v]) {
                jsonDict[k] = v
            } else {
                jsonDict[k] = "\(v)"
            }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8) else { return }

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("userdefaults_\(Int(Date().timeIntervalSince1970)).json")
        try? json.write(to: tmpURL, atomically: true, encoding: .utf8)

        let ac = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
        if let pop = ac.popoverPresentationController {
            pop.barButtonItem = navigationItem.rightBarButtonItems?.first
        }
        present(ac, animated: true)
    }

    @objc private func addKey() {
        let alert = UIAlertController(title: "Add Key", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Key"; $0.autocorrectionType = .no }
        alert.addTextField { $0.placeholder = "Value (string)" }
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let key = alert.textFields?[0].text, !key.isEmpty else { return }
            let value = alert.textFields?[1].text ?? ""
            UserDefaults.standard.set(value, forKey: key)
            self?.loadDefaults()
            self?.showToast("Added")
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showEditAlert(for entry: UDEntry) {
        let alert = UIAlertController(
            title: "Edit Value",
            message: entry.key,
            preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = entry.displayValue
            tf.autocorrectionType = .no
            tf.keyboardType = entry.type == .number ? .decimalPad : .default
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let text = alert.textFields?[0].text else { return }
            if entry.type == .number, let num = Double(text) {
                UserDefaults.standard.set(num, forKey: entry.key)
            } else {
                UserDefaults.standard.set(text, forKey: entry.key)
            }
            self?.loadDefaults()
            self?.showToast("Saved")
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showToast(_ text: String) {
        let toast = UILabel()
        toast.text = "  \(text)  "
        toast.font = .systemFont(ofSize: 12, weight: .bold)
        toast.textColor = .white
        toast.backgroundColor = UIColor.Phantom.vibrantGreen.withAlphaComponent(0.9)
        toast.layer.cornerRadius = 12
        toast.layer.masksToBounds = true
        toast.textAlignment = .center
        toast.alpha = 0
        view.addSubview(toast)
        toast.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toast.heightAnchor.constraint(equalToConstant: 30),
        ])
        UIView.animate(withDuration: 0.2) { toast.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            UIView.animate(withDuration: 0.3, animations: { toast.alpha = 0 }) { _ in toast.removeFromSuperview() }
        }
    }
}

// MARK: - UISearchBarDelegate

extension UserDefaultsInspectorVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applySearch(query: searchText)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        applySearch(query: "")
    }
}

// MARK: - UDEntry

private struct UDEntry {
    let key: String
    let value: Any
    let type: EntryType
    let displayValue: String

    enum EntryType {
        case boolean, string, number, array, dictionary, other
    }

    init(key: String, value: Any) {
        self.key = key
        self.value = value
        switch value {
        case let b as Bool:
            self.type = .boolean
            self.displayValue = b ? "true" : "false"
        case let s as String:
            self.type = .string
            self.displayValue = s
        case let n as NSNumber:
            self.type = .number
            self.displayValue = n.stringValue
        case let a as [Any]:
            self.type = .array
            if let data = try? JSONSerialization.data(withJSONObject: a, options: .prettyPrinted),
               let str = String(data: data, encoding: .utf8) {
                self.displayValue = str
            } else {
                self.displayValue = "\(a.count) items"
            }
        case let d as [String: Any]:
            self.type = .dictionary
            if let data = try? JSONSerialization.data(withJSONObject: d, options: .prettyPrinted),
               let str = String(data: data, encoding: .utf8) {
                self.displayValue = str
            } else {
                self.displayValue = "\(d.count) keys"
            }
        default:
            self.type = .other
            self.displayValue = "\(value)"
        }
    }
}

// MARK: - UDToggleCell

private final class UDToggleCell: UITableViewCell {

    private let keyLabel = UILabel()
    private let toggle = UISwitch()
    private var onChange: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        keyLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        keyLabel.textColor = .white
        keyLabel.numberOfLines = 2
        keyLabel.lineBreakMode = .byWordWrapping
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(keyLabel)

        toggle.onTintColor = UIColor.Phantom.neonAzure
        toggle.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(toggle)
        toggle.addTarget(self, action: #selector(toggled), for: .valueChanged)

        NSLayoutConstraint.activate([
            keyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            keyLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            keyLabel.trailingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: -8),

            toggle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            toggle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(entry: UDEntry, onChange: @escaping (Bool) -> Void) {
        keyLabel.text = entry.key
        toggle.isOn = entry.displayValue == "true"
        self.onChange = onChange
    }

    @objc private func toggled() { onChange?(toggle.isOn) }
}

// MARK: - UDValueCell

private final class UDValueCell: UITableViewCell {

    private let keyLabel = UILabel()
    private let valueLabel = UILabel()
    private let typeBadge = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        keyLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        keyLabel.textColor = .white
        keyLabel.numberOfLines = 0
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(keyLabel)

        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        valueLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        valueLabel.numberOfLines = 3
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(valueLabel)

        typeBadge.font = UIFont.systemFont(ofSize: 8, weight: .bold)
        typeBadge.textColor = UIColor.Phantom.neonAzure
        typeBadge.backgroundColor = UIColor.Phantom.neonAzure.withAlphaComponent(0.12)
        typeBadge.layer.cornerRadius = 6
        typeBadge.layer.masksToBounds = true
        typeBadge.textAlignment = .center
        typeBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(typeBadge)

        let disc = UIImageView()
        if #available(iOS 13.0, *) {
            disc.image = UIImage(systemName: "chevron.right")
        }
        disc.tintColor = UIColor.white.withAlphaComponent(0.2)
        disc.contentMode = .scaleAspectFit
        disc.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(disc)

        NSLayoutConstraint.activate([
            typeBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            typeBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            typeBadge.heightAnchor.constraint(equalToConstant: 16),
            typeBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),

            keyLabel.topAnchor.constraint(equalTo: typeBadge.bottomAnchor, constant: 4),
            keyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            keyLabel.trailingAnchor.constraint(equalTo: disc.leadingAnchor, constant: -8),

            valueLabel.topAnchor.constraint(equalTo: keyLabel.bottomAnchor, constant: 2),
            valueLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            valueLabel.trailingAnchor.constraint(equalTo: disc.leadingAnchor, constant: -8),
            valueLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            disc.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            disc.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            disc.widthAnchor.constraint(equalToConstant: 12),
            disc.heightAnchor.constraint(equalToConstant: 16),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(entry: UDEntry) {
        keyLabel.text = entry.key
        valueLabel.text = entry.displayValue

        let (typeText, typeColor): (String, UIColor)
        switch entry.type {
        case .string:     (typeText, typeColor) = ("STR", UIColor.Phantom.vibrantGreen)
        case .number:     (typeText, typeColor) = ("NUM", UIColor.Phantom.vibrantOrange)
        case .array:      (typeText, typeColor) = ("ARR", UIColor.Phantom.vibrantPurple)
        case .dictionary: (typeText, typeColor) = ("DICT", UIColor.Phantom.electricIndigo)
        case .other:      (typeText, typeColor) = ("ANY", UIColor.white.withAlphaComponent(0.3))
        default:          (typeText, typeColor) = ("?", UIColor.white.withAlphaComponent(0.3))
        }
        typeBadge.text = "  \(typeText)  "
        typeBadge.textColor = typeColor
        typeBadge.backgroundColor = typeColor.withAlphaComponent(0.1)
    }
}

#endif
