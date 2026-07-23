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
    @ObservationIgnored public private(set) var latestAmbientIntensity: Double?
    public private(set) var isLightingPoor: Bool = false
    public private(set) var isAngleOK: Bool = true

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

    public func captureBaseline() throws {
        guard phase == .tracking, let measurement = latestMeasurement else { return }
        let baseline = try repository.saveBaseline(
            measurement,
            capturedAt: now(),
            lightingQuality: latestAmbientIntensity.map(LightingEvaluator.quality(ambientIntensity:)) ?? 1.0,
            deviceAngleOK: isAngleOK
        )
        try repository.pruneOldBaselines()
        session.stop()
        phase = .saved(baseline)
    }
}
