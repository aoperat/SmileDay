import XCTest
import SwiftData
@testable import CoachingKit

@MainActor
final class SmileLibraryViewModelTests: XCTestCase {
    private final class MockScheduler: ReminderScheduling {
        private(set) var scheduled: [(id: String, hour: Int, minute: Int, guideID: String, days: Int)] = []
        private(set) var cancelled: [String] = []
        var status: ReminderAuthorizationStatus = .authorized

        func requestAuthorization() async -> Bool { true }
        func currentAuthorizationStatus() async -> ReminderAuthorizationStatus { status }
        func scheduleRollingWindow(id: String, hour: Int, minute: Int, guide: SmileGuide, days: Int) async {
            scheduled.append((id, hour, minute, guide.id, days))
        }
        func cancel(id: String) { cancelled.append(id) }
    }

    private func makeViewModel() throws -> (SmileLibraryViewModel, ReminderRepository, MockScheduler) {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let reminders = ReminderRepository(modelContext: context)
        let scheduler = MockScheduler()
        let viewModel = SmileLibraryViewModel(
            library: SmileGuideLibrary(modelContext: context, hiddenStore: InMemoryHiddenSmileGuideStore()),
            reminderRepository: reminders,
            scheduler: scheduler
        )
        return (viewModel, reminders, scheduler)
    }

    func test_refresh_listsBuiltInCards() throws {
        let (viewModel, _, _) = try makeViewModel()

        try viewModel.refresh()

        XCTAssertEqual(viewModel.guides.count, 14)
        XCTAssertTrue(viewModel.hiddenGuides.isEmpty)
    }

