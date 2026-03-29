# Changelog

All notable changes to PhantomSwift will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
