import XCTest
import SwiftData
@testable import CoachingKit

final class HistoryViewModelTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func saveCheckIn(_ repository: SessionRepository, daysAgo: Int, scoreDelta: Double) throws {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: Date()))!
        let noon = calendar.date(byAdding: .hour, value: 12, to: start)!
        try repository.saveCheckIn(
            measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
            date: noon,
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: scoreDelta
        )
    }

    func test_refresh_buildsWeeklyScores_fromLast7Days() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 0, scoreDelta: 0.31)
        try saveCheckIn(repository, daysAgo: 2, scoreDelta: 0.12)
        try saveCheckIn(repository, daysAgo: 6, scoreDelta: -0.05)
        try saveCheckIn(repository, daysAgo: 8, scoreDelta: 0.9) // 범위 밖
        let viewModel = HistoryViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.weeklyScores.map(\.displayScore), [-1, 1, 3])
        XCTAssertEqual(viewModel.weeklyScores.count, 3)
    }

    func test_refresh_collectsMonthCheckInDays() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let calendar = Calendar.current
        let today = Date()
        try saveCheckIn(repository, daysAgo: 0, scoreDelta: 0.1)
        let viewModel = HistoryViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertTrue(viewModel.monthCheckInDays.contains(calendar.component(.day, from: today)))
    }

    func test_refresh_monthCheckInCount_countsSessionsNotDays() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 0, scoreDelta: 0.1)
        try saveCheckIn(repository, daysAgo: 0, scoreDelta: 0.2) // 같은 날 두 번째 체크인
        let viewModel = HistoryViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.monthCheckInCount, 2)
        XCTAssertEqual(viewModel.monthCheckInDays.count, 1)
    }
}
