import XCTest
@testable import CoachingKit

final class BaselineTests: XCTestCase {
    private func makeBaseline(capturedAt: Date) -> Baseline {
        Baseline(
            capturedAt: capturedAt,
            mouthCornerLeft: 0,
            mouthCornerRight: 0,
            browTension: 0,
            lightingQuality: 1.0,
            deviceAngleOK: true
        )
    }

    func test_ageWeeks_computesWholeWeeksSinceCapture() {
        let now = Date()
        let sixWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -6, to: now)!
        let baseline = makeBaseline(capturedAt: sixWeeksAgo)

        XCTAssertEqual(baseline.ageWeeks(now: now), 6)
    }

    func test_ageWeeks_neverNegative() {
        let now = Date()
        let baseline = makeBaseline(capturedAt: now)

        XCTAssertEqual(baseline.ageWeeks(now: now), 0)
    }

    func test_isOverdueForReset_falseUnderThreshold() {
        let now = Date()
        let threeWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -3, to: now)!
        let baseline = makeBaseline(capturedAt: threeWeeksAgo)

        XCTAssertFalse(baseline.isOverdueForReset(now: now))
    }

    func test_isOverdueForReset_trueAtThresholdWeeksOrMore() {
        let now = Date()
        let fourWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: now)!
        let baseline = makeBaseline(capturedAt: fourWeeksAgo)

        XCTAssertTrue(baseline.isOverdueForReset(now: now))
    }
}
