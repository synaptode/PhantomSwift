# PhantomSwift — Product Requirements Document

> **Version:** 1.0.0 (Draft)
> **Status:** Active Development
> **Last Updated:** 2025

---

## 🤖 Agent Instructions

> **READ THIS FIRST — For AI Agents (Antigravity)**
>
> You are acting as a **senior iOS engineer** and **open source library architect**.
> Your job is to implement **PhantomSwift** based on this PRD.
>
> **Rules:**
> - Always refer back to this PRD before generating any code
> - Follow the folder structure defined in Section 9 **exactly**
> - Never add external dependencies — zero dependency policy is non-negotiable
> - All UI must use **UIKit only** (no SwiftUI) for iOS 12 compatibility
> - Wrap all PhantomSwift code in `#if DEBUG` or custom compiler flags
> - Every public API must have DocC documentation comment
> - All code must be thread-safe using DispatchQueue
> - Follow Swift API Design Guidelines for all public APIs
> - Minimum iOS: **12.0**, Minimum Swift: **5.3**
> - When implementing a module, always start with the model/core layer before UI

---

## 1. Executive Summary

**PhantomSwift** is an open-source, all-in-one iOS debugging toolkit designed to be the single replacement for FLEX, Netfox, and any other debugging library in the iOS ecosystem.

**Tagline:** *"See everything. Ship nothing."*

**Core Philosophy:** Zero footprint in production. Full power in development. PhantomSwift automatically disappears in Release builds — leaving no trace in the app shipped to end users.

**License:** MIT — free to use, modify, and contribute.

---

## 2. Problem Statement

iOS developers today must juggle multiple libraries for debugging:

| Need | Current Solution | Problem |
|------|-----------------|---------|
| Network monitoring | Netfox | No API mocking, no redirect |
| UI inspection | FLEX | No memory leak detection |
| Memory leaks | No good iOS solution | Developers rely on Instruments only |
| API mocking | Mockoon + manual code changes | Requires code changes per environment |
| Environment gating | Manual `#if DEBUG` everywhere | Inconsistent, scattered config |

**PhantomSwift solves all of the above in one library with a single configuration entry point.**

---

## 3. Target Audience

### 3.1 Personas

**Junior iOS Developer**
- Experience: 0–2 years
- Pain points: Doesn't know how to debug network issues or memory problems
- Needs: Friendly UI, clear logs, easy 5-minute setup

**Senior iOS Developer**
- Experience: 3+ years
- Pain points: Needs full control, API mocking without changing production code
- Needs: Deep control, plugin system, flexible programmatic configuration

**QA Engineer**
- Role: Quality Assurance / Testing
- Pain points: Cannot see API traffic, hard to reproduce bugs, manual bug reporting
- Needs: Network inspector, annotated screenshots, one-tap bug report with full context

---

## 4. Environment & Feature Flag System

### 4.1 Built-in Environments

```swift
// Usage in AppDelegate
PhantomSwift.configure { config in
    config.environment = .dev  // All features ON
    // config.environment = .uat  // Network + QA only
    // config.environment = .release  // Nothing active (safe to ship)
    // config.environment = .custom([.network, .logger])  // Pick your own
}
PhantomSwift.launch()
```

### 4.2 Feature Matrix

| Feature Module | DEV | UAT | RELEASE |
|----------------|:---:|:---:|:-------:|
| Network Inspector | ✅ | ✅ | ❌ |
| API Interceptor & Mock | ✅ | ✅ | ❌ |
| Console Logger | ✅ | ✅ | ❌ |
| Crash Reporter | ✅ | ✅ | ❌ |
| PhantomHUD Overlay | ✅ | ✅ | ❌ |
| QA Bug Report Tools | ✅ | ✅ | ❌ |
| UI Inspector | ✅ | ❌ | ❌ |
| Memory Leak Detector | ✅ | ❌ | ❌ |
| Storage Inspector | ✅ | ❌ | ❌ |
| Performance Monitor | ✅ | ❌ | ❌ |
| Security Inspector | ✅ | ❌ | ❌ |
| LLDB Debugger Bridge | ✅ | ❌ | ❌ |

### 4.3 Environment Implementation

```swift
// PhantomEnvironment.swift
public enum PhantomEnvironment {
    case dev
    case uat
    case release
    case custom([PhantomFeature])

    var enabledFeatures: Set<PhantomFeature> {
        switch self {
        case .dev:     return Set(PhantomFeature.allCases)
        case .uat:     return [.network, .interceptor, .logger, .crashReporter, .hud, .qa]
        case .release: return []
        case .custom(let features): return Set(features)
        }
    }
}
```

