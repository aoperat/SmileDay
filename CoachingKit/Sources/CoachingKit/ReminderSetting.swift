import Foundation
import SwiftData

@Model
public final class ReminderSetting {
    public var hour: Int
    public var minute: Int
    public var isEnabled: Bool
    public var createdAt: Date
    public var notificationID: String

    public init(hour: Int, minute: Int, isEnabled: Bool = true, createdAt: Date = Date(), notificationID: String = UUID().uuidString) {
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.notificationID = notificationID
    }
}
