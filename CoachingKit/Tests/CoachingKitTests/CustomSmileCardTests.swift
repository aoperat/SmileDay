import XCTest
@testable import CoachingKit

final class CustomSmileCardTests: XCTestCase {
    func test_guide_usesTypedInstruction() {
        let card = CustomSmileCard(title: "엘리베이터에서 웃기", instructionText: "문이 닫히면 한 번 웃어보세요.", slot: .anytime)

        XCTAssertEqual(card.guide.instruction, "문이 닫히면 한 번 웃어보세요.")
        XCTAssertEqual(card.guide.title, "엘리베이터에서 웃기")
        XCTAssertFalse(card.guide.isBuiltIn)
    }

    func test_guide_fallsBackToDefaultInstruction_whenNil() {
        let card = CustomSmileCard(title: "엘리베이터에서 웃기", instructionText: nil, slot: .anytime)

        XCTAssertEqual(card.guide.instruction, SmileGuideCatalog.defaultInstruction)
    }

    func test_guide_lastsFiveSeconds() {
        XCTAssertEqual(CustomSmileCard(title: "제목", slot: .morning).guide.durationSeconds, 5)
    }

    func test_guide_keepsSlot() {
        XCTAssertEqual(CustomSmileCard(title: "제목", slot: .evening).guide.slot, .evening)
    }

    func test_guide_idMatchesCardID() {
        let card = CustomSmileCard(title: "제목", slot: .anytime)

        XCTAssertEqual(card.guide.id, card.id)
    }

    func test_slot_roundTrips() {
        for slot in DaySlot.allCases {
            XCTAssertEqual(CustomSmileCard(title: "제목", slot: slot).slot, slot)
        }
    }

    func test_slot_fallsBackToAnytime_whenRawValueUnknown() {
        let card = CustomSmileCard(title: "제목", slot: .morning)

        card.slotRawValue = "midnight"

        XCTAssertEqual(card.slot, .anytime)
    }

    func test_slot_setter_updatesRawValue() {
        let card = CustomSmileCard(title: "제목", slot: .morning)

        card.slot = .evening

        XCTAssertEqual(card.slotRawValue, "evening")
    }

    func test_schema_containsCustomSmileCard_andKeepsLegacyModels() {
        let names = PersistenceSchema.models.map { String(describing: $0) }

        for expected in ["Baseline", "CheckInSession", "ReminderSetting", "CareSession", "SmileMoment", "CustomSmileCard"] {
            XCTAssertTrue(names.contains(expected), expected)
        }
    }
}
