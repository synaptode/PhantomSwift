#if DEBUG
import UIKit
import Security

/// Lists generic password items in the Keychain.
internal final class KeychainInspectorVC: PhantomTableVC {
    private var allItems: [[String: Any]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Keychain"
        loadData()
    }
    
    private func loadData() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let items = result as? [[String: Any]] {
            self.allItems = items
        } else {
            self.allItems = []
        }
        tableView.reloadData()
    }
    
    // MARK: - TableView
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allItems.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "KeychainCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "KeychainCell")
        let item = allItems[indexPath.row]
        
        cell.backgroundColor = .clear
        cell.textLabel?.text = item[kSecAttrAccount as String] as? String ?? "Unknown Account"
        cell.textLabel?.textColor = PhantomTheme.shared.textColor
        cell.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        
        cell.detailTextLabel?.text = "Service: \(item[kSecAttrService as String] as? String ?? "Unknown")"
        cell.detailTextLabel?.textColor = UIColor.Phantom.primary
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let item = allItems[indexPath.row]
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: item[kSecAttrAccount as String] as Any,
                kSecAttrService as String: item[kSecAttrService as String] as Any
            ]
            SecItemDelete(query as CFDictionary)
            loadData()
        }
    }
}
#endif
