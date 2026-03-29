#if DEBUG
import UIKit

/// Displays a modern, grid-based gallery of audited assets with memory impact warnings.
internal final class AssetListVC: UIViewController {
    private let collectionView: UICollectionView
    private var allAssets: [PhantomAssetInfo] = []
    private var filteredAssets: [PhantomAssetInfo] = []
    private let searchController = UISearchController(searchResultsController: nil)
    
    private let filterSegment = UISegmentedControl(items: ["All", "Heavy Only"])
    private let refreshButton = UIButton(type: .system)
    
    internal init() {
        let layout = UICollectionViewFlowLayout()
        let width = (UIScreen.main.bounds.width - 60) / 2
        layout.itemSize = CGSize(width: width, height: 180)
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
        setupSearch()
        loadAssets()
    }
    
    private func setupUI() {
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        title = "Asset Auditor"
        
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refreshTapped))
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Refresh", style: .plain, target: self, action: #selector(refreshTapped))
        }
        
        filterSegment.selectedSegmentIndex = 0
        filterSegment.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        filterSegment.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterSegment)
        
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(AssetGridCell.self, forCellWithReuseIdentifier: "AssetCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            filterSegment.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            filterSegment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            filterSegment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            collectionView.topAnchor.constraint(equalTo: filterSegment.bottomAnchor, constant: 12),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupSearch() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search assets..."
        searchController.searchBar.applyPhantomStyle()
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
    }
    
    private func loadAssets() {
        allAssets = PhantomAssetInspector.shared.scanAssets()
        applyFilters()
    }
    
    @objc private func refreshTapped() {
        loadAssets()
        UIView.transition(with: collectionView, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
    }
    
    @objc private func filterChanged() {
        applyFilters()
    }
    
    private func applyFilters() {
        let searchText = searchController.searchBar.text?.lowercased() ?? ""
        let heavyOnly = filterSegment.selectedSegmentIndex == 1
        
        filteredAssets = allAssets.filter { asset in
            let matchesSearch = searchText.isEmpty || asset.name.lowercased().contains(searchText)
            let matchesHeavy = !heavyOnly || asset.size > 300_000 // > 300KB
            return matchesSearch && matchesHeavy
        }
        
        collectionView.reloadData()
        
        if filteredAssets.isEmpty {
            showEmptyState()
        } else {
            hideEmptyState()
        }
    }
    
    private let emptyLabel = UILabel()
    private func showEmptyState() {
        emptyLabel.text = "No assets found.\nTry adding images to your bundle."
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.3)
        emptyLabel.font = .systemFont(ofSize: 14)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func hideEmptyState() {
        emptyLabel.removeFromSuperview()
    }
}

extension AssetListVC: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredAssets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AssetCell", for: indexPath) as! AssetGridCell
        cell.configure(with: filteredAssets[indexPath.row])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset = filteredAssets[indexPath.row]
        let alert = UIAlertController(title: asset.name, message: "Path:\n\(asset.path)\n\nSize: \(ByteCountFormatter.string(fromByteCount: asset.size, countStyle: .file))\nResolution: \(asset.resolution)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        present(alert, animated: true)
    }
}

extension AssetListVC: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        applyFilters()
    }
}
#endif
