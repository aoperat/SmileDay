import XCTest
@testable import CoachingKit

final class LiveSmileNudgeSettingsTests: XCTestCase {
    func test_default_isSixtySecondsWithHaptic() {
        let settings = LiveSmileNudgeSettings.default

        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(settings.intervalSeconds, 60)
        XCTAssertTrue(settings.isHapticEnabled)
    }

    func test_allowedIntervals_areSortedAndContainDefault() {
        XCTAssertEqual(
            LiveSmileNudgeSettings.allowedIntervalSeconds,
            LiveSmileNudgeSettings.allowedIntervalSeconds.sorted()
        )
        XCTAssertTrue(LiveSmileNudgeSettings.allowedIntervalSeconds.contains(60))
    }

    /// 목록에 없는 값이 저장돼 있어도 알림이 멈추면 안 된다.
    func test_init_snapsUnknownIntervalToNearestAllowed() {
        XCTAssertEqual(LiveSmileNudgeSettings(intervalSeconds: 55).intervalSeconds, 60)
        XCTAssertEqual(LiveSmileNudgeSettings(intervalSeconds: 0).intervalSeconds, 30)
        XCTAssertEqual(LiveSmileNudgeSettings(intervalSeconds: 9999).intervalSeconds, 180)
        XCTAssertEqual(LiveSmileNudgeSettings(intervalSeconds: -10).intervalSeconds, 30)
    }

    // MARK: - 저장소

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "live-smile-nudge-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }

    func test_store_returnsDefaults_whenNothingSaved() throws {
        let store = UserDefaultsLiveSmileNudgeSettingsStore(defaults: try makeDefaults())

        XCTAssertEqual(store.settings, .default)
    }

    func test_store_roundTripsEveryField() throws {
        let store = UserDefaultsLiveSmileNudgeSettingsStore(defaults: try makeDefaults())

        store.settings = LiveSmileNudgeSettings(
            isEnabled: false,
            intervalSeconds: 180,
            isHapticEnabled: false
        )

        XCTAssertEqual(
            store.settings,
            LiveSmileNudgeSettings(isEnabled: false, intervalSeconds: 180, isHapticEnabled: false)
        )
    }

    /// false로 저장한 것과 저장한 적 없는 것을 구분해야 한다.
    func test_store_keepsFalse_ratherThanFallingBackToDefault() throws {
        let store = UserDefaultsLiveSmileNudgeSettingsStore(defaults: try makeDefaults())

        store.settings = LiveSmileNudgeSettings(isEnabled: false, isHapticEnabled: false)

        XCTAssertFalse(store.settings.isEnabled)
        XCTAssertFalse(store.settings.isHapticEnabled)
    }

    func test_inMemoryStore_roundTrips() {
        let store = InMemorySmileNudgeStoreDouble()

        store.settings = LiveSmileNudgeSettings(intervalSeconds: 90)

        XCTAssertEqual(store.settings.intervalSeconds, 90)
    }

    private typealias InMemorySmileNudgeStoreDouble = InMemoryLiveSmileNudgeSettingsStore
}
