import Foundation
import Observation

/// 다음에 울릴 알림 하나.
public struct UpcomingReminder: Equatable, Sendable {
    public let date: Date

    public init(date: Date) {
        self.date = date
    }
}

/// 홈 화면 상태.
///
/// 점수, 어제 대비, 기분, 스트릭 손실을 다루지 않는다. 오늘 몇 번 웃었는지와
/// 다음 알림이 언제인지만 보여준다. 쉬어간 날은 0회일 뿐 실패가 아니다.
@Observable
public final class SmileHomeViewModel {
    public private(set) var todayCompletionCount = 0
    public private(set) var recentSevenDayTotal = 0
    /// 오늘로 끝나는 7일. 기록이 없는 날도 0회로 포함한다.
    public private(set) var recentSevenDays: [SmileDayCount] = []
    public private(set) var nextReminder: UpcomingReminder?

    private let momentRepository: SmileMomentRepository
    private let scheduleRepository: SmileReminderScheduleRepository
    private let calendar: Calendar
    private let now: () -> Date

    public init(
        momentRepository: SmileMomentRepository,
        scheduleRepository: SmileReminderScheduleRepository,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.momentRepository = momentRepository
        self.scheduleRepository = scheduleRepository
        self.calendar = calendar
        self.now = now
    }

    public func refresh() throws {
        let today = now()
        todayCompletionCount = try momentRepository.count(onDayOf: today, calendar: calendar)
        recentSevenDays = try momentRepository.recentSevenDays(endingOn: today, calendar: calendar)
        recentSevenDayTotal = recentSevenDays.reduce(0) { $0 + $1.count }
        nextReminder = try findNextReminder(after: today)
    }

    /// 단일 반복 패턴에서 다음 발생 시각을 구한다.
    private func findNextReminder(after reference: Date) throws -> UpcomingReminder? {
        guard let schedule = try scheduleRepository.fetchCurrent(),
              schedule.isEnabled,
              let pattern = schedule.pattern else {
            return nil
        }

        let todayCandidates = pattern.occurrences().compactMap {
            occurrence(on: reference, time: $0)
        }
        if let nextToday = todayCandidates.first(where: { $0 > reference }) {
            return UpcomingReminder(date: nextToday)
        }

        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: reference),
              let first = pattern.occurrences().first,
              let next = occurrence(on: tomorrow, time: first) else {
            return nil
        }
        return UpcomingReminder(date: next)
    }

    private func occurrence(on day: Date, time: ReminderTime) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = time.hour
        components.minute = time.minute
        return calendar.date(from: components)
    }
}
