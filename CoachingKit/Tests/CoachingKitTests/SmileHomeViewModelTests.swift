import XCTest
import SwiftData
@testable import CoachingKit

@MainActor
final class SmileHomeViewModelTests: XCTestCase {
    /// 홈은 예약만 하지 않고 권한 상태도 읽는다. 알림이 실제로 도착할 수 있는지는
    /// 둘을 같이 봐야 알 수 있기 때문이다.
    private final class StubScheduler: ReminderScheduling {
        var status: ReminderAuthorizationStatus

        init(status: ReminderAuthorizationStatus = .authorized) {
            self.status = status
        }

        func requestAuthorization() async -> Bool { status == .authorized }
        func currentAuthorizationStatus() async -> ReminderAuthorizationStatus { status }
        func scheduleDailyPattern(groupID: String, times: [ReminderTime], messages: [ReminderMessage]) async throws {}
        func cancelGroup(id: String) {}
        func cancel(id: String) {}
    }

    private let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return value
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour, minute: minute))!
    }

    private func makeViewModel(
        now: Date,
        authorization: ReminderAuthorizationStatus = .authorized
    ) throws -> (
        SmileHomeViewModel,
        SmileMomentRepository,
        SmileReminderScheduleRepository
    ) {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let moments = SmileMomentRepository(modelContext: context)
        let schedules = SmileReminderScheduleRepository(modelContext: context)
        return (
            SmileHomeViewModel(
                momentRepository: moments,
                scheduleRepository: schedules,
                scheduler: StubScheduler(status: authorization),
                calendar: calendar,
                now: { now }
            ),
            moments,
            schedules
        )
    }

    func test_refresh_countsTodayAndRecentSevenDayTotal() async throws {
        let (viewModel, moments, _) = try makeViewModel(now: date(29, 12))
        try moments.save(guideID: "anytime-soft", source: .manual, date: date(29, 9))
        try moments.save(guideID: "anytime-soft", source: .notification, date: date(29, 11))
        try moments.save(guideID: "anytime-soft", source: .manual, date: date(27, 9))

        try await viewModel.refresh()

        XCTAssertEqual(viewModel.todayCompletionCount, 2)
        XCTAssertEqual(viewModel.recentSevenDayTotal, 3)
        XCTAssertEqual(viewModel.recentSevenDays.count, 7)
    }

    func test_refresh_findsNextOccurrenceToday() async throws {
        let (viewModel, _, schedules) = try makeViewModel(now: date(29, 10))
        try schedules.save(pattern: .recommended, isEnabled: true)

        try await viewModel.refresh()

        XCTAssertEqual(viewModel.nextReminder?.date, date(29, 12))
    }

    func test_refresh_rollsNextOccurrenceToTomorrow() async throws {
        let (viewModel, _, schedules) = try makeViewModel(now: date(29, 22))
        try schedules.save(pattern: .recommended, isEnabled: true)

        try await viewModel.refresh()

        XCTAssertEqual(viewModel.nextReminder?.date, date(30, 9))
    }

    func test_refresh_hasNoNextReminder_whenScheduleDisabledOrMissing() async throws {
        let (missing, _, _) = try makeViewModel(now: date(29, 10))
        try await missing.refresh()
        XCTAssertNil(missing.nextReminder)

        let (disabled, _, schedules) = try makeViewModel(now: date(29, 10))
        try schedules.save(pattern: .recommended, isEnabled: false)
        try await disabled.refresh()
        XCTAssertNil(disabled.nextReminder)
    }

    // MARK: - 알림이 도착할 수 있는 상태인지

    func test_refresh_reportsScheduled_whenPermissionAndScheduleAreBothReady() async throws {
        let (viewModel, _, schedules) = try makeViewModel(now: date(29, 10), authorization: .authorized)
        try schedules.save(pattern: .recommended, isEnabled: true)

        try await viewModel.refresh()

        XCTAssertEqual(viewModel.reminderDelivery, .scheduled(UpcomingReminder(date: date(29, 12))))
    }

    /// 예약은 그대로 남아 다음 시각도 계산되지만, 그 시각에 아무것도 오지 않는다.
    /// 홈이 시각만 보고 약속하면 안 되는 이유가 이 경우다.
    func test_refresh_reportsBlocked_whenPermissionIsDeniedButScheduleLooksReady() async throws {
        let (viewModel, _, schedules) = try makeViewModel(now: date(29, 10), authorization: .denied)
        try schedules.save(pattern: .recommended, isEnabled: true)

        try await viewModel.refresh()

        XCTAssertNotNil(viewModel.nextReminder)
        XCTAssertEqual(viewModel.reminderDelivery, .blockedByPermission)
    }

    func test_refresh_reportsNotRequested_whenPermissionWasNeverAsked() async throws {
        let (viewModel, _, schedules) = try makeViewModel(now: date(29, 10), authorization: .notDetermined)
        try schedules.save(pattern: .recommended, isEnabled: true)

        try await viewModel.refresh()

        XCTAssertEqual(viewModel.reminderDelivery, .permissionNotRequested)
    }

    func test_refresh_reportsOff_whenTheUserTurnedRemindersOff() async throws {
        let (viewModel, _, schedules) = try makeViewModel(now: date(29, 10), authorization: .authorized)
        try schedules.save(pattern: .recommended, isEnabled: false)

        try await viewModel.refresh()

        XCTAssertEqual(viewModel.reminderDelivery, .off)
    }
}
