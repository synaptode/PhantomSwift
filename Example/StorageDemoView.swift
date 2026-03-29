import SwiftUI
import Foundation
import PhantomSwift

// MARK: - Storage Inspector Demo
struct StorageDemoView: View {
    @State private var key = ""
    @State private var value = ""
    @State private var savedPairs: [(String, String)] = []

    let presetKeys = [
        ("username", "PhantomUser_Demo"),
        ("notifications_enabled", "true"),
        ("app_launch_count", "42"),
        ("preferred_locale", "en-US"),
        ("theme_preference", "dark")
    ]

    var body: some View {
        List {
            Section(header: Text("📝 Write UserDefaults")) {
                TextField("Key", text: $key)
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
                TextField("Value", text: $value)
                    .autocorrectionDisabled()
                Button("Save Value") {
                    guard !key.isEmpty else { return }
                    UserDefaults.standard.set(value, forKey: key)
                    savedPairs.append((key, value))
                    PhantomLog.info("UserDefaults set: \(key) = \(value)", tag: "Storage")
                    key = ""; value = ""
                }
                .disabled(key.isEmpty)
            }

            Section(header: Text("⚡ Quick Presets")) {
                ForEach(presetKeys, id: \.0) { pair in
                    Button("Set \(pair.0) = \"\(pair.1)\"") {
                        UserDefaults.standard.set(pair.1, forKey: pair.0)
                        PhantomLog.debug("Preset saved: \(pair.0) = \(pair.1)", tag: "Storage")
                    }
                    .foregroundColor(.blue)
                    .font(.system(size: 13))
                }
            }

            Section(header: Text("📂 File System")) {
                Button("Write Test File to Documents") {
                    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("phantom_demo_\(Date().timeIntervalSince1970).txt")
                    let content = "PhantomSwift Storage Demo — \(Date())"
                    try? content.write(to: url, atomically: true, encoding: .utf8)
                    PhantomLog.info("Test file written: \(url.lastPathComponent)", tag: "Storage")
                }
                Button("Write JSON Data File") {
                    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("phantom_data.json")
                    let json = ["app": "PhantomSwift", "version": "1.0", "timestamp": Date().description]
                    if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
                        try? data.write(to: url)
                    }
                    PhantomLog.info("JSON data file written", tag: "Storage")
                }
            }

            Section(header: Text("🧹 Cleanup")) {
                Button("Delete All UserDefaults") {
                    UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "com.phantomswift.Example")
                    savedPairs.removeAll()
                    PhantomLog.warning("All UserDefaults deleted", tag: "Storage")
                }
                .foregroundColor(.red)
            }

            Section(footer: Text("Open 'Storage' in the PhantomSwift dashboard to browse all UserDefaults, files, and SQLite databases in real-time.")) {
                EmptyView()
            }
        }
        .navigationTitle("Storage Inspector")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
    }
}

// MARK: - State Snapshot Demo
struct SnapshotDemoView: View {
    @State private var snapshots: [PhantomSnapshot] = []
    @State private var lastAction = ""

    var body: some View {
        List {
            Section(header: Text("ℹ️ State Snapshot")) {
                Text("Saves all UserDefaults to a named snapshot. You can restore any past state with one tap — great for testing different app configurations.")
                    .font(.caption).foregroundColor(.secondary)
            }

            Section(header: Text("📸 Capture")) {
                Button("Save Current State as 'Clean Baseline'") {
                    let s = PhantomSnapshotManager.shared.saveCurrentState(name: "Clean Baseline")
                    lastAction = "Saved: \(s.name)"
                    loadSnapshots()
                    PhantomLog.info("State snapshot saved: Clean Baseline", tag: "Snapshot")
                }
                .foregroundColor(.blue)

                Button("Save as 'After Login'") {
                    UserDefaults.standard.set("logged_in", forKey: "auth_state")
                    UserDefaults.standard.set("user_abc123", forKey: "user_id")
                    let s = PhantomSnapshotManager.shared.saveCurrentState(name: "After Login")
                    lastAction = "Saved: \(s.name)"
                    loadSnapshots()
                    PhantomLog.info("State snapshot saved: After Login", tag: "Snapshot")
                }
                .foregroundColor(.green)

                Button("Save as 'Premium User'") {
                    UserDefaults.standard.set("premium", forKey: "subscription_tier")
                    UserDefaults.standard.set(true, forKey: "premium_features_enabled")
                    let s = PhantomSnapshotManager.shared.saveCurrentState(name: "Premium User")
                    lastAction = "Saved: \(s.name)"
                    loadSnapshots()
                    PhantomLog.info("State snapshot saved: Premium User", tag: "Snapshot")
                }
                .foregroundColor(.purple)
            }

            if !snapshots.isEmpty {
                Section(header: Text("📋 Saved Snapshots (\(snapshots.count))")) {
                    ForEach(snapshots) { snapshot in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.name)
                                .font(.system(size: 14, weight: .semibold))
                            Text("\(snapshot.userDefaults.count) keys • \(formattedDate(snapshot.timestamp))")
                                .font(.caption2).foregroundColor(.secondary)
                            HStack {
                                Button("♻️ Restore") {
                                    PhantomSnapshotManager.shared.restore(snapshot: snapshot)
                                    lastAction = "Restored: \(snapshot.name)"
                                    PhantomLog.info("State restored from snapshot: \(snapshot.name)", tag: "Snapshot")
                                }
                                .font(.caption).foregroundColor(.blue)
                                Spacer()
                                Button("🗑 Delete") {
                                    PhantomSnapshotManager.shared.delete(id: snapshot.id)
                                    loadSnapshots()
                                    PhantomLog.info("Snapshot deleted: \(snapshot.name)", tag: "Snapshot")
                                }
                                .font(.caption).foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if !lastAction.isEmpty {
                Section {
                    Text("✅ \(lastAction)").font(.caption).foregroundColor(.green)
                }
            }

            Section {
                InfoRow(icon: "info.circle.fill", text: "Open 'State Snapshot' in the dashboard to manage and time-travel through app states.", color: .phantomMint)
            }
        }
        .navigationTitle("State Snapshot")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
        .onAppear { loadSnapshots() }
    }

    private func loadSnapshots() {
        snapshots = PhantomSnapshotManager.shared.getAllSnapshots()
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .medium
        f.dateStyle = .short
        return f.string(from: date)
    }
}
