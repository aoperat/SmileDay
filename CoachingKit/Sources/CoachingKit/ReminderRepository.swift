import Foundation
import SwiftData

public final class ReminderRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    public func add(hour: Int, minute: Int) throws -> ReminderSetting {
        let reminder = ReminderSetting(hour: hour, minute: minute)
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

    public func delete(_ reminder: ReminderSetting) throws {
        modelContext.delete(reminder)
        try modelContext.save()
    }

    public func setEnabled(_ reminder: ReminderSetting, _ enabled: Bool) throws {
        reminder.isEnabled = enabled
        try modelContext.save()
    }
}
