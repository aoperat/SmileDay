import Foundation

/// 리마인더 알림이 며칠치를 미리 예약해둘지. 로컬 알림만 쓰므로(서버 푸시 없음)
/// 사용자가 이 기간보다 오래 앱을 열지 않으면 그 이후 알림은 끊긴다.
public let reminderRollingWindowDays = 14

/// 알림 권한 상태. UserDefaults로 추정하지 않고 시스템에 매번 물어본다.
public enum ReminderAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

public protocol ReminderScheduling: AnyObject {
    /// 거부되어도 throw하지 않는다. 호출자가 상태를 보고 안내 문구를 정한다.
    func requestAuthorization() async -> Bool
    func currentAuthorizationStatus() async -> ReminderAuthorizationStatus
    /// hour:minute에 향후 `days`일치 알림을 예약한다. 문구와 딥링크는 `guideID`가 정한다.
    func scheduleRollingWindow(id: String, hour: Int, minute: Int, guideID: String, days: Int) async
    func cancel(id: String)
}
