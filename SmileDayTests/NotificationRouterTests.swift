import XCTest
import CoachingKit
@testable import SmileDay

/// 알림 탭이 화면으로 이어지는 경계.
///
/// 여기서 잘못 판단하면 사용자가 겪는 일이 둘 중 하나다 — 알림을 지웠는데 가이드가 열리거나,
/// 알림을 눌렀는데 아무 일도 일어나지 않거나.
@MainActor
final class NotificationRouterTests: XCTestCase {

    func test_유효한_payload를_받으면_가이드를_연다() {
        let router = NotificationRouter()

        router.handleNotificationTap(
            userInfo: ReminderNotificationPayload(reminderID: "R1", guideID: "anytime-soft").userInfo
        )

        XCTAssertEqual(router.pendingSmileGuide?.guideID, "anytime-soft")
        XCTAssertEqual(router.pendingSmileGuide?.reminderID, "R1")
    }

    /// 가이드가 없던 시절 알림은 `bucket`/`promptText`를 싣고 있다. 그것도 열려야 한다 —
    /// 기기에 그 알림이 아직 예약돼 있는 사용자가 있다.
    func test_구버전_payload도_기본_가이드로_연다() {
        let router = NotificationRouter()

        router.handleNotificationTap(userInfo: ["bucket": "morning", "promptText": "웃어볼까요?"])

        XCTAssertEqual(router.pendingSmileGuide?.guideID, SmileGuideCatalog.default.id)
    }

    /// 해석할 수 없는 알림이면 **아무 일도 하지 않는다.**
    ///
    /// 여기서 기본 가이드를 열어버리면, 이 앱과 무관한 알림을 눌렀는데 미소 화면이 뜬다.
    func test_해석할_수_없는_payload면_홈에_머문다() {
        let router = NotificationRouter()

        router.handleNotificationTap(userInfo: ["somethingElse": "value"])

        XCTAssertNil(router.pendingSmileGuide)
    }

    func test_빈_userInfo면_홈에_머문다() {
        let router = NotificationRouter()

        router.handleNotificationTap(userInfo: [:])

        XCTAssertNil(router.pendingSmileGuide)
    }

    /// 빈 문자열 guideID는 유효한 값이 아니다. 저 값으로 가이드를 열면 어떤 가이드인지 모른 채 연다.
    func test_guideID가_비어있고_구버전_키도_없으면_홈에_머문다() {
        let router = NotificationRouter()

        router.handleNotificationTap(userInfo: ["reminderID": "R1", "guideID": ""])

        XCTAssertNil(router.pendingSmileGuide)
    }

    /// 홈이 payload를 읽고 nil로 되돌린 뒤에도 다음 알림을 받을 수 있어야 한다.
    func test_소비된_뒤에도_다음_알림을_받는다() {
        let router = NotificationRouter()

        router.handleNotificationTap(
            userInfo: ReminderNotificationPayload(reminderID: "R1", guideID: "anytime-soft").userInfo
        )
        router.pendingSmileGuide = nil

        router.handleNotificationTap(
            userInfo: ReminderNotificationPayload(reminderID: "R2", guideID: "anytime-soft").userInfo
        )

        XCTAssertEqual(router.pendingSmileGuide?.reminderID, "R2")
    }

    // MARK: - 가이드 없이 기록한 경우

    /// 앱이 이미 떠 있는 채로 배너의 "웃었어요"를 누르면 scenePhase가 바뀌지 않아 홈이 다시
    /// 읽지 않는다. 홈은 이 값의 **변화**를 신호로 쓴다.
    func test_가이드없이_기록하면_카운터가_오른다() {
        let router = NotificationRouter()
        XCTAssertEqual(router.recordedWithoutGuideCount, 0)

        router.noteRecordedWithoutGuide()
        XCTAssertEqual(router.recordedWithoutGuideCount, 1)

        router.noteRecordedWithoutGuide()
        XCTAssertEqual(router.recordedWithoutGuideCount, 2)
    }

    /// 기록은 가이드를 열지 않는다. 두 경로가 섞이면 "웃었어요"를 눌렀는데 앱이 열린다.
    func test_가이드없이_기록해도_가이드를_열지_않는다() {
        let router = NotificationRouter()

        router.noteRecordedWithoutGuide()

        XCTAssertNil(router.pendingSmileGuide)
    }
}
