import XCTest
@testable import CoachingKit

final class SmileGuideTests: XCTestCase {
    func test_catalog_hasExactlyThreeGuides_inFixedOrder() {
        XCTAssertEqual(SmileGuideCatalog.all.map(\.id), ["soft-smile", "greeting-smile", "bright-smile"])
    }

    func test_catalog_idsAreUnique() {
        XCTAssertEqual(Set(SmileGuideCatalog.all.map(\.id)).count, SmileGuideCatalog.all.count)
    }

    func test_everyGuide_lastsFiveSeconds() {
        for guide in SmileGuideCatalog.all {
            XCTAssertEqual(guide.durationSeconds, 5, "\(guide.id)")
        }
    }

    func test_everyGuide_hasNonEmptyCopy() {
        for guide in SmileGuideCatalog.all {
            XCTAssertFalse(guide.title.isEmpty, "\(guide.id) title")
            XCTAssertFalse(guide.instruction.isEmpty, "\(guide.id) instruction")
            XCTAssertFalse(guide.notificationText.isEmpty, "\(guide.id) notificationText")
        }
    }

    /// 건강·미용 효과를 약속하는 표현(가이드라인 1.4.1)과 점수 개념이 문구에 없어야 한다.
    func test_copy_avoidsClaimAndScoreWording() {
        let banned = ["개선", "교정", "치료", "리프팅", "젊어", "점수", "행복해", "좋아집니다", "좋아져요", "예뻐"]
        for guide in SmileGuideCatalog.all {
            let copy = "\(guide.title) \(guide.instruction) \(guide.notificationText)"
            for word in banned {
                XCTAssertFalse(copy.contains(word), "\(guide.id)에 금지 표현 '\(word)'이 있다")
            }
        }
    }

    /// 걷거나 운전하며 화면을 보도록 유도하지 않는다.
    func test_notificationText_doesNotUrgeUseWhileMoving() {
        let banned = ["걷는", "걸으며", "운전", "이동 중", "횡단"]
        for guide in SmileGuideCatalog.all {
            for word in banned {
                XCTAssertFalse(guide.notificationText.contains(word), "\(guide.id)에 '\(word)'이 있다")
            }
        }
    }

    func test_guideForID_returnsMatchingGuide() {
        XCTAssertEqual(SmileGuideCatalog.guide(id: "greeting-smile").id, "greeting-smile")
        XCTAssertEqual(SmileGuideCatalog.guide(id: "bright-smile").id, "bright-smile")
    }

    func test_guideForID_fallsBackToSoftSmile_whenUnknown() {
        XCTAssertEqual(SmileGuideCatalog.guide(id: "no-such-guide").id, "soft-smile")
        XCTAssertEqual(SmileGuideCatalog.guide(id: "").id, "soft-smile")
    }

    func test_guideForID_fallsBackToSoftSmile_whenNil() {
        XCTAssertEqual(SmileGuideCatalog.guide(id: nil).id, "soft-smile")
    }

    func test_default_isSoftSmile() {
        XCTAssertEqual(SmileGuideCatalog.default.id, "soft-smile")
    }
}
