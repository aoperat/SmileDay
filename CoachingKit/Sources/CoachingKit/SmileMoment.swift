import Foundation
import SwiftData

/// 미소를 시작하게 된 경로. 알림이 실제로 행동을 만들었는지 보려고 남긴다.
///
/// 저장되는 것은 `rawValue` 문자열이므로 case를 더해도 스키마는 그대로다 — 마이그레이션이 없다.
public enum SmileMomentSource: String, CaseIterable, Equatable, Sendable {
    case manual
    case notification
    /// 잠금화면 알림의 "웃었어요"를 눌러 가이드 없이 기록한 것.
    ///
    /// `notification`과 나눠 둔다. 저쪽은 가이드를 열고 5초를 지킨 기록이고 이쪽은 자기 신고다.
    /// 지금 화면은 둘을 구분해 보여주지 않지만, 나중에 "알림만으로도 루프가 도는가"를
    /// 물어볼 때 이 구분이 없으면 답할 수 없다.
    case notificationAction = "notification-action"
}

/// 완료한 미소 하나. 시각과 어떤 가이드였는지만 남기고 표정은 측정하지 않는다.
@Model
public final class SmileMoment {
    public var date: Date
    public var guideID: String
    public var sourceRawValue: String

    public init(date: Date, guideID: String, source: SmileMomentSource) {
        self.date = date
        self.guideID = guideID
        self.sourceRawValue = source.rawValue
    }

    /// 저장된 문자열이 깨졌거나 미래 버전 값이면 조용히 `.manual`로 읽는다.
    public var source: SmileMomentSource {
        get { SmileMomentSource(rawValue: sourceRawValue) ?? .manual }
        set { sourceRawValue = newValue.rawValue }
    }

    // `guideID`는 기록을 남긴 시점의 가이드 ID다. 화면에 이름을 보여주지 않으므로
    // 여기서 해석하지 않고, 지난 버전이 남긴 값도 그대로 보관한다.
}
