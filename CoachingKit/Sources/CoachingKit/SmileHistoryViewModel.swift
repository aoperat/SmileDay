import Foundation
import Observation

/// 저장된 완료만으로 월간 기록을 보여주는 화면 상태.
///
/// 점수, 연속 기록, 전월 대비는 계산하지 않는다. 쉬어간 날은 `count == 0`인 날짜다.
@MainActor
@Observable
public final class SmileHistoryViewModel {
    public private(set) var displayedMonth: Date
    public private(set) var days: [SmileDayCount] = []
    public private(set) var monthTotal = 0
    public private(set) var activeDayCount = 0
    public private(set) var selectedDate: Date?

    private let momentRepository: SmileMomentRepository
    private let calendar: Calendar
    private let now: () -> Date

    public init(
        momentRepository: SmileMomentRepository,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.momentRepository = momentRepository
        self.calendar = calendar
        self.now = now

        let today = now()
        self.displayedMonth = calendar.dateInterval(of: .month, for: today)?.start
            ?? calendar.startOfDay(for: today)
        self.selectedDate = calendar.startOfDay(for: today)
    }

    public var canShowNextMonth: Bool {
        guard let currentMonth = calendar.dateInterval(of: .month, for: now())?.start else {
            return false
        }
        return displayedMonth < currentMonth
    }

    public var selectedDayCount: Int? {
        guard let selectedDate else { return nil }
        return days.first(where: { calendar.isDate($0.date, inSameDayAs: selectedDate) })?.count
    }

    public func refresh() throws {
        try loadDisplayedMonth()
    }

    public func showPreviousMonth() throws {
        guard let previous = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        displayedMonth = previous
        selectedDate = nil
        try loadDisplayedMonth()
    }

    public func showNextMonth() throws {
        guard canShowNextMonth,
              let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        displayedMonth = next
        selectedDate = nil
        try loadDisplayedMonth()
    }

    public func select(_ date: Date) {
        guard isSelectable(date),
              calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month) else { return }
        selectedDate = calendar.startOfDay(for: date)
    }

    public func isSelectable(_ date: Date) -> Bool {
        calendar.startOfDay(for: date) <= calendar.startOfDay(for: now())
    }

    private func loadDisplayedMonth() throws {
        days = try momentRepository.monthlyCounts(containing: displayedMonth, calendar: calendar)
        monthTotal = days.reduce(0) { $0 + $1.count }
        activeDayCount = days.reduce(0) { $0 + ($1.hasSmile ? 1 : 0) }
    }
}
