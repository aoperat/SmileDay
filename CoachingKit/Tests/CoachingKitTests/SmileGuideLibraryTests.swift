import XCTest
import SwiftData
@testable import CoachingKit

final class SmileGuideLibraryTests: XCTestCase {
    private func makeLibrary() throws -> (SmileGuideLibrary, InMemoryHiddenSmileGuideStore) {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let hidden = InMemoryHiddenSmileGuideStore()
        return (SmileGuideLibrary(modelContext: ModelContext(container), hiddenStore: hidden), hidden)
    }

    // MARK: - 목록

    func test_visibleGuides_startsWithEveryBuiltInCard() throws {
        let (library, _) = try makeLibrary()

        XCTAssertEqual(try library.visibleGuides().count, 14)
    }

    func test_visibleGuides_areOrderedBySlot() throws {
        let (library, _) = try makeLibrary()

        let slots = try library.visibleGuides().map(\.slot.sortIndex)

        XCTAssertEqual(slots, slots.sorted(), "아침 → 낮 → 저녁 → 언제든 순이어야 한다")
    }

    func test_visibleGuides_placeCustomCardAfterBuiltInsOfSameSlot() throws {
        let (library, _) = try makeLibrary()
        try library.addCustom(title: "엘리베이터에서 웃기", instruction: nil, slot: .morning)

        let morning = try library.visibleGuides().filter { $0.slot == .morning }

        XCTAssertEqual(morning.last?.title, "엘리베이터에서 웃기")
        XCTAssertTrue(morning.dropLast().allSatisfy(\.isBuiltIn))
    }

    func test_visibleGuides_keepCustomCardsInCreationOrder() throws {
        let (library, _) = try makeLibrary()
        try library.addCustom(title: "첫째", instruction: nil, slot: .anytime)
        try library.addCustom(title: "둘째", instruction: nil, slot: .anytime)

        let custom = try library.visibleGuides().filter { !$0.isBuiltIn }

        XCTAssertEqual(custom.map(\.title), ["첫째", "둘째"])
    }

    // MARK: - 추가

    func test_addCustom_appearsInVisibleGuides() throws {
        let (library, _) = try makeLibrary()

        let added = try library.addCustom(title: "엘리베이터에서 웃기", instruction: nil, slot: .anytime)

        XCTAssertEqual(try library.visibleGuides().count, 15)
        XCTAssertEqual(library.guide(id: added.id).title, "엘리베이터에서 웃기")
    }

    func test_addCustom_withoutInstruction_usesDefaultInstruction() throws {
        let (library, _) = try makeLibrary()

        let added = try library.addCustom(title: "엘리베이터에서 웃기", instruction: nil, slot: .anytime)

        XCTAssertEqual(added.instruction, SmileGuideCatalog.defaultInstruction)
    }

    func test_addCustom_withBlankInstruction_usesDefaultInstruction() throws {
        let (library, _) = try makeLibrary()

        let added = try library.addCustom(title: "엘리베이터에서 웃기", instruction: "   ", slot: .anytime)

        XCTAssertEqual(added.instruction, SmileGuideCatalog.defaultInstruction)
    }

    func test_addCustom_trimsTitleAndInstruction() throws {
        let (library, _) = try makeLibrary()

        let added = try library.addCustom(title: "  엘리베이터에서 웃기  ", instruction: "  문이 닫히면 웃어보세요.  ", slot: .anytime)

        XCTAssertEqual(added.title, "엘리베이터에서 웃기")
        XCTAssertEqual(added.instruction, "문이 닫히면 웃어보세요.")
    }

    func test_addCustom_rejectsBlankTitle() throws {
        let (library, _) = try makeLibrary()

        XCTAssertThrowsError(try library.addCustom(title: "   ", instruction: nil, slot: .anytime)) { error in
            XCTAssertEqual(error as? SmileGuideLibraryError, .blankTitle)
        }
        XCTAssertEqual(try library.visibleGuides().count, 14)
    }

    func test_addCustom_isNotBuiltIn() throws {
        let (library, _) = try makeLibrary()

        let added = try library.addCustom(title: "엘리베이터에서 웃기", instruction: nil, slot: .anytime)

        XCTAssertFalse(added.isBuiltIn)
    }

    // MARK: - 삭제와 숨기기

