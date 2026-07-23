import XCTest
@testable import CoachingKit

final class SessionMetricsAccumulatorTests: XCTestCase {
    private let keys = CuratedMetricKeys.default

    private func measurement(smileLeft: Double, smileRight: Double, blendShapes: [String: Double] = [:]) -> FaceMeasurement {
        FaceMeasurement(
            mouthCornerLeft: smileLeft,
            mouthCornerRight: smileRight,
            browTension: 0.1,
            blendShapes: blendShapes
        )
    }

    func test_smileStats_meanMaxStd_fromKnownSequence() {
        let accumulator = SessionMetricsAccumulator(keys: keys)
        let base = Date(timeIntervalSince1970: 1_000)
        // smile = (L+R)/2 → 0.2, 0.4, 0.6
        accumulator.add(measurement(smileLeft: 0.2, smileRight: 0.2), at: base)
        accumulator.add(measurement(smileLeft: 0.4, smileRight: 0.4), at: base.addingTimeInterval(0.1))
        accumulator.add(measurement(smileLeft: 0.6, smileRight: 0.6), at: base.addingTimeInterval(0.2))

        let summary = accumulator.summarize()
        XCTAssertEqual(summary.smileMean ?? -1, 0.4, accuracy: 0.0001)
        XCTAssertEqual(summary.smileMax ?? -1, 0.6, accuracy: 0.0001)
        // 표본 표준편차: sqrt(((−0.2)²+0²+0.2²)/2) = 0.2
        XCTAssertEqual(summary.smileStability ?? -1, 0.2, accuracy: 0.0001)
    }

    func test_smileAsymmetry_isMeanOfLeftMinusRight() {
        let accumulator = SessionMetricsAccumulator(keys: keys)
        let base = Date(timeIntervalSince1970: 1_000)
        accumulator.add(measurement(smileLeft: 0.5, smileRight: 0.3), at: base)
        accumulator.add(measurement(smileLeft: 0.4, smileRight: 0.4), at: base.addingTimeInterval(0.1))

        XCTAssertEqual(accumulator.summarize().smileAsymmetry ?? -1, 0.1, accuracy: 0.0001)
    }

    func test_duchenneScore_averagesFourSquintKeys_whenAllPresent() {
        let accumulator = SessionMetricsAccumulator(keys: keys)
        let shapes = [
            keys.eyeSquintLeft: 0.2, keys.eyeSquintRight: 0.4,
            keys.cheekSquintLeft: 0.6, keys.cheekSquintRight: 0.8,
        ]
        accumulator.add(measurement(smileLeft: 0.5, smileRight: 0.5, blendShapes: shapes), at: Date(timeIntervalSince1970: 1_000))

        XCTAssertEqual(accumulator.summarize().duchenneScore ?? -1, 0.5, accuracy: 0.0001)
    }

    func test_duchenneScore_isNil_whenSquintKeysMissing() {
        let accumulator = SessionMetricsAccumulator(keys: keys)
        accumulator.add(measurement(smileLeft: 0.5, smileRight: 0.5), at: Date(timeIntervalSince1970: 1_000))

        XCTAssertNil(accumulator.summarize().duchenneScore)
    }

    func test_curatedStats_trackedPerKey() {
        let accumulator = SessionMetricsAccumulator(keys: keys)
        let base = Date(timeIntervalSince1970: 1_000)
        accumulator.add(measurement(smileLeft: 0.1, smileRight: 0.1, blendShapes: [keys.jawOpen: 0.2]), at: base)
        accumulator.add(measurement(smileLeft: 0.1, smileRight: 0.1, blendShapes: [keys.jawOpen: 0.6]), at: base.addingTimeInterval(0.1))

        let stats = accumulator.summarize().stats[keys.jawOpen]
        XCTAssertEqual(stats?.mean ?? -1, 0.4, accuracy: 0.0001)
        XCTAssertEqual(stats?.max ?? -1, 0.6, accuracy: 0.0001)
    }

    func test_trackingLossCount_countsFrameGapsOverThreshold() {
        let accumulator = SessionMetricsAccumulator(keys: keys, gapThreshold: 0.5)
        let base = Date(timeIntervalSince1970: 1_000)
        accumulator.add(measurement(smileLeft: 0.1, smileRight: 0.1), at: base)
        accumulator.add(measurement(smileLeft: 0.1, smileRight: 0.1), at: base.addingTimeInterval(0.1))
        accumulator.add(measurement(smileLeft: 0.1, smileRight: 0.1), at: base.addingTimeInterval(1.0)) // 0.9초 갭 → 유실 1회

        let summary = accumulator.summarize()
        XCTAssertEqual(summary.trackingLossCount, 1)
        XCTAssertEqual(summary.durationSeconds, 1.0, accuracy: 0.0001)
    }

    func test_emptyAccumulator_summarizesToZeroDurationAndNilMetrics() {
        let summary = SessionMetricsAccumulator(keys: keys).summarize()
        XCTAssertEqual(summary.durationSeconds, 0)
        XCTAssertEqual(summary.trackingLossCount, 0)
        XCTAssertNil(summary.smileMean)
        XCTAssertTrue(summary.stats.isEmpty)
    }
}
