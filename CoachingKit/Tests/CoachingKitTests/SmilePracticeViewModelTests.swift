import XCTest
import SwiftData
@testable import CoachingKit

final class SmilePracticeViewModelTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func makeViewModel(
        careRepository: CareRepository,
        favorites: SmilePracticeFavoritesStoring = InMemorySmilePracticeFavorites(),
        hour: Int
    ) -> SmilePracticeViewModel {
        let calendar = Calendar.current
        let at = calendar.date(byAdding: .hour, value: hour, to: calendar.startOfDay(for: Date()))!
        return SmilePracticeViewModel(careRepository: careRepository, favorites: favorites, now: { at })
    }

    // MARK: - 시간대 기반 추천

    func test_recommendation_morning_offersDayStartPractice() throws {
        let repository = CareRepository(modelContext: try makeInMemoryContext())
        let viewModel = makeViewModel(careRepository: repository, hour: 8)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recommendation?.practice.category, .pause)
        XCTAssertEqual(viewModel.recommendation?.reason, "하루를 여는 짧은 시간이에요.")
    }

    func test_recommendation_afternoon_offersBreathingPractice() throws {
        let repository = CareRepository(modelContext: try makeInMemoryContext())
        let viewModel = makeViewModel(careRepository: repository, hour: 14)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recommendation?.practice.category, .breathe)
    }

    func test_recommendation_evening_offersRecallPractice() throws {
        let repository = CareRepository(modelContext: try makeInMemoryContext())
        let viewModel = makeViewModel(careRepository: repository, hour: 21)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recommendation?.practice.category, .recall)
    }

    func test_recommendation_afterTodaysCompletion_isInvitingNotDemanding() throws {
        let context = try makeInMemoryContext()
        let repository = CareRepository(modelContext: context)
        let calendar = Calendar.current
        let at = calendar.date(byAdding: .hour, value: 9, to: calendar.startOfDay(for: Date()))!
        try repository.saveCompletion(routineID: "smile-breath", date: at)
        let viewModel = makeViewModel(careRepository: repository, hour: 14)

        try viewModel.refresh()

        XCTAssertEqual(
            viewModel.recommendation?.reason,
            "오늘 이미 한 번 쉬어갔어요. 더 하고 싶으면 편하게 이어가세요."
        )
    }

    /// 추천 문구는 얼굴 지표나 점수를 근거로 삼지 않는다.
    func test_recommendationReasons_neverMentionScoreOrFace() throws {
        let repository = CareRepository(modelContext: try makeInMemoryContext())
        let banned = ["점수", "°", "어제", "개선", "근육", "붓기", "균형"]

        for hour in [7, 13, 20] {
            let viewModel = makeViewModel(careRepository: repository, hour: hour)
            try viewModel.refresh()
            let reason = try XCTUnwrap(viewModel.recommendation?.reason)
            for phrase in banned {
                XCTAssertFalse(reason.contains(phrase), "'\(phrase)'가 추천 문구에 있다: \(reason)")
            }
        }
    }

    // MARK: - 필터

    func test_filteredPractices_returnsAll_whenNoCategorySelected() throws {
        let repository = CareRepository(modelContext: try makeInMemoryContext())
        let viewModel = makeViewModel(careRepository: repository, hour: 9)

        XCTAssertEqual(viewModel.filteredPractices.count, SmilePractice.catalog.count)
    }

    func test_filteredPractices_narrowsToSelectedCategory() throws {
        let repository = CareRepository(modelContext: try makeInMemoryContext())
        let viewModel = makeViewModel(careRepository: repository, hour: 9)

        viewModel.selectedCategory = .connect

        XCTAssertFalse(viewModel.filteredPractices.isEmpty)
        XCTAssertTrue(viewModel.filteredPractices.allSatisfy { $0.category == .connect })
    }

    // MARK: - 즐겨찾기

    func test_toggleFavorite_addsThenRemoves() throws {
        let repository = CareRepository(modelContext: try makeInMemoryContext())
        let favorites = InMemorySmilePracticeFavorites()
        let viewModel = makeViewModel(careRepository: repository, favorites: favorites, hour: 9)

        viewModel.toggleFavorite("smile-breath")
        XCTAssertTrue(viewModel.favoriteIDs.contains("smile-breath"))
        XCTAssertEqual(favorites.favoritePracticeIDs, ["smile-breath"])

        viewModel.toggleFavorite("smile-breath")
        XCTAssertFalse(viewModel.favoriteIDs.contains("smile-breath"))
        XCTAssertTrue(favorites.favoritePracticeIDs.isEmpty)
    }

    /// 과거 케어 루틴 즐겨찾기는 화면에서 무시하되 저장된 값을 지우지 않는다.
    func test_legacyFavoriteIDs_areIgnoredButNotErased() throws {
        let repository = CareRepository(modelContext: try makeInMemoryContext())
        let favorites = InMemorySmilePracticeFavorites()
        favorites.favoritePracticeIDs = ["lift-smile", "smile-breath"]
        let viewModel = makeViewModel(careRepository: repository, favorites: favorites, hour: 9)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.visibleFavoriteIDs, ["smile-breath"])
        XCTAssertTrue(favorites.favoritePracticeIDs.contains("lift-smile"), "저장된 과거 ID를 강제로 지우지 않는다")
    }

    // MARK: - 기록 저장

    func test_completePractice_savesCompletedSession() throws {
        let context = try makeInMemoryContext()
        let repository = CareRepository(modelContext: context)
        let viewModel = makeViewModel(careRepository: repository, hour: 9)
        let practice = try XCTUnwrap(SmilePractice.catalog.first)

        try viewModel.completePractice(practice)

        let sessions = try context.fetch(FetchDescriptor<CareSession>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.routineID, practice.id)
        XCTAssertEqual(sessions.first?.wasCompleted, true)
        XCTAssertEqual(sessions.first?.completedSteps, practice.steps.count)
    }

    func test_abandonPractice_savesPartialSession() throws {
        let context = try makeInMemoryContext()
        let repository = CareRepository(modelContext: context)
        let viewModel = makeViewModel(careRepository: repository, hour: 9)
        let practice = try XCTUnwrap(SmilePractice.catalog.first)

        try viewModel.abandonPractice(practice, startedAt: nil, completedSteps: 1)

        let sessions = try context.fetch(FetchDescriptor<CareSession>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.wasCompleted, false)
        XCTAssertEqual(sessions.first?.completedSteps, 1)
    }

    func test_abandonPractice_ignoresImmediateExit() throws {
        let context = try makeInMemoryContext()
        let repository = CareRepository(modelContext: context)
        let viewModel = makeViewModel(careRepository: repository, hour: 9)
        let practice = try XCTUnwrap(SmilePractice.catalog.first)

        try viewModel.abandonPractice(practice, startedAt: nil, completedSteps: 0)

        XCTAssertTrue(try context.fetch(FetchDescriptor<CareSession>()).isEmpty)
    }

    /// 과거 케어 기록은 삭제하지 않고 그대로 남는다.
    func test_legacyCareSessions_arePreserved() throws {
        let context = try makeInMemoryContext()
        let repository = CareRepository(modelContext: context)
        try repository.saveCompletion(routineID: "lift-smile", date: Date())
        let viewModel = makeViewModel(careRepository: repository, hour: 9)

        try viewModel.refresh()
        try viewModel.completePractice(try XCTUnwrap(SmilePractice.catalog.first))

        let ids = try context.fetch(FetchDescriptor<CareSession>()).map(\.routineID)
        XCTAssertTrue(ids.contains("lift-smile"))
        XCTAssertEqual(ids.count, 2)
    }

    func test_categoryForBucket_mapsTimeOfDayToIntent() {
        XCTAssertEqual(SmilePracticeViewModel.category(for: .morning), .pause)
        XCTAssertEqual(SmilePracticeViewModel.category(for: .afternoon), .breathe)
        XCTAssertEqual(SmilePracticeViewModel.category(for: .evening), .recall)
    }
}
