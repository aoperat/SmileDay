import XCTest
@testable import CoachingKit

final class ReminderNotificationPayloadTests: XCTestCase {
    func test_userInfo_roundTrip() {
        let payload = ReminderNotificationPayload(bucket: .evening, promptText: "지금 한 번 웃어볼까요?")

        let decoded = ReminderNotificationPayload(userInfo: payload.userInfo)

        XCTAssertEqual(decoded, payload)
    }

    func test_init_returnsNil_whenBucketMissing() {
        XCTAssertNil(ReminderNotificationPayload(userInfo: ["promptText": "text"]))
    }

    func test_init_returnsNil_whenPromptTextMissing() {
        XCTAssertNil(ReminderNotificationPayload(userInfo: ["bucket": "morning"]))
    }

    func test_init_returnsNil_whenBucketRawValueUnknown() {
        XCTAssertNil(ReminderNotificationPayload(userInfo: ["bucket": "midnight", "promptText": "text"]))
    }

    func test_init_returnsNil_whenUserInfoEmpty() {
        XCTAssertNil(ReminderNotificationPayload(userInfo: [:]))
    }
}
