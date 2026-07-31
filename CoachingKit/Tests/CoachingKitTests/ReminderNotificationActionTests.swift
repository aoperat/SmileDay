import XCTest
@testable import CoachingKit

final class ReminderNotificationActionTests: XCTestCase {

    // MARK: - 호환 계약

    /// 기기에 이미 예약된 알림이 이 문자열들을 담고 있다. 바꾸면 그 알림의 버튼이 죽는다.
    ///
    /// 값을 직접 적어 고정한다 — `action.rawValue`와 비교하면 함께 바뀌어 아무것도 못 막는다.
    func test_identifiers_areFrozen() {
        XCTAssertEqual(ReminderNotificationAction.recordSmile.rawValue, "smile-recorded")
        XCTAssertEqual(ReminderNotificationAction.openGuide.rawValue, "open-guide")
        XCTAssertEqual(ReminderNotificationCategory.identifier, "smile-reminder")
    }

    func test_rawValues_roundTrip() {
        for action in ReminderNotificationAction.allCases {
            XCTAssertEqual(ReminderNotificationAction(rawValue: action.rawValue), action)
        }
    }

    /// iOS가 보내는 기본 탭·해제 식별자를 버튼으로 오인하면 안 된다.
    func test_systemIdentifiers_areNotActions() {
        XCTAssertNil(ReminderNotificationAction(rawValue: "com.apple.UNNotificationDefaultActionIdentifier"))
        XCTAssertNil(ReminderNotificationAction(rawValue: "com.apple.UNNotificationDismissActionIdentifier"))
    }

    // MARK: - 동작 구분

    /// 기록은 화면 없이 끝나야 한다. 앱이 열리면 지금 흐름과 같아져 만든 이유가 사라진다.
    func test_recordSmile_doesNotOpenTheApp() {
        XCTAssertFalse(ReminderNotificationAction.recordSmile.opensApp)
    }

    func test_openGuide_opensTheApp() {
        XCTAssertTrue(ReminderNotificationAction.openGuide.opensApp)
    }

    // MARK: - 문구

    func test_titles_areKoreanAndNonEmpty() {
        for action in ReminderNotificationAction.allCases {
            XCTAssertFalse(action.title.isEmpty)
            XCTAssertTrue(
                action.title.contains(where: { ("가"..."힣").contains($0) }),
                "\(action)의 문구가 한국어가 아니다: \(action.title)"
            )
        }
    }

    /// 건강 효과 문구(App Store 1.4.1)와 순위·연속 실패 어휘를 쓰지 않는다.
    func test_titles_avoidBannedWording() {
        let banned = ["리프팅", "젊어", "교정", "치료", "연속", "실패", "달성"]
        for action in ReminderNotificationAction.allCases {
            for word in banned {
                XCTAssertFalse(
                    action.title.contains(word),
                    "\(action)의 문구에 금지어 '\(word)'가 있다: \(action.title)"
                )
            }
        }
    }
}
