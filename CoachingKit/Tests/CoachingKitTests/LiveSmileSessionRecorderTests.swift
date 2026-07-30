import XCTest
@testable import CoachingKit

final class LiveSmileSessionSummaryTests: XCTestCase {
    private func summary(_ timeline: [LiveSmileObservation]) -> LiveSmileSessionSummary {
        LiveSmileSessionSummary(timeline: timeline)
    }

    func test_emptySession_hasNoRatioAndDoesNotDivideByZero() {
        let result = summary([])

        XCTAssertEqual(result.totalSeconds, 0)
        XCTAssertNil(result.smilingRatio, "판정 가능 시간이 0이면 비율이 없다")
        XCTAssertEqual(result.unknownRatio, 0, "세션 길이가 0이어도 NaN을 내보내지 않는다")
    }

    /// 세 값을 모두 다르게 둔다. 세는 대상이 뒤바뀌면 이 테스트 하나로도 잡힌다.
    func test_countsEachObservation() {
        let result = summary([.smiling, .smiling, .smiling, .notSmiling, .notSmiling, .unknown])

        XCTAssertEqual(result.totalSeconds, 6)
        XCTAssertEqual(result.smilingSeconds, 3)
        XCTAssertEqual(result.notSmilingSeconds, 2)
        XCTAssertEqual(result.unknownSeconds, 1)
        XCTAssertEqual(result.usableSeconds, 5)
    }

    /// 분모에서 unknown을 뺀다. 자리를 비운 시간이 낮은 숫자로 돌아오면 안 된다.
    func test_ratioExcludesUnknownFromDenominator() throws {
        let result = summary([.smiling, .notSmiling, .unknown, .unknown])

        XCTAssertEqual(try XCTUnwrap(result.smilingRatio), 0.5, accuracy: 0.0001)
        XCTAssertEqual(result.unknownRatio, 0.5, accuracy: 0.0001)
    }

    /// unknown만 있으면 판정 가능 시간이 0이다.
    func test_ratioIsNil_whenEverythingUnknown() {
        let result = summary([.unknown, .unknown])

        XCTAssertNil(result.smilingRatio)
        XCTAssertEqual(result.unknownRatio, 1, accuracy: 0.0001)
    }

    /// 한 번도 웃지 않은 것과 측정하지 못한 것은 다르다. 전자는 0%, 후자는 값이 없다.
    func test_ratioIsZero_whenUserNeverSmiled() throws {
        let result = summary([.notSmiling, .notSmiling])

        XCTAssertEqual(try XCTUnwrap(result.smilingRatio), 0, accuracy: 0.0001)
    }

    // MARK: - 신뢰 상태

    /// 측정이 없으면 신뢰 여부를 말하지 않는다. 없는 숫자를 두고 "참고만 해주세요"가
    /// 함께 뜨는 조합을 막는 것이 이 상태의 존재 이유다.
    func test_confidence_isNoMeasurement_whenNothingUsable() {
        XCTAssertEqual(summary([]).confidence, .noMeasurement)
        XCTAssertEqual(summary([.unknown, .unknown]).confidence, .noMeasurement)
    }

    func test_confidence_atUsableSecondsBoundary() {
        let justUnder = summary(Array(repeating: .smiling, count: 59))
        let atBoundary = summary(Array(repeating: .smiling, count: 60))

        XCTAssertEqual(justUnder.confidence, .low(ratio: 1), "59초는 짧다")
        XCTAssertEqual(atBoundary.confidence, .reliable(ratio: 1), "60초는 믿는다")
    }

    func test_confidence_whenUnknownExceedsHalf() {
        // 판정 가능 60초 + unknown 61초 → unknown 비율 약 50.4%
        let tooMuchUnknown = summary(
            Array(repeating: .smiling, count: 60) + Array(repeating: .unknown, count: 61)
        )
        // 판정 가능 60초 + unknown 60초 → 정확히 50%, 초과가 아니다
        let exactlyHalf = summary(
            Array(repeating: .smiling, count: 60) + Array(repeating: .unknown, count: 60)
        )

        XCTAssertEqual(tooMuchUnknown.confidence, .low(ratio: 1))
        XCTAssertEqual(exactlyHalf.confidence, .reliable(ratio: 1), "초과일 때만 낮은 신뢰다")
    }
}
