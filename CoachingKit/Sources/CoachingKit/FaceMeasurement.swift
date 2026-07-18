import Foundation

public struct FaceMeasurement: Equatable, Sendable {
    public let mouthCornerLeft: Double
    public let mouthCornerRight: Double
    public let browTension: Double

    public init(mouthCornerLeft: Double, mouthCornerRight: Double, browTension: Double) {
        self.mouthCornerLeft = mouthCornerLeft
        self.mouthCornerRight = mouthCornerRight
        self.browTension = browTension
    }
}
