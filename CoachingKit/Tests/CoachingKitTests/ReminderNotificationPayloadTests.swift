import XCTest
@testable import CoachingKit

final class ReminderNotificationPayloadTests: XCTestCase {
    func test_userInfo_roundTrip() {
        let payload = ReminderNotificationPayload(reminderID: "reminder-1", guideID: "morning-greeting")

        let decoded = ReminderNotificationPayload(userInfo: payload.userInfo)

        XCTAssertEqual(decoded, payload)
    }

    /// payload는 ID만 나른다. 카드 해석은 `SmileGuideLibrary`가 해야 사용자가 만든 카드도 열린다.
    func test_carriesGuideIDVerbatim() {
        let payload = ReminderNotificationPayload(reminderID: "reminder-1", guideID: "my-custom-card")

        XCTAssertEqual(payload.guideID, "my-custom-card")
    }

    /// 카탈로그에서 사라진 ID여도 파싱은 성공한다. 대체는 여는 쪽에서 한다.
    func test_init_keepsUnknownGuideID() {
        let payload = ReminderNotificationPayload(userInfo: ["reminderID": "reminder-1", "guideID": "retired-guide"])

        XCTAssertEqual(payload?.guideID, "retired-guide")
    }

    func test_init_allowsMissingReminderID() {
        let payload = ReminderNotificationPayload(userInfo: ["guideID": "anytime-soft"])

        XCTAssertEqual(payload?.reminderID, "")
        XCTAssertEqual(payload?.guideID, "anytime-soft")
    }

    // MARK: - 구버전 알림

    /// 이미 예약된 구버전 알림을 탭해도 기본 가이드가 열려야 한다.
    func test_init_convertsLegacyBucketPayload_toDefaultGuide() {
        let payload = ReminderNotificationPayload(userInfo: ["bucket": "morning", "promptText": "오늘 어때요?"])

        XCTAssertEqual(payload?.guideID, "anytime-soft")
        XCTAssertEqual(payload?.reminderID, "")
    }

    func test_init_convertsLegacyPayload_whenOnlyBucketPresent() {
        XCTAssertEqual(ReminderNotificationPayload(userInfo: ["bucket": "evening"])?.guideID, "anytime-soft")
    }

    func test_init_convertsLegacyPayload_whenOnlyPromptTextPresent() {
        XCTAssertEqual(ReminderNotificationPayload(userInfo: ["promptText": "잠깐 웃어볼까요?"])?.guideID, "anytime-soft")
    }

    /// 알 수 없는 bucket rawValue여도 기본 가이드로 연결한다 — 예전처럼 조용히 버리지 않는다.
    func test_init_convertsLegacyPayload_whenBucketRawValueUnknown() {
        XCTAssertEqual(ReminderNotificationPayload(userInfo: ["bucket": "midnight"])?.guideID, "anytime-soft")
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
