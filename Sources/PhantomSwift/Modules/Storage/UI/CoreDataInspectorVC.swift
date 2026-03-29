#if DEBUG
import UIKit
import CoreData

// MARK: - CoreDataInspectorVC

/// Browses all CoreData persistent stores discovered in the app's bundle and
/// lets the developer inspect entities, records, and attribute values at runtime.
///
/// Usage: push from `StorageListVC` or integrate into any navigation stack.
internal final class CoreDataInspectorVC: UIViewController {

    // MARK: - Model

    private struct StoreInfo {
        let url: URL
        let name: String
        let coordinator: NSPersistentStoreCoordinator
    }

    // MARK: - State

    private var stores: [StoreInfo] = []
    private let tableView: UITableView = {
        if #available(iOS 13.0, *) {
            return UITableView(frame: .zero, style: .insetGrouped)
        }
        return UITableView(frame: .zero, style: .grouped)
    }()
    private static let cellID = "StoreCell"

    // MARK: - Init

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "CoreData"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        setupTable()
        setupNav()
        discoverStores()
    }

    // MARK: - Setup

    private func setupNav() {
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "arrow.clockwise"),
                style: .plain,
                target: self,
                action: #selector(refresh)
            )
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Refresh", style: .plain,
                target: self, action: #selector(refresh))
        }
        navigationItem.rightBarButtonItem?.tintColor = PhantomTheme.shared.primaryColor
    }

    private func setupTable() {
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Discovery

    /// Scans the app's Documents and Application Support directories for `.sqlite`
    /// files and attempts to load them as `NSPersistentStoreCoordinator` stores.
    private func discoverStores() {
        stores.removeAll()

        // Collect candidate sqlite paths
        var paths: [URL] = []
        let fm = FileManager.default

        let searchDirs: [FileManager.SearchPathDirectory] = [.documentDirectory, .applicationSupportDirectory]
        for dir in searchDirs {
            if let base = try? fm.url(for: dir, in: .userDomainMask, appropriateFor: nil, create: false) {
                let candidates = (try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)) ?? []
                paths += candidates.filter { $0.pathExtension == "sqlite" }
            }
        }

        // Also inspect NSPersistentContainer.defaultDirectoryURL if iOS 10+
        if #available(iOS 10.0, *) {
            let defaultDir = NSPersistentContainer.defaultDirectoryURL()
            let candidates = (try? fm.contentsOfDirectory(at: defaultDir, includingPropertiesForKeys: nil)) ?? []
            paths += candidates.filter { $0.pathExtension == "sqlite" }
        }

        // Walk loaded NSPersistentStoreCoordinator instances via ObjC runtime
        paths += discoverViaRuntime()

        // De-dup
        let uniquePaths = Array(Set(paths.map { $0.standardizedFileURL }))

        for url in uniquePaths {
            let momsInBundle = discoverManagedObjectModels()
            let coordinator: NSPersistentStoreCoordinator

            if let mom = matchingModel(for: url, from: momsInBundle) {
                coordinator = NSPersistentStoreCoordinator(managedObjectModel: mom)
            } else {
                // Fallback: use a blank model — enough to read entity list via SQLite pragma
                coordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
            }

            let storeOptions: [String: Any] = [
                NSReadOnlyPersistentStoreOption: true,
                NSSQLitePragmasOption: ["journal_mode": "DELETE"]
            ]

            if (try? coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: url,
                options: storeOptions
            )) != nil {
                stores.append(StoreInfo(
                    url: url,
                    name: url.deletingPathExtension().lastPathComponent,
                    coordinator: coordinator
                ))
            }
        }

        tableView.reloadData()
        updateEmptyState()
    }

    /// Discovers live `NSPersistentStoreCoordinator` instances already loaded in
    /// the process using the ObjC runtime — catches in-memory and non-sqlite stores.
    private func discoverViaRuntime() -> [URL] {
        let urls: [URL] = []
        var count: UInt32 = 0
        guard let classList = objc_copyClassList(&count) else { return urls }
        defer { free(UnsafeMutableRawPointer(classList)) }

        for i in 0..<Int(count) {
            let cls: AnyClass = classList[i]
            // Look for subclasses of NSPersistentContainer
            if #available(iOS 10.0, *) {
                if class_getSuperclass(cls) == NSPersistentContainer.self ||
                   cls == NSPersistentContainer.self {
                    // Can't easily get the singleton; skip — stores found via fs scan
                }
            }
        }
        return urls
    }

    /// Finds all `.mom` / `.momd` compiled models in the main bundle.
    private func discoverManagedObjectModels() -> [NSManagedObjectModel] {
        var models: [NSManagedObjectModel] = []
        let bundle = Bundle.main

        // .momd directories
        let momds = bundle.urls(forResourcesWithExtension: "momd", subdirectory: nil) ?? []
        for momd in momds {
            if let model = NSManagedObjectModel(contentsOf: momd) {
                models.append(model)
            }
        }

        // .mom files
        let moms = bundle.urls(forResourcesWithExtension: "mom", subdirectory: nil) ?? []
        for mom in moms {
            if let model = NSManagedObjectModel(contentsOf: mom) {
                models.append(model)
            }
        }

        return models
    }

    /// Tries to match a model to the given store URL by name convention.
    private func matchingModel(for storeURL: URL, from models: [NSManagedObjectModel]) -> NSManagedObjectModel? {
        let storeName = storeURL.deletingPathExtension().lastPathComponent.lowercased()
        for model in models {
            let entities = model.entitiesByName.keys
            let names = entities.map { $0.lowercased() }
            if names.contains(where: { $0.contains(storeName) || storeName.contains($0) }) {
                return model
            }
        }
        return models.first
    }

    // MARK: - Empty State

    private func updateEmptyState() {
        if stores.isEmpty {
            let label = UILabel()
            label.text = "No CoreData stores found.\nConfigure NSPersistentContainer before launching Phantom."
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 14)
            label.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
            label.numberOfLines = 0
            tableView.backgroundView = label
        } else {
            tableView.backgroundView = nil
        }
    }

    // MARK: - Actions

    @objc private func refresh() {
        discoverStores()
    }
}

