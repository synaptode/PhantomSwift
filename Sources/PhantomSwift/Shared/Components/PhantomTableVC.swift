#if DEBUG
import UIKit

/// Base table view controller with shared styling for PhantomSwift.
internal class PhantomTableVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
    internal let tableView = UITableView(frame: .zero, style: .plain)
    internal let searchBar = UISearchBar()
    internal let emptyStateView = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBaseUI()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // No-op if using Auto Layout, but good practice.
    }
    
    private func setupBaseUI() {
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        
        // Search Bar
        searchBar.barStyle = PhantomTheme.shared.currentTheme == .light ? .default : .black
        searchBar.placeholder = "Search..."
        searchBar.setBackgroundImage(UIImage(), for: .any, barMetrics: .default)
        view.addSubview(searchBar)
        
        // Table View
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorColor = PhantomTheme.shared.textColor.withAlphaComponent(0.1)
        tableView.tableFooterView = UIView()
        view.addSubview(tableView)
        
        // Layout
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - UITableViewDataSource
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell()
    }
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    open func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // No-op
    }
    
    open func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}
#endif
