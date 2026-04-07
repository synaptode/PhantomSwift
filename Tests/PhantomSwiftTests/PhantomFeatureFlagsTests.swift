import XCTest
@testable import PhantomSwift

final class PhantomFeatureFlagsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Ensure clean state before each test
        PhantomFeatureFlags.shared.resetAll()
        UserDefaults.standard.removeObject(forKey: "com.phantom.featureflags.overrides")
    }

    override func tearDown() {
        PhantomFeatureFlags.shared.resetAll()
        UserDefaults.standard.removeObject(forKey: "com.phantom.featureflags.overrides")
        super.tearDown()
    }

    func testSetOverride() {
        let sut = PhantomFeatureFlags.shared
        let key = "test_override_flag"

        // 1. Register a flag with default false
        sut.register(key: key, title: "Test Flag", defaultValue: false)

        // Ensure default is false
        // isEnabled uses queue.sync which guarantees the register barrier has executed.
        XCTAssertFalse(sut.isEnabled(key))

        // 2. Set override to true
        sut.setOverride(key, value: true)

        // Ensure it is now enabled.
        // isEnabled uses queue.sync which guarantees the setOverride barrier has executed.
        XCTAssertTrue(sut.isEnabled(key))

        // 3. Set override to false
        sut.setOverride(key, value: false)

        // Ensure it is now disabled
        XCTAssertFalse(sut.isEnabled(key))

        // 4. Remove override (set to nil)
        sut.setOverride(key, value: nil)

        // Ensure it falls back to default
        XCTAssertFalse(sut.isEnabled(key))
    }

    func testSetOverridePersists() {
        let sut = PhantomFeatureFlags.shared
        let key = "test_persist_flag"

        sut.register(key: key, title: "Test Persist Flag", defaultValue: false)

        // Set override
        sut.setOverride(key, value: true)

        // Flush queue by performing a sync read
        _ = sut.isEnabled(key)

        // Verify UserDefaults actually has the persisted value
        let persistenceKey = "com.phantom.featureflags.overrides"
        let dict = UserDefaults.standard.dictionary(forKey: persistenceKey) as? [String: Bool]
        XCTAssertNotNil(dict, "UserDefaults should contain the overrides dictionary")
        XCTAssertEqual(dict?[key], true, "The persisted value should match the override")
    }

    func testSetOverrideForUnregisteredFlag() {
        let sut = PhantomFeatureFlags.shared
        let key = "test_unregistered_flag"

        // Set override for a flag that has not been registered
        sut.setOverride(key, value: true)

        // Flush queue
        _ = sut.isEnabled(key)

        // Register the flag afterwards with default false
        sut.register(key: key, title: "Unregistered Flag", defaultValue: false)

        // It should not pick up the override, because setOverride modifies existing flags.
        // Wait, the setOverride logic says: `self.flags[key]?.overrideValue = value`
        // If the flag doesn't exist in `flags` dict, `setOverride` does nothing to `flags[key]`.
        // Let's test that it *doesn't* crash and fails gracefully (flag is false).
        XCTAssertFalse(sut.isEnabled(key), "Setting an override for an unregistered flag should have no effect")
    }
}
