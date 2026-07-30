import XCTest
@testable import CoachingKit

final class SmileCueTests: XCTestCase {
    func test_catalog_isNonEmptyUniqueAndNonJudgmental() {
        XCTAssertFalse(SmileCueCatalog.all.isEmpty)
        XCTAssertEqual(Set(SmileCueCatalog.all.map(\.id)).count, SmileCueCatalog.all.count)

        let banned = ["사랑받", "예뻐", "인상 개선", "교정", "치료", "더 크게", "잘 웃"]
        for cue in SmileCueCatalog.all {
            XCTAssertFalse(cue.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            for word in banned {
                XCTAssertFalse(cue.text.contains(word), "\(cue.id): \(word)")
            }
        }
    }

    func test_catalog_allowsHavingNothingPositiveToRecall() {
        XCTAssertTrue(SmileCueCatalog.all.contains { $0.text.contains("떠오르는 장면이 없어도 괜찮아요") })
    }

    func test_selector_cyclesWithoutImmediateRepeat_andPersistsCursor() {
        let store = InMemorySmileCueCursorStore()
        let selector = SmileCueSelector(store: store)

        let first = selector.next()
        let second = selector.next()
        let resumed = SmileCueSelector(store: store).next()

        XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(second, resumed)
        XCTAssertEqual(resumed, SmileCueCatalog.all[2])
    }
}
