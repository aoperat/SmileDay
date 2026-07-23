import XCTest
@testable import CoachingKit

final class BaselineResetNudgeTests: XCTestCase {
    func test_shouldShowHomeCard_trueWhenRecommendedAndNotSnoozed() {
        let nudge = BaselineResetNudge(store: InMemoryBaselineResetNudgeState())
        XCTAssertTrue(nudge.shouldShowHomeCard(shouldRecommendReset: true, now: Date()))
    }

    func test_shouldShowHomeCard_falseWhenNotRecommended() {
        let nudge = BaselineResetNudge(store: InMemoryBaselineResetNudgeState())
        XCTAssertFalse(nudge.shouldShowHomeCard(shouldRecommendReset: false, now: Date()))
    }

    func test_snooze_hidesCardUntilSnoozeExpires() {
        let store = InMemoryBaselineResetNudgeState()
        let nudge = BaselineResetNudge(store: store)
        let now = Date()

        nudge.snooze(now: now, days: 7)

        XCTAssertFalse(nudge.shouldShowHomeCard(shouldRecommendReset: true, now: now))
        let eightDaysLater = Calendar.current.date(byAdding: .day, value: 8, to: now)!
        XCTAssertTrue(nudge.shouldShowHomeCard(shouldRecommendReset: true, now: eightDaysLater))
    }

    func test_clearSnooze_showsCardImmediately() {
        let store = InMemoryBaselineResetNudgeState()
        let nudge = BaselineResetNudge(store: store)
        let now = Date()
        nudge.snooze(now: now, days: 7)

        nudge.clearSnooze()

        XCTAssertTrue(nudge.shouldShowHomeCard(shouldRecommendReset: true, now: now))
    }

    func test_userDefaultsStore_persistsAcrossInstances() throws {
        let suiteName = "baseline-reset-nudge-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let now = Date()
        let first = UserDefaultsBaselineResetNudgeState(defaults: defaults)
        first.snoozedUntil = now

        let second = UserDefaultsBaselineResetNudgeState(defaults: defaults)
        XCTAssertEqual(second.snoozedUntil?.timeIntervalSince1970 ?? 0, now.timeIntervalSince1970, accuracy: 0.001)
    }
}
