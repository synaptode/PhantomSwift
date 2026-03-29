import SwiftUI
import PhantomSwift

// MARK: - Network Monitor Demo
struct NetworkDemoView: View {
    @State private var results: [String] = []
    @State private var isLoading = false
    @State private var lastStatus = ""

    var body: some View {
        List {
            Section(header: Text("✅ Success Requests")) {
                demoButton("GET Products (200 OK)", color: .green) { fetchProducts() }
                demoButton("GET User Profile (200 OK)", color: .green) { fetchUser() }
                demoButton("POST Add to Cart (201 Created)", color: .blue) { postAddCart() }
            }

            Section(header: Text("⚠️ Error Requests")) {
                demoButton("GET 404 Not Found", color: .orange) { trigger404() }
                demoButton("GET 401 Unauthorized", color: .orange) { trigger401() }
                demoButton("GET 500 Server Error", color: .red) { trigger500() }
            }

            Section(header: Text("🔁 Concurrent Requests")) {
                demoButton("Fire 5 Requests Simultaneously", color: .purple) { fireConcurrent() }
            }

            if isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text(" Loading...").foregroundColor(.secondary)
                    }
                }
            }

            if !results.isEmpty {
                Section(header: Text("📥 Results")) {
                    ForEach(results, id: \.self) { r in
                        Text(r).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Network Monitor")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
        .overlay(
            Group {
                if !lastStatus.isEmpty {
                    Text(lastStatus)
                        .font(.caption)
                        .padding(8)
                        .background(Color(.secondarySystemBackground).opacity(0.9))
                        .cornerRadius(8)
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            },
            alignment: .bottom
        )
    }

    private func fetchProducts() {
        isLoading = true
        PhantomLog.info("Fetching products list", tag: "Network")
        URLSession.shared.dataTask(with: URL(string: "https://dummyjson.com/products?limit=5")!) { data, resp, _ in
            DispatchQueue.main.async {
                isLoading = false
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let products = json["products"] as? [[String: Any]] {
                    results = products.compactMap { "• \($0["title"] as? String ?? "")" }
                }
                lastStatus = "GET /products → \(code) OK"
                PhantomLog.info("Products fetched successfully — \(code)", tag: "Network")
            }
        }.resume()
    }

    private func fetchUser() {
        PhantomLog.info("Fetching user profile", tag: "Network")
        URLSession.shared.dataTask(with: URL(string: "https://dummyjson.com/users/1")!) { _, resp, _ in
            DispatchQueue.main.async {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                lastStatus = "GET /users/1 → \(code)"
                results = ["User fetched. Check Network module in dashboard."]
                PhantomLog.debug("User profile response: \(code)", tag: "Network")
            }
        }.resume()
    }

    private func postAddCart() {
        var req = URLRequest(url: URL(string: "https://dummyjson.com/carts/add")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["userId": 1, "products": [["id": 1, "quantity": 1]]])
        PhantomLog.info("POST add to cart", tag: "Network")
        URLSession.shared.dataTask(with: req) { _, resp, _ in
            DispatchQueue.main.async {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                lastStatus = "POST /carts/add → \(code)"
                results = ["Cart POST fired. Check Network module."]
                PhantomLog.info("Add to cart → \(code)", tag: "Network")
            }
        }.resume()
    }

    private func trigger404() {
        PhantomLog.warning("Triggering intentional 404", tag: "Network")
        URLSession.shared.dataTask(with: URL(string: "https://dummyjson.com/this-does-not-exist")!) { _, resp, _ in
            DispatchQueue.main.async {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                lastStatus = "GET /invalid → \(code)"
                results = ["404 triggered. Check Network module for AI analysis."]
                PhantomLog.error("404 Not Found on /invalid-endpoint", tag: "Network")
            }
        }.resume()
    }

    private func trigger401() {
        var req = URLRequest(url: URL(string: "https://dummyjson.com/auth/me")!)
        req.setValue("Bearer invalid_token_here", forHTTPHeaderField: "Authorization")
        PhantomLog.warning("Triggering 401 — invalid token", tag: "Network")
        URLSession.shared.dataTask(with: req) { _, resp, _ in
            DispatchQueue.main.async {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                lastStatus = "GET /auth/me → \(code)"
                results = ["401 triggered. Check Network module in dashboard."]
                PhantomLog.error("Unauthorized — token invalid", tag: "Auth")
            }
        }.resume()
    }

    private func trigger500() {
        PhantomLog.error("Triggering server error scenario", tag: "Network")
        URLSession.shared.dataTask(with: URL(string: "https://httpstat.us/500")!) { _, resp, _ in
            DispatchQueue.main.async {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                lastStatus = "GET httpstat.us/500 → \(code)"
                results = ["Server error triggered. Check Network module."]
                PhantomLog.critical("Server returned 500 Internal Server Error", tag: "Network")
            }
        }.resume()
    }

    private func fireConcurrent() {
        let urls = [
            "https://dummyjson.com/products/1",
            "https://dummyjson.com/products/2",
            "https://dummyjson.com/users/1",
            "https://dummyjson.com/posts/1",
            "https://dummyjson.com/todos/1"
        ]
        isLoading = true
        results = []
        PhantomLog.info("Firing \(urls.count) concurrent requests", tag: "Network")
        let group = DispatchGroup()
        for url in urls {
            group.enter()
            URLSession.shared.dataTask(with: URL(string: url)!) { _, _, _ in group.leave() }.resume()
        }
        group.notify(queue: .main) {
            isLoading = false
            results = urls.map { "✓ \($0.components(separatedBy: "/").last ?? "")" }
            lastStatus = "5 concurrent requests complete"
            PhantomLog.info("All concurrent requests completed", tag: "Network")
        }
    }

    private func demoButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(color.opacity(0.7))
            }
        }
        .foregroundColor(.primary)
    }
}

