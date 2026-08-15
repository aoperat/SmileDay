import Foundation

/// 리마인더 알림에 붙는 버튼. 잠금화면에서 알림을 길게 누르면 나온다.
///
/// **문자열은 기기에 예약된 알림과의 호환 계약이다.** 예약된 알림은 `categoryIdentifier`를
/// 담은 채로 기기에 남아 있고, 사용자가 설정을 다시 저장하기 전까지 갱신되지 않는다.
/// 값을 바꾸면 그 알림들의 버튼이 눌려도 어느 동작인지 알 수 없게 된다 —
/// `ReminderNotificationPayload`의 key와 같은 이유로 고정이다.
///
/// 실제 `UNNotificationCategory`는 앱 타깃이 만든다. 패키지는 식별자만 갖는다. 문구는 앱 타깃(`Localizable.xcstrings`의 `reminderAction.<rawValue>`)에 있다.
public enum ReminderNotificationAction: String, CaseIterable, Equatable, Sendable {
    /// 앱을 열지 않고 그 자리에서 기록한다.
    case recordSmile = "smile-recorded"
    /// 앱을 앞으로 가져와 미소 가이드를 연다. 알림 본문을 탭한 것과 같은 결과다.
    case openGuide = "open-guide"

    /// 앱을 앞으로 가져와야 하는 동작인지. 기록은 화면 없이 끝난다.
    public var opensApp: Bool {
        switch self {
        case .recordSmile: false
        case .openGuide: true
        }
    }
}

/// 위 버튼들을 묶는 카테고리. 예약할 때 알림에 이 값을 찍어야 버튼이 나온다.
public enum ReminderNotificationCategory {
    /// 같은 호환 계약이다 — 이미 예약된 알림이 이 문자열을 담고 있다.
    public static let identifier = "smile-reminder"
}
