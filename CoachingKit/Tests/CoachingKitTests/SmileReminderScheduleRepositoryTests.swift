import XCTest
import SwiftData
@testable import CoachingKit

final class SmileReminderScheduleRepositoryTests: XCTestCase {
    private func makeRepository() throws -> SmileReminderScheduleRepository {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return SmileReminderScheduleRepository(modelContext: ModelContext(container))
    }

    func test_saveAndFetch_roundTripsPattern() throws {
        let repository = try makeRepository()

        let saved = try repository.save(pattern: .recommended, isEnabled: true)
        let fetched = try repository.fetchCurrent()

        XCTAssertEqual(fetched?.pattern, .recommended)
        XCTAssertTrue(fetched?.isEnabled == true)
        XCTAssertEqual(fetched?.notificationGroupID, saved.notificationGroupID)
    }

    func test_save_updatesSameRecordAndKeepsGroupID() throws {
        let repository = try makeRepository()
        let first = try repository.save(pattern: .recommended, isEnabled: true)
        let changed = try SmileReminderPattern(
            startTime: ReminderTime(hour: 8, minute: 0),
            endTime: ReminderTime(hour: 20, minute: 0),
            intervalMinutes: 240
        )

        let second = try repository.save(pattern: changed, isEnabled: false)

        XCTAssertEqual(second.notificationGroupID, first.notificationGroupID)
        XCTAssertEqual(try repository.fetchCurrent()?.pattern, changed)
        XCTAssertFalse(second.isEnabled)
    }

    func test_save_replacesGroupID_whenNewScheduledGroupIsProvided() throws {
        let repository = try makeRepository()
        try repository.save(
            pattern: .recommended,
            isEnabled: true,
            notificationGroupID: "old-group"
        )

        let updated = try repository.save(
            pattern: .recommended,
            isEnabled: true,
            notificationGroupID: "new-group"
        )

        XCTAssertEqual(updated.notificationGroupID, "new-group")
        XCTAssertEqual(try repository.fetchCurrent()?.notificationGroupID, "new-group")
    }
}
