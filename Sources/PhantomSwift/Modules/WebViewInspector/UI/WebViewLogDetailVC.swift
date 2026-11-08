#if DEBUG
import UIKit

/// Detail view controller displaying the full payload of a WKWebView log or bridge message.
internal final class WebViewLogDetailVC: UIViewController {
    private let entry: PhantomWebViewLogEntry
    private let codeView = PhantomCodeView()
    private let copyButton = UIButton(type: .system)
    private let metaLabel = UILabel()

    init(entry: PhantomWebViewLogEntry) {
        self.entry = entry
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = entry.kind.title
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        setupUI()
        populate()
    }

    private func setupUI() {
        metaLabel.numberOfLines = 0
        metaLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        metaLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.7)
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(metaLabel)

        copyButton.setTitle("Copy Payload", for: .normal)
        copyButton.setTitleColor(.white, for: .normal)
        copyButton.backgroundColor = PhantomTheme.shared.primaryColor
        copyButton.layer.cornerRadius = 8
        copyButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        copyButton.addTarget(self, action: #selector(didTapCopy), for: .touchUpInside)
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(copyButton)

        codeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(codeView)

        NSLayoutConstraint.activate([
            metaLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            metaLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            metaLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            codeView.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 12),
            codeView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            codeView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            codeView.bottomAnchor.constraint(equalTo: copyButton.topAnchor, constant: -12),

            copyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            copyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            copyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            copyButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func populate() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timeStr = formatter.string(from: entry.timestamp)

        var meta = "Time: \(timeStr)\nType: \(entry.kind.title)"
        if let url = entry.sourceURL, !url.isEmpty {
            meta += "\nURL: \(url)"
        }
        if let pageTitle = entry.pageTitle, !pageTitle.isEmpty {
            meta += "\nTitle: \(pageTitle)"
        }
        metaLabel.text = meta

        codeView.text = entry.payload
    }

    @objc private func didTapCopy() {
        UIPasteboard.general.string = entry.payload
        copyButton.setTitle("Copied!", for: .normal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.copyButton.setTitle("Copy Payload", for: .normal)
        }
    }
}
#endif
