#if DEBUG
import UIKit

/// A premium dashboard to configure and test bad network conditions.
internal final class BadNetworkDashboardVC: PhantomTableVC {
    
    private var headerContainer: UIView?
    private let masterSwitch = UISwitch()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Network Simulation"
        setupHeader()
        
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged), name: PhantomNetworkSimulator.stateChangedNotification, object: nil)
    }
    
    @objc private func stateChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.masterSwitch.isOn = PhantomNetworkSimulator.shared.isEnabled
            self.tableView.reloadData()
            self.updateHeaderStyle()
        }
    }
    
    private func setupHeader() {
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = .clear
        
        let container = UIView()
        container.backgroundColor = PhantomTheme.shared.surfaceColor
        container.layer.cornerRadius = 16
        PhantomTheme.shared.applyPremiumShadow(to: container.layer)
        headerView.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        self.headerContainer = container
        
        let label = UILabel()
        label.text = "Simulation Master"
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textColor = PhantomTheme.shared.textColor
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        masterSwitch.isOn = PhantomNetworkSimulator.shared.isEnabled
        masterSwitch.onTintColor = PhantomTheme.shared.primaryColor
        masterSwitch.addTarget(self, action: #selector(toggleMaster(_:)), for: .valueChanged)
        container.addSubview(masterSwitch)
        masterSwitch.translatesAutoresizingMaskIntoConstraints = false
        
        // Body constraints for headerView
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 12),
            container.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -12),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            masterSwitch.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            masterSwitch.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        tableView.tableHeaderView = headerView
        
        // Fix header view size for UITableView
        headerView.layoutIfNeeded()
        let headerSize = headerView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        headerView.frame.size.height = max(headerSize.height, 84)
        
        updateHeaderStyle()
    }
    
    private func updateHeaderStyle() {
        guard let container = headerContainer else { return }
        UIView.animate(withDuration: 0.3) { [weak self] in
            guard let self = self else { return }
            container.layer.borderWidth = self.masterSwitch.isOn ? 2 : 0
            container.layer.borderColor = PhantomTheme.shared.primaryColor.withAlphaComponent(0.5).cgColor
        }
    }
    
    @objc private func toggleMaster(_ sender: UISwitch) {
        PhantomNetworkSimulator.shared.isEnabled = sender.isOn
        // Pulse animation
        UIView.animate(withDuration: 0.1, animations: {
            sender.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }) { [weak sender] _ in
            UIView.animate(withDuration: 0.1) {
                sender?.transform = .identity
            }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "PremiumNetCell")
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        let container = UIView()
        container.backgroundColor = PhantomTheme.shared.surfaceColor
        container.layer.cornerRadius = 12
        container.clipsToBounds = true
        container.isUserInteractionEnabled = false
        PhantomTheme.shared.applyPremiumShadow(to: container.layer)
        cell.contentView.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = PhantomTheme.shared.primaryColor
        iconView.isUserInteractionEnabled = false
        container.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = PhantomTheme.shared.textColor
        titleLabel.numberOfLines = 1
        titleLabel.isUserInteractionEnabled = false
        
        let detailLabel = UILabel()
        detailLabel.font = .systemFont(ofSize: 12, weight: .regular)
        detailLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.6)
        detailLabel.numberOfLines = 1
        detailLabel.isUserInteractionEnabled = false
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.distribution = .fillEqually
        stack.isUserInteractionEnabled = false
        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
            container.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
            container.heightAnchor.constraint(equalToConstant: 70),
            
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            
            stack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
        
        let config = PhantomNetworkSimulator.shared
        let isEnabled = config.isEnabled
        container.alpha = (isEnabled || indexPath.row == 3) ? 1.0 : 0.5
        
        switch indexPath.row {
        case 0:
            titleLabel.text = "3G (High Latency)"
            detailLabel.text = "Adds 2.0s delay"
            iconView.image = UIImage.phantomSymbol("antenna.radiowaves.left.and.right")
            container.layer.borderWidth = (config.latency == 2.0 && isEnabled) ? 2 : 0
        case 1:
            titleLabel.text = "Edge (Very High Latency)"
            detailLabel.text = "Adds 5.0s delay"
            iconView.image = UIImage.phantomSymbol("slowmo")
            container.layer.borderWidth = (config.latency == 5.0 && isEnabled) ? 2 : 0
        case 2:
            titleLabel.text = "Blocked (Packet Loss)"
            detailLabel.text = "100% loss"
            iconView.image = UIImage.phantomSymbol("xmark.octagon.fill")
            container.layer.borderWidth = (config.errorRate == 1.0 && isEnabled) ? 2 : 0
        case 3:
            titleLabel.text = "Reset to Normal"
            detailLabel.text = "Clear simulation"
            iconView.image = UIImage.phantomSymbol("arrow.counterclockwise")
            titleLabel.textColor = UIColor.Phantom.success
            iconView.tintColor = UIColor.Phantom.success
            container.layer.borderWidth = 0
        default: break
        }
        
        container.layer.borderColor = PhantomTheme.shared.primaryColor.cgColor
        
        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 86
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard PhantomNetworkSimulator.shared.isEnabled || indexPath.row == 3 else { return }
        
        let config = PhantomNetworkSimulator.shared
        switch indexPath.row {
        case 0: 
            config.latency = 2.0
            config.errorRate = 0
        case 1: 
            config.latency = 5.0
            config.errorRate = 0
        case 2: 
            config.latency = 0
            config.errorRate = 1.0
        case 3: 
            config.latency = 0
            config.errorRate = 0
            config.isEnabled = false
        default: break
        }
        
        // Visual feedback with safe animation
        if let cell = tableView.cellForRow(at: indexPath) {
            UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseInOut, animations: {
                cell.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            }, completion: { _ in
                UIView.animate(withDuration: 0.15) {
                    cell.transform = .identity
                }
            })
        }
        
        tableView.reloadData()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
#endif
