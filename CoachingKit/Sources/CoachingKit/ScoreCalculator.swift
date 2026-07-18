import Foundation

public enum ScoreCalculator {
    public static func delta(current: FaceMeasurement, baseline: FaceMeasurement) -> Double {
        let mouthLeftDelta = current.mouthCornerLeft - baseline.mouthCornerLeft
        let mouthRightDelta = current.mouthCornerRight - baseline.mouthCornerRight
        let browDelta = current.browTension - baseline.browTension
        return (mouthLeftDelta + mouthRightDelta + browDelta) / 3
    }
}
