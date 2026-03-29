#if DEBUG
import UIKit

/// Dashboard for viewing and toggling feature flag overrides at runtime.
internal final class FeatureFlagsDashboardVC: PhantomTableVC {

    private var groups: [(name: String, flags: [PhantomFeatureFlags.FeatureFlag])] = []
    private var filteredGroups: [(name: String, flags: [PhantomFeatureFlags.FeatureFlag])] = []
    private var filterText = ""

    // MARK: - Header

    private let headerContainer = UIView()
    private let overrideCountLabel = UILabel()
    private let resetButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Feature Flags"
        searchBar.delegate = self
        setupHeader()
        reloadFlags()
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
    }

    // MARK: - Setup

    private func setupHeader() {
        headerContainer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 90)

        let card = UIView()
        card.backgroundColor = PhantomTheme.shared.surfaceColor
        card.layer.cornerRadius = 16
        if #available(iOS 13.0, *) { card.layer.cornerCurve = .continuous }
        PhantomTheme.shared.applyPremiumShadow(to: card.layer)
        headerContainer.addSubview(card)
        card.translatesAutoresizingMaskIntoConstraints = false

        overrideCountLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        overrideCountLabel.textColor = PhantomTheme.shared.textColor
        card.addSubview(overrideCountLabel)
        overrideCountLabel.translatesAutoresizingMaskIntoConstraints = false

        resetButton.setTitle("Reset All", for: .normal)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        resetButton.backgroundColor = UIColor.Phantom.vibrantRed
        resetButton.layer.cornerRadius = 14
        resetButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        resetButton.addTarget(self, action: #selector(resetAll), for: .touchUpInside)
        card.addSubview(resetButton)
        resetButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 10),
            card.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -10),

            overrideCountLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            overrideCountLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            resetButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            resetButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])

        tableView.tableHeaderView = headerContainer
    }

    // MARK: - Data

    private func reloadFlags() {
        let grouped = PhantomFeatureFlags.shared.allFlags()
        groups = grouped.keys.sorted().map { (name: $0, flags: grouped[$0] ?? []) }
        applyFilter()
        updateHeader()
    }

    private func applyFilter() {
        if filterText.isEmpty {
            filteredGroups = groups
        } else {
            let q = filterText.lowercased()
            filteredGroups = groups.compactMap { group in
                let matches = group.flags.filter {
                    $0.title.lowercased().contains(q) ||
                    $0.key.lowercased().contains(q) ||
                    $0.description.lowercased().contains(q)
                }
                return matches.isEmpty ? nil : (name: group.name, flags: matches)
            }
        }
        tableView.reloadData()
    }

    private func updateHeader() {
        let count = PhantomFeatureFlags.shared.overrideCount
        overrideCountLabel.text = count > 0 ? "\(count) override\(count == 1 ? "" : "s") active" : "No overrides active"
        overrideCountLabel.textColor = count > 0 ? UIColor.Phantom.vibrantOrange : PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        resetButton.isHidden = count == 0
    }

    // MARK: - Actions

    @objc private func resetAll() {
        PhantomFeatureFlags.shared.resetAll()
        reloadFlags()
    }

    // MARK: - UITableView

    override func numberOfSections(in tableView: UITableView) -> Int {
        return filteredGroups.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredGroups[section].flags.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        let label = UILabel()
        label.text = filteredGroups[section].name.uppercased()
        label.font = .systemFont(ofSize: 11, weight: .heavy)
        label.textColor = PhantomTheme.shared.primaryColor
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 36
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseID = "FeatureFlagCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseID) as? FeatureFlagCell
            ?? FeatureFlagCell(reuseIdentifier: reuseID)
        let flag = filteredGroups[indexPath.section].flags[indexPath.row]
        cell.configure(with: flag)
        cell.onToggle = { [weak self] in
            PhantomFeatureFlags.shared.toggle(flag.key)
            self?.reloadFlags()
        }
        cell.onReset = { [weak self] in
            PhantomFeatureFlags.shared.resetOverride(flag.key)
            self?.reloadFlags()
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
}

// MARK: - UISearchBarDelegate

extension FeatureFlagsDashboardVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterText = searchText
        applyFilter()
    }
}

// MARK: - FeatureFlagCell

private final class FeatureFlagCell: UITableViewCell {

