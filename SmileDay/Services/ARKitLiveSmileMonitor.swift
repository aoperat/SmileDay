import ARKit
import AVFoundation
import Foundation
import simd
import CoachingKit

/// TrueDepth 얼굴 추적을 `LiveSmileSample`로 좁혀서 올려보내는 경계.
///
/// 카메라 영상을 화면에 그리지 않는다. `ARFrame.capturedImage`를 읽지 않고,
/// 프리뷰용 뷰나 Metal/CoreImage 파이프라인도 만들지 않는다. 얼굴에서 꺼내는 값은
/// 좌우 입꼬리 계수와 고개 각도, 주변 밝기뿐이며 어디에도 저장하지 않는다.
final class ARKitLiveSmileMonitor: NSObject, LiveSmileMonitoring {
    var onEvent: ((LiveSmileMonitorEvent) -> Void)?

    private let session = ARSession()
    /// start() 이후 stop() 전까지만 true. stop() 뒤 늦게 도착한 콜백을 버리는 데 쓴다.
    private var isActive = false
    private var latestAmbientIntensity: Double?
    /// 얼굴이 카메라를 보고 있는지 판단하려면 카메라의 현재 위치가 필요하다.
    private var latestCameraTransform: simd_float4x4?

    // MARK: - LiveSmileMonitoring

    func start() {
        guard !isActive else { return }

        guard ARFaceTrackingConfiguration.isSupported else {
            onEvent?(.unsupportedDevice)
            return
        }

        isActive = true

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            runSession()
        case .notDetermined:
            // 사용자가 명시적으로 시작했을 때만 권한을 묻는다.
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self, self.isActive else { return }
                    guard granted else {
                        self.isActive = false
                        self.onEvent?(.permissionDenied)
                        return
                    }
                    self.runSession()
                }
            }
        default:
            isActive = false
            onEvent?(.permissionDenied)
        }
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
