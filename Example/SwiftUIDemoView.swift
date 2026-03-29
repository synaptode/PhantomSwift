import SwiftUI
import PhantomSwift

// MARK: - SwiftUI Render Tracker Demo
struct SwiftUIDemoView: View {
    @State private var renderCount = 0
    @State private var timerCount = 0
    @State private var localState = "tap_me"
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: Render Tracker
                GroupBox(label: Label("Render Tracker", systemImage: "atom")) {
                    VStack(spacing: 8) {
                        Text("View re-renders: \(renderCount)")
                            .font(.title2.bold())
                        Text("Timer ticks: \(timerCount)")
                            .font(.caption).foregroundColor(.secondary)
                        Text("This view is tracked as 'TimerView'. Change state to trigger re-renders.")
                            .font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
                        HStack {
                            Button("Force Re-render") {
                                localState = UUID().uuidString
                                renderCount += 1
                                PhantomLog.verbose("Manual re-render triggered", tag: "SwiftUI")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(8)
                            Button("Render ×10") {
                                for i in 0..<10 {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                                        localState = UUID().uuidString
                                        renderCount += 1
                                    }
                                }
                                PhantomLog.debug("Triggered 10 rapid re-renders", tag: "SwiftUI")
                            }
                            .foregroundColor(.orange)
                        }
                    }
                    .padding(.top, 4)
                }
                .trackRender(as: "TimerView")

                // MARK: Accessibility Issues (Intentional)
                GroupBox(label: Label("Accessibility Issues (Intentional)", systemImage: "figure.roll")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Elements below have intentional accessibility problems. Use 'Accessibility Audit' in Phantom to detect them.")
                            .font(.caption2).foregroundColor(.secondary)

                        // No accessibility label on interactive image
                        HStack {
                            Image(systemName: "hand.thumbsup.fill")
                                .resizable().frame(width: 22, height: 22)
                                .padding(8)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(6)
                                .onTapGesture { PhantomLog.debug("Unlabeled image tapped", tag: "A11y") }
                            Text("← No accessibilityLabel")
                                .font(.caption).foregroundColor(.orange)
                        }

                        // Small touch target
                        HStack {
                            Button("Sm") {}
                                .frame(width: 20, height: 20)
                                .background(Color.red)
                                .cornerRadius(4)
                            Text("← Touch target 20×20 (< 44pt min)")
                                .font(.caption).foregroundColor(.orange)
                        }

                        // Low contrast text (intentional)
                        HStack {
                            Text("Low contrast text")
                                .foregroundColor(.white.opacity(0.25))
                                .font(.caption)
                                .padding(6)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(4)
                            Text("← Low contrast").font(.caption).foregroundColor(.orange)
                        }
                    }
                    .padding(.top, 4)
                }

                // MARK: State observation note
                GroupBox(label: Label("State Observation", systemImage: "eye")) {
                    Text("The `.trackRender(as:)` modifier above hooks into PhantomSwift's SwiftUI tracker. Open 'SwiftUI' module in the dashboard to see how often each view renders.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("SwiftUI Render Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in
            timerCount += 1
            renderCount += 1
        }
    }
}

// MARK: - UI Inspector Demo
struct UIInspectorDemoView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GroupBox(label: Label("What is UI Inspector?", systemImage: "view.3d")) {
                    Text("The UI Inspector lets you tap any view in your app to inspect its properties, constraints, and hierarchy without leaving the app.")
                        .font(.caption).foregroundColor(.secondary)
                }

                GroupBox(label: Label("How to Use", systemImage: "hand.point.up.left.fill")) {
                    VStack(alignment: .leading, spacing: 8) {
                        stepRow("1", text: "Open Phantom dashboard (shake or floating button)")
                        stepRow("2", text: "Tap 'UI Inspector'")
                        stepRow("3", text: "The dashboard closes automatically")
                        stepRow("4", text: "Tap any view on screen to inspect it")
                        stepRow("5", text: "View frame, color, constraints, and full hierarchy")
                    }
                    .padding(.top, 4)
                }

                GroupBox(label: Label("Sample UI to Inspect", systemImage: "rectangle.3.group")) {
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            ForEach(0..<3) { i in
                                RoundedRectangle(cornerRadius: 10)
                                    .fill([Color.blue, Color.green, Color.purple][i].opacity(0.3))
                                    .frame(height: 60)
                                    .overlay(Text("View \(i+1)").font(.caption))
                            }
                        }
                        HStack {
                            Circle().fill(Color.red.opacity(0.3)).frame(width: 50, height: 50)
                            VStack(alignment: .leading) {
                                Text("Label Text").font(.headline)
                                Text("Subtitle text").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
        }
        .navigationTitle("UI Inspector")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stepRow(_ number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption.bold())
                .frame(width: 20, height: 20)
                .background(Color.purple.opacity(0.2))
                .clipShape(Circle())
            Text(text).font(.caption).foregroundColor(.secondary)
        }
    }
}

