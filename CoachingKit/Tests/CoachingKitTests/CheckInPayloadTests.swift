import XCTest
@testable import CoachingKit

final class CheckInPayloadTests: XCTestCase {
    func test_encodeDecode_roundTrip() throws {
        let payload = CheckInPayload(
            blendshapesFinal: ["mouthSmile_L": 0.42, "jawOpen": 0.1],
            sessionStats: ["smile": MetricStats(mean: 0.4, max: 0.6, std: 0.2)],
            pitchDegrees: 3.5,
            yawDegrees: -1.2,
            captureDurationSeconds: 12.5,
            trackingLossCount: 2
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(CheckInPayload.self, from: data)

        XCTAssertEqual(decoded, payload)
    }

    func test_decode_missingOptionalAngles_succeeds() throws {
        let json = """
        {"blendshapesFinal":{},"sessionStats":{},"captureDurationSeconds":0,"trackingLossCount":0}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(CheckInPayload.self, from: json)
        XCTAssertNil(decoded.pitchDegrees)
        XCTAssertNil(decoded.yawDegrees)
    }
}
