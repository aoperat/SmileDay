import UIKit
import UserNotifications
import CoachingKit

/// 실시간 확인 중 웃지 않는 시간이 이어질 때 사용자를 부르는 경계.
///
/// 기기를 세워두고 다른 일을 하는 상황을 가정한다. 화면만 바꾸면 못 보므로
/// 진동과 알림을 함께 쓴다. 알림 권한이 없으면 조용히 진동만 울린다.
final class LiveSmileNudgeNotifier: LiveSmileNudging {
    /// 같은 식별자를 재사용해 배너가 쌓이지 않게 한다.
    private static let notificationID = "live-smile-nudge"

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func nudge(withHaptic: Bool) {
        if withHaptic {
            // 성공·실패 알림음이 아니라 가볍게 두드리는 느낌. 평가가 아니라 신호다.
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        postNotification()
    }

    /// 세션이 끝나면 이 알림은 뜻을 잃는다. 배달된 것과 아직 처리 중인 것을 모두 거둔다.
    func clearNudges() {
        center.removeDeliveredNotifications(withIdentifiers: [Self.notificationID])
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    private func postNotification() {
        let content = UNMutableNotificationContent()
        content.title = SharedStrings.liveMonitorNudgeTitle
        content.body = SharedStrings.liveMonitorNudgeBody
        content.sound = .default
        // userInfo를 비워둔다. 이 알림을 탭해도 5초 미소 화면으로 딥링크하지 않는다 —
        // 사용자는 이미 실시간 확인 화면에 있다.
        let request = UNNotificationRequest(
            identifier: Self.notificationID,
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}
