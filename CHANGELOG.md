# Changelog

All notable changes to PhantomSwift will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-04-18

### Added
- 🧪 **Automated Test Coverage**: Added broad unit test coverage for configuration, event bus, feature catalog, launch planning, request store, analytics monitoring, interceptor flows, logger bridge, render store, feature flags, and location handling
- 🌐 **WKWebView Console Bridge**: Added WebView console capture plus auto-install support so hybrid app logs flow into PhantomSwift's logger pipeline
- 🚀 **Launch Planning & Feature Catalog**: Added launch planner and centralized feature catalog to improve feature discovery, gating, and module registration
- 🛠️ **Example App Test Infrastructure**: Added Example test target, shared scheme support, and project generation config to make the sample app verifiable in CI and locally

### Changed
- 🧱 **Networking Boundaries**: Split reusable networking primitives into `PhantomSwiftNetworking` to improve package structure and reduce coupling between transport logic and UI/debug surfaces
- 🎛️ **Module UX Polish**: Refined interceptor, dashboard, network list, grid overlay, view hierarchy, and other inspector flows for more reliable navigation and better ergonomics
- 🤖 **CI/CD Pipeline**: Added and iterated on GitHub Actions workflows for iOS builds and tests, improving release confidence and repo automation
- 📚 **Documentation**: Clarified compatibility and setup guidance for iOS 12 and Swift 5-era consumers

### Fixed
- 🩹 **iOS 12 Compatibility**: Filled in missing SF Symbol fallbacks and other availability-safe UI paths across multiple modules
- 🔒 **Presentation & Lifecycle Safety**: Improved presentation resolution, dismissal behavior, cleanup paths, and event subscription handling to reduce UI inconsistencies and retain-cycle risk
- 🧠 **Memory & Diagnostics Accuracy**: Improved heap snapshot and leak-tracking behavior, request replay/supporting inspectors, and several diagnostic views
- ✅ **Build/Test Reliability**: Fixed multiple CI, package-test, and example-project issues that previously made verification brittle

### Technical Notes
- **SemVer rationale**: Released as a minor because this ships new capabilities, architectural refactoring, and substantially expanded verification surface without intentionally breaking the public integration model
- **Release focus**: Stability, observability, and maintainability after the recent PR train leading up to PR #48
- **Recommended upgrade**: Consumers on `1.0.x` can move to `1.1.0` directly for better CI/test confidence and improved iOS 12 compatibility
## [1.0.2] - 2026-03-31

### Fixed
- 🔧 **SPI Build Fix**: Replaced direct `_dyld_image_count()` / `_dyld_get_image_name()` calls with `dlsym`-based dynamic resolution in `PhantomSecurityInspector.swift` — the Swift `MachO` module does not expose these C symbols on iOS, causing build failures on Swift Package Index across all Xcode versions (15.4, 16.2, 16.3, 26.0)
- 🏗️ **Compatibility**: Verified build succeeds on Swift 5.10, 6.0, 6.1, and 6.2 for iOS

## [1.0.1] - 2026-03-30

### Fixed
- 🔧 **Build Fix**: Added missing `import MachO` in `PhantomSecurityInspector.swift` to resolve `_dyld_image_count` and `_dyld_get_image_name` compilation errors across all Swift versions (5.10, 6.0, 6.1, 6.2)

## [1.0.0] - 2026-03-30

### Added
- ✨ **25 Debug Modules**: Comprehensive debugging toolkit including network interception, performance monitoring, memory leak detection, UI inspection, and more
- 🎨 **3D View Hierarchy Inspector**: Advanced UIView tree visualization with exploded 3D rendering, gesture-based rotation, zoom, and pan controls
- 📊 **Network Interceptor**: Real-time HTTP/HTTPS request/response inspection with rule-based mock responses
- 🚀 **Performance Monitor**: App startup time, frame rate monitoring, memory usage tracking
- 💾 **Storage Inspector**: UserDefaults, Keychain, file system, and CoreData inspection
- 📝 **Logger Console**: Unified logging with OSLog bridge, log levels (verbose, debug, info, warn, error)
- 🔍 **Asset Auditor**: Image asset size analyzer and optimization suggestions
- 🌐 **Environment Manager**: Hardware info, GPS spoofing, localization override, thermal state, battery simulation
- ♿ **Accessibility Inspector**: Element hierarchy, accessibility labels, traits inspection
- 🔐 **Security Inspector**: Certificate pinning, encryption verification, secure storage validation
- 📈 **Analytics Debugger**: Event feed and provider tracking for analytics implementations

