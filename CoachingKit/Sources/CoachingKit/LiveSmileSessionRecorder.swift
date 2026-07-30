import Foundation

/// 1초 칸 하나의 판정.
///
/// `unknown`은 "안 웃었다"가 아니라 "웃었는지 알 수 없다"다. 이 구분이 이 기능의 핵심이다 —
/// 얼굴이 안 보인 시간을 안 웃은 시간으로 적으면 자리를 비운 것이 나쁜 기록이 된다.
public enum LiveSmileObservation: Equatable, Sendable {
    case smiling
    case notSmiling
    case unknown
}

/// 요약 화면이 분기하는 상태. 셋 중 하나만 성립한다.
///
/// "측정 없음"과 "낮은 신뢰"를 Optional과 Bool로 따로 들면 둘 다 참인 조합이 만들어진다.
/// 그러면 화면에 없는 숫자를 두고 "이 숫자는 참고만 해주세요"가 함께 뜬다.
/// 상호배타 상태로 두어 그 조합을 아예 표현할 수 없게 한다.
public enum LiveSmileSessionConfidence: Equatable, Sendable {
    /// 판정 가능한 시간이 없어 비율을 낼 수 없다. 다른 안내보다 우선한다.
    case noMeasurement
    /// 비율은 있지만 인식된 시간이 짧아 참고만 해야 한다.
    case low(ratio: Double)
    /// 비율을 그대로 보여줘도 된다.
    case reliable(ratio: Double)
}

/// 한 세션의 집계. 타임라인 하나에서 전부 계산한다 — 카운터를 따로 들면 배열과 어긋날 수 있다.
public struct LiveSmileSessionSummary: Equatable, Sendable {
    /// 판정 가능 시간이 이보다 짧으면 비율을 믿지 않는다.
    ///
    /// 초기값이다. 실기기 검증에서 조정한다 — 설계 §5.2.
    static let minimumReliableUsableSeconds = 60
    /// `unknown` 비율이 이를 넘으면 비율을 믿지 않는다. 같은 이유로 초기값이다.
    static let maximumReliableUnknownRatio = 0.5

    public let timeline: [LiveSmileObservation]

    public init(timeline: [LiveSmileObservation]) {
        self.timeline = timeline
    }

    /// 요약 헤더에 쓰는 값. 그래프 가로축과 같다.
    public var totalSeconds: Int { timeline.count }

    public var smilingSeconds: Int { timeline.filter { $0 == .smiling }.count }
    public var notSmilingSeconds: Int { timeline.filter { $0 == .notSmiling }.count }
    public var unknownSeconds: Int { timeline.filter { $0 == .unknown }.count }
    public var usableSeconds: Int { smilingSeconds + notSmilingSeconds }

    /// 판정 가능 시간이 0이면 nil. 한 번도 웃지 않았으면 0이다 — 둘은 다른 상태다.
    ///
    /// Swift의 `Double` 나눗셈은 트랩하지 않으므로 여기서 막는 것은 크래시가 아니라
    /// `NaN`이 퍼센트 라벨까지 흘러가는 것이다.
    public var smilingRatio: Double? {
        guard usableSeconds > 0 else { return nil }
        return Double(smilingSeconds) / Double(usableSeconds)
    }

    /// 분모에서 unknown을 뺐으므로 이 값을 화면에 항상 함께 보여준다.
    ///
    /// 단 `smilingRatio`와 분모가 다르다 — 이쪽은 전체 시간이다. 두 값을 하나의 100%
    /// 막대에 쌓으면 산술적으로 의미가 없으므로 따로 보여준다.
    public var unknownRatio: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(unknownSeconds) / Double(totalSeconds)
    }

    /// 화면은 이 값 하나로 분기한다. 비율과 신뢰 안내를 따로 조합하지 않는다.
    public var confidence: LiveSmileSessionConfidence {
        guard let smilingRatio else { return .noMeasurement }

        let isReliable = usableSeconds >= Self.minimumReliableUsableSeconds
            && unknownRatio <= Self.maximumReliableUnknownRatio
        return isReliable ? .reliable(ratio: smilingRatio) : .low(ratio: smilingRatio)
    }
}
