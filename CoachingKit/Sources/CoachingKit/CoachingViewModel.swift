import Foundation
import Observation

@Observable
public final class CoachingViewModel {
    public enum Phase: Equatable {
        case tracking
        case completed
    }

    public private(set) var phase: Phase = .tracking
    // 초당 수십 회 갱신되는 원시 측정값은 관찰 대상에서 제외한다.
    // 저장에는 항상 이 최신 값을 쓴다.
    @ObservationIgnored public private(set) var latestMeasurement: FaceMeasurement?
    /// 얼굴이 잡혀 저장할 수 있는 상태인지 알리는 관찰 값.
    ///
    /// 값 자체를 화면에 숫자로 보여주지 않는다. 저장 버튼 활성화와 트래킹 준비 안내에만 쓰므로
    /// 첫 측정이 들어온 순간 한 번만 갱신해 프레임마다 UI가 무효화되지 않게 한다.
    public private(set) var displayedMeasurement: FaceMeasurement?
    // 원시 조명값도 같은 이유로 관찰 대상에서 제외한다.
    @ObservationIgnored public private(set) var latestAmbientIntensity: Double?
    public private(set) var isLightingPoor: Bool = false
    public private(set) var isAngleOK: Bool = true

    private let session: FaceTrackingSession
    private let repository: SessionRepository
    private let baseline: Baseline
    private let now: () -> Date
    @ObservationIgnored private let accumulator: SessionMetricsAccumulator

    public init(
        session: FaceTrackingSession,
        repository: SessionRepository,
        baseline: Baseline,
        now: @escaping () -> Date = Date.init,
        metricKeys: CuratedMetricKeys = .default
    ) {
        self.session = session
        self.repository = repository
        self.baseline = baseline
        self.now = now
        self.accumulator = SessionMetricsAccumulator(keys: metricKeys)
        self.session.onUpdate = { [weak self] measurement in
            guard let self else { return }
            self.latestMeasurement = measurement
            self.accumulator.add(measurement, at: self.now())
            if self.displayedMeasurement == nil {
                self.displayedMeasurement = measurement
            }
        }
        self.session.onLightingUpdate = { [weak self] intensity in
            guard let self else { return }
            self.latestAmbientIntensity = intensity
            let poor = LightingEvaluator.isTooDark(ambientIntensity: intensity)
            if poor != self.isLightingPoor {
                self.isLightingPoor = poor
            }
        }
        self.session.onTrackingQualityUpdate = { [weak self] ok in
            self?.isAngleOK = ok
        }
    }

    public func start() {
        session.start()
    }

    /// 미소 시간을 마치고 기록을 저장한다.
    ///
    /// 얼굴 측정값과 점수는 측정 품질·데이터 호환을 위해 계속 저장하지만 결과로 돌려주지 않는다.
    /// 사용자에게 보여줄 문구는 `HabitEncouragementEngine`이 행동 이력만으로 만든다.
    ///
    /// - Parameter promptText: 이 미소 시간을 열게 한 질문. 알림 없이 진입했으면 nil.
    public func complete(promptText: String? = nil) throws {
        guard phase == .tracking, let measurement = latestMeasurement else { return }
        let delta = ScoreCalculator.delta(current: measurement, baseline: baseline.measurement)
        let summary = accumulator.summarize()
        let payload = CheckInPayload(
            blendshapesFinal: measurement.blendShapes,
            sessionStats: summary.stats,
            pitchDegrees: measurement.pitchDegrees,
            yawDegrees: measurement.yawDegrees,
            captureDurationSeconds: summary.durationSeconds,
            trackingLossCount: summary.trackingLossCount
        )
        try repository.saveCheckIn(
            measurement: measurement,
            date: now(),
            lightingQuality: latestAmbientIntensity.map(LightingEvaluator.quality(ambientIntensity:)) ?? 1.0,
            deviceAngleOK: isAngleOK,
            scoreDelta: delta,
            summary: summary,
            payload: payload,
            promptText: promptText
        )
        session.stop()
        phase = .completed
    }
}
