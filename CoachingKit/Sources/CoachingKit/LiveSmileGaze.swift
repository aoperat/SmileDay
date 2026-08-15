import Foundation
import simd

/// 얼굴이 카메라를 보고 있는지 재는 순수 기하 계산.
///
/// 화면 중앙에 있는지는 보지 않는다. 얼굴 **위치**가 아니라, 얼굴이 향하는 **방향**이
/// 카메라 쪽인지만 본다. 그래서 옆으로 비켜 앉아 고개를 돌려 카메라를 보면 0°에 가깝고,
/// 정중앙에 있어도 딴 곳을 보면 큰 값이 나온다.
public enum LiveSmileGaze {
    /// 얼굴이 향하는 방향이 "얼굴에서 카메라로 향하는 방향"에서 몇 도 벗어났는지.
    ///
    /// 카메라 축과 비교하지 않는 이유: 그러면 비켜 앉은 사용자가 카메라를 정확히 봐도
    /// 벗어난 것으로 잡힌다. 위치가 판정에 섞여 들어가면 안 된다.
    public static func offsetDegrees(
        faceTransform: simd_float4x4,
        cameraTransform: simd_float4x4
    ) -> Double {
        // 카메라 좌표계로 옮겨야 카메라가 원점이 되어 방향 계산이 단순해진다.
        let faceInCamera = simd_mul(simd_inverse(cameraTransform), faceTransform)

        let forwardColumn = faceInCamera.columns.2
        let positionColumn = faceInCamera.columns.3
        let forward = SIMD3<Float>(forwardColumn.x, forwardColumn.y, forwardColumn.z)
        let position = SIMD3<Float>(positionColumn.x, positionColumn.y, positionColumn.z)

        // 얼굴이 카메라와 겹치는 비정상 프레임에서는 방향을 정할 수 없다.
        guard simd_length(forward) > 0.0001, simd_length(position) > 0.0001 else { return 0 }

        let toCamera = simd_normalize(-position)
        let cosine = Double(simd_dot(simd_normalize(forward), toCamera))

        return acos(min(max(cosine, -1), 1)) * 180 / .pi
    }
}
