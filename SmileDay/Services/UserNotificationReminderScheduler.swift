import Foundation
import UserNotifications
import CoachingKit

final class UserNotificationReminderScheduler: ReminderScheduling {
    private let center: UNUserNotificationCenter

    /// 예약이 매일 반복 트리거라 날짜를 직접 계산하지 않는다 — 달력도 현재 시각도 필요 없다.
    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
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

    /// 예전 버전이 하루에 하나씩 미리 예약해둔 알림을 지운다.
    ///
    /// 그때와 같은 규칙으로 identifier를 만들어야 지워진다 — 형식을 바꾸면 옛 알림이 계속 울린다.
    func cancel(id: String) {
        let identifiers = (0..<reminderRollingWindowDays).map { "\(id)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func scheduleDailyPattern(
        groupID: String,
        times: [ReminderTime],
        messages: [ReminderMessage]
    ) async throws {
        let availableMessages = messages.isEmpty ? ReminderMessageCatalog.defaults : messages
        var addedIdentifiers: [String] = []
        for (index, time) in times.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "스마일데이"
            content.body = availableMessages[index % availableMessages.count].text
            content.sound = .default
            // 잠금화면에서 알림을 길게 눌렀을 때 "웃었어요" 버튼이 나오게 하는 값.
            // 이 값이 없는 채로 이미 예약된 알림은 버튼 없이 그대로 울린다 — 설정을 다시
            // 저장하면 새 값으로 바뀐다.
            content.categoryIdentifier = ReminderNotificationCategory.identifier
            content.userInfo = ReminderNotificationPayload(
                reminderID: groupID,
                guideID: SmileGuideCatalog.default.id
            ).userInfo

            var components = DateComponents()
            components.hour = time.hour
            components.minute = time.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let identifier = dailyIdentifier(groupID: groupID, time: time)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            do {
                try await center.add(request)
                addedIdentifiers.append(identifier)
            } catch {
                center.removePendingNotificationRequests(withIdentifiers: addedIdentifiers)
                throw error
            }
        }
    }

    func cancelGroup(id: String) {
        let identifiers = (0..<24).flatMap { hour in
            (0..<60).map { minute in
                "\(id)-daily-\(String(format: "%02d", hour))\(String(format: "%02d", minute))"
            }
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func dailyIdentifier(groupID: String, time: ReminderTime) -> String {
        "\(groupID)-daily-\(String(format: "%02d", time.hour))\(String(format: "%02d", time.minute))"
    }
}