---

## 5. Feature Specifications

### 5.1 Network Inspector

**Priority:** P0 — Must have in v1.0

**Description:** Real-time monitoring of all HTTP/HTTPS traffic in the app.

**Intercepted session types:**
- `URLSession.shared`
- Custom `URLSession` instances
- Alamofire (via URLProtocol)
- Moya (via URLProtocol)

**Required capabilities:**
- List view of all requests: URL, method, HTTP status code, duration, timestamp
- Detail view: request headers, request body (formatted), response headers, response body (formatted)
- Filter by: URL keyword, HTTP method (GET/POST/etc), status code range, date range
- Visual badge on mocked/intercepted requests
- Visual badge on blocked requests
- JSON body auto-format with syntax highlighting
- Export single request as cURL command
- Re-send request from UI (with editable headers and body before resend)
- Timeline waterfall chart per request
- Bandwidth throttle simulator: 2G, 3G, 4G/LTE, Custom (delay in ms)
- SSL Pinning bypass toggle (DEV environment only)
- HAR (HTTP Archive) file export for all sessions
- GraphQL body parser and pretty printer
- WebSocket frame inspector
- Multipart form-data viewer
- Certificate chain viewer (subject, issuer, validity, SHA fingerprint)
- Cookie & HTTPCookieStorage viewer

**Data model:**
```swift
struct PhantomRequest {
    let id: UUID
    let url: String
    let method: String
    let requestHeaders: [String: String]
    let requestBody: Data?
    let responseHeaders: [String: String]?
    let responseBody: Data?
    let statusCode: Int?
    let duration: TimeInterval
    let timestamp: Date
    let isMocked: Bool
    let isBlocked: Bool
    let isWebSocket: Bool
}
```

---

### 5.2 API Interceptor & Mock Engine

**Priority:** P0 — Must have in v1.0

**Description:** The most powerful feature of PhantomSwift. Redirect, mock, block, or delay any API request directly from the device without changing production code.

**Rule types:**

```swift
public enum InterceptRule {
    /// Redirect request URL to a different server (e.g., Mockoon at localhost)
    case redirect(from: String, to: String)

    /// Inject a fake HTTP response without hitting the network
    case mockResponse(url: String, statusCode: Int, headers: [String: String], body: [String: Any])

    /// Add artificial delay before the request is sent
    case delay(url: String, seconds: TimeInterval)

    /// Drop the request entirely and return an NSError
    case block(url: String)

    /// Modify request headers/body before sending
    case modifyRequest(url: String, transform: (inout URLRequest) -> Void)

    /// Modify response before the app receives it
    case modifyResponse(url: String, transform: (inout HTTPURLResponse, inout Data) -> Void)
}
```

**URL matching strategies:**
- Exact match: `"api.example.com/product"`
- Wildcard: `"api.example.com/*"`
- Regex: `"api\\.example\\.com\\/product\\/[0-9]+"`
- Method-specific: apply rule only for GET, POST, etc.
- Priority-based: rule with higher priority wins when multiple rules match

**Implementation approach:**
- Use `URLProtocol` subclass registered via `URLProtocol.registerClass(_:)`
- In `canInit(with:)`, check if any rule matches the request URL
- In `startLoading()`, apply the matching rule action

**Mock server integrations (via redirect rule):**
- Mockoon (localhost:port)
- WireMock (localhost:port)
- Any custom local HTTP server

**UI requirements:**
- List of all active rules
- Toggle individual rules on/off from device
- Rule editor: create/edit/delete rules directly on device
- Per-request indicator showing which rule was applied

---

### 5.3 Memory Leak Detector

**Priority:** P0 — Must have in v1.0

**Description:** Automatically detect memory leaks without requiring Instruments or Xcode. This feature does NOT exist in FLEX or Netfox.

**Detection mechanism:**
1. Swizzle `UIViewController.viewDidDisappear(_:)` automatically on launch
2. Store a `weak` reference to the dismissed VC
3. After configurable threshold (default: 3.0 seconds), check if the weak reference is still non-nil
4. If still alive → potential leak detected
5. Capture retain count, call stack, and class name
6. Optionally capture heap snapshot before/after for comparison

**Heap snapshot diff:**
- Take snapshot of allocated objects at point A
- Take snapshot at point B (after dismiss)
- Diff: objects in B that weren't in A and should have been deallocated → leaked

**Retain cycle visualizer:**
- Build object reference graph from leaked objects
- Display visual graph showing which objects are retaining each other

