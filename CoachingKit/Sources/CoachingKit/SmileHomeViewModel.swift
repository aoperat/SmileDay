import Foundation
import Observation

/// 다음에 울릴 알림 하나.
public struct UpcomingReminder: Equatable, Sendable {
    public let date: Date
    public let guide: SmileGuide

    public init(date: Date, guide: SmileGuide) {
        self.date = date
        self.guide = guide
    }
}

/// 홈 화면 상태.
///
/// 점수, 어제 대비, 기분, 스트릭 손실을 다루지 않는다. 오늘 몇 번 웃었는지와
/// 다음 알림이 언제인지만 보여준다. 쉬어간 날은 0회일 뿐 실패가 아니다.
@Observable
public final class SmileHomeViewModel {
    public private(set) var todayCompletionCount = 0
    public private(set) var weekActiveDayCount = 0
    /// 오늘로 끝나는 7일. 기록이 없는 날도 0회로 포함한다.
    public private(set) var recentSevenDays: [SmileDayCount] = []
    public private(set) var nextReminder: UpcomingReminder?

    public let guides: [SmileGuide]

    private let momentRepository: SmileMomentRepository
    private let reminderRepository: ReminderRepository
    private let calendar: Calendar
    private let now: () -> Date

    public init(
        momentRepository: SmileMomentRepository,
        reminderRepository: ReminderRepository,
        guides: [SmileGuide] = SmileGuideCatalog.all,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.momentRepository = momentRepository
        self.reminderRepository = reminderRepository
        self.guides = guides
        self.calendar = calendar
        self.now = now
    }

    public func refresh() throws {
        let today = now()
        todayCompletionCount = try momentRepository.count(onDayOf: today, calendar: calendar)
        weekActiveDayCount = try momentRepository.weekActiveDayCount(endingOn: today, calendar: calendar)
        recentSevenDays = try momentRepository.recentSevenDays(endingOn: today, calendar: calendar)
        nextReminder = try findNextReminder(after: today)
    }

    /// 활성 알림마다 다음 발생 시각을 구해 가장 이른 것을 고른다.
    /// 오늘 남은 알림이 없으면 자연스럽게 내일 첫 알림이 된다.
    private func findNextReminder(after reference: Date) throws -> UpcomingReminder? {
        let enabled = try reminderRepository.fetchAll().filter(\.isEnabled)

        let candidates: [(date: Date, tieBreaker: String, guide: SmileGuide)] = enabled.compactMap { reminder in
            guard let date = nextOccurrence(hour: reminder.hour, minute: reminder.minute, after: reference) else { return nil }
            return (date, reminder.notificationID, reminder.guide)
        }

        // 같은 시각에 두 개가 있어도 항상 같은 하나를 고르도록 ID로 마지막 순서를 정한다.
        let earliest = candidates.min { lhs, rhs in
            lhs.date == rhs.date ? lhs.tieBreaker < rhs.tieBreaker : lhs.date < rhs.date
        }
        return earliest.map { UpcomingReminder(date: $0.date, guide: $0.guide) }
    }

    private func nextOccurrence(hour: Int, minute: Int, after reference: Date) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: reference)
        components.hour = hour
        components.minute = minute
        guard let todayOccurrence = calendar.date(from: components) else { return nil }

        if todayOccurrence > reference { return todayOccurrence }
        return calendar.date(byAdding: .day, value: 1, to: todayOccurrence)
    }
}
