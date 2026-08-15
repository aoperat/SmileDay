import XCTest
import SwiftData
@testable import CoachingKit

@MainActor
final class SmileHistoryViewModelTests: XCTestCase {
    private let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Seoul")!
        value.locale = Locale(identifier: "ko_KR")
        return value
    }()

    private func date(_ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func makeViewModel(now: Date) throws -> (SmileHistoryViewModel, SmileMomentRepository) {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let repository = SmileMomentRepository(modelContext: ModelContext(container))
        return (
            SmileHistoryViewModel(
                momentRepository: repository,
                calendar: calendar,
                now: { now }
            ),
            repository
        )
    }

    func test_refreshBuildsMonthlySummaryAndSelectsToday() throws {
        let (viewModel, repository) = try makeViewModel(now: date(8, 4, 15))
        try repository.save(guideID: "anytime-soft", source: .manual, date: date(8, 1, 9))
        try repository.save(guideID: "anytime-soft", source: .manual, date: date(8, 4, 9))
        try repository.save(guideID: "anytime-soft", source: .notification, date: date(8, 4, 13))

        try viewModel.refresh()

        XCTAssertEqual(viewModel.days.count, 31)
        XCTAssertEqual(viewModel.monthTotal, 3)
        XCTAssertEqual(viewModel.activeDayCount, 2)
        XCTAssertTrue(calendar.isDate(viewModel.selectedDate!, inSameDayAs: date(8, 4)))
        XCTAssertEqual(viewModel.selectedDayCount, 2)
        XCTAssertFalse(viewModel.canShowNextMonth)
    }

    func test_monthNavigationLoadsPreviousMonthAndStopsAtCurrentMonth() throws {
        let (viewModel, repository) = try makeViewModel(now: date(8, 4))
        try repository.save(guideID: "anytime-soft", source: .manual, date: date(7, 20))
        try viewModel.refresh()

        try viewModel.showPreviousMonth()

        XCTAssertEqual(calendar.component(.month, from: viewModel.displayedMonth), 7)
        XCTAssertEqual(viewModel.monthTotal, 1)
        XCTAssertNil(viewModel.selectedDate)
        XCTAssertTrue(viewModel.canShowNextMonth)

        try viewModel.showNextMonth()
        try viewModel.showNextMonth()

        XCTAssertEqual(calendar.component(.month, from: viewModel.displayedMonth), 8)
        XCTAssertFalse(viewModel.canShowNextMonth)
    }

    func test_selectIgnoresFutureDate() throws {
        let (viewModel, _) = try makeViewModel(now: date(8, 4))
        try viewModel.refresh()

        viewModel.select(date(8, 10))

        XCTAssertTrue(calendar.isDate(viewModel.selectedDate!, inSameDayAs: date(8, 4)))
    }
}