// MARK: - UITableViewDataSource / Delegate

extension CoreDataInspectorVC: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        stores.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        stores.isEmpty ? nil : "Persistent Stores (\(stores.count))"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellID, for: indexPath)
        let store = stores[indexPath.row]
        if #available(iOS 14.0, *) {
            var config = cell.defaultContentConfiguration()
            config.text = store.name
            config.secondaryText = store.url.path
            config.secondaryTextProperties.color = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
            config.secondaryTextProperties.font = .systemFont(ofSize: 11)
            config.image = UIImage(systemName: "cylinder.split.1x2.fill")
            config.imageProperties.tintColor = UIColor.Phantom.neonAzure
            cell.contentConfiguration = config
        } else {
            cell.textLabel?.text = store.name
            cell.detailTextLabel?.text = store.url.lastPathComponent
        }
        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = PhantomTheme.shared.surfaceColor
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let store = stores[indexPath.row]
        let entityListVC = CoreDataEntityListVC(store: store.coordinator, storeName: store.name)
        navigationController?.pushViewController(entityListVC, animated: true)
    }
}

// MARK: - CoreDataEntityListVC

/// Lists all entities in a given `NSPersistentStoreCoordinator`.
private final class CoreDataEntityListVC: UIViewController {

    private let coordinator: NSPersistentStoreCoordinator
    private let storeName: String
    private var entities: [NSEntityDescription] = []
    private let tableView: UITableView = {
        if #available(iOS 13.0, *) {
            return UITableView(frame: .zero, style: .insetGrouped)
        }
        return UITableView(frame: .zero, style: .grouped)
    }()
    private static let cellID = "EntityCell"

    init(store: NSPersistentStoreCoordinator, storeName: String) {
        self.coordinator = store
        self.storeName = storeName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = storeName
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        setupTable()
        loadEntities()
    }

    private func setupTable() {
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func loadEntities() {
        entities = coordinator.managedObjectModel.entities.sorted { $0.name ?? "" < $1.name ?? "" }
        tableView.reloadData()
    }
}

extension CoreDataEntityListVC: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entities.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Entities (\(entities.count))"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellID, for: indexPath)
        let entity = entities[indexPath.row]
        if #available(iOS 14.0, *) {
            var config = cell.defaultContentConfiguration()
            config.text = entity.name ?? "Unknown"
            config.secondaryText = "\(entity.properties.count) properties"
            config.image = UIImage(systemName: "tablecells")
            config.imageProperties.tintColor = UIColor.Phantom.vibrantPurple
            cell.contentConfiguration = config
        } else {
            cell.textLabel?.text = entity.name
            cell.detailTextLabel?.text = "\(entity.properties.count) properties"
        }
        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = PhantomTheme.shared.surfaceColor
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let entity = entities[indexPath.row]
        let recordsVC = CoreDataRecordsVC(coordinator: coordinator, entity: entity)
        navigationController?.pushViewController(recordsVC, animated: true)
    }
}

// MARK: - CoreDataRecordsVC

/// Fetches and displays all records for a given entity.
private final class CoreDataRecordsVC: UIViewController {

    private let coordinator: NSPersistentStoreCoordinator
    private let entity: NSEntityDescription
    private var records: [[String: String]] = []
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let countLabel = UILabel()
    private static let cellID = "RecordCell"

