#if DEBUG
import UIKit

/// Displays a list of accessibility issues detected in the current view.
internal final class AccessibilityDashboardVC: PhantomTableVC {
    private var issues: [AccessibilityIssue] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Accessibility Audit"
        setupNavigation()
        runAudit()
    }
    
    private func setupNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Re-Audit", style: .plain, target: self, action: #selector(runAudit))
    }
    
    @objc private func runAudit() {
        let window = UIApplication.shared.windows.first { $0.isKeyWindow }
        self.issues = PhantomAccessibilityAuditor.shared.audit(window: window)
        self.tableView.reloadData()
        
        if issues.isEmpty {
            // Show empty state
        }
    }
    
    // MARK: - UITableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return issues.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "IssueCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "IssueCell")
        let issue = issues[indexPath.row]
        
        cell.backgroundColor = .clear
        cell.textLabel?.text = issue.message
        cell.textLabel?.textColor = UIColor.Phantom.error
        cell.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        
        let typeString = String(describing: issue.type).capitalized
        cell.detailTextLabel?.text = "Type: \(typeString) | View: \(type(of: issue.view))"
        cell.detailTextLabel?.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.6)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let issue = issues[indexPath.row]
        highlight(view: issue.view)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    private func highlight(view: UIView) {
        let originalColor = view.backgroundColor
        UIView.animate(withDuration: 0.5, animations: {
            view.backgroundColor = UIColor.Phantom.error.withAlphaComponent(0.5)
        }) { _ in
            UIView.animate(withDuration: 0.5) {
                view.backgroundColor = originalColor
            }
        }
    }
}
#endif
