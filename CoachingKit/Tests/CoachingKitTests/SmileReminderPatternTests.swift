import XCTest
@testable import CoachingKit

final class SmileReminderPatternTests: XCTestCase {
    private func time(_ hour: Int, _ minute: Int = 0) throws -> ReminderTime {
        try ReminderTime(hour: hour, minute: minute)
    }

    func test_recommendedPattern_createsFiveDailyTimes() {
        XCTAssertEqual(
            SmileReminderPattern.recommended.occurrences(),
            [
                try! time(9), try! time(12), try! time(15),
                try! time(18), try! time(21),
            ]
        )
    }

    func test_endTime_isIncludedOnlyWhenIntervalLandsExactly() throws {
        let pattern = try SmileReminderPattern(
            startTime: time(9, 30),
            endTime: time(14),
            intervalMinutes: 120
        )

        XCTAssertEqual(pattern.occurrences(), [try time(9, 30), try time(11, 30), try time(13, 30)])
    }

    /// 길이가 0인지 24시간인지 구분할 방법이 없다. 이것만 거부한다.
    func test_rejectsTheSameStartAndEnd() throws {
        XCTAssertThrowsError(
            try SmileReminderPattern(startTime: time(9), endTime: time(9), intervalMinutes: 180)
        ) {
            XCTAssertEqual($0 as? SmileReminderPatternError, .invalidRange)
        }
    }

    func test_rejectsUnsupportedInterval() throws {
        XCTAssertThrowsError(
            try SmileReminderPattern(startTime: time(9), endTime: time(21), intervalMinutes: 45)
        ) {
            XCTAssertEqual($0 as? SmileReminderPatternError, .unsupportedInterval)
        }
    }

    // MARK: - 자정을 넘는 시간창

    /// 밤에 일하는 사람에게는 22:00~02:00이 하루 전부다. 이 창을 만들 수 없으면
    /// 그 사람은 앱의 핵심 루프 자체를 쓸 수 없다.
    func test_windowCrossingMidnight_isAllowed() throws {
        let pattern = try SmileReminderPattern(
            startTime: time(22),
            endTime: time(2),
            intervalMinutes: 60
        )

        XCTAssertTrue(pattern.crossesMidnight)
        XCTAssertEqual(pattern.spanMinutes, 240)
    }

    /// 창을 지나는 순서로 온다 — 시계 순이 아니다. 알림 문구가 이 순서로 돌기 때문에
    /// 사용자가 겪는 순서와 같아야 한다.
    func test_crossingMidnight_walksTheWindowInOrder() throws {
        let pattern = try SmileReminderPattern(
            startTime: time(22),
            endTime: time(2),
            intervalMinutes: 60
        )

        XCTAssertEqual(
            pattern.occurrences(),
            [try time(22), try time(23), try time(0), try time(1), try time(2)]
        )
    }

    /// 자정 직전에서 넘어가는 30분 간격이 정확히 이어져야 한다.
    func test_crossingMidnight_withHalfHourInterval() throws {
        let pattern = try SmileReminderPattern(
            startTime: try ReminderTime(hour: 23, minute: 0),
            endTime: try ReminderTime(hour: 0, minute: 30),
            intervalMinutes: 30
        )

        XCTAssertEqual(
            pattern.occurrences(),
            [
                try ReminderTime(hour: 23, minute: 0),
                try ReminderTime(hour: 23, minute: 30),
                try ReminderTime(hour: 0, minute: 0),
                try ReminderTime(hour: 0, minute: 30),
            ]
        )
    }

    /// 같은 시각이 두 번 예약되면 하나가 다른 하나를 덮어써 알림이 조용히 사라진다.
    func test_occurrences_neverRepeatTheSameClockTime() throws {
        for interval in SmileReminderPattern.allowedIntervals {
            let pattern = try SmileReminderPattern(
                startTime: try ReminderTime(hour: 0, minute: 1),
                endTime: try ReminderTime(hour: 0, minute: 0),
                intervalMinutes: interval
            )
            let times = pattern.occurrences()
            XCTAssertEqual(Set(times).count, times.count, "\(interval)분 간격에서 시각이 겹친다")
        }
    }

    /// 30분 간격도 한 시간 미만 단위로 정확히 나와야 한다.
    func test_halfHourInterval_stepsByThirtyMinutes() throws {
        let pattern = try SmileReminderPattern(
            startTime: time(9),
            endTime: time(10),
            intervalMinutes: 30
        )

        XCTAssertEqual(
            pattern.occurrences(),
            [
                try ReminderTime(hour: 9, minute: 0),
                try ReminderTime(hour: 9, minute: 30),
                try ReminderTime(hour: 10, minute: 0),
            ]
        )
    }

    func test_reminderTime_rejectsInvalidClockValues() {
        XCTAssertThrowsError(try ReminderTime(hour: 24, minute: 0))
        XCTAssertThrowsError(try ReminderTime(hour: 9, minute: 60))
    }

    /// iOS는 앱 하나가 예약해둘 수 있는 알림을 64개까지만 들고, 넘치면 **말없이** 뒤쪽을
    /// 버린다. 예약 실패도, 경고도 없다 — 사용자는 저녁 알림이 왜 안 오는지 알 수 없다.
    ///
    /// 지금은 가장 촘촘한 60분 간격에 하루를 다 써도 24개라 여유가 크다. 이 테스트는 나중에
    /// 더 짧은 간격을 허용값에 넣는 순간 그 자리에서 실패해 이 상한을 알린다.
    func test_everyAllowedInterval_staysUnderTheSystemPendingNotificationLimit() throws {
        let systemPendingNotificationLimit = 64
        let start = try ReminderTime(hour: 0, minute: 0)
        let end = try ReminderTime(hour: 23, minute: 59)

        for interval in SmileReminderPattern.allowedIntervals {
            let pattern = try SmileReminderPattern(
                startTime: start,
                endTime: end,
                intervalMinutes: interval
            )
            XCTAssertLessThanOrEqual(
                pattern.occurrences().count,
                systemPendingNotificationLimit,
                "\(interval)분 간격은 하루를 다 쓰면 iOS가 조용히 버리는 개수를 넘는다"
            )
        }
    }
}
