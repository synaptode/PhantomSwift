#if DEBUG
import UIKit

// MARK: - MockoonCardView

private final class MockoonCardView: UIView, UITextFieldDelegate {
    var onConfigChange: ((MockoonConfig) -> Void)?
    private var config: MockoonConfig = PhantomInterceptor.shared.mockoonConfig

    private let statusDot       = UIView()
    private let titleLabel      = UILabel()
    private let subtitleLabel   = UILabel()
    private let toggleSwitch    = UISwitch()
    private let divider1        = UIView()
    private let hostLabel       = UILabel()
    private let portLabel       = UILabel()
    private let hostField       = UITextField()
    private let portField       = UITextField()
    private let divider2        = UIView()
    private let excludeLabel    = UILabel()
    private let excludeField    = UITextField()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = PhantomTheme.shared.surfaceColor
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor

        // Status dot
        statusDot.layer.cornerRadius = 5
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusDot)

        // Title
        titleLabel.text = "Mockoon Server"
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = PhantomTheme.shared.textColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Toggle
        toggleSwitch.onTintColor = PhantomTheme.shared.primaryColor
        toggleSwitch.isOn = config.isEnabled
        toggleSwitch.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        toggleSwitch.translatesAutoresizingMaskIntoConstraints = false
        addSubview(toggleSwitch)

        // Subtitle
        subtitleLabel.text = "Redirect all traffic to local mock server"
        subtitleLabel.font = .systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        // Divider 1
        divider1.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        divider1.translatesAutoresizingMaskIntoConstraints = false
        addSubview(divider1)

        // Host / Port
        hostLabel.text = "HOST"
        styleInputLabel(hostLabel)
        portLabel.text = "PORT"
        styleInputLabel(portLabel)

        styleTextField(hostField, placeholder: "localhost", text: config.host)
        hostField.autocorrectionType = .no
        hostField.autocapitalizationType = .none
        hostField.delegate = self

        styleTextField(portField, placeholder: "3000", text: "\(config.port)")
        portField.keyboardType = .numberPad
        portField.delegate = self

        // Divider 2
        divider2.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        divider2.translatesAutoresizingMaskIntoConstraints = false
        addSubview(divider2)

        // Exclude patterns
        excludeLabel.text = "SKIP PATTERNS"
        styleInputLabel(excludeLabel)

        styleTextField(excludeField,
                       placeholder: "e.g. *.analytics.com, */cdn/*",
                       text: config.excludePatterns.joined(separator: ", "))
        excludeField.autocorrectionType = .no
        excludeField.autocapitalizationType = .none
        excludeField.delegate = self

        NSLayoutConstraint.activate([
            // Title row
            statusDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            statusDot.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 10),
            statusDot.heightAnchor.constraint(equalToConstant: 10),

            titleLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggleSwitch.leadingAnchor, constant: -8),

            toggleSwitch.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            toggleSwitch.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggleSwitch.leadingAnchor, constant: -8),

            // Divider 1
            divider1.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            divider1.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            divider1.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            divider1.heightAnchor.constraint(equalToConstant: 1),

            // Host/Port row labels
            hostLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            hostLabel.topAnchor.constraint(equalTo: divider1.bottomAnchor, constant: 10),

            portLabel.leadingAnchor.constraint(equalTo: portField.leadingAnchor),
            portLabel.topAnchor.constraint(equalTo: divider1.bottomAnchor, constant: 10),

            // Host/Port fields
            hostField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            hostField.topAnchor.constraint(equalTo: hostLabel.bottomAnchor, constant: 4),
            hostField.trailingAnchor.constraint(equalTo: portField.leadingAnchor, constant: -12),
            hostField.heightAnchor.constraint(equalToConstant: 40),

            portField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            portField.topAnchor.constraint(equalTo: portLabel.bottomAnchor, constant: 4),
            portField.widthAnchor.constraint(equalToConstant: 88),
            portField.heightAnchor.constraint(equalToConstant: 40),

            // Divider 2
            divider2.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            divider2.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            divider2.topAnchor.constraint(equalTo: hostField.bottomAnchor, constant: 14),
            divider2.heightAnchor.constraint(equalToConstant: 1),

            // Exclude patterns
            excludeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            excludeLabel.topAnchor.constraint(equalTo: divider2.bottomAnchor, constant: 10),

            excludeField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            excludeField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            excludeField.topAnchor.constraint(equalTo: excludeLabel.bottomAnchor, constant: 4),
            excludeField.heightAnchor.constraint(equalToConstant: 40),
            excludeField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])

        updateAppearance()
    }

    private func styleInputLabel(_ label: UILabel) {
        label.font = .systemFont(ofSize: 9, weight: .black)
        label.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.35)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
    }

    private func styleTextField(_ tf: UITextField, placeholder: String, text: String) {
        tf.placeholder = placeholder
        tf.text = text
        tf.backgroundColor = PhantomTheme.shared.backgroundColor
        tf.textColor = PhantomTheme.shared.textColor
        if #available(iOS 13.0, *) {
            tf.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        } else {
            tf.font = UIFont(name: "Menlo", size: 13)
        }
        tf.layer.cornerRadius = 8
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 40))
        tf.leftViewMode = .always
        tf.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tf)
    }

    private func updateAppearance() {
        let isActive = config.isEnabled
        statusDot.backgroundColor = isActive ? .systemGreen : .systemGray
        hostField.alpha = isActive ? 1.0 : 0.45
        portField.alpha = isActive ? 1.0 : 0.45
        excludeField.alpha = isActive ? 1.0 : 0.45
        hostField.isUserInteractionEnabled = isActive
        portField.isUserInteractionEnabled = isActive
        excludeField.isUserInteractionEnabled = isActive
        layer.borderColor = isActive
            ? PhantomTheme.shared.primaryColor.withAlphaComponent(0.3).cgColor
            : UIColor.white.withAlphaComponent(0.08).cgColor
    }

    @objc private func toggleChanged() {
        config.isEnabled = toggleSwitch.isOn
        applyChanges()
    }

    private func applyChanges() {
        updateAppearance()
        onConfigChange?(config)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField === hostField {
            let raw = hostField.text?.trimmingCharacters(in: .whitespaces) ?? ""
            config.host = raw.isEmpty ? "localhost" : raw
            hostField.text = config.host
        } else if textField === portField {
            config.port = Int(portField.text ?? "") ?? 3000
            portField.text = "\(config.port)"
        } else if textField === excludeField {
            let raw = excludeField.text ?? ""
            config.excludePatterns = raw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        applyChanges()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func refresh() {
        config = PhantomInterceptor.shared.mockoonConfig
        toggleSwitch.isOn = config.isEnabled
        hostField.text = config.host
        portField.text = "\(config.port)"
        excludeField.text = config.excludePatterns.joined(separator: ", ")
        updateAppearance()
    }
}

// MARK: - InterceptorListVC

/// Displays a modern, grid-based list of active interception rules.
internal final class InterceptorListVC: UIViewController {
    private var collectionView: UICollectionView
    private var rules: [PhantomInterceptRule] = []
    private let mockoonCard = MockoonCardView()
    
    init() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width, height: 90)
        layout.minimumLineSpacing = 0
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        mockoonCard.refresh()
        loadRules()
    }
    
    private func setupUI() {
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        title = "INTERCEPTOR"

        // Mockoon redirect card
        mockoonCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mockoonCard)
        mockoonCard.onConfigChange = { config in
            PhantomInterceptor.shared.updateMockoon(config)
        }

        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(InterceptorCardCell.self, forCellWithReuseIdentifier: "RuleCell")
        view.addSubview(collectionView)

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mockoonCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            mockoonCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            mockoonCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            collectionView.topAnchor.constraint(equalTo: mockoonCard.bottomAnchor, constant: 12),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupNavigation() {
        if #available(iOS 13.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "plus.circle.fill"), style: .plain, target: self, action: #selector(addNewRule))
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewRule))
        }
    }
    
    private func loadRules() {
        self.rules = PhantomInterceptor.shared.getAll().sorted(by: { $0.createdAt > $1.createdAt })
        self.collectionView.reloadData()
        
        if rules.isEmpty {
            showEmptyState()
        } else {
            hideEmptyState()
        }
    }
    
    private let emptyView = PhantomEmptyStateView(emoji: "🎭", title: "No active rules", message: "Intercept or mock network traffic by adding a rule.")
    
    private func showEmptyState() {
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyView)
        NSLayoutConstraint.activate([
            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50)
        ])
    }
    
    private func hideEmptyState() {
        emptyView.removeFromSuperview()
    }
    
    @objc private func addNewRule() {
        let editor = RuleEditorVC()
        navigationController?.pushViewController(editor, animated: true)
    }
}

