import XCTest
import SwiftData
@testable import CoachingKit

final class HomeViewModelTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    func test_refresh_setsHasCheckedInToday_true_whenCheckInExistsToday() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        try repository.saveCheckIn(measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1), date: Date(), lightingQuality: 1.0, deviceAngleOK: true, scoreDelta: 0.0)
        let viewModel = HomeViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertTrue(viewModel.hasCheckedInToday)
    }

    func test_refresh_setsHasCheckedInToday_false_whenNoCheckInToday() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let viewModel = HomeViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertFalse(viewModel.hasCheckedInToday)
    }

    private func saveCheckIn(_ repository: SessionRepository, daysAgo: Int) throws {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: Date()))!
        let noon = calendar.date(byAdding: .hour, value: 12, to: start)!
        try repository.saveCheckIn(
            measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
            date: noon,
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: 0.0
        )
    }

    func test_refresh_computesStreakDays() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 0)
        try saveCheckIn(repository, daysAgo: 1)
        let viewModel = HomeViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.streakDays, 2)
    }

    func test_refresh_computesRecentWeek_rollingSevenDays_oldestToNewest() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 0)
        try saveCheckIn(repository, daysAgo: 3)
        let viewModel = HomeViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recentWeek.map(\.checkedIn), [false, false, false, true, false, false, true])
        XCTAssertEqual(viewModel.recentWeek.last?.date, Calendar.current.startOfDay(for: Date()))
    }

    private func saveCheckIn(_ repository: SessionRepository, daysAgo: Int, scoreDelta: Double, from now: Date) throws {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        let noon = calendar.date(byAdding: .hour, value: 12, to: start)!
        try repository.saveCheckIn(
            measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
            date: noon,
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: scoreDelta
        )
    }

    // 2026-07-15 수요일 정오 고정
    private var fixedNow: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
    }

    func test_refresh_setsYesterdayAndTodayScores() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let now = fixedNow
        try saveCheckIn(repository, daysAgo: 1, scoreDelta: 0.32, from: now)
        try saveCheckIn(repository, daysAgo: 0, scoreDelta: 0.11, from: now)
        let viewModel = HomeViewModel(repository: repository, now: { now })

        try viewModel.refresh()

        XCTAssertEqual(viewModel.yesterdayScore, 3)
        XCTAssertEqual(viewModel.todayScore, 1)
    }

    func test_refresh_weekCheckInCount_countsMondayThroughTodayOnly() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let now = fixedNow
        try saveCheckIn(repository, daysAgo: 0, scoreDelta: 0.1, from: now) // 수
        try saveCheckIn(repository, daysAgo: 2, scoreDelta: 0.1, from: now) // 월
        try saveCheckIn(repository, daysAgo: 3, scoreDelta: 0.1, from: now) // 지난주 일 — 이번 주 아님
        let viewModel = HomeViewModel(repository: repository, now: { now })

        try viewModel.refresh()

        XCTAssertEqual(viewModel.weekCheckInCount, 2)
        // 롤링 7일에는 지난주 일요일 기록도 그대로 보인다.
        XCTAssertEqual(viewModel.recentWeek.filter(\.checkedIn).count, 3)
    }

    func test_refresh_computesWeeklyAverage_overDaysWithRecordsOnly() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let now = fixedNow
        try saveCheckIn(repository, daysAgo: 0, scoreDelta: 0.4, from: now)
        try saveCheckIn(repository, daysAgo: 1, scoreDelta: 0.2, from: now)
        let viewModel = HomeViewModel(repository: repository, now: { now })

        try viewModel.refresh()

        XCTAssertEqual(viewModel.weeklyAverageScore, 3.0)
    }

    func test_refresh_weeklyAverageIsNil_whenNoRecords() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let viewModel = HomeViewModel(repository: repository, now: { self.fixedNow })

        try viewModel.refresh()

        XCTAssertNil(viewModel.weeklyAverageScore)
        XCTAssertNil(viewModel.yesterdayScore)
        XCTAssertNil(viewModel.todayScore)
    }
}
