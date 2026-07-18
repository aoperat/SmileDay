import ARKit
import SceneKit
import CoachingKit

enum FaceTrackingError: Error {
    case unsupportedDevice
}

final class ARKitFaceTrackingSession: NSObject, FaceTrackingSession {
    var onUpdate: ((FaceMeasurement) -> Void)?
    var onError: ((Error) -> Void)?

    let previewView = ARSCNView()
    private var isRunning = false

    override init() {
        super.init()
        previewView.delegate = self
        previewView.session.delegate = self
    }

    func start() {
        guard !isRunning else { return }
        guard ARFaceTrackingConfiguration.isSupported else {
            onError?(FaceTrackingError.unsupportedDevice)
            return
        }
        let configuration = ARFaceTrackingConfiguration()
        previewView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
    }

    func stop() {
        previewView.session.pause()
        isRunning = false
    }
}

extension ARKitFaceTrackingSession: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        let blendShapes = faceAnchor.blendShapes

        let mouthCornerLeft = blendShapes[.mouthSmileLeft]?.doubleValue ?? 0
        let mouthCornerRight = blendShapes[.mouthSmileRight]?.doubleValue ?? 0
        let browDownLeft = blendShapes[.browDownLeft]?.doubleValue ?? 0
        let browDownRight = blendShapes[.browDownRight]?.doubleValue ?? 0
        let browInnerUp = blendShapes[.browInnerUp]?.doubleValue ?? 0
        let browTension = (browDownLeft + browDownRight + browInnerUp) / 3

        let measurement = FaceMeasurement(
            mouthCornerLeft: mouthCornerLeft,
            mouthCornerRight: mouthCornerRight,
            browTension: browTension
        )

        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?(measurement)
        }
    }
}

extension ARKitFaceTrackingSession: ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        onError?(error)
    }
}
