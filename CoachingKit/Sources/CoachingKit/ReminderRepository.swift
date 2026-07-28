import Foundation
import SwiftData

public final class ReminderRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    public func add(hour: Int, minute: Int, guideID: String? = nil) throws -> ReminderSetting {
        let reminder = ReminderSetting(hour: hour, minute: minute, guideID: guideID)
        modelContext.insert(reminder)
        try modelContext.save()
        return reminder
    }

    public func fetchAll() throws -> [ReminderSetting] {
        let descriptor = FetchDescriptor<ReminderSetting>(
            sortBy: [SortDescriptor(\.hour), SortDescriptor(\.minute)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// 등록된 리마인더들이 커버하는 시간대 집합.
    public func registeredBuckets() throws -> Set<TimeBucket> {
        Set(try fetchAll().map { TimeBucket(hour: $0.hour) })
    }

    public func delete(_ reminder: ReminderSetting) throws {
        modelContext.delete(reminder)
        try modelContext.save()
    }

    public func setEnabled(_ reminder: ReminderSetting, _ enabled: Bool) throws {
        reminder.isEnabled = enabled
        try modelContext.save()
    }

    public func updateTime(_ reminder: ReminderSetting, hour: Int, minute: Int) throws {
        reminder.hour = hour
        reminder.minute = minute
        try modelContext.save()
    }

    public func updateGuide(_ reminder: ReminderSetting, guideID: String) throws {
        reminder.guideID = guideID
        try modelContext.save()
    }
}
