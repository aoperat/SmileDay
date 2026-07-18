import Foundation

public protocol FaceTrackingSession: AnyObject {
    var onUpdate: ((FaceMeasurement) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }
    var onLightingUpdate: ((Double) -> Void)? { get set }
    func start()
    func stop()
}
