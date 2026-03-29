#if DEBUG
import UIKit

/// Audits the UI hierarchy for common accessibility issues.
public final class PhantomAccessibilityAuditor {
    public static let shared = PhantomAccessibilityAuditor()
    
    private init() {}
    
    /// Audits the current visible view hierarchy.
    public func audit(window: UIWindow?) -> [AccessibilityIssue] {
        var issues: [AccessibilityIssue] = []
        guard let root = window?.rootViewController?.view else { return [] }
        
        findIssues(in: root, issues: &issues)
        return issues
    }
    
    private func findIssues(in view: UIView, issues: inout [AccessibilityIssue]) {
        // 1. Check for missing labels on interactive elements
        if let button = view as? UIButton {
            if button.accessibilityLabel == nil && button.title(for: .normal) == nil {
                issues.append(AccessibilityIssue(view: button, message: "Missing accessibility label or title", type: .missingLabel))
            }
            
            // 2. Check for small touch targets
            let size = button.frame.size
            if size.width < 44 || size.height < 44 {
                issues.append(AccessibilityIssue(view: button, message: "Small touch target (\(Int(size.width))x\(Int(size.height)))", type: .smallTarget))
            }
        }
        
        if let imageView = view as? UIImageView, imageView.isUserInteractionEnabled {
            if imageView.accessibilityLabel == nil {
                issues.append(AccessibilityIssue(view: imageView, message: "Interactive image missing label", type: .missingLabel))
            }
        }
        
        for subview in view.subviews {
            findIssues(in: subview, issues: &issues)
        }
    }
}

public struct AccessibilityIssue {
    public let view: UIView
    public let message: String
    public let type: IssueType
    
    public enum IssueType {
        case missingLabel
        case smallTarget
        case lowContrast
    }
}
#endif