### Fixed
- 🐛 **3D View Zoom Anomalies**: Fixed zoom-on-entry regression (saat masuk terlalu zoom) and fit-all overzoom issues with proportional calculation
- 👆 **Gesture Interactions**: Implemented UIGestureRecognizerDelegate for simultaneous pan/pinch recognition; added rotation sliders for z-axis control
- 💥 **Crash Prevention**: Added bounds checking (idx < snapshots.count) in applySelection() and handleTap() to prevent index out of range crashes
- 🔄 **Memory Management**: Added [weak self] in animation closures in showInspector, closeInspector, focusSelected to prevent retain cycles
- 🛑 **Double Cleanup**: Added isCleanedUp flag to prevent redundant cleanup in both viewWillDisappear and deinit
- 🎯 **Deprecated API**: Replaced UIGraphicsBeginImageContextWithOptions with UIGraphicsImageRenderer for iOS 10+ compatibility

### Changed
- 📚 **Documentation**: Expanded README from 434 lines to 825+ lines with detailed module descriptions, usage examples, architecture diagram, and configuration guide
- 📷 **Visual Assets**: Integrated 31 UI screenshots from phantom-swift-ui across all major modules
- 🔧 **.gitignore**: Expanded from 43 to 120 lines with organized sections for Xcode, SPM, CocoaPods, Carthage, Fastlane, coverage tools, and IDEs

### Technical Details
- **Target**: iOS 12.0+ with #available guards for iOS 13+ APIs
- **Dependencies**: Zero external dependencies (Apple frameworks only)
- **Language**: Swift 5.0+ / Swift 5.9+ recommended
- **Architecture**: UIKit-first, programmatic UI layout (no storyboards/XIBs)
- **Debug Wrapping**: All code within #if DEBUG / #endif
- **Theme System**: Unified PhantomTheme for consistent, modern dark-mode UI
- **Event Bus**: PhantomEventBus for decoupled module communication
- **Threading**: DispatchQueue with .barrier for thread-safe operations

### Installation
- **SPM**: Add to Package.swift or Xcode build settings
- **CocoaPods**: pod 'PhantomSwift', '~> 1.0.0'
- **Manual**: Copy Sources/PhantomSwift/ to your project

### Known Limitations
- Requires DEBUG build configuration to activate
- 3D hierarchy rendering optimized for iOS 14+ (iOS 12-13 fallback to 2D)
- Dynamic Island support for iOS 16.1+
- Max 10,000 log entries in memory (circular buffer)
- Network interception excludes WebSocket and custom URLProtocol subclasses

---

## Versioning Strategy

PhantomSwift follows **Semantic Versioning (SemVer)**:

- **MAJOR** (e.g., 1.0.0): Breaking API changes, architecture refactors
- **MINOR** (e.g., 1.x.0): New features, new modules, backward-compatible additions
- **PATCH** (e.g., 1.0.x): Bug fixes, performance improvements, documentation updates

### Release Cadence
- **Patch**: As needed for critical bug fixes
- **Minor**: Monthly or as new features stabilize
- **Major**: Annually or with significant architectural changes

### Pre-release Tags
- **Beta**: 1.0.0-beta.1 (feature-complete, under testing)
- **RC**: 1.0.0-rc.1 (release candidate, minimal changes)
- **Alpha**: 1.0.0-alpha.1 (early development, unstable)

---

## Migration Guide

### From Previous Versions
N/A - This is the initial release.

### Upgrading to Future Versions
See individual release notes for migration steps.

---

## Contributors
- MRLF (@synaptode)

## License
MIT - See LICENSE file for details
