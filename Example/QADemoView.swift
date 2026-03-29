import SwiftUI
import PhantomSwift

// MARK: - QA Toolkit Demo
struct QADemoView: View {
    @State private var shortcutResult = ""

    var body: some View {
        List {
            Section(header: Text("ℹ️ QA Toolkit")) {
                Text("The QA module gives testers and developers powerful tools: bug reporting, shortcuts, and flow recording — all accessible from the dashboard.")
                    .font(.caption).foregroundColor(.secondary)
            }

            // MARK: Bug Reporter
            Section(header: Text("🐛 Bug Reporter")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Captures a screenshot of the current screen and opens a share sheet with screenshot + device info. Great for sending to Jira, Slack, or GitHub Issues.")
                        .font(.caption).foregroundColor(.secondary)
                    Button("📸 Capture & Report a Bug Now") {
                        // Delay to let the UI settle before capture
                        PhantomLog.info("Bug report initiated from QA Demo", tag: "QA")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            PhantomBugReporter.shared.initiateReport()
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.85))
                    .cornerRadius(10)
                }
                .padding(.vertical, 4)
            }

            // MARK: Bug scenarios to reproduce
            Section(header: Text("🔁 Reproducible Scenarios")) {
                Button("Simulate Crash-worthy State") {
                    PhantomLog.critical("QA: Simulating near-crash state for bug report", tag: "QA")
                    PhantomLog.error("NilPointerException simulated at ProductListVC.loadData()", tag: "QA")
                    Thread.sleep(forTimeInterval: 0.5) // Simulate hang
                    shortcutResult = "Crash scenario logged. Open dashboard → Console + Hang Detector."
                }
                .foregroundColor(.red)

                Button("Simulate Corrupt Data State") {
                    UserDefaults.standard.set("CORRUPTED_VALUE_\(Int.random(in: 1...99))", forKey: "auth_token")
                    UserDefaults.standard.set(-999, forKey: "user_id")
                    PhantomLog.error("Corrupt data injected into UserDefaults for QA testing", tag: "QA")
                    shortcutResult = "Corrupt state injected. Open Storage module to verify."
                }
                .foregroundColor(.orange)

                Button("Clear Corrupt State") {
                    UserDefaults.standard.removeObject(forKey: "auth_token")
                    UserDefaults.standard.removeObject(forKey: "user_id")
                    PhantomLog.info("Corrupt state cleared", tag: "QA")
                    shortcutResult = "State cleared."
                }
                .foregroundColor(.green)
            }

            // MARK: App Shortcuts
            Section(header: Text("⚡ App Shortcuts")) {
                Text("These shortcuts are registered in PhantomExampleApp.init(). Open 'QA' → 'App Shortcuts' in dashboard to trigger them.")
                    .font(.caption).foregroundColor(.secondary)
                ForEach([
                    ("🔴 Trigger Memory Leak", "Creates a tracked leaky NSObject"),
                    ("🌐 Fetch Products", "Background network request"),
                    ("📊 Track Purchase Event", "Fires analytics event"),
                    ("📸 Capture State Snapshot", "Saves current UserDefaults"),
                    ("💥 Simulate 500ms Hang", "Triggers hang detector")
                ], id: \.0) { pair in
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text(pair.0).font(.system(size: 13, weight: .medium))
                            Text(pair.1).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }

            // MARK: Accessibility Integration
            Section(header: Text("♿ Accessibility")) {
                Button("Navigate to Accessibility Demo") {
                    PhantomLog.info("Navigating to Accessibility demo", tag: "QA")
                }
                .foregroundColor(.phantomTeal)
                Text("Use 'Accessibility Audit' in the dashboard to scan the current screen for A11y issues.")
                    .font(.caption).foregroundColor(.secondary)
            }

            // MARK: Result
            if !shortcutResult.isEmpty {
                Section(header: Text("📋 Result")) {
                    Text(shortcutResult).font(.caption).foregroundColor(.secondary)
                }
            }

            Section {
                InfoRow(icon: "info.circle.fill", text: "Open 'QA' module in dashboard for App Shortcuts. Bug Reporter is accessible from any screen.", color: .orange)
            }
        }
        .navigationTitle("QA Toolkit")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
    }
}

