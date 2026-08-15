import XCTest
import SwiftData
@testable import CoachingKit

@MainActor
final class LocalizedReminderBackfillTests: XCTestCase {

    private final class MockScheduler: ReminderScheduling {
        enum SchedulingError: Error { case failed }

        var shouldFailScheduling = false
        private(set) var scheduled: [(groupID: String, times: [ReminderTime])] = []
        private(set) var cancelledGroups: [String] = []
        private(set) var calls: [String] = []

        func requestAuthorization() async -> Bool { true }
        func currentAuthorizationStatus() async -> ReminderAuthorizationStatus { .authorized }
        func cancel(id: String) {}
        func cancelGroup(id: String) {
            cancelledGroups.append(id)
            calls.append("cancel:\(id)")
        }
        func scheduleDailyPattern(
            groupID: String,
            times: [ReminderTime],
            messages: [ReminderMessage]
        ) async throws {
            if shouldFailScheduling { throw SchedulingError.failed }
            scheduled.append((groupID, times))
            calls.append("schedule:\(groupID)")
        }
    }

    private final class MemoryStore: LocalizedReminderBackfillStoring {
        var hasBackfilledLocalizedReminders = false
    }

    private func makeBackfill() throws -> (
        LocalizedReminderBackfill,
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
            LocalizedReminderBackfill(
                scheduleRepository: repository,
                scheduler: scheduler,
                messageStore: InMemoryReminderMessageStore(),
                store: store,
                groupIDFactory: { "localized-group" }
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

    /// 새 그룹이 완전히 등록된 뒤에만 저장값을 교체하고 옛 그룹을 지운다.
    /// 평문 알림을 들고 있던 옛 그룹은 새 키 기반 그룹이 자리 잡은 다음에야 사라진다.
    func test_runsOnce_withNewGroup_thenCancelsOld() async throws {
        let (backfill, repository, scheduler, store) = try makeBackfill()
        let schedule = try repository.save(pattern: pattern(), isEnabled: true)
        let previousGroupID = schedule.notificationGroupID

        let didRun = await backfill.runIfNeeded()

        XCTAssertTrue(didRun)
        XCTAssertEqual(scheduler.scheduled.count, 1)
        XCTAssertEqual(scheduler.scheduled.first?.groupID, "localized-group")
        XCTAssertNotEqual(scheduler.scheduled.first?.groupID, previousGroupID)
        XCTAssertEqual(scheduler.cancelledGroups, [previousGroupID])
        XCTAssertEqual(
            scheduler.calls,
            ["schedule:localized-group", "cancel:\(previousGroupID)"]
        )
        XCTAssertEqual(try repository.fetchCurrent()?.notificationGroupID, "localized-group")
        XCTAssertTrue(store.hasBackfilledLocalizedReminders)
    }

    func test_reschedulesEveryOccurrence() async throws {
        let (backfill, repository, scheduler, _) = try makeBackfill()
        _ = try repository.save(pattern: pattern(), isEnabled: true)

        await backfill.runIfNeeded()

        XCTAssertEqual(scheduler.scheduled.first?.times, try pattern().occurrences())
    }

    // MARK: - 한 번만 돈다

    func test_secondRun_doesNothing() async throws {
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
        store.hasBackfilledLocalizedReminders = true

        await backfill.runIfNeeded()

        XCTAssertTrue(scheduler.scheduled.isEmpty)
    }

    // MARK: - 다시 등록할 게 없는 경우

    /// 예약 자체가 없으면 아직 온보딩을 안 끝낸 사용자다. 표시도 남기지 않는다 —
    /// 그 사용자가 나중에 설정을 저장하면 그 경로가 이미 키 기반으로 예약한다.
    func test_doesNothing_whenNoScheduleExists() async throws {
        let (backfill, _, scheduler, store) = try makeBackfill()

        let didRun = await backfill.runIfNeeded()

        XCTAssertFalse(didRun)
        XCTAssertTrue(scheduler.scheduled.isEmpty)
        XCTAssertFalse(store.hasBackfilledLocalizedReminders)
    }

    /// 알림을 꺼둔 사용자에게 알림을 되살리면 안 된다. 갈아끼울 것도 없으니 표시만 남긴다.
    func test_whenDisabled_marksDoneWithoutScheduling() async throws {
        let (backfill, repository, scheduler, store) = try makeBackfill()
        _ = try repository.save(pattern: pattern(), isEnabled: false)

        let didRun = await backfill.runIfNeeded()

        XCTAssertFalse(didRun)
        XCTAssertTrue(scheduler.scheduled.isEmpty)
        XCTAssertTrue(scheduler.cancelledGroups.isEmpty)
        XCTAssertTrue(store.hasBackfilledLocalizedReminders, "다시 시도할 이유가 없으므로 표시는 남긴다")
    }

    // MARK: - 실패

    /// 실패했는데 표시를 남기면 그 사용자는 영어 기기에서 한국어 알림을 영영 받는다.
    func test_schedulingFailure_leavesFlagUnset_andOldGroupIntact() async throws {
        let (backfill, repository, scheduler, store) = try makeBackfill()
        let previous = try repository.save(pattern: pattern(), isEnabled: true)
        let previousGroupID = previous.notificationGroupID
        scheduler.shouldFailScheduling = true

        let didRun = await backfill.runIfNeeded()

        XCTAssertFalse(didRun)
        XCTAssertFalse(store.hasBackfilledLocalizedReminders)
        XCTAssertTrue(scheduler.cancelledGroups.isEmpty, "실패하면 기존 그룹을 취소하면 안 된다")
        XCTAssertEqual(try repository.fetchCurrent()?.notificationGroupID, previousGroupID)

        scheduler.shouldFailScheduling = false
        let retry = await backfill.runIfNeeded()

        XCTAssertTrue(retry, "다음 실행에서 다시 시도해야 한다")
    }
}
