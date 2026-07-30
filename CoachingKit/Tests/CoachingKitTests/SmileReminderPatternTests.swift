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

    func test_rejectsInvalidRange() throws {
        XCTAssertThrowsError(
            try SmileReminderPattern(startTime: time(21), endTime: time(9), intervalMinutes: 180)
        ) {
            XCTAssertEqual($0 as? SmileReminderPatternError, .invalidRange)
        }
    }

    func test_rejectsUnsupportedInterval() throws {
        XCTAssertThrowsError(
            try SmileReminderPattern(startTime: time(9), endTime: time(21), intervalMinutes: 30)
        ) {
            XCTAssertEqual($0 as? SmileReminderPatternError, .unsupportedInterval)
        }
    }

    func test_reminderTime_rejectsInvalidClockValues() {
        XCTAssertThrowsError(try ReminderTime(hour: 24, minute: 0))
        XCTAssertThrowsError(try ReminderTime(hour: 9, minute: 60))
    }
}