**Trackable object types:**
- `UIViewController` and all subclasses (auto, via swizzle)
- `UIView` and all subclasses (opt-in)
- Custom classes (developer registers via `PhantomLeakTracker.track(MyClass.self)`)

**Leak report model:**
```swift
struct LeakReport {
    let className: String
    let retainCount: Int
    let file: String
    let line: Int
    let callStack: [String]
    let timestamp: Date
    let snapshot: HeapSnapshot?
}
```

**Developer callbacks:**
```swift
config.memoryLeak.onLeakDetected = { leak in
    // Custom handling: log to crash reporter, send to Slack, etc.
}
```

**UI requirements:**
- Red badge on HUD button when leak detected
- List of all detected leaks with class name, timestamp, retain count
- Detail view with full call stack (syntax highlighted)
- Retain cycle graph visualization
- Export leak report as JSON

---

### 5.4 UI Inspector

**Priority:** P1 — Must have in v1.0

**Description:** Tap-to-inspect any UIView element on screen and live-edit its properties.

**Capabilities:**
- Transparent overlay layer placed above app UI to intercept taps
- View hierarchy tree explorer (tree representation of UIView hierarchy from UIWindow)
- On tap: show properties panel for selected view
- Live editable properties: frame (x, y, width, height), backgroundColor, alpha, isHidden, cornerRadius, borderWidth, borderColor
- For UILabel: text, font, textColor, textAlignment, numberOfLines
- For UIImageView: contentMode
- Auto Layout constraint viewer for selected view
- Constraint conflict highlighter (show broken constraints in red)
- Slow animation detector (highlight views with animations below 60fps)
- Dark mode toggle (instant, no restart)
- Dynamic Type size switcher (xSmall through accessibility5)
- Accessibility inspector: color contrast ratio checker, touch target size checker
- Localization switcher (change app language without restart using AppleLanguages UserDefaults key)
- RTL layout toggle

---

### 5.5 Console Logger

**Priority:** P0 — Must have in v1.0

**Description:** Centralized logging replacing scattered `print()` calls.

**Log levels:**

```swift
public enum LogLevel: Int, CaseIterable {
    case verbose  = 0   // 🔍 Granular technical details
    case debug    = 1   // 🐛 General debug info
    case info     = 2   // ℹ️ Normal app flow
    case warning  = 3   // ⚠️ Unusual but non-fatal
    case error    = 4   // ❌ Error requiring attention
    case critical = 5   // 🚨 Fatal, potential crash
}
```

**Public API:**
```swift
PhantomLog.verbose("Fetching user data", tag: "Network")
PhantomLog.debug("Cache hit for key: \(key)")
PhantomLog.info("User logged in: \(userId)")
PhantomLog.warning("Retry attempt \(n) of 3")
PhantomLog.error("Failed to decode response: \(error)")
PhantomLog.critical("CoreData stack failed to initialize")
```

**Features:**
- Auto-capture: file, function, line number, timestamp per log entry
- Breadcrumb trail: ordered list of the last N log entries before a crash
- In-memory circular buffer (configurable size, default: 1000 entries)
- Filter by: log level, tag, module name, keyword search
- Export log as `.txt` or `.json`
- Remote logging: POST log entries to Slack webhook or custom HTTP endpoint

---

### 5.6 Storage Inspector

**Priority:** P1 — Must have in v1.0

**Capabilities:**
- **UserDefaults:** Read, create, edit, delete any key-value pair. Supports all primitive types.
- **Keychain:** View all keychain items for the app. Delete individual items. (Read-only for security)
- **CoreData:** Browse all entities, view all records, filter and sort. No editing to prevent corruption.
- **SQLite:** Connect to any `.sqlite` file in the app sandbox. Execute custom SELECT queries. View table schema.
- **File System Explorer:** Browse the entire app sandbox directory structure. View file sizes and metadata. View text file contents.
- **NSCache:** List all cached objects (class name, key). Cannot inspect values directly.
- **HTTPCookieStorage:** View all cookies for all domains. Delete individual cookies.

---

### 5.7 Performance Monitor

**Priority:** P1 — Must have in v1.0

**Metrics tracked:**

| Metric | Method | Update Interval |
|--------|--------|-----------------|
| Memory (MB used) | `task_info` Mach call | 1 second |
| CPU % | `host_processor_info` | 1 second |
| FPS | `CADisplayLink` | Per frame |
| Main thread blocked | `CFRunLoopObserver` | Continuous |
| Thermal state | `ProcessInfo.thermalState` | On change |
| Battery % | `UIDevice.batteryLevel` | On change |
| Disk read/write | `proc_pid_rusage` | 2 seconds |

