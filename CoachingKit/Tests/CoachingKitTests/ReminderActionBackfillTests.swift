import XCTest
import SwiftData
@testable import CoachingKit

@MainActor
final class ReminderActionBackfillTests: XCTestCase {

    private final class MockScheduler: ReminderScheduling {
        enum SchedulingError: Error { case failed }

        var shouldFailScheduling = false
        private(set) var scheduled: [(groupID: String, times: [ReminderTime])] = []
        private(set) var cancelledGroups: [String] = []

        func requestAuthorization() async -> Bool { true }
        func currentAuthorizationStatus() async -> ReminderAuthorizationStatus { .authorized }
        func cancel(id: String) {}
        func cancelGroup(id: String) { cancelledGroups.append(id) }
        func scheduleDailyPattern(
            groupID: String,
            times: [ReminderTime],
            messages: [ReminderMessage]
        ) async throws {
            if shouldFailScheduling { throw SchedulingError.failed }
            scheduled.append((groupID, times))
        }
    }

    private final class MemoryStore: ReminderActionBackfillStoring {
        var hasBackfilledReminderActions = false
    }

    private func makeBackfill() throws -> (
        ReminderActionBackfill,
        SmileReminderScheduleRepository,
        MockScheduler,
        MemoryStore
    ) {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let repository = SmileReminderScheduleRepository(modelContext: ModelContext(container))
        let scheduler = MockScheduler()
        let store = MemoryStore()
        return (
            ReminderActionBackfill(
                scheduleRepository: repository,
                scheduler: scheduler,
                messageStore: InMemoryReminderMessageStore(),
                store: store
            ),
            repository,
            scheduler,
            store
        )
    }

    private func pattern() throws -> SmileReminderPattern {
        try SmileReminderPattern(
            startTime: ReminderTime(hour: 9, minute: 0),
            endTime: ReminderTime(hour: 21, minute: 0),
            intervalMinutes: 180
        )
    }

    // MARK: - 다시 등록해야 하는 경우

    /// 핵심: 예약된 그룹을 **같은 ID로** 다시 등록해야 알림이 덮어써진다.
    /// 새 ID로 만들면 옛 알림이 그대로 남아 하루에 두 번 울린다.
    func test_reschedulesIntoTheSameGroup() async throws {
        let (backfill, repository, scheduler, _) = try makeBackfill()
        let schedule = try repository.save(pattern: pattern(), isEnabled: true)
        let groupID = schedule.notificationGroupID

        let didRun = await backfill.runIfNeeded()

        XCTAssertTrue(didRun)
        XCTAssertEqual(scheduler.scheduled.count, 1)
        XCTAssertEqual(scheduler.scheduled.first?.groupID, groupID)
    }

    /// 덮어쓰기라서 지울 그룹이 없다. 취소를 부르면 그 순간 알림이 비는 구간이 생긴다.
    func test_cancelsNothing() async throws {
        let (backfill, repository, scheduler, _) = try makeBackfill()
        _ = try repository.save(pattern: pattern(), isEnabled: true)

        await backfill.runIfNeeded()

        XCTAssertTrue(scheduler.cancelledGroups.isEmpty)
    }

    func test_reschedulesEveryOccurrence() async throws {
        let (backfill, repository, scheduler, _) = try makeBackfill()
        _ = try repository.save(pattern: pattern(), isEnabled: true)

        await backfill.runIfNeeded()

        XCTAssertEqual(scheduler.scheduled.first?.times, try pattern().occurrences())
    }

    // MARK: - 한 번만 돈다

    func test_doesNotRunTwice() async throws {
        let (backfill, repository, scheduler, _) = try makeBackfill()
        _ = try repository.save(pattern: pattern(), isEnabled: true)

        await backfill.runIfNeeded()
        let secondRun = await backfill.runIfNeeded()

        XCTAssertFalse(secondRun)
        XCTAssertEqual(scheduler.scheduled.count, 1, "매 실행마다 다시 예약하면 안 된다")
    }

    func test_skipsWhenAlreadyMarked() async throws {
        let (backfill, repository, scheduler, store) = try makeBackfill()
        _ = try repository.save(pattern: pattern(), isEnabled: true)
        store.hasBackfilledReminderActions = true

        await backfill.runIfNeeded()

        XCTAssertTrue(scheduler.scheduled.isEmpty)
    }

    // MARK: - 다시 등록할 게 없는 경우

    /// 예약 자체가 없으면 아직 온보딩을 안 끝낸 사용자다. 표시도 남기지 않는다 —
    /// 그 사용자가 나중에 설정을 저장하면 그 경로가 이미 새 카테고리를 붙인다.
    func test_doesNothing_whenNoScheduleExists() async throws {
        let (backfill, _, scheduler, store) = try makeBackfill()

        let didRun = await backfill.runIfNeeded()

        XCTAssertFalse(didRun)
        XCTAssertTrue(scheduler.scheduled.isEmpty)
        XCTAssertFalse(store.hasBackfilledReminderActions)
    }

    /// 알림을 꺼둔 사용자에게 알림을 되살리면 안 된다.
    func test_doesNotScheduleWhenRemindersAreOff() async throws {
        let (backfill, repository, scheduler, store) = try makeBackfill()
        _ = try repository.save(pattern: pattern(), isEnabled: false)

        await backfill.runIfNeeded()

        XCTAssertTrue(scheduler.scheduled.isEmpty)
        XCTAssertTrue(store.hasBackfilledReminderActions, "다시 시도할 이유가 없으므로 표시는 남긴다")
    }

    // MARK: - 실패

    /// 실패했는데 표시를 남기면 그 사용자는 버튼을 영영 못 받는다.
    func test_retriesOnNextLaunch_whenSchedulingFails() async throws {
        let (backfill, repository, scheduler, store) = try makeBackfill()
        _ = try repository.save(pattern: pattern(), isEnabled: true)
        scheduler.shouldFailScheduling = true

        let didRun = await backfill.runIfNeeded()

        XCTAssertFalse(didRun)
        XCTAssertFalse(store.hasBackfilledReminderActions)

        scheduler.shouldFailScheduling = false
        let retry = await backfill.runIfNeeded()

        XCTAssertTrue(retry, "다음 실행에서 다시 시도해야 한다")
    }
}
