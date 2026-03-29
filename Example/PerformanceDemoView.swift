import SwiftUI
import PhantomSwift

// MARK: - Performance Monitor Demo
struct PerformanceDemoView: View {
    var body: some View {
        List {
            Section(header: Text("📊 CPU Stress")) {
                demoButton("🚀 Spike CPU — 1 Second", subtitle: "Heavy math loop on main thread", color: .orange) {
                    PhantomLog.warning("CPU stress test starting", tag: "Performance")
                    let start = Date()
                    while Date().timeIntervalSince(start) < 1.0 {
                        _ = sin(Double.random(in: 0...Double.pi)) * cos(Double.random(in: 0...Double.pi))
                    }
                    PhantomLog.info("CPU stress test done", tag: "Performance")
                }
                demoButton("🔥 Spike CPU — 3 Seconds", subtitle: "Sustained heavy load", color: .red) {
                    PhantomLog.warning("CPU 3s stress test starting", tag: "Performance")
                    DispatchQueue.global(qos: .userInitiated).async {
                        let start = Date()
                        while Date().timeIntervalSince(start) < 3.0 {
                            _ = (0...1000).reduce(0.0) { acc, _ in acc + sin(Double.random(in: 0...1)) }
                        }
                        DispatchQueue.main.async {
                            PhantomLog.info("CPU 3s stress done", tag: "Performance")
                        }
                    }
                }
            }

            Section(header: Text("🧵 FPS Drop")) {
                demoButton("🐌 Freeze UI — 200ms (Mild)", subtitle: "Below 400ms threshold", color: .yellow) {
                    PhantomLog.verbose("Mild UI freeze 200ms", tag: "Performance")
                    Thread.sleep(forTimeInterval: 0.2)
                }
                demoButton("🧊 Freeze UI — 600ms (Detected!)", subtitle: "Triggers HangDetector alert", color: .red) {
                    PhantomLog.warning("Intentional 600ms UI freeze", tag: "HangDetector")
                    Thread.sleep(forTimeInterval: 0.6)
                }
            }

            Section(header: Text("💾 Memory Pressure")) {
                demoButton("📦 Allocate 50MB", subtitle: "Create large in-memory buffer", color: .blue) {
                    PhantomLog.info("Allocating 50MB", tag: "Memory")
                    let megabytes = 50
                    var buffer = [UInt8](repeating: 0, count: megabytes * 1024 * 1024)
                    buffer[0] = 1 // Prevent optimization
                    PhantomLog.debug("50MB allocated (will be released)", tag: "Memory")
                    _ = buffer.first  // Keep reference
                }
            }

            Section {
                InfoRow(icon: "info.circle.fill", text: "Open 'Performance' in dashboard to see CPU, FPS, and Memory graphs.", color: .blue)
            }
        }
        .navigationTitle("Performance Monitor")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
    }
}

// MARK: - Hang Detector Demo
struct HangDetectorDemoView: View {
    @State private var hangCount: Int = 0

    var body: some View {
        List {
            Section(header: Text("ℹ️ About Hang Detector")) {
                Text("PhantomSwift monitors the main thread via a watchdog. Any block > 400ms is recorded as a 'Hang Event'.")
                    .font(.caption).foregroundColor(.secondary)
                Text("Hangs detected so far: \(PhantomHangDetector.shared.hangs.count)")
                    .font(.caption).bold()
            }

            Section(header: Text("🧪 Trigger Hangs")) {
                demoButton("⚡ 200ms Hang (Below Threshold)", subtitle: "Will NOT be detected", color: .green) {
                    Thread.sleep(forTimeInterval: 0.2)
                    hangCount = PhantomHangDetector.shared.hangs.count
                    PhantomLog.verbose("200ms sleep — below detection threshold", tag: "HangDetector")
                }
                demoButton("⚠️ 500ms Hang (Detected!)", subtitle: "Will show in Hang Detector", color: .orange) {
                    PhantomLog.warning("Triggering 500ms hang", tag: "HangDetector")
                    Thread.sleep(forTimeInterval: 0.5)
                    hangCount = PhantomHangDetector.shared.hangs.count
                }
                demoButton("🔴 1 Second Hang (Severe)", subtitle: "Longest detectable freeze", color: .red) {
                    PhantomLog.error("Triggering 1s severe hang", tag: "HangDetector")
                    Thread.sleep(forTimeInterval: 1.0)
                    hangCount = PhantomHangDetector.shared.hangs.count
                }
                demoButton("🔄 Sync Heavy File I/O", subtitle: "File read blocking main thread", color: .purple) {
                    PhantomLog.warning("Synchronous file I/O on main thread", tag: "HangDetector")
                    let path = NSTemporaryDirectory() + "phantom_test.txt"
                    let data = String(repeating: "X", count: 100_000).data(using: .utf8)!
                    try? data.write(to: URL(fileURLWithPath: path))
                    _ = try? Data(contentsOf: URL(fileURLWithPath: path))
                    hangCount = PhantomHangDetector.shared.hangs.count
                }
            }

            Section(header: Text("📋 Summary")) {
                Text("Total hangs recorded: \(hangCount)")
                    .foregroundColor(hangCount > 0 ? .red : .green)
                Button("Clear Hang History") {
                    PhantomHangDetector.shared.clearLogs()
                    hangCount = 0
                    PhantomLog.info("Hang history cleared", tag: "HangDetector")
                }
                .foregroundColor(.red)
            }

            Section {
                InfoRow(icon: "info.circle.fill", text: "Open 'Hang Detector' module in dashboard to see detected hangs with call stacks.", color: .orange)
            }
        }
        .navigationTitle("Hang Detector")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
        .onAppear { hangCount = PhantomHangDetector.shared.hangs.count }
    }
}

