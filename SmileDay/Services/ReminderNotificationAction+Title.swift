import Foundation
import UserNotifications
import CoachingKit

extension ReminderNotificationAction {
    /// 잠금화면 버튼 문구. 키는 `reminderAction.<rawValue>` — rawValue가 곧 호환 계약이므로
    /// 키도 같이 고정이다.
    ///
    /// `localizedUserNotificationString`으로 만들어 **표시 시점** 언어를 따른다. 카테고리는 앱
    /// 실행마다 다시 등록되지만, 이렇게 두면 등록 시점 언어와도 무관해진다.
    var title: String {
        NSString.localizedUserNotificationString(forKey: "reminderAction.\(rawValue)", arguments: nil)
    }
}
