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

/// 한 세션의 집계. 타임라인 하나에서 전부 계산한다 — 카운터를 따로 들면 배열과 어긋날 수 있다.
public struct LiveSmileSessionSummary: Equatable, Sendable {
    /// 판정 가능 시간이 이보다 짧으면 낮은 신뢰로 본다.
    public static let lowConfidenceUsableSeconds = 60
    /// `unknown` 비율이 이보다 높으면 낮은 신뢰로 본다.
    public static let lowConfidenceUnknownRatio = 0.5

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

    /// 판정 가능 시간이 0이면 nil. 0으로 나누는 경로를 타입으로 막는다.
    public var smilingRatio: Double? {
        guard usableSeconds > 0 else { return nil }
        return Double(smilingSeconds) / Double(usableSeconds)
    }

    /// 분모에서 unknown을 뺐으므로 이 값을 화면에 항상 함께 보여준다.
    public var unknownRatio: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(unknownSeconds) / Double(totalSeconds)
    }

    public var isLowConfidence: Bool {
        usableSeconds < Self.lowConfidenceUsableSeconds
            || unknownRatio > Self.lowConfidenceUnknownRatio
    }
}
