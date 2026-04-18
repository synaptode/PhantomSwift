#if DEBUG
import UIKit

/// A dedicated UIWindow for PhantomSwift overlay.
internal final class PhantomHUDWindow: UIWindow {
    /// Initializer for the HUD window.
    /// - Parameter frame: The frame for the window.
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // Wait for scene to be ready if on iOS 13+
        if #available(iOS 13.0, *) {
            NotificationCenter.default.addObserver(self, selector: #selector(attachToScene), name: UIScene.didActivateNotification, object: nil)
        }
        
        setup()
        attachToScene() // Try immediately
    }
    
    @objc private func attachToScene() {
        guard #available(iOS 13.0, *) else { return }
        
        if self.windowScene == nil {
            if let windowScene = PhantomPresentationResolver.hostWindows()
                .first?.windowScene {
                self.windowScene = windowScene
                
                // Ensure it stays visible after attachment
                self.isHidden = false
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setup() {
        self.backgroundColor = .clear
        self.windowLevel = .alert + 1
        self.isHidden = false
    }
    
    /// Overridden to allow touches to pass through the background area.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view == self ? nil : view
    }
    
    /// Detect shake gesture to initiate bug reporting.
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake && PhantomSwift.shared.config.triggers.contains(.shake) {
            PhantomBugReporter.shared.initiateReport()
        }
    }
    
    /// Allow CMD+D to toggle the dashboard in the simulator
    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(input: "d", modifierFlags: .command, action: #selector(handleDebugShortcut))
        ]
    }
    
    @objc private func handleDebugShortcut() {
        PhantomSwift.shared.showDashboard()
    }
}
#endif
