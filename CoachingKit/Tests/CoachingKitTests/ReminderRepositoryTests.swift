import XCTest
import SwiftData
@testable import CoachingKit

final class ReminderRepositoryTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    func test_add_persistsReminder_withDefaults() throws {
        let repository = ReminderRepository(modelContext: try makeInMemoryContext())

        let reminder = try repository.add(hour: 9, minute: 30)

        XCTAssertEqual(reminder.hour, 9)
        XCTAssertEqual(reminder.minute, 30)
        XCTAssertTrue(reminder.isEnabled)
        XCTAssertFalse(reminder.notificationID.isEmpty)
        XCTAssertEqual(try repository.fetchAll().count, 1)
    }

    func test_fetchAll_sortsByTime() throws {
        let repository = ReminderRepository(modelContext: try makeInMemoryContext())
        try repository.add(hour: 21, minute: 0)
        try repository.add(hour: 9, minute: 30)
        try repository.add(hour: 9, minute: 0)

        let all = try repository.fetchAll()

        XCTAssertEqual(all.map { ($0.hour * 60) + $0.minute }, [540, 570, 1260])
    }

    func test_delete_removesReminder() throws {
        let repository = ReminderRepository(modelContext: try makeInMemoryContext())
        let reminder = try repository.add(hour: 9, minute: 0)

        try repository.delete(reminder)

        XCTAssertEqual(try repository.fetchAll().count, 0)
    }

    func test_registeredBuckets_mapsHoursToBuckets() throws {
        let repository = ReminderRepository(modelContext: try makeInMemoryContext())
        _ = try repository.add(hour: 8, minute: 0)   // morning
        _ = try repository.add(hour: 20, minute: 0)  // evening
        _ = try repository.add(hour: 21, minute: 30) // evening (중복 버킷)

        XCTAssertEqual(try repository.registeredBuckets(), [.morning, .evening])
    }

    func test_updateTime_changesHourAndMinute() throws {
        let repository = ReminderRepository(modelContext: try makeInMemoryContext())
        let reminder = try repository.add(hour: 9, minute: 0)

        try repository.updateTime(reminder, hour: 20, minute: 30)

        let updated = try XCTUnwrap(repository.fetchAll().first)
        XCTAssertEqual(updated.hour, 20)
        XCTAssertEqual(updated.minute, 30)
    }

    func test_setEnabled_updatesFlag() throws {
        let repository = ReminderRepository(modelContext: try makeInMemoryContext())
        let reminder = try repository.add(hour: 9, minute: 0)

        try repository.setEnabled(reminder, false)

        XCTAssertFalse(try XCTUnwrap(repository.fetchAll().first).isEnabled)
    }
}
