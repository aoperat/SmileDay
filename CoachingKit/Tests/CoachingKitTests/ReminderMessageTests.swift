import XCTest
import SwiftData
@testable import CoachingKit

@MainActor
final class ReminderMessageTests: XCTestCase {
    /// 문구가 카탈로그로 옮겨간 뒤 이 테스트가 볼 수 있는 것은 id뿐이다. 금지어와 문구
    /// 중복은 `StringCatalogGuaranteeTests`가 카탈로그 JSON을 직접 읽어 검사한다.
    func test_defaults_areVariedAndUniquelyIdentified() {
        let messages = ReminderMessageCatalog.defaults

        XCTAssertGreaterThanOrEqual(messages.count, 6)
        XCTAssertEqual(Set(messages.map(\.id)).count, messages.count)

        for message in messages {
            XCTAssertFalse(message.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func test_viewModel_addsEditsRemovesAndPersistsOrder() {
        let first = ReminderMessage(id: "first", text: "첫 번째")
        let second = ReminderMessage(id: "second", text: "두 번째")
        let store = InMemoryReminderMessageStore(messages: [first, second])
        let viewModel = ReminderMessageViewModel(store: store) { $0.text ?? $0.id }

        XCTAssertTrue(viewModel.add(text: "  세 번째  "))
        let thirdID = viewModel.messages[2].id
        XCTAssertEqual(viewModel.messages[2].text, "세 번째")

        XCTAssertTrue(viewModel.update(id: second.id, text: "수정한 두 번째"))
        viewModel.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(viewModel.messages.map(\.id), [thirdID, first.id, second.id])

        XCTAssertTrue(viewModel.remove(id: first.id))
        XCTAssertEqual(store.messages, viewModel.messages)
        XCTAssertEqual(store.messages.map(\.id), [thirdID, second.id])
    }

    func test_viewModel_rejectsBlankDuplicateAndRemovingLastMessage() {
        let only = ReminderMessage(id: "only", text: "한 번 웃어볼까요?")
        let viewModel = ReminderMessageViewModel(
            store: InMemoryReminderMessageStore(messages: [only])
        ) { $0.text ?? $0.id }

        XCTAssertFalse(viewModel.add(text: " \n "))
        XCTAssertEqual(viewModel.error, .empty)

        XCTAssertFalse(viewModel.add(text: only.text ?? only.id))
        XCTAssertEqual(viewModel.error, .duplicate)

        XCTAssertFalse(viewModel.remove(id: only.id))
        XCTAssertEqual(viewModel.error, .lastRemaining)
        XCTAssertEqual(viewModel.messages, [only])
    }

    func test_userDefaultsStore_roundTripsAndFallsBackForMissingOrCorruptData() throws {
        let suiteName = "ReminderMessageTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsReminderMessageStore(defaults: defaults)

        XCTAssertEqual(store.messages, ReminderMessageCatalog.defaults)

        let custom = [
            ReminderMessage(id: "custom-1", text: "사용자 메시지"),
            ReminderMessage(id: "custom-2", text: "다음 메시지"),
        ]
        store.messages = custom
        XCTAssertEqual(UserDefaultsReminderMessageStore(defaults: defaults).messages, custom)

        defaults.set(Data("broken".utf8), forKey: "reminderMessages.v2")
        XCTAssertEqual(store.messages, ReminderMessageCatalog.defaults)
    }

    func test_defaults_haveNoInlineText() {
        for message in ReminderMessageCatalog.defaults {
            XCTAssertNil(message.text, "\(message.id) should resolve from the catalog, not carry text")
        }
    }

    func test_store_writesV2AndLeavesV1Untouched() throws {
        let suite = "ReminderMessageTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        // 옛 빌드가 남긴 v1
        let v1 = try JSONEncoder().encode([
            ReminderMessage(id: "gentle-five-seconds", text: "지금 괜찮다면 5초만 편안하게 미소 지어보세요."),
            ReminderMessage(id: "custom-1", text: "내가 쓴 문구"),
        ])
        defaults.set(v1, forKey: "reminderMessages.v1")

        let store = UserDefaultsReminderMessageStore(defaults: defaults)
        let messages = store.messages
        XCTAssertNil(messages[0].text, "untouched default is promoted")
        XCTAssertEqual(messages[1].text, "내가 쓴 문구")

        store.messages = messages
        XCTAssertNotNil(defaults.data(forKey: "reminderMessages.v2"))
        XCTAssertEqual(defaults.data(forKey: "reminderMessages.v1"), v1, "v1 must never be rewritten")
    }

    func test_duplicateCheck_usesResolvedText() {
        // 해석기가 "gentle-five-seconds"를 "A"로 푼다고 하자. 사용자가 "A"를 새로 추가하면 중복이다.
        let store = InMemoryReminderMessageStore(messages: [ReminderMessage(id: "gentle-five-seconds")])
        let viewModel = ReminderMessageViewModel(store: store) { $0.text ?? ($0.id == "gentle-five-seconds" ? "A" : $0.id) }
        XCTAssertFalse(viewModel.add(text: "A"))
        XCTAssertEqual(viewModel.error, .duplicate)
    }

    func test_update_toResolvedDefault_clearsTextBackToNil() {
        let store = InMemoryReminderMessageStore(messages: [ReminderMessage(id: "gentle-five-seconds")])
        let viewModel = ReminderMessageViewModel(store: store) { $0.text ?? "A" }
        XCTAssertTrue(viewModel.update(id: "gentle-five-seconds", text: "A"))
        XCTAssertNil(viewModel.messages[0].text, "saving the default unchanged must not freeze it")
        XCTAssertTrue(viewModel.update(id: "gentle-five-seconds", text: "B"))
        XCTAssertEqual(viewModel.messages[0].text, "B")
    }

    func test_scheduleViewModel_passesStoredMessagesToScheduler() async throws {
        final class Scheduler: ReminderScheduling {
            var receivedMessages: [ReminderMessage] = []

            func requestAuthorization() async -> Bool { true }
            func currentAuthorizationStatus() async -> ReminderAuthorizationStatus { .authorized }
            func scheduleDailyPattern(
                groupID: String,
                times: [ReminderTime],
                messages: [ReminderMessage]
            ) async throws {
                receivedMessages = messages
            }
            func cancelGroup(id: String) {}
            func cancel(id: String) {}
        }

        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let scheduler = Scheduler()
        let custom = [ReminderMessage(id: "custom", text: "내가 정한 문구")]
        let viewModel = SmileReminderScheduleViewModel(
            scheduleRepository: SmileReminderScheduleRepository(modelContext: context),
            legacyReminderRepository: LegacyReminderRepository(modelContext: context),
            scheduler: scheduler,
            messageStore: InMemoryReminderMessageStore(messages: custom)
        )

        let didSave = await viewModel.save()
        XCTAssertTrue(didSave)
        XCTAssertEqual(scheduler.receivedMessages, custom)
    }
}
