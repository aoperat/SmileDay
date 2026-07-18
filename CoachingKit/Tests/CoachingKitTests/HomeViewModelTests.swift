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

    func test_refresh_computesRecentDays_oldestToNewest() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 0)
        try saveCheckIn(repository, daysAgo: 3)
        let viewModel = HomeViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recentDays, [false, true, false, false, true])
    }
}
