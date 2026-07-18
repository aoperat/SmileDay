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
}
