import XCTest
@testable import CoachingKit

final class LightingEvaluatorTests: XCTestCase {
    func test_quality_normalizesAmbientIntensity() {
        XCTAssertEqual(LightingEvaluator.quality(ambientIntensity: 1000), 1.0, accuracy: 0.001)
        XCTAssertEqual(LightingEvaluator.quality(ambientIntensity: 500), 0.5, accuracy: 0.001)
        XCTAssertEqual(LightingEvaluator.quality(ambientIntensity: 2000), 1.0, accuracy: 0.001)
        XCTAssertEqual(LightingEvaluator.quality(ambientIntensity: 0), 0.0, accuracy: 0.001)
    }

    func test_isTooDark_belowThreshold() {
        XCTAssertTrue(LightingEvaluator.isTooDark(ambientIntensity: 299))
        XCTAssertFalse(LightingEvaluator.isTooDark(ambientIntensity: 300))
    }
}
