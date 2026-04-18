#if DEBUG
import UIKit

/// A UITextView with basic syntax highlighting support.
internal final class PhantomCodeView: UIView {
    private let textView = UITextView()
    internal var onTextChange: ((String) -> Void)?
    
    internal var isEditable: Bool {
        get { return textView.isEditable }
        set { textView.isEditable = newValue }
    }
    
    internal var text: String? {
        get { return textView.text }
        set { 
            textView.text = newValue
            applyHighlighting()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        textView.backgroundColor = PhantomTheme.shared.surfaceColor
        textView.textColor = PhantomTheme.shared.textColor
        textView.font = UIFont.phantomMonospaced(size: 12, weight: .regular)
        textView.isEditable = false
        textView.layer.cornerRadius = 8
        textView.delegate = self
        
        addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: self.topAnchor),
            textView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
    
    private func applyHighlighting() {
        guard let text = textView.text else { return }
        let attributedString = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: text.count)
        
        // Default color
        attributedString.addAttribute(.foregroundColor, value: PhantomTheme.shared.textColor, range: range)
        
        // Simple regex highlighting for JSON and Callstacks
        highlight(regex: "\"[^\"]*\"", color: UIColor.Phantom.success, in: attributedString) // Strings
        highlight(regex: "\\b(true|false|null)\\b", color: UIColor.Phantom.secondary, in: attributedString) // Booleans
        highlight(regex: "\\b\\d+\\b", color: UIColor.Phantom.warning, in: attributedString) // Numbers
        
        textView.attributedText = attributedString
    }
    
    private func highlight(regex: String, color: UIColor, in attributedString: NSMutableAttributedString) {
        guard let expression = try? NSRegularExpression(pattern: regex) else { return }
        let matches = expression.matches(in: attributedString.string, range: NSRange(location: 0, length: attributedString.length))
        for match in matches {
            attributedString.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }
}

extension PhantomCodeView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        applyHighlighting()
        onTextChange?(textView.text)
    }
}
#endif
