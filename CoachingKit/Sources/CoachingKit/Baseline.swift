import Foundation
import SwiftData

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

    public var measurement: FaceMeasurement {
        FaceMeasurement(mouthCornerLeft: mouthCornerLeft, mouthCornerRight: mouthCornerRight, browTension: browTension)
    }
}
