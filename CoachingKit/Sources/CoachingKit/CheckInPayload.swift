import Foundation

/// 체크인 1회의 확장 데이터. CheckInSession.payload에 JSON으로 저장된다.
/// 스키마 확장은 optional 필드 추가 + payloadVersion 증가로 한다.
public struct CheckInPayload: Codable, Equatable, Sendable {
    public var blendshapesFinal: [String: Double]
    public var sessionStats: [String: MetricStats]
    public var pitchDegrees: Double?
    public var yawDegrees: Double?
    public var captureDurationSeconds: Double
    public var trackingLossCount: Int

    public static let currentVersion = 1

    public init(
        blendshapesFinal: [String: Double],
        sessionStats: [String: MetricStats],
        pitchDegrees: Double?,
        yawDegrees: Double?,
        captureDurationSeconds: Double,
        trackingLossCount: Int
    ) {
        self.blendshapesFinal = blendshapesFinal
        self.sessionStats = sessionStats
        self.pitchDegrees = pitchDegrees
        self.yawDegrees = yawDegrees
        self.captureDurationSeconds = captureDurationSeconds
        self.trackingLossCount = trackingLossCount
    }
}
