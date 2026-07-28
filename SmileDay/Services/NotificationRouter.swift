import Foundation
import Observation
import CoachingKit

/// 알림 탭 신호를 뷰 계층에 전달한다. AppDelegate가 쓰고 홈 화면이 소비한다.
@MainActor
@Observable
final class NotificationRouter {
    /// 열어야 할 미소 가이드. 홈이 읽고 나면 nil로 되돌린다.
    var pendingSmileGuide: ReminderNotificationPayload?

    /// 열 수 없는 userInfo(가이드 정보가 없는 옛 알림 등)면 아무것도 하지 않는다 — 홈 유지.
    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let payload = ReminderNotificationPayload(userInfo: userInfo) else { return }
        pendingSmileGuide = payload
    }
}
