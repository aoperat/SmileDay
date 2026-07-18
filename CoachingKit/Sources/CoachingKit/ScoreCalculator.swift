import Foundation

public enum ScoreCalculator {
    public static func delta(current: FaceMeasurement, baseline: FaceMeasurement) -> Double {
        let mouthLeftDelta = current.mouthCornerLeft - baseline.mouthCornerLeft
        let mouthRightDelta = current.mouthCornerRight - baseline.mouthCornerRight
        let browDelta = current.browTension - baseline.browTension
        return (mouthLeftDelta + mouthRightDelta + browDelta) / 3
    }

    /// 내부 delta 계수를 표시용 점수(°)로 변환. 실측 각도가 아닌 표시용 스케일이다.
    public static func displayScore(_ delta: Double) -> Int {
        Int((delta * 10).rounded())
    }
}