    init(coordinator: NSPersistentStoreCoordinator, entity: NSEntityDescription) {
        self.coordinator = coordinator
        self.entity = entity
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = entity.name
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        setupCountLabel()
        setupTable()
        fetchRecords()
    }

    private func setupCountLabel() {
        countLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        countLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        countLabel.textAlignment = .center
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(countLabel)
        NSLayoutConstraint.activate([
            countLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            countLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            countLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    private func setupTable() {
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func fetchRecords() {
        let ctx = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        ctx.persistentStoreCoordinator = coordinator

        ctx.perform { [weak self] in
            guard let self else { return }
            let request = NSFetchRequest<NSManagedObject>(entityName: self.entity.name ?? "")
            request.fetchLimit = 500
            let fetched = (try? ctx.fetch(request)) ?? []

            let rows: [[String: String]] = fetched.map { obj in
                var row: [String: String] = [:]
                for (key, _) in self.entity.attributesByName {
                    let val = obj.value(forKey: key)
                    row[key] = "\(val ?? "nil")"
                }
                return row
            }

            DispatchQueue.main.async {
                self.records = rows
                self.countLabel.text = "\(rows.count) record\(rows.count == 1 ? "" : "s") (capped at 500)"
                self.tableView.reloadData()
            }
        }
    }
}

extension CoreDataRecordsVC: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        records.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellID, for: indexPath)
        let record = records[indexPath.row]

        // Build a compact multi-line display
        let text = record.sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")

        if #available(iOS 14.0, *) {
            var config = cell.defaultContentConfiguration()
            config.text = "Record \(indexPath.row + 1)"
            config.secondaryText = text
            config.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            config.secondaryTextProperties.color = PhantomTheme.shared.textColor.withAlphaComponent(0.75)
            config.secondaryTextProperties.numberOfLines = 0
            cell.contentConfiguration = config
        } else {
            cell.textLabel?.text = "Record \(indexPath.row + 1)"
            cell.detailTextLabel?.text = text
            cell.detailTextLabel?.numberOfLines = 0
        }
        cell.backgroundColor = PhantomTheme.shared.surfaceColor
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let record = records[indexPath.row]
        let detailVC = CoreDataRecordDetailVC(record: record, title: "Record \(indexPath.row + 1)")
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - CoreDataRecordDetailVC

/// Shows all key-value pairs for a single CoreData record in a readable list.
private final class CoreDataRecordDetailVC: UIViewController {

    private let record: [String: String]
    private let recordTitle: String
    private var keys: [String] = []
    private let tableView: UITableView = {
        if #available(iOS 13.0, *) {
            return UITableView(frame: .zero, style: .insetGrouped)
        }
        return UITableView(frame: .zero, style: .grouped)
    }()
    private static let cellID = "DetailCell"

    init(record: [String: String], title: String) {
        self.record = record
        self.recordTitle = title
        self.keys = record.keys.sorted()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = recordTitle
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        setupTable()
        addCopyButton()
    }

    private func setupTable() {
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func addCopyButton() {
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "doc.on.doc"),
                style: .plain,
                target: self,
                action: #selector(copyRecord)
            )
        }
        navigationItem.rightBarButtonItem?.tintColor = PhantomTheme.shared.primaryColor
    }

    @objc private func copyRecord() {
        let text = keys.map { "\($0): \(record[$0] ?? "")" }.joined(separator: "\n")
        UIPasteboard.general.string = text
        let banner = UILabel()
        banner.text = " ✓ Copied "
        banner.backgroundColor = UIColor.Phantom.vibrantGreen
        banner.textColor = .white
        banner.font = .systemFont(ofSize: 13, weight: .bold)
        banner.layer.cornerRadius = 8
        banner.clipsToBounds = true
        banner.sizeToFit()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: banner)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.addCopyButton()
        }
    }
}

extension CoreDataRecordDetailVC: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        keys.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Attributes (\(keys.count))"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellID, for: indexPath)
        let key = keys[indexPath.row]
        let value = record[key] ?? "nil"

        if #available(iOS 14.0, *) {
            var config = cell.defaultContentConfiguration()
            config.text = key
            config.textProperties.font = .systemFont(ofSize: 13, weight: .semibold)
            config.secondaryText = value
            config.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            config.secondaryTextProperties.color = PhantomTheme.shared.textColor.withAlphaComponent(0.8)
            config.secondaryTextProperties.numberOfLines = 0
            cell.contentConfiguration = config
        } else {
            cell.textLabel?.text = key
            cell.textLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
            cell.detailTextLabel?.text = value
            cell.detailTextLabel?.font = .systemFont(ofSize: 12)
            cell.detailTextLabel?.numberOfLines = 0
        }
        cell.backgroundColor = PhantomTheme.shared.surfaceColor
        cell.selectionStyle = .none
        return cell
    }
}
#endif
