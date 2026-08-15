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
@MainActor
@Observable
public final class SmileHomeViewModel {
    public private(set) var todayCompletionCount = 0
    public private(set) var recentSevenDayTotal = 0
    /// 오늘로 끝나는 7일. 기록이 없는 날도 0회로 포함한다.
    public private(set) var recentSevenDays: [SmileDayCount] = []
    public private(set) var nextReminder: UpcomingReminder?
    /// 알림이 실제로 도착할 수 있는 상태인지. 일정만으로는 알 수 없어 권한까지 같이 본다.
    public private(set) var reminderDelivery: ReminderDeliveryState = .off

    private let momentRepository: SmileMomentRepository
    private let scheduleRepository: SmileReminderScheduleRepository
    private let scheduler: ReminderScheduling
    private let calendar: Calendar
    private let now: () -> Date

    public init(
        momentRepository: SmileMomentRepository,
        scheduleRepository: SmileReminderScheduleRepository,
        scheduler: ReminderScheduling,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.momentRepository = momentRepository
        self.scheduleRepository = scheduleRepository
        self.scheduler = scheduler
        self.calendar = calendar
        self.now = now
    }

    public func refresh() async throws {
        let today = now()
        todayCompletionCount = try momentRepository.count(onDayOf: today, calendar: calendar)
        recentSevenDays = try momentRepository.recentSevenDays(endingOn: today, calendar: calendar)
        recentSevenDayTotal = recentSevenDays.reduce(0) { $0 + $1.count }
        nextReminder = try findNextReminder(after: today)

        let isScheduleEnabled = try scheduleRepository.fetchCurrent()?.isEnabled ?? false
        reminderDelivery = ReminderDeliveryState(
            authorization: await scheduler.currentAuthorizationStatus(),
            isScheduleEnabled: isScheduleEnabled,
            nextReminder: nextReminder
        )
    }

    /// 단일 반복 패턴에서 다음 발생 시각을 구한다.
    ///
    /// 각 시각은 매일 반복하는 알림이라, 다음에 울릴 것은 "오늘 남은 시각 중 가장 이른 것,
    /// 없으면 내일 가장 이른 시각"이다. `occurrences()`는 창을 지나는 순서로 오므로
    /// (자정을 넘는 창이면 22:00 다음에 00:00이 온다) 여기서는 시계 순으로 정렬해서 본다.
    private func findNextReminder(after reference: Date) throws -> UpcomingReminder? {
        guard let schedule = try scheduleRepository.fetchCurrent(),
              schedule.isEnabled,
              let pattern = schedule.pattern else {
            return nil
        }

        let byClock = pattern.occurrences()
            .sorted { $0.minutesSinceMidnight < $1.minutesSinceMidnight }

        let todayCandidates = byClock.compactMap { occurrence(on: reference, time: $0) }
        if let nextToday = todayCandidates.first(where: { $0 > reference }) {
            return UpcomingReminder(date: nextToday)
        }

        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: reference),
              let earliest = byClock.first,
              let next = occurrence(on: tomorrow, time: earliest) else {
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
