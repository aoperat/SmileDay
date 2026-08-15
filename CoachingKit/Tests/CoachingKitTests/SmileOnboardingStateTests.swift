import XCTest
import SwiftData
@testable import CoachingKit

@MainActor
final class SmileOnboardingStateTests: XCTestCase {
    private final class MockScheduler: ReminderScheduling {
        enum SchedulingError: Error {
            case failed
        }

        var status: ReminderAuthorizationStatus = .authorized
        var shouldFailScheduling = false
        private(set) var authorizationRequests = 0
        private(set) var dailySchedules: [(String, [ReminderTime], [ReminderMessage])] = []
        private(set) var cancelledGroups: [String] = []
        private(set) var cancelledLegacy: [String] = []

        func requestAuthorization() async -> Bool {
            authorizationRequests += 1
            return status == .authorized
        }

        func currentAuthorizationStatus() async -> ReminderAuthorizationStatus { status }
        func cancel(id: String) { cancelledLegacy.append(id) }
        func scheduleDailyPattern(
            groupID: String,
            times: [ReminderTime],
            messages: [ReminderMessage]
        ) async throws {
            if shouldFailScheduling {
                throw SchedulingError.failed
            }
            dailySchedules.append((groupID, times, messages))
        }
        func cancelGroup(id: String) {
            cancelledGroups.append(id)
        }
    }

    private func makeViewModel() throws -> (
        SmileOnboardingViewModel,
        SmileReminderScheduleRepository,
        MockScheduler,
        InMemorySmileOnboardingStore
    ) {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let repository = SmileReminderScheduleRepository(modelContext: context)
        let scheduler = MockScheduler()
        let store = InMemorySmileOnboardingStore()
        let schedule = SmileReminderScheduleViewModel(
            scheduleRepository: repository,
            legacyReminderRepository: LegacyReminderRepository(modelContext: context),
            scheduler: scheduler,
            messageStore: InMemoryReminderMessageStore()
        )
        return (SmileOnboardingViewModel(schedule: schedule, store: store), repository, scheduler, store)
    }

    func test_confirm_savesRecommendedPatternAndSchedulesFiveTimes() async throws {
        let (viewModel, repository, scheduler, store) = try makeViewModel()

        await viewModel.confirm()

        XCTAssertEqual(try repository.fetchCurrent()?.pattern, .recommended)
        XCTAssertEqual(scheduler.dailySchedules.first?.1.count, 5)
        XCTAssertEqual(scheduler.authorizationRequests, 1)
        XCTAssertTrue(store.hasCompletedOnboarding)
        XCTAssertTrue(viewModel.didComplete)
    }

    /// 예전에는 거부당해도 그대로 온보딩을 끝냈다. 그러면 사용자는 알림이 켜진 줄 알고
    /// 홈으로 나가고, 이 앱에 남는 흐름이 없는 채로 며칠이 지난다. iOS는 권한을 한 번만
    /// 물으므로 여기서 짚지 않으면 다시 물을 기회도 없다.
    func test_confirm_stopsToExplain_whenPermissionDenied() async throws {
        let (viewModel, repository, scheduler, store) = try makeViewModel()
        scheduler.status = .denied

        await viewModel.confirm()

        // 일정은 저장돼 있다 — 권한만 켜면 바로 동작해야 하기 때문이다.
        XCTAssertNotNil(try repository.fetchCurrent())
        XCTAssertTrue(viewModel.wasPermissionDenied)
        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertFalse(viewModel.didComplete)
    }

    /// 설명을 읽고도 그대로 가겠다면 막지 않는다.
    func test_continueWithoutPermission_completesAfterTheExplanation() async throws {
        let (viewModel, _, scheduler, store) = try makeViewModel()
        scheduler.status = .denied
        await viewModel.confirm()

        viewModel.continueWithoutPermission()

        XCTAssertTrue(store.hasCompletedOnboarding)
        XCTAssertTrue(viewModel.didComplete)
    }

    func test_confirm_doesNotFlagDenial_whenPermissionGranted() async throws {
        let (viewModel, _, _, store) = try makeViewModel()

        await viewModel.confirm()

        XCTAssertFalse(viewModel.wasPermissionDenied)
        XCTAssertTrue(store.hasCompletedOnboarding)
    }

    func test_skipReminders_savesDisabledSchedule() async throws {
        let (viewModel, repository, scheduler, store) = try makeViewModel()

        await viewModel.skipReminders()

        XCTAssertFalse(try XCTUnwrap(repository.fetchCurrent()).isEnabled)
        XCTAssertTrue(scheduler.dailySchedules.isEmpty)
        XCTAssertTrue(store.hasCompletedOnboarding)
    }

    /// 시작과 끝이 같은 창만 거부한다 — 끝이 더 이르면 자정을 넘는 창이다.
    func test_invalidRange_doesNotComplete() async throws {
        let (viewModel, repository, _, store) = try makeViewModel()
        viewModel.schedule.updateStart(hour: 21, minute: 0)
        viewModel.schedule.updateEnd(hour: 21, minute: 0)

        await viewModel.confirm()

        XCTAssertNil(try repository.fetchCurrent())
        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertFalse(viewModel.didComplete)
        XCTAssertFalse(viewModel.schedule.isPatternValid)
        XCTAssertNil(viewModel.error)
    }

    func test_scheduleFailure_doesNotCompleteOrPersistSchedule() async throws {
        let (viewModel, repository, scheduler, store) = try makeViewModel()
        scheduler.shouldFailScheduling = true

        await viewModel.confirm()

        XCTAssertNil(try repository.fetchCurrent())
        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertFalse(viewModel.didComplete)
        XCTAssertEqual(viewModel.error, .schedulingFailed)
    }

    func test_userDefaultsStore_roundTripsFlag() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "SmileOnboardingStateTests"))
        defaults.removePersistentDomain(forName: "SmileOnboardingStateTests")
        let store = UserDefaultsSmileOnboardingStore(defaults: defaults)

        store.hasCompletedOnboarding = true

        XCTAssertTrue(UserDefaultsSmileOnboardingStore(defaults: defaults).hasCompletedOnboarding)
        defaults.removePersistentDomain(forName: "SmileOnboardingStateTests")
    }
}
