# Configuration

Customize PhantomSwift's behaviour, triggers, and active modules before launch.

## Overview

All configuration is done through ``PhantomConfig`` inside a ``PhantomSwift/PhantomSwift/configure(_:)``
closure.  Call ``PhantomSwift/PhantomSwift/launch()`` afterwards; calling it before
`configure` is safe but will use default values.

```swift
#if DEBUG
PhantomSwift.configure { config in
    config.environment       = .staging
    config.triggers          = [.shake, .dynamicIsland]
    config.theme             = .auto
    config.enableOSLogBridge = true          // iOS 15+ only
    config.shortcuts         = [
        AppShortcut(title: "Reset Onboarding") {
            UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
        }
    ]
}
PhantomSwift.launch()
#endif
```

## Environment

``PhantomEnvironment`` controls which backend environment badge is shown in the dashboard
header.

| Value | Typical use |
|-------|-------------|
| `.dev` | Local / development server |
| `.staging` | Pre-production environment |
| `.release` | Production environment |

```swift
config.environment = .staging
```

## Triggers

``PhantomConfig/TriggerType`` defines how the PhantomSwift dashboard is opened.

| Value | Description |
|-------|-------------|
| `.shake` | Physical shake gesture (default; also works in Simulator) |
| `.dynamicIsland` | Floating pill overlay — tap to open the dashboard |

```swift
config.triggers = [.shake, .dynamicIsland]  // Enable both simultaneously
```

## Theme

``PhantomConfig/ThemeType`` controls the overall appearance of the dashboard and all module
screens.

| Value | Description |
|-------|-------------|
| `.dark` | Forces dark glassmorphic UI (default) |
| `.light` | Forces light UI |
| `.auto` | Follows the device's system interface style |

## OSLog Bridge

When `enableOSLogBridge` is `true`, PhantomSwift polls `OSLogStore` every two seconds
(iOS 15+) and imports new log entries into the **Console Logger** module.  Entries from
non-app subsystems below `warning` level are filtered automatically.

```swift
config.enableOSLogBridge = true   // iOS 15+; no-op on earlier OS versions
```

## Custom QA Shortcuts

``AppShortcut`` lets you register quick actions that appear as tappable buttons inside the
**QA** module. Use them to trigger common developer tasks without leaving the app:

```swift
config.shortcuts = [
    AppShortcut(title: "Clear Image Cache") {
        URLCache.shared.removeAllCachedResponses()
    },
    AppShortcut(title: "Delete All Data") {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
    },
    AppShortcut(title: "Force Memory Warning") {
        // Simulate a memory pressure event for testing
        UIApplication.shared.perform(Selector(("_performMemoryWarning")))
    }
]
```

> Important: All shortcuts execute on the main thread. For background work, dispatch
> inside the closure as needed.

## Feature Flags

Register feature flags at launch so they appear in the **Feature Flags** module panel:

```swift
#if DEBUG
PhantomFeatureFlags.shared.register(
    key:          "new_checkout_flow",
    title:        "New Checkout Flow",
    defaultValue: false,
    group:        "Commerce"
)
#endif

// Anywhere in your code:
#if DEBUG
if PhantomFeatureFlags.shared.isEnabled("new_checkout_flow") {
    showNewCheckout()
}
#endif
```

Flag override states are persisted across app launches via `UserDefaults`.
