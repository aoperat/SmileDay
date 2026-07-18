import Foundation

public protocol ReminderScheduling: AnyObject {
    func requestAuthorization() async -> Bool
    func scheduleDaily(id: String, hour: Int, minute: Int) async
    func cancel(id: String)
}
