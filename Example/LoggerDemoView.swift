import SwiftUI
import PhantomSwift

// MARK: - Logger Demo
struct LoggerDemoView: View {
    @State private var logCount = 0
    @State private var lastLogged = ""

    var body: some View {
        List {
            Section(header: Text("ℹ️ Console Logger")) {
                Text("PhantomLog captures logs at 6 levels. All logs appear in the 'Console' module in the Phantom dashboard with color-coded level indicators.")
                    .font(.caption).foregroundColor(.secondary)
            }

            Section(header: Text("📋 Log Levels")) {
                logButton("VERBOSE", subtitle: "Detailed trace info", color: .gray, systemImage: "text.alignleft") {
                    PhantomLog.verbose("User preference loaded: theme=dark, locale=en-US", tag: "Config")
                    PhantomLog.verbose("URL cache: 120 entries, 14.2MB used", tag: "Cache")
                }
                logButton("DEBUG", subtitle: "Developer debugging info", color: .blue, systemImage: "ladybug.fill") {
                    PhantomLog.debug("JWT parsed: sub=user_42, exp=+3600s", tag: "Auth")
                    PhantomLog.debug("ViewDidLoad: HomeViewController (0.023s)", tag: "UI")
                }
                logButton("INFO", subtitle: "General informational messages", color: .green, systemImage: "info.circle.fill") {
                    PhantomLog.info("User logged in successfully: user_42", tag: "Auth")
                    PhantomLog.info("Application moved to foreground", tag: "App")
                }
                logButton("WARNING", subtitle: "Potential issue, not critical", color: .orange, systemImage: "exclamationmark.triangle.fill") {
                    PhantomLog.warning("Cache is 90% full — consider clearing stale entries", tag: "Cache")
                    PhantomLog.warning("API response time >1s: /product/list took 1.4s", tag: "Network")
                }
                logButton("ERROR", subtitle: "Recoverable error occurred", color: .red, systemImage: "xmark.octagon.fill") {
                    PhantomLog.error("Failed to parse response body: invalid JSON at key 'items'", tag: "Parsing")
                    PhantomLog.error("Image download failed: 404 Not Found for product_img_887", tag: "Assets")
                }
                logButton("CRITICAL", subtitle: "Severe, system-level failure", color: .purple, systemImage: "bolt.fill") {
                    PhantomLog.critical("CoreData persistent store failed to initialize — data loss risk", tag: "Storage")
                    PhantomLog.critical("Out of memory warning received from OS", tag: "Memory")
                }
            }

            Section(header: Text("🔥 Scenario Simulations")) {
                scenarioButton("Auth Flow", subtitle: "Login → token → profile fetch") {
                    simulateAuthFlow()
                }
                scenarioButton("Network Error Cascade", subtitle: "Retry → timeout → fallback") {
                    simulateNetworkCascade()
                }
                scenarioButton("Checkout Flow", subtitle: "Cart → payment → confirmation") {
                    simulateCheckout()
                }
                scenarioButton("App Launch Sequence", subtitle: "Config → auth → data prefetch") {
                    simulateAppLaunch()
                }
                scenarioButton("Crash Investigation", subtitle: "Warning chain leading to critical") {
                    simulateCrashInvestigation()
                }
            }

            Section(header: Text("📊 Stats")) {
                HStack {
                    Text("Logs sent this session:")
                    Spacer()
                    Text("\(logCount)").bold().foregroundColor(.blue)
                }
                if !lastLogged.isEmpty {
                    Text("Last: \(lastLogged)").font(.caption).foregroundColor(.secondary)
                }
            }

            Section {
                InfoRow(icon: "info.circle.fill", text: "Open 'Console' in the Phantom dashboard to see all logs with level filtering, tags, and long-press for AI analysis.", color: .gray)
            }
        }
        .navigationTitle("Console Logger")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
    }

    // MARK: - Helpers

    private func logButton(_ level: String, subtitle: String, color: Color, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            logCount += 2
            lastLogged = level
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: systemImage)
                        .font(.system(size: 15))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(level)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(color)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("2 logs")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func scenarioButton(_ title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            lastLogged = title
        }) {
            VStack(alignment: .leading, spacing: 2) {
                Text("▶ \(title)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Simulation Scenarios

    private func simulateAuthFlow() {
        logCount += 6
        DispatchQueue.main.async {
            PhantomLog.verbose("Auth flow initiated from LoginView", tag: "Auth")
            PhantomLog.info("POST /auth/login — credentials sent", tag: "Auth")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            PhantomLog.info("Token received — expires in 3600s", tag: "Auth")
            PhantomLog.debug("JWT stored to Keychain", tag: "Auth")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            PhantomLog.info("GET /auth/me — profile loaded for user_42", tag: "Auth")
            PhantomLog.verbose("Auth flow complete in 0.6s", tag: "Auth")
        }
    }

    private func simulateNetworkCascade() {
        logCount += 7
        DispatchQueue.main.async {
            PhantomLog.info("GET /products — attempt 1/3", tag: "Network")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            PhantomLog.warning("Request timed out after 3s — retrying (2/3)", tag: "Network")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            PhantomLog.warning("Request timed out after 3s — retrying (3/3)", tag: "Network")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            PhantomLog.error("All retries exhausted — serving cached data", tag: "Network")
            PhantomLog.warning("Stale cache data from 6 hours ago served to UI", tag: "Cache")
            PhantomLog.info("Fallback complete — user notified via banner", tag: "Network")
        }
    }

    private func simulateCheckout() {
        logCount += 8
        PhantomLog.info("Checkout initiated — 3 items, total $49.97", tag: "Commerce")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            PhantomLog.debug("Payment token requested from Stripe SDK", tag: "Payment")
            PhantomLog.verbose("Card last4=4242, exp=12/26", tag: "Payment")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            PhantomLog.info("POST /orders — order created: ORD-789", tag: "Commerce")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            PhantomLog.info("Payment authorized — charge_id=ch_abc123", tag: "Payment")
            PhantomLog.info("Analytics: purchase_success event fired", tag: "Analytics")
            PhantomLog.info("Confirmation email queued for user@example.com", tag: "Commerce")
        }
    }

    private func simulateAppLaunch() {
        logCount += 7
        PhantomLog.verbose("AppDelegate: application(_:didFinishLaunchingWithOptions:)", tag: "App")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            PhantomLog.debug("Remote config fetched — variant: B", tag: "Config")
            PhantomLog.info("Feature flags refreshed — 3 flags active", tag: "Config")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            PhantomLog.info("Auth token valid — auto-login user_42", tag: "Auth")
            PhantomLog.verbose("Prefetching home feed (12 items)...", tag: "Data")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            PhantomLog.info("App ready — launch time: 1.2s", tag: "App")
        }
    }

    private func simulateCrashInvestigation() {
        logCount += 5
        PhantomLog.warning("Memory usage at 180MB — approaching 200MB limit", tag: "Memory")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            PhantomLog.warning("NSCache evicted 134 objects due to memory pressure", tag: "Cache")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            PhantomLog.error("Image decoder failed — insufficient memory for 4K texture", tag: "Assets")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            PhantomLog.error("UICollectionView scroll stuttering — frame drop detected", tag: "UI")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            PhantomLog.critical("EXC_BAD_ACCESS in [ProductImageCell loadHighResImage]", tag: "Crash")
        }
    }
}
