import XCTest
import SwiftData
@testable import CoachingKit

@MainActor
final class SmileOnboardingStateTests: XCTestCase {
    private final class MockScheduler: ReminderScheduling {
        private(set) var authorizationRequests = 0
        private(set) var scheduled: [(id: String, hour: Int, minute: Int, guideID: String, days: Int)] = []
        private(set) var cancelled: [String] = []
        var status: ReminderAuthorizationStatus = .authorized

        func requestAuthorization() async -> Bool {
            authorizationRequests += 1
            return status == .authorized
        }

        func currentAuthorizationStatus() async -> ReminderAuthorizationStatus {
            status
        }

        func scheduleRollingWindow(id: String, hour: Int, minute: Int, guideID: String, days: Int) async {
            scheduled.append((id, hour, minute, guideID, days))
        }

        func cancel(id: String) {
            cancelled.append(id)
        }
    }

    private func makeViewModel() throws -> (SmileOnboardingViewModel, ReminderRepository, MockScheduler, InMemorySmileOnboardingStore) {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let repository = ReminderRepository(modelContext: ModelContext(container))
        let scheduler = MockScheduler()
        let store = InMemorySmileOnboardingStore()
        let viewModel = SmileOnboardingViewModel(
            reminderRepository: repository,
            scheduler: scheduler,
            store: store
        )
        return (viewModel, repository, scheduler, store)
    }

    // MARK: - 저장소

    func test_inMemoryStore_startsIncomplete() {
        XCTAssertFalse(InMemorySmileOnboardingStore().hasCompletedOnboarding)
    }

