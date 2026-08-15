import XCTest
@testable import CoachingKit

final class LiveSmileSignalEvaluatorTests: XCTestCase {
    private func sample(
        left: Double,
        right: Double? = nil,
        gazeOffset: Double = 0,
        ambient: Double? = 800
    ) -> LiveSmileSample {
        LiveSmileSample(
            mouthSmileLeft: left,
            mouthSmileRight: right ?? left,
            gazeOffsetDegrees: gazeOffset,
            ambientIntensity: ambient
        )
    }

    private func signal(_ smile: Double, neutral: Double = 0) -> Double {
        LiveSmileSignalEvaluator.signal(sample: sample(left: smile), neutralSmileMean: neutral)
    }

    // MARK: - 신호

    /// 편한 표정과 같으면 0이다. 가만히 있는 사람에게 신호를 주지 않는다.
    func test_signal_isZero_whenEqualToNeutral() {
        XCTAssertEqual(signal(0.2, neutral: 0.2), 0)
    }

    /// 편한 표정보다 낮아도 0이다. 음수 신호나 "찡그림 점수"는 없다.
    func test_signal_isZero_whenBelowNeutral() {
        XCTAssertEqual(signal(0.05, neutral: 0.3), 0)
    }

    func test_signal_isHalf_atHalfOfDisplaySpan() {
        XCTAssertEqual(signal(0.225), 0.5, accuracy: 0.0001)
    }

    func test_signal_reachesOne_atDisplaySpan() {
        XCTAssertEqual(signal(0.45), 1, accuracy: 0.0001)
    }

    func test_signal_staysAtOne_beyondDisplaySpan() {
        XCTAssertEqual(signal(1.0), 1, accuracy: 0.0001)
    }

    func test_signal_isRelativeToNeutral() {
        XCTAssertEqual(signal(0.5, neutral: 0.275), 0.5, accuracy: 0.0001)
    }

    /// 좌우가 달라도 평균만 쓴다. 비대칭은 감점 사유가 아니다.
    func test_signal_usesMeanOnly_whenAsymmetric() {
        let asymmetric = LiveSmileSignalEvaluator.signal(
            sample: sample(left: 0.45, right: 0.0),
            neutralSmileMean: 0
        )

        XCTAssertEqual(asymmetric, signal(0.225), accuracy: 0.0001)
    }

    // MARK: - 비정상 입력

    func test_signal_clampsOutOfRangeInput() {
        XCTAssertEqual(signal(-5), 0)
        XCTAssertEqual(signal(99), 1, accuracy: 0.0001)
        XCTAssertEqual(signal(0.5, neutral: -3), 1, accuracy: 0.0001)
        XCTAssertEqual(signal(0.5, neutral: 9), 0)
    }

    func test_smileMean_clampsNonFiniteInput() {
        XCTAssertEqual(LiveSmileSignalEvaluator.smileMean(sample(left: .nan, right: 1.0)), 0.5)
        XCTAssertEqual(LiveSmileSignalEvaluator.smileMean(sample(left: .infinity, right: 0)), 0)
    }

    // MARK: - 카메라를 보고 있는지

    func test_isFacingCamera_atBoundary() {
        let tolerance = LiveSmileSignalEvaluator.gazeToleranceDegrees

        XCTAssertTrue(LiveSmileSignalEvaluator.isFacingCamera(sample(left: 0.2, gazeOffset: tolerance)))
        XCTAssertTrue(LiveSmileSignalEvaluator.isFacingCamera(sample(left: 0.2, gazeOffset: -tolerance)))
    }

    func test_isFacingCamera_isFalse_justBeyondBoundary() {
        let justOutside = LiveSmileSignalEvaluator.gazeToleranceDegrees + 0.1

        XCTAssertFalse(LiveSmileSignalEvaluator.isFacingCamera(sample(left: 0.2, gazeOffset: justOutside)))
    }

    /// 정확도보다 인식률을 택했다. 곁눈으로 보며 쓰는 각도에서 끊기면 안 된다.
    /// 이 값을 좁히려면 실기기에서 인식이 끊기지 않는지 먼저 확인해야 한다.
    func test_gazeTolerance_staysGenerous() {
        XCTAssertGreaterThanOrEqual(LiveSmileSignalEvaluator.gazeToleranceDegrees, 30)
    }

    // MARK: - 조명

    func test_isTooDark_belowThreshold() {
        XCTAssertTrue(LiveSmileSignalEvaluator.isTooDark(sample(left: 0.2, ambient: 299)))
    }

    func test_isTooDark_isFalse_atOrAboveThreshold() {
        XCTAssertFalse(LiveSmileSignalEvaluator.isTooDark(sample(left: 0.2, ambient: 300)))
    }

    /// 추정값이 없는 상태를 어두움으로 단정하면 시작하자마자 조명 안내가 뜬다.
    func test_isTooDark_isFalse_whenAmbientIntensityUnknown() {
        XCTAssertFalse(LiveSmileSignalEvaluator.isTooDark(sample(left: 0.2, ambient: nil)))
    }

    // MARK: - 단계

    func test_level_boundaries() {
        XCTAssertEqual(LiveSmileLevel.containing(signal: 0), .resting)
        XCTAssertEqual(LiveSmileLevel.containing(signal: 0.099), .resting)
        XCTAssertEqual(LiveSmileLevel.containing(signal: 0.10), .starting)
        XCTAssertEqual(LiveSmileLevel.containing(signal: 0.299), .starting)
        XCTAssertEqual(LiveSmileLevel.containing(signal: 0.30), .holding)
        XCTAssertEqual(LiveSmileLevel.containing(signal: 0.599), .holding)
        XCTAssertEqual(LiveSmileLevel.containing(signal: 0.60), .clear)
        XCTAssertEqual(LiveSmileLevel.containing(signal: 1), .clear)
    }

    /// 4등분이 아니라 아래쪽이 좁고 위로 갈수록 넓어야 한다.
    func test_level_widthsGrowTowardTheTop() {
        let bounds = LiveSmileLevel.allCases.map(\.lowerBound) + [1.0]
        let widths = zip(bounds, bounds.dropFirst()).map { $1 - $0 }

        XCTAssertEqual(widths.count, 4)
        for (narrower, wider) in zip(widths, widths.dropFirst()) {
            XCTAssertLessThan(narrower, wider, "위 단계가 더 넓어야 한다")
        }
    }

    /// 편한 표정에서 살짝만 벗어나도 첫 단계로 올라가야 한다.
    func test_level_leavesRestingOnSmallChange() {
        XCTAssertEqual(LiveSmileLevel.containing(signal: 0.12), .starting)
    }

    func test_level_isOrderedByRawValue() {
        XCTAssertEqual(LiveSmileLevel.allCases, [.resting, .starting, .holding, .clear])
        XCTAssertEqual(LiveSmileLevel.allCases.map(\.rawValue), [0, 1, 2, 3])
    }
}
