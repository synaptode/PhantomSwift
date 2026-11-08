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
    private var isTransitioning = false

    
    /// Returns all registered plugins.
    internal var registeredPlugins: [PhantomPlugin] {
        return plugins
    }
    
    /// Register a custom plugin to appear in the dashboard.
    public func register(plugin: PhantomPlugin) {
        plugins = PhantomPluginRegistry.merged(existing: plugins, inserting: plugin)

        guard isLaunched else { return }
        if Thread.isMainThread {
            refreshDashboardInfrastructure()
        } else {
            DispatchQueue.main.async {
                self.refreshDashboardInfrastructure()
            }
        }
    }

    /// Resets the shared runtime state for tests.
    /// This keeps production behavior unchanged while allowing isolated test setup.
    internal func resetForTesting() {
        if Thread.isMainThread {
            resetRuntimeState()
        } else {
            DispatchQueue.main.sync {
                self.resetRuntimeState()
            }
        }
    }

    private func resetRuntimeState() {
        isLaunched = false
        hudWindow = nil
        dynamicIsland = nil
        plugins.removeAll()
        activeLaunchServices.removeAll()
        isHUDSetupScheduled = false
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
            PhantomPushMonitor.shared.start()
        case .backgroundTaskInspection:
            if #available(iOS 13.0, *) {
                PhantomBGTaskInspector.shared.start()
            }

        case .osLogBridge:
            PhantomOSLogBridge.shared.start()

        case .automaticWebViewConsoleBridge:
            PhantomWebViewConsoleAutoInstaller.shared.start()

        case .uiKitRenderTracking:
            PhantomUIKitTracker.shared.start()
            PhantomRenderStore.shared.isUIKitTrackingEnabled = true

        case .mainThreadChecking:
            PhantomMainThreadChecker.shared.start()

        case .environmentMonitoring:
            _ = PhantomEnvironmentMonitor.shared

        case .webViewInspection:
            #if canImport(WebKit)
            PhantomWebViewInterceptor.shared.start()
            #endif
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
            self?.toggleDashboard()
        }
        dynamicIsland = island
        hudWindow?.addSubview(island)
    }
    
    /// Whether the dashboard or any of its child views is currently visible.
    public var isDashboardVisible: Bool {
        PhantomPresentationResolver.activeDashboard() != nil
    }

    /// Toggles the PhantomSwift dashboard (shows if hidden, dismisses if visible).
    public func toggleDashboard() {
        if isDashboardVisible || PhantomUIInspector.shared.isInspecting {
            hideDashboard()
        } else {
            showDashboard()
        }
    }

    /// Manually show the PhantomSwift dashboard.
    public func showDashboard() {
        guard !isDashboardVisible, !isTransitioning else { return }
        guard let presenter = PhantomPresentationResolver.topPresenter() else { return }
        presentDashboard(from: presenter)
    }

    /// Manually hide the PhantomSwift dashboard and all open modules.
    public func hideDashboard(animated: Bool = true, completion: (() -> Void)? = nil) {
        if PhantomUIInspector.shared.isInspecting {
            PhantomUIInspector.shared.stopInspecting()
        }

        guard let dashboard = PhantomPresentationResolver.activeDashboard() else {
            completion?()
            return
        }

        guard !isTransitioning else { return }
        isTransitioning = true

        let dismissTarget: UIViewController = dashboard.presentingViewController ?? dashboard
        dismissTarget.dismiss(animated: animated) { [weak self] in
            self?.isTransitioning = false
            PhantomEventBus.shared.post(.dashboardDismissed)
            completion?()
        }
    }

    private func presentDashboard(from presenter: UIViewController) {
        guard !isDashboardVisible, !isTransitioning else { return }
        guard !PhantomPresentationResolver.isPhantomViewController(presenter) else { return }

        var finalPresenter: UIViewController? = presenter
        var depth = 0
        while let nextPresenter = finalPresenter?.presentedViewController, depth < 10 {
            if PhantomPresentationResolver.isPhantomViewController(nextPresenter) { return }
            finalPresenter = nextPresenter
            depth += 1
        }

        guard let targetPresenter = finalPresenter,
              !PhantomPresentationResolver.isPhantomViewController(targetPresenter) else { return }

        isTransitioning = true
        let dashboard = PhantomDashboardVC()
        dashboard.modalPresentationStyle = .fullScreen

        targetPresenter.present(dashboard, animated: true) { [weak self] in
            self?.isTransitioning = false
            PhantomEventBus.shared.post(.dashboardPresented)
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
