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
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: delta
        )
        session.stop()
        phase = .completed(scoreDelta: delta)
    }
}
