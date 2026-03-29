#if DEBUG
import UIKit
import SQLite3

/// A generic inspector for SQLite databases.
internal final class SQLiteInspectorVC: PhantomTableVC {
    private let fileURL: URL
    
    private var tables: [String] = []
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = fileURL.lastPathComponent
        setupUI()
        loadTables()
    }
    
    private func setupUI() {
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        
        // PhantomTableVC handles layout
    }
    
    private func loadTables() {
        var db: OpaquePointer?
        if sqlite3_open(fileURL.path, &db) == SQLITE_OK {
            let query = "SELECT name FROM sqlite_master WHERE type='table';"
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    if let name = sqlite3_column_text(statement, 0) {
                        tables.append(String(cString: name))
                    }
                }
            }
            sqlite3_finalize(statement)
        }
        sqlite3_close(db)
        tableView.reloadData()
    }
    
    // MARK: - TableView Overrides
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tables.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TableCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "TableCell")
        cell.backgroundColor = .clear
        cell.textLabel?.text = tables[indexPath.row]
        cell.textLabel?.textColor = PhantomTheme.shared.textColor
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // In a real implementation, we would open a TableContentViewerVC
        let tableName = tables[indexPath.row]
        let alert = UIAlertController(title: "Table Selected", message: "Viewing '\(tableName)' content is coming in the next update!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
#endif