    var onToggle: (() -> Void)?
    var onReset: (() -> Void)?

    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let keyLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let statusBar = UIView()
    private let toggleSwitch = UISwitch()
    private let overrideBadge = UILabel()
    private let defaultLabel = UILabel()
    private let resetBtn = UIButton(type: .system)

    init(reuseIdentifier: String) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        cardView.backgroundColor = PhantomTheme.shared.surfaceColor
        cardView.layer.cornerRadius = 14
        if #available(iOS 13.0, *) { cardView.layer.cornerCurve = .continuous }
        contentView.addSubview(cardView)
        cardView.translatesAutoresizingMaskIntoConstraints = false

        statusBar.layer.cornerRadius = 2
        cardView.addSubview(statusBar)
        statusBar.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = PhantomTheme.shared.textColor
        cardView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        keyLabel.font = .phantomMonospaced(size: 11, weight: .medium)
        keyLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        cardView.addSubview(keyLabel)
        keyLabel.translatesAutoresizingMaskIntoConstraints = false

        descriptionLabel.font = .systemFont(ofSize: 12, weight: .regular)
        descriptionLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.6)
        descriptionLabel.numberOfLines = 0
        cardView.addSubview(descriptionLabel)
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        toggleSwitch.onTintColor = PhantomTheme.shared.primaryColor
        toggleSwitch.addTarget(self, action: #selector(toggled), for: .valueChanged)
        cardView.addSubview(toggleSwitch)
        toggleSwitch.translatesAutoresizingMaskIntoConstraints = false

        overrideBadge.font = .systemFont(ofSize: 9, weight: .black)
        overrideBadge.textColor = .white
        overrideBadge.textAlignment = .center
        overrideBadge.backgroundColor = UIColor.Phantom.vibrantOrange
        overrideBadge.layer.cornerRadius = 8
        overrideBadge.clipsToBounds = true
        overrideBadge.text = "  OVERRIDE  "
        cardView.addSubview(overrideBadge)
        overrideBadge.translatesAutoresizingMaskIntoConstraints = false

        defaultLabel.font = .systemFont(ofSize: 10, weight: .medium)
        defaultLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.35)
        cardView.addSubview(defaultLabel)
        defaultLabel.translatesAutoresizingMaskIntoConstraints = false

        resetBtn.setTitle("Reset", for: .normal)
        resetBtn.titleLabel?.font = .systemFont(ofSize: 11, weight: .semibold)
        resetBtn.setTitleColor(UIColor.Phantom.vibrantRed, for: .normal)
        resetBtn.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        cardView.addSubview(resetBtn)
        resetBtn.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            statusBar.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 8),
            statusBar.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 8),
            statusBar.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -8),
            statusBar.widthAnchor.constraint(equalToConstant: 4),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: statusBar.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggleSwitch.leadingAnchor, constant: -10),

            keyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            keyLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            descriptionLabel.topAnchor.constraint(equalTo: keyLabel.bottomAnchor, constant: 6),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: toggleSwitch.leadingAnchor, constant: -10),

            toggleSwitch.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            toggleSwitch.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),

            overrideBadge.topAnchor.constraint(equalTo: toggleSwitch.bottomAnchor, constant: 6),
            overrideBadge.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            overrideBadge.heightAnchor.constraint(equalToConstant: 16),

            defaultLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 6),
            defaultLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            defaultLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),

            resetBtn.centerYAnchor.constraint(equalTo: defaultLabel.centerYAnchor),
            resetBtn.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
        ])
    }

    func configure(with flag: PhantomFeatureFlags.FeatureFlag) {
        titleLabel.text = flag.title
        keyLabel.text = flag.key
        descriptionLabel.text = flag.description.isEmpty ? nil : flag.description
        descriptionLabel.isHidden = flag.description.isEmpty
        toggleSwitch.isOn = flag.currentValue

        let isOverridden = flag.isOverridden
        overrideBadge.isHidden = !isOverridden
        resetBtn.isHidden = !isOverridden
        defaultLabel.text = "Default: \(flag.defaultValue ? "ON" : "OFF")"

        statusBar.backgroundColor = flag.currentValue ? UIColor.Phantom.vibrantGreen : UIColor.Phantom.vibrantRed.withAlphaComponent(0.5)
    }

    @objc private func toggled() {
        onToggle?()
    }

    @objc private func resetTapped() {
        onReset?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onToggle = nil
        onReset = nil
    }
}
#endif
