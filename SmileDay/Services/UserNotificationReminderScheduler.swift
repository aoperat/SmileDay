import Foundation
import UserNotifications
import UIKit
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
        // 첨부 생성이 중간에 실패하면 사본이 남는다. 예약을 새로 할 때마다 통째로 비운다.
        try? FileManager.default.removeItem(at: Self.thumbnailDirectory)
        let thumbnailData = Self.thumbnailPNGData()
        var addedIdentifiers: [String] = []
        for (index, time) in times.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "스마일데이"
            content.body = availableMessages[index % availableMessages.count].text
            content.sound = .default
            // 썸네일은 장식이다. 만들지 못해도 알림 자체는 그대로 예약한다 — 5초를 떠올리게
            // 하는 것이 알림의 일이고, 그림이 없다고 그 일을 걸러서는 안 된다.
            if let thumbnailData,
               let attachment = Self.makeThumbnail(from: thumbnailData, index: index) {
                content.attachments = [attachment]
            }
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

    // MARK: - 알림 썸네일

    private static let thumbnailDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("reminder-thumbnails", isDirectory: true)

    /// 자산 카탈로그 이미지는 `Assets.car` 안에 있어 번들에서 파일로 꺼낼 수 없다.
    /// `UIImage`로 읽어 PNG로 다시 인코딩한 뒤, 알림마다 그 데이터를 사본으로 쓴다.
    /// 인코딩은 한 번만 하고 결과를 돌려쓴다.
    private static func thumbnailPNGData() -> Data? {
        UIImage(named: "AppIconArtwork")?.pngData()
    }

    /// `UNNotificationAttachment`는 파일 URL만 받고, 시스템이 요청을 등록할 때 그 파일을
    /// 자기 저장소로 **옮긴다**. 그래서 알림 하나마다 사본이 따로 필요하다 — 같은 URL을
    /// 재사용하면 두 번째부터 원본이 이미 사라져 실패한다.
    ///
    /// 이미 예약된 알림에는 붙지 않는다. 설정을 다시 저장해 새로 예약해야 썸네일이 생긴다 —
    /// `categoryIdentifier`가 그랬던 것과 같다.
    private static func makeThumbnail(from data: Data, index: Int) -> UNNotificationAttachment? {
        do {
            try FileManager.default.createDirectory(
                at: thumbnailDirectory,
                withIntermediateDirectories: true
            )
            let url = thumbnailDirectory.appendingPathComponent("reminder-\(index).png")
            try data.write(to: url, options: .atomic)
            return try UNNotificationAttachment(
                identifier: "thumbnail-\(index)",
                url: url,
                options: nil
            )
        } catch {
            return nil
        }
    }
}
