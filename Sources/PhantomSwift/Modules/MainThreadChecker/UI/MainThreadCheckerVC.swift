#if DEBUG
import UIKit

/// Displays main thread violation reports.
internal final class MainThreadCheckerVC: PhantomTableVC {

    private var violations: [PhantomMainThreadChecker.ThreadViolation] = []
    private var filteredViolations: [PhantomMainThreadChecker.ThreadViolation] = []
    private var filterText = ""

    // MARK: - Header

    private let headerContainer = UIView()
    private let countLabel = UILabel()
    private let statusDot = UIView()
    private let clearButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Thread Checker"
        searchBar.delegate = self
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        setupHeader()
        reload()

        // Auto-refresh
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.reload()
        }
    }

    private func setupHeader() {
        headerContainer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 80)

        let card = UIView()
        card.backgroundColor = PhantomTheme.shared.surfaceColor
        card.layer.cornerRadius = 16
        if #available(iOS 13.0, *) { card.layer.cornerCurve = .continuous }
        PhantomTheme.shared.applyPremiumShadow(to: card.layer)
        headerContainer.addSubview(card)
        card.translatesAutoresizingMaskIntoConstraints = false

        statusDot.layer.cornerRadius = 5
        statusDot.backgroundColor = UIColor.Phantom.vibrantGreen
        card.addSubview(statusDot)
        statusDot.translatesAutoresizingMaskIntoConstraints = false

        countLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        countLabel.textColor = PhantomTheme.shared.textColor
        card.addSubview(countLabel)
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        if #available(iOS 13.0, *) {
            clearButton.setImage(UIImage(systemName: "trash"), for: .normal)
            clearButton.tintColor = .white
            clearButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        } else {
            clearButton.setTitle("Clear", for: .normal)
            clearButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        }
        clearButton.setTitleColor(.white, for: .normal)
        clearButton.backgroundColor = UIColor.Phantom.vibrantRed
        clearButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        clearButton.layer.cornerRadius = 14
        clearButton.addTarget(self, action: #selector(clear), for: .touchUpInside)
        card.addSubview(clearButton)
        clearButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 8),
            card.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -8),

            statusDot.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            statusDot.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 10),
            statusDot.heightAnchor.constraint(equalToConstant: 10),

            countLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 8),
            countLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            clearButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            clearButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])

        tableView.tableHeaderView = headerContainer
    }

    // MARK: - Data

    private func reload() {
        violations = PhantomMainThreadChecker.shared.getViolations()
        applyFilter()
        updateHeader()
    }

    private func applyFilter() {
        if filterText.isEmpty {
            filteredViolations = violations
        } else {
            let q = filterText.lowercased()
            filteredViolations = violations.filter {
                $0.className.lowercased().contains(q) ||
                $0.methodName.lowercased().contains(q) ||
                $0.threadName.lowercased().contains(q)
            }
        }
        tableView.reloadData()
    }

    private func updateHeader() {
        let count = violations.count
        countLabel.text = count == 0 ? "No violations detected" : "\(count) violation\(count == 1 ? "" : "s")"
        statusDot.backgroundColor = count == 0 ? UIColor.Phantom.vibrantGreen : UIColor.Phantom.vibrantRed
        clearButton.isHidden = count == 0
    }

    @objc private func clear() {
        PhantomMainThreadChecker.shared.clearViolations()
        reload()
    }

    // MARK: - Table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredViolations.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseID = "ViolationCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseID) as? ViolationCell
            ?? ViolationCell(reuseIdentifier: reuseID)
        cell.configure(with: filteredViolations[indexPath.row])
        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 110
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let violation = filteredViolations[indexPath.row]
        let detail = ViolationDetailVC(violation: violation)
        navigationController?.pushViewController(detail, animated: true)
    }

}

// MARK: - UISearchBarDelegate

extension MainThreadCheckerVC: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterText = searchText
        applyFilter()
    }
}

// MARK: - ViolationCell

private final class ViolationCell: UITableViewCell {

    private let cardView = UIView()
    private let severityBar = UIView()
    private let classLabel = UILabel()
    private let methodLabel = UILabel()
    private let threadLabel = UILabel()
    private let timeLabel = UILabel()

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

        severityBar.backgroundColor = UIColor.Phantom.vibrantRed
        severityBar.layer.cornerRadius = 2
        cardView.addSubview(severityBar)
        severityBar.translatesAutoresizingMaskIntoConstraints = false

        classLabel.font = .systemFont(ofSize: 15, weight: .bold)
        classLabel.textColor = PhantomTheme.shared.textColor
        cardView.addSubview(classLabel)
        classLabel.translatesAutoresizingMaskIntoConstraints = false

