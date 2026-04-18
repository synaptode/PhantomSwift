#if DEBUG
import UIKit

/// Visualizes tracked objects and highlights potential leaks.
internal final class MemoryGraphVC: PhantomTableVC {
    private var allObjects: [PhantomTrackedObject] = []
    private var filteredObjects: [PhantomTrackedObject] = []
    private var timer: Timer?
    
    private var isSearching: Bool {
        return searchBar.isFirstResponder && !(searchBar.text?.isEmpty ?? true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Memory Graph"
        setupNavigation()
        setupTableView()
        setupSearchBar()
    }
    
    private func setupTableView() {
        tableView.register(MemoryObjectCell.self, forCellReuseIdentifier: "MemoryCell")
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 20, right: 0)
    }
    
    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.placeholder = "Search class or address..."
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startRefreshing()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
    }
    
    private func setupNavigation() {
        let clearDeadItem: UIBarButtonItem
        if #available(iOS 13.0, *) {
            clearDeadItem = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(clearDead))
        } else {
            clearDeadItem = UIBarButtonItem(title: "Clear Dead", style: .plain, target: self, action: #selector(clearDead))
        }
        navigationItem.rightBarButtonItems = [clearDeadItem]
    }
    
    private func startRefreshing() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshData()
        }
    }
    
    private func refreshData() {
        allObjects = PhantomObjectTracker.shared.trackedObjects.reversed() // Newest first
        updateFiltering()
    }
    
    private func updateFiltering() {
        if let text = searchBar.text?.lowercased(), !text.isEmpty {
            filteredObjects = allObjects.filter { 
                $0.className.lowercased().contains(text) || $0.address.lowercased().contains(text)
            }
        } else {
            filteredObjects = allObjects
        }
        tableView.reloadData()
    }
    
    @objc private func clearDead() {
        PhantomObjectTracker.shared.clearDeallocated()
        refreshData()
    }
    
    // MARK: - TableView
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredObjects.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "MemoryCell", for: indexPath) as? MemoryObjectCell else {
            return UITableViewCell()
        }
        
        let obj = filteredObjects[indexPath.row]
        cell.configure(with: obj)
        return cell
    }
}

extension MemoryGraphVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateFiltering()
    }
}

// MARK: - Custom UI Components

private final class MemoryObjectCell: UITableViewCell {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let addressBadge = UIView()
    private let addressLabel = UILabel()
    private let statusBadge = UIView()
    private let statusLabel = UILabel()
    private let locationLabel = UILabel()
    private let timeLabel = UILabel()
    private let leakIndicator = UIImageView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        containerView.backgroundColor = PhantomTheme.shared.surfaceColor.withAlphaComponent(0.6)
        containerView.layer.cornerRadius = 16
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        contentView.addSubview(containerView)
        
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = PhantomTheme.shared.textColor
        containerView.addSubview(titleLabel)
        
        addressBadge.backgroundColor = PhantomTheme.shared.textColor.withAlphaComponent(0.05)
        addressBadge.layer.cornerRadius = 6
        containerView.addSubview(addressBadge)
        
        addressLabel.font = UIFont.phantomMonospaced(size: 10, weight: .medium)
        addressLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.6)
        addressBadge.addSubview(addressLabel)
        
        statusBadge.layer.cornerRadius = 6
        containerView.addSubview(statusBadge)
        
        statusLabel.font = .systemFont(ofSize: 10, weight: .black)
        statusLabel.textColor = .white
        statusBadge.addSubview(statusLabel)
        
        locationLabel.font = .systemFont(ofSize: 12, weight: .regular)
        locationLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        containerView.addSubview(locationLabel)
        
        timeLabel.font = .systemFont(ofSize: 10, weight: .medium)
        timeLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.3)
        containerView.addSubview(timeLabel)
        
        leakIndicator.image = UIImage.phantomSymbol("exclamationmark.triangle.fill")
        leakIndicator.tintColor = UIColor.Phantom.vibrantRed
        leakIndicator.isHidden = true
        containerView.addSubview(leakIndicator)
        
        // Layout
        [containerView, titleLabel, addressBadge, addressLabel, statusBadge, statusLabel, locationLabel, timeLabel, leakIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            addressBadge.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            addressBadge.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            
            addressLabel.topAnchor.constraint(equalTo: addressBadge.topAnchor, constant: 2),
            addressLabel.leadingAnchor.constraint(equalTo: addressBadge.leadingAnchor, constant: 6),
            addressLabel.trailingAnchor.constraint(equalTo: addressBadge.trailingAnchor, constant: -6),
            addressLabel.bottomAnchor.constraint(equalTo: addressBadge.bottomAnchor, constant: -2),
            
            statusBadge.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            statusBadge.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            statusLabel.topAnchor.constraint(equalTo: statusBadge.topAnchor, constant: 2),
            statusLabel.leadingAnchor.constraint(equalTo: statusBadge.leadingAnchor, constant: 6),
            statusLabel.trailingAnchor.constraint(equalTo: statusBadge.trailingAnchor, constant: -6),
            statusLabel.bottomAnchor.constraint(equalTo: statusBadge.bottomAnchor, constant: -2),
            
            locationLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            locationLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            locationLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            
            timeLabel.topAnchor.constraint(equalTo: locationLabel.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            timeLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            leakIndicator.centerYAnchor.constraint(equalTo: locationLabel.centerYAnchor),
            leakIndicator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            leakIndicator.widthAnchor.constraint(equalToConstant: 20),
            leakIndicator.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(with obj: PhantomTrackedObject) {
        titleLabel.text = obj.className
        addressLabel.text = obj.address
        locationLabel.text = "📍 \(obj.file):\(obj.line)"
        
        timeLabel.text = "Tracked at \(MemoryObjectCell.dateFormatter.string(from: obj.timestamp))"
        
        let isAlive = obj.object != nil
        if isAlive {
            let isSuspicious = Date().timeIntervalSince(obj.timestamp) > 30
            statusBadge.backgroundColor = isSuspicious ? UIColor.Phantom.vibrantOrange : UIColor.Phantom.vibrantGreen
            statusLabel.text = isSuspicious ? "LEAK?" : "ALIVE"
            leakIndicator.isHidden = !isSuspicious
        } else {
            statusBadge.backgroundColor = UIColor.Phantom.vibrantGray.withAlphaComponent(0.5)
            statusLabel.text = "DEAD"
            leakIndicator.isHidden = true
        }
    }
}
#endif
