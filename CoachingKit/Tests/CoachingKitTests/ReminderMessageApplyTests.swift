import XCTest
import SwiftData
@testable import CoachingKit

/// 반복 알림은 예약 시점의 문구를 본문에 박아 기기에 남는다. 다시 예약하지 않으면 사용자가
/// 메시지 관리에서 무엇을 바꾸든 옛 문구가 계속 울린다 — 화면은 바뀌었는데 알림만 그대로다.
@MainActor
final class ReminderMessageApplyTests: XCTestCase {
    private final class MockScheduler: ReminderScheduling {
        /// 등록할 때마다 그 시점의 문구를 그대로 남긴다. 알림에 실제로 실리는 값이다.
        /// nil은 "기본 문구" — 앱 타깃이 예약 직전에 카탈로그에서 해석한다.
        private(set) var scheduledMessages: [[String?]] = []
        private(set) var cancelledGroups: [String] = []

        func requestAuthorization() async -> Bool { true }
        func currentAuthorizationStatus() async -> ReminderAuthorizationStatus { .authorized }

        func scheduleDailyPattern(groupID: String, times: [ReminderTime], messages: [ReminderMessage]) async throws {
            scheduledMessages.append(messages.map(\.text))
        }

        func cancelGroup(id: String) { cancelledGroups.append(id) }
        func cancel(id: String) {}
    }

    private func makeViewModel(
        applyDelayNanoseconds: UInt64 = 0
    ) throws -> (SmileReminderScheduleViewModel, SmileReminderScheduleRepository, MockScheduler, InMemoryReminderMessageStore) {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let repository = SmileReminderScheduleRepository(modelContext: context)
        let scheduler = MockScheduler()
        let messageStore = InMemoryReminderMessageStore(
            messages: [ReminderMessage(id: "first", text: "예전 문구")]
        )
        let viewModel = SmileReminderScheduleViewModel(
            scheduleRepository: repository,
            legacyReminderRepository: LegacyReminderRepository(modelContext: context),
            scheduler: scheduler,
            messageStore: messageStore,
            appliesChangesImmediately: true,
            applyDelayNanoseconds: applyDelayNanoseconds
        )
        return (viewModel, repository, scheduler, messageStore)
    }

    // MARK: - 문구 변경이 알림까지 도달하는가

    func test_applyMessageChange_reschedulesWithTheNewText() async throws {
        let (viewModel, _, scheduler, messageStore) = try makeViewModel()
        viewModel.updateEnabled(true)
        await viewModel.waitForPendingApply()

        messageStore.messages = [ReminderMessage(id: "first", text: "바꾼 문구")]
        viewModel.applyMessageChange()
        await viewModel.waitForPendingApply()

        XCTAssertEqual(scheduler.scheduledMessages.last, ["바꾼 문구"])
    }

    /// 옛 그룹이 남아 있으면 바꾸기 전 문구가 계속 울린다.
    func test_applyMessageChange_replacesThePreviousGroup() async throws {
        let (viewModel, _, scheduler, messageStore) = try makeViewModel()
        viewModel.updateEnabled(true)
        await viewModel.waitForPendingApply()
        let cancelledBefore = scheduler.cancelledGroups.count

        messageStore.messages = [ReminderMessage(id: "first", text: "바꾼 문구")]
        viewModel.applyMessageChange()
        await viewModel.waitForPendingApply()

        XCTAssertGreaterThan(scheduler.cancelledGroups.count, cancelledBefore)
    }

    /// 알림이 꺼져 있으면 예약된 것이 없다. 다시 등록해서 켜버리면 안 된다.
    func test_applyMessageChange_schedulesNothingWhileRemindersAreOff() async throws {
        let (viewModel, repository, scheduler, messageStore) = try makeViewModel()
        viewModel.updateEnabled(false)
        await viewModel.waitForPendingApply()
        let scheduledBefore = scheduler.scheduledMessages.count

        messageStore.messages = [ReminderMessage(id: "first", text: "바꾼 문구")]
        viewModel.applyMessageChange()
        await viewModel.waitForPendingApply()

        XCTAssertEqual(scheduler.scheduledMessages.count, scheduledBefore)
        XCTAssertEqual(try repository.fetchCurrent()?.isEnabled, false)
    }

    /// 문구를 여러 번 고쳐도 마지막 목록으로 한 번만 등록한다.
    func test_repeatedMessageEdits_collapseIntoASingleSchedule() async throws {
        let (viewModel, _, scheduler, messageStore) = try makeViewModel()
        viewModel.updateEnabled(true)
        await viewModel.waitForPendingApply()
        let scheduledBefore = scheduler.scheduledMessages.count

        for text in ["하나", "둘", "셋"] {
            messageStore.messages = [ReminderMessage(id: "first", text: text)]
            viewModel.applyMessageChange()
        }
        await viewModel.waitForPendingApply()

        XCTAssertEqual(scheduler.scheduledMessages.count, scheduledBefore + 1)
        XCTAssertEqual(scheduler.scheduledMessages.last, ["셋"])
    }

    // MARK: - 화면을 떠나기 전 반영

    /// 시간을 바꾸자마자 뒤로 나가면 지연이 끝나기 전이다. 홈이 옛 값을 읽지 않게 flush가
    /// 지연을 건너뛰고 지금 저장한다.
    func test_flushPendingApply_savesWithoutWaitingForTheDelay() async throws {
        let (viewModel, repository, _, _) = try makeViewModel(applyDelayNanoseconds: 5_000_000_000)

        viewModel.updateInterval(60)
        await viewModel.flushPendingApply()

        XCTAssertEqual(try repository.fetchCurrent()?.intervalMinutes, 60)
    }

    /// 대기 중인 변경이 없으면 아무 일도 하지 않는다 — 화면을 열었다 닫기만 해도 알림이
    /// 다시 등록되면 그때마다 예약이 갈린다.
    func test_flushPendingApply_doesNothingWithoutPendingChanges() async throws {
        let (viewModel, _, scheduler, _) = try makeViewModel()
        viewModel.updateEnabled(true)
        await viewModel.waitForPendingApply()
        let scheduledBefore = scheduler.scheduledMessages.count

        await viewModel.flushPendingApply()

        XCTAssertEqual(scheduler.scheduledMessages.count, scheduledBefore)
    }

    /// 켜기 직후 바로 나가도 권한 요청이 사라지면 안 된다.
    func test_flushPendingApply_keepsTheAuthorizationRequestOfAPendingEnable() async throws {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        final class CountingScheduler: ReminderScheduling {
            private(set) var authorizationRequests = 0
            func requestAuthorization() async -> Bool {
                authorizationRequests += 1
                return true
            }
            func currentAuthorizationStatus() async -> ReminderAuthorizationStatus { .authorized }
            func scheduleDailyPattern(groupID: String, times: [ReminderTime], messages: [ReminderMessage]) async throws {}
            func cancelGroup(id: String) {}
            func cancel(id: String) {}
        }

        let scheduler = CountingScheduler()
        let viewModel = SmileReminderScheduleViewModel(
            scheduleRepository: SmileReminderScheduleRepository(modelContext: context),
            legacyReminderRepository: LegacyReminderRepository(modelContext: context),
            scheduler: scheduler,
            messageStore: InMemoryReminderMessageStore(),
            appliesChangesImmediately: true,
            applyDelayNanoseconds: 5_000_000_000
        )

        viewModel.updateEnabled(true)
        await viewModel.flushPendingApply()

        XCTAssertEqual(scheduler.authorizationRequests, 1)
    }
}
