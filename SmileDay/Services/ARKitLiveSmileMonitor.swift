import ARKit
import AVFoundation
import Foundation
import simd
import CoachingKit

/// TrueDepth 얼굴 추적을 `LiveSmileSample`로 좁혀서 올려보내는 경계.
///
/// 프레임마다 얼굴에서 꺼내는 값은 좌우 입꼬리 계수와 고개 각도, 주변 밝기뿐이다.
/// `ARFrame.capturedImage`는 어디서도 읽지 않는다 — 프레임의 픽셀을 꺼내는 경로 자체가 없다.
/// 남는 절대 조항은 하나다 — 어느 값도 저장하거나 전송하지 않는다.
final class ARKitLiveSmileMonitor: NSObject, LiveSmileMonitoring {
    var onEvent: ((LiveSmileMonitorEvent) -> Void)?

    private let session = ARSession()
    /// start() 이후 stop() 전까지만 true. stop() 뒤 늦게 도착한 콜백을 버리는 데 쓴다.
    private var isActive = false
    private var latestAmbientIntensity: Double?
    /// 얼굴이 카메라를 보고 있는지 판단하려면 카메라의 현재 위치가 필요하다.
    private var latestCameraTransform: simd_float4x4?

    // MARK: - LiveSmileMonitoring

    /// 이 기기가 TrueDepth 얼굴 추적을 할 수 있는지. 못 하면 권한을 물을 이유도 없다.
    var isFaceTrackingSupported: Bool { ARFaceTrackingConfiguration.isSupported }

    var cameraPermission: LiveSmileCameraPermission {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    /// 세션을 켜기 전에 권한을 끝낸다.
    ///
    /// 예전에는 `start()` 안에서 물었는데, 권한 대화상자가 뜨는 동안 앱이 inactive가 되고
    /// 화면은 그것을 "카메라를 쓰다 벗어났다"로 읽어 세션을 멈췄다. 그래서 처음 쓰는 사람이
    /// 허용을 누르고 돌아오면 측정 화면 대신 "측정을 멈췄어요"를 봤다.
    func requestCameraPermission() async -> LiveSmileCameraPermission {
        guard cameraPermission == .notDetermined else { return cameraPermission }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .granted : .denied
    }

    func start() {
        guard !isActive else { return }

        guard isFaceTrackingSupported else {
            onEvent?(.unsupportedDevice)
            return
        }

        // 권한은 이 지점 전에 이미 정해져 있다. 여기서 묻지 않는다.
        guard cameraPermission == .granted else {
            onEvent?(.permissionDenied)
            return
        }

        isActive = true
        runSession()
    }

    /// 프리뷰가 그릴 세션. 사용자가 카메라 화면을 켰을 때만 쓰인다.
    var previewSession: ARSession { session }

    /// 프리뷰 뷰가 세션을 넘겨받으며 delegate를 바꿔도 샘플 전달이 끊기지 않게 되돌린다.
    func reassertSampleDelegate() {
        guard isActive else { return }
        session.delegate = self
        session.delegateQueue = .main
    }

    func stop() {
        guard isActive else { return }

        isActive = false
        session.delegate = nil
        session.pause()
        latestAmbientIntensity = nil
        latestCameraTransform = nil
    }

    private func runSession() {
        let configuration = ARFaceTrackingConfiguration()
        configuration.maximumNumberOfTrackedFaces = 1
        configuration.isLightEstimationEnabled = true

        session.delegate = self
        // 이벤트를 메인에서 전달한다는 프로토콜 계약을 여기서 지킨다.
        session.delegateQueue = .main
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    private func emit(_ event: LiveSmileMonitorEvent) {
        guard isActive else { return }
        onEvent?(event)
    }
}

// MARK: - ARSessionDelegate

extension ARKitLiveSmileMonitor: ARSessionDelegate {
    /// 카메라 자세와 밝기 추정값만 읽는다. `frame.capturedImage`는 건드리지 않는다.
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        latestCameraTransform = frame.camera.transform
        if let ambientIntensity = frame.lightEstimate?.ambientIntensity {
            latestAmbientIntensity = Double(ambientIntensity)
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }

        guard face.isTracked else {
            emit(.faceLost)
            return
        }
        guard let sample = makeSample(from: face) else { return }
        emit(.sample(sample))
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard anchors.contains(where: { $0 is ARFaceAnchor }) else { return }
        emit(.faceLost)
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        emit(.sessionFailed)
    }

    func sessionWasInterrupted(_ session: ARSession) {
        emit(.sessionFailed)
    }

    /// 필요한 두 계수와 시선 각도만 꺼낸다. 나머지 blend shape는 읽지 않는다.
    ///
    /// 카메라 자세를 아직 못 받았으면 각도를 지어내지 않고 이 프레임을 버린다.
    private func makeSample(from face: ARFaceAnchor) -> LiveSmileSample? {
        guard let left = face.blendShapes[.mouthSmileLeft]?.doubleValue,
              let right = face.blendShapes[.mouthSmileRight]?.doubleValue,
              let cameraTransform = latestCameraTransform else {
            return nil
        }

        // 각도 계산은 순수 기하라 패키지에 있다. 여기서는 값만 넘긴다.
        return LiveSmileSample(
            mouthSmileLeft: left,
            mouthSmileRight: right,
            gazeOffsetDegrees: LiveSmileGaze.offsetDegrees(
                faceTransform: face.transform,
                cameraTransform: cameraTransform
            ),
            ambientIntensity: latestAmbientIntensity
        )
    }
}
