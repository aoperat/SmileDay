import Foundation

/// 실시간 확인 모드에서 한 프레임이 넘겨주는 값.
///
/// 앱 타깃의 ARKit 경계가 이 타입으로 좁혀서 넘긴다. 전체 blend shape 사전이나
/// 카메라 프레임은 패키지로 들어오지 않는다 — 여기 없는 값은 계산할 수도, 저장할 수도 없다.
///
/// 입꼬리 신호와 자세·조명 품질만 담는다. 감정이나 인상을 추론하는 값은 담지 않는다.
public struct LiveSmileSample: Equatable, Sendable {
    /// ARKit `mouthSmileLeft` 계수. 0~1 범위를 기대하지만 검증은 계산 쪽에서 한다.
    public let mouthSmileLeft: Double
    /// ARKit `mouthSmileRight` 계수.
    public let mouthSmileRight: Double
    /// 얼굴이 향하는 방향이 "카메라를 바라보는 방향"에서 벗어난 각도(도). 0이면 정확히 마주 본다.
    ///
    /// 화면 중앙에 있는지와는 무관하다. 옆으로 비켜 앉아 고개를 돌려 카메라를 보면 이 값은 0에 가깝다.
    public let gazeOffsetDegrees: Double
    /// 주변 밝기(lux). 추정값을 아직 받지 못했으면 nil이며, nil을 어두움으로 단정하지 않는다.
    public let ambientIntensity: Double?

    public init(
        mouthSmileLeft: Double,
        mouthSmileRight: Double,
        gazeOffsetDegrees: Double,
        ambientIntensity: Double? = nil
    ) {
        self.mouthSmileLeft = mouthSmileLeft
        self.mouthSmileRight = mouthSmileRight
        self.gazeOffsetDegrees = gazeOffsetDegrees
        self.ambientIntensity = ambientIntensity
    }
}
