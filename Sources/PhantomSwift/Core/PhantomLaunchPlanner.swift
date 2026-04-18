#if DEBUG
import Foundation

/// Internal launch-time services that PhantomSwift can activate.
internal enum PhantomLaunchService: String, Hashable {
    case dashboardShakeTrigger
    case dashboardDynamicIsland
    case networkInterception
    case memoryLeakTracking
    case hangDetection
    case crashLogCapture
    case layoutConflictMonitoring
    case pushNotificationSimulation
    case backgroundTaskInspection
    case osLogBridge
    case automaticWebViewConsoleBridge
    case uiKitRenderTracking
    case mainThreadChecking
    case environmentMonitoring
}

/// Immutable input for computing the PhantomSwift launch plan.
internal struct PhantomLaunchContext {
    let config: PhantomConfig
    let pluginCount: Int
    let enabledFeatures: Set<PhantomFeature>

    init(config: PhantomConfig, pluginCount: Int) {
        self.config = config
        self.pluginCount = pluginCount
        self.enabledFeatures = Set(config.environment.enabledFeatures)
    }

    var hasDashboardAccess: Bool {
        !enabledFeatures.isEmpty || pluginCount > 0
    }
}

/// Computes which launch-time services should be activated for a given config.
internal enum PhantomLaunchPlanner {
    private struct Descriptor {
        let service: PhantomLaunchService
        let requiredFeatures: Set<PhantomFeature>
        let additionalRequirement: (PhantomLaunchContext) -> Bool

        init(
            service: PhantomLaunchService,
            requiredFeatures: Set<PhantomFeature> = [],
            additionalRequirement: @escaping (PhantomLaunchContext) -> Bool = { _ in true }
        ) {
            self.service = service
            self.requiredFeatures = requiredFeatures
            self.additionalRequirement = additionalRequirement
        }

        func isEnabled(in context: PhantomLaunchContext) -> Bool {
            let featureRequirementSatisfied =
                requiredFeatures.isEmpty || !requiredFeatures.isDisjoint(with: context.enabledFeatures)
            return featureRequirementSatisfied && additionalRequirement(context)
        }
    }

    static func makePlan(config: PhantomConfig, pluginCount: Int) -> [PhantomLaunchService] {
        let context = PhantomLaunchContext(config: config, pluginCount: pluginCount)
        return descriptors.compactMap { descriptor in
            descriptor.isEnabled(in: context) ? descriptor.service : nil
        }
    }

    private static let descriptors: [Descriptor] = [
        Descriptor(
            service: .dashboardShakeTrigger,
            additionalRequirement: { context in
                context.hasDashboardAccess && context.config.triggers.contains(.shake)
            }
        ),
        Descriptor(
            service: .networkInterception,
            requiredFeatures: [.network, .interceptor, .badNetwork, .waterfall]
        ),
        Descriptor(
            service: .memoryLeakTracking,
            requiredFeatures: [.memoryLeak]
        ),
        Descriptor(
            service: .hangDetection,
            requiredFeatures: [.hangDetector]
        ),
        Descriptor(
            service: .crashLogCapture,
            requiredFeatures: [.crashLogs]
        ),
        Descriptor(
            service: .layoutConflictMonitoring,
            requiredFeatures: [.layoutConflicts]
        ),
        Descriptor(
            service: .pushNotificationSimulation,
            requiredFeatures: [.pushNotificationSimulator]
        ),
        Descriptor(
            service: .backgroundTaskInspection,
            requiredFeatures: [.backgroundTaskInspector]
        ),
        Descriptor(
            service: .osLogBridge,
            requiredFeatures: [.logger],
            additionalRequirement: { context in
                context.config.enableOSLogBridge
            }
        ),
        Descriptor(
            service: .automaticWebViewConsoleBridge,
            requiredFeatures: [.logger],
            additionalRequirement: { context in
                context.config.enableAutomaticWebViewConsoleBridge
            }
        ),
        Descriptor(
            service: .uiKitRenderTracking,
            requiredFeatures: [.swiftUI]
        ),
        Descriptor(
            service: .mainThreadChecking,
            requiredFeatures: [.mainThreadChecker]
        ),
        Descriptor(
            service: .environmentMonitoring,
            requiredFeatures: [.environment]
        ),
        Descriptor(
            service: .dashboardDynamicIsland,
            additionalRequirement: { context in
                context.hasDashboardAccess && context.config.triggers.contains(.dynamicIsland)
            }
        ),
    ]
}
#endif
