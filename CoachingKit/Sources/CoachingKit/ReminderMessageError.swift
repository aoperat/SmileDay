import Foundation

/// 알림 문구 편집이 거부된 이유. 문구는 앱 타깃이 붙인다.
public enum ReminderMessageError: Equatable, Sendable {
    case empty
    case tooLong(limit: Int)
    case duplicate
    /// 마지막 한 개는 지울 수 없다.
    case lastRemaining
}
