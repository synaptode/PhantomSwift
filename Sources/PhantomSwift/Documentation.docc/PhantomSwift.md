# ``PhantomSwift``

The Elite, Zero-Dependency iOS Debugging & Diagnostic Toolkit.

## Overview

**PhantomSwift** is a production-safe, modular debugging ecosystem for iOS apps. It ships
**25+ rich modules** — from network inspection and performance profiling to remote WebSocket
debugging and macro recording — all wrapped in a premium glassmorphic UI.

Every line of code is compiled only in `#if DEBUG` builds, so PhantomSwift adds **zero
overhead** to your production binary.

```swift
// AppDelegate.swift or @main App
#if DEBUG
import PhantomSwift
#endif

// In your app's entry point:
#if DEBUG
PhantomSwift.configure { config in
    config.environment = .dev
    config.triggers   = [.shake, .dynamicIsland]
    config.theme      = .dark
}
PhantomSwift.launch()
#endif
```

Shake the device (or tap the Dynamic Island overlay) to open the dashboard and access all
debugging tools instantly.

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Configuration>

### Core API

- ``PhantomSwift/PhantomSwift``
- ``PhantomConfig``
- ``PhantomEnvironment``
- ``AppShortcut``

### Modules

- ``PhantomFeature``

### Events

- ``PhantomEventBus``
- ``PhantomEvent``
- ``PhantomEventObserver``

### Extensibility

- ``PhantomPlugin``
