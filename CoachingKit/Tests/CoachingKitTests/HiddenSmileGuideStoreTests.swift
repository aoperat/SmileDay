import XCTest
@testable import CoachingKit

final class HiddenSmileGuideStoreTests: XCTestCase {
    private let suite = "HiddenSmileGuideStoreTests"

    func test_inMemoryStore_startsEmpty() {
        XCTAssertTrue(InMemoryHiddenSmileGuideStore().hiddenGuideIDs.isEmpty)
    }

    func test_userDefaultsStore_roundTripsIDs() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let store = UserDefaultsHiddenSmileGuideStore(defaults: defaults)

        XCTAssertTrue(store.hiddenGuideIDs.isEmpty)
        store.hiddenGuideIDs = ["morning-coffee", "noon-before-call"]

        XCTAssertEqual(
            UserDefaultsHiddenSmileGuideStore(defaults: defaults).hiddenGuideIDs,
            ["morning-coffee", "noon-before-call"]
        )

        defaults.removePersistentDomain(forName: suite)
    }

    func test_userDefaultsStore_clearingLeavesEmptySet() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let store = UserDefaultsHiddenSmileGuideStore(defaults: defaults)
        store.hiddenGuideIDs = ["morning-coffee"]

        store.hiddenGuideIDs = []

        XCTAssertTrue(UserDefaultsHiddenSmileGuideStore(defaults: defaults).hiddenGuideIDs.isEmpty)
        defaults.removePersistentDomain(forName: suite)
    }
}