**FPS overlay:** Small translucent badge showing live FPS in corner of screen (always visible when Performance module is active).

**Main thread checker:** If main thread is blocked for more than 16ms (1 frame at 60fps), log a warning with the blocking call stack.

**UI:** Line graphs for Memory and CPU over time (last 60 seconds). Separate cards for FPS, thermal state, battery.

---

### 5.8 QA & Testing Tools

**Priority:** P1 — Must have in v1.0

**Bug Reporting flow:**
1. User shakes device (or taps "Report Bug" in HUD)
2. Screenshot is automatically captured
3. Annotation screen opens: user can draw, add text, add arrows
4. Bug report form: title, description, severity
5. Auto-attached context: last 50 network requests, last 100 log entries, device info, app version, build number, environment, git commit hash (if injected at build time)
6. User selects destination and submits

**Bug report destinations:**
- **GitHub Issues:** POST via GitHub REST API (requires token in config)
- **Jira:** Create issue via Jira REST API (requires Jira URL + token)
- **Linear:** Create issue via Linear API
- **Slack:** Post to channel via Slack Incoming Webhook URL
- **Email:** Open system mail composer with pre-filled content
- **Custom webhook:** POST JSON payload to any URL

**Screen recording:**
- Use `RPScreenRecorder` (ReplayKit) to record screen
- Overlay: log entries scroll over the recording in real time
- Export as `.mp4`

**Simulator & testing tools:**
```swift
// Deep link tester
PhantomDeepLink.open("myapp://profile/123")

// Push notification simulator
PhantomPush.simulate(title: "New message", body: "Hello!", badge: 1)

// Location spoofer
PhantomLocation.spoof(latitude: -6.2088, longitude: 106.8456)
PhantomLocation.stopSpoofing()

// Time travel
PhantomTime.travel(to: Date(timeIntervalSince1970: 1735689600)) // Jan 1 2025
PhantomTime.reset()

// Network condition simulator (wraps bandwidth throttle)
PhantomNetwork.simulate(.threeG)
PhantomNetwork.simulate(.offline)
PhantomNetwork.simulate(.custom(latency: 500, downloadKbps: 100, uploadKbps: 50))
```

---

### 5.9 Security Inspector

**Priority:** P2 — Nice to have in v1.0

**Capabilities:**
- Jailbreak detection result: show result of common jailbreak checks and explain what was detected
- SSL certificate chain viewer: for each HTTPS request, view full certificate chain with subject, issuer, validity dates, SHA-256 fingerprint
- Sensitive data detector: scan all log entries and network request/response bodies for patterns matching API keys, bearer tokens, passwords, credit card numbers, email addresses
- Pasteboard monitor: log every time UIPasteboard.general changes, show the content type and value
- App Transport Security configuration viewer: display the current ATS config from Info.plist

---

### 5.10 PhantomHUD — Floating Overlay

**Priority:** P0 — Must have in v1.0

**Description:** The always-present entry point for PhantomSwift, rendered in a separate UIWindow above the app's main window.

**Architecture:** Separate `UIWindow` with `windowLevel = .alert + 1` to render above all app content.

**Trigger methods:**
```swift
config.trigger = .shake           // Default — device shake gesture
config.trigger = .floatingButton  // Always-visible floating button
config.trigger = .custom          // Developer calls PhantomSwift.showDashboard() manually
config.floatingButtonPosition = .bottomRight  // .topLeft .topRight .bottomLeft .bottomRight
```

**Dashboard:**
- Grid of module icons (only shows modules enabled for current environment)
- Notification badges on icons: red dot for leaks detected, yellow for warnings
- Always-visible mini stats bar at bottom: Memory MB / CPU% / FPS
- Global search across all PhantomSwift data (network logs, console logs, storage)

**Themes:**
```swift
config.theme = .dark    // Default
config.theme = .light
config.theme = .auto    // Follows UITraitCollection.userInterfaceStyle
```

---

## 6. Plugin System

### 6.1 Philosophy

The plugin system allows the community to build custom modules that integrate seamlessly into the PhantomSwift dashboard without forking the main library.

### 6.2 Plugin Protocol

