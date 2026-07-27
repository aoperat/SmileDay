import XCTest
@testable import CoachingKit

final class SmileReflectionTests: XCTestCase {
    func test_init_keepsTrimmedValues() {
        let reflection = SmileReflection(mood: "😊", momentNote: "  버스에서 본 강아지  ")

        XCTAssertEqual(reflection.mood, "😊")
        XCTAssertEqual(reflection.momentNote, "버스에서 본 강아지")
        XCTAssertFalse(reflection.isEmpty)
    }

    func test_init_normalizesBlankInputToNil() {
        let blank = SmileReflection(mood: "   ", momentNote: "\n\n  \t ")

        XCTAssertNil(blank.mood)
        XCTAssertNil(blank.momentNote)
        XCTAssertTrue(blank.isEmpty)
    }

    func test_init_withNoArguments_isEmpty() {
        XCTAssertTrue(SmileReflection().isEmpty)
    }

    func test_isEmpty_isFalse_whenOnlyOneFieldPresent() {
        XCTAssertFalse(SmileReflection(mood: "🙂", momentNote: nil).isEmpty)
        XCTAssertFalse(SmileReflection(mood: nil, momentNote: "좋았던 통화").isEmpty)
    }

    func test_normalizedMomentNote_keepsExactlyLimitCharacters() {
        let exact = String(repeating: "가", count: SmileReflection.momentNoteLimit)

        XCTAssertEqual(SmileReflection.normalizedMomentNote(exact)?.count, SmileReflection.momentNoteLimit)
        XCTAssertEqual(SmileReflection(momentNote: exact).momentNote, exact)
    }

    func test_normalizedMomentNote_truncatesBeyondLimit() throws {
        let tooLong = String(repeating: "나", count: SmileReflection.momentNoteLimit + 40)

        let normalized = try XCTUnwrap(SmileReflection.normalizedMomentNote(tooLong))
        XCTAssertEqual(normalized.count, SmileReflection.momentNoteLimit)
        XCTAssertEqual(normalized, String(repeating: "나", count: SmileReflection.momentNoteLimit))
        XCTAssertEqual(SmileReflection(momentNote: tooLong).momentNote?.count, SmileReflection.momentNoteLimit)
    }

    func test_normalizedMomentNote_trimsBeforeApplyingLimit() {
        let padded = "  " + String(repeating: "다", count: SmileReflection.momentNoteLimit) + "  "

        XCTAssertEqual(SmileReflection.normalizedMomentNote(padded)?.count, SmileReflection.momentNoteLimit)
    }

    func test_normalizedMomentNote_returnsNil_forNilOrEmpty() {
        XCTAssertNil(SmileReflection.normalizedMomentNote(nil))
        XCTAssertNil(SmileReflection.normalizedMomentNote(""))
        XCTAssertNil(SmileReflection.normalizedMomentNote(" \n "))
    }

    func test_equatable_comparesNormalizedValues() {
        XCTAssertEqual(
            SmileReflection(mood: "😊", momentNote: " 커피 "),
            SmileReflection(mood: "😊", momentNote: "커피")
        )
        XCTAssertEqual(SmileReflection(mood: nil, momentNote: "  "), SmileReflection())
    }
}
