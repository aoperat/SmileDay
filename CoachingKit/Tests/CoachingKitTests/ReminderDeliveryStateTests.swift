import XCTest
@testable import CoachingKit

/// 알림이 도착할 수 있는 상태인지 판단하는 규칙.
///
/// 가장 중요한 경우는 "일정은 켜져 있는데 권한이 없는" 조합이다. 그 상태에서 다음 시각을
/// 그대로 보여주면 앱이 오지 않을 알림을 약속하게 된다.
final class ReminderDeliveryStateTests: XCTestCase {
    private let reminder = UpcomingReminder(date: Date(timeIntervalSince1970: 1_785_000_000))

    func test_authorizedAndEnabled_promisesTheTime() {
        let state = ReminderDeliveryState(
            authorization: .authorized,
            isScheduleEnabled: true,
            nextReminder: reminder
        )

        XCTAssertEqual(state, .scheduled(reminder))
        XCTAssertFalse(state.needsAttention)
    }

    /// 앱은 예약을 마쳤다고 믿지만 iOS가 막고 있다 — 시각을 약속하면 거짓말이 된다.
    func test_deniedPermission_isReportedEvenThoughScheduleLooksReady() {
        let state = ReminderDeliveryState(
            authorization: .denied,
            isScheduleEnabled: true,
            nextReminder: reminder
        )

        XCTAssertEqual(state, .blockedByPermission)
        XCTAssertTrue(state.needsAttention)
    }

    func test_notDetermined_asksRatherThanBlames() {
        let state = ReminderDeliveryState(
            authorization: .notDetermined,
            isScheduleEnabled: true,
            nextReminder: reminder
        )

        XCTAssertEqual(state, .permissionNotRequested)
        XCTAssertTrue(state.needsAttention)
    }

    /// 사용자가 끈 것은 사용자의 선택이다. 권한 문제로 바꿔 말하지 않는다.
    func test_scheduleOff_staysScheduleOff_whateverThePermissionIs() {
        for authorization in [ReminderAuthorizationStatus.authorized, .denied, .notDetermined] {
            let state = ReminderDeliveryState(
                authorization: authorization,
                isScheduleEnabled: false,
                nextReminder: reminder
            )

            XCTAssertEqual(state, .off, "권한 \(authorization)에서 꺼둔 일정이 다른 상태로 보고됐다")
        }
    }

    /// 권한이 있어도 다음 시각을 못 구하면 약속할 것이 없다.
    func test_authorizedWithoutAnUpcomingTime_isOff() {
        let state = ReminderDeliveryState(
            authorization: .authorized,
            isScheduleEnabled: true,
            nextReminder: nil
        )

        XCTAssertEqual(state, .off)
        XCTAssertTrue(state.needsAttention)
    }
}
