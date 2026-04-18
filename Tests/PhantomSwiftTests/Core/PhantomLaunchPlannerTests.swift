import XCTest
@testable import PhantomSwift

final class PhantomLaunchPlannerTests: XCTestCase {

    func testEmptyCustomEnvironmentWithoutPluginsDoesNotExposeDashboardInfrastructure() {
        var config = PhantomConfig()
        config.environment = .custom([])
        config.triggers = [.shake, .dynamicIsland]

        let plan = Set(PhantomLaunchPlanner.makePlan(config: config, pluginCount: 0))

        XCTAssertTrue(plan.isEmpty)
    }

    func testPluginOnlyConfigurationCanStillActivateDashboardInfrastructure() {
        var config = PhantomConfig()
        config.environment = .custom([])
        config.triggers = [.shake, .dynamicIsland]

        let plan = Set(PhantomLaunchPlanner.makePlan(config: config, pluginCount: 1))

        XCTAssertEqual(plan, [.dashboardShakeTrigger, .dashboardDynamicIsland])
    }

    func testNetworkFamilyFeaturesShareSingleInterceptionRuntime() {
        let networkFamily: [PhantomFeature] = [.network, .interceptor, .badNetwork, .waterfall]

        for feature in networkFamily {
            var config = PhantomConfig()
            config.environment = .custom([feature])
            config.triggers = []

            let plan = Set(PhantomLaunchPlanner.makePlan(config: config, pluginCount: 0))

            XCTAssertEqual(plan, [.networkInterception], "Expected only the shared interception runtime for \(feature.rawValue)")
        }
    }

    func testOSLogBridgeRequiresLoggerFeatureAndExplicitOptIn() {
        var loggerConfig = PhantomConfig()
        loggerConfig.environment = .custom([.logger])
        loggerConfig.triggers = []
        loggerConfig.enableOSLogBridge = true

        let loggerPlan = Set(PhantomLaunchPlanner.makePlan(config: loggerConfig, pluginCount: 0))
        XCTAssertEqual(loggerPlan, [.osLogBridge])

        var nonLoggerConfig = PhantomConfig()
        nonLoggerConfig.environment = .custom([.network])
        nonLoggerConfig.triggers = []
        nonLoggerConfig.enableOSLogBridge = true

        let nonLoggerPlan = Set(PhantomLaunchPlanner.makePlan(config: nonLoggerConfig, pluginCount: 0))
        XCTAssertFalse(nonLoggerPlan.contains(.osLogBridge))
    }

    func testMultiFeaturePlanOnlyStartsRequestedRuntimes() {
        var config = PhantomConfig()
        config.environment = .custom([.memoryLeak, .swiftUI, .mainThreadChecker])
        config.triggers = []

        let plan = Set(PhantomLaunchPlanner.makePlan(config: config, pluginCount: 0))

        XCTAssertEqual(
            plan,
            [.memoryLeakTracking, .uiKitRenderTracking, .mainThreadChecking]
        )
    }
}