    func test_removeCustom_dropsItFromList() throws {
        let (library, _) = try makeLibrary()
        let added = try library.addCustom(title: "엘리베이터에서 웃기", instruction: nil, slot: .anytime)

        try library.removeCustom(id: added.id)

        XCTAssertEqual(try library.visibleGuides().count, 14)
        XCTAssertEqual(library.guide(id: added.id).id, SmileGuideCatalog.default.id,
                       "완전히 사라진 카드는 기본 카드로 떨어진다")
    }

    func test_removeCustom_isNoOp_whenIDUnknown() throws {
        let (library, _) = try makeLibrary()

        XCTAssertNoThrow(try library.removeCustom(id: "no-such-card"))
        XCTAssertEqual(try library.visibleGuides().count, 14)
    }

    func test_removeCustom_doesNotTouchBuiltIns() throws {
        let (library, hidden) = try makeLibrary()

        try library.removeCustom(id: "morning-coffee")

        XCTAssertEqual(try library.visibleGuides().count, 14)
        XCTAssertTrue(hidden.hiddenGuideIDs.isEmpty)
    }

    func test_hideBuiltIn_removesFromListButKeepsNameLookup() throws {
        let (library, _) = try makeLibrary()

        library.hideBuiltIn(id: "morning-coffee")

        XCTAssertEqual(try library.visibleGuides().count, 13)
        XCTAssertFalse(try library.visibleGuides().contains { $0.id == "morning-coffee" })
        XCTAssertEqual(library.guide(id: "morning-coffee").title, "첫 커피 마시며 숨 고르기",
                       "숨긴 카드도 이름은 찾아져야 한다")
    }

    func test_hiddenBuiltInGuides_listsWhatWasHidden() throws {
        let (library, _) = try makeLibrary()
        library.hideBuiltIn(id: "morning-coffee")
        library.hideBuiltIn(id: "noon-before-call")

        XCTAssertEqual(Set(library.hiddenBuiltInGuides().map(\.id)), ["morning-coffee", "noon-before-call"])
    }

    func test_restoreBuiltIn_bringsItBack() throws {
        let (library, _) = try makeLibrary()
        library.hideBuiltIn(id: "morning-coffee")

        library.restoreBuiltIn(id: "morning-coffee")

        XCTAssertEqual(try library.visibleGuides().count, 14)
        XCTAssertTrue(library.hiddenBuiltInGuides().isEmpty)
    }

    func test_hideBuiltIn_ignoresUnknownID() throws {
        let (library, hidden) = try makeLibrary()

        library.hideBuiltIn(id: "no-such-card")

        XCTAssertTrue(hidden.hiddenGuideIDs.isEmpty)
    }

    /// 기본 카드를 전부 숨겨도 내 카드만 남고 조회는 계속 동작한다.
    func test_hidingEveryBuiltIn_leavesOnlyCustomCards() throws {
        let (library, _) = try makeLibrary()
        let mine = try library.addCustom(title: "엘리베이터에서 웃기", instruction: nil, slot: .anytime)
        for guide in SmileGuideCatalog.builtIn {
            library.hideBuiltIn(id: guide.id)
        }

        XCTAssertEqual(try library.visibleGuides().map(\.id), [mine.id])
    }

    // MARK: - 조회

    func test_guideForID_findsCustomCard() throws {
        let (library, _) = try makeLibrary()
        let added = try library.addCustom(title: "엘리베이터에서 웃기", instruction: "문이 닫히면 웃어보세요.", slot: .anytime)

        let found = library.guide(id: added.id)

        XCTAssertEqual(found.title, "엘리베이터에서 웃기")
        XCTAssertEqual(found.instruction, "문이 닫히면 웃어보세요.")
    }

    func test_guideForID_resolvesLegacyIDs() throws {
        let (library, _) = try makeLibrary()

        XCTAssertEqual(library.guide(id: "soft-smile").id, "anytime-soft")
        XCTAssertEqual(library.guide(id: "greeting-smile").id, "morning-greeting")
        XCTAssertEqual(library.guide(id: "bright-smile").id, "anytime-pause")
    }

    func test_guideForID_fallsBackToDefault_whenNilOrUnknown() throws {
        let (library, _) = try makeLibrary()

        XCTAssertEqual(library.guide(id: nil).id, "anytime-soft")
        XCTAssertEqual(library.guide(id: "no-such-card").id, "anytime-soft")
    }
}
