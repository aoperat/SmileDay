import Foundation

/// 리마인더 알림 userInfo에 싣는 딥링크 정보. 스케줄러가 쓰고 라우터가 읽는다.
///
/// 현재 홈은 이 값을 "유효한 미소 알림을 탭했다"는 신호로만 쓴다 —
/// `reminderID`와 `guideID`를 읽어 화면을 가르지 않는다. 두 필드가 남아 있는 이유는
/// 기기에 이미 예약된 알림의 userInfo가 이 key들을 담고 있어, 파싱이 계속 성공해야 하기 때문이다.
public struct ReminderNotificationPayload: Equatable, Sendable {
    /// 어떤 리마인더에서 왔는지. 출처를 알 수 없는 구버전 알림은 빈 문자열이다.
    public let reminderID: String
    /// 예약 당시의 가이드 ID. 지금 화면을 고르는 데 쓰지 않는다.
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
