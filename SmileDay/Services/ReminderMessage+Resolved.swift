import Foundation
import CoachingKit

extension ReminderMessage {
    /// 화면에 보이는 문구. 사용자가 쓴 것이면 그대로, 기본값이면 카탈로그에서 현재 언어로.
    var resolvedText: String {
        // 키를 먼저 String으로 합친다. 보간 리터럴을 LocalizationValue에 직접 넘기면 보간이
        // 포맷 인자로 잡혀 "reminderMessage.%@"를 찾는다 (Task 6에서 실측·수정한 함정).
        if let text { return text }
        let key = "reminderMessage." + id
        return String(localized: String.LocalizationValue(key))
    }
}