        methodLabel.font = .phantomMonospaced(size: 13, weight: .medium)
        methodLabel.textColor = UIColor.Phantom.vibrantOrange
        cardView.addSubview(methodLabel)
        methodLabel.translatesAutoresizingMaskIntoConstraints = false

        threadLabel.font = .systemFont(ofSize: 11, weight: .medium)
        threadLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        cardView.addSubview(threadLabel)
        threadLabel.translatesAutoresizingMaskIntoConstraints = false

        timeLabel.font = .systemFont(ofSize: 10, weight: .medium)
        timeLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.35)
        timeLabel.textAlignment = .right
        cardView.addSubview(timeLabel)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            severityBar.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 8),
            severityBar.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 8),
            severityBar.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -8),
            severityBar.widthAnchor.constraint(equalToConstant: 4),

            classLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            classLabel.leadingAnchor.constraint(equalTo: severityBar.trailingAnchor, constant: 12),
            classLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),

            methodLabel.topAnchor.constraint(equalTo: classLabel.bottomAnchor, constant: 4),
            methodLabel.leadingAnchor.constraint(equalTo: classLabel.leadingAnchor),
            methodLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),

            threadLabel.topAnchor.constraint(equalTo: methodLabel.bottomAnchor, constant: 6),
            threadLabel.leadingAnchor.constraint(equalTo: classLabel.leadingAnchor),
            threadLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),

            timeLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            timeLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
        ])
    }

    func configure(with violation: PhantomMainThreadChecker.ThreadViolation) {
        classLabel.text = violation.className
        methodLabel.text = violation.methodName
        threadLabel.text = "Thread: \(violation.threadName) (#\(violation.threadID))"

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        timeLabel.text = formatter.string(from: violation.timestamp)
    }
}

// MARK: - ViolationDetailVC

private final class ViolationDetailVC: UIViewController {

    private let violation: PhantomMainThreadChecker.ThreadViolation
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    init(violation: PhantomMainThreadChecker.ThreadViolation) {
        self.violation = violation
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Violation Detail"
        view.backgroundColor = PhantomTheme.shared.backgroundColor

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
        ])

        addInfoCard("Class", violation.className)
        addInfoCard("Method", violation.methodName)
        addInfoCard("Thread", "\(violation.threadName) (ID: \(violation.threadID))")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        addInfoCard("Time", formatter.string(from: violation.timestamp))

        addCallStackCard()
    }

    private func addInfoCard(_ title: String, _ value: String) {
        let card = UIView()
        card.backgroundColor = PhantomTheme.shared.surfaceColor
        card.layer.cornerRadius = 12
        if #available(iOS 13.0, *) { card.layer.cornerCurve = .continuous }

        let titleL = UILabel()
        titleL.text = title.uppercased()
        titleL.font = .systemFont(ofSize: 10, weight: .heavy)
        titleL.textColor = PhantomTheme.shared.primaryColor

        let valueL = UILabel()
        valueL.text = value
        valueL.font = .phantomMonospaced(size: 14, weight: .medium)
        valueL.textColor = PhantomTheme.shared.textColor
        valueL.numberOfLines = 0

        card.addSubview(titleL)
        card.addSubview(valueL)
        titleL.translatesAutoresizingMaskIntoConstraints = false
        valueL.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleL.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            titleL.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            valueL.topAnchor.constraint(equalTo: titleL.bottomAnchor, constant: 6),
            valueL.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            valueL.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            valueL.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])

        stackView.addArrangedSubview(card)
    }

    private func addCallStackCard() {
        let card = UIView()
        card.backgroundColor = PhantomTheme.shared.surfaceColor
        card.layer.cornerRadius = 12
        if #available(iOS 13.0, *) { card.layer.cornerCurve = .continuous }

        let titleL = UILabel()
        titleL.text = "CALL STACK"
        titleL.font = .systemFont(ofSize: 10, weight: .heavy)
        titleL.textColor = PhantomTheme.shared.primaryColor

        let stackL = UILabel()
        stackL.text = violation.callStack.joined(separator: "\n")
        stackL.font = .phantomMonospaced(size: 10, weight: .regular)
        stackL.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.7)
        stackL.numberOfLines = 0

        card.addSubview(titleL)
        card.addSubview(stackL)
        titleL.translatesAutoresizingMaskIntoConstraints = false
        stackL.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleL.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            titleL.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stackL.topAnchor.constraint(equalTo: titleL.bottomAnchor, constant: 8),
            stackL.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stackL.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stackL.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])

        stackView.addArrangedSubview(card)
    }
}
#endif
