import XCTest
import SwiftData
@testable import CoachingKit

final class SettingsViewModelTests: XCTestCase {
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
        XCTAssertEqual(scheduler.scheduled.first?.days, reminderRollingWindowDays)
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

    func test_refreshAllScheduledReminders_reschedulesOnlyEnabledReminders() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        try await viewModel.addReminder(hour: 9, minute: 0)
        try await viewModel.addReminder(hour: 20, minute: 30)
        let morningReminder = try XCTUnwrap(viewModel.reminders.first { $0.hour == 9 })
        try await viewModel.toggleReminder(morningReminder) // 끈다
        let scheduledBeforeRefresh = scheduler.scheduled.count

        try await viewModel.refreshAllScheduledReminders()

        let newlyScheduled = scheduler.scheduled.suffix(from: scheduledBeforeRefresh)
        XCTAssertEqual(newlyScheduled.count, 1, "꺼진 리마인더는 다시 예약되면 안 된다")
        XCTAssertEqual(newlyScheduled.first?.hour, 20)
    }

    func test_updateReminderTime_enabledReminder_reschedules() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        try await viewModel.addReminder(hour: 9, minute: 0)
        let reminder = try XCTUnwrap(viewModel.reminders.first)
        let scheduledBefore = scheduler.scheduled.count

        try await viewModel.updateReminderTime(reminder, hour: 20, minute: 30)

        XCTAssertEqual(viewModel.reminders.first?.hour, 20)
        XCTAssertEqual(viewModel.reminders.first?.minute, 30)
        let newlyScheduled = scheduler.scheduled.suffix(from: scheduledBefore)
        XCTAssertEqual(newlyScheduled.count, 1)
        XCTAssertEqual(newlyScheduled.first?.hour, 20)
        XCTAssertEqual(newlyScheduled.first?.minute, 30)
    }

    func test_updateReminderTime_disabledReminder_doesNotReschedule() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        try await viewModel.addReminder(hour: 9, minute: 0)
        let reminder = try XCTUnwrap(viewModel.reminders.first)
        try await viewModel.toggleReminder(reminder) // 끈다
        let scheduledBefore = scheduler.scheduled.count

        try await viewModel.updateReminderTime(reminder, hour: 20, minute: 30)

        XCTAssertEqual(viewModel.reminders.first?.hour, 20)
        XCTAssertEqual(scheduler.scheduled.count, scheduledBefore, "꺼진 리마인더는 시간만 바뀌고 재예약되면 안 된다")
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

    func test_shouldRecommendReset_falseUnderFourWeeks() throws {
        let (viewModel, sessionRepository, _) = try makeViewModel()
        let threeWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -3, to: Date())!
        try sessionRepository.saveBaseline(
            FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
            capturedAt: threeWeeksAgo,
            lightingQuality: 1.0,
            deviceAngleOK: true
        )

        try viewModel.refresh()

        XCTAssertFalse(viewModel.shouldRecommendReset)
    }

    func test_shouldRecommendReset_trueAtFourWeeksOrMore() throws {
        let (viewModel, sessionRepository, _) = try makeViewModel()
        let fourWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: Date())!
        try sessionRepository.saveBaseline(
            FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
            capturedAt: fourWeeksAgo,
            lightingQuality: 1.0,
            deviceAngleOK: true
        )

        try viewModel.refresh()

        XCTAssertTrue(viewModel.shouldRecommendReset)
    }

    func test_shouldRecommendReset_falseWhenNoBaseline() throws {
        let (viewModel, _, _) = try makeViewModel()

        try viewModel.refresh()

        XCTAssertFalse(viewModel.shouldRecommendReset)
    }

    // MARK: - 미소 가이드

    func test_addReminder_schedulesWithChosenGuide() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()

        try await viewModel.addReminder(hour: 13, minute: 0, guideID: "greeting-smile")

        XCTAssertEqual(viewModel.reminders.first?.guideID, "greeting-smile")
        XCTAssertEqual(scheduler.scheduled.first?.guideID, "greeting-smile")
    }

    func test_addReminder_withoutGuide_usesDefaultGuide() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()

        try await viewModel.addReminder(hour: 9, minute: 0)

        XCTAssertEqual(scheduler.scheduled.first?.guideID, SmileGuideCatalog.default.id)
    }

    func test_updateReminderGuide_reschedulesWithNewGuide() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        try await viewModel.addReminder(hour: 9, minute: 0, guideID: "soft-smile")
        let reminder = try XCTUnwrap(viewModel.reminders.first)
        let scheduledBefore = scheduler.scheduled.count

        try await viewModel.updateReminderGuide(reminder, guideID: "bright-smile")

        XCTAssertEqual(viewModel.reminders.first?.guideID, "bright-smile")
        let newlyScheduled = scheduler.scheduled.suffix(from: scheduledBefore)
        XCTAssertEqual(newlyScheduled.count, 1)
        XCTAssertEqual(newlyScheduled.first?.guideID, "bright-smile")
    }

    func test_updateReminderGuide_disabledReminder_doesNotReschedule() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        try await viewModel.addReminder(hour: 9, minute: 0)
        let reminder = try XCTUnwrap(viewModel.reminders.first)
        try await viewModel.toggleReminder(reminder) // 끈다
        let scheduledBefore = scheduler.scheduled.count

        try await viewModel.updateReminderGuide(reminder, guideID: "bright-smile")

        XCTAssertEqual(viewModel.reminders.first?.guideID, "bright-smile")
        XCTAssertEqual(scheduler.scheduled.count, scheduledBefore)
    }

    func test_updateReminderTime_keepsGuide() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        try await viewModel.addReminder(hour: 9, minute: 0, guideID: "bright-smile")
        let reminder = try XCTUnwrap(viewModel.reminders.first)
        let scheduledBefore = scheduler.scheduled.count

        try await viewModel.updateReminderTime(reminder, hour: 20, minute: 30)

        let newlyScheduled = scheduler.scheduled.suffix(from: scheduledBefore)
        XCTAssertEqual(newlyScheduled.first?.guideID, "bright-smile")
        XCTAssertEqual(newlyScheduled.first?.hour, 20)
    }

    func test_toggleReminder_backOn_keepsGuide() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        try await viewModel.addReminder(hour: 9, minute: 0, guideID: "greeting-smile")
        let reminder = try XCTUnwrap(viewModel.reminders.first)

        try await viewModel.toggleReminder(reminder) // 끈다
        try await viewModel.toggleReminder(reminder) // 다시 켠다

        XCTAssertEqual(scheduler.scheduled.last?.guideID, "greeting-smile")
    }

    func test_refreshAllScheduledReminders_keepsEachReminderGuide() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        try await viewModel.addReminder(hour: 9, minute: 0, guideID: "soft-smile")
        try await viewModel.addReminder(hour: 13, minute: 0, guideID: "greeting-smile")
        try await viewModel.addReminder(hour: 18, minute: 0, guideID: "bright-smile")
        let scheduledBefore = scheduler.scheduled.count

        try await viewModel.refreshAllScheduledReminders()

        let newlyScheduled = scheduler.scheduled.suffix(from: scheduledBefore)
        XCTAssertEqual(newlyScheduled.map(\.guideID), ["soft-smile", "greeting-smile", "bright-smile"])
    }

    /// guideID가 nil인 과거 알림도 재예약 시 기본 가이드로 나간다.
    func test_refreshAllScheduledReminders_legacyReminderWithoutGuide_usesDefault() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        try await viewModel.addReminder(hour: 9, minute: 0)
        let reminder = try XCTUnwrap(viewModel.reminders.first)
        reminder.guideID = nil
        let scheduledBefore = scheduler.scheduled.count

        try await viewModel.refreshAllScheduledReminders()

        let newlyScheduled = scheduler.scheduled.suffix(from: scheduledBefore)
        XCTAssertEqual(newlyScheduled.first?.guideID, "soft-smile")
    }

    /// 여러 알림을 만드는 데 개수 제한이 없어야 한다 — 다중 알림이 MVP 핵심 무료 기능이다.
    func test_addReminder_hasNoCountLimit() async throws {
        let (viewModel, _, _) = try makeViewModel()

        for hour in 8...17 {
            try await viewModel.addReminder(hour: hour, minute: 0)
        }

        XCTAssertEqual(viewModel.reminders.count, 10)
    }

    // MARK: - 권한 상태

    func test_refreshAuthorizationStatus_readsFromScheduler() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        XCTAssertNil(viewModel.authorizationStatus)
        scheduler.status = .denied

        await viewModel.refreshAuthorizationStatus()

        XCTAssertEqual(viewModel.authorizationStatus, .denied)
    }

    /// 권한을 거부해도 리마인더 저장 자체는 성공해야 한다.
    func test_addReminder_stillSaves_whenAuthorizationDenied() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        scheduler.status = .denied

        try await viewModel.addReminder(hour: 9, minute: 0)

        XCTAssertEqual(viewModel.reminders.count, 1)
        XCTAssertEqual(viewModel.authorizationStatus, .denied)
    }
}
