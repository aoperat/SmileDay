import Foundation

/// 알림 일정 저장이 실패한 이유. 문구는 앱 타깃이 붙인다.
public enum ReminderScheduleError: Equatable, Sendable {
    /// 새 알림을 등록하지 못했다. 기존 알림은 그대로다.
    case schedulingFailed
    /// 일정을 저장하지 못했다.
    case persistenceFailed
}
