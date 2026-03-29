#if DEBUG
import UIKit

/// UI for managing app state snapshots (Capture/Restore).
internal final class SnapshotListVC: PhantomTableVC {
    private var snapshots: [PhantomSnapshot] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "State Snapshots"
        setupNavigation()
        loadData()
    }
    
    private func setupNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(captureSnapshot))
    }
    
    private func loadData() {
        snapshots = PhantomSnapshotManager.shared.getAllSnapshots().sorted(by: { $0.timestamp > $1.timestamp })
        tableView.reloadData()
    }
    
    @objc private func captureSnapshot() {
        let alert = UIAlertController(title: "Save Snapshot", message: "Enter a name for the current state", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "e.g. Ready to Checkout" }
        alert.addAction(UIAlertAction(title: "Capture", style: .default) { _ in
            let name = alert.textFields?.first?.text ?? "New Snapshot"
            _ = PhantomSnapshotManager.shared.saveCurrentState(name: name)
            self.loadData()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - TableView
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return snapshots.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SnapshotCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "SnapshotCell")
        let snapshot = snapshots[indexPath.row]
        
        cell.backgroundColor = .clear
        cell.textLabel?.text = snapshot.name
        cell.textLabel?.textColor = PhantomTheme.shared.textColor
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        cell.detailTextLabel?.text = "Captured: \(formatter.string(from: snapshot.timestamp)) • \(snapshot.userDefaults.count) keys"
        cell.detailTextLabel?.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.6)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let snapshot = snapshots[indexPath.row]
        let alert = UIAlertController(title: "Restore State?", message: "This will overwrite your current UserDefaults with '\(snapshot.name)'.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Restore", style: .destructive) { _ in
            PhantomSnapshotManager.shared.restore(snapshot: snapshot)
            
            let restartAlert = UIAlertController(title: "Restored!", message: "State applied. Please restart the app for full effects.", preferredStyle: .alert)
            restartAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(restartAlert, animated: true)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let id = snapshots[indexPath.row].id
            PhantomSnapshotManager.shared.delete(id: id)
            loadData()
        }
    }
}
#endif