```swift
public protocol PhantomPlugin: AnyObject {
    /// Unique reverse-domain identifier: "com.mycompany.myplugin"
    var identifier: String { get }

    /// Display name shown in HUD dashboard
    var displayName: String { get }

    /// SF Symbol name for dashboard icon
    var iconName: String { get }

    /// Called when PhantomSwift.launch() is called
    func start(with config: PhantomConfig)

    /// Called when the user taps this plugin in the dashboard
    func presentUI(from viewController: UIViewController)

    /// Called when PhantomSwift is stopped (e.g., moving to release)
    func stop()

    /// Optional: subscribe to internal PhantomSwift events
    func onEvent(_ event: PhantomEvent)
}
```

### 6.3 Registering a Plugin

```swift
PhantomSwift.configure { config in
    config.environment = .dev
}

// Register community plugin
PhantomSwift.register(plugin: RealmBrowserPlugin())
PhantomSwift.register(plugin: FirebaseInspectorPlugin())

PhantomSwift.launch()
```

### 6.4 PhantomEvent (Event Bus)

```swift
public enum PhantomEvent {
    case networkRequestCompleted(PhantomRequest)
    case networkRequestFailed(PhantomRequest, Error)
    case memoryLeakDetected(LeakReport)
    case memoryWarningReceived
    case logEntryAdded(LogEntry)
    case appDidEnterBackground
    case appWillEnterForeground
}
```

### 6.5 Example Community Plugins (Roadmap)

- `PhantomSwift-RealmBrowser` — Browse Realm database
- `PhantomSwift-FirebaseInspector` — View Remote Config, Firestore
- `PhantomSwift-RevenueCat` — View subscription & purchase state
- `PhantomSwift-SwiftUIInspector` — Inspect SwiftUI view hierarchy

---

## 7. Architecture

### 7.1 High-Level Design

```
┌─────────────────────────────────────────────┐
│              HOST APPLICATION               │
├─────────────────────────────────────────────┤
│  PhantomSwift.configure { }.launch()        │  ← Single entry point
├─────────────┬───────────────────────────────┤
│  PhantomHUD │  PhantomEventBus              │  ← Core layer
│  (UIWindow) │  (Internal pub/sub)           │
├─────────────┴───────────────────────────────┤
│  Modules (loaded based on environment)      │
│  ┌─────────┐ ┌──────────┐ ┌─────────────┐  │
│  │ Network │ │Interceptr│ │MemoryLeak   │  │
│  ├─────────┤ ├──────────┤ ├─────────────┤  │
│  │UIInspct │ │ Logger   │ │ Storage     │  │
│  ├─────────┤ ├──────────┤ ├─────────────┤  │
│  │ Perform │ │   QA     │ │ Security    │  │
│  └─────────┘ └──────────┘ └─────────────┘  │
├─────────────────────────────────────────────┤
│  Shared: Extensions / Components / Helpers  │
└─────────────────────────────────────────────┘
```

### 7.2 Core Design Patterns

| Pattern | Usage |
|---------|-------|
| Builder | `PhantomConfig` configuration |
| Observer | `PhantomEventBus` for inter-module communication |
| Strategy | `InterceptRule` for different interception behaviors |
| Singleton | `PhantomSwift.shared` as main coordinator |
| Repository | `PhantomRequestStore`, `LogStore` for in-memory data |
| Protocol-oriented | `PhantomPlugin` for extensibility |

### 7.3 Threading Model

```swift
// All data stores use a dedicated serial queue
let queue = DispatchQueue(label: "com.phantomswift.network", qos: .utility)

// All UI updates dispatched to main queue
DispatchQueue.main.async { /* UI update */ }

// Network interception on background queue
// Store operations on dedicated serial queue
// UI reads on main queue only
```

---

## 8. Distribution

### 8.1 Swift Package Manager

```swift
// Package.swift
let package = Package(
    name: "PhantomSwift",
    platforms: [.iOS(.v12)],
    products: [
        .library(name: "PhantomSwift", targets: ["PhantomSwift"]),
    ],
    targets: [
        .target(
            name: "PhantomSwift",
            dependencies: [],    // ZERO external dependencies
            path: "Sources/PhantomSwift"
        ),
        .testTarget(
            name: "PhantomSwiftTests",
            dependencies: ["PhantomSwift"]
        )
    ]
)
```

### 8.2 CocoaPods

```ruby
# PhantomSwift.podspec
Pod::Spec.new do |s|
  s.name             = 'PhantomSwift'
  s.version          = '1.0.0'
  s.summary          = 'See everything. Ship nothing.'
  s.description      = 'All-in-one iOS debugging toolkit. Zero footprint in production.'
  s.homepage         = 'https://github.com/phantomswift/PhantomSwift'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'PhantomSwift' => 'hello@phantomswift.dev' }
  s.source           = { :git => 'https://github.com/phantomswift/PhantomSwift.git', :tag => s.version.to_s }
  s.ios.deployment_target = '12.0'
  s.swift_versions   = ['5.3']
  s.source_files     = 'Sources/PhantomSwift/**/*'
  s.dependency       # none — zero external dependencies
end
```

