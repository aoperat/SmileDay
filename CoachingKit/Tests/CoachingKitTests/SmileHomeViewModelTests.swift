import XCTest
import SwiftData
@testable import CoachingKit

final class SmileHomeViewModelTests: XCTestCase {
    private let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return value
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour, minute: minute))!
    }

    private func makeViewModel(now: Date) throws -> (
        SmileHomeViewModel,
        SmileMomentRepository,
        SmileReminderScheduleRepository
    ) {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let moments = SmileMomentRepository(modelContext: context)
        let schedules = SmileReminderScheduleRepository(modelContext: context)
        return (
            SmileHomeViewModel(
                momentRepository: moments,
                scheduleRepository: schedules,
                calendar: calendar,
                now: { now }
            ),
            moments,
            schedules
        )
    }

    func test_refresh_countsTodayAndRecentSevenDayTotal() throws {
        let (viewModel, moments, _) = try makeViewModel(now: date(29, 12))
        try moments.save(guideID: "anytime-soft", source: .manual, date: date(29, 9))
        try moments.save(guideID: "anytime-soft", source: .notification, date: date(29, 11))
        try moments.save(guideID: "anytime-soft", source: .manual, date: date(27, 9))

        try viewModel.refresh()

        XCTAssertEqual(viewModel.todayCompletionCount, 2)
        XCTAssertEqual(viewModel.recentSevenDayTotal, 3)
        XCTAssertEqual(viewModel.recentSevenDays.count, 7)
    }

    func test_refresh_findsNextOccurrenceToday() throws {
        let (viewModel, _, schedules) = try makeViewModel(now: date(29, 10))
        try schedules.save(pattern: .recommended, isEnabled: true)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.nextReminder?.date, date(29, 12))
    }

    func test_refresh_rollsNextOccurrenceToTomorrow() throws {
        let (viewModel, _, schedules) = try makeViewModel(now: date(29, 22))
        try schedules.save(pattern: .recommended, isEnabled: true)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.nextReminder?.date, date(30, 9))
    }

    func test_refresh_hasNoNextReminder_whenScheduleDisabledOrMissing() throws {
        let (missing, _, _) = try makeViewModel(now: date(29, 10))
        try missing.refresh()
        XCTAssertNil(missing.nextReminder)

        let (disabled, _, schedules) = try makeViewModel(now: date(29, 10))
        try schedules.save(pattern: .recommended, isEnabled: false)
        try disabled.refresh()
        XCTAssertNil(disabled.nextReminder)
    }
}
