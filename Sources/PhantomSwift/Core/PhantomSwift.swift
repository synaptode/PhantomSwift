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
    private var activeLaunchServices = Set<PhantomLaunchService>()
    private var isHUDSetupScheduled = false
    
    /// Returns all registered plugins.
    internal var registeredPlugins: [PhantomPlugin] {
        return plugins
    }
    
    /// Register a custom plugin to appear in the dashboard.
    public func register(plugin: PhantomPlugin) {
        plugins.append(plugin)

        guard isLaunched else { return }
        if Thread.isMainThread {
            refreshDashboardInfrastructure()
        } else {
            DispatchQueue.main.async {
                self.refreshDashboardInfrastructure()
            }
        }
    }
    
    private func setup() {
        let config = self.config

        guard config.environment != .release else {
            return
        }

        let launchPlan = PhantomLaunchPlanner.makePlan(config: config, pluginCount: plugins.count)
        applyLaunchPlan(launchPlan)
        
        PhantomEventBus.shared.post(.appLaunched)
        print("🚀 PhantomSwift launched in \(config.environment) environment.")
    }
    
    private func applyLaunchPlan(_ services: [PhantomLaunchService]) {
        services.forEach(startLaunchService(_:))
    }

    private func startLaunchService(_ service: PhantomLaunchService) {
        guard activeLaunchServices.insert(service).inserted else { return }

        switch service {
        case .dashboardShakeTrigger:
            PhantomGestureHandler.shared.start()

        case .dashboardDynamicIsland:
            scheduleHUDSetup()

        case .networkInterception:
            URLProtocol.registerClass(PhantomURLProtocol.self)
            swizzleURLSessionConfiguration()

        case .memoryLeakTracking:
            PhantomLeakTracker.shared.start()

        case .hangDetection:
            PhantomHangDetector.shared.start()

        case .crashLogCapture:
            PhantomCrashLogStore.shared.start()

        case .layoutConflictMonitoring:
            PhantomLayoutConflictDetector.shared.start()

        case .pushNotificationSimulation:
            PhantomPushSimulator.shared.start()

        case .backgroundTaskInspection:
            if #available(iOS 13.0, *) {
                PhantomBGTaskInspector.shared.start()
            }

        case .osLogBridge:
            PhantomOSLogBridge.shared.start()

        case .uiKitRenderTracking:
            PhantomUIKitTracker.shared.start()
            PhantomRenderStore.shared.isUIKitTrackingEnabled = true

        case .mainThreadChecking:
            PhantomMainThreadChecker.shared.start()

        case .environmentMonitoring:
            _ = PhantomEnvironmentMonitor.shared
        }
    }

    private func refreshDashboardInfrastructure() {
        let services = PhantomLaunchPlanner.makePlan(config: config, pluginCount: plugins.count)
        let shellServices = services.filter {
            $0 == .dashboardShakeTrigger || $0 == .dashboardDynamicIsland
        }
        applyLaunchPlan(shellServices)
    }

    private func scheduleHUDSetup() {
        guard !isHUDSetupScheduled else { return }
        isHUDSetupScheduled = true

        // Delay slightly so SwiftUI UIWindowScene is fully formed before overlay setup.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            self.isHUDSetupScheduled = false
            self.setupHUD()
        }
    }

    private func setupHUD() {
        guard config.triggers.contains(.dynamicIsland) else { return }

        let screenBounds = UIScreen.main.bounds
        if hudWindow == nil {
            hudWindow = PhantomHUDWindow(frame: screenBounds)
        }

        guard dynamicIsland == nil else { return }

        let width: CGFloat = 60
        let height: CGFloat = 36
        let x = (screenBounds.width - width) / 2
        let y: CGFloat = 12

        let island = PhantomDynamicIsland(frame: CGRect(x: x, y: y, width: width, height: height))
        island.onAction = { [weak self] in
            self?.showDashboard()
        }
        dynamicIsland = island
        hudWindow?.addSubview(island)
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
