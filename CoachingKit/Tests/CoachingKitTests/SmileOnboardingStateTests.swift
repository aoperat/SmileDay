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

    func test_confirm_completesWhenPermissionDenied() async throws {
        let (viewModel, repository, scheduler, store) = try makeViewModel()
        scheduler.status = .denied

        await viewModel.confirm()

        XCTAssertNotNil(try repository.fetchCurrent())
        XCTAssertTrue(store.hasCompletedOnboarding)
        XCTAssertTrue(viewModel.didComplete)
    }

    func test_skipReminders_savesDisabledSchedule() async throws {
        let (viewModel, repository, scheduler, store) = try makeViewModel()

        await viewModel.skipReminders()

        XCTAssertFalse(try XCTUnwrap(repository.fetchCurrent()).isEnabled)
        XCTAssertTrue(scheduler.dailySchedules.isEmpty)
        XCTAssertTrue(store.hasCompletedOnboarding)
    }

    func test_invalidRange_doesNotComplete() async throws {
        let (viewModel, repository, _, store) = try makeViewModel()
        viewModel.schedule.updateStart(hour: 21, minute: 0)
        viewModel.schedule.updateEnd(hour: 9, minute: 0)

        await viewModel.confirm()

        XCTAssertNil(try repository.fetchCurrent())
        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertFalse(viewModel.didComplete)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func test_scheduleFailure_doesNotCompleteOrPersistSchedule() async throws {
        let (viewModel, repository, scheduler, store) = try makeViewModel()
        scheduler.shouldFailScheduling = true

        await viewModel.confirm()

        XCTAssertNil(try repository.fetchCurrent())
        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertFalse(viewModel.didComplete)
        XCTAssertNotNil(viewModel.errorMessage)
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
