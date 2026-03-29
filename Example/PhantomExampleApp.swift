import SwiftUI
import PhantomSwift

@main
struct PhantomExampleApp: App {
    init() {
        // 1. Configure PhantomSwift – enable all features in dev mode
        PhantomSwift.configure { config in
            config.environment = .dev
            config.triggers = [.shake]
            config.theme = .dark

            // Register QA App Shortcuts
            config.shortcuts = [
                AppShortcut(title: "🔴 Trigger Memory Leak") {
                    let leakyObj = NSMutableArray()
                    PhantomObjectTracker.shared.track(leakyObj, name: "ShortcutLeakyArray")
                    PhantomLog.warning("Leaky object created via shortcut", tag: "QA")
                },
                AppShortcut(title: "🌐 Fetch Products") {
                    let url = URL(string: "https://dummyjson.com/products?limit=3")!
                    URLSession.shared.dataTask(with: url) { _, _, _ in }.resume()
                    PhantomLog.info("Background fetch triggered via shortcut", tag: "Network")
                },
                AppShortcut(title: "📊 Track Purchase Event") {
                    PhantomAnalyticsMonitor.shared.track(
                        name: "shortcut_purchase",
                        provider: "Firebase",
                        parameters: ["item": "shortcut_item", "price": 0.99]
                    )
                },
                AppShortcut(title: "📸 Capture State Snapshot") {
                    _ = PhantomSnapshotManager.shared.saveCurrentState(name: "Shortcut Snapshot")
                    PhantomLog.info("State snapshot captured via shortcut", tag: "Storage")
                },
                AppShortcut(title: "💥 Simulate 500ms Hang") {
                    Thread.sleep(forTimeInterval: 0.5)
                    PhantomLog.warning("500ms hang simulated via shortcut", tag: "Performance")
                }
            ]
        }

        // 2. Launch the framework
        PhantomSwift.launch()

        // 3. Seed demo data for all modules
        seedNetworkInterceptorRules()
        seedUserDefaults()
        seedDummyDatabase()
        seedInitialLogs()
        seedInitialAnalytics()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    // MARK: - Seeds

    private func seedNetworkInterceptorRules() {
        // Pre-register a mock rule for the interceptor demo
        let mockBody = """
        {"id":999,"title":"[MOCKED] PhantomSwift Product","price":0,"brand":"Phantom","category":"debug"}
        """.data(using: .utf8)

        PhantomInterceptor.shared.add(rule: .mockResponse(
            urlPattern: "dummyjson.com/products/999",
            method: nil,
            statusCode: 200,
            headers: ["Content-Type": "application/json", "X-Mocked-By": "PhantomSwift"],
            body: mockBody
        ))
    }

    private func seedUserDefaults() {
        UserDefaults.standard.set("PhantomUser_Demo", forKey: "username")
        UserDefaults.standard.set(true, forKey: "notifications_enabled")
        UserDefaults.standard.set(42, forKey: "app_launch_count")
        UserDefaults.standard.set("en-US", forKey: "preferred_locale")
        UserDefaults.standard.set("dark", forKey: "theme_preference")
        UserDefaults.standard.set(Date().description, forKey: "last_seen_at")
    }

    private func seedDummyDatabase() {
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("phantom_demo.sqlite")
        if !FileManager.default.fileExists(atPath: path.path) {
            FileManager.default.createFile(atPath: path.path, contents: "demo".data(using: .utf8))
        }
    }

    private func seedInitialLogs() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            PhantomLog.info("PhantomSwift Example App launched successfully", tag: "App")
            PhantomLog.debug("Dev environment active — all 21 modules enabled", tag: "Config")
            PhantomLog.verbose("UserDefaults seeded with 6 demo keys", tag: "Storage")
            PhantomLog.warning("Mock interceptor rule active for /products/999", tag: "Network")
        }
    }

    private func seedInitialAnalytics() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            PhantomAnalyticsMonitor.shared.track(
                name: "app_launch",
                provider: "Firebase",
                parameters: ["environment": "dev", "version": "1.0"]
            )
            PhantomAnalyticsMonitor.shared.track(
                name: "session_start",
                provider: "Amplitude",
                parameters: ["user_id": "demo_user_42", "platform": "iOS"]
            )
        }
    }
}

// MARK: - Color Compatibility Extension
// Essential for iOS 14 support as .indigo, .teal, .mint, .cyan, .brown are iOS 15+

extension Color {
    static var phantomIndigo: Color {
        if #available(iOS 15.0, *) {
            return .indigo
        } else {
            return Color(red: 0.34, green: 0.33, blue: 0.84)
        }
    }
    
    static var phantomTeal: Color {
        if #available(iOS 15.0, *) {
            return .teal
        } else {
            return Color(red: 0.18, green: 0.69, blue: 0.76)
        }
    }
    
    static var phantomMint: Color {
        if #available(iOS 15.0, *) {
            return .mint
        } else {
            return Color(red: 0.0, green: 0.78, blue: 0.74)
        }
    }
    
    static var phantomCyan: Color {
        if #available(iOS 15.0, *) {
            return .cyan
        } else {
            return Color(red: 0.19, green: 0.69, blue: 0.89)
        }
    }
    
    static var phantomBrown: Color {
        if #available(iOS 15.0, *) {
            return .brown
        } else {
            return Color(red: 0.63, green: 0.52, blue: 0.38)
        }
    }
}
