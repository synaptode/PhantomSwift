#if DEBUG
import UIKit

/// Main navigation hub for storage inspection with a modern card-based dashboard.
internal final class StorageListVC: UIViewController {
    private let collectionView: UICollectionView
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    private struct StorageItem {
        let title: String
        let subtitle: String
        let icon: String
        let color: UIColor
        let action: () -> Void
    }
    
    private var items: [StorageItem] = []
    
    internal init() {
        let layout = UICollectionViewFlowLayout()
        let width = (UIScreen.main.bounds.width - 60) / 2
        layout.itemSize = CGSize(width: width, height: 160)
        layout.minimumInteritemSpacing = 20
        layout.minimumLineSpacing = 20
        layout.sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupItems()
    }
    
    private func setupUI() {
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        title = "Storage"
        
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        
        titleLabel.text = "DATA VAULT"
        titleLabel.font = .systemFont(ofSize: 22, weight: .black)
        titleLabel.textColor = PhantomTheme.shared.textColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)
        
        subtitleLabel.text = "Analyze and manage your app's persistent layers"
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(subtitleLabel)
        
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(StorageDashboardCell.self, forCellWithReuseIdentifier: "StorageCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            
            collectionView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupItems() {
        items = [
            StorageItem(
                title: "User Defaults",
                subtitle: "\(UserDefaults.standard.dictionaryRepresentation().count) Keys",
                icon: "person.text.rectangle.fill",
                color: .systemBlue
            ) { [weak self] in
                self?.navigationController?.pushViewController(UserDefaultsVC(), animated: true)
            },
            StorageItem(
                title: "Keychain",
                subtitle: "Secure Items",
                icon: "key.fill",
                color: .systemYellow
            ) { [weak self] in
                self?.navigationController?.pushViewController(KeychainInspectorVC(), animated: true)
            },
            StorageItem(
                title: "Sandbox",
                subtitle: "Local Files",
                icon: "folder.fill",
                color: .systemTeal
            ) { [weak self] in
                self?.navigationController?.pushViewController(SandboxInspectorVC(), animated: true)
            },
            StorageItem(
                title: "Snapshots",
                subtitle: "App States",
                icon: "clock.arrow.2.circlepath",
                color: .systemPurple
            ) { [weak self] in
                self?.navigationController?.pushViewController(SnapshotListVC(), animated: true)
            },
            StorageItem(
                title: "CoreData",
                subtitle: "Entities & Records",
                icon: "cylinder.split.1x2.fill",
                color: UIColor.Phantom.vibrantPurple
            ) { [weak self] in
                self?.navigationController?.pushViewController(CoreDataInspectorVC(), animated: true)
            }
        ]
        collectionView.reloadData()
    }
}

extension StorageListVC: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StorageCell", for: indexPath) as! StorageDashboardCell
        let item = items[indexPath.row]
        cell.configure(title: item.title, subtitle: item.subtitle, icon: item.icon, iconColor: item.color)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        items[indexPath.row].action()
    }
}
#endif