// MARK: - Security Audit Demo
struct SecurityDemoView: View {
    @State private var auditResult = ""

    var body: some View {
        List {
            Section(header: Text("🔒 Security Auditor")) {
                Text("PhantomSwift's Security module checks for common iOS security vulnerabilities at runtime. Tap a scenario below and then open 'Security' in the dashboard to see the audit results.")
                    .font(.caption).foregroundColor(.secondary)
            }

            Section(header: Text("🧪 Audit Scenarios")) {
                securityRow("Jailbreak Detection Check", icon: "checkmark.shield.fill", color: .green) {
                    PhantomLog.info("Security: Jailbreak detection scan started", tag: "Security")
                    auditResult = "Jailbreak check triggered. Open 'Security' in dashboard for results."
                }
                securityRow("SSL Pinning Status", icon: "lock.fill", color: .orange) {
                    PhantomLog.info("Security: SSL pinning audit triggered", tag: "Security")
                    auditResult = "SSL pinning status logged. Check Security module."
                }
                securityRow("Sensitive Data in UserDefaults", icon: "eye.slash.fill", color: .red) {
                    // Store some sensitive-looking data to simulate the issue
                    UserDefaults.standard.set("sk_live_abc123xyz_very_secret", forKey: "stripe_api_key")
                    UserDefaults.standard.set("user_super_secret_password", forKey: "cached_password")
                    PhantomLog.warning("Sensitive keys stored in UserDefaults — security risk!", tag: "Security")
                    auditResult = "⚠️ Sensitive data injected into UserDefaults. Open Storage + Security to inspect."
                }
                securityRow("Clear Sensitive Data", icon: "trash.fill", color: .gray) {
                    UserDefaults.standard.removeObject(forKey: "stripe_api_key")
                    UserDefaults.standard.removeObject(forKey: "cached_password")
                    PhantomLog.info("Sensitive UserDefaults keys cleared", tag: "Security")
                    auditResult = "Sensitive data cleared from UserDefaults."
                }
                securityRow("Debug Mode Check", icon: "ant.fill", color: .purple) {
                    #if DEBUG
                    PhantomLog.warning("App running in DEBUG mode — not suitable for production", tag: "Security")
                    auditResult = "DEBUG mode active. Security module will flag this."
                    #else
                    PhantomLog.info("App running in RELEASE mode", tag: "Security")
                    auditResult = "RELEASE mode confirmed."
                    #endif
                }
            }

            Section(header: Text("🌍 Environment Info")) {
                infoRow("Environment", value: "Development")
                infoRow("Configuration", value: "Debug (#if DEBUG active)")
                infoRow("Bundle ID", value: Bundle.main.bundleIdentifier ?? "Unknown")
                infoRow("OS Version", value: UIDevice.current.systemVersion)
                infoRow("Device Model", value: UIDevice.current.model)
                infoRow("PhantomSwift", value: "All 21 modules active")
            }

            if !auditResult.isEmpty {
                Section(header: Text("📋 Last Result")) {
                    Text(auditResult).font(.caption).foregroundColor(.secondary)
                }
            }

            Section {
                InfoRow(icon: "info.circle.fill", text: "Open 'Security' in dashboard for the full security audit report with scores.", color: .red)
            }
        }
        .navigationTitle("Security Audit")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
    }

    private func securityRow(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption.bold()).lineLimit(1)
        }
    }
}

