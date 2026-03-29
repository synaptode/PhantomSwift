#if DEBUG
import UIKit

/// High-fidelity dashboard for UI Performance, tracking SwiftUI renders and UIKit layouts.
internal final class RenderListVC: UIViewController {
    private var events: [PhantomRenderEvent] = []
    private var filteredEvents: [PhantomRenderEvent] = []
    private var currentFilter: PhantomRenderEventType? = nil
    private var timer: Timer?
    
    private let segmentedControl = UISegmentedControl(items: ["ALL", "SWIFTUI", "UIKIT"])
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let statsHeader = UIView()
    private let pauseButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadEvents()
        
        // Start live updates
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.loadEvents()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
    }
    
    private func setupUI() {
        title = "UI PERFORMANCE"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        
        // 1. Navigation Bar
        if #available(iOS 13.0, *) {
            let closeBtn = UIBarButtonItem(image: UIImage(systemName: "xmark.circle.fill"), style: .plain, target: self, action: #selector(dismissS))
            navigationItem.leftBarButtonItem = closeBtn
        } else {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "CLOSE", style: .plain, target: self, action: #selector(dismissS))
        }
        
        let clearBtn: UIBarButtonItem
        if #available(iOS 13.0, *) {
            clearBtn = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(clearStats))
        } else {
            clearBtn = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearStats))
        }
        navigationItem.rightBarButtonItem = clearBtn
        
        // 2. Filter Bar
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        
        if #available(iOS 13.0, *) {
            segmentedControl.selectedSegmentTintColor = PhantomTheme.shared.primaryColor
        } else {
            segmentedControl.tintColor = PhantomTheme.shared.primaryColor
        }
        
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segmentedControl.setTitleTextAttributes([.foregroundColor: PhantomTheme.shared.textColor.withAlphaComponent(0.6)], for: .normal)
        
        // 3. Pause/Record Button
        updatePauseButton()
        pauseButton.addTarget(self, action: #selector(togglePause), for: .touchUpInside)
        
        // 4. Table View
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.register(RenderCardCell.self, forCellReuseIdentifier: "RenderCardCell")
        
        // Layout
        let stack = UIStackView(arrangedSubviews: [segmentedControl, pauseButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        
        view.addSubview(stack)
        view.addSubview(tableView)
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: stack.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func filterChanged() {
        switch segmentedControl.selectedSegmentIndex {
        case 1: currentFilter = .swiftUI
        case 2: currentFilter = .uiKit
        default: currentFilter = nil
        }
        loadEvents()
    }
    
    @objc private func togglePause() {
        PhantomRenderStore.shared.isPaused.toggle()
        updatePauseButton()
    }
    
    private func updatePauseButton() {
        let isPaused = PhantomRenderStore.shared.isPaused
        let title = isPaused ? "RESUME TRACKING" : "PAUSE TRACKING"
        let color: UIColor = isPaused ? UIColor.Phantom.vibrantGreen : UIColor.Phantom.vibrantRed
        
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.baseBackgroundColor = color
            config.title = title
            config.cornerStyle = .capsule
            pauseButton.configuration = config
        } else {
            pauseButton.setTitle(title, for: .normal)
            pauseButton.backgroundColor = color
            pauseButton.setTitleColor(.white, for: .normal)
            pauseButton.layer.cornerRadius = 20
            pauseButton.clipsToBounds = true
        }
    }
    
    @objc private func clearStats() {
        PhantomRenderStore.shared.clear()
        loadEvents()
    }
    
    @objc private func dismissS() {
        dismiss(animated: true)
    }
    
    private func loadEvents() {
        let all = PhantomRenderStore.shared.getAll()
        if let filter = currentFilter {
            filteredEvents = all.filter { $0.type == filter }
        } else {
            filteredEvents = all
        }
        tableView.reloadData()
    }
}

extension RenderListVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredEvents.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "RenderCardCell", for: indexPath) as? RenderCardCell else {
            return UITableViewCell()
        }
        let event = filteredEvents[indexPath.row]
        let maxCount = filteredEvents.first?.count ?? 1
        cell.configure(with: event, maxCount: maxCount)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}

// MARK: - Custom Cell
internal final class RenderCardCell: UITableViewCell {
    private let containerView = UIView()
    private let nameLabel = UILabel()
    private let typeBadge = UIView()
    private let typeLabel = UILabel()
    private let countLabel = UILabel()
    private let intensityBar = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        containerView.backgroundColor = PhantomTheme.shared.surfaceColor
        containerView.layer.cornerRadius = 12
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        
        nameLabel.font = .systemFont(ofSize: 16, weight: .bold)
        nameLabel.textColor = PhantomTheme.shared.textColor
        
        typeBadge.layer.cornerRadius = 4
        typeLabel.font = .systemFont(ofSize: 10, weight: .black)
        typeLabel.textColor = .white
        
        countLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .black)
        
        intensityBar.backgroundColor = PhantomTheme.shared.primaryColor
        intensityBar.layer.cornerRadius = 2
        
        contentView.addSubview(containerView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(typeBadge)
        typeBadge.addSubview(typeLabel)
        containerView.addSubview(countLabel)
        containerView.addSubview(intensityBar)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        typeBadge.translatesAutoresizingMaskIntoConstraints = false
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        intensityBar.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            nameLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -8),
            
            typeBadge.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            typeBadge.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            
            typeLabel.topAnchor.constraint(equalTo: typeBadge.topAnchor, constant: 2),
            typeLabel.bottomAnchor.constraint(equalTo: typeBadge.bottomAnchor, constant: -2),
            typeLabel.leadingAnchor.constraint(equalTo: typeBadge.leadingAnchor, constant: 4),
            typeLabel.trailingAnchor.constraint(equalTo: typeBadge.trailingAnchor, constant: -4),
            
            countLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            countLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            intensityBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            intensityBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            intensityBar.heightAnchor.constraint(equalToConstant: 4)
        ])
    }
    
    private var widthConstraint: NSLayoutConstraint?
    
    func configure(with event: PhantomRenderEvent, maxCount: Int) {
        nameLabel.text = event.viewName
        countLabel.text = "\(event.count)x"
        
        typeLabel.text = event.type.rawValue.uppercased()
        typeBadge.backgroundColor = event.type == .swiftUI ? UIColor.Phantom.neonAzure : UIColor.Phantom.vibrantOrange
        
        countLabel.textColor = event.count > (maxCount / 2) ? UIColor.Phantom.vibrantRed : PhantomTheme.shared.textColor
        
        // Intensity Bar Width
        widthConstraint?.isActive = false
        let ratio = max(0.01, min(1.0, CGFloat(event.count) / CGFloat(maxCount)))
        widthConstraint = intensityBar.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: ratio)
        widthConstraint?.isActive = true
        
        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }
    }
}
#endif