    func test_addCard_appearsInList() throws {
        let (viewModel, _, _) = try makeViewModel()
        try viewModel.refresh()

        try viewModel.addCard(title: "엘리베이터에서 웃기", instruction: nil, slot: .anytime)

        XCTAssertEqual(viewModel.guides.count, 15)
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_addCard_blankTitle_setsKoreanError() throws {
        let (viewModel, _, _) = try makeViewModel()
        try viewModel.refresh()

        XCTAssertThrowsError(try viewModel.addCard(title: "  ", instruction: nil, slot: .anytime))

        XCTAssertEqual(viewModel.errorMessage, "상황 이름을 적어주세요.")
        XCTAssertEqual(viewModel.guides.count, 14)
    }

    func test_addCard_clearsPreviousError() throws {
        let (viewModel, _, _) = try makeViewModel()
        try viewModel.refresh()
        XCTAssertThrowsError(try viewModel.addCard(title: " ", instruction: nil, slot: .anytime))

        try viewModel.addCard(title: "엘리베이터에서 웃기", instruction: nil, slot: .anytime)

        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - 삭제 전 안내

    func test_removalImpact_listsAffectedReminderTimes() throws {
        let (viewModel, reminders, _) = try makeViewModel()
        try reminders.add(hour: 9, minute: 0, guideID: "morning-greeting")
        try reminders.add(hour: 13, minute: 30, guideID: "morning-greeting")
        try viewModel.refresh()

        let impact = try viewModel.removalImpact(for: SmileGuideCatalog.guide(id: "morning-greeting"))

        XCTAssertEqual(impact.affectedReminderTimes, ["09:00", "13:30"])
        XCTAssertTrue(impact.isInUse)
        XCTAssertNotEqual(impact.replacement.id, "morning-greeting")
    }

    func test_removalImpact_isNotInUse_whenNoReminderPointsAtIt() throws {
        let (viewModel, _, _) = try makeViewModel()
        try viewModel.refresh()

        let impact = try viewModel.removalImpact(for: SmileGuideCatalog.guide(id: "morning-greeting"))

        XCTAssertFalse(impact.isInUse)
        XCTAssertTrue(impact.affectedReminderTimes.isEmpty)
    }

    func test_removalImpact_replacementSharesSlot() throws {
        let (viewModel, _, _) = try makeViewModel()
        try viewModel.refresh()

        let impact = try viewModel.removalImpact(for: SmileGuideCatalog.guide(id: "morning-greeting"))

        XCTAssertEqual(impact.replacement.slot, .morning)
    }

    // MARK: - 삭제

    func test_remove_builtIn_hidesIt() async throws {
        let (viewModel, _, _) = try makeViewModel()
        try viewModel.refresh()

        try await viewModel.remove(SmileGuideCatalog.guide(id: "morning-coffee"))

        XCTAssertEqual(viewModel.guides.count, 13)
        XCTAssertEqual(viewModel.hiddenGuides.map(\.id), ["morning-coffee"])
    }

    func test_remove_custom_deletesIt() async throws {
        let (viewModel, _, _) = try makeViewModel()
        try viewModel.refresh()
        try viewModel.addCard(title: "엘리베이터에서 웃기", instruction: nil, slot: .anytime)
        let added = try XCTUnwrap(viewModel.guides.first { !$0.isBuiltIn })

        try await viewModel.remove(added)

        XCTAssertEqual(viewModel.guides.count, 14)
        XCTAssertTrue(viewModel.hiddenGuides.isEmpty, "내 카드는 숨김 목록에 들어가지 않는다")
    }

    func test_remove_reassignsAffectedRemindersAndReschedules() async throws {
        let (viewModel, reminders, scheduler) = try makeViewModel()
        try reminders.add(hour: 9, minute: 0, guideID: "morning-greeting")
        try viewModel.refresh()
        let target = SmileGuideCatalog.guide(id: "morning-greeting")
        let replacement = try viewModel.removalImpact(for: target).replacement

        try await viewModel.remove(target)

        let reminder = try XCTUnwrap(reminders.fetchAll().first)
        XCTAssertEqual(reminder.guideID, replacement.id)
        XCTAssertEqual(scheduler.scheduled.count, 1)
        XCTAssertEqual(scheduler.scheduled.first?.guideID, replacement.id)
        XCTAssertEqual(scheduler.scheduled.first?.days, reminderRollingWindowDays)
    }

    /// 예약된 14일치가 사라진 카드의 문구를 그대로 들고 나가면 안 된다.
    func test_remove_reschedulesEveryAffectedReminder() async throws {
        let (viewModel, reminders, scheduler) = try makeViewModel()
        try reminders.add(hour: 9, minute: 0, guideID: "morning-greeting")
        try reminders.add(hour: 10, minute: 0, guideID: "morning-greeting")
        try viewModel.refresh()

        try await viewModel.remove(SmileGuideCatalog.guide(id: "morning-greeting"))

        XCTAssertEqual(scheduler.scheduled.count, 2)
    }

    func test_remove_doesNotRescheduleDisabledReminders() async throws {
        let (viewModel, reminders, scheduler) = try makeViewModel()
        let reminder = try reminders.add(hour: 9, minute: 0, guideID: "morning-greeting")
        try reminders.setEnabled(reminder, false)
        try viewModel.refresh()

        try await viewModel.remove(SmileGuideCatalog.guide(id: "morning-greeting"))

        XCTAssertTrue(scheduler.scheduled.isEmpty)
        XCTAssertNotEqual(reminder.guideID, "morning-greeting", "꺼져 있어도 카드는 바뀌어야 한다")
    }

    func test_remove_leavesUnrelatedRemindersAlone() async throws {
        let (viewModel, reminders, scheduler) = try makeViewModel()
        try reminders.add(hour: 18, minute: 0, guideID: "evening-after-work")
        try viewModel.refresh()

        try await viewModel.remove(SmileGuideCatalog.guide(id: "morning-greeting"))

        XCTAssertEqual(try reminders.fetchAll().first?.guideID, "evening-after-work")
        XCTAssertTrue(scheduler.scheduled.isEmpty)
    }

    /// 지운 카드로 예약돼 있던 커스텀 카드도 대체되어야 한다.
    func test_remove_custom_reassignsItsReminders() async throws {
        let (viewModel, reminders, scheduler) = try makeViewModel()
        try viewModel.refresh()
        try viewModel.addCard(title: "엘리베이터에서 웃기", instruction: nil, slot: .anytime)
        let mine = try XCTUnwrap(viewModel.guides.first { !$0.isBuiltIn })
        try reminders.add(hour: 15, minute: 0, guideID: mine.id)

        try await viewModel.remove(mine)

        let reminder = try XCTUnwrap(reminders.fetchAll().first)
        XCTAssertNotEqual(reminder.guideID, mine.id)
        XCTAssertEqual(scheduler.scheduled.first?.guideID, reminder.guideID)
    }

    func test_restore_bringsHiddenCardBack() async throws {
        let (viewModel, _, _) = try makeViewModel()
        try viewModel.refresh()
        try await viewModel.remove(SmileGuideCatalog.guide(id: "morning-coffee"))

        try viewModel.restore(SmileGuideCatalog.guide(id: "morning-coffee"))

        XCTAssertEqual(viewModel.guides.count, 14)
        XCTAssertTrue(viewModel.hiddenGuides.isEmpty)
    }

    /// 숨겼다 되돌려도 목록 순서가 흐트러지지 않는다.
    func test_restore_keepsListOrder() async throws {
        let (viewModel, _, _) = try makeViewModel()
        try viewModel.refresh()
        let originalOrder = viewModel.guides.map(\.id)

        try await viewModel.remove(SmileGuideCatalog.guide(id: "morning-coffee"))
        try viewModel.restore(SmileGuideCatalog.guide(id: "morning-coffee"))

        XCTAssertEqual(viewModel.guides.map(\.id), originalOrder)
    }
}
