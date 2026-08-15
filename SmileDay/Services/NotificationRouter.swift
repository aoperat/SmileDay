import Foundation
import Observation
import CoachingKit

/// 알림 탭 신호를 뷰 계층에 전달한다. AppDelegate가 쓰고 홈 화면이 소비한다.
@MainActor
@Observable
final class NotificationRouter {
    /// 열어야 할 미소 가이드. 홈이 읽고 나면 nil로 되돌린다.
    var pendingSmileGuide: ReminderNotificationPayload?

    /// 알림의 "웃었어요"로 가이드 없이 기록될 때마다 오른다. 홈이 이 변화를 보고 다시 읽는다.
    ///
    /// 홈은 원래 `scenePhase`가 active로 돌아올 때 새로 읽는데, 앱이 이미 떠 있는 채로 배너에서
    /// 누르면 그 전환이 일어나지 않아 오늘 횟수가 옛 값에 머문다. 값 자체는 의미가 없고
    /// 변화만 신호로 쓴다 — 화면에 이 숫자를 보여주면 안 된다.
    private(set) var recordedWithoutGuideCount = 0

    /// 열 수 없는 userInfo(가이드 정보가 없는 옛 알림 등)면 아무것도 하지 않는다 — 홈 유지.
    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let payload = ReminderNotificationPayload(userInfo: userInfo) else { return }
        pendingSmileGuide = payload
    }

    /// 저장이 끝난 뒤 `AppDelegate`가 부른다.
    func noteRecordedWithoutGuide() {
        recordedWithoutGuideCount += 1
    }
}
