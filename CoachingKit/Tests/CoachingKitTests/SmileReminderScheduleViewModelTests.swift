import XCTest
import SwiftData
@testable import CoachingKit

@MainActor
final class SmileReminderScheduleViewModelTests: XCTestCase {
    /// 호출을 조용히 버리지 않고 전부 기록한다 — 예약이 빠진 것과 기록이 빠진 것을 구분해야 한다.
    private final class MockScheduler: ReminderScheduling {
        enum SchedulingError: Error {
            case failed
        }

        var status: ReminderAuthorizationStatus = .authorized
        var shouldFailScheduling = false
        private(set) var scheduled: [(String, [ReminderTime], [ReminderMessage])] = []
        private(set) var cancelledGroups: [String] = []
        private(set) var cancelledLegacy: [String] = []
        private(set) var operations: [String] = []

        func requestAuthorization() async -> Bool { status == .authorized }
        func currentAuthorizationStatus() async -> ReminderAuthorizationStatus { status }
        func cancel(id: String) {
            cancelledLegacy.append(id)
            operations.append("cancel-legacy:\(id)")
        }
        func scheduleDailyPattern(
            groupID: String,
            times: [ReminderTime],
            messages: [ReminderMessage]
        ) async throws {
            operations.append("schedule:\(groupID)")
            if shouldFailScheduling {
                throw SchedulingError.failed
            }
            scheduled.append((groupID, times, messages))
        }
        func cancelGroup(id: String) {
            cancelledGroups.append(id)
            operations.append("cancel-group:\(id)")
        }
    }

    private func makeViewModel() throws -> (
        SmileReminderScheduleViewModel,
        SmileReminderScheduleRepository,
        ModelContext,
        MockScheduler
    ) {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let schedules = SmileReminderScheduleRepository(modelContext: context)
        let scheduler = MockScheduler()
        return (
            SmileReminderScheduleViewModel(
                scheduleRepository: schedules,
                legacyReminderRepository: LegacyReminderRepository(modelContext: context),
                scheduler: scheduler,
                messageStore: InMemoryReminderMessageStore(),
                groupIDFactory: { "new-group" }
            ),
            schedules,
            context,
            scheduler
        )
    }

    /// 예전 버전이 남긴 개별 알림 레코드.
    @discardableResult
    private func insertLegacyReminder(
        _ context: ModelContext,
        hour: Int,
        minute: Int = 0,
        notificationID: String
    ) throws -> String {
        context.insert(ReminderSetting(hour: hour, minute: minute, notificationID: notificationID))
        try context.save()
        return notificationID
    }

    func test_defaultState_hasRecommendedFiveOccurrences() throws {
        let (viewModel, _, _, _) = try makeViewModel()

        XCTAssertEqual(viewModel.pattern, .recommended)
        XCTAssertEqual(viewModel.occurrenceTimes.count, 5)
    }

    func test_saveSchedulesDailyPattern_andCancelsLegacyAfterSave() async throws {
        let (viewModel, schedules, context, scheduler) = try makeViewModel()
        let old = try insertLegacyReminder(context, hour: 9, notificationID: "legacy-morning")

        let didSave = await viewModel.save()
        XCTAssertTrue(didSave)

        XCTAssertEqual(try schedules.fetchCurrent()?.pattern, .recommended)
        XCTAssertEqual(try schedules.fetchCurrent()?.notificationGroupID, "new-group")
        XCTAssertEqual(scheduler.scheduled.first?.1.count, 5)
        XCTAssertEqual(scheduler.scheduled.first?.2, ReminderMessageCatalog.defaults)
        XCTAssertEqual(scheduler.cancelledLegacy, [old])
    }

    /// 예전 알림이 여러 개면 하나도 남기지 않고 전부 취소해야 한다.
    func test_save_cancelsEveryLegacyNotificationID() async throws {
        let (viewModel, _, context, scheduler) = try makeViewModel()
        try insertLegacyReminder(context, hour: 9, notificationID: "legacy-morning")
        try insertLegacyReminder(context, hour: 13, notificationID: "legacy-noon")
        try insertLegacyReminder(context, hour: 21, notificationID: "legacy-evening")

        let didSave = await viewModel.save()
        XCTAssertTrue(didSave)

        XCTAssertEqual(
            Set(scheduler.cancelledLegacy),
            ["legacy-morning", "legacy-noon", "legacy-evening"]
        )
    }

