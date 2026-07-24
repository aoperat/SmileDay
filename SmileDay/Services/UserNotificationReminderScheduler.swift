import Foundation
import UserNotifications
import CoachingKit

final class UserNotificationReminderScheduler: ReminderScheduling {
    private let center: UNUserNotificationCenter
    private let promptSelector: ReminderPromptSelector
    private let calendar: Calendar
    private let now: () -> Date

    init(
        center: UNUserNotificationCenter = .current(),
        promptSelector: ReminderPromptSelector = ReminderPromptSelector(cursorStore: UserDefaultsReminderPromptCursorStore()),
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.center = center
        self.promptSelector = promptSelector
        self.calendar = calendar
        self.now = now
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func scheduleRollingWindow(id: String, hour: Int, minute: Int, days: Int) async {
        cancel(id: id)

        let today = calendar.startOfDay(for: now())
        for dayOffset in 0..<days {
            guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: targetDay)
            components.hour = hour
            components.minute = minute

            let prompt = promptSelector.nextPrompt(forHour: hour)
            let content = UNMutableNotificationContent()
            content.title = "스마일데이"
            content.body = prompt.text
            content.sound = .default
            content.userInfo = ReminderNotificationPayload(bucket: TimeBucket(hour: hour), promptText: prompt.text).userInfo

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "\(id)-\(dayOffset)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func cancel(id: String) {
        let identifiers = (0..<reminderRollingWindowDays).map { "\(id)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
