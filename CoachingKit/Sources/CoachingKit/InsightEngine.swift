import Foundation

/// 체크인 1회의 판정용 스냅샷. SwiftData 모델과 분리된 값 타입.
public struct CheckInRecord: Equatable, Sendable {
    public let date: Date
    public let browTension: Double
    /// 확장 전 레코드는 nil.
    public let smileAsymmetry: Double?
    public let duchenneScore: Double?
    public let deviceAngleOK: Bool
    public let lightingQuality: Double
    /// payload 디코드 결과. 구버전 레코드는 nil (신뢰 불가로 취급하지 않는다).
    public let trackingLossCount: Int?

    public init(
        date: Date,
        browTension: Double,
        smileAsymmetry: Double?,
        duchenneScore: Double?,
        deviceAngleOK: Bool,
        lightingQuality: Double,
        trackingLossCount: Int?
    ) {
        self.date = date
        self.browTension = browTension
        self.smileAsymmetry = smileAsymmetry
        self.duchenneScore = duchenneScore
        self.deviceAngleOK = deviceAngleOK
        self.lightingQuality = lightingQuality
        self.trackingLossCount = trackingLossCount
    }

    /// 코칭 판정에 쓸 수 없는 기록인지.
    public var isUnreliable: Bool {
        !deviceAngleOK
            || lightingQuality < InsightEngine.poorLightingThreshold
            || (trackingLossCount ?? 0) >= InsightEngine.trackingLossLimit
    }
}

/// 체크인 1회에 대한 코칭 인사이트. 우선순위가 가장 높은 1개만 만들어진다.
public struct CheckInInsight: Equatable, Sendable {
    public enum Side: Equatable, Sendable { case left, right }

    public enum Kind: Equatable, Sendable {
        case lowReliability
        case highTension
        case asymmetry(weakSide: Side)
        case lowDuchenne
    }

    public let kind: Kind
    public let message: String
    /// 케어 탭 추천에 연결할 카테고리. lowReliability는 nil.
    public let recommendedCategory: CareCategory?
}

/// 개인 히스토리 상대 비교로 체크인 인사이트를 판정하는 순수 로직.
/// 날짜 필터링(최근 7일, 오늘 제외)은 호출자 책임 — 여기서는 신뢰도 필터만 한다.
public enum InsightEngine {
    public static let poorLightingThreshold = 0.3  // LightingEvaluator.darkThreshold / referenceIntensity
    public static let trackingLossLimit = 3
    static let minimumHistoryCount = 3
    static let tensionMinDelta = 0.05
    static let asymmetryMinDelta = 0.03
    static let duchenneMinDelta = 0.05

    public static func evaluate(today: CheckInRecord, history: [CheckInRecord]) -> CheckInInsight? {
        if today.isUnreliable {
            return CheckInInsight(
                kind: .lowReliability,
                message: "측정이 조금 흔들렸어요. 내일은 밝은 곳에서 정면으로 찍어봐요",
                recommendedCategory: nil
            )
        }
        let reliable = history.filter { !$0.isUnreliable }

        if let stats = Stats(values: reliable.map(\.browTension)),
           today.browTension > stats.mean + Swift.max(0.5 * stats.std, tensionMinDelta) {
            return CheckInInsight(
                kind: .highTension,
                message: "오늘은 미간 긴장이 평소보다 높아요. 릴랙스 케어로 풀어줘요",
                recommendedCategory: .relax
            )
        }

        if let todayAsymmetry = today.smileAsymmetry,
           let stats = Stats(values: reliable.compactMap(\.smileAsymmetry).map(abs)),
           abs(todayAsymmetry) > stats.mean + Swift.max(0.5 * stats.std, asymmetryMinDelta) {
            // smileAsymmetry = 좌 − 우. 양수면 왼쪽이 더 올라간 것 → 오른쪽이 약한 쪽.
            let weakSide: CheckInInsight.Side = todayAsymmetry > 0 ? .right : .left
            let sideText = weakSide == .right ? "오른" : "왼"
            return CheckInInsight(
                kind: .asymmetry(weakSide: weakSide),
                message: "오늘은 \(sideText)쪽 입꼬리가 덜 올라갔어요. 리프팅으로 균형을 맞춰봐요",
                recommendedCategory: .lift
            )
        }

        if let todayDuchenne = today.duchenneScore,
           let stats = Stats(values: reliable.compactMap(\.duchenneScore)),
           todayDuchenne < stats.mean - Swift.max(0.5 * stats.std, duchenneMinDelta) {
            return CheckInInsight(
                kind: .lowDuchenne,
                message: "입은 웃는데 눈은 아직이에요. 아침 스마일 스트레칭이 도움 돼요",
                recommendedCategory: .morning
            )
        }

        return nil
    }

    /// 표본 minimumHistoryCount개 이상일 때만 만들어지는 평균/표본표준편차.
    private struct Stats {
        let mean: Double
        let std: Double

        init?(values: [Double]) {
            guard values.count >= InsightEngine.minimumHistoryCount else { return nil }
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count - 1)
            self.mean = mean
            self.std = variance.squareRoot()
        }
    }
}

public extension CheckInRecord {
    /// SwiftData 모델 → 판정용 값 타입. payload가 있으면 trackingLossCount를 디코드한다.
    init(session: CheckInSession) {
        let payload = session.payload.flatMap { try? JSONDecoder().decode(CheckInPayload.self, from: $0) }
        self.init(
            date: session.date,
            browTension: session.browTension,
            smileAsymmetry: session.smileAsymmetry,
            duchenneScore: session.duchenneScore,
            deviceAngleOK: session.deviceAngleOK,
            lightingQuality: session.lightingQuality,
            trackingLossCount: payload?.trackingLossCount
        )
    }
}

public extension InsightEngine {
    /// 저장소의 최신 체크인을 오늘로, 그 직전 historyDays일을 히스토리로 판정한다.
    /// fetchCheckIns의 상한이 exclusive(date < end)라 최신 기록 자신은 히스토리에 포함되지 않는다.
    static func evaluateLatest(
        in repository: SessionRepository,
        historyDays: Int = 7,
        calendar: Calendar = .current
    ) throws -> CheckInInsight? {
        guard let latest = try repository.fetchLatestCheckIn(),
              let windowStart = calendar.date(byAdding: .day, value: -historyDays, to: latest.date)
        else { return nil }
        let history = try repository.fetchCheckIns(from: windowStart, to: latest.date)
            .map(CheckInRecord.init(session:))
        return evaluate(today: CheckInRecord(session: latest), history: history)
    }
}
