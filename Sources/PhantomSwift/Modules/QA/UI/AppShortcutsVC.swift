#if DEBUG
import UIKit

/// Displays a list of user-defined QA shortcuts.
internal final class AppShortcutsVC: PhantomTableVC {
    private var shortcuts: [AppShortcut] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "QA Shortcuts"
        loadShortcuts()
    }
    
    private func loadShortcuts() {
        self.shortcuts = PhantomSwift.shared.config.shortcuts
        if shortcuts.isEmpty {
            let empty = PhantomEmptyStateView(emoji: "⌨️", title: "No Shortcuts", message: "Register shortcuts in PhantomConfig to see them here.")
            tableView.backgroundView = empty
        } else {
            tableView.backgroundView = nil
        }
        tableView.reloadData()
    }
    
    // MARK: - TableView
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return shortcuts.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ShortcutCell") ?? UITableViewCell(style: .default, reuseIdentifier: "ShortcutCell")
        let shortcut = shortcuts[indexPath.row]
        
        cell.backgroundColor = .clear
        cell.textLabel?.text = "⚡️ \(shortcut.title)"
        cell.textLabel?.textColor = PhantomTheme.shared.textColor
        cell.accessoryType = .none
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let shortcut = shortcuts[indexPath.row]
        self.dismiss(animated: true) {
            shortcut.action()
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
#endif
