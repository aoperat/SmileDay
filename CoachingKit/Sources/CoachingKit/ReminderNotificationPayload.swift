import Foundation

/// 리마인더 알림 userInfo에 싣는 딥링크 정보. 스케줄러가 쓰고 라우터가 읽는다.
///
/// 알림 하나가 어떤 가이드를 열지만 담는다. 문구 자체는 싣지 않는다 — 카탈로그가 바뀌어도
/// 이미 예약된 알림이 사라진 문구를 붙들지 않게 하려는 것이다.
public struct ReminderNotificationPayload: Equatable, Sendable {
    /// 어떤 리마인더에서 왔는지. 출처를 알 수 없는 구버전 알림은 빈 문자열이다.
    public let reminderID: String
    /// 카탈로그에서 사라진 ID일 수도 있다. 원문을 그대로 두고 쓰는 쪽에서 대체한다.
    public let guideID: String

    private enum Key {
        static let reminderID = "reminderID"
        static let guideID = "guideID"
        // 가이드가 없던 시절 알림이 싣던 필드. 읽기만 한다.
        static let legacyBucket = "bucket"
        static let legacyPromptText = "promptText"
    }

    public init(reminderID: String, guideID: String) {
        self.reminderID = reminderID
        self.guideID = guideID
    }

    public var userInfo: [String: Any] {
        [Key.reminderID: reminderID, Key.guideID: guideID]
    }

    // 카드 해석은 `SmileGuideLibrary.guide(id:)`가 한다. 여기서 카탈로그를 직접 부르면
    // 사용자가 만든 카드로 예약한 알림을 탭했을 때 기본 카드가 열린다.

    /// 새 payload면 그대로, 구버전(bucket/promptText) 알림이면 기본 가이드로 연결한다.
    /// 둘 다 아니면 nil이라 앱은 홈에 머문다.
    public init?(userInfo: [AnyHashable: Any]) {
        if let guideID = userInfo[Key.guideID] as? String, !guideID.isEmpty {
            self.reminderID = userInfo[Key.reminderID] as? String ?? ""
            self.guideID = guideID
            return
        }

        let isLegacy = userInfo[Key.legacyBucket] is String || userInfo[Key.legacyPromptText] is String
        guard isLegacy else { return nil }
        self.reminderID = ""
        self.guideID = SmileGuideCatalog.default.id
    }
}
