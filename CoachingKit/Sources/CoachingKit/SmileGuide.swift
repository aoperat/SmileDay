import Foundation

/// 미소 한 번의 실행 단위.
///
/// 얼굴을 측정하지 않으므로 "얼마나 잘 웃었는지"는 어디에도 없다.
/// 화면에 보이는 비평가적 문구는 `SmileCueCatalog`가 맡는다.
/// 여기에는 완료 기록과 알림 payload가 쓰는 식별자와 실행 길이만 둔다.
public struct SmileGuide: Identifiable, Equatable, Sendable {
    public let id: String
    public let durationSeconds: Int

    public init(id: String, durationSeconds: Int = SmileGuideCatalog.defaultDurationSeconds) {
        self.id = id
        self.durationSeconds = durationSeconds
    }
}

public enum SmileGuideCatalog {
    public static let defaultDurationSeconds = 5

    /// 활성 흐름이 쓰는 단 하나의 가이드.
    ///
    /// ID는 바꾸지 않는다. 이미 저장된 `SmileMoment.guideID`와 기기에 예약된
    /// 알림 payload가 이 문자열을 그대로 담고 있다.
    public static let `default` = SmileGuide(id: "anytime-soft")
}
