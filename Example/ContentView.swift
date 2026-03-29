import SwiftUI
import PhantomSwift

struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                // MARK: - Header Banner
                Section {
                    PhantomBannerView()
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                // MARK: - 1. Network & Interceptor
                Section(header: categoryHeader("🌐 Network & API", color: .blue)) {
                    demoRow("Network Monitor", icon: "network", color: .blue, subtitle: "Monitor all HTTP traffic in real-time") {
                        NetworkDemoView()
                    }
                    demoRow("Interceptor & Mocking", icon: "bolt.shield.fill", color: .phantomIndigo, subtitle: "Mock, block, redirect, delay requests") {
                        InterceptorDemoView()
                    }
                    demoRow("Bad Network Simulation", icon: "wifi.exclamationmark", color: .orange, subtitle: "Simulate 3G, offline, packet loss") {
                        BadNetworkDemoView()
                    }
                }

                // MARK: - 2. Performance & Memory
                Section(header: categoryHeader("⚡ Performance & Memory", color: .orange)) {
                    demoRow("Performance Monitor", icon: "gauge.medium", color: .orange, subtitle: "CPU, FPS, memory timeline graphs") {
                        PerformanceDemoView()
                    }
                    demoRow("Hang Detector", icon: "hand.raised.slash.fill", color: .red, subtitle: "Detect main-thread freezes > 400ms") {
                        HangDetectorDemoView()
                    }
                    demoRow("Memory Leak Tracker", icon: "drop.triangle.fill", color: .red, subtitle: "Track and detect retain cycles") {
                        MemoryLeakDemoView()
                    }
                }

                // MARK: - 3. Storage & State
                Section(header: categoryHeader("🗄 Storage & State", color: .green)) {
                    demoRow("Storage Inspector", icon: "archivebox.fill", color: .green, subtitle: "Browse UserDefaults, files, SQLite") {
                        StorageDemoView()
                    }
                    demoRow("State Snapshot", icon: "clock.arrow.2.circlepath", color: .phantomMint, subtitle: "Save & restore full app state") {
                        SnapshotDemoView()
                    }
                }

                // MARK: - 4. UI & SwiftUI
                Section(header: categoryHeader("🎨 UI & SwiftUI", color: .pink)) {
                    demoRow("SwiftUI Render Tracker", icon: "atom", color: .pink, subtitle: "Track re-render frequency per view") {
                        SwiftUIDemoView()
                    }
                    demoRow("UI Inspector", icon: "view.3d", color: .purple, subtitle: "Tap to inspect any view hierarchy") {
                        UIInspectorDemoView()
                    }
                    demoRow("Asset Inspector", icon: "photo.fill.on.rectangle.fill", color: .pink, subtitle: "Audit image memory and sizing") {
                        AssetInspectorDemoView()
                    }
                    demoRow("Accessibility Audit", icon: "figure.roll", color: .phantomTeal, subtitle: "Find missing labels, small targets") {
                        AccessibilityDemoView()
                    }
                }

                // MARK: - 5. Dev Toolkit
                Section(header: categoryHeader("🛠 Dev Toolkit", color: .gray)) {
                    demoRow("Console Logger", icon: "terminal.fill", color: .gray, subtitle: "Log all levels with tags & metadata") {
                        LoggerDemoView()
                    }
                    demoRow("Analytics Interceptor", icon: "chart.bar.doc.horizontal.fill", color: .blue, subtitle: "Track & inspect events (Firebase, etc.)") {
                        AnalyticsDemoView()
                    }
                    demoRow("QA Toolkit", icon: "ant.fill", color: .orange, subtitle: "Bug reporter, shortcuts, flow recorder") {
                        QADemoView()
                    }
                    demoRow("Security Audit", icon: "lock.shield.fill", color: .red, subtitle: "Jailbreak, SSL, app integrity checks") {
                        SecurityDemoView()
                    }
                    demoRow("Environment & GPS", icon: "globe", color: .phantomCyan, subtitle: "Spoof locale, GPS, system health") {
                        EnvironmentDemoView()
                    }
                    demoRow("Extension Sidekick", icon: "puzzlepiece.fill", color: .phantomBrown, subtitle: "Cross-process logs from widgets") {
                        ExtensionSidekickDemoView()
                    }
                }

                // MARK: - Tips
                Section(header: Text("💡 How to Open PhantomSwift")) {
                    HStack(spacing: 12) {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .foregroundColor(.secondary)
                        Text("Shake device  /  ⌘+⌃+Z in Simulator")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("PhantomSwift Demo")
            .navigationBarTitleDisplayMode(.large)
            .listStyle(InsetGroupedListStyle())
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func demoRow<Destination: View>(_ title: String, icon: String, color: Color, subtitle: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func categoryHeader(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(color)
            .textCase(nil)
    }
}

// MARK: - Banner View

struct PhantomBannerView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.85), Color.blue.opacity(0.7)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    Text("PHANTOM SWIFT")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(2)
                }
                Text("Developer Suite — 20 Premium Modules Active")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(8)
            }
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(14)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