---

## 9. Folder Structure

> **Agent Note:** This is the **exact** folder structure to implement. Do not deviate.

```
PhantomSwift/
│
├── Sources/
│   └── PhantomSwift/
│       │
│       ├── Core/
│       │   ├── PhantomSwift.swift            # Public entry point, singleton
│       │   ├── PhantomConfig.swift           # Builder pattern config object
│       │   ├── PhantomEnvironment.swift      # .dev / .uat / .release / .custom
│       │   ├── PhantomFeature.swift          # Enum of all feature flags
│       │   ├── PhantomPlugin.swift           # Plugin protocol + registry
│       │   └── PhantomEventBus.swift         # Internal event publisher/subscriber
│       │
│       ├── HUD/
│       │   ├── PhantomHUDWindow.swift        # UIWindow rendered above app
│       │   ├── PhantomHUDButton.swift        # Draggable floating trigger button
│       │   ├── PhantomDashboardVC.swift      # Main module grid menu
│       │   ├── PhantomTheme.swift            # Color tokens + theme switching
│       │   └── PhantomGestureHandler.swift   # Shake + custom gesture detection
│       │
│       ├── Modules/
│       │   │
│       │   ├── Network/
│       │   │   ├── Core/
│       │   │   │   ├── PhantomURLProtocol.swift     # URLProtocol subclass
│       │   │   │   ├── PhantomRequestStore.swift    # Thread-safe request list
│       │   │   │   ├── PhantomNetworkModel.swift    # PhantomRequest + PhantomResponse
│       │   │   │   └── PhantomCURLExporter.swift    # Build cURL string from request
│       │   │   └── UI/
│       │   │       ├── NetworkListVC.swift
│       │   │       ├── RequestDetailVC.swift
│       │   │       ├── RequestHeadersVC.swift
│       │   │       └── NetworkFilterView.swift
│       │   │
│       │   ├── Interceptor/
│       │   │   ├── PhantomInterceptor.swift          # Rule engine singleton
│       │   │   ├── InterceptRule.swift               # Enum of rule types
│       │   │   ├── PhantomRuleMatcher.swift          # Exact / wildcard / regex matcher
│       │   │   ├── MockResponseBuilder.swift         # Construct fake URLResponse + Data
│       │   │   └── UI/
│       │   │       ├── InterceptorListVC.swift        # Active rules list
│       │   │       └── RuleEditorVC.swift             # Create / edit rule on device
│       │   │
│       │   ├── MemoryLeak/
│       │   │   ├── PhantomLeakTracker.swift           # Swizzle + weak ref tracking
│       │   │   ├── PhantomHeapSnapshot.swift          # Snapshot + diff logic
│       │   │   ├── RetainCycleDetector.swift          # Reference graph analysis
│       │   │   ├── LeakReport.swift                   # Leak data model
│       │   │   └── UI/
│       │   │       ├── LeakListVC.swift
│       │   │       └── LeakDetailVC.swift             # Call stack + retain graph
│       │   │
│       │   ├── UIInspector/
│       │   │   ├── PhantomTapOverlay.swift            # Transparent UIView intercept layer
│       │   │   ├── ViewHierarchyBuilder.swift         # Walk UIWindow view tree
│       │   │   ├── LivePropertyEditor.swift           # Read/write view properties
│       │   │   ├── ConstraintInspector.swift          # NSLayoutConstraint analyzer
│       │   │   ├── AccessibilityChecker.swift         # Contrast ratio + hit area
│       │   │   └── UI/
│       │   │       ├── HierarchyTreeVC.swift
│       │   │       └── PropertyEditorVC.swift
│       │   │
│       │   ├── Logger/
│       │   │   ├── PhantomLog.swift                   # Public static API
│       │   │   ├── LogLevel.swift                     # Enum
│       │   │   ├── LogEntry.swift                     # Model with file/line/tag
│       │   │   ├── LogStore.swift                     # Circular buffer, thread-safe
│       │   │   ├── RemoteLogger.swift                 # Slack / webhook sender
│       │   │   └── UI/
│       │   │       ├── LogConsoleVC.swift
│       │   │       └── LogFilterView.swift
│       │   │
│       │   ├── Storage/
│       │   │   ├── UserDefaultsInspector.swift
│       │   │   ├── KeychainInspector.swift
│       │   │   ├── CoreDataBrowser.swift
│       │   │   ├── SQLiteBrowser.swift
│       │   │   ├── FileSystemExplorer.swift
│       │   │   └── UI/
│       │   │       ├── StorageMenuVC.swift
│       │   │       ├── KeyValueEditorVC.swift
│       │   │       └── TableBrowserVC.swift
│       │   │
│       │   ├── Performance/
│       │   │   ├── MemoryMonitor.swift                # task_info based
│       │   │   ├── CPUMonitor.swift                   # host_processor_info based
│       │   │   ├── FPSTracker.swift                   # CADisplayLink based
│       │   │   ├── MainThreadChecker.swift            # CFRunLoopObserver based
│       │   │   ├── ThermalMonitor.swift               # ProcessInfo.thermalState
│       │   │   └── UI/
│       │   │       ├── PerformanceDashboardVC.swift
│       │   │       └── PhantomGraphView.swift         # Reusable line chart UIView
│       │   │
│       │   ├── QA/
│       │   │   ├── BugReporter.swift                  # Orchestrates full bug report
│       │   │   ├── ScreenshotAnnotator.swift          # Drawing overlay on UIImage
│       │   │   ├── ScreenRecorder.swift               # ReplayKit wrapper
│       │   │   ├── DeepLinkTester.swift               # Open URL scheme
│       │   │   ├── LocationSpoofer.swift              # Override CLLocationManager
│       │   │   ├── TimeTraveler.swift                 # Swizzle Date.init
│       │   │   ├── Integrations/
│       │   │   │   ├── GitHubReporter.swift
│       │   │   │   ├── JiraReporter.swift
│       │   │   │   ├── LinearReporter.swift
│       │   │   │   ├── SlackReporter.swift
│       │   │   │   └── WebhookReporter.swift
│       │   │   └── UI/
│       │   │       ├── BugReportVC.swift
│       │   │       └── AnnotationCanvasView.swift
│       │   │
│       │   └── Security/
│       │       ├── JailbreakDetector.swift
│       │       ├── CertificateInspector.swift
│       │       ├── SensitiveDataScanner.swift
│       │       ├── PasteboardMonitor.swift
│       │       └── UI/
│       │           └── SecurityDashboardVC.swift
│       │
│       └── Shared/
│           ├── Extensions/
│           │   ├── UIColor+Phantom.swift              # Phantom color tokens
│           │   ├── UIView+Phantom.swift               # Utility view helpers
│           │   └── Data+Pretty.swift                  # JSON pretty print
│           ├── Components/
│           │   ├── PhantomTableVC.swift               # Base table with search + empty state
│           │   ├── PhantomCodeView.swift              # Syntax-highlighted UITextView
│           │   ├── PhantomBadgeView.swift             # Notification badge
│           │   └── PhantomEmptyStateView.swift        # Empty state illustration
│           └── Helpers/
│               ├── PhantomSwizzler.swift              # Safe method swizzling helper
│               ├── WeakRef.swift                      # Generic weak wrapper
│               └── CircularBuffer.swift               # Fixed-size thread-safe buffer
│
├── Tests/
│   └── PhantomSwiftTests/
│       ├── Core/
│       │   ├── PhantomConfigTests.swift
│       │   └── PhantomEnvironmentTests.swift
│       ├── Network/
│       │   ├── PhantomURLProtocolTests.swift
│       │   ├── RuleMatcherTests.swift
│       │   └── CURLExporterTests.swift
│       ├── MemoryLeak/
│       │   └── LeakTrackerTests.swift
│       ├── Logger/
│       │   └── LogStoreTests.swift
│       └── Mocks/
│           └── MockURLSession.swift
│
├── Example/
│   └── PhantomSwiftDemo/
│       ├── AppDelegate.swift
│       ├── DemoViewController.swift
│       └── Assets.xcassets
│
├── Docs/
│   ├── GettingStarted.md
│   ├── Configuration.md
│   ├── APIInterceptor.md
│   ├── MemoryLeakDetector.md
│   ├── PluginDevelopment.md
│   └── Migration/
│       ├── FromFLEX.md
│       └── FromNetfox.md
│
├── .github/
│   ├── workflows/
│   │   ├── ci.yml
│   │   └── release.yml
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   └── pull_request_template.md
│
├── Package.swift
├── PhantomSwift.podspec
├── README.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
└── LICENSE
```