    func test_userDefaultsStore_roundTripsFlag() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "SmileOnboardingStateTests"))
        defaults.removePersistentDomain(forName: "SmileOnboardingStateTests")
        let store = UserDefaultsSmileOnboardingStore(defaults: defaults)

        XCTAssertFalse(store.hasCompletedOnboarding)
        store.hasCompletedOnboarding = true
        XCTAssertTrue(UserDefaultsSmileOnboardingStore(defaults: defaults).hasCompletedOnboarding)

        defaults.removePersistentDomain(forName: "SmileOnboardingStateTests")
    }

    // MARK: - 권장 기본값

    func test_recommendedDrafts_areThreeTimesWithDistinctGuides() throws {
        let (viewModel, _, _, _) = try makeViewModel()

        XCTAssertEqual(viewModel.drafts.count, 3)
        XCTAssertEqual(viewModel.drafts.map(\.hour), [9, 13, 18])
        XCTAssertEqual(viewModel.drafts.map(\.guideID), ["soft-smile", "greeting-smile", "bright-smile"])
    }

    func test_guides_offerTheWholeCatalog() throws {
        let (viewModel, _, _, _) = try makeViewModel()

        XCTAssertEqual(viewModel.guides.map(\.id), SmileGuideCatalog.all.map(\.id))
    }

    // MARK: - 사용자 수정

    func test_updateTime_changesOnlyThatDraft() throws {
        let (viewModel, _, _, _) = try makeViewModel()
        let target = try XCTUnwrap(viewModel.drafts.first)

        viewModel.updateTime(draftID: target.id, hour: 7, minute: 30)

        XCTAssertEqual(viewModel.drafts.first?.hour, 7)
        XCTAssertEqual(viewModel.drafts.first?.minute, 30)
        XCTAssertEqual(viewModel.drafts[1].hour, 13)
    }

    func test_updateGuide_changesOnlyThatDraft() throws {
        let (viewModel, _, _, _) = try makeViewModel()
        let target = try XCTUnwrap(viewModel.drafts.first)

        viewModel.updateGuide(draftID: target.id, guideID: "bright-smile")

        XCTAssertEqual(viewModel.drafts.first?.guideID, "bright-smile")
        XCTAssertEqual(viewModel.drafts[1].guideID, "greeting-smile")
    }

    func test_addAndRemoveDraft() throws {
        let (viewModel, _, _, _) = try makeViewModel()

        viewModel.addDraft(hour: 21, minute: 0, guideID: "soft-smile")
        XCTAssertEqual(viewModel.drafts.count, 4)

        let removed = try XCTUnwrap(viewModel.drafts.last)
        viewModel.removeDraft(id: removed.id)
        XCTAssertEqual(viewModel.drafts.count, 3)
    }

    // MARK: - 확정

    func test_confirm_requestsAuthorizationSavesAndSchedules() async throws {
        let (viewModel, repository, scheduler, store) = try makeViewModel()

        await viewModel.confirm()

        XCTAssertEqual(scheduler.authorizationRequests, 1)
        XCTAssertEqual(try repository.fetchAll().count, 3)
        XCTAssertEqual(scheduler.scheduled.map(\.guideID), ["soft-smile", "greeting-smile", "bright-smile"])
        XCTAssertEqual(scheduler.scheduled.map(\.hour), [9, 13, 18])
        XCTAssertTrue(scheduler.scheduled.allSatisfy { $0.days == reminderRollingWindowDays })
        XCTAssertTrue(store.hasCompletedOnboarding)
        XCTAssertTrue(viewModel.didComplete)
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_confirm_savesUserEditedTimesAndGuides() async throws {
        let (viewModel, repository, scheduler, _) = try makeViewModel()
        let first = try XCTUnwrap(viewModel.drafts.first)
        viewModel.updateTime(draftID: first.id, hour: 7, minute: 15)
        viewModel.updateGuide(draftID: first.id, guideID: "bright-smile")

        await viewModel.confirm()

        let saved = try repository.fetchAll()
        XCTAssertEqual(saved.first?.hour, 7)
        XCTAssertEqual(saved.first?.minute, 15)
        XCTAssertEqual(saved.first?.guideID, "bright-smile")
        XCTAssertEqual(scheduler.scheduled.first?.guideID, "bright-smile")
    }

    /// 권한을 거부해도 리마인더는 저장되고 앱에 들어갈 수 있어야 한다.
    func test_confirm_completesEvenWhenAuthorizationDenied() async throws {
        let (viewModel, repository, scheduler, store) = try makeViewModel()
        scheduler.status = .denied

        await viewModel.confirm()

        XCTAssertEqual(viewModel.authorizationStatus, .denied)
        XCTAssertTrue(store.hasCompletedOnboarding)
        XCTAssertTrue(viewModel.didComplete)
        XCTAssertEqual(try repository.fetchAll().count, 3)
    }

    /// 알림을 하나도 두지 않아도 진입할 수 있다.
    func test_confirm_withNoDrafts_completesWithoutReminders() async throws {
        let (viewModel, repository, scheduler, store) = try makeViewModel()
        for draft in viewModel.drafts {
            viewModel.removeDraft(id: draft.id)
        }

        await viewModel.confirm()

        XCTAssertTrue(try repository.fetchAll().isEmpty)
        XCTAssertTrue(scheduler.scheduled.isEmpty)
        XCTAssertTrue(store.hasCompletedOnboarding)
    }

    func test_confirm_isIgnored_whileAlreadySaving() async throws {
        let (viewModel, repository, _, _) = try makeViewModel()

        async let first: Void = viewModel.confirm()
        async let second: Void = viewModel.confirm()
        _ = await (first, second)

        XCTAssertEqual(try repository.fetchAll().count, 3, "확정 버튼 연타로 알림이 두 벌 저장되면 안 된다")
    }

    // MARK: - 알림 없이 시작

    func test_skipReminders_completesWithoutSavingAnything() throws {
        let (viewModel, repository, scheduler, store) = try makeViewModel()

        viewModel.skipReminders()

        XCTAssertTrue(store.hasCompletedOnboarding)
        XCTAssertTrue(viewModel.didComplete)
        XCTAssertTrue(try repository.fetchAll().isEmpty)
        XCTAssertTrue(scheduler.scheduled.isEmpty)
    }
}
