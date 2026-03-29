#if DEBUG
import UIKit

/// Displays and manages standard UserDefaults content.
internal final class UserDefaultsVC: PhantomTableVC {
    private var allItems: [(key: String, value: Any)] = []
    private var filteredItems: [(key: String, value: Any)] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "User Defaults"
        setupNavigation()
        setupSearch()
        loadData()
    }
    
    private func setupSearch() {
        let sc = UISearchController(searchResultsController: nil)
        sc.searchResultsUpdater = self
        sc.obscuresBackgroundDuringPresentation = false
        sc.searchBar.placeholder = "Search keys or values..."
        sc.searchBar.applyPhantomStyle()
        navigationItem.searchController = sc
        navigationItem.hidesSearchBarWhenScrolling = false
    }
    
    private func setupNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addItem))
    }
    
    @objc private func addItem() {
        showEditAlert(for: nil)
    }
    
    private func loadData() {
        let defaults = UserDefaults.standard.dictionaryRepresentation()
        allItems = defaults.map { ($0.key, $0.value) }.sorted(by: { $0.key < $1.key })
        filteredItems = allItems
        tableView.reloadData()
    }
    
    // MARK: - TableView
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredItems.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "DefaultCell")
        let item = filteredItems[indexPath.row]
        
        cell.backgroundColor = .clear
        let typeIcon = icon(for: item.value)
        cell.textLabel?.text = "\(typeIcon) \(item.key)"
        cell.textLabel?.textColor = PhantomTheme.shared.textColor
        cell.textLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        
        cell.detailTextLabel?.text = "\(item.value)"
        cell.detailTextLabel?.textColor = PhantomTheme.shared.primaryColor
        cell.detailTextLabel?.font = UIFont.phantomMonospaced(size: 11, weight: .regular)
        cell.detailTextLabel?.numberOfLines = 2
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let key = filteredItems[indexPath.row].key
            UserDefaults.standard.removeObject(forKey: key)
            loadData()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = filteredItems[indexPath.row]
        showEditAlert(for: item)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    private func showEditAlert(for item: (key: String, value: Any)?) {
        let title = item == nil ? "Add Item" : "Edit Value"
        let alert = UIAlertController(title: title, message: "Enter key and value", preferredStyle: .alert)
        
        alert.addTextField { tf in
            tf.placeholder = "Key"
            tf.text = item?.key
            tf.isEnabled = (item == nil)
        }
        
        alert.addTextField { tf in
            tf.placeholder = "Value (String, Int, or Bool)"
            if let val = item?.value {
                tf.text = "\(val)"
            }
        }
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            guard let key = alert.textFields?[0].text, !key.isEmpty,
                  let value = alert.textFields?[1].text else { return }
            
            // Basic type inference
            if let intVal = Int(value) {
                UserDefaults.standard.set(intVal, forKey: key)
            } else if value.lowercased() == "true" {
                UserDefaults.standard.set(true, forKey: key)
            } else if value.lowercased() == "false" {
                UserDefaults.standard.set(false, forKey: key)
            } else {
                UserDefaults.standard.set(value, forKey: key)
            }
            
            self.loadData()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func icon(for value: Any) -> String {
        if value is String { return "📄" }
        if value is Int || value is Double || value is Float { return "🔢" }
        if value is Bool { return "🔘" }
        if value is Data { return "📦" }
        if value is [Any] || value is [AnyHashable: Any] { return "📁" }
        return "❓"
    }
}

extension UserDefaultsVC: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text, !text.isEmpty else {
            filteredItems = allItems
            tableView.reloadData()
            return
        }
        
        filteredItems = allItems.filter { 
            $0.key.lowercased().contains(text.lowercased()) || 
            "\($0.value)".lowercased().contains(text.lowercased())
        }
        tableView.reloadData()
    }
}
#endif
