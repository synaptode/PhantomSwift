#if DEBUG
import Foundation
import UIKit

/// The central coordinator for PhantomSwift.
public final class PhantomSwift {
    /// The shared singleton instance.
    public static let shared = PhantomSwift()
    
    /// Default configuration.
    public var config: PhantomConfig = {
        var config = PhantomConfig()
        config.triggers = [.shake] // Default to shake only as requested
        return config
    }()
    
    /// Whether the library has been launched.
    private(set) var isLaunched = false
    
    private init() {}
    
    /// Configures PhantomSwift with the provided closure.
    /// - Parameter closure: The configuration closure.
    public static func configure(_ closure: (inout PhantomConfig) -> Void) {
        closure(&shared.config)
    }
    
    /// Launches PhantomSwift and initializes enabled modules.
    public static func launch() {
        guard !shared.isLaunched else { return }
        shared.isLaunched = true
        
        // Ensure we are on the main thread for UI setup
        if Thread.isMainThread {
            shared.setup()
        } else {
            DispatchQueue.main.async {
                shared.setup()
            }
        }
    }
    
    private var hudWindow: PhantomHUDWindow?
    private var dynamicIsland: PhantomDynamicIsland?
    private var plugins: [PhantomPlugin] = []
    
    /// Returns all registered plugins.
    internal var registeredPlugins: [PhantomPlugin] {
        return plugins
    }
    
    /// Register a custom plugin to appear in the dashboard.
    public func register(plugin: PhantomPlugin) {
        plugins.append(plugin)
    }
    
    private func setup() {
        guard config.environment != .release else {
            return
        }
        
        // Register URLProtocol
        URLProtocol.registerClass(PhantomURLProtocol.self)
        
        // Swizzle URLSessionConfiguration to automatically include our protocol
        swizzleURLSessionConfiguration()
        
        // Initialize Gesture Handler
        PhantomGestureHandler.shared.start()
        
        // Initialize Leak Tracker
        PhantomLeakTracker.shared.start()
        
        // Initialize HUD with a slightly longer delay to ensure SwiftUI UIWindowScene is fully formed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.setupHUD()
        }
        
        // Start Hang Detector
        PhantomHangDetector.shared.start()

        // Start Crash Log Store (exception handler + persist prior sessions)
        PhantomCrashLogStore.shared.start()

        // Start Auto Layout Conflict Detector (stderr tap)
        PhantomLayoutConflictDetector.shared.start()

        // Start Push Simulator (loads persisted templates)
        PhantomPushSimulator.shared.start()

        // Start Background Task Inspector (iOS 13+)
        if #available(iOS 13.0, *) {
            PhantomBGTaskInspector.shared.start()
        }

        // Start OSLog bridge if opted in (iOS 15+ only; no-op on older)
        if config.enableOSLogBridge {
            PhantomOSLogBridge.shared.start()
        }
        
        // Start UIKit Layout Tracker
        PhantomUIKitTracker.shared.start()
        PhantomRenderStore.shared.isUIKitTrackingEnabled = true
        
        // Start Main Thread Checker
        PhantomMainThreadChecker.shared.start()
        
        // Eagerly init environment monitor so battery monitoring begins at launch
        _ = PhantomEnvironmentMonitor.shared
        
        PhantomEventBus.shared.post(.appLaunched)
        print("🚀 PhantomSwift launched in \(config.environment) environment.")
    }
    
    private func setupHUD() {
        let screenBounds = UIScreen.main.bounds
        hudWindow = PhantomHUDWindow(frame: screenBounds)
        
        // Dynamic Island
        if config.triggers.contains(.dynamicIsland) {
            let width: CGFloat = 60   // icon + dot only — no text label
            let height: CGFloat = 36
            let x = (screenBounds.width - width) / 2
            let y: CGFloat = 12 // Positioned below the notch/island
            
            dynamicIsland = PhantomDynamicIsland(frame: CGRect(x: x, y: y, width: width, height: height))
            dynamicIsland?.onAction = { [weak self] in
                self?.showDashboard()
            }
            hudWindow?.addSubview(dynamicIsland!)
        }
    }
    
    /// Manually show the PhantomSwift dashboard.
    public func showDashboard() {
        // Find the main application window to present the dashboard on.
        // This is much more reliable than using our own HUD window for full-screen UI.
        guard let mainAppWindow = findActiveWindow() else {
            // Last resort: try HUD window
            if let window = hudWindow {
                presentDashboard(on: window)
            }
            return
        }
        
        presentDashboard(on: mainAppWindow)
    }
    
    private func presentDashboard(on window: UIWindow) {
        // Ensure no existing dashboard is being presented
        if let presented = window.rootViewController?.presentedViewController, presented is PhantomDashboardVC {
            return // Already showing
        }
        
        // If it's presenting something else, we should present on THAT instead of the root
        var presenter = window.rootViewController
        var depth = 0
        while let nextPresenter = presenter?.presentedViewController, depth < 10 {
            if nextPresenter is PhantomDashboardVC { return } // Already showing
            presenter = nextPresenter
            depth += 1
        }
        
        guard let finalPresenter = presenter else {
            // If window has no rootVC, we must provide one
            let tempVC = UIViewController()
            tempVC.view.backgroundColor = .clear
            window.rootViewController = tempVC
            presentDashboard(on: window) // Retry with new root
            return
        }
        
        let dashboard = PhantomDashboardVC()
        dashboard.modalPresentationStyle = .fullScreen
        
        finalPresenter.present(dashboard, animated: true) {
            PhantomEventBus.shared.post(.dashboardPresented)
        }
    }
    
    private func findActiveWindow() -> UIWindow? {
        if #available(iOS 13.0, *) {
            // Priority 1: Key window of active scene
            let scene = UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .compactMap { $0 as? UIWindowScene }
                .first
            
            return scene?.windows.first { $0.isKeyWindow } ?? 
                   scene?.windows.first ?? 
                   UIApplication.shared.windows.first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.keyWindow
        }
    }
    
    private func swizzleURLSessionConfiguration() {
        let cls = URLSessionConfiguration.self
        let original = #selector(getter: cls.default)
        let swizzled = #selector(getter: cls.phantom_default)
        PhantomSwizzler.swizzleClassMethod(cls: cls, originalSelector: original, swizzledSelector: swizzled)
    }
}

extension URLSessionConfiguration {
    @objc class var phantom_default: URLSessionConfiguration {
        let config = self.phantom_default // After swizzling, this calls the ORIGINAL 'default'
        var protocols = config.protocolClasses ?? []
        protocols.insert(PhantomURLProtocol.self, at: 0)
        config.protocolClasses = protocols
        return config
    }
}
#endif
