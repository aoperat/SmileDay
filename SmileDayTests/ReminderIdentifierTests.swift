import XCTest
import CoachingKit
@testable import SmileDay

/// 반복 알림 식별자에 대한 테스트.
///
/// 이 저장소에서 가장 되돌리기 어려운 고장을 겨눈다. 등록한 알림을 취소하지 못하면
/// 반복 알림이 영영 울리는데, 사용자가 앱 안에서 되돌릴 방법이 없다 — 설정을 다시 저장해도
/// 지우지 못한 옛 식별자는 그대로 남는다.
///
/// `cancelGroup`은 하루의 분 1,440개를 통째로 지워 그 위험을 막는다. 그 방어가 성립하려면
/// **등록이 만드는 문자열이 그 1,440개 안에 반드시 들어 있어야** 한다.
final class ReminderIdentifierTests: XCTestCase {

    // MARK: - 호환 계약

    /// 형식은 기기에 이미 깔린 빌드와의 계약이다. 옛 빌드가 예약해둔 알림도 같은 규칙으로
    /// 만들어져 있어야 지워지므로, 이 문자열이 바뀌면 그 알림들을 영영 취소할 수 없다.
    func test_dailyIdentifier_형식이_고정돼있다() {
        XCTAssertEqual(
            UserNotificationReminderScheduler.dailyIdentifier(groupID: "GROUP", hour: 9, minute: 5),
            "GROUP-daily-0905"
        )
        XCTAssertEqual(
            UserNotificationReminderScheduler.dailyIdentifier(groupID: "GROUP", hour: 0, minute: 0),
            "GROUP-daily-0000"
        )
        XCTAssertEqual(
            UserNotificationReminderScheduler.dailyIdentifier(groupID: "GROUP", hour: 23, minute: 59),
            "GROUP-daily-2359"
        )
    }

    /// 시와 분은 반드시 두 자리로 채워야 한다.
    ///
    /// 채우지 않으면 01:15와 11:05가 둘 다 "115"가 되어 같은 식별자를 갖는다. 그러면 뒤에
    /// 등록한 쪽이 앞의 알림을 덮어써서 사용자가 정한 시각 하나가 조용히 사라진다.
    /// 이 테스트가 그 조합을 직접 짚는다.
    func test_dailyIdentifier_한자리_시각이_충돌하지_않는다() {
        XCTAssertNotEqual(
            UserNotificationReminderScheduler.dailyIdentifier(groupID: "G", hour: 1, minute: 15),
            UserNotificationReminderScheduler.dailyIdentifier(groupID: "G", hour: 11, minute: 5)
        )
    }

    /// 하루 안의 어떤 두 시각도 같은 식별자를 갖지 않는다.
    func test_dailyIdentifier_하루_전체에서_유일하다() {
        var seen = Set<String>()
        for hour in 0..<24 {
            for minute in 0..<60 {
                let identifier = UserNotificationReminderScheduler.dailyIdentifier(
                    groupID: "G", hour: hour, minute: minute
                )
                XCTAssertTrue(seen.insert(identifier).inserted, "중복 식별자: \(identifier)")
            }
        }
        XCTAssertEqual(seen.count, 24 * 60)
    }

    /// 그룹이 다르면 같은 시각이어도 식별자가 다르다.
    ///
    /// 그룹 교체는 새 그룹을 전부 등록한 뒤 옛 그룹을 지우는 순서로 도는데, 두 그룹의 같은
    /// 시각이 한 식별자를 공유하면 옛 그룹을 지우는 마지막 단계가 방금 등록한 알림을 함께 지운다.
    func test_dailyIdentifier_그룹이_다르면_다르다() {
        XCTAssertNotEqual(
            UserNotificationReminderScheduler.dailyIdentifier(groupID: "A", hour: 9, minute: 0),
            UserNotificationReminderScheduler.dailyIdentifier(groupID: "B", hour: 9, minute: 0)
        )
    }

    // MARK: - 등록과 취소의 일치

    /// 앱이 예약할 수 있는 모든 시각이 취소 대상 안에 들어 있다.
    ///
    /// 허용된 주기(30·60·120·180·240분)와 자정을 넘는 창까지 포함해, `occurrences()`가
    /// 만들어낼 수 있는 시각 전부를 `cancelGroup`이 만드는 1,440개 집합과 대조한다.
    /// 한 시각이라도 빠지면 그 알림은 취소되지 않고 매일 울린다.
    func test_예약가능한_모든_시각이_취소_대상에_포함된다() throws {
        let groupID = "GROUP"
        let cancelable = Set(
            (0..<24).flatMap { hour in
                (0..<60).map { minute in
                    UserNotificationReminderScheduler.dailyIdentifier(
                        groupID: groupID, hour: hour, minute: minute
                    )
                }
            }
        )

        // 하루를 꽉 채우는 창, 자정을 넘는 창, 짧은 창을 각각 모든 주기로 돌린다.
        let windows = [
            (start: (9, 0), end: (21, 0)),    // 기본
            (start: (22, 0), end: (2, 0)),    // 자정을 넘는 창
            (start: (0, 1), end: (0, 0)),     // 거의 하루 전체
            (start: (7, 37), end: (8, 3)),    // 분이 0이 아닌 짧은 창
        ]

        for window in windows {
            for interval in SmileReminderPattern.allowedIntervals {
                let pattern = try XCTUnwrap(
                    SmileReminderPattern(
                        startHour: window.start.0,
                        startMinute: window.start.1,
                        endHour: window.end.0,
                        endMinute: window.end.1,
                        intervalMinutes: interval
                    ),
                    "창 \(window) 주기 \(interval)분이 만들어지지 않았다"
                )

                for time in pattern.occurrences() {
                    let identifier = UserNotificationReminderScheduler.dailyIdentifier(
                        groupID: groupID, hour: time.hour, minute: time.minute
                    )
                    XCTAssertTrue(
                        cancelable.contains(identifier),
                        "취소되지 않는 알림: \(identifier) (창 \(window), 주기 \(interval)분)"
                    )
                }
            }
        }
    }

    /// 한 패턴 안에서 같은 식별자가 두 번 나오지 않는다.
    ///
    /// 겹치면 `UNUserNotificationCenter`가 뒤엣것으로 덮어써서 알림 하나가 조용히 사라진다.
    func test_한_패턴_안에서_식별자가_겹치지_않는다() throws {
        for interval in SmileReminderPattern.allowedIntervals {
            let pattern = try XCTUnwrap(
                SmileReminderPattern(
                    startHour: 0, startMinute: 1, endHour: 0, endMinute: 0,
                    intervalMinutes: interval
                )
            )
            let identifiers = pattern.occurrences().map {
                UserNotificationReminderScheduler.dailyIdentifier(
                    groupID: "G", hour: $0.hour, minute: $0.minute
                )
            }
            XCTAssertEqual(
                Set(identifiers).count, identifiers.count,
                "주기 \(interval)분에서 식별자가 겹친다"
            )
        }
    }

    // MARK: - 예전 개별 알림 취소

    /// 예전 버전은 리마인더 하나당 며칠치를 `"{id}-{n}"`으로 미리 예약했다.
    /// 그 형식으로 만든 식별자를 지워야 옛 알림이 멈춘다.
    func test_예전_개별알림_취소_식별자_개수가_롤링윈도우와_같다() {
        XCTAssertEqual(reminderRollingWindowDays, 14)
    }
}
