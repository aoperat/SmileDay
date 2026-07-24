import Foundation

/// 리마인더 알림 userInfo에 싣는 딥링크 정보. 스케줄러가 쓰고 라우터가 읽는다.
public struct ReminderNotificationPayload: Equatable, Sendable {
    public let bucket: TimeBucket
    public let promptText: String

    private enum Key {
        static let bucket = "bucket"
        static let promptText = "promptText"
    }

    public init(bucket: TimeBucket, promptText: String) {
        self.bucket = bucket
        self.promptText = promptText
    }

    public var userInfo: [String: Any] {
        [Key.bucket: bucket.rawValue, Key.promptText: promptText]
    }

    /// 필드 누락·미지의 rawValue면 nil — 구버전 알림은 조용히 무시된다.
    public init?(userInfo: [AnyHashable: Any]) {
        guard let rawBucket = userInfo[Key.bucket] as? String,
              let bucket = TimeBucket(rawValue: rawBucket),
              let promptText = userInfo[Key.promptText] as? String else { return nil }
        self.bucket = bucket
        self.promptText = promptText
    }
}
