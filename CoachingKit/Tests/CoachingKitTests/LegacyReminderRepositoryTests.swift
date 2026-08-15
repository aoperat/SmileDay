import XCTest
import SwiftData
@testable import CoachingKit

/// 새 반복 스케줄로 넘어간 뒤에도 예전 개별 알림을 정확히 끌 수 있어야 한다.
final class LegacyReminderRepositoryTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [configuration]))
    }

    func test_pendingNotificationIDs_returnsEveryStoredID_inTimeOrder() throws {
        let context = try makeContext()
        context.insert(ReminderSetting(hour: 21, minute: 0, notificationID: "evening"))
        context.insert(ReminderSetting(hour: 9, minute: 30, notificationID: "late-morning"))
        context.insert(ReminderSetting(hour: 9, minute: 0, notificationID: "morning"))
        try context.save()

        let ids = try LegacyReminderRepository(modelContext: context).pendingNotificationIDs()

        XCTAssertEqual(ids, ["morning", "late-morning", "evening"])
    }

    /// 꺼둔 알림도 예약이 남아 있을 수 있어 취소 대상에서 빠지면 안 된다.
    func test_pendingNotificationIDs_includesDisabledReminders() throws {
        let context = try makeContext()
        context.insert(ReminderSetting(hour: 9, minute: 0, isEnabled: false, notificationID: "disabled"))
        try context.save()

        XCTAssertEqual(try LegacyReminderRepository(modelContext: context).pendingNotificationIDs(), ["disabled"])
    }

    func test_pendingNotificationIDs_isEmpty_whenNoLegacyReminders() throws {
        XCTAssertTrue(try LegacyReminderRepository(modelContext: try makeContext()).pendingNotificationIDs().isEmpty)
    }
}
