#if DEBUG
import Foundation
import UIKit
import Network

/// WebSocket-based remote debug server using Network.framework (iOS 13+).
/// Allows controlling PhantomSwift from a browser dashboard.
@available(iOS 13.0, *)
internal final class PhantomRemoteServer {
    internal static let shared = PhantomRemoteServer()

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "com.phantomswift.remote", qos: .userInitiated)
    private let accessQueue = DispatchQueue(label: "com.phantomswift.remote.access", attributes: .concurrent)

    private(set) var isRunning = false
    private(set) var port: UInt16 = 9876

    private init() {}

    // MARK: - Server Lifecycle

    internal func start(port: UInt16 = 9876) {
        guard !isRunning else { return }
        self.port = port

        let params = NWParameters.tcp
        let ws = NWProtocolWebSocket.Options()
        params.defaultProtocolStack.applicationProtocols.insert(ws, at: 0)

        do {
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port) ?? 9876)
        } catch {
            print("⚠️ [PhantomRemote] Failed to create listener: \(error)")
            return
        }

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isRunning = true
                print("🌐 [PhantomRemote] Server ready on port \(port)")
            case .failed(let err):
                self?.isRunning = false
                print("⚠️ [PhantomRemote] Server failed: \(err)")
                self?.stop()
            case .cancelled:
                self?.isRunning = false
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener?.start(queue: queue)
    }

    internal func stop() {
        listener?.cancel()
        accessQueue.async(flags: .barrier) { [weak self] in
            self?.connections.forEach { $0.cancel() }
            self?.connections.removeAll()
        }
        isRunning = false
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        accessQueue.async(flags: .barrier) { [weak self] in
            self?.connections.append(connection)
        }

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveMessage(from: connection)
                self?.sendWelcome(to: connection)
            case .failed, .cancelled:
                self?.removeConnection(connection)
            default:
                break
            }
        }

        connection.start(queue: queue)
    }

    private func removeConnection(_ connection: NWConnection) {
        accessQueue.async(flags: .barrier) { [weak self] in
            self?.connections.removeAll { $0 === connection }
        }
    }

    // MARK: - Send / Receive

    private func sendWelcome(to connection: NWConnection) {
        let welcome: [String: Any] = [
            "type": "welcome",
            "app": Bundle.main.bundleIdentifier ?? "unknown",
            "device": UIDevice.current.name,
            "system": "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            "phantom_version": "1.0.0"
        ]
        sendJSON(welcome, to: connection)
    }

    private func receiveMessage(from connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, _, error in
            guard let self = self else { return }

            if let error = error {
                print("⚠️ [PhantomRemote] Receive error: \(error)")
                return
            }

            if let data = data, let text = String(data: data, encoding: .utf8) {
                self.handleCommand(text, from: connection)
            }

            // Continue receiving
            self.receiveMessage(from: connection)
        }
    }

    private func sendJSON(_ dict: [String: Any], to connection: NWConnection) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "ws", metadata: [metadata])
        connection.send(content: data, contentContext: context, completion: .idempotent)
    }

    internal func broadcast(_ dict: [String: Any]) {
        let conns = accessQueue.sync { connections }
        for conn in conns {
            sendJSON(dict, to: conn)
        }
    }

    // MARK: - Command Routing

    private func handleCommand(_ text: String, from connection: NWConnection) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try JSON command first
        if let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let command = json["command"] as? String {
            executeCommand(command, args: json, connection: connection)
            return
        }

        // Plain text command
        executeCommand(trimmed, args: [:], connection: connection)
    }

    private func executeCommand(_ command: String, args: [String: Any], connection: NWConnection) {
        switch command.lowercased() {

        case "app-info":
            let info: [String: Any] = [
                "type": "response",
                "command": "app-info",
                "data": [
                    "bundle_id": Bundle.main.bundleIdentifier ?? "unknown",
                    "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
                    "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?",
                    "device": UIDevice.current.model,
                    "system": "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
                    "device_name": UIDevice.current.name,
                ]
            ]
            sendJSON(info, to: connection)

        case "system-status":
            let pm = PerformanceMonitor.shared
            let status: [String: Any] = [
                "type": "response",
                "command": "system-status",
                "data": [
                    "fps": pm.currentFPS,
                    "log_count": LogStore.shared.getAll().count,
                    "network_count": PhantomRequestStore.shared.getAll().count,
                    "thread_violations": PhantomMainThreadChecker.shared.violationCount,
                    "feature_flag_overrides": PhantomFeatureFlags.shared.overrideCount,
                ]
            ]
            sendJSON(status, to: connection)

        case "logs", "logs-stream":
            let logs = LogStore.shared.getAll().suffix(50)
            let logData: [[String: Any]] = logs.map {[
                "level": $0.level.name,
                "message": $0.message,
                "tag": $0.tag ?? "",
                "timestamp": ISO8601DateFormatter().string(from: $0.timestamp),
                "file": $0.file,
                "function": $0.function,
                "line": $0.line,
            ]}
            sendJSON([
                "type": "response",
                "command": "logs",
                "data": logData
            ], to: connection)

        case "network-trace":
            let requests = PhantomRequestStore.shared.getAll().prefix(50)
            let reqData: [[String: Any]] = requests.map {[
                "method": $0.method,
                "url": $0.url.absoluteString,
                "status": $0.response?.statusCode ?? 0,
                "duration": $0.response?.duration ?? 0,
                "timestamp": ISO8601DateFormatter().string(from: $0.timestamp),
                "is_mocked": $0.mockoonRedirectedURL != nil,
            ]}
            sendJSON([
                "type": "response",
                "command": "network-trace",
                "data": reqData
            ], to: connection)

        case "feature-flags":
            let flags = PhantomFeatureFlags.shared.allFlagsFlat()
            let flagData: [[String: Any]] = flags.map {[
                "key": $0.key,
                "title": $0.title,
                "default": $0.defaultValue,
                "current": $0.currentValue,
                "overridden": $0.isOverridden,
                "group": $0.group,
            ]}
            sendJSON([
                "type": "response",
                "command": "feature-flags",
                "data": flagData
            ], to: connection)

        case "toggle-flag":
            if let key = args["key"] as? String {
                PhantomFeatureFlags.shared.toggle(key)
                sendJSON([
                    "type": "response",
                    "command": "toggle-flag",
                    "data": ["key": key, "success": true]
                ], to: connection)
            }

        case "clear-logs":
            LogStore.shared.clear()
            sendJSON([
                "type": "response",
                "command": "clear-logs",
                "data": ["success": true]
            ], to: connection)

        case "clear-network":
            PhantomRequestStore.shared.clear()
            sendJSON([
                "type": "response",
                "command": "clear-network",
                "data": ["success": true]
            ], to: connection)

        case "performance":
            let pm = PerformanceMonitor.shared
            let history = pm.history.suffix(30)
            let histData: [[String: Any]] = history.map {[
                "fps": $0.fps,
                "cpu": $0.cpu,
                "ram": $0.ram,
            ]}
            sendJSON([
                "type": "response",
                "command": "performance",
                "data": [
                    "current_fps": pm.currentFPS,
                    "history": histData
                ]
            ], to: connection)

        case "help":
            sendJSON([
                "type": "response",
                "command": "help",
                "data": [
                    "commands": [
                        "app-info", "system-status", "logs", "network-trace",
                        "feature-flags", "toggle-flag", "clear-logs",
                        "clear-network", "performance", "help"
                    ]
                ]
            ], to: connection)

        default:
            sendJSON([
                "type": "error",
                "message": "Unknown command: \(command). Type 'help' for available commands."
            ], to: connection)
        }
    }
}

