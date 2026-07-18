import Foundation
import SwiftData

@Model
public final class Baseline {
    public var capturedAt: Date
    public var mouthCornerLeft: Double
    public var mouthCornerRight: Double
    public var browTension: Double

    public init(capturedAt: Date, mouthCornerLeft: Double, mouthCornerRight: Double, browTension: Double) {
        self.capturedAt = capturedAt
        self.mouthCornerLeft = mouthCornerLeft
        self.mouthCornerRight = mouthCornerRight
        self.browTension = browTension
    }

    public var measurement: FaceMeasurement {
        FaceMeasurement(mouthCornerLeft: mouthCornerLeft, mouthCornerRight: mouthCornerRight, browTension: browTension)
    }
}
