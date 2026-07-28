import Foundation
import SwiftData

/// 미소를 시작하게 된 경로. 알림이 실제로 행동을 만들었는지 보려고 남긴다.
public enum SmileMomentSource: String, CaseIterable, Equatable, Sendable {
    case manual
    case notification
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

    /// 저장된 ID가 카탈로그에 없으면 기본 가이드로 대체한다.
    public var guide: SmileGuide {
        SmileGuideCatalog.guide(id: guideID)
    }
}
