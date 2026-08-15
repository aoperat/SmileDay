import XCTest
import SwiftData
@testable import CoachingKit

/// 설정 화면은 바꾸는 즉시 반영한다. 온보딩은 그러면 안 된다 — 같은 뷰모델을 쓰기 때문에
/// 이 구분이 무너지면 시간을 고르는 도중에 알림이 예약되고 권한 대화상자가 뜬다.
@MainActor
final class ScheduleImmediateApplyTests: XCTestCase {
    private final class MockScheduler: ReminderScheduling {
        var status: ReminderAuthorizationStatus = .authorized
        private(set) var authorizationRequests = 0
        private(set) var scheduledGroups: [String] = []
        private(set) var cancelledGroups: [String] = []

        func requestAuthorization() async -> Bool {
            authorizationRequests += 1
            return status == .authorized
        }

        func currentAuthorizationStatus() async -> ReminderAuthorizationStatus { status }

        func scheduleDailyPattern(groupID: String, times: [ReminderTime], messages: [ReminderMessage]) async throws {
            scheduledGroups.append(groupID)
        }

        func cancelGroup(id: String) { cancelledGroups.append(id) }
        func cancel(id: String) {}
    }

    private func makeViewModel(
        appliesChangesImmediately: Bool
    ) throws -> (SmileReminderScheduleViewModel, SmileReminderScheduleRepository, MockScheduler) {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let repository = SmileReminderScheduleRepository(modelContext: context)
        let scheduler = MockScheduler()
        let viewModel = SmileReminderScheduleViewModel(
            scheduleRepository: repository,
            legacyReminderRepository: LegacyReminderRepository(modelContext: context),
            scheduler: scheduler,
            messageStore: InMemoryReminderMessageStore(),
            appliesChangesImmediately: appliesChangesImmediately,
            applyDelayNanoseconds: 0
        )
        return (viewModel, repository, scheduler)
    }

    // MARK: - 설정 화면

    func test_updateInterval_savesWithoutASaveButton() async throws {
        let (viewModel, repository, _) = try makeViewModel(appliesChangesImmediately: true)

        viewModel.updateInterval(60)
        await viewModel.waitForPendingApply()

        XCTAssertEqual(try repository.fetchCurrent()?.intervalMinutes, 60)
    }

    func test_updateEnabledOff_cancelsTheGroupAndPersistsIt() async throws {
        let (viewModel, repository, scheduler) = try makeViewModel(appliesChangesImmediately: true)
        viewModel.updateEnabled(true)
        await viewModel.waitForPendingApply()

        viewModel.updateEnabled(false)
        await viewModel.waitForPendingApply()

        XCTAssertEqual(try repository.fetchCurrent()?.isEnabled, false)
        XCTAssertFalse(scheduler.cancelledGroups.isEmpty)
    }

    /// 시간만 바꿨는데 권한 대화상자가 뜨면 안 된다. 켤 때만 묻는다.
    func test_timeAndIntervalChanges_neverRequestAuthorization() async throws {
        let (viewModel, _, scheduler) = try makeViewModel(appliesChangesImmediately: true)

        viewModel.updateStart(hour: 8, minute: 0)
        await viewModel.waitForPendingApply()
        viewModel.updateEnd(hour: 20, minute: 0)
        await viewModel.waitForPendingApply()
        viewModel.updateInterval(120)
        await viewModel.waitForPendingApply()

        XCTAssertEqual(scheduler.authorizationRequests, 0)
    }

    func test_turningOn_requestsAuthorizationOnce() async throws {
        let (viewModel, _, scheduler) = try makeViewModel(appliesChangesImmediately: true)

        viewModel.updateEnabled(true)
        await viewModel.waitForPendingApply()

        XCTAssertEqual(scheduler.authorizationRequests, 1)
    }

    /// 다이얼을 굴리는 동안 값이 계속 바뀐다. 마지막 값으로 한 번만 저장돼야 한다.
    func test_rapidChanges_collapseIntoASingleSchedule() async throws {
        let (viewModel, repository, scheduler) = try makeViewModel(appliesChangesImmediately: true)
        viewModel.updateEnabled(true)
        await viewModel.waitForPendingApply()
        let groupsAfterEnabling = scheduler.scheduledGroups.count

        viewModel.updateInterval(60)
        viewModel.updateInterval(120)
        viewModel.updateInterval(240)
        await viewModel.waitForPendingApply()

        XCTAssertEqual(scheduler.scheduledGroups.count, groupsAfterEnabling + 1, "중간 값마다 알림을 다시 등록했다")
        XCTAssertEqual(try repository.fetchCurrent()?.intervalMinutes, 240)
    }

    /// 시작과 끝이 같으면 저장하지 않고 안내만 남긴다. 끝이 더 이른 것은 이제 자정을
    /// 넘는 창이라 유효하다.
    func test_invalidRange_doesNotPersist() async throws {
        let (viewModel, repository, _) = try makeViewModel(appliesChangesImmediately: true)
        viewModel.updateStart(hour: 21, minute: 0)
        await viewModel.waitForPendingApply()

        viewModel.updateEnd(hour: 21, minute: 0)
        await viewModel.waitForPendingApply()

        XCTAssertFalse(viewModel.isPatternValid)
        XCTAssertNil(viewModel.error)
        XCTAssertNotEqual(try repository.fetchCurrent()?.endHour, 21)
    }

    /// 밤에 일하는 사람의 창이다. 예전에는 이 조합이 오류였다.
    func test_windowCrossingMidnight_persists() async throws {
        let (viewModel, repository, _) = try makeViewModel(appliesChangesImmediately: true)
        viewModel.updateStart(hour: 22, minute: 0)
        await viewModel.waitForPendingApply()

        viewModel.updateEnd(hour: 2, minute: 0)
        await viewModel.waitForPendingApply()

        XCTAssertNil(viewModel.error)
        XCTAssertEqual(try repository.fetchCurrent()?.startHour, 22)
        XCTAssertEqual(try repository.fetchCurrent()?.endHour, 2)
    }

    // MARK: - 온보딩

    /// 온보딩은 "시작하기"를 누르기 전까지 아무것도 예약하지 않는다.
    func test_onboarding_changesNothingUntilItIsConfirmed() async throws {
        let (viewModel, repository, scheduler) = try makeViewModel(appliesChangesImmediately: false)

        viewModel.updateEnabled(true)
        viewModel.updateInterval(60)
        viewModel.updateStart(hour: 8, minute: 0)
        await viewModel.waitForPendingApply()

        XCTAssertNil(try repository.fetchCurrent())
        XCTAssertTrue(scheduler.scheduledGroups.isEmpty)
        XCTAssertEqual(scheduler.authorizationRequests, 0)
    }
}
