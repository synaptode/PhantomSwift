#if DEBUG
import Foundation

/// A runtime feature flag override system for development debugging.
/// Allows registering, toggling, and persisting feature flag overrides.
public final class PhantomFeatureFlags {
    public static let shared = PhantomFeatureFlags()

    private let queue = DispatchQueue(label: "com.phantomswift.featureflags", attributes: .concurrent)
    private var flags: [String: FeatureFlag] = [:]
    private let persistenceKey = "com.phantom.featureflags.overrides"

    private init() {
        loadPersistedOverrides()
    }

    // MARK: - Public types

    public struct FeatureFlag {
        public let key: String
        public let title: String
        public let description: String
        public let defaultValue: Bool
        public var overrideValue: Bool?
        public let group: String

        /// The current effective value (override wins over default).
        public var currentValue: Bool {
            return overrideValue ?? defaultValue
        }

        /// Whether an override is active.
        public var isOverridden: Bool {
            return overrideValue != nil
        }
    }

    // MARK: - Registration

    /// Register a new feature flag that can be overridden from the HUD.
    public func register(key: String,
                         title: String,
                         description: String = "",
                         defaultValue: Bool,
                         group: String = "General") {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            // Preserve existing override if re-registering
            let existing = self.flags[key]
            var flag = FeatureFlag(
                key: key,
                title: title,
                description: description,
                defaultValue: defaultValue,
                overrideValue: existing?.overrideValue,
                group: group
            )
            // Load persisted override
            if let persisted = self.loadOverride(forKey: key) {
                flag.overrideValue = persisted
            }
            self.flags[key] = flag
        }
    }

    /// Check flag value at runtime.
    public func isEnabled(_ key: String) -> Bool {
        return queue.sync {
            flags[key]?.currentValue ?? false
        }
    }

    /// Override a flag.
    public func setOverride(_ key: String, value: Bool?) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.flags[key]?.overrideValue = value
            self.persistOverrides()
        }
    }

    /// Toggle a flag override.
    public func toggle(_ key: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            guard let flag = self.flags[key] else { return }
            let newValue = !(flag.overrideValue ?? flag.defaultValue)
            self.flags[key]?.overrideValue = newValue
            self.persistOverrides()
        }
    }

    /// Reset a specific flag override.
    public func resetOverride(_ key: String) {
        setOverride(key, value: nil)
    }

    /// Reset all overrides.
    public func resetAll() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            for key in self.flags.keys {
                self.flags[key]?.overrideValue = nil
            }
            UserDefaults.standard.removeObject(forKey: self.persistenceKey)
        }
    }

    /// Returns all registered flags grouped by group name.
    internal func allFlags() -> [String: [FeatureFlag]] {
        return queue.sync {
            var grouped: [String: [FeatureFlag]] = [:]
            for flag in flags.values.sorted(by: { $0.title < $1.title }) {
                grouped[flag.group, default: []].append(flag)
            }
            return grouped
        }
    }

    /// Returns all registered flags as a flat array.
    internal func allFlagsFlat() -> [FeatureFlag] {
        return queue.sync {
            Array(flags.values).sorted { $0.title < $1.title }
        }
    }

    /// Returns the count of active overrides.
    internal var overrideCount: Int {
        return queue.sync {
            flags.values.filter { $0.isOverridden }.count
        }
    }

    // MARK: - Persistence

    private func persistOverrides() {
        var dict: [String: Bool] = [:]
        for (key, flag) in flags {
            if let ov = flag.overrideValue {
                dict[key] = ov
            }
        }
        UserDefaults.standard.set(dict, forKey: persistenceKey)
    }

    private func loadPersistedOverrides() {
        // No-op at init — overrides are applied during register()
    }

    private func loadOverride(forKey key: String) -> Bool? {
        guard let dict = UserDefaults.standard.dictionary(forKey: persistenceKey) as? [String: Bool] else {
            return nil
        }
        return dict[key]
    }
}
#endif
