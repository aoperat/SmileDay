import XCTest
import SwiftData
@testable import CoachingKit

@MainActor
final class ReminderMessageTests: XCTestCase {
    func test_defaults_areVariedUniqueAndNonJudgmental() {
        let messages = ReminderMessageCatalog.defaults

        XCTAssertGreaterThanOrEqual(messages.count, 6)
        XCTAssertEqual(Set(messages.map(\.id)).count, messages.count)
        XCTAssertEqual(Set(messages.map(\.text)).count, messages.count)

        let banned = ["리프팅", "젊어진", "교정", "치료", "인상 개선", "더 크게"]
        for message in messages {
            XCTAssertFalse(message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            for word in banned {
                XCTAssertFalse(message.text.contains(word), "\(message.id): \(word)")
            }
        }
    }

    func test_viewModel_addsEditsRemovesAndPersistsOrder() {
        let first = ReminderMessage(id: "first", text: "첫 번째")
        let second = ReminderMessage(id: "second", text: "두 번째")
        let store = InMemoryReminderMessageStore(messages: [first, second])
        let viewModel = ReminderMessageViewModel(store: store)

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
        )

        XCTAssertFalse(viewModel.add(text: " \n "))
        XCTAssertEqual(viewModel.error, .empty)

        XCTAssertFalse(viewModel.add(text: only.text))
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

        defaults.set(Data("broken".utf8), forKey: "reminderMessages.v1")
        XCTAssertEqual(store.messages, ReminderMessageCatalog.defaults)
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