// MARK: - Environment & GPS Demo
struct EnvironmentDemoView: View {
    var body: some View {
        List {
            Section(header: Text("ℹ️ Environment Dashboard")) {
                Text("The Environment module lets you spoof GPS location, change locale/language, and monitor system health (battery, thermal) without leaving the app.")
                    .font(.caption).foregroundColor(.secondary)
            }

            Section(header: Text("📍 GPS Spoofing")) {
                Text("Open Phantom dashboard → 'Environment' → 'GPS Spoof Mode' to set a custom latitude/longitude.")
                    .font(.caption).foregroundColor(.secondary)
                Button("Log: Simulate NYC Location Check") {
                    PhantomLog.debug("GPS spoof test: requesting CLLocationManager auth", tag: "Environment")
                    PhantomLog.info("Spoofed location: lat=40.7128, lon=-74.0060 (New York)", tag: "Environment")
                }
                .foregroundColor(.phantomCyan)
                Button("Log: Simulate Tokyo Location") {
                    PhantomLog.info("Spoofed location: lat=35.6762, lon=139.6503 (Tokyo)", tag: "Environment")
                }
                .foregroundColor(.phantomCyan)
            }

            Section(header: Text("🌐 Locale Simulation")) {
                Text("Change locale in dashboard → Environment → 'Change Locale'. Check results by observing date/number formatting in your app.")
                    .font(.caption).foregroundColor(.secondary)
                Group {
                    localeRow("en-US", flag: "🇺🇸")
                    localeRow("ja-JP", flag: "🇯🇵")
                    localeRow("ar-SA", flag: "🇸🇦 RTL")
                    localeRow("de-DE", flag: "🇩🇪")
                }
            }

            Section(header: Text("📊 System Health")) {
                infoRow("Battery Level", value: "\(Int(UIDevice.current.batteryLevel * 100 == -100 ? 100 : UIDevice.current.batteryLevel * 100))%")
                infoRow("Device Model", value: UIDevice.current.model)
                infoRow("System Name", value: UIDevice.current.systemName)
                infoRow("System Version", value: UIDevice.current.systemVersion)
            }

            Section {
                InfoRow(icon: "info.circle.fill", text: "Open 'Environment' in dashboard for live GPS spoof toggle, locale picker, and battery/thermal monitor.", color: .phantomCyan)
            }
        }
        .navigationTitle("Environment & GPS")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
        }
    }

    private func localeRow(_ locale: String, flag: String) -> some View {
        Button("\(flag) Set locale to \(locale)") {
            PhantomLog.info("Locale simulation: \(locale)", tag: "Environment")
        }
        .font(.system(size: 13))
        .foregroundColor(.primary)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption.bold())
        }
    }
}



// MARK: - Extension Sidekick Demo
struct ExtensionSidekickDemoView: View {
    var body: some View {
        List {
            Section(header: Text("🧩 Extension Sidekick")) {
                Text("Extension Sidekick captures logs from App Extensions (Widgets, Share Extensions, Notification Service Extensions) that normally can't communicate with the main app.")
                    .font(.caption).foregroundColor(.secondary)
            }

            Section(header: Text("📋 How It Works")) {
                VStack(alignment: .leading, spacing: 10) {
                    stepRow("1", text: "Add PhantomSwift to your App Extension target")
                    stepRow("2", text: "Use PhantomLog (or OSLog) in your extension")
                    stepRow("3", text: "Logs are shared via App Group UserDefaults")
                    stepRow("4", text: "View them in 'Extension Sidekick' in the dashboard")
                }
                .padding(.vertical, 4)
            }

            Section(header: Text("🧪 Simulate Extension Log")) {
                Button("Simulate Widget Log Entry") {
                    // Simulate what an extension would write to shared UserDefaults
                    let defaults = UserDefaults(suiteName: Bundle.main.bundleIdentifier)
                    defaults?.set("[Widget] Timeline refreshed — 3 entries", forKey: "phantom_ext_log_\(Date().timeIntervalSince1970)")
                    PhantomLog.debug("Simulated widget log entry written", tag: "ExtensionSidekick")
                }
                .foregroundColor(.blue)
                Button("Simulate Share Extension Log") {
                    PhantomLog.info("Simulated Share Extension: user shared URL to PhantomKit", tag: "ExtensionSidekick")
                }
                .foregroundColor(.blue)
            }

            Section(header: Text("⚙️ Setup Required")) {
                Text("Extension Sidekick requires App Groups. Add 'com.yourapp.group' to both your main app and extension targets in Xcode Signing & Capabilities.")
                    .font(.caption).foregroundColor(.secondary)
            }

            Section {
                InfoRow(icon: "info.circle.fill", text: "Open 'Extension Sidekick' in the dashboard to view cross-process logs.", color: .phantomBrown)
            }
        }
        .navigationTitle("Extension Sidekick")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
    }

    private func stepRow(_ number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption.bold())
                .frame(width: 20, height: 20)
                .background(Color.phantomBrown.opacity(0.2))
                .clipShape(Circle())
            Text(text).font(.caption).foregroundColor(.secondary)
        }
    }
}
