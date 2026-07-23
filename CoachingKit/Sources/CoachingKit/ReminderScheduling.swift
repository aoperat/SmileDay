import Foundation

/// 리마인더 알림이 며칠치를 미리 예약해둘지. 로컬 알림만 쓰므로(서버 푸시 없음)
/// 사용자가 이 기간보다 오래 앱을 열지 않으면 그 이후 알림은 끊긴다.
public let reminderRollingWindowDays = 14

public protocol ReminderScheduling: AnyObject {
    func requestAuthorization() async -> Bool
    /// hour:minute에 향후 `days`일치 알림을 각각 다른(순환) 문구로 개별 예약한다.
    func scheduleRollingWindow(id: String, hour: Int, minute: Int, days: Int) async
    func cancel(id: String)
}
