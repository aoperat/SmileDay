import Foundation

/// 측정 시점 얼굴 각도(pitch/yaw, 도 단위)가 신뢰 가능한 정면 범위인지 판정.
public enum AngleEvaluator {
    public static let maxPitchDegrees: Double = 15
    public static let maxYawDegrees: Double = 15

    public static func isWithinTolerance(pitchDegrees: Double, yawDegrees: Double) -> Bool {
        abs(pitchDegrees) <= maxPitchDegrees && abs(yawDegrees) <= maxYawDegrees
    }
}