// MARK: - Memory Leak Demo
struct MemoryLeakDemoView: View {
    @State private var trackedCount = 0
    @State private var leakyObjects: [AnyObject] = [] // Strong ref = intentional "leak"

    var body: some View {
        List {
            Section(header: Text("ℹ️ About Leak Tracker")) {
                Text("PhantomLeakTracker swizzles UIViewController to auto-detect controllers that are not deallocated after dismissal.")
                    .font(.caption).foregroundColor(.secondary)
                Text("PhantomObjectTracker lets you manually track any object to see if it leaks.")
                    .font(.caption).foregroundColor(.secondary)
            }

            Section(header: Text("🩸 Create Leaky Objects")) {
                demoButton("Create 1 Leaky NSObject", subtitle: "Strong-retained → tracked", color: .red) {
                    let obj = NSObject()
                    leakyObjects.append(obj)
                    PhantomObjectTracker.shared.track(obj, name: "LeakyObject_\(leakyObjects.count)")
                    trackedCount = PhantomObjectTracker.shared.trackedObjects.count
                    PhantomLog.warning("Leaky object #\(leakyObjects.count) created and tracked", tag: "MemoryLeak")
                }
                demoButton("Create 5 Leaky Objects", subtitle: "Batch creation", color: .orange) {
                    for i in 1...5 {
                        let obj = NSMutableArray()
                        leakyObjects.append(obj)
                        PhantomObjectTracker.shared.track(obj, name: "BatchLeak_\(i)")
                    }
                    trackedCount = PhantomObjectTracker.shared.trackedObjects.count
                    PhantomLog.warning("5 batch leaky objects created", tag: "MemoryLeak")
                }
                demoButton("Create Retain Cycle", subtitle: "Class A → B → A (circular)", color: .red) {
                    createRetainCycle()
                }
            }

            Section(header: Text("♻️ Release Objects")) {
                demoButton("Release All Leaky Objects", subtitle: "Removes strong references", color: .green) {
                    leakyObjects.removeAll()
                    PhantomObjectTracker.shared.clearDeallocated()
                    trackedCount = PhantomObjectTracker.shared.trackedObjects.count
                    PhantomLog.info("All leaky objects released", tag: "MemoryLeak")
                }
            }

            Section(header: Text("📊 Status")) {
                HStack {
                    Text("Held in memory:")
                    Spacer()
                    Text("\(leakyObjects.count)").bold().foregroundColor(.red)
                }
                HStack {
                    Text("Tracked objects total:")
                    Spacer()
                    Text("\(trackedCount)").bold().foregroundColor(.orange)
                }
            }

            Section {
                InfoRow(icon: "info.circle.fill", text: "Open 'Memory Leak' and 'Memory Graph' in dashboard to inspect tracked objects.", color: .red)
            }
        }
        .navigationTitle("Memory Leak Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
        .onAppear { trackedCount = PhantomObjectTracker.shared.trackedObjects.count }
    }

    private func createRetainCycle() {
        class NodeA {
            var nodeB: NodeB?
            deinit { PhantomLog.debug("NodeA deallocated", tag: "MemoryLeak") }
        }
        class NodeB {
            var nodeA: NodeA?
            deinit { PhantomLog.debug("NodeB deallocated", tag: "MemoryLeak") }
        }
        let a = NodeA()
        let b = NodeB()
        a.nodeB = b
        b.nodeA = a // Retain cycle — neither will ever deallocate
        PhantomObjectTracker.shared.track(a, name: "RetainCycle_NodeA")
        PhantomObjectTracker.shared.track(b, name: "RetainCycle_NodeB")
        leakyObjects.append(contentsOf: [a, b] as [AnyObject])
        trackedCount = PhantomObjectTracker.shared.trackedObjects.count
        PhantomLog.error("Retain cycle created: NodeA ↔ NodeB", tag: "MemoryLeak")
    }
}

// MARK: - Shared Helpers

func demoButton(_ title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundColor(color)
            Text(text).font(.caption).foregroundColor(.secondary)
        }
    }
}
