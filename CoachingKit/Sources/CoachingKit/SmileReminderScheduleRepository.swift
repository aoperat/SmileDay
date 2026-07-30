import Foundation
import SwiftData

public final class SmileReminderScheduleRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchCurrent() throws -> SmileReminderSchedule? {
        var descriptor = FetchDescriptor<SmileReminderSchedule>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    public func save(
        pattern: SmileReminderPattern,
        isEnabled: Bool,
        notificationGroupID: String? = nil,
        now: Date = Date()
    ) throws -> SmileReminderSchedule {
        if let current = try fetchCurrent() {
            current.startHour = pattern.startTime.hour
            current.startMinute = pattern.startTime.minute
            current.endHour = pattern.endTime.hour
            current.endMinute = pattern.endTime.minute
            current.intervalMinutes = pattern.intervalMinutes
            current.isEnabled = isEnabled
            if let notificationGroupID {
                current.notificationGroupID = notificationGroupID
            }
            current.updatedAt = now
            try modelContext.save()
            return current
        }

        let schedule = SmileReminderSchedule(
            pattern: pattern,
            isEnabled: isEnabled,
            notificationGroupID: notificationGroupID ?? UUID().uuidString,
            updatedAt: now
        )
        modelContext.insert(schedule)
        try modelContext.save()
        return schedule
    }
}