---

## 10. Technical Requirements

| Requirement | Specification |
|-------------|---------------|
| Minimum iOS | 12.0 |
| Minimum Swift | 5.3 (Xcode 12+) |
| Minimum Xcode | 12.0 |
| External dependencies | **ZERO** |
| UI framework | UIKit only (no SwiftUI) |
| Thread safety | All stores thread-safe via `DispatchQueue` |
| Memory overhead | < 5 MB at idle, < 20 MB when active |
| CPU overhead | < 1% at idle, < 5% with panel open |
| App Store safety | No private API usage. Exclude from Release build. |
| Architectures | arm64, x86_64 (simulator), arm64 (Apple Silicon simulator) |
| Test coverage | Minimum 70% for Core and Network modules |
| CI | GitHub Actions — test on every PR, auto-release on tag |

---

## 11. Design System

### Color Tokens

| Token | Hex | Usage |
|-------|-----|-------|
| `phantom.background` | `#0D1117` | Main background |
| `phantom.surface` | `#161B22` | Cards, cells |
| `phantom.accent` | `#6C47FF` | CTA, active state |
| `phantom.success` | `#3FB950` | 2xx status, OK |
| `phantom.warning` | `#D29922` | 3xx status, warnings |
| `phantom.error` | `#F85149` | 4xx/5xx, leak detected |
| `phantom.info` | `#58A6FF` | Info badges |
| `phantom.textPrimary` | `#C9D1D9` | Primary text |
| `phantom.textSecondary` | `#8B949E` | Secondary text |

