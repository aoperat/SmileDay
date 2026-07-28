import XCTest
@testable import CoachingKit

final class ReminderNotificationPayloadTests: XCTestCase {
    func test_userInfo_roundTrip() {
        let payload = ReminderNotificationPayload(reminderID: "reminder-1", guideID: "greeting-smile")

        let decoded = ReminderNotificationPayload(userInfo: payload.userInfo)

        XCTAssertEqual(decoded, payload)
    }

    func test_guide_resolvesGuideID() {
        let payload = ReminderNotificationPayload(reminderID: "reminder-1", guideID: "bright-smile")

        XCTAssertEqual(payload.guide.id, "bright-smile")
    }

    /// 카탈로그에서 사라진 ID여도 파싱은 성공하고, 열 때 기본 가이드로 대체된다.
    func test_init_keepsUnknownGuideID_andResolvesToDefault() {
        let payload = try? XCTUnwrap(ReminderNotificationPayload(
            userInfo: ["reminderID": "reminder-1", "guideID": "retired-guide"]
        ))

        XCTAssertEqual(payload?.guideID, "retired-guide")
        XCTAssertEqual(payload?.guide.id, "soft-smile")
    }

    func test_init_allowsMissingReminderID() {
        let payload = ReminderNotificationPayload(userInfo: ["guideID": "soft-smile"])

        XCTAssertEqual(payload?.reminderID, "")
        XCTAssertEqual(payload?.guideID, "soft-smile")
    }

    // MARK: - 구버전 알림

    /// 이미 예약된 구버전 알림을 탭해도 기본 가이드가 열려야 한다.
    func test_init_convertsLegacyBucketPayload_toDefaultGuide() {
        let payload = ReminderNotificationPayload(userInfo: ["bucket": "morning", "promptText": "오늘 어때요?"])

        XCTAssertEqual(payload?.guideID, "soft-smile")
        XCTAssertEqual(payload?.reminderID, "")
    }

    func test_init_convertsLegacyPayload_whenOnlyBucketPresent() {
        XCTAssertEqual(ReminderNotificationPayload(userInfo: ["bucket": "evening"])?.guideID, "soft-smile")
    }

    func test_init_convertsLegacyPayload_whenOnlyPromptTextPresent() {
        XCTAssertEqual(ReminderNotificationPayload(userInfo: ["promptText": "잠깐 웃어볼까요?"])?.guideID, "soft-smile")
    }

    /// 알 수 없는 bucket rawValue여도 기본 가이드로 연결한다 — 예전처럼 조용히 버리지 않는다.
    func test_init_convertsLegacyPayload_whenBucketRawValueUnknown() {
        XCTAssertEqual(ReminderNotificationPayload(userInfo: ["bucket": "midnight"])?.guideID, "soft-smile")
    }

    // MARK: - 열 수 없는 payload

    func test_init_returnsNil_whenUserInfoEmpty() {
        XCTAssertNil(ReminderNotificationPayload(userInfo: [:]))
    }

    func test_init_returnsNil_whenNoRecognizedField() {
        XCTAssertNil(ReminderNotificationPayload(userInfo: ["somethingElse": "value"]))
    }

    func test_init_returnsNil_whenGuideIDEmptyAndNotLegacy() {
        XCTAssertNil(ReminderNotificationPayload(userInfo: ["reminderID": "reminder-1", "guideID": ""]))
    }
}
