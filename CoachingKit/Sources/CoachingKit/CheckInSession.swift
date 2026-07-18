import Foundation
import SwiftData

@Model
public final class CheckInSession {
    public var date: Date
    public var mouthCornerLeft: Double
    public var mouthCornerRight: Double
    public var browTension: Double
    public var lightingQuality: Double
    public var deviceAngleOK: Bool
    public var scoreDelta: Double

    public init(
        date: Date,
        mouthCornerLeft: Double,
        mouthCornerRight: Double,
        browTension: Double,
        lightingQuality: Double,
        deviceAngleOK: Bool,
        scoreDelta: Double
    ) {
        self.date = date
        self.mouthCornerLeft = mouthCornerLeft
        self.mouthCornerRight = mouthCornerRight
        self.browTension = browTension
        self.lightingQuality = lightingQuality
        self.deviceAngleOK = deviceAngleOK
        self.scoreDelta = scoreDelta
    }
}