    /// 저장이 실패했는데 예전 알림을 먼저 끄면 사용자는 알림이 아예 없는 상태로 남는다.
    func test_invalidRange_doesNotCancelLegacyNotifications() async throws {
        let (viewModel, _, context, scheduler) = try makeViewModel()
        try insertLegacyReminder(context, hour: 9, notificationID: "legacy-morning")
        viewModel.updateStart(hour: 21, minute: 0)
        viewModel.updateEnd(hour: 21, minute: 0)

        let didSave = await viewModel.save()
        XCTAssertFalse(didSave)

        XCTAssertTrue(scheduler.cancelledLegacy.isEmpty, "저장 전에는 예전 알림을 끄지 않는다")
    }

    func test_disabledSave_cancelsGroupWithoutScheduling() async throws {
        let (viewModel, schedules, _, scheduler) = try makeViewModel()
        viewModel.updateEnabled(false)

        let didSave = await viewModel.save()
        XCTAssertTrue(didSave)

        let saved = try XCTUnwrap(schedules.fetchCurrent())
        XCTAssertTrue(scheduler.scheduled.isEmpty)
        XCTAssertEqual(scheduler.cancelledGroups.last, saved.notificationGroupID)
    }

    func test_invalidRange_isRejectedWithoutPersistence() async throws {
        let (viewModel, schedules, _, scheduler) = try makeViewModel()
        viewModel.updateStart(hour: 21, minute: 0)
        viewModel.updateEnd(hour: 21, minute: 0)

        let didSave = await viewModel.save()
        XCTAssertFalse(didSave)
        XCTAssertNil(try schedules.fetchCurrent())
        XCTAssertTrue(scheduler.scheduled.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    /// 자정을 넘는 창도 창을 지나는 순서 그대로 예약된다 — 문구가 이 순서로 돈다.
    func test_windowCrossingMidnight_schedulesInWindowOrder() async throws {
        let (viewModel, _, _, scheduler) = try makeViewModel()
        viewModel.updateStart(hour: 22, minute: 0)
        viewModel.updateEnd(hour: 1, minute: 0)
        viewModel.updateInterval(60)

        let didSave = await viewModel.save()
        XCTAssertTrue(didSave)

        XCTAssertEqual(
            scheduler.scheduled.last?.1.map(\.hour),
            [22, 23, 0, 1]
        )
    }

    func test_scheduleFailure_keepsPreviousScheduleAndLegacyNotifications() async throws {
        let (viewModel, schedules, context, scheduler) = try makeViewModel()
        let changedPattern = try SmileReminderPattern(
            startTime: ReminderTime(hour: 10, minute: 0),
            endTime: ReminderTime(hour: 20, minute: 0),
            intervalMinutes: 120
        )
        try schedules.save(
            pattern: changedPattern,
            isEnabled: true,
            notificationGroupID: "old-group"
        )
        try insertLegacyReminder(context, hour: 9, notificationID: "legacy-morning")
        scheduler.shouldFailScheduling = true

        let didSave = await viewModel.save()

        XCTAssertFalse(didSave)
        let stored = try XCTUnwrap(schedules.fetchCurrent())
        XCTAssertEqual(stored.pattern, changedPattern)
        XCTAssertEqual(stored.notificationGroupID, "old-group")
        XCTAssertTrue(scheduler.cancelledGroups.isEmpty)
        XCTAssertTrue(scheduler.cancelledLegacy.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, "알림을 등록하지 못했어요. 기존 알림은 그대로 유지했어요.")
    }

    func test_successfulReplacement_schedulesNewGroupBeforeCancellingOldGroup() async throws {
        let (viewModel, schedules, context, scheduler) = try makeViewModel()
        try schedules.save(
            pattern: .recommended,
            isEnabled: true,
            notificationGroupID: "old-group"
        )
        try insertLegacyReminder(context, hour: 9, notificationID: "legacy-morning")

        let didSave = await viewModel.save()

        XCTAssertTrue(didSave)
        XCTAssertEqual(
            scheduler.operations,
            [
                "schedule:new-group",
                "cancel-group:old-group",
                "cancel-legacy:legacy-morning",
            ]
        )
        XCTAssertEqual(try schedules.fetchCurrent()?.notificationGroupID, "new-group")
    }
}