// MARK: - Interceptor Demo
struct InterceptorDemoView: View {
    @State private var resultText = "Tap a button to test interception."
    @State private var activeRuleLabel = "None active"

    var body: some View {
        List {
            Section(header: Text("🎭 Mock Response")) {
                Text("A mock rule for /products/999 is pre-loaded at app launch.")
                    .font(.caption).foregroundColor(.secondary)
                Button("GET /products/999 (Returns Mock)") { fetchMocked() }
                    .foregroundColor(.phantomIndigo)
            }

            Section(header: Text("🚫 Block Request")) {
                Button("Block /posts Endpoint") { blockPosts() }
                    .foregroundColor(.red)
                Button("Remove Block Rule") { clearRules() }
                    .foregroundColor(.gray)
            }

            Section(header: Text("⏱ Delay Request")) {
                Button("Delay /todos by 2 seconds") { delayRequest() }
                    .foregroundColor(.orange)
            }

            Section(header: Text("📤 Redirect Request")) {
                Button("Redirect /products/1 → /products/2") { redirectRequest() }
                    .foregroundColor(.purple)
            }

            Section(header: Text("📋 Active Rule")) {
                Text(activeRuleLabel)
                    .font(.caption).foregroundColor(.secondary)
            }

            Section(header: Text("📥 Result")) {
                Text(resultText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Interceptor & Mocking")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
    }

    private func fetchMocked() {
        resultText = "Fetching mocked response..."
        activeRuleLabel = "mockResponse → /products/999"
        PhantomLog.debug("Fetching mocked endpoint /products/999", tag: "Interceptor")
        URLSession.shared.dataTask(with: URL(string: "https://dummyjson.com/products/999")!) { data, resp, _ in
            DispatchQueue.main.async {
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let title = json["title"] as? String {
                    resultText = "✅ Response: \"\(title)\" (HTTP \(code)) — From mock, not real server!"
                } else {
                    resultText = "Data received — HTTP \(code). Check Interceptor module."
                }
                PhantomLog.info("Mock response received → HTTP \(code)", tag: "Interceptor")
            }
        }.resume()
    }

    private func blockPosts() {
        PhantomInterceptor.shared.clear()
        PhantomInterceptor.shared.add(rule: .block(urlPattern: "dummyjson.com/posts"))
        activeRuleLabel = "block → /posts"
        resultText = "Block rule added. Fetching /posts..."
        PhantomLog.warning("Block rule added for /posts", tag: "Interceptor")
        URLSession.shared.dataTask(with: URL(string: "https://dummyjson.com/posts")!) { _, _, err in
            DispatchQueue.main.async {
                resultText = err != nil ? "🚫 Blocked! Error: \(err!.localizedDescription)" : "Unexpected success."
                PhantomLog.error("Block rule triggered: \(err?.localizedDescription ?? "No error")", tag: "Interceptor")
            }
        }.resume()
    }

    private func delayRequest() {
        PhantomInterceptor.shared.clear()
        PhantomInterceptor.shared.add(rule: .delay(urlPattern: "dummyjson.com/todos", seconds: 2.0))
        activeRuleLabel = "delay 2s → /todos"
        resultText = "⏱ Fetching /todos with 2s delay..."
        PhantomLog.debug("Delay rule added for /todos", tag: "Interceptor")
        let start = Date()
        URLSession.shared.dataTask(with: URL(string: "https://dummyjson.com/todos/1")!) { _, resp, _ in
            DispatchQueue.main.async {
                let elapsed = Date().timeIntervalSince(start)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                resultText = "✅ Responded in \(String(format: "%.1f", elapsed))s (HTTP \(code)) — delay injected!"
                PhantomLog.info("Delayed request completed in \(String(format: "%.1f", elapsed))s", tag: "Interceptor")
                PhantomInterceptor.shared.clear()
            }
        }.resume()
    }

    private func redirectRequest() {
        PhantomInterceptor.shared.clear()
        PhantomInterceptor.shared.add(rule: .redirect(from: "dummyjson.com/products/1", to: "https://dummyjson.com/products/2"))
        activeRuleLabel = "redirect /products/1 → /products/2"
        resultText = "Fetching /products/1 (will redirect)..."
        PhantomLog.info("Redirect rule: /products/1 → /products/2", tag: "Interceptor")
        URLSession.shared.dataTask(with: URL(string: "https://dummyjson.com/products/1")!) { data, _, _ in
            DispatchQueue.main.async {
                if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let id = json["id"], let title = json["title"] {
                    resultText = "✅ Got product id=\(id) '\(title)' — redirected from id=1 to id=2!"
                } else {
                    resultText = "Response received. Check Interceptor module."
                }
                PhantomLog.info("Redirect complete", tag: "Interceptor")
                PhantomInterceptor.shared.clear()
            }
        }.resume()
    }

    private func clearRules() {
        PhantomInterceptor.shared.clear()
        // Re-seed the default mock
        let mockBody = """
        {"id":999,"title":"[MOCKED] PhantomSwift Product","price":0,"brand":"Phantom","category":"debug"}
        """.data(using: .utf8)
        PhantomInterceptor.shared.add(rule: .mockResponse(
            urlPattern: "dummyjson.com/products/999",
            method: nil,
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: mockBody
        ))
        activeRuleLabel = "Reset to default mock"
        resultText = "Rules cleared. Default mock for /products/999 restored."
        PhantomLog.info("Interceptor rules cleared and reset", tag: "Interceptor")
    }
}

// MARK: - Bad Network Demo
struct BadNetworkDemoView: View {
    @State private var isEnabled = false
    @State private var latency: Double = 0
    @State private var errorRate: Double = 0
    @State private var testResult = ""

    var body: some View {
        List {
            Section(header: Text("🔧 Configuration")) {
                Toggle("Enable Bad Network Simulation", isOn: $isEnabled)
                    .onChange(of: isEnabled) { val in
                        PhantomNetworkSimulator.shared.isEnabled = val
                        PhantomLog.warning(val ? "Bad network enabled" : "Bad network disabled", tag: "BadNetwork")
                    }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Latency")
                        Spacer()
                        Text("\(Int(latency * 1000))ms").foregroundColor(.orange).bold()
                    }
                    Slider(value: $latency, in: 0...5, step: 0.5)
                        .onChange(of: latency) { val in
                            PhantomNetworkSimulator.shared.latency = val
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Error Rate")
                        Spacer()
                        Text("\(Int(errorRate * 100))%").foregroundColor(.red).bold()
                    }
                    Slider(value: $errorRate, in: 0...1, step: 0.1)
                        .onChange(of: errorRate) { val in
                            PhantomNetworkSimulator.shared.errorRate = val
                        }
                }
            }

            Section(header: Text("🚀 Quick Presets")) {
                presetButton("📶 Normal (Off)", latency: 0, error: 0, enabled: false)
                presetButton("🐢 Slow 3G (2s, 0% loss)", latency: 2.0, error: 0, enabled: true)
                presetButton("📡 Flaky (1s, 30% loss)", latency: 1.0, error: 0.3, enabled: true)
                presetButton("⛔ Offline (100% loss)", latency: 0, error: 1.0, enabled: true)
            }

            Section(header: Text("🧪 Test Request")) {
                Button("Fire Test Request Now") { testRequest() }
                    .foregroundColor(.blue)
                if !testResult.isEmpty {
                    Text(testResult)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(footer: Text("Open 'Bad Network' in the PhantomSwift dashboard to control these settings live.")) {
                EmptyView()
            }
        }
        .navigationTitle("Bad Network Simulation")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
        .onAppear {
            isEnabled = PhantomNetworkSimulator.shared.isEnabled
            latency = PhantomNetworkSimulator.shared.latency
            errorRate = PhantomNetworkSimulator.shared.errorRate
        }
    }

    private func presetButton(_ label: String, latency: Double, error: Double, enabled: Bool) -> some View {
        Button(label) {
            self.latency = latency
            self.errorRate = error
            self.isEnabled = enabled
            PhantomNetworkSimulator.shared.isEnabled = enabled
            PhantomNetworkSimulator.shared.latency = latency
            PhantomNetworkSimulator.shared.errorRate = error
            PhantomLog.info("Bad network preset: \(label)", tag: "BadNetwork")
        }
        .foregroundColor(.primary)
    }

    private func testRequest() {
        testResult = "⏱ Sending..."
        let start = Date()
        PhantomLog.info("Test request fired under bad network conditions", tag: "BadNetwork")
        URLSession.shared.dataTask(with: URL(string: "https://dummyjson.com/products/1")!) { _, resp, err in
            DispatchQueue.main.async {
                let elapsed = String(format: "%.2f", Date().timeIntervalSince(start))
                if let err {
                    testResult = "❌ Failed in \(elapsed)s: \(err.localizedDescription)"
                    PhantomLog.error("Test request failed: \(err.localizedDescription)", tag: "BadNetwork")
                } else {
                    let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                    testResult = "✅ Success in \(elapsed)s — HTTP \(code)"
                    PhantomLog.info("Test request success in \(elapsed)s", tag: "BadNetwork")
                }
            }
        }.resume()
    }
}

// MARK: - Session Replay Demo
struct SessionReplayDemoView: View {
    @State private var isRecording = false
    @State private var recordedCount = 0
    @State private var replayStatus = ""
    @State private var isReplaying = false

    var body: some View {
        List {
            Section(header: Text("🎥 Record Session")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(isRecording ? Color.red : Color.secondary.opacity(0.4))
                            .frame(width: 10, height: 10)
                        Text(isRecording ? "Recording in progress..." : "Not recording")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Text("Recorded: \(recordedCount) requests")
                        .font(.caption2).foregroundColor(.secondary)
                }

                Button(isRecording ? "⏹ Stop Recording" : "🔴 Start Recording") {
                    toggleRecording()
                }
                .foregroundColor(isRecording ? .red : .blue)
            }

            Section(header: Text("🌐 Fire Requests to Record")) {
                Button("GET /products (record this)") { fireRequest("https://dummyjson.com/products/1") }
                Button("GET /users (record this)") { fireRequest("https://dummyjson.com/users/1") }
                Button("GET /posts (record this)") { fireRequest("https://dummyjson.com/posts/1") }
            }
            .disabled(!isRecording)
            .foregroundColor(isRecording ? .primary : .secondary)

            Section(header: Text("▶️ Replay")) {
                Button("Replay All Recorded Requests") { startReplay() }
                    .disabled(recordedCount == 0 || isReplaying || isRecording)
                    .foregroundColor(recordedCount > 0 ? .phantomTeal : .secondary)
                if !replayStatus.isEmpty {
                    Text(replayStatus).font(.caption).foregroundColor(.secondary)
                }
            }

            Section(footer: Text("Recording captures all network requests made during the session, then replays them to test consistency.")) {
                EmptyView()
            }
        }
        .navigationTitle("Session Replay")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
    }

    private func toggleRecording() {
        if isRecording {
            PhantomSessionRecorder.shared.stopRecording()
            isRecording = false
            recordedCount = PhantomSessionRecorder.shared.recordedRequests.count
            PhantomLog.info("Session recording stopped — \(recordedCount) requests captured", tag: "SessionReplay")
        } else {
            PhantomSessionRecorder.shared.startRecording()
            isRecording = true
            recordedCount = 0
            replayStatus = ""
            PhantomLog.info("Session recording started", tag: "SessionReplay")
        }
    }

    private func fireRequest(_ urlString: String) {
        URLSession.shared.dataTask(with: URL(string: urlString)!) { _, _, _ in
            DispatchQueue.main.async {
                recordedCount = PhantomSessionRecorder.shared.recordedRequests.count
                PhantomLog.debug("Request recorded: \(urlString)", tag: "SessionReplay")
            }
        }.resume()
    }

    private func startReplay() {
        let requests = PhantomSessionRecorder.shared.recordedRequests
        guard !requests.isEmpty else { return }
        isReplaying = true
        replayStatus = "⏳ Replaying \(requests.count) requests..."
        PhantomLog.info("Replaying \(requests.count) requests", tag: "SessionReplay")
        PhantomSessionReplayer.shared.replay(requests: requests) {
            self.isReplaying = false
            self.replayStatus = "✅ Replay complete — check Network module for duplicates"
            PhantomLog.info("Session replay completed", tag: "SessionReplay")
        }
    }
}
