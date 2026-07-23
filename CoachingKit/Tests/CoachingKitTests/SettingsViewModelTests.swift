import XCTest
import SwiftData
@testable import CoachingKit

final class SettingsViewModelTests: XCTestCase {
    private final class MockScheduler: ReminderScheduling {
        private(set) var authorizationRequests = 0
        private(set) var scheduled: [(id: String, hour: Int, minute: Int)] = []
        private(set) var cancelled: [String] = []

        func requestAuthorization() async -> Bool {
            authorizationRequests += 1
            return true
        }

        func scheduleDaily(id: String, hour: Int, minute: Int) async {
            scheduled.append((id, hour, minute))
        }

        func cancel(id: String) {
            cancelled.append(id)
        }
    }

    private func makeViewModel() throws -> (SettingsViewModel, SessionRepository, MockScheduler) {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let sessionRepository = SessionRepository(modelContext: context)
        let scheduler = MockScheduler()
        let viewModel = SettingsViewModel(
            reminderRepository: ReminderRepository(modelContext: context),
            sessionRepository: sessionRepository,
            scheduler: scheduler
        )
        return (viewModel, sessionRepository, scheduler)
    }

    func test_addReminder_persistsAndSchedules() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()

        try await viewModel.addReminder(hour: 9, minute: 30)

        XCTAssertEqual(viewModel.reminders.count, 1)
        XCTAssertEqual(scheduler.authorizationRequests, 1)
        XCTAssertEqual(scheduler.scheduled.count, 1)
        XCTAssertEqual(scheduler.scheduled.first?.hour, 9)
        XCTAssertEqual(scheduler.scheduled.first?.minute, 30)
    }

    func test_removeReminder_deletesAndCancels() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        try await viewModel.addReminder(hour: 9, minute: 0)
        let reminder = try XCTUnwrap(viewModel.reminders.first)

        try viewModel.removeReminder(reminder)

        XCTAssertEqual(viewModel.reminders.count, 0)
        XCTAssertEqual(scheduler.cancelled, [reminder.notificationID])
    }

    func test_toggleReminder_offCancels_onReschedules() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        try await viewModel.addReminder(hour: 9, minute: 0)
        let reminder = try XCTUnwrap(viewModel.reminders.first)

        try await viewModel.toggleReminder(reminder)
        XCTAssertFalse(reminder.isEnabled)
        XCTAssertEqual(scheduler.cancelled, [reminder.notificationID])

        try await viewModel.toggleReminder(reminder)
        XCTAssertTrue(reminder.isEnabled)
        XCTAssertEqual(scheduler.scheduled.count, 2)
    }

    func test_refresh_computesBaselineAgeWeeks() throws {
        let (viewModel, sessionRepository, _) = try makeViewModel()
        let sixWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -6, to: Date())!
        try sessionRepository.saveBaseline(
            FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
            capturedAt: sixWeeksAgo,
            lightingQuality: 1.0,
            deviceAngleOK: true
        )

        try viewModel.refresh()

        XCTAssertEqual(viewModel.baselineAgeWeeks, 6)
    }

    func test_refresh_baselineAgeNil_whenNoBaseline() throws {
        let (viewModel, _, _) = try makeViewModel()

        try viewModel.refresh()

        XCTAssertNil(viewModel.baselineAgeWeeks)
    }
}
