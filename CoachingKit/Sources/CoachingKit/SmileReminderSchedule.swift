import Foundation
import SwiftData

@Model
public final class SmileReminderSchedule {
    public var startHour: Int = 9
    public var startMinute: Int = 0
    public var endHour: Int = 21
    public var endMinute: Int = 0
    public var intervalMinutes: Int = 180
    public var isEnabled: Bool = true
    public var notificationGroupID: String = UUID().uuidString
    public var updatedAt: Date = Date()

    public init(
        pattern: SmileReminderPattern,
        isEnabled: Bool = true,
        notificationGroupID: String = UUID().uuidString,
        updatedAt: Date = Date()
    ) {
        startHour = pattern.startTime.hour
        startMinute = pattern.startTime.minute
        endHour = pattern.endTime.hour
        endMinute = pattern.endTime.minute
        intervalMinutes = pattern.intervalMinutes
        self.isEnabled = isEnabled
        self.notificationGroupID = notificationGroupID
        self.updatedAt = updatedAt
    }

    public var pattern: SmileReminderPattern? {
        guard let start = try? ReminderTime(hour: startHour, minute: startMinute),
              let end = try? ReminderTime(hour: endHour, minute: endMinute) else {
            return nil
        }
        return try? SmileReminderPattern(
            startTime: start,
            endTime: end,
            intervalMinutes: intervalMinutes
        )
    }
}
