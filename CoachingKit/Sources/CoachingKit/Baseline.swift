import Foundation
import SwiftData

/// 기준선 촬영 시절의 기록. 새 흐름은 얼굴을 측정하지 않아 더 쓰지 않지만,
/// 기존 저장소를 열려면 스키마에 남아 있어야 한다.
@Model
public final class Baseline {
    public var capturedAt: Date
    public var mouthCornerLeft: Double
    public var mouthCornerRight: Double
    public var browTension: Double
    public var lightingQuality: Double = 1.0
    public var deviceAngleOK: Bool = true

    public init(
        capturedAt: Date,
        mouthCornerLeft: Double,
        mouthCornerRight: Double,
        browTension: Double,
        lightingQuality: Double,
        deviceAngleOK: Bool
    ) {
        self.capturedAt = capturedAt
        self.mouthCornerLeft = mouthCornerLeft
        self.mouthCornerRight = mouthCornerRight
        self.browTension = browTension
        self.lightingQuality = lightingQuality
        self.deviceAngleOK = deviceAngleOK
    }
}