// MARK: - Remote Server Dashboard VC

@available(iOS 13.0, *)
internal final class RemoteServerDashboardVC: UIViewController {

    private let statusCard = UIView()
    private let statusDot = UIView()
    private let statusLabel = UILabel()
    private let portLabel = UILabel()
    private let ipLabel = UILabel()
    private let toggleButton = UIButton(type: .system)
    private let instructionsLabel = UILabel()
    private var refreshTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Remote Server"
        view.backgroundColor = PhantomTheme.shared.backgroundColor
        setupUI()
        updateStatus()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        refreshTimer?.invalidate()
    }

    private func setupUI() {
        // Status Card
        statusCard.backgroundColor = PhantomTheme.shared.surfaceColor
        statusCard.layer.cornerRadius = 20
        statusCard.layer.cornerCurve = .continuous
        PhantomTheme.shared.applyPremiumShadow(to: statusCard.layer)
        view.addSubview(statusCard)
        statusCard.translatesAutoresizingMaskIntoConstraints = false

        statusDot.layer.cornerRadius = 8
        statusCard.addSubview(statusDot)
        statusDot.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 20, weight: .black)
        statusLabel.textColor = PhantomTheme.shared.textColor
        statusCard.addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        ipLabel.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        ipLabel.textColor = PhantomTheme.shared.primaryColor
        ipLabel.numberOfLines = 0
        statusCard.addSubview(ipLabel)
        ipLabel.translatesAutoresizingMaskIntoConstraints = false

        portLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        portLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        statusCard.addSubview(portLabel)
        portLabel.translatesAutoresizingMaskIntoConstraints = false

        // Toggle Button
        toggleButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        toggleButton.layer.cornerRadius = 16
        toggleButton.layer.cornerCurve = .continuous
        toggleButton.addTarget(self, action: #selector(toggleServer), for: .touchUpInside)
        view.addSubview(toggleButton)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false

        // Instructions
        instructionsLabel.font = .systemFont(ofSize: 13, weight: .regular)
        instructionsLabel.textColor = PhantomTheme.shared.textColor.withAlphaComponent(0.5)
        instructionsLabel.numberOfLines = 0
        instructionsLabel.textAlignment = .center
        instructionsLabel.text = "Open the PhantomSwift web dashboard in your browser.\nBoth devices must be on the same Wi-Fi network.\n\nAvailable commands: app-info, system-status, logs,\nnetwork-trace, feature-flags, toggle-flag, performance"
        view.addSubview(instructionsLabel)
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            statusCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            statusCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            statusDot.topAnchor.constraint(equalTo: statusCard.topAnchor, constant: 24),
            statusDot.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: 20),
            statusDot.widthAnchor.constraint(equalToConstant: 16),
            statusDot.heightAnchor.constraint(equalToConstant: 16),

            statusLabel.centerYAnchor.constraint(equalTo: statusDot.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 10),

            ipLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            ipLabel.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: 20),
            ipLabel.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -20),

            portLabel.topAnchor.constraint(equalTo: ipLabel.bottomAnchor, constant: 6),
            portLabel.leadingAnchor.constraint(equalTo: ipLabel.leadingAnchor),
            portLabel.bottomAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: -24),

            toggleButton.topAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: 24),
            toggleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            toggleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            toggleButton.heightAnchor.constraint(equalToConstant: 52),

            instructionsLabel.topAnchor.constraint(equalTo: toggleButton.bottomAnchor, constant: 24),
            instructionsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            instructionsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    private func updateStatus() {
        let isRunning = PhantomRemoteServer.shared.isRunning
        let port = PhantomRemoteServer.shared.port

        statusDot.backgroundColor = isRunning ? UIColor.Phantom.vibrantGreen : UIColor.Phantom.vibrantRed
        statusLabel.text = isRunning ? "Server Running" : "Server Stopped"

        if isRunning {
            let ips = getWiFiAddresses()
            if let ip = ips.first {
                ipLabel.text = "ws://\(ip):\(port)"
            } else {
                ipLabel.text = "ws://localhost:\(port)"
            }
            portLabel.text = "Port \(port) · \(ips.count) interface\(ips.count == 1 ? "" : "s")"

            toggleButton.setTitle("Stop Server", for: .normal)
            toggleButton.setTitleColor(.white, for: .normal)
            toggleButton.backgroundColor = UIColor.Phantom.vibrantRed
        } else {
            ipLabel.text = "Not running"
            portLabel.text = "Tap Start to begin"

            toggleButton.setTitle("Start Server", for: .normal)
            toggleButton.setTitleColor(.white, for: .normal)
            toggleButton.backgroundColor = UIColor.Phantom.vibrantGreen
        }
    }

    @objc private func toggleServer() {
        if PhantomRemoteServer.shared.isRunning {
            PhantomRemoteServer.shared.stop()
        } else {
            PhantomRemoteServer.shared.start()
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        updateStatus()
    }

    // MARK: - Network Helpers

    private func getWiFiAddresses() -> [String] {
        var addresses: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return addresses }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let interface = current.pointee
            let family = interface.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" || name.hasPrefix("utun") {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    let ip = String(cString: hostname)
                    if !ip.isEmpty && ip != "127.0.0.1" {
                        addresses.append(ip)
                    }
                }
            }
            ptr = interface.ifa_next
        }

        return addresses
    }
}
#endif
