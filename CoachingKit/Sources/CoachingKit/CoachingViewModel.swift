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
    public private(set) var latestAmbientIntensity: Double?

    private let session: FaceTrackingSession
    private let repository: SessionRepository
    private let baseline: Baseline
    private let now: () -> Date

    public var isLightingPoor: Bool {
        latestAmbientIntensity.map(LightingEvaluator.isTooDark(ambientIntensity:)) ?? false
    }

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
            self?.latestAmbientIntensity = intensity
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
