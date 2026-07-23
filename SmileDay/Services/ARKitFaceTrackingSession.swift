import ARKit
import CoachingKit

enum FaceTrackingError: Error {
    case unsupportedDevice
}

final class ARKitFaceTrackingSession: NSObject, FaceTrackingSession {
    var onUpdate: ((FaceMeasurement) -> Void)?
    var onError: ((Error) -> Void)?
    var onLightingUpdate: ((Double) -> Void)?
    var onTrackingQualityUpdate: ((Bool) -> Void)?

    let previewView = FilteredCameraPreviewView()
    private let session = ARSession()
    private var isRunning = false

    override init() {
        super.init()
        session.delegate = self
    }

    func start() {
        guard !isRunning else { return }
        guard ARFaceTrackingConfiguration.isSupported else {
            onError?(FaceTrackingError.unsupportedDevice)
            return
        }
        let configuration = ARFaceTrackingConfiguration()
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
    }

    func stop() {
        session.pause()
        isRunning = false
    }
}

extension ARKitFaceTrackingSession: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }
        // 트래킹이 유실된 프레임(손으로 가림/프레임 이탈)은 마지막 정상값을 덮어쓰지 않도록 무시한다.
        guard faceAnchor.isTracked else { return }
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

        let angleOK = Self.isAngleWithinTolerance(transform: faceAnchor.transform)

        // ARSession delegate 큐는 기본값(메인 직렬 큐)이라 바로 콜백해도 안전하다.
        onUpdate?(measurement)
        onTrackingQualityUpdate?(angleOK)
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        previewView.update(with: frame)
        if let intensity = frame.lightEstimate?.ambientIntensity {
            onLightingUpdate?(Double(intensity))
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        onError?(error)
    }

    /// 얼굴 world-space transform에서 pitch(x축)/yaw(y축) 각도를 도 단위로 구해 허용 범위를 판정한다.
    /// 쿼터니언 성분 순서는 simd_quatf.vector == (x, y, z, w).
    private static func isAngleWithinTolerance(transform: simd_float4x4) -> Bool {
        let q = simd_quatf(transform)
        let x = Double(q.vector.x)
        let y = Double(q.vector.y)
        let z = Double(q.vector.z)
        let w = Double(q.vector.w)

        // pitch: x축 회전 (atan2), yaw: y축 회전 (asin). 정면 응시 시 항등 쿼터니언 → 0도.
        let pitchRadians = atan2(2 * (w * x + y * z), 1 - 2 * (x * x + y * y))
        let sinYaw = max(-1, min(1, 2 * (w * y - z * x)))
        let yawRadians = asin(sinYaw)

        let pitchDegrees = pitchRadians * 180 / .pi
        let yawDegrees = yawRadians * 180 / .pi

        return AngleEvaluator.isWithinTolerance(pitchDegrees: pitchDegrees, yawDegrees: yawDegrees)
    }
}
