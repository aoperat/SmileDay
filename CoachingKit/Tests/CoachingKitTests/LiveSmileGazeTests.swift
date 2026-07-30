import XCTest
import simd
@testable import CoachingKit

/// 핵심 요구: **화면 중앙에서 벗어나도 인식돼야 한다.**
/// 판정에 들어가는 것은 얼굴 위치가 아니라 얼굴이 향하는 방향뿐이다.
final class LiveSmileGazeTests: XCTestCase {
    /// 카메라는 원점에 두고 -Z를 본다.
    private let cameraTransform = matrix_identity_float4x4

    /// 필요한 두 열(방향, 위치)만 채운 얼굴 transform.
    private func face(at position: SIMD3<Float>, facing forward: SIMD3<Float>) -> simd_float4x4 {
        var transform = matrix_identity_float4x4
        transform.columns.2 = SIMD4<Float>(simd_normalize(forward), 0)
        transform.columns.3 = SIMD4<Float>(position, 1)
        return transform
    }

    /// 그 위치에서 카메라(원점)를 정확히 바라보는 방향.
    private func lookingAtCamera(from position: SIMD3<Float>) -> SIMD3<Float> {
        simd_normalize(-position)
    }

    private func offset(_ transform: simd_float4x4) -> Double {
        LiveSmileGaze.offsetDegrees(faceTransform: transform, cameraTransform: cameraTransform)
    }

    // MARK: - 위치와 무관함

    func test_offset_isZero_whenFacingCameraFromCenter() {
        let position = SIMD3<Float>(0, 0, -0.5)

        let degrees = offset(face(at: position, facing: lookingAtCamera(from: position)))

        XCTAssertEqual(degrees, 0, accuracy: 0.5)
    }

    /// 크게 비켜 앉아도 카메라를 보고 있으면 0에 가까워야 한다.
    func test_offset_isZero_whenFacingCameraFromFarOffCenter() {
        for position in [
            SIMD3<Float>(0.6, 0, -0.5),    // 오른쪽으로 60cm
            SIMD3<Float>(-0.6, 0, -0.5),   // 왼쪽으로 60cm
            SIMD3<Float>(0, 0.5, -0.5),    // 위로 50cm
            SIMD3<Float>(0, -0.5, -0.5),   // 아래로 50cm
            SIMD3<Float>(0.5, 0.4, -0.4),  // 대각선
        ] {
            let degrees = offset(face(at: position, facing: lookingAtCamera(from: position)))

            XCTAssertEqual(degrees, 0, accuracy: 0.5, "\(position)에서 카메라를 보면 0이어야 한다")
        }
    }

    /// 비켜 앉아 카메라를 보는 경우가 허용 범위 안이어야 한다 — 이게 깨지면 인식이 끊긴다.
    func test_offCenterButFacingCamera_passesTolerance() {
        for position in [
            SIMD3<Float>(0.8, 0, -0.4),
            SIMD3<Float>(-0.8, 0, -0.4),
            SIMD3<Float>(0, 0.6, -0.3),
        ] {
            let sample = LiveSmileSample(
                mouthSmileLeft: 0.2,
                mouthSmileRight: 0.2,
                gazeOffsetDegrees: offset(face(at: position, facing: lookingAtCamera(from: position)))
            )

            XCTAssertTrue(
                LiveSmileSignalEvaluator.isFacingCamera(sample),
                "\(position)에서 카메라를 보고 있는데 인식이 끊기면 안 된다"
            )
        }
    }

    // MARK: - 방향은 반영됨

    /// 정중앙에 있어도 딴 곳을 보면 큰 값이 나와야 한다.
    func test_offset_isLarge_whenLookingAwayFromCenter() {
        let position = SIMD3<Float>(0, 0, -0.5)

        // 카메라는 +Z 쪽에 있는데 옆(+X)을 본다.
        let degrees = offset(face(at: position, facing: SIMD3<Float>(1, 0, 0)))

        XCTAssertEqual(degrees, 90, accuracy: 1)
    }

    /// 비켜 앉아 카메라를 지나쳐 정면을 보면 벗어난 것으로 잡혀야 한다.
    func test_offset_isLarge_whenOffCenterAndLookingStraightPastTheCamera() {
        let position = SIMD3<Float>(0.6, 0, -0.5)

        let degrees = offset(face(at: position, facing: SIMD3<Float>(0, 0, 1)))

        XCTAssertGreaterThan(degrees, 45, "카메라를 안 보고 있으면 커야 한다")
    }

    func test_offset_growsAsHeadTurnsAway() {
        let position = SIMD3<Float>(0, 0, -0.5)
        let toCamera = lookingAtCamera(from: position)

        var previous = -1.0
        for angle in stride(from: 0.0, through: 80.0, by: 20.0) {
            let radians = Float(angle * .pi / 180)
            let turned = SIMD3<Float>(
                sin(radians) * toCamera.z + cos(radians) * toCamera.x,
                toCamera.y,
                cos(radians) * toCamera.z - sin(radians) * toCamera.x
            )
            let degrees = offset(face(at: position, facing: turned))

            XCTAssertGreaterThan(degrees, previous, "\(angle)°에서 더 커져야 한다")
            previous = degrees
        }
    }

    // MARK: - 비정상 입력

    /// 얼굴이 카메라와 겹치는 프레임에서는 방향을 정할 수 없다.
    func test_offset_isZero_whenFaceIsAtCameraOrigin() {
        let degrees = offset(face(at: SIMD3<Float>(0, 0, 0), facing: SIMD3<Float>(0, 0, 1)))

        XCTAssertEqual(degrees, 0)
    }

    /// 카메라가 움직여도 두 transform의 관계만 본다.
    func test_offset_isIndependentOfWorldOrigin() {
        var movedCamera = matrix_identity_float4x4
        movedCamera.columns.3 = SIMD4<Float>(3, 1, 7, 1)

        // 카메라 앞 0.5m에서 카메라를 바라보는 얼굴.
        var movedFace = matrix_identity_float4x4
        movedFace.columns.2 = SIMD4<Float>(0, 0, 1, 0)
        movedFace.columns.3 = SIMD4<Float>(3, 1, 6.5, 1)

        let degrees = LiveSmileGaze.offsetDegrees(
            faceTransform: movedFace,
            cameraTransform: movedCamera
        )

        XCTAssertEqual(degrees, 0, accuracy: 0.5)
    }
}
