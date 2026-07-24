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
        XCTAssertEqual(viewModel.recommendation?.reason.contains("+2.0°"), true)
    }

    func test_refresh_recommendationMentionsDrop_whenYesterdayNegative() throws {
        let context = try makeInMemoryContext()
        try saveCheckIn(context, daysAgo: 1, scoreDelta: -0.3, from: fixedNow)
        let viewModel = makeViewModel(context: context)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recommendation?.reason.contains("-3.0°"), true)
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

    func test_completeRoutine_savesFullCompletionWithDuration() throws {
        let context = try makeInMemoryContext()
        let careRepository = CareRepository(modelContext: context)
        let viewModel = CareViewModel(
            sessionRepository: SessionRepository(modelContext: context),
            careRepository: careRepository,
            favorites: InMemoryCareFavorites(),
            now: { Date(timeIntervalSince1970: 2_000) }
        )
        let routine = CareRoutine.catalog[0]

        try viewModel.completeRoutine(routine, startedAt: Date(timeIntervalSince1970: 1_870))

        let saved = try XCTUnwrap(careRepository.fetchCompletions(from: .distantPast, to: .distantFuture).first)
        XCTAssertTrue(saved.wasCompleted)
        XCTAssertEqual(saved.durationSeconds ?? -1, 130, accuracy: 0.001)
        XCTAssertEqual(saved.completedSteps, routine.steps.count)
        XCTAssertEqual(saved.totalSteps, routine.steps.count)
    }

    func test_abandonRoutine_savesPartialProgress() throws {
        let context = try makeInMemoryContext()
        let careRepository = CareRepository(modelContext: context)
        let viewModel = CareViewModel(
            sessionRepository: SessionRepository(modelContext: context),
            careRepository: careRepository,
            favorites: InMemoryCareFavorites(),
            now: { Date(timeIntervalSince1970: 2_000) }
        )
        let routine = CareRoutine.catalog[0]

        try viewModel.abandonRoutine(routine, startedAt: Date(timeIntervalSince1970: 1_940), completedSteps: 2)

        let saved = try XCTUnwrap(careRepository.fetchCompletions(from: .distantPast, to: .distantFuture).first)
        XCTAssertFalse(saved.wasCompleted)
        XCTAssertEqual(saved.completedSteps, 2)
        XCTAssertEqual(saved.totalSteps, routine.steps.count)
    }

    func test_abandonRoutine_ignoresZeroStepAbandons() throws {
        let context = try makeInMemoryContext()
        let careRepository = CareRepository(modelContext: context)
        let viewModel = CareViewModel(
            sessionRepository: SessionRepository(modelContext: context),
            careRepository: careRepository,
            favorites: InMemoryCareFavorites(),
            now: { Date(timeIntervalSince1970: 2_000) }
        )

        try viewModel.abandonRoutine(CareRoutine.catalog[0], startedAt: Date(timeIntervalSince1970: 1_990), completedSteps: 0)

        XCTAssertTrue(try careRepository.fetchCompletions(from: .distantPast, to: .distantFuture).isEmpty)
    }

    func test_routineDurationText_roundsUpToMinutes() {
        let routine = CareRoutine.catalog.first { $0.id == "lift-smile" }!
        // 30 + 10×3 + 30 + 60 = 150초 → 3분
        XCTAssertEqual(routine.totalSeconds, 150)
        XCTAssertEqual(routine.durationText, "3분")
    }

    func test_refresh_recommendsFromInsight_whenTensionHigh() throws {
        let context = try makeInMemoryContext()
        let sessionRepository = SessionRepository(modelContext: context)
        // 신뢰 히스토리 3일(긴장도 0.2) + 최신(긴장도 0.4) → highTension → relax 추천.
        for daysAgo in [1, 2, 3] {
            try seedCheckIn(sessionRepository, daysAgo: daysAgo, browTension: 0.2, from: fixedNow)
        }
        try seedCheckIn(sessionRepository, daysAgo: 0, browTension: 0.4, from: fixedNow)
        let viewModel = makeViewModel(context: context)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recommendation?.routine.category, .relax)
        XCTAssertEqual(viewModel.recommendation?.reason.contains("긴장"), true)
    }

    private func seedCheckIn(_ repository: SessionRepository, daysAgo: Int, browTension: Double, from now: Date) throws {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        let noon = calendar.date(byAdding: .hour, value: 12, to: start)!
        try repository.saveCheckIn(
            measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: browTension),
            date: noon,
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: 0
        )
    }
}
