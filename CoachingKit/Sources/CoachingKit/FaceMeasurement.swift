import Foundation

public struct FaceMeasurement: Equatable, Sendable {
    public let mouthCornerLeft: Double
    public let mouthCornerRight: Double
    public let browTension: Double
    /// 블렌드셰이프 전체 (키: 앱 레이어가 주입한 ARKit rawValue). 테스트/구버전 경로에서는 빈 딕셔너리.
    public let blendShapes: [String: Double]
    /// 얼굴 각도 원본 (도 단위). 트래킹 세션이 제공하지 않으면 nil.
    public let pitchDegrees: Double?
    public let yawDegrees: Double?

    public init(
        mouthCornerLeft: Double,
        mouthCornerRight: Double,
        browTension: Double,
        blendShapes: [String: Double] = [:],
        pitchDegrees: Double? = nil,
        yawDegrees: Double? = nil
    ) {
        self.mouthCornerLeft = mouthCornerLeft
        self.mouthCornerRight = mouthCornerRight
        self.browTension = browTension
        self.blendShapes = blendShapes
        self.pitchDegrees = pitchDegrees
        self.yawDegrees = yawDegrees
    }
}
