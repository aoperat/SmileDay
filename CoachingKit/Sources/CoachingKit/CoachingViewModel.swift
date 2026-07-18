import Foundation
import Observation

@Observable
public final class CoachingViewModel {
    public enum Phase: Equatable {
        case tracking
        case completed(scoreDelta: Double)
    }

    public private(set) var phase: Phase = .tracking
    public private(set) var latestMeasurement: FaceMeasurement?
    // 초당 수십 회 갱신되는 원시 조명값은 관찰 대상에서 제외하고,
    // UI가 읽는 isLightingPoor는 상태가 실제로 바뀔 때만 갱신한다.
    @ObservationIgnored public private(set) var latestAmbientIntensity: Double?
    public private(set) var isLightingPoor: Bool = false

    private let session: FaceTrackingSession
    private let repository: SessionRepository
    private let baseline: Baseline
    private let now: () -> Date

    public init(
        session: FaceTrackingSession,
        repository: SessionRepository,
        baseline: Baseline,
        now: @escaping () -> Date = Date.init
    ) {
        self.session = session
        self.repository = repository
        self.baseline = baseline
        self.now = now
        self.session.onUpdate = { [weak self] measurement in
            self?.latestMeasurement = measurement
        }
        self.session.onLightingUpdate = { [weak self] intensity in
            guard let self else { return }
            self.latestAmbientIntensity = intensity
            let poor = LightingEvaluator.isTooDark(ambientIntensity: intensity)
            if poor != self.isLightingPoor {
                self.isLightingPoor = poor
            }
        }
    }

    public func start() {
        session.start()
    }

    public func complete() throws {
        guard phase == .tracking, let measurement = latestMeasurement else { return }
        let delta = ScoreCalculator.delta(current: measurement, baseline: baseline.measurement)
        try repository.saveCheckIn(
            measurement: measurement,
            date: now(),
            lightingQuality: latestAmbientIntensity.map(LightingEvaluator.quality(ambientIntensity:)) ?? 1.0,
            deviceAngleOK: true,
            scoreDelta: delta
        )
        session.stop()
        phase = .completed(scoreDelta: delta)
    }

    public func yesterdayDelta(calendar: Calendar = .current) throws -> Double? {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now()) else { return nil }
        return try repository.fetchLatestCheckIn(onDayOf: yesterday, calendar: calendar)?.scoreDelta
    }
}
