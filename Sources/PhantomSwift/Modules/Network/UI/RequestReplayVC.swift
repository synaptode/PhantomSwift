#if DEBUG
import UIKit
import PhantomSwiftNetworking

/// Allows editing and replaying a captured network request with modified headers/body.
internal final class RequestReplayVC: UIViewController {

    private let originalRequest: PhantomRequest
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private let methodField = UITextField()
    private let urlField = UITextField()
    private let headersView = UITextView()
    private let bodyView = UITextView()
    private let responseView = UITextView()
    private let statusLabel = UILabel()
    private let replayButton = UIButton(type: .system)
    private let saveRuleButton = UIButton(type: .system)
    private let spinner: UIActivityIndicatorView = {
        if #available(iOS 13.0, *) {
            return UIActivityIndicatorView(style: .medium)
        } else {
            return UIActivityIndicatorView(style: .white)
        }
    }()

    private var lastResponse: (data: Data?, response: URLResponse?, error: Error?)?

    init(request: PhantomRequest) {
        self.originalRequest = request
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Edit & Replay"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        setupUI()
        populateFields()
    }

    // MARK: - Setup

    private func setupUI() {
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        stackView.axis = .vertical
        stackView.spacing = 16
        scrollView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

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

        // Method
        addSectionHeader("METHOD")
        setupField(methodField, placeholder: "GET")
        methodField.autocapitalizationType = .allCharacters
        stackView.addArrangedSubview(methodField)

        // URL
        addSectionHeader("URL")
        setupField(urlField, placeholder: "https://api.example.com/endpoint")
        urlField.autocapitalizationType = .none
        urlField.keyboardType = .URL
        stackView.addArrangedSubview(urlField)

        // Headers
        addSectionHeader("HEADERS (JSON)")
        setupTextView(headersView, height: 100)
        stackView.addArrangedSubview(headersView)

        // Body
        addSectionHeader("BODY")
        setupTextView(bodyView, height: 120)
        stackView.addArrangedSubview(bodyView)

        // Action buttons
        let btnStack = UIStackView()
        btnStack.axis = .horizontal
        btnStack.spacing = 12
        btnStack.distribution = .fillEqually

        setupButton(replayButton, title: "Replay Request", color: PhantomTheme.shared.primaryColor)
        replayButton.addTarget(self, action: #selector(replay), for: .touchUpInside)
        btnStack.addArrangedSubview(replayButton)

        setupButton(saveRuleButton, title: "Save as Rule", color: UIColor.Phantom.vibrantGreen)
        saveRuleButton.addTarget(self, action: #selector(saveAsRule), for: .touchUpInside)
        saveRuleButton.isHidden = true
        btnStack.addArrangedSubview(saveRuleButton)

        stackView.addArrangedSubview(btnStack)
        btnStack.heightAnchor.constraint(equalToConstant: 48).isActive = true

        // Spinner
        spinner.hidesWhenStopped = true
        spinner.color = PhantomTheme.shared.textColor
        stackView.addArrangedSubview(spinner)

        // Status
        statusLabel.font = .systemFont(ofSize: 13, weight: .bold)
        statusLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.6)
        statusLabel.textAlignment = .center
        statusLabel.isHidden = true
        stackView.addArrangedSubview(statusLabel)

        // Response
        addSectionHeader("RESPONSE")
        setupTextView(responseView, height: 200)
        responseView.isEditable = false
        responseView.text = "Replay a request to see the response."
        stackView.addArrangedSubview(responseView)
    }

    private func populateFields() {
        methodField.text = originalRequest.method
        urlField.text = originalRequest.url.absoluteString

        // Headers as pretty JSON
        if let data = try? JSONSerialization.data(withJSONObject: originalRequest.headers,
                                                   options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            headersView.text = text
        } else {
            headersView.text = "{}"
        }

        // Body
        if let body = originalRequest.body {
            if let jsonObj = try? JSONSerialization.jsonObject(with: body),
               let pretty = try? JSONSerialization.data(withJSONObject: jsonObj, options: .prettyPrinted),
               let text = String(data: pretty, encoding: .utf8) {
                bodyView.text = text
            } else {
                bodyView.text = String(data: body, encoding: .utf8) ?? body.base64EncodedString()
            }
        }
    }

    // MARK: - Actions

    @objc private func replay() {
        guard let urlString = urlField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: urlString) else {
            statusLabel.text = "Invalid URL"
            statusLabel.textColor = UIColor.Phantom.vibrantRed
            statusLabel.isHidden = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = methodField.text ?? "GET"

        // Parse headers
        if let headersText = headersView.text,
           let headersData = headersText.data(using: .utf8),
           let headers = try? JSONSerialization.jsonObject(with: headersData) as? [String: String] {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Body
        if let bodyText = bodyView.text, !bodyText.isEmpty {
            request.httpBody = bodyText.data(using: .utf8)
        }

        // Mark phantom-handled to avoid re-capture
        request.setValue("true", forHTTPHeaderField: "X-Phantom-Replay")

        spinner.startAnimating()
        replayButton.isEnabled = false
        statusLabel.isHidden = true
        responseView.text = "Loading..."

        let session = URLSession(configuration: .ephemeral)
        let startTime = Date()

        session.dataTask(with: request) { [weak self] data, response, error in
            let duration = Date().timeIntervalSince(startTime)
            self?.lastResponse = (data, response, error)

            DispatchQueue.main.async {
                self?.spinner.stopAnimating()
                self?.replayButton.isEnabled = true
                self?.displayResponse(data: data, response: response, error: error, duration: duration)
            }
        }.resume()
    }

    private func displayResponse(data: Data?, response: URLResponse?, error: Error?, duration: TimeInterval) {
        if let error = error {
            responseView.text = "Error: \(error.localizedDescription)"
            statusLabel.text = "Failed"
            statusLabel.textColor = UIColor.Phantom.vibrantRed
            statusLabel.isHidden = false
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            responseView.text = "No HTTP response"
            return
        }

        let statusCode = httpResponse.statusCode
        let durationStr = String(format: "%.0fms", duration * 1000)

        statusLabel.text = "\(statusCode) · \(durationStr)"
        statusLabel.textColor = statusCode < 400 ? UIColor.Phantom.vibrantGreen : UIColor.Phantom.vibrantRed
        statusLabel.isHidden = false
        saveRuleButton.isHidden = false

        var output = "Status: \(statusCode)\nDuration: \(durationStr)\n\n"
        output += "Headers:\n"
        for (key, value) in httpResponse.allHeaderFields {
            output += "  \(key): \(value)\n"
        }

        if let data = data {
            output += "\nBody (\(data.count) bytes):\n"
            if let jsonObj = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: jsonObj, options: .prettyPrinted),
               let text = String(data: pretty, encoding: .utf8) {
                output += text
            } else if let text = String(data: data, encoding: .utf8) {
                output += text
            } else {
                output += "[Binary data: \(data.count) bytes]"
            }
        }

        responseView.text = output
    }

    @objc private func saveAsRule() {
        guard let responseData = lastResponse,
              let httpResp = responseData.response as? HTTPURLResponse,
              let body = responseData.data else { return }

        let headers = Dictionary(uniqueKeysWithValues: httpResp.allHeaderFields.compactMap { key, value -> (String, String)? in
            guard let k = key as? String, let v = value as? String else { return nil }
            return (k, v)
        })

        let replayResponse = PhantomResponse(
            statusCode: httpResp.statusCode,
            headers: headers,
            body: body,
            duration: 0
        )
        let draft = PhantomInterceptorDraft.mock(from: originalRequest, response: replayResponse)
        let editor = RuleEditorVC(draft: draft)
        navigationController?.pushViewController(editor, animated: true)
    }

    // MARK: - UI Helpers

    private func addSectionHeader(_ text: String) {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 10, weight: .heavy)
        label.textColor = PhantomTheme.shared.primaryColor
        stackView.addArrangedSubview(label)
    }

    private func setupField(_ field: UITextField, placeholder: String) {
        field.font = .phantomMonospaced(size: 14, weight: .medium)
        field.textColor = PhantomTheme.shared.textColor
        field.backgroundColor = PhantomTheme.shared.surfaceColor
        field.layer.cornerRadius = 10
        if #available(iOS 13.0, *) { field.layer.cornerCurve = .continuous }
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        field.leftViewMode = .always
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: PhantomTheme.shared.textColor.withAlphaComponent(0.3)]
        )
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true
    }

    private func setupTextView(_ textView: UITextView, height: CGFloat) {
        textView.font = .phantomMonospaced(size: 12, weight: .regular)
        textView.textColor = PhantomTheme.shared.textColor
        textView.backgroundColor = PhantomTheme.shared.surfaceColor
        textView.layer.cornerRadius = 10
        if #available(iOS 13.0, *) { textView.layer.cornerCurve = .continuous }
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: height).isActive = true
    }

    private func setupButton(_ button: UIButton, title: String, color: UIColor) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        button.backgroundColor = color
        button.layer.cornerRadius = 14
        if #available(iOS 13.0, *) { button.layer.cornerCurve = .continuous }
    }
}
#endif
