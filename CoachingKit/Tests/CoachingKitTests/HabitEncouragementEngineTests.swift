import XCTest
@testable import CoachingKit

final class HabitEncouragementEngineTests: XCTestCase {
    private func context(
        todayCheckInCount: Int = 1,
        streakDays: Int = 1,
        recentSevenDayCount: Int = 1,
        daysSincePreviousCheckIn: Int? = 1,
        hasMomentNote: Bool = false
    ) -> HabitContext {
        HabitContext(
            todayCheckInCount: todayCheckInCount,
            streakDays: streakDays,
            recentSevenDayCount: recentSevenDayCount,
            daysSincePreviousCheckIn: daysSincePreviousCheckIn,
            hasMomentNote: hasMomentNote
        )
    }

    // MARK: - 각 상황별 문구

    func test_firstCheckIn_whenNoPreviousRecord() {
        let result = HabitEncouragementEngine.evaluate(
            context(streakDays: 1, recentSevenDayCount: 1, daysSincePreviousCheckIn: nil)
        )

        XCTAssertEqual(result.kind, .first)
        XCTAssertEqual(result.message, "첫 미소 시간을 남겼어요. 내일도 부담 없이 들러보세요.")
    }

    func test_repeatedToday_whenSecondCheckInSameDay() {
        let result = HabitEncouragementEngine.evaluate(
            context(todayCheckInCount: 2, daysSincePreviousCheckIn: 0)
        )

        XCTAssertEqual(result.kind, .repeatedToday)
        XCTAssertEqual(result.message, "오늘 벌써 두 번째 미소예요. 잠깐의 여유가 하나 더 쌓였어요.")
    }

    func test_streak_whenThreeOrMoreConsecutiveDays() {
        let result = HabitEncouragementEngine.evaluate(context(streakDays: 3, recentSevenDayCount: 3))

        XCTAssertEqual(result.kind, .streak)
        XCTAssertEqual(result.message, "연속 3일째 웃어보는 시간을 만들고 있어요.")
    }

    func test_streak_belowThreshold_doesNotMentionStreak() {
        let result = HabitEncouragementEngine.evaluate(context(streakDays: 2, recentSevenDayCount: 2))

        XCTAssertNotEqual(result.kind, .streak)
    }

    func test_returning_whenGapOfTwoOrMoreDays() {
        let result = HabitEncouragementEngine.evaluate(
            context(streakDays: 1, recentSevenDayCount: 1, daysSincePreviousCheckIn: 4)
        )

        XCTAssertEqual(result.kind, .returning)
        XCTAssertEqual(result.message, "다시 돌아온 오늘이 새로운 시작이에요.")
    }

    func test_returning_doesNotTrigger_whenYesterdayContinued() {
        let result = HabitEncouragementEngine.evaluate(context(daysSincePreviousCheckIn: 1))

        XCTAssertNotEqual(result.kind, .returning)
    }

    func test_momentNote_whenNoteWritten() {
        let result = HabitEncouragementEngine.evaluate(context(hasMomentNote: true))

        XCTAssertEqual(result.kind, .momentNote)
        XCTAssertEqual(result.message, "오늘의 좋은 순간도 함께 남겼어요.")
    }

    func test_steady_isDefault() {
        let result = HabitEncouragementEngine.evaluate(context(recentSevenDayCount: 1))

        XCTAssertEqual(result.kind, .steady)
        XCTAssertEqual(result.message, "오늘의 미소 하나가 기록되었어요.")
    }

    func test_steady_mentionsWeek_whenMultipleDaysThisWeek() {
        let result = HabitEncouragementEngine.evaluate(context(streakDays: 1, recentSevenDayCount: 2))

        XCTAssertEqual(result.kind, .steady)
        XCTAssertEqual(result.message, "이번 주에 웃어본 날이 하나 더 쌓였어요.")
    }

    // MARK: - 우선순위

    func test_returning_outranksEveryOtherCondition() {
        let result = HabitEncouragementEngine.evaluate(
            context(
                todayCheckInCount: 3,
                streakDays: 10,
                recentSevenDayCount: 5,
                daysSincePreviousCheckIn: 5,
                hasMomentNote: true
            )
        )

        XCTAssertEqual(result.kind, .returning)
    }

    func test_first_outranksRepeatAndStreakAndNote() {
        let result = HabitEncouragementEngine.evaluate(
            context(
                todayCheckInCount: 2,
                streakDays: 5,
                recentSevenDayCount: 5,
                daysSincePreviousCheckIn: nil,
                hasMomentNote: true
            )
        )

        XCTAssertEqual(result.kind, .first)
    }

