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

/// 프레임을 1초 칸으로 접는다.
///
/// 타이머를 쓰지 않는다. 프레임이 도착할 때 몇 번째 초 칸인지 계산하고, 건너뛴 칸은
/// `unknown`으로 채운다. 별도 처리 없이 "그 시간은 모른다"가 정확히 표현되고,
/// 주입한 `now()`로 전부 테스트된다.
public final class LiveSmileSessionRecorder {
    public static let bucketDuration: TimeInterval = 1
    /// 스냅샷 슬롯이 열리는 간격.
    public static let snapshotInterval: TimeInterval = 60
    /// 경계 후 이 시간 안에 쓸 프레임이 없으면 그 분은 건너뛴다.
    public static let snapshotGrace: TimeInterval = 5
    /// 메모리 상한. 넘으면 사진만 멈추고 타임라인은 계속 쌓는다.
    public static let maxSnapshots = 120

    private let now: () -> Date

    /// 확정된 칸들. 측정 중 그래프가 이 값을 그린다.
    public private(set) var timeline: [LiveSmileObservation] = []

    private var startedAt: Date?
    private var currentBucketIndex = 0
    private var observedFrames = 0
    private var usableFrames = 0
    private var smilingFrames = 0
    /// 두 번 부르면 빈 칸이 하나 덧붙는다. 한 번만 확정하게 막는다.
    private var hasFinished = false
    private var lastObservation: LiveSmileObservation?
    private var claimedSlot: Int?
    private var snapshotCount = 0

    public init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    /// 프레임마다 부른다.
    public func observe(_ observation: LiveSmileObservation) {
        let timestamp = now()

        guard let startedAt else {
            self.startedAt = timestamp
            currentBucketIndex = 0
            count(observation)
            return
        }

        let index = Int(timestamp.timeIntervalSince(startedAt) / Self.bucketDuration)
        if index > currentBucketIndex {
            closeCurrentBucket()
            // 프레임이 오지 않은 칸은 모른다고 적는다.
            while timeline.count < index {
                timeline.append(.unknown)
            }
            currentBucketIndex = index
        }

        count(observation)
    }

    /// 마지막 부분 칸을 확정하고, 마지막 프레임 이후 종료까지도 채운 뒤 집계한다.
    ///
    /// 끝머리를 빼면 `unknownRatio`의 분모가 줄어 세션이 실제보다 믿을 만해 보인다.
    /// 숫자를 과신하지 않게 하려고 있는 신호가 거꾸로 작동하는 셈이다.
    /// 종료를 누르려면 사용자가 있어야 하니 짧다고 단정할 수도 없다 —
    /// 고개를 돌려 인식이 끊긴 뒤 한참 있다 누를 수 있다.
    public func finish() -> LiveSmileSessionSummary {
        guard let startedAt, !hasFinished else {
            return LiveSmileSessionSummary(timeline: timeline)
        }
        hasFinished = true

        closeCurrentBucket()

        let endIndex = Int(now().timeIntervalSince(startedAt) / Self.bucketDuration)
        while timeline.count <= endIndex {
            timeline.append(.unknown)
        }

        return LiveSmileSessionSummary(timeline: timeline)
    }

    /// 지금 사진을 잡아야 하면 true. 분당 최대 한 번만 true를 낸다.
    ///
    /// 묻기와 표시하기를 두 단계로 나누지 않는다 — 표시를 잊으면 매 프레임 사진을 찍는다.
    public func claimSnapshotSlot() -> Bool {
        guard snapshotCount < Self.maxSnapshots else { return false }
        guard let startedAt else { return false }
        // 얼굴이 없거나 각도가 벗어난 프레임으로 남기면 얼굴 없는 사진이 된다.
        guard let lastObservation, lastObservation != .unknown else { return false }

        let elapsed = now().timeIntervalSince(startedAt)
        let slot = Int(elapsed / Self.snapshotInterval)
        guard slot != claimedSlot else { return false }

        // 경계에서 너무 멀어졌으면 이번 분은 포기한다.
        let sinceSlotStart = elapsed - Double(slot) * Self.snapshotInterval
        guard sinceSlotStart <= Self.snapshotGrace else { return false }

        claimedSlot = slot
        snapshotCount += 1
        return true
    }

    private func count(_ observation: LiveSmileObservation) {
        observedFrames += 1
        if observation != .unknown { usableFrames += 1 }
        if observation == .smiling { smilingFrames += 1 }
        lastObservation = observation
    }

    private func closeCurrentBucket() {
        timeline.append(decideCurrentBucket())
        observedFrames = 0
        usableFrames = 0
        smilingFrames = 0
    }

    private func decideCurrentBucket() -> LiveSmileObservation {
        guard observedFrames > 0 else { return .unknown }
        // 절반 미만만 판정 가능하면 그 1초는 믿지 않는다.
        guard Double(usableFrames) >= Double(observedFrames) / 2 else { return .unknown }
        // 동수는 안 웃음으로 — 적게 세는 쪽으로 기운다.
        return smilingFrames * 2 > usableFrames ? .smiling : .notSmiling
    }
}
