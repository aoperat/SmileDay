import Foundation
import SwiftData

@Model
public final class ReminderSetting {
    public var hour: Int
    public var minute: Int
    public var isEnabled: Bool
    public var createdAt: Date
    public var notificationID: String
    /// 이 시각에 안내할 미소 가이드. 가이드가 없던 시절에 만든 알림은 nil이다.
    public var guideID: String?

    public init(
        hour: Int,
        minute: Int,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        notificationID: String = UUID().uuidString,
        guideID: String? = nil
    ) {
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.notificationID = notificationID
        self.guideID = guideID
    }

    // 카드 해석은 `SmileGuideLibrary.guide(id:)`가 한다. 여기에 편의 프로퍼티를 두면
    // 사용자가 만든 카드를 못 찾고 조용히 기본 카드로 떨어진다.
}
