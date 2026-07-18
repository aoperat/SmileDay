import XCTest
import SwiftData
@testable import CoachingKit

final class CareViewModelTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    // 2026-07-15 수요일 정오 고정
    private var fixedNow: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
    }

    private func makeViewModel(
        context: ModelContext,
        favorites: CareFavoritesStoring = InMemoryCareFavorites(),
        now: Date? = nil
    ) -> CareViewModel {
        let resolvedNow = now ?? fixedNow
        return CareViewModel(
            sessionRepository: SessionRepository(modelContext: context),
            careRepository: CareRepository(modelContext: context),
            favorites: favorites,
            now: { resolvedNow }
        )
    }

    private func saveCheckIn(_ context: ModelContext, daysAgo: Int, scoreDelta: Double, from now: Date) throws {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        let noon = calendar.date(byAdding: .hour, value: 12, to: start)!
        try SessionRepository(modelContext: context).saveCheckIn(
            measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
            date: noon,
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: scoreDelta
        )
    }

    func test_refresh_recommendsLiftWithPositiveYesterdayScore() throws {
        let context = try makeInMemoryContext()
        try saveCheckIn(context, daysAgo: 1, scoreDelta: 0.2, from: fixedNow)
        let viewModel = makeViewModel(context: context)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recommendation?.routine.category, .lift)
        XCTAssertEqual(viewModel.recommendation?.reason.contains("+2°"), true)
    }

    func test_refresh_recommendationMentionsDrop_whenYesterdayNegative() throws {
        let context = try makeInMemoryContext()
        try saveCheckIn(context, daysAgo: 1, scoreDelta: -0.3, from: fixedNow)
        let viewModel = makeViewModel(context: context)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recommendation?.reason.contains("-3°"), true)
    }

    func test_refresh_recommendsFirstCare_whenNoYesterdayRecord() throws {
        let context = try makeInMemoryContext()
        let viewModel = makeViewModel(context: context)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recommendation?.reason.contains("첫 케어"), true)
    }

    func test_filteredRoutines_byCategory() throws {
        let context = try makeInMemoryContext()
        let viewModel = makeViewModel(context: context)

        viewModel.selectedCategory = .relax

        XCTAssertFalse(viewModel.filteredRoutines.isEmpty)
        XCTAssertTrue(viewModel.filteredRoutines.allSatisfy { $0.category == .relax })

        viewModel.selectedCategory = nil
        XCTAssertEqual(viewModel.filteredRoutines.count, CareRoutine.catalog.count)
    }

    func test_toggleFavorite_persistsToStore() throws {
        let context = try makeInMemoryContext()
        let favorites = InMemoryCareFavorites()
        let viewModel = makeViewModel(context: context, favorites: favorites)

        viewModel.toggleFavorite("lift-smile")
        XCTAssertEqual(favorites.favoriteRoutineIDs, ["lift-smile"])
        XCTAssertEqual(viewModel.favoriteIDs, ["lift-smile"])

        viewModel.toggleFavorite("lift-smile")
        XCTAssertTrue(favorites.favoriteRoutineIDs.isEmpty)
    }

    func test_completeRoutine_savesCareSession() throws {
        let context = try makeInMemoryContext()
        let viewModel = makeViewModel(context: context)
        let routine = CareRoutine.catalog[0]

        try viewModel.completeRoutine(routine)

        let repository = CareRepository(modelContext: context)
        XCTAssertTrue(try repository.hasCompletion(onDayOf: fixedNow))
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: fixedNow)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        XCTAssertEqual(try repository.fetchCompletions(from: start, to: end).map(\.routineID), [routine.id])
    }

    func test_routineDurationText_roundsUpToMinutes() {
        let routine = CareRoutine.catalog.first { $0.id == "lift-smile" }!
        // 30 + 10×3 + 30 + 60 = 150초 → 3분
        XCTAssertEqual(routine.totalSeconds, 150)
        XCTAssertEqual(routine.durationText, "3분")
    }
}
