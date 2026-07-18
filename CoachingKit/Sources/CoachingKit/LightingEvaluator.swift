import Foundation

/// ARKit lightEstimate.ambientIntensity(약 1000 = 밝은 실내) 기반 조명 판정.
public enum LightingEvaluator {
    public static let referenceIntensity: Double = 1000
    public static let darkThreshold: Double = 300

    public static func quality(ambientIntensity: Double) -> Double {
        min(max(ambientIntensity / referenceIntensity, 0), 1)
    }

    public static func isTooDark(ambientIntensity: Double) -> Bool {
        ambientIntensity < darkThreshold
    }
}