### Design Principles

1. **Non-intrusive** — PhantomSwift must never interfere with app UI when closed
2. **Familiar** — follow iOS native navigation patterns and gestures
3. **Information dense** — show maximum useful information without clutter
4. **Developer-first** — optimized for debugging workflows, not end users

---

## 12. Release Roadmap

| Phase | Version | Scope | Timeline |
|-------|---------|-------|----------|
| Alpha | 0.1.0 | Core + HUD + Network Inspector + API Interceptor | Month 1–2 |
| Beta | 0.5.0 | + Memory Leak + Logger + Storage Inspector | Month 3–4 |
| RC | 0.9.0 | + UI Inspector + QA Tools + Performance Monitor | Month 5 |
| Stable | 1.0.0 | + Security Inspector + Plugin System + Full docs | Month 6 |
| Post 1.0 | 1.x | Community plugins, third-party integrations | Ongoing |

---

## 13. Open Source

| Aspect | Detail |
|--------|--------|
| License | MIT |
| Organization | `github.com/phantomswift` |
| Main repo | `github.com/phantomswift/PhantomSwift` |
| Demo app | `github.com/phantomswift/PhantomSwift-Demo` |
| Plugin template | `github.com/phantomswift/PhantomSwift-PluginTemplate` |
| Website | `phantomswift.dev` |
| Discussion | GitHub Discussions |
| Roadmap | GitHub Projects (public) |

---

## 14. Out of Scope (v1.0)

The following will **not** be implemented in v1.0:

- macOS / tvOS / watchOS support
- SwiftUI-native UI for PhantomSwift itself
- Remote debugging (debug from Mac to device via network)
- AI-powered anomaly detection (roadmap v2.0)
- Paid or Pro tier — entirely free and open source

---

## 15. Competitive Advantage

| Feature | Netfox | FLEX | **PhantomSwift** |
|---------|:------:|:----:|:----------------:|
| Network Inspector | ✅ | ✅ | ✅ + HAR, timeline |
| API Redirect / Mock | ❌ | ❌ | ✅ |
| Request Block / Delay | ❌ | ❌ | ✅ |
| Re-send Request | ❌ | ❌ | ✅ |
| Export cURL | ❌ | ❌ | ✅ |
| SSL Pinning Bypass | ❌ | ❌ | ✅ |
| Memory Leak Detector | ❌ | ⚠️ | ✅ Heap diff |
| Retain Cycle Graph | ❌ | ❌ | ✅ |
| UI Inspector | ❌ | ✅ | ✅ + Accessibility |
| Localization Switcher | ❌ | ❌ | ✅ |
| Storage Inspector | ❌ | ✅ | ✅ + SQLite |
| Performance Monitor | ❌ | ⚠️ | ✅ Full |
| Environment Feature Flag | ❌ | ❌ | ✅ |
| QA Bug Report | ❌ | ❌ | ✅ |
| Plugin System | ❌ | ❌ | ✅ |
| SPM + CocoaPods | ✅ | ✅ | ✅ |

---

*PhantomSwift — See everything. Ship nothing. 👻*
