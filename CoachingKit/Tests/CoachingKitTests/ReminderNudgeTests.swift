import XCTest
@testable import CoachingKit

final class ReminderNudgeTests: XCTestCase {
    func test_shouldOfferAfterCheckIn_trueOnlyWhenNoRemindersAndNotDeclined() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        XCTAssertTrue(nudge.shouldOfferAfterCheckIn(reminderCount: 0))
        XCTAssertFalse(nudge.shouldOfferAfterCheckIn(reminderCount: 1))
    }

    func test_declineCheckInPrompt_suppressesFutureOffers() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        nudge.declineCheckInPrompt()
        XCTAssertFalse(nudge.shouldOfferAfterCheckIn(reminderCount: 0))
    }

    func test_shouldShowHomeCard_requiresCheckInHistoryAndNoReminders() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        XCTAssertTrue(nudge.shouldShowHomeCard(reminderCount: 0, hasAnyCheckIn: true))
        XCTAssertFalse(nudge.shouldShowHomeCard(reminderCount: 0, hasAnyCheckIn: false))
        XCTAssertFalse(nudge.shouldShowHomeCard(reminderCount: 2, hasAnyCheckIn: true))
    }

    func test_dismissHomeCard_suppressesCard() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        nudge.dismissHomeCard()
        XCTAssertFalse(nudge.shouldShowHomeCard(reminderCount: 0, hasAnyCheckIn: true))
    }

    func test_declineAndDismiss_areIndependentFlags() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        nudge.declineCheckInPrompt()
        XCTAssertTrue(nudge.shouldShowHomeCard(reminderCount: 0, hasAnyCheckIn: true),
                      "체크인 제안 거절이 홈 카드까지 숨기면 안 된다")
    }

    func test_userDefaultsStore_persistsAcrossInstances() throws {
        let suiteName = "reminder-nudge-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = UserDefaultsReminderNudgeState(defaults: defaults)
        first.hasDeclinedCheckInPrompt = true
        first.hasDismissedHomeCard = true

        let second = UserDefaultsReminderNudgeState(defaults: defaults)
        XCTAssertTrue(second.hasDeclinedCheckInPrompt)
        XCTAssertTrue(second.hasDismissedHomeCard)
    }
}
