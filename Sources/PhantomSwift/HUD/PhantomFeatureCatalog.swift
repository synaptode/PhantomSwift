#if DEBUG
import UIKit

internal struct PhantomFeaturePresentationContext {
    let inspectedRootView: UIView
}

internal struct PhantomFeatureDescriptor {
    let title: String
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
                icon: "network",
                accent: UIColor.Phantom.neonAzure,
                badgeProvider: { PhantomRequestStore.shared.getAll().count },
                makeViewController: { _ in NetworkListVC() }
            )

        case .interceptor:
            return PhantomFeatureDescriptor(
                title: "Interceptor",
                icon: "bolt.shield",
                accent: UIColor.Phantom.neonAzure,
                badgeProvider: { PhantomRequestStore.shared.getAll().count },
                makeViewController: { _ in InterceptorListVC() }
            )

        case .logger:
            return PhantomFeatureDescriptor(
                title: "Logger",
                icon: "terminal",
                accent: UIColor.Phantom.vibrantGreen,
                badgeProvider: { LogStore.shared.getAll().count },
                makeViewController: { _ in LogConsoleVC() }
            )

        case .memoryLeak:
            return PhantomFeatureDescriptor(
                title: "Leak Tracker",
                icon: "drop.triangle",
                accent: UIColor.Phantom.vibrantRed,
                badgeProvider: { 0 },
                makeViewController: { _ in LeakListVC() }
            )

        case .uiInspector:
            return PhantomFeatureDescriptor(
                title: "UI Inspector",
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
                icon: "archivebox",
                accent: UIColor.Phantom.electricIndigo,
                badgeProvider: { 0 },
                makeViewController: { _ in StorageListVC() }
            )

        case .performance:
            return PhantomFeatureDescriptor(
                title: "Performance",
                icon: "gauge.medium",
                accent: UIColor.Phantom.vibrantOrange,
                badgeProvider: { 0 },
                makeViewController: { _ in PerformanceDashboardVC() }
            )

        case .qa:
            return PhantomFeatureDescriptor(
                title: "QA Shortcuts",
                icon: "ant",
                accent: UIColor.Phantom.electricIndigo,
                badgeProvider: { 0 },
                makeViewController: { _ in AppShortcutsVC() }
            )

        case .security:
            return PhantomFeatureDescriptor(
                title: "Security",
                icon: "lock.shield",
                accent: UIColor.Phantom.electricIndigo,
                badgeProvider: { 0 },
                makeViewController: { _ in SecurityDashboardVC() }
            )

        case .swiftUI:
            return PhantomFeatureDescriptor(
                title: "SwiftUI",
                icon: "atom",
                accent: UIColor.Phantom.vibrantPurple,
                badgeProvider: { 0 },
                makeViewController: { _ in RenderListVC() }
            )

        case .accessibility:
            return PhantomFeatureDescriptor(
                title: "Accessibility",
                icon: "figure.roll",
                accent: UIColor.Phantom.vibrantPurple,
                badgeProvider: { 0 },
                makeViewController: { _ in AccessibilityDashboardVC() }
            )

        case .environment:
            return PhantomFeatureDescriptor(
                title: "Environment",
                icon: "globe",
                accent: UIColor.Phantom.electricIndigo,
                badgeProvider: { 0 },
                makeViewController: { _ in EnvironmentDashboardVC() }
            )

        case .extensionSidekick:
            return PhantomFeatureDescriptor(
                title: "Extensions",
                icon: "puzzlepiece",
                accent: UIColor.Phantom.electricIndigo,
                badgeProvider: { 0 },
                makeViewController: { _ in ExtensionLogVC() }
            )

        case .badNetwork:
            return PhantomFeatureDescriptor(
                title: "Bad Network",
                icon: "wifi.exclamationmark",
                accent: UIColor.Phantom.neonAzure,
                badgeProvider: { 0 },
                makeViewController: { _ in BadNetworkDashboardVC() }
            )

        case .hangDetector:
            return PhantomFeatureDescriptor(
                title: "Hang Detector",
                icon: "hand.raised.slash",
                accent: UIColor.Phantom.vibrantOrange,
                badgeProvider: { 0 },
                makeViewController: { _ in HangListVC() }
            )

        case .stateSnapshot:
            return PhantomFeatureDescriptor(
                title: "State Snapshot",
                icon: "clock.arrow.2.circlepath",
                accent: UIColor.Phantom.electricIndigo,
                badgeProvider: { 0 },
                makeViewController: { _ in SnapshotListVC() }
            )

        case .analytics:
            return PhantomFeatureDescriptor(
                title: "Analytics",
                icon: "chart.bar.doc.horizontal",
                accent: UIColor.Phantom.electricIndigo,
                badgeProvider: { 0 },
                makeViewController: { _ in AnalyticsListVC() }
            )

        case .memoryGraph:
            return PhantomFeatureDescriptor(
                title: "Memory Graph",
                icon: "brain.head.profile",
                accent: UIColor.Phantom.vibrantRed,
                badgeProvider: { 0 },
                makeViewController: { _ in MemoryGraphVC() }
            )

        case .assetInspector:
            return PhantomFeatureDescriptor(
                title: "Asset Inspector",
                icon: "photo.on.rectangle",
                accent: UIColor.Phantom.vibrantPurple,
                badgeProvider: { 0 },
                makeViewController: { _ in AssetListVC() }
            )

        case .featureFlags:
            return PhantomFeatureDescriptor(
                title: "Feature Flags",
                icon: "flag.fill",
                accent: UIColor.Phantom.vibrantOrange,
                badgeProvider: { PhantomFeatureFlags.shared.overrideCount },
                makeViewController: { _ in FeatureFlagsDashboardVC() }
            )

        case .mainThreadChecker:
            return PhantomFeatureDescriptor(
                title: "Thread Checker",
                icon: "exclamationmark.triangle.fill",
                accent: UIColor.Phantom.vibrantRed,
                badgeProvider: { PhantomMainThreadChecker.shared.violationCount },
                makeViewController: { _ in MainThreadCheckerVC() }
            )

        case .waterfall:
            return PhantomFeatureDescriptor(
                title: "Waterfall",
                icon: "chart.bar.xaxis",
                accent: UIColor.Phantom.neonAzure,
                badgeProvider: { 0 },
                makeViewController: { _ in NetworkWaterfallVC() }
            )

        case .remoteServer:
            return PhantomFeatureDescriptor(
                title: "Remote Server",
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
                icon: "link.badge.plus",
                accent: UIColor.Phantom.neonAzure,
                badgeProvider: { 0 },
                makeViewController: { _ in DeepLinkTesterVC() }
            )

        case .crashLogs:
            return PhantomFeatureDescriptor(
                title: "Crash Logs",
                icon: "exclamationmark.octagon.fill",
                accent: UIColor.Phantom.vibrantRed,
                badgeProvider: { PhantomCrashLogStore.shared.count },
                makeViewController: { _ in CrashLogVC() }
            )

        case .layoutConflicts:
            return PhantomFeatureDescriptor(
                title: "Layout Conflicts",
                icon: "ruler",
                accent: UIColor.Phantom.vibrantOrange,
                badgeProvider: { PhantomLayoutConflictDetector.shared.count },
                makeViewController: { _ in LayoutConflictVC() }
            )

        case .pushNotificationSimulator:
            return PhantomFeatureDescriptor(
                title: "Push Notifications",
                icon: "bell.badge",
                accent: UIColor.Phantom.vibrantPurple,
                badgeProvider: { 0 },
                makeViewController: { _ in PushSimulatorVC() }
            )

        case .backgroundTaskInspector:
            return PhantomFeatureDescriptor(
                title: "BG Tasks",
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

        let emptyState = PhantomEmptyStateView(emoji: "ℹ️", title: title, message: message)
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
