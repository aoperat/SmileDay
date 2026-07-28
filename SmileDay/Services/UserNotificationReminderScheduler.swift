import Foundation
import UserNotifications
import CoachingKit

final class UserNotificationReminderScheduler: ReminderScheduling {
    private let center: UNUserNotificationCenter
    private let calendar: Calendar
    private let now: () -> Date

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.center = center
        self.calendar = calendar
        self.now = now
    }

    /// 거부되어도 throw하지 않는다. 화면이 상태를 보고 안내를 띄운다.
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func currentAuthorizationStatus() async -> ReminderAuthorizationStatus {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default: return .authorized
        }
    }

    func scheduleRollingWindow(id: String, hour: Int, minute: Int, guideID: String, days: Int) async {
        cancel(id: id)

        // 사라진 ID여도 빈 알림이 나가지 않게 카탈로그가 기본 가이드로 대체한다.
        let guide = SmileGuideCatalog.guide(id: guideID)
        let today = calendar.startOfDay(for: now())

        for dayOffset in 0..<days {
            guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: targetDay)
            components.hour = hour
            components.minute = minute

            let content = UNMutableNotificationContent()
            content.title = guide.title
            content.body = guide.notificationText
            content.sound = .default
            content.userInfo = ReminderNotificationPayload(reminderID: id, guideID: guide.id).userInfo

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            // 취소가 같은 규칙으로 identifier를 만들어 지운다 — 형식을 바꾸면 재예약이 쌓인다.
            let request = UNNotificationRequest(identifier: "\(id)-\(dayOffset)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func cancel(id: String) {
        let identifiers = (0..<reminderRollingWindowDays).map { "\(id)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
