import XCTest
@testable import CoachingKit

final class SmileGuideTests: XCTestCase {
    func test_catalog_hasFourteenGuides() {
        XCTAssertEqual(SmileGuideCatalog.builtIn.count, 14)
    }

    func test_catalog_idsAreUnique() {
        XCTAssertEqual(Set(SmileGuideCatalog.builtIn.map(\.id)).count, 14)
    }

    func test_catalog_titlesAreUnique() {
        XCTAssertEqual(Set(SmileGuideCatalog.builtIn.map(\.title)).count, 14)
    }

    func test_catalog_coversEverySlot() {
        for slot in DaySlot.allCases {
            XCTAssertFalse(SmileGuideCatalog.builtIn(in: slot).isEmpty, "\(slot) 비어 있다")
        }
    }

    func test_everyGuide_lastsFiveSeconds_andIsBuiltIn() {
        for guide in SmileGuideCatalog.builtIn {
            XCTAssertEqual(guide.durationSeconds, 5, "\(guide.id)")
            XCTAssertTrue(guide.isBuiltIn, "\(guide.id)")
        }
    }

    func test_everyGuide_hasNonEmptyCopy() {
        for guide in SmileGuideCatalog.builtIn {
            XCTAssertFalse(guide.title.isEmpty, "\(guide.id) title")
            XCTAssertFalse(guide.instruction.isEmpty, "\(guide.id) instruction")
        }
    }

    /// 건강·미용 효과를 약속하는 표현(가이드라인 1.4.1)과 점수 개념이 없어야 한다.
    func test_copy_avoidsClaimAndScoreWording() {
        let banned = ["개선", "교정", "치료", "리프팅", "젊어", "점수", "행복해", "좋아집니다", "좋아져요", "예뻐"]
        for guide in SmileGuideCatalog.builtIn {
            let copy = "\(guide.title) \(guide.instruction)"
            for word in banned {
                XCTAssertFalse(copy.contains(word), "\(guide.id)에 금지 표현 '\(word)'이 있다")
            }
        }
    }

    /// 걷거나 운전하며 화면을 보도록 유도하지 않는다. 제목에도 적용한다.
    func test_copy_doesNotUrgeUseWhileMoving() {
        let banned = ["걷는", "걸으며", "운전", "이동 중", "횡단", "퇴근길", "출근길"]
        for guide in SmileGuideCatalog.builtIn {
            let copy = "\(guide.title) \(guide.instruction)"
            for word in banned {
                XCTAssertFalse(copy.contains(word), "\(guide.id)에 '\(word)'이 있다")
            }
        }
    }

    func test_guideForID_returnsMatchingGuide() {
        XCTAssertEqual(SmileGuideCatalog.guide(id: "evening-after-work").id, "evening-after-work")
        XCTAssertEqual(SmileGuideCatalog.guide(id: "noon-before-lunch").title, "점심 먹기 전 숨 고르고 웃기")
    }

    func test_guideForID_fallsBackToDefault_whenUnknownOrNil() {
        XCTAssertEqual(SmileGuideCatalog.guide(id: "no-such-guide").id, "anytime-soft")
        XCTAssertEqual(SmileGuideCatalog.guide(id: "").id, "anytime-soft")
        XCTAssertEqual(SmileGuideCatalog.guide(id: nil).id, "anytime-soft")
    }

    func test_builtInGuideForID_returnsNil_whenUnknownOrNil() {
        XCTAssertNil(SmileGuideCatalog.builtInGuide(id: "no-such-guide"))
        XCTAssertNil(SmileGuideCatalog.builtInGuide(id: nil))
    }

    func test_default_isAnytimeSoft_andUsesDefaultInstruction() {
        XCTAssertEqual(SmileGuideCatalog.default.id, "anytime-soft")
        XCTAssertEqual(SmileGuideCatalog.default.instruction, SmileGuideCatalog.defaultInstruction)
        XCTAssertEqual(SmileGuideCatalog.default.slot, .anytime, "대체 카드는 시간대에 매이면 안 된다")
    }

    // MARK: - 옛 ID

    func test_legacyIDs_resolveToNewGuides() {
        XCTAssertEqual(SmileGuideCatalog.guide(id: "soft-smile").id, "anytime-soft")
        XCTAssertEqual(SmileGuideCatalog.guide(id: "greeting-smile").id, "morning-greeting")
        XCTAssertEqual(SmileGuideCatalog.guide(id: "bright-smile").id, "anytime-pause")
    }

    func test_legacyAliases_allPointAtRealGuides() {
        for target in SmileGuideCatalog.legacyIDAliases.values {
            XCTAssertNotNil(SmileGuideCatalog.builtIn.first { $0.id == target }, target)
        }
    }

    /// 옛 ID가 새 카드 ID와 겹치면 별칭이 자기 자신을 덮어쓴다.
    func test_legacyAliases_doNotCollideWithCurrentIDs() {
        let currentIDs = Set(SmileGuideCatalog.builtIn.map(\.id))
        for legacy in SmileGuideCatalog.legacyIDAliases.keys {
            XCTAssertFalse(currentIDs.contains(legacy), "\(legacy)")
        }
    }

    // MARK: - DaySlot

    func test_daySlot_fromHour_neverReturnsAnytime() {
        for hour in 0...23 {
            XCTAssertNotEqual(DaySlot(hour: hour), .anytime, "\(hour)시")
        }
    }

    func test_daySlot_boundaries() {
        XCTAssertEqual(DaySlot(hour: 5), .morning)
        XCTAssertEqual(DaySlot(hour: 10), .morning)
        XCTAssertEqual(DaySlot(hour: 11), .afternoon)
        XCTAssertEqual(DaySlot(hour: 16), .afternoon)
        XCTAssertEqual(DaySlot(hour: 17), .evening)
        XCTAssertEqual(DaySlot(hour: 23), .evening)
        XCTAssertEqual(DaySlot(hour: 4), .evening)
    }

    func test_daySlot_displayOrder_putsMorningFirstAnytimeLast() {
        XCTAssertEqual(DaySlot.displayOrder, [.morning, .afternoon, .evening, .anytime])
    }

    func test_daySlot_displayNamesAreDistinctAndNonEmpty() {
        let names = DaySlot.allCases.map(\.displayName)
        XCTAssertEqual(Set(names).count, DaySlot.allCases.count)
        XCTAssertFalse(names.contains(where: \.isEmpty))
    }
}
