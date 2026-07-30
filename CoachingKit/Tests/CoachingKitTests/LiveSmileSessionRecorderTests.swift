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
        XCTAssertEqual(result.unknownRatio, 0, "세션 길이가 0이어도 0으로 나누지 않는다")
    }

    func test_countsEachObservation() {
        let result = summary([.smiling, .smiling, .notSmiling, .unknown])

        XCTAssertEqual(result.totalSeconds, 4)
        XCTAssertEqual(result.smilingSeconds, 2)
        XCTAssertEqual(result.notSmilingSeconds, 1)
        XCTAssertEqual(result.unknownSeconds, 1)
        XCTAssertEqual(result.usableSeconds, 3)
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

    func test_isLowConfidence_atUsableSecondsBoundary() {
        let justUnder = summary(Array(repeating: .smiling, count: 59))
        let atBoundary = summary(Array(repeating: .smiling, count: 60))

        XCTAssertTrue(justUnder.isLowConfidence, "59초는 짧다")
        XCTAssertFalse(atBoundary.isLowConfidence, "60초는 낮은 신뢰가 아니다")
    }

    func test_isLowConfidence_whenUnknownExceedsHalf() {
        // 판정 가능 60초 + unknown 61초 → unknown 비율 약 50.4%
        let tooMuchUnknown = summary(
            Array(repeating: .smiling, count: 60) + Array(repeating: .unknown, count: 61)
        )
        // 판정 가능 60초 + unknown 60초 → 정확히 50%, 초과가 아니다
        let exactlyHalf = summary(
            Array(repeating: .smiling, count: 60) + Array(repeating: .unknown, count: 60)
        )

        XCTAssertTrue(tooMuchUnknown.isLowConfidence)
        XCTAssertFalse(exactlyHalf.isLowConfidence, "초과일 때만 낮은 신뢰다")
    }
}
