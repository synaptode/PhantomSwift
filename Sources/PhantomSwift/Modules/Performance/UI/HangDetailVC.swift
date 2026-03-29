#if DEBUG
import UIKit

/// Displays detailed information about a hang event, including the call stack.
internal final class HangDetailVC: UIViewController {
    private let hang: PhantomHangEvent
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    
    init(hang: PhantomHangEvent) {
        self.hang = hang
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        title = "Hang Details"
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.axis = .vertical
        contentView.spacing = 20
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
        
        setupHeader()
        setupCallStack()
    }
    
    private func setupHeader() {
        let card = UIView()
        card.backgroundColor = PhantomTheme.shared.surfaceColor
        card.layer.cornerRadius = 20
        contentView.addArrangedSubview(card)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        
        let durationLabel = UILabel()
        durationLabel.text = String(format: "%.2fs Freeze", hang.duration)
        durationLabel.font = .systemFont(ofSize: 28, weight: .black)
        durationLabel.textColor = hang.duration > 0.8 ? UIColor.Phantom.vibrantRed : PhantomTheme.shared.textColor
        durationLabel.numberOfLines = 1
        durationLabel.adjustsFontSizeToFitWidth = true
        durationLabel.minimumScaleFactor = 0.7
        stack.addArrangedSubview(durationLabel)
        
        let screenLabel = UILabel()
        screenLabel.text = "Occurred in \(hang.screenName)"
        screenLabel.font = .systemFont(ofSize: 15, weight: .bold)
        screenLabel.textColor = PhantomTheme.shared.primaryColor
        screenLabel.numberOfLines = 0
        screenLabel.lineBreakMode = .byWordWrapping
        stack.addArrangedSubview(screenLabel)
        
        let timeLabel = UILabel()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        timeLabel.text = formatter.string(from: hang.timestamp)
        timeLabel.font = .systemFont(ofSize: 12, weight: .medium)
        timeLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        timeLabel.numberOfLines = 0
        timeLabel.lineBreakMode = .byWordWrapping
        stack.addArrangedSubview(timeLabel)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupCallStack() {
        let header = UILabel()
        header.text = "MAIN THREAD CALL STACK"
        header.font = .systemFont(ofSize: 12, weight: .black)
        header.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.4)
        contentView.addArrangedSubview(header)
        
        let codeView = PhantomCodeView()
        let stackText = hang.callStack.joined(separator: "\n")
        codeView.text = stackText
        // Use intrinsic height up to a maximum so content is never clipped
        let estimatedLines = hang.callStack.count
        let estimatedHeight = max(200, min(CGFloat(estimatedLines) * 18 + 32, 500))
        codeView.heightAnchor.constraint(greaterThanOrEqualToConstant: estimatedHeight).isActive = true
        contentView.addArrangedSubview(codeView)
        
        let hint = UILabel()
        hint.text = "The trace captures where the main thread was stuck when it failed to respond."
        hint.font = .systemFont(ofSize: 12, weight: .medium)
        hint.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.3)
        hint.numberOfLines = 0
        contentView.addArrangedSubview(hint)
        
        let copyButton = UIButton(type: .system)
        copyButton.setTitle("Copy Stack Trace", for: .normal)
        copyButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        copyButton.tintColor = PhantomTheme.shared.primaryColor
        copyButton.addTarget(self, action: #selector(copyStackTrace), for: .touchUpInside)
        contentView.addArrangedSubview(copyButton)
    }
    
    @objc private func copyStackTrace() {
        UIPasteboard.general.string = hang.callStack.joined(separator: "\n")
        
        let alert = UIAlertController(title: "Copied!", message: "Stack trace copied to clipboard.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
#endif
