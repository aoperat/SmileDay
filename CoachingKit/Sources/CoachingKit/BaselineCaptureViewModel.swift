import Foundation
import Observation

@Observable
public final class BaselineCaptureViewModel {
    public enum Phase: Equatable {
        case tracking
        case saved(Baseline)
    }

    public private(set) var phase: Phase = .tracking
    public private(set) var latestMeasurement: FaceMeasurement?

    private let session: FaceTrackingSession
    private let repository: SessionRepository
    private let now: () -> Date

    public init(session: FaceTrackingSession, repository: SessionRepository, now: @escaping () -> Date = Date.init) {
        self.session = session
        self.repository = repository
        self.now = now
        self.session.onUpdate = { [weak self] measurement in
            self?.latestMeasurement = measurement
        }
    }

    public func start() {
        session.start()
    }

    public func captureBaseline() throws {
        guard phase == .tracking, let measurement = latestMeasurement else { return }
        let baseline = try repository.saveBaseline(measurement, capturedAt: now())
        session.stop()
        phase = .saved(baseline)
    }
}
