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

    /// nil이거나 카탈로그에 없는 ID는 기본 가이드로 읽는다 — 알림이 비어 나가지 않게.
    public var guide: SmileGuide {
        SmileGuideCatalog.guide(id: guideID)
    }
}
