import XCTest
@testable import CoachingKit

final class ScoreCalculatorTests: XCTestCase {
    func test_delta_isZero_whenCurrentMatchesBaseline() {
        let baseline = FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.2)
        let current = FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.2)

        XCTAssertEqual(ScoreCalculator.delta(current: current, baseline: baseline), 0.0, accuracy: 0.0001)
    }

    func test_delta_isPositive_whenCurrentValuesExceedBaseline() {
        let baseline = FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1)
        let current = FaceMeasurement(mouthCornerLeft: 0.4, mouthCornerRight: 0.4, browTension: 0.4)

        XCTAssertEqual(ScoreCalculator.delta(current: current, baseline: baseline), 0.3, accuracy: 0.0001)
    }

    func test_delta_averagesMixedDirections() {
        let baseline = FaceMeasurement(mouthCornerLeft: 0.2, mouthCornerRight: 0.2, browTension: 0.2)
        let current = FaceMeasurement(mouthCornerLeft: 0.5, mouthCornerRight: 0.1, browTension: 0.2)

        // (0.3 + -0.1 + 0.0) / 3
        XCTAssertEqual(ScoreCalculator.delta(current: current, baseline: baseline), 0.2 / 3, accuracy: 0.0001)
    }

    func test_displayValue_roundsDeltaTimesTenToOneDecimal() {
        XCTAssertEqual(ScoreCalculator.displayValue(0.31), 3.1, accuracy: 0.0001)
        XCTAssertEqual(ScoreCalculator.displayValue(0.315), 3.2, accuracy: 0.0001)
        XCTAssertEqual(ScoreCalculator.displayValue(-0.12), -1.2, accuracy: 0.0001)
        XCTAssertEqual(ScoreCalculator.displayValue(0.0), 0.0, accuracy: 0.0001)
    }
}
