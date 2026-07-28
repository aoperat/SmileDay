import XCTest
import SwiftData
@testable import CoachingKit

final class SmileHomeViewModelTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.firstWeekday = 1
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    private func makeViewModel(now: Date) throws -> (SmileHomeViewModel, SmileMomentRepository, ReminderRepository) {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let momentRepository = SmileMomentRepository(modelContext: context)
        let reminderRepository = ReminderRepository(modelContext: context)
        let viewModel = SmileHomeViewModel(
            momentRepository: momentRepository,
            reminderRepository: reminderRepository,
            calendar: calendar,
            now: { now }
        )
        return (viewModel, momentRepository, reminderRepository)
    }

    // MARK: - 오늘 횟수

    func test_refresh_countsEveryCompletionToday() throws {
        let (viewModel, moments, _) = try makeViewModel(now: date(2026, 7, 28, 20))
        try moments.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 28, 9))
        try moments.save(guideID: "greeting-smile", source: .notification, date: date(2026, 7, 28, 13))
        try moments.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 27, 9))

        try viewModel.refresh()

        XCTAssertEqual(viewModel.todayCompletionCount, 2)
    }

    func test_refresh_todayCountIsZero_whenNothingSaved() throws {
        let (viewModel, _, _) = try makeViewModel(now: date(2026, 7, 28, 20))

        try viewModel.refresh()

        XCTAssertEqual(viewModel.todayCompletionCount, 0)
    }

    /// 자정 직후에는 어제 기록이 오늘로 넘어오지 않는다.
    func test_refresh_afterMidnight_startsTodayCountFromZero() throws {
        let (viewModel, moments, _) = try makeViewModel(now: date(2026, 7, 29, 0, 5))
        try moments.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 28, 23, 55))

        try viewModel.refresh()

        XCTAssertEqual(viewModel.todayCompletionCount, 0)
    }

    // MARK: - 이번 주 일수와 최근 7일

    func test_refresh_weekActiveDayCount_countsDistinctDays() throws {
        let (viewModel, moments, _) = try makeViewModel(now: date(2026, 7, 28, 20))
        try moments.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 26, 9))
        try moments.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 28, 9))
        try moments.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 28, 18))

        try viewModel.refresh()

        XCTAssertEqual(viewModel.weekActiveDayCount, 2)
    }

    func test_refresh_recentSevenDays_endsOnToday_andFillsGaps() throws {
        let (viewModel, moments, _) = try makeViewModel(now: date(2026, 7, 28, 20))
        try moments.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 28, 9))
        try moments.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 25, 9))

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recentSevenDays.count, 7)
        XCTAssertEqual(viewModel.recentSevenDays.map(\.count), [0, 0, 0, 1, 0, 0, 1])
        XCTAssertEqual(calendar.component(.day, from: viewModel.recentSevenDays.last!.date), 28)
    }

    // MARK: - 다음 알림

    func test_refresh_nextReminder_picksNearestLaterToday() throws {
        let (viewModel, _, reminders) = try makeViewModel(now: date(2026, 7, 28, 10))
        try reminders.add(hour: 9, minute: 0, guideID: "soft-smile")
        try reminders.add(hour: 13, minute: 0, guideID: "greeting-smile")
        try reminders.add(hour: 18, minute: 0, guideID: "bright-smile")

        try viewModel.refresh()

        XCTAssertEqual(viewModel.nextReminder?.date, date(2026, 7, 28, 13))
        XCTAssertEqual(viewModel.nextReminder?.guide.id, "greeting-smile")
    }

    /// 오늘 남은 알림이 없으면 다음 날 첫 알림.
    func test_refresh_nextReminder_rollsOverToTomorrow() throws {
        let (viewModel, _, reminders) = try makeViewModel(now: date(2026, 7, 28, 22))
        try reminders.add(hour: 9, minute: 0, guideID: "soft-smile")
        try reminders.add(hour: 18, minute: 0, guideID: "bright-smile")

        try viewModel.refresh()

        XCTAssertEqual(viewModel.nextReminder?.date, date(2026, 7, 29, 9))
        XCTAssertEqual(viewModel.nextReminder?.guide.id, "soft-smile")
    }

    /// 방금 울린 알림은 다시 "다음"이 되지 않는다.
    func test_refresh_nextReminder_skipsReminderAtExactlyNow() throws {
        let (viewModel, _, reminders) = try makeViewModel(now: date(2026, 7, 28, 13, 0))
        try reminders.add(hour: 13, minute: 0, guideID: "greeting-smile")
        try reminders.add(hour: 18, minute: 0, guideID: "bright-smile")

        try viewModel.refresh()

        XCTAssertEqual(viewModel.nextReminder?.date, date(2026, 7, 28, 18))
    }

    func test_refresh_nextReminder_ignoresDisabledReminders() throws {
        let (viewModel, _, reminders) = try makeViewModel(now: date(2026, 7, 28, 10))
        let disabled = try reminders.add(hour: 13, minute: 0, guideID: "greeting-smile")
        try reminders.setEnabled(disabled, false)
        try reminders.add(hour: 18, minute: 0, guideID: "bright-smile")

        try viewModel.refresh()

        XCTAssertEqual(viewModel.nextReminder?.date, date(2026, 7, 28, 18))
        XCTAssertEqual(viewModel.nextReminder?.guide.id, "bright-smile")
    }

    func test_refresh_nextReminder_isNil_whenNoReminders() throws {
        let (viewModel, _, _) = try makeViewModel(now: date(2026, 7, 28, 10))

        try viewModel.refresh()

        XCTAssertNil(viewModel.nextReminder)
    }

    func test_refresh_nextReminder_isNil_whenAllRemindersDisabled() throws {
        let (viewModel, _, reminders) = try makeViewModel(now: date(2026, 7, 28, 10))
        let reminder = try reminders.add(hour: 13, minute: 0)
        try reminders.setEnabled(reminder, false)

        try viewModel.refresh()

        XCTAssertNil(viewModel.nextReminder)
    }

    /// 같은 시각에 두 개가 있어도 매번 같은 하나를 고른다.
    func test_refresh_nextReminder_isStable_whenTwoRemindersShareTime() throws {
        let (viewModel, _, reminders) = try makeViewModel(now: date(2026, 7, 28, 10))
        try reminders.add(hour: 13, minute: 0, guideID: "greeting-smile")
        try reminders.add(hour: 13, minute: 0, guideID: "bright-smile")

        try viewModel.refresh()
        let firstPick = viewModel.nextReminder
        try viewModel.refresh()

        XCTAssertEqual(viewModel.nextReminder?.date, date(2026, 7, 28, 13))
        XCTAssertEqual(viewModel.nextReminder, firstPick)
    }

    /// guideID가 없던 시절 알림도 기본 가이드로 표시된다.
    func test_refresh_nextReminder_legacyReminderShowsDefaultGuide() throws {
        let (viewModel, _, reminders) = try makeViewModel(now: date(2026, 7, 28, 10))
        try reminders.add(hour: 13, minute: 0)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.nextReminder?.guide.id, "soft-smile")
    }

    // MARK: - 노출 범위

    func test_guides_areTheThreeCatalogGuides() throws {
        let (viewModel, _, _) = try makeViewModel(now: date(2026, 7, 28, 10))

        XCTAssertEqual(viewModel.guides.map(\.id), ["soft-smile", "greeting-smile", "bright-smile"])
    }
}
