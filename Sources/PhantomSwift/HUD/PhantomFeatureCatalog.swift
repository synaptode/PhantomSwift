#if DEBUG
import UIKit

internal struct PhantomFeaturePresentationContext {
    let inspectedRootView: UIView
}

internal struct PhantomFeatureDescriptor {
    let title: String
    let subtitle: String
    let icon: String
    let accent: UIColor
    let badgeProvider: () -> Int
    let makeViewController: (PhantomFeaturePresentationContext) -> UIViewController

    var badge: Int { badgeProvider() }
}

internal enum PhantomFeatureCatalog {
    static func descriptor(for feature: PhantomFeature) -> PhantomFeatureDescriptor {
        switch feature {
        case .network:
            return PhantomFeatureDescriptor(
                title: "Network",
                subtitle: "Live HTTP/HTTPS inspection",
                icon: "network",
                accent: UIColor.Phantom.neonAzure,
                badgeProvider: { PhantomRequestStore.shared.getAll().count },
                makeViewController: { _ in NetworkListVC() }
            )

        case .interceptor:
            return PhantomFeatureDescriptor(
                title: "Interceptor",
                subtitle: "Mock, block, or delay requests",
                icon: "bolt.shield",
                accent: UIColor.Phantom.neonAzure,
                badgeProvider: { PhantomRequestStore.shared.getAll().count },
                makeViewController: { _ in InterceptorListVC() }
            )

        case .logger:
            return PhantomFeatureDescriptor(
                title: "Logger",
                subtitle: "Central log console and bridges",
                icon: "terminal",
                accent: UIColor.Phantom.vibrantGreen,
                badgeProvider: { LogStore.shared.getAll().count },
                makeViewController: { _ in LogConsoleVC() }
            )

        case .memoryLeak:
            return PhantomFeatureDescriptor(
                title: "Leak Tracker",
                subtitle: "Retain-cycle and leak tracking",
                icon: "drop.triangle",
                accent: UIColor.Phantom.vibrantRed,
                badgeProvider: { 0 },
                makeViewController: { _ in LeakListVC() }
            )

        case .uiInspector:
            return PhantomFeatureDescriptor(
                title: "UI Inspector",
                subtitle: "Inspect and edit live view hierarchies",
                icon: "view.3d",
                accent: UIColor.Phantom.vibrantPurple,
                badgeProvider: { 0 },
                makeViewController: { context in
                    ViewHierarchyVC(rootView: context.inspectedRootView)
                }
            )

        case .storage:
            return PhantomFeatureDescriptor(
                title: "Storage",
                subtitle: "Browse defaults, files, and databases",
                icon: "archivebox",
                accent: UIColor.Phantom.electricIndigo,
                badgeProvider: { 0 },
                makeViewController: { _ in StorageListVC() }
            )

        case .performance:
            return PhantomFeatureDescriptor(
                title: "Performance",
                subtitle: "CPU, FPS, RAM, and hang metrics",
                icon: "gauge.medium",
                accent: UIColor.Phantom.vibrantOrange,
                badgeProvider: { 0 },
                makeViewController: { _ in PerformanceDashboardVC() }
            )

        case .qa:
            return PhantomFeatureDescriptor(
                title: "QA Shortcuts",
                subtitle: "Shortcut panel for QA flows",
                icon: "ant",
                accent: UIColor.Phantom.electricIndigo,
                badgeProvider: { 0 },
                makeViewController: { _ in AppShortcutsVC() }
            )

        case .security:
            return PhantomFeatureDescriptor(
                title: "Security",
                subtitle: "Jailbreak, pinning, and integrity checks",
                icon: "lock.shield",
                accent: UIColor.Phantom.electricIndigo,
                badgeProvider: { 0 },
                makeViewController: { _ in SecurityDashboardVC() }
            )

        case .swiftUI:
            return PhantomFeatureDescriptor(
                title: "SwiftUI",
                subtitle: "Track SwiftUI render frequency",
                icon: "atom",
                accent: UIColor.Phantom.vibrantPurple,
                badgeProvider: { 0 },
                makeViewController: { _ in RenderListVC() }
            )

        case .accessibility:
            return PhantomFeatureDescriptor(
                title: "Accessibility",
                subtitle: "Audit labels, targets, and contrast",
                icon: "figure.roll",
                accent: UIColor.Phantom.vibrantPurple,
                badgeProvider: { 0 },
                makeViewController: { _ in AccessibilityDashboardVC() }
            )

        case .environment:
            return PhantomFeatureDescriptor(
                title: "Environment",
                subtitle: "Override locale, GPS, battery, and more",
                icon: "globe",
                accent: UIColor.Phantom.electricIndigo,
                badgeProvider: { 0 },
                makeViewController: { _ in EnvironmentDashboardVC() }
            )

        case .extensionSidekick:
            return PhantomFeatureDescriptor(
                title: "Extensions",
                subtitle: "Inspect extension-side logs",
                icon: "puzzlepiece",
                accent: UIColor.Phantom.electricIndigo,
                badgeProvider: { 0 },
                makeViewController: { _ in ExtensionLogVC() }
            )

        case .badNetwork:
            return PhantomFeatureDescriptor(
                title: "Bad Network",
                subtitle: "Simulate poor network conditions",
                icon: "wifi.exclamationmark",
                accent: UIColor.Phantom.neonAzure,
                badgeProvider: { 0 },
                makeViewController: { _ in BadNetworkDashboardVC() }
            )

        case .hangDetector:
            return PhantomFeatureDescriptor(
                title: "Hang Detector",
                subtitle: "Capture main-thread freezes",
                icon: "hand.raised.slash",
                accent: UIColor.Phantom.vibrantOrange,
                badgeProvider: { 0 },
                makeViewController: { _ in HangListVC() }
            )

        case .stateSnapshot:
            return PhantomFeatureDescriptor(
                title: "State Snapshot",
                subtitle: "Save and restore app state",
                icon: "clock.arrow.2.circlepath",
                accent: UIColor.Phantom.electricIndigo,
                badgeProvider: { 0 },
                makeViewController: { _ in SnapshotListVC() }
            )

        case .analytics:
            return PhantomFeatureDescriptor(
                title: "Analytics",
                subtitle: "Inspect analytics event traffic",
                icon: "chart.bar.doc.horizontal",
                accent: UIColor.Phantom.electricIndigo,
                badgeProvider: { 0 },
                makeViewController: { _ in AnalyticsListVC() }
            )

        case .memoryGraph:
            return PhantomFeatureDescriptor(
                title: "Memory Graph",
                subtitle: "Visualize heap relationships",
                icon: "brain.head.profile",
                accent: UIColor.Phantom.vibrantRed,
                badgeProvider: { 0 },
                makeViewController: { _ in MemoryGraphVC() }
            )

        case .assetInspector:
            return PhantomFeatureDescriptor(
                title: "Asset Inspector",
                subtitle: "Audit media for memory cost",
                icon: "photo.on.rectangle",
                accent: UIColor.Phantom.vibrantPurple,
                badgeProvider: { 0 },
                makeViewController: { _ in AssetListVC() }
            )

        case .featureFlags:
            return PhantomFeatureDescriptor(
                title: "Feature Flags",
                subtitle: "Toggle and persist feature overrides",
                icon: "flag.fill",
                accent: UIColor.Phantom.vibrantOrange,
                badgeProvider: { PhantomFeatureFlags.shared.overrideCount },
                makeViewController: { _ in FeatureFlagsDashboardVC() }
            )

        case .mainThreadChecker:
            return PhantomFeatureDescriptor(
                title: "Thread Checker",
                subtitle: "Detect UIKit work off the main thread",
                icon: "exclamationmark.triangle.fill",
                accent: UIColor.Phantom.vibrantRed,
                badgeProvider: { PhantomMainThreadChecker.shared.violationCount },
                makeViewController: { _ in MainThreadCheckerVC() }
            )

        case .waterfall:
            return PhantomFeatureDescriptor(
                title: "Waterfall",
                subtitle: "Timeline view for request concurrency",
                icon: "chart.bar.xaxis",
                accent: UIColor.Phantom.neonAzure,
                badgeProvider: { 0 },
                makeViewController: { _ in NetworkWaterfallVC() }
            )

        case .remoteServer:
            return PhantomFeatureDescriptor(
                title: "Remote Server",
                subtitle: "WebSocket remote inspection. Requires iOS 13+",
                icon: "antenna.radiowaves.left.and.right",
                accent: UIColor.Phantom.vibrantGreen,
                badgeProvider: { 0 },
                makeViewController: { _ in
                    if #available(iOS 13.0, *) {
                        return RemoteServerDashboardVC()
                    }
                    return unavailableViewController(
                        title: "Remote Server",
                        message: "Remote Server requires iOS 13 or newer."
                    )
                }
            )

        case .deepLinkTester:
            return PhantomFeatureDescriptor(
                title: "Deep Link Tester",
                subtitle: "Open URL schemes and universal links",
                icon: "link.badge.plus",
                accent: UIColor.Phantom.neonAzure,
                badgeProvider: { 0 },
                makeViewController: { _ in DeepLinkTesterVC() }
            )

        case .crashLogs:
            return PhantomFeatureDescriptor(
                title: "Crash Logs",
                subtitle: "Review captured crash diagnostics",
                icon: "exclamationmark.octagon.fill",
                accent: UIColor.Phantom.vibrantRed,
                badgeProvider: { PhantomCrashLogStore.shared.count },
                makeViewController: { _ in CrashLogVC() }
            )

        case .layoutConflicts:
            return PhantomFeatureDescriptor(
                title: "Layout Conflicts",
                subtitle: "Surface live Auto Layout conflicts",
                icon: "ruler",
                accent: UIColor.Phantom.vibrantOrange,
                badgeProvider: { PhantomLayoutConflictDetector.shared.count },
                makeViewController: { _ in LayoutConflictVC() }
            )

        case .pushNotificationSimulator:
            return PhantomFeatureDescriptor(
                title: "Push Notifications",
                subtitle: "Trigger local push payloads",
                icon: "bell.badge",
                accent: UIColor.Phantom.vibrantPurple,
                badgeProvider: { 0 },
                makeViewController: { _ in PushSimulatorVC() }
            )

        case .backgroundTaskInspector:
            return PhantomFeatureDescriptor(
                title: "BG Tasks",
                subtitle: "Inspect BGTaskScheduler requests. Requires iOS 13+",
                icon: "gearshape.2",
                accent: UIColor.Phantom.vibrantOrange,
                badgeProvider: {
                    if #available(iOS 13.0, *) {
                        return PhantomBGTaskInspector.shared.pendingCount
                    }
                    return 0
                },
                makeViewController: { _ in
                    if #available(iOS 13.0, *) {
                        return BGTaskInspectorVC()
                    }
                    return unavailableViewController(
                        title: "Background Tasks",
                        message: "Background task inspection requires iOS 13 or newer."
                    )
                }
            )

        case .runtimeBrowser:
            return PhantomFeatureDescriptor(
                title: "Runtime Browser",
                subtitle: "Browse Objective-C runtime symbols",
                icon: "cpu",
                accent: UIColor.Phantom.vibrantGreen,
                badgeProvider: { 0 },
                makeViewController: { _ in RuntimeBrowserVC() }
            )
        }
    }

    private static func unavailableViewController(title: String, message: String) -> UIViewController {
        let vc = UIViewController()
        vc.title = title
        vc.view.backgroundColor = PhantomTheme.shared.backgroundColor

        let emptyState = PhantomEmptyStateView(symbolName: "info.circle", title: title, message: message)
        emptyState.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(emptyState)

        NSLayoutConstraint.activate([
            emptyState.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor),
            emptyState.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            emptyState.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            emptyState.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
        ])

        return vc
    }
}
#endif
