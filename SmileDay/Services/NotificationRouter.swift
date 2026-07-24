import Foundation
import Observation
import CoachingKit

/// 알림 탭 신호를 뷰 계층에 전달한다. AppDelegate가 쓰고 MainTabView가 소비한다.
@MainActor
@Observable
final class NotificationRouter {
    var pendingCoaching: ReminderNotificationPayload?

    /// userInfo 파싱 실패(구버전 알림 등) 시 아무것도 하지 않는다 — 홈 유지.
    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let payload = ReminderNotificationPayload(userInfo: userInfo) else { return }
        pendingCoaching = payload
    }
}
