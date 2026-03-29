import SwiftUI
import PhantomSwift

// MARK: - Analytics Demo
struct AnalyticsDemoView: View {
    @State private var trackedCount = 0
    @State private var lastEvent = ""

    let providers = ["Firebase", "Amplitude", "Mixpanel", "Segment", "Braze"]

    var body: some View {
        List {
            Section(header: Text("ℹ️ Analytics Interceptor")) {
                Text("PhantomAnalyticsMonitor intercepts all analytics events before they're sent to any provider. All events appear in the 'Analytics' module in the Phantom dashboard.")
                    .font(.caption).foregroundColor(.secondary)
                HStack {
                    Text("Events tracked this session:")
                    Spacer()
                    Text("\(PhantomAnalyticsMonitor.shared.events.count)").bold().foregroundColor(.blue)
                }
                .font(.caption)
            }

            Section(header: Text("🎯 Product Events")) {
                eventButton("👀 Product Viewed", provider: "Firebase") {
                    trackEvent("product_viewed", provider: "Firebase", params: [
                        "product_id": "PRD-001", "product_name": "PhantomKit Pro", "category": "developer_tools", "price": 49.99
                    ])
                }
                eventButton("🛒 Add to Cart", provider: "Firebase") {
                    trackEvent("add_to_cart", provider: "Firebase", params: [
                        "product_id": "PRD-001", "quantity": 1, "price": 49.99, "currency": "USD"
                    ])
                }
                eventButton("💳 Purchase Completed", provider: "Firebase") {
                    trackEvent("purchase", provider: "Firebase", params: [
                        "transaction_id": "TXN-\(Int.random(in: 1000...9999))", "total": 49.99, "currency": "USD", "items": 1
                    ])
                }
                eventButton("❤️ Add to Wishlist", provider: "Amplitude") {
                    trackEvent("wishlist_add", provider: "Amplitude", params: [
                        "product_id": "PRD-002", "list_length": 4
                    ])
                }
            }

            Section(header: Text("👤 User Events")) {
                eventButton("🔐 User Signed In", provider: "Amplitude") {
                    trackEvent("user_signed_in", provider: "Amplitude", params: [
                        "method": "email", "user_id": "user_42", "is_returning": true
                    ])
                }
                eventButton("📧 Email Subscription", provider: "Mixpanel") {
                    trackEvent("subscribe_email", provider: "Mixpanel", params: [
                        "source": "checkout_flow", "variant": "B", "timestamp": Date().description
                    ])
                }
                eventButton("⚙️ Settings Changed", provider: "Mixpanel") {
                    trackEvent("settings_changed", provider: "Mixpanel", params: [
                        "setting": "notifications", "new_value": "enabled", "previous_value": "disabled"
                    ])
                }
            }

            Section(header: Text("📱 App Lifecycle Events")) {
                eventButton("🚀 App Launched", provider: "Segment") {
                    trackEvent("app_launched", provider: "Segment", params: [
                        "version": "2.1.0", "build": "401", "cold_start": true, "locale": "en-US"
                    ])
                }
                eventButton("📊 Screen Viewed", provider: "Segment") {
                    trackEvent("screen_viewed", provider: "Segment", params: [
                        "screen_name": "ProductDetail", "previous_screen": "ProductList", "visit_count": 3
                    ])
                }
                eventButton("🔔 Push Permission Granted", provider: "Braze") {
                    trackEvent("push_permission_granted", provider: "Braze", params: [
                        "granted": true, "prompt_context": "post_purchase"
                    ])
                }
            }

            Section(header: Text("🎮 Batch Scenarios")) {
                scenarioButton("Full Checkout Flow", subtitle: "view → cart → purchase (5 events)") {
                    simulateCheckoutFlow()
                }
                scenarioButton("Onboarding Funnel", subtitle: "start → steps → complete (6 events)") {
                    simulateOnboardingFunnel()
                }
                scenarioButton("Feature Discovery", subtitle: "Multi-screen analytics burst") {
                    simulateFeatureDiscovery()
                }
            }

            if !lastEvent.isEmpty {
                Section(header: Text("✅ Last Event")) {
                    Text(lastEvent).font(.caption).foregroundColor(.secondary)
                }
            }

            Section {
                InfoRow(icon: "info.circle.fill", text: "Open 'Analytics' in dashboard to see all events with provider, parameters, and timestamp.", color: .blue)
            }
        }
        .navigationTitle("Analytics Interceptor")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
    }

    // MARK: - Helpers

    private func trackEvent(_ name: String, provider: String, params: [String: Any]) {
        PhantomAnalyticsMonitor.shared.track(name: name, provider: provider, parameters: params)
        trackedCount += 1
        lastEvent = "[\(provider)] \(name)"
        PhantomLog.debug("Analytics: [\(provider)] \(name)", tag: "Analytics")
    }

    private func eventButton(_ title: String, provider: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .medium))
                    Text("→ \(provider)").font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "paperplane.fill")
                    .font(.caption)
                    .foregroundColor(.blue.opacity(0.6))
            }
        }
        .foregroundColor(.primary)
    }

    private func scenarioButton(_ title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text("▶ \(title)").font(.system(size: 14, weight: .semibold)).foregroundColor(.blue)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Scenarios

    private func simulateCheckoutFlow() {
        let providers_list = ["Firebase", "Firebase", "Amplitude", "Firebase", "Segment"]
        let events = [
            ("product_detail_viewed", ["product_id": "PRD-001", "source": "search"]),
            ("add_to_cart", ["product_id": "PRD-001", "price": 49.99]),
            ("cart_viewed", ["item_count": 1, "total": 49.99]),
            ("checkout_started", ["total": 49.99, "currency": "USD"]),
            ("purchase_complete", ["order_id": "ORD-\(Int.random(in: 100...999))", "total": 49.99])
        ]
        for (i, (name, params)) in events.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                trackEvent(name, provider: providers_list[i], params: params)
            }
        }
    }

    private func simulateOnboardingFunnel() {
        let steps = [
            ("onboarding_started", ["variant": "A"]),
            ("onboarding_step_1", ["step": "welcome", "duration_s": 3]),
            ("onboarding_step_2", ["step": "permissions", "notifications_granted": true]),
            ("onboarding_step_3", ["step": "profile_setup", "fields_filled": 4]),
            ("onboarding_step_4", ["step": "tutorial_skipped", "at_step": 3]),
            ("onboarding_completed", ["total_time_s": 45, "steps_seen": 4])
        ]
        for (i, (name, params)) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                trackEvent(name, provider: ["Amplitude", "Segment", "Firebase"][i % 3], params: params)
            }
        }
    }

    private func simulateFeatureDiscovery() {
        let events: [(String, String, [String: Any])] = [
            ("feature_discovery_modal_shown", "Braze", ["feature": "dark_mode"]),
            ("feature_discovery_tap", "Braze", ["feature": "dark_mode", "action": "learn_more"]),
            ("feature_enabled", "Firebase", ["feature": "dark_mode"]),
            ("screen_viewed", "Segment", ["screen": "DarkModeSettings"]),
            ("setting_toggled", "Mixpanel", ["setting": "dark_mode", "value": true])
        ]
        for (i, (name, provider, params)) in events.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                trackEvent(name, provider: provider, params: params)
            }
        }
    }
}