    func test_repeatedToday_outranksStreakAndNote() {
        let result = HabitEncouragementEngine.evaluate(
            context(todayCheckInCount: 2, streakDays: 6, daysSincePreviousCheckIn: 0, hasMomentNote: true)
        )

        XCTAssertEqual(result.kind, .repeatedToday)
    }

    func test_streak_outranksNote() {
        let result = HabitEncouragementEngine.evaluate(context(streakDays: 4, hasMomentNote: true))

        XCTAssertEqual(result.kind, .streak)
    }

    // MARK: - withMomentNote

    func test_withMomentNote_changesOnlyTheNoteFlag() {
        let base = context(todayCheckInCount: 1, streakDays: 2, recentSevenDayCount: 2, daysSincePreviousCheckIn: 1)

        let withNote = base.withMomentNote(true)

        XCTAssertTrue(withNote.hasMomentNote)
        XCTAssertEqual(withNote.todayCheckInCount, base.todayCheckInCount)
        XCTAssertEqual(withNote.streakDays, base.streakDays)
        XCTAssertEqual(withNote.recentSevenDayCount, base.recentSevenDayCount)
        XCTAssertEqual(withNote.daysSincePreviousCheckIn, base.daysSincePreviousCheckIn)
        XCTAssertEqual(withNote.withMomentNote(false), base)
    }

    /// 완료 화면은 저장 전에 문구를 보여주므로, 메모를 쓰는 동안 문구가 따라 바뀌어야 한다.
    func test_withMomentNote_flipsMessageWithoutRefetching() {
        let base = context(streakDays: 1, recentSevenDayCount: 1, daysSincePreviousCheckIn: 1)

        XCTAssertEqual(HabitEncouragementEngine.evaluate(base).kind, .steady)
        XCTAssertEqual(HabitEncouragementEngine.evaluate(base.withMomentNote(true)).kind, .momentNote)
    }

    // MARK: - 어조 보증

    /// 압박·평가·실패 어휘는 어떤 조합에서도 나오지 않아야 한다.
    func test_noPressureOrEvaluationWording_acrossAllContexts() {
        let banned = ["실패", "깨짐", "복구", "점수", "개선", "리프팅", "치료", "교정"]

        for message in allReachableMessages() {
            for phrase in banned {
                XCTAssertFalse(message.contains(phrase), "'\(phrase)'가 문구에 남아 있다: \(message)")
            }
            XCTAssertFalse(
                containsZeroDayPhrase(message),
                "공백을 '0일'로 노출하면 안 된다: \(message)"
            )
        }
    }

    /// 연속 일수가 10·20·30일이어도 문구는 정상이며 "0일" 압박 표현으로 읽히지 않는다.
    func test_longStreakMessage_isNotReadAsZeroDays() {
        for streak in [10, 20, 30] {
            let message = HabitEncouragementEngine.evaluate(context(streakDays: streak)).message
            XCTAssertEqual(message, "연속 \(streak)일째 웃어보는 시간을 만들고 있어요.")
            XCTAssertFalse(containsZeroDayPhrase(message))
        }
    }

    /// 앞에 다른 숫자가 붙지 않은 "0일"만 금지 대상으로 본다. "10일"은 정상 표기다.
    private func containsZeroDayPhrase(_ message: String) -> Bool {
        var previous: Character?
        for (index, character) in message.enumerated() {
            defer { previous = character }
            guard character == "0" else { continue }
            let next = message[message.index(message.startIndex, offsetBy: index + 1)...].first
            guard next == "일" else { continue }
            if let previous, previous.isNumber { continue }
            return true
        }
        return false
    }

    private func allReachableMessages() -> [String] {
        var messages: [String] = []
        for todayCount in [1, 2, 3] {
            for streak in [0, 1, 2, 3, 10] {
                for weekCount in [0, 1, 2, 7] {
                    for gap in [nil, 0, 1, 2, 9] as [Int?] {
                        for hasNote in [false, true] {
                            messages.append(
                                HabitEncouragementEngine.evaluate(
                                    context(
                                        todayCheckInCount: todayCount,
                                        streakDays: streak,
                                        recentSevenDayCount: weekCount,
                                        daysSincePreviousCheckIn: gap,
                                        hasMomentNote: hasNote
                                    )
                                ).message
                            )
                        }
                    }
                }
            }
        }
        return messages
    }
}
