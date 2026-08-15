import XCTest
@testable import SmileDay
import CoachingKit

/// 큐 문구가 실제로 카탈로그에서 해석되는지 본다.
///
/// `StringCatalogGuaranteeTests`는 카탈로그 JSON에 키가 있는지만 본다. 키가 있어도 조회 방식이
/// 틀리면 화면에 키 문자열이 뜬다 — 그 조합을 여기서 막는다. 앱 타깃이라 컴파일된 카탈로그를
/// 진짜로 읽는다.
final class SmileCueTextTests: XCTestCase {
    func test_everyCue_resolvesToCopy_notToItsKey() {
        for cue in SmileCueCatalog.all {
            let text = cue.text
            XCTAssertFalse(text.isEmpty, cue.id)
            XCTAssertNotEqual(text, "smileCue.\(cue.id)", "\(cue.id) rendered its key, not its copy")
            XCTAssertFalse(text.hasPrefix("smileCue."), cue.id)
        }
    }
}
