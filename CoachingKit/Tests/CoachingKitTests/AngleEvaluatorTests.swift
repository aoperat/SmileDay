import XCTest
@testable import CoachingKit

final class AngleEvaluatorTests: XCTestCase {
    func test_isWithinTolerance_trueWhenBothWithinLimits() {
        XCTAssertTrue(AngleEvaluator.isWithinTolerance(pitchDegrees: 0, yawDegrees: 0))
        XCTAssertTrue(AngleEvaluator.isWithinTolerance(pitchDegrees: 10, yawDegrees: -10))
    }

    func test_isWithinTolerance_trueAtExactBoundary() {
        XCTAssertTrue(AngleEvaluator.isWithinTolerance(pitchDegrees: 15, yawDegrees: 15))
        XCTAssertTrue(AngleEvaluator.isWithinTolerance(pitchDegrees: -15, yawDegrees: -15))
    }

    func test_isWithinTolerance_falseWhenPitchExceeds() {
        XCTAssertFalse(AngleEvaluator.isWithinTolerance(pitchDegrees: 15.1, yawDegrees: 0))
        XCTAssertFalse(AngleEvaluator.isWithinTolerance(pitchDegrees: -20, yawDegrees: 0))
    }

    func test_isWithinTolerance_falseWhenYawExceeds() {
        XCTAssertFalse(AngleEvaluator.isWithinTolerance(pitchDegrees: 0, yawDegrees: 15.1))
        XCTAssertFalse(AngleEvaluator.isWithinTolerance(pitchDegrees: 0, yawDegrees: -30))
    }
}
