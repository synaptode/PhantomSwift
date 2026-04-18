#if DEBUG
import UIKit
import PhantomSwiftNetworking

/// A visual editor for modifying and mocking network responses.
internal final class PhantomMockEditorVC: UIViewController {
    private let request: PhantomRequest
    private let codeView = PhantomCodeView()
    private let saveButton = UIButton(type: .system)
    
    init(request: PhantomRequest) {
        self.request = request
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadInitialData()
    }
    
    private func setupUI() {
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        title = "Edit & Mock"
        
        codeView.isEditable = true
        view.addSubview(codeView)
        
        saveButton.setTitle("Save as Intercept Rule", for: .normal)
        saveButton.backgroundColor = UIColor.Phantom.primary
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 12
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        saveButton.addTarget(self, action: #selector(saveMock), for: .touchUpInside)
        view.addSubview(saveButton)
        
        codeView.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            codeView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            codeView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            codeView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            
            saveButton.topAnchor.constraint(equalTo: codeView.bottomAnchor, constant: 20),
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func loadInitialData() {
        if let body = request.response?.body, let bodyString = String(data: body, encoding: .utf8) {
            codeView.text = bodyString
        } else {
            codeView.text = "{}"
        }
    }
    
    @objc private func saveMock() {
        guard let text = codeView.text, let data = text.data(using: .utf8) else { return }
        
        // 1. Generate a filename based on URL hash
        let urlString = request.url.absoluteString
        let fileName = "mock_\(abs(urlString.hashValue)).json"
        
        // 2. Save to Sandbox
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            
            // 3. Create and add Intercept Rule
            let rule = InterceptRule.mapLocal(urlPattern: urlString, fileName: fileName)
            PhantomInterceptor.shared.add(rule: rule)
            
            // 4. Show Success and Dismiss
            let alert = UIAlertController(title: "Success", message: "Rule added: Requests to this URL will now be mocked with your edited JSON.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                self.navigationController?.popViewController(animated: true)
            })
            present(alert, animated: true)
            
        } catch {
            let alert = UIAlertController(title: "Error", message: "Failed to save mock file: \(error.localizedDescription)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Clear", style: .destructive))
            present(alert, animated: true)
        }
    }
}
#endif
