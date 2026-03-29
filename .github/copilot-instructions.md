# PhantomSwift — Copilot Instructions

## Project Context
PhantomSwift is a **zero-dependency iOS debugging library** written in Swift.
- Target: iOS 12.0+ (use `#available` guards for newer APIs)
- Language: Swift 5.9+, UIKit-first, no SwiftUI in library core
- No external dependencies — solve everything with Apple frameworks only
- All code MUST be wrapped in `#if DEBUG` / `#endif`

## Code Generation Rules

### Swift Style
- Use `final class` for performance unless inheritance is required
- Prefer `struct` for value types (models, configs); `class` for UIKit controllers
- Use Swift concurrency (`async/await`, `actor`) for iOS 15+ code; `DispatchQueue` for iOS 12 compat
- Always use `[weak self]` in closures that may outlive the caller
- Mark internal APIs `internal` (default), public API explicitly `public`

### UIKit Patterns
- Build all UI programmatically — no storyboards, no XIBs
- Use `NSLayoutConstraint.activate([...])` — never `translatesAutoresizingMaskIntoConstraints = true`
- Use `UICollectionViewCompositionalLayout` for complex layouts (iOS 13+)
- Wrap `UIImage(systemName:)` in `if #available(iOS 13.0, *)`
- Use `PhantomTheme.shared` for all colors, fonts, shadows — never hardcode colors

### Architecture
- Singleton pattern for module managers (e.g., `PhantomLog.shared`)
- Event communication via `PhantomEventBus` — not `NotificationCenter`
- Thread safety: use `DispatchQueue(label:, attributes: .concurrent)` with `.barrier` for writes
- View controllers go in `Modules/<Name>/UI/`, core logic in `Modules/<Name>/Core/`

### iOS Availability
- Wrap iOS 13+ APIs: `if #available(iOS 13.0, *) { ... } else { /* fallback */ }`
- Do NOT use `@available` on entire classes unless the whole class is iOS 13+
- SF Symbols require iOS 13 — always provide text/Menlo fallback

### Naming Conventions
- Prefix all public types: `Phantom` (e.g., `PhantomLog`, `PhantomTheme`)
- Module cells: `<Name>Cell`, VCs: `<Name>VC`, Core: `Phantom<Name>`
- Extensions: `UIColor+Phantom.swift`, `UIFont+Phantom.swift`

### Testing & Safety
- Never force-unwrap (`!`) — use guard/if let or provide meaningful fallback
- Use `PhantomSwizzler` for method swizzling, never raw `method_exchangeImplementations`
- Avoid retain cycles: prefer `weak` delegates, `[weak self]` in closures

## Key Files
- Entry point: `Sources/PhantomSwift/Core/PhantomSwift.swift`
- Theme system: `Sources/PhantomSwift/HUD/PhantomTheme.swift`
- Feature list: `Sources/PhantomSwift/Core/PhantomFeature.swift`
- Event bus: `Sources/PhantomSwift/Core/PhantomEventBus.swift`
