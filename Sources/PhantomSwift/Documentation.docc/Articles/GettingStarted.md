# Getting Started with PhantomSwift

Add PhantomSwift to your project and open the debug dashboard in minutes.

## Overview

PhantomSwift is distributed as a Swift Package and a CocoaPod.  Because every file is
wrapped in `#if DEBUG`, it is safe to add PhantomSwift to your main target — nothing will
be compiled into a Release build.  For maximum binary cleanliness, restrict the dependency
to the **Debug** configuration.

## Installation

### Swift Package Manager (Recommended)

1. Open your project in Xcode and choose **File › Add Package Dependencies…**
2. Paste the repository URL:

   ```
   https://github.com/synaptode/PhantomSwift.git
   ```

3. Choose **Up to Next Major Version** starting from `1.0.0`.
4. Add the library to your **app target** (Debug configuration only for zero release overhead).

Or declare the dependency in `Package.swift`:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/synaptode/PhantomSwift.git", from: "1.0.0")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "PhantomSwift", package: "PhantomSwift")
    ])
]
```

### CocoaPods

```ruby
# Podfile
pod 'PhantomSwift', :configurations => ['Debug']
```

## Launching PhantomSwift

### SwiftUI

```swift
import SwiftUI
#if DEBUG
import PhantomSwift
#endif

@main
struct MyApp: App {
    init() {
        #if DEBUG
        PhantomSwift.configure { config in
            config.environment = .dev
            config.triggers    = [.shake, .dynamicIsland]
            config.theme       = .dark
        }
        PhantomSwift.launch()
        #endif
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

### UIKit

```swift
import UIKit
#if DEBUG
import PhantomSwift
#endif

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        #if DEBUG
        PhantomSwift.configure { config in
            config.environment = .dev
            config.triggers    = [.shake]
            config.theme       = .dark
            config.shortcuts   = [
                AppShortcut(title: "Clear Cache") {
                    URLCache.shared.removeAllCachedResponses()
                }
            ]
        }
        PhantomSwift.launch()
        #endif
        return true
    }
}
```

## Opening the Dashboard

| Trigger | How |
|---------|-----|
| **Shake** | Shake the physical device (works in Simulator too) |
| **Dynamic Island** | Tap the floating pill overlay on iPhone 14 Pro and later |

Both triggers can be combined: `config.triggers = [.shake, .dynamicIsland]`

## Logging

Use ``PhantomLog`` (available once the module is enabled) to write structured, filterable
log entries:

```swift
#if DEBUG
PhantomLog.debug("View loaded",             tag: "UI")
PhantomLog.info("User signed in",           tag: "Auth")
PhantomLog.warning("Cache miss: \(key)",    tag: "Cache")
PhantomLog.error("Decode failed",           tag: "Network")
#endif
```

All entries are stored in-memory and surfaced in the **Console Logger** module with
full-text search and tag filtering.