extension InterceptorListVC: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return rules.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RuleCell", for: indexPath) as! InterceptorCardCell
        let rule = rules[indexPath.item]
        cell.configure(with: rule)
        
        cell.onToggle = { [weak self] isEnabled in
            PhantomInterceptor.shared.toggle(id: rule.id)
            self?.loadRules()
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let rule = rules[indexPath.item]
        let alert = UIAlertController(title: "Rule Info", message: "Rule: \(rule.rule.typeDisplayName)\nPattern: \(rule.rule.urlPattern)", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Delete Rule", style: .destructive) { [weak self] _ in
            PhantomInterceptor.shared.delete(id: rule.id)
            self?.loadRules()
        })
        
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        present(alert, animated: true)
    }
}

/// A comprehensive editor for creating advanced interception rules.
internal final class RuleEditorVC: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    private let dynamicStack = UIStackView()
    
    private let urlTextField = UITextField()
    private let typeSegment = UISegmentedControl(items: ["Block", "Delay", "Mock", "Redirect"])
    
    // Type-specific views
    private let methodSegment = UISegmentedControl(items: ["ALL", "GET", "POST", "PUT", "DELETE"])
    private let statusTextField = UITextField()
    private let headersCodeView = PhantomCodeView()
    private let delayInput = UITextField()
    private let redirectInput = UITextField()
    private let mockBodyView = PhantomCodeView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        title = "CONFIGURE RULE"
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        // 1. URL Pattern Section
        addSectionTitle("TARGET URL PATTERN", to: stackView)
        urlTextField.placeholder = "e.g. */api/v1/user*"
        styleTextField(urlTextField)
        stackView.addArrangedSubview(urlTextField)
        
        // 2. Action Type Section
        addSectionTitle("INTERCEPTION ACTION", to: stackView)
        typeSegment.selectedSegmentIndex = 0
        typeSegment.applyPhantomStyle()
        typeSegment.addTarget(self, action: #selector(typeChanged), for: .valueChanged)
        stackView.addArrangedSubview(typeSegment)
        
        // 3. Dynamic Inputs
        dynamicStack.axis = .vertical
        dynamicStack.spacing = 24
        stackView.addArrangedSubview(dynamicStack)
        setupDynamicInputs()
        
        // 4. Save Button
        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Activate Interceptor", for: .normal)
        saveButton.backgroundColor = PhantomTheme.shared.primaryColor
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 16
        saveButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        saveButton.addTarget(self, action: #selector(saveRule), for: .touchUpInside)
        saveButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
        stackView.addArrangedSubview(saveButton)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        
        updateVisibleInputs()
    }
    
    private func setupDynamicInputs() {
        methodSegment.selectedSegmentIndex = 0
        methodSegment.applyPhantomStyle()
        
        statusTextField.placeholder = "HTTP Status Code (e.g. 200)"
        statusTextField.keyboardType = .numberPad
        styleTextField(statusTextField)
        
        headersCodeView.isEditable = true
        headersCodeView.text = "{\n  \"Content-Type\": \"application/json\"\n}"
        headersCodeView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        
        delayInput.placeholder = "Delay in seconds (e.g. 2.5)"
        delayInput.keyboardType = .decimalPad
        styleTextField(delayInput)
        
        redirectInput.placeholder = "Destination URL (e.g. https://dev.api.com/...)"
        styleTextField(redirectInput)
        
        mockBodyView.isEditable = true
        mockBodyView.heightAnchor.constraint(equalToConstant: 200).isActive = true
    }
    
    private func addSectionTitle(_ title: String, to stack: UIStackView) {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 10, weight: .black)
        label.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        label.letterSpacing = 1.2
        stack.addArrangedSubview(label)
        stack.setCustomSpacing(8, after: label)
    }
    
    private func styleTextField(_ tf: UITextField) {
        tf.backgroundColor = PhantomTheme.shared.surfaceColor
        tf.textColor = PhantomTheme.shared.textColor
        tf.font = .systemFont(ofSize: 14, weight: .medium)
        tf.layer.cornerRadius = 12
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor.white.withAlphaComponent(0.05).cgColor
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 44))
        tf.leftViewMode = .always
        tf.heightAnchor.constraint(equalToConstant: 48).isActive = true
    }
    
    @objc private func typeChanged() {
        updateVisibleInputs()
    }
    
    private func updateVisibleInputs() {
        dynamicStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        switch typeSegment.selectedSegmentIndex {
        case 1: // Delay
            addSectionTitle("DELAY DURATION", to: dynamicStack)
            dynamicStack.addArrangedSubview(delayInput)
        case 2: // Mock
            addSectionTitle("HTTP METHOD", to: dynamicStack)
            dynamicStack.addArrangedSubview(methodSegment)
            
            addSectionTitle("RESPONSE STATUS", to: dynamicStack)
            dynamicStack.addArrangedSubview(statusTextField)
            
            addSectionTitle("RESPONSE HEADERS (JSON)", to: dynamicStack)
            dynamicStack.addArrangedSubview(headersCodeView)
            
            addSectionTitle("RESPONSE BODY", to: dynamicStack)
            dynamicStack.addArrangedSubview(mockBodyView)
        case 3: // Redirect
            addSectionTitle("REDIRECT DESTINATION", to: dynamicStack)
            dynamicStack.addArrangedSubview(redirectInput)
        default: break
        }
        
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func saveRule() {
        guard let pattern = urlTextField.text, !pattern.isEmpty else { return }
        
        let rule: InterceptRule
        switch typeSegment.selectedSegmentIndex {
        case 0: // Block
            rule = .block(urlPattern: pattern)
        case 1: // Delay
            let seconds = TimeInterval(delayInput.text ?? "2.0") ?? 2.0
            rule = .delay(urlPattern: pattern, seconds: seconds)
        case 2: // Mock
            let method = methodSegment.selectedSegmentIndex == 0 ? nil : methodSegment.titleForSegment(at: methodSegment.selectedSegmentIndex)
            let statusCode = Int(statusTextField.text ?? "200") ?? 200
            
            var headers: [String: String] = [:]
            if let headersData = headersCodeView.text?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: headersData) as? [String: String] {
                headers = json
            }
            
            let body = mockBodyView.text?.data(using: .utf8)
            rule = .mockResponse(urlPattern: pattern, method: method, statusCode: statusCode, headers: headers, body: body)
        case 3: // Redirect
            let destination = redirectInput.text ?? ""
            rule = .redirect(from: pattern, to: destination)
        default:
            return
        }
        
        PhantomInterceptor.shared.add(rule: rule)
        navigationController?.popViewController(animated: true)
    }
}
#endif
