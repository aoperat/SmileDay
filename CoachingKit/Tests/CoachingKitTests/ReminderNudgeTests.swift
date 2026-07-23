import XCTest
@testable import CoachingKit

final class ReminderNudgeTests: XCTestCase {
    func test_shouldOfferAfterCheckIn_onlyWhenCurrentBucketMissing() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        XCTAssertTrue(nudge.shouldOfferAfterCheckIn(registeredBuckets: [], checkInHour: 9))
        XCTAssertFalse(nudge.shouldOfferAfterCheckIn(registeredBuckets: [.morning], checkInHour: 9))
        XCTAssertTrue(nudge.shouldOfferAfterCheckIn(registeredBuckets: [.morning], checkInHour: 20))
    }

    func test_declineCheckInPrompt_isPerBucket() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        nudge.declineCheckInPrompt(forHour: 9) // 아침 거절
        XCTAssertFalse(nudge.shouldOfferAfterCheckIn(registeredBuckets: [], checkInHour: 10))
        XCTAssertTrue(nudge.shouldOfferAfterCheckIn(registeredBuckets: [], checkInHour: 20),
                      "아침 거절이 저녁 제안을 막으면 안 된다")
    }

    func test_missingBuckets_keepsAllCasesOrder() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        XCTAssertEqual(nudge.missingBuckets(registeredBuckets: [.afternoon]), [.morning, .evening])
        XCTAssertEqual(nudge.missingBuckets(registeredBuckets: []), [.morning, .afternoon, .evening])
        XCTAssertEqual(nudge.missingBuckets(registeredBuckets: [.morning, .afternoon, .evening]), [])
    }

    func test_shouldShowHomeCard_whenAnyBucketMissing() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        XCTAssertTrue(nudge.shouldShowHomeCard(registeredBuckets: [.morning], hasAnyCheckIn: true))
        XCTAssertFalse(nudge.shouldShowHomeCard(registeredBuckets: [.morning, .afternoon, .evening], hasAnyCheckIn: true))
        XCTAssertFalse(nudge.shouldShowHomeCard(registeredBuckets: [], hasAnyCheckIn: false))
    }

    func test_dismissHomeCard_hidesUntilMissingSetChanges() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        nudge.dismissHomeCard(registeredBuckets: [.morning]) // 빈 버킷: 낮·저녁
        XCTAssertFalse(nudge.shouldShowHomeCard(registeredBuckets: [.morning], hasAnyCheckIn: true))
        // 낮 리마인더 추가 → 빈 버킷 조합이 [저녁]으로 달라짐 → 재노출
        XCTAssertTrue(nudge.shouldShowHomeCard(registeredBuckets: [.morning, .afternoon], hasAnyCheckIn: true))
    }

    func test_userDefaultsStore_persistsAcrossInstances() throws {
        let suiteName = "reminder-nudge-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = UserDefaultsReminderNudgeState(defaults: defaults)
        first.declinedBuckets = [.morning, .evening]
        first.dismissedHomeCardMissingBuckets = [.afternoon]

        let second = UserDefaultsReminderNudgeState(defaults: defaults)
        XCTAssertEqual(second.declinedBuckets, [.morning, .evening])
        XCTAssertEqual(second.dismissedHomeCardMissingBuckets, [.afternoon])
    }

    func test_userDefaultsStore_snapshotNilMeansNeverDismissed() throws {
        let suiteName = "reminder-nudge-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsReminderNudgeState(defaults: defaults)
        XCTAssertNil(store.dismissedHomeCardMissingBuckets)
    }
}