// MARK: - Asset Inspector Demo
struct AssetInspectorDemoView: View {
    @State private var loadedImages: [String] = []

    let imageURLs = [
        "https://picsum.photos/200/200",
        "https://picsum.photos/400/400",
        "https://picsum.photos/800/600",
        "https://picsum.photos/1200/900"
    ]

    var body: some View {
        List {
            Section(header: Text("ℹ️ Asset Inspector")) {
                Text("Detects oversized images, wrong content mode, and memory usage. Load images below and then open 'Asset Inspector' in the dashboard to audit them.")
                    .font(.caption).foregroundColor(.secondary)
            }

            Section(header: Text("🖼 Load Test Images")) {
                ForEach(imageURLs, id: \.self) { url in
                    Button("Load Image (\(imageSize(url)))") {
                        loadedImages.append(url)
                        PhantomLog.info("Loading image: \(url)", tag: "AssetInspector")
                    }
                    .foregroundColor(.blue)
                }
                Button("Load All Images") {
                    loadedImages = imageURLs
                    PhantomLog.warning("Loading all test images — check Asset Inspector for memory usage", tag: "AssetInspector")
                }
                .foregroundColor(.orange)
            }

            if !loadedImages.isEmpty {
                Section(header: Text("📷 Loaded Images (\(loadedImages.count))")) {
                    ForEach(loadedImages, id: \.self) { url in
                        VStack {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("Image Loading (iOS 15+ only)").font(.caption2).foregroundColor(.secondary)
                            Text(url).font(.system(size: 8)).foregroundColor(.secondary).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    }
                    Button("Clear Images") {
                        loadedImages.removeAll()
                        PhantomLog.info("Test images cleared", tag: "AssetInspector")
                    }
                    .foregroundColor(.red)
                }
            }

            Section {
                InfoRow(icon: "info.circle.fill", text: "Open 'Asset Inspector' in dashboard after loading images to see memory audit.", color: .pink)
            }
        }
        .navigationTitle("Asset Inspector")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
    }

    private func imageSize(_ url: String) -> String {
        if url.contains("200/200") { return "200×200" }
        if url.contains("400/400") { return "400×400" }
        if url.contains("800/600") { return "800×600" }
        return "1200×900 (heavy)"
    }
}

// MARK: - Accessibility Demo
struct AccessibilityDemoView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GroupBox(label: Label("Accessibility Auditor", systemImage: "figure.roll")) {
                    Text("The accessibility auditor scans the view hierarchy for:\n• Missing accessibility labels on interactive elements\n• Touch targets smaller than 44pt\n• Low contrast text (coming soon)")
                        .font(.caption).foregroundColor(.secondary)
                        .padding(.top, 4)
                }

                GroupBox(label: Label("Intentional Issues Below", systemImage: "exclamationmark.triangle.fill")) {
                    VStack(spacing: 12) {
                        // Issue 1: Button with no label
                        HStack {
                            Button(action: {}) {
                                Image(systemName: "star.fill")
                                    .padding(6)
                                    .background(Color.yellow.opacity(0.3))
                                    .cornerRadius(6)
                            }
                            Text("← No accessibility label (button)")
                                .font(.caption).foregroundColor(.orange)
                        }

                        // Issue 2: Small touch target
                        HStack {
                            Button("X") {}
                                .frame(width: 15, height: 15)
                                .background(Color.red.opacity(0.8))
                            Text("← 15×15pt touch target")
                                .font(.caption).foregroundColor(.orange)
                        }

                        // Issue 3: Correct element for comparison
                        HStack {
                            Button("Add to Cart") {}
                                .frame(minWidth: 44, minHeight: 44)
                                .background(Color.green.opacity(0.3))
                                .cornerRadius(8)
                                .accessibilityLabel("Add item to shopping cart")
                            Text("← ✅ Correct")
                                .font(.caption).foregroundColor(.green)
                        }
                    }
                    .padding(.top, 4)
                }

                GroupBox(label: Label("How to Audit", systemImage: "info.circle")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. Open Phantom dashboard")
                        Text("2. Tap 'Accessibility Audit'")
                        Text("3. Tap 'Re-Audit' to scan current screen")
                        Text("4. Tap any issue to highlight the problematic view")
                    }
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.top, 4)
                }
            }
            .padding()
        }
        .navigationTitle("Accessibility Audit")
        .navigationBarTitleDisplayMode(.inline)
    }
}
