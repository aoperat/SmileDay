import Foundation

/// 지표 하나의 세션 통계 (표본 표준편차).
public struct MetricStats: Codable, Equatable, Sendable {
    public var mean: Double
    public var max: Double
    public var std: Double

    public init(mean: Double, max: Double, std: Double) {
        self.mean = mean
        self.max = max
        self.std = std
    }
}

/// 선별 지표 12개의 블렌드셰이프 딕셔너리 키.
/// 앱 레이어가 ARKit BlendShapeLocation rawValue로 인스턴스를 만들어 주입하므로
/// 프로덕션에서는 문자열 추측이 없다. `default`는 테스트/프리뷰용.
public struct CuratedMetricKeys: Sendable {
    public let mouthSmileLeft: String
    public let mouthSmileRight: String
    public let browDownLeft: String
    public let browDownRight: String
    public let browInnerUp: String
    public let eyeSquintLeft: String
    public let eyeSquintRight: String
    public let cheekSquintLeft: String
    public let cheekSquintRight: String
    public let jawOpen: String
    public let mouthPressLeft: String
    public let mouthPressRight: String

    public init(
        mouthSmileLeft: String, mouthSmileRight: String,
        browDownLeft: String, browDownRight: String, browInnerUp: String,
        eyeSquintLeft: String, eyeSquintRight: String,
        cheekSquintLeft: String, cheekSquintRight: String,
        jawOpen: String,
        mouthPressLeft: String, mouthPressRight: String
    ) {
        self.mouthSmileLeft = mouthSmileLeft
        self.mouthSmileRight = mouthSmileRight
        self.browDownLeft = browDownLeft
        self.browDownRight = browDownRight
        self.browInnerUp = browInnerUp
        self.eyeSquintLeft = eyeSquintLeft
        self.eyeSquintRight = eyeSquintRight
        self.cheekSquintLeft = cheekSquintLeft
        self.cheekSquintRight = cheekSquintRight
        self.jawOpen = jawOpen
        self.mouthPressLeft = mouthPressLeft
        self.mouthPressRight = mouthPressRight
    }

    public var all: [String] {
        [mouthSmileLeft, mouthSmileRight, browDownLeft, browDownRight, browInnerUp,
         eyeSquintLeft, eyeSquintRight, cheekSquintLeft, cheekSquintRight,
         jawOpen, mouthPressLeft, mouthPressRight]
    }

    public static let `default` = CuratedMetricKeys(
        mouthSmileLeft: "mouthSmile_L", mouthSmileRight: "mouthSmile_R",
        browDownLeft: "browDown_L", browDownRight: "browDown_R", browInnerUp: "browInnerUp",
        eyeSquintLeft: "eyeSquint_L", eyeSquintRight: "eyeSquint_R",
        cheekSquintLeft: "cheekSquint_L", cheekSquintRight: "cheekSquint_R",
        jawOpen: "jawOpen",
        mouthPressLeft: "mouthPress_L", mouthPressRight: "mouthPress_R"
    )
}

/// 파생 지표의 stats 딕셔너리 키.
public enum DerivedMetric {
    public static let smile = "smile"
    public static let smileAsymmetry = "smileAsymmetry"
    public static let duchenne = "duchenne"
}

/// 트래킹 세션 동안 프레임을 받아 지표별 mean/max/std를 스트리밍 계산한다.
/// Welford 알고리즘 — 프레임 원본을 쌓지 않으므로 메모리 사용이 일정하다.
public final class SessionMetricsAccumulator {
    public struct Summary: Equatable, Sendable {
        public let stats: [String: MetricStats]
        public let durationSeconds: Double
        public let trackingLossCount: Int

        public var smileMean: Double? { stats[DerivedMetric.smile]?.mean }
        public var smileMax: Double? { stats[DerivedMetric.smile]?.max }
        public var smileStability: Double? { stats[DerivedMetric.smile]?.std }
        public var smileAsymmetry: Double? { stats[DerivedMetric.smileAsymmetry]?.mean }
        public var duchenneScore: Double? { stats[DerivedMetric.duchenne]?.mean }
    }

    private struct Welford {
        var count = 0
        var mean = 0.0
        var m2 = 0.0
        var maxValue = -Double.infinity

        mutating func add(_ value: Double) {
            count += 1
            let delta = value - mean
            mean += delta / Double(count)
            m2 += delta * (value - mean)
            maxValue = Swift.max(maxValue, value)
        }

        var stats: MetricStats {
            MetricStats(mean: mean, max: maxValue, std: count > 1 ? (m2 / Double(count - 1)).squareRoot() : 0)
        }
    }

    private let keys: CuratedMetricKeys
    private let gapThreshold: TimeInterval
    private var welfords: [String: Welford] = [:]
    private var firstFrameAt: Date?
    private var lastFrameAt: Date?
    private var trackingLossCount = 0

    public init(keys: CuratedMetricKeys = .default, gapThreshold: TimeInterval = 0.5) {
        self.keys = keys
        self.gapThreshold = gapThreshold
    }

    public func add(_ measurement: FaceMeasurement, at date: Date) {
        if firstFrameAt == nil { firstFrameAt = date }
        if let last = lastFrameAt, date.timeIntervalSince(last) > gapThreshold {
            trackingLossCount += 1
        }
        lastFrameAt = date

        for key in keys.all {
            if let value = measurement.blendShapes[key] {
                welfords[key, default: Welford()].add(value)
            }
        }

        let smile = (measurement.mouthCornerLeft + measurement.mouthCornerRight) / 2
        welfords[DerivedMetric.smile, default: Welford()].add(smile)
        welfords[DerivedMetric.smileAsymmetry, default: Welford()].add(measurement.mouthCornerLeft - measurement.mouthCornerRight)

        let squints = [keys.eyeSquintLeft, keys.eyeSquintRight, keys.cheekSquintLeft, keys.cheekSquintRight]
            .compactMap { measurement.blendShapes[$0] }
        if squints.count == 4 {
            welfords[DerivedMetric.duchenne, default: Welford()].add(squints.reduce(0, +) / 4)
        }
    }

    public func summarize() -> Summary {
        let duration: Double
        if let first = firstFrameAt, let last = lastFrameAt {
            duration = last.timeIntervalSince(first)
        } else {
            duration = 0
        }
        return Summary(
            stats: welfords.mapValues(\.stats),
            durationSeconds: duration,
            trackingLossCount: trackingLossCount
        )
    }
}
