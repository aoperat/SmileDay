import XCTest
@testable import CoachingKit

final class SmileCueTests: XCTestCase {
    func test_catalog_isNonEmptyAndUnique() {
        XCTAssertFalse(SmileCueCatalog.all.isEmpty)
        XCTAssertEqual(Set(SmileCueCatalog.all.map(\.id)).count, SmileCueCatalog.all.count)
    }
    // 금지어·공백·"떠올릴 게 없어도 괜찮다" 불변식은 StringCatalogGuaranteeTests로 옮겼다 —
    // 문구가 앱 카탈로그로 갔기 때문이다.

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
