import XCTest
@testable import CoachingKit

final class SmileMomentTests: XCTestCase {
    func test_init_storesSourceRawValue() {
        let moment = SmileMoment(date: Date(), guideID: "soft-smile", source: .notification)

        XCTAssertEqual(moment.sourceRawValue, "notification")
        XCTAssertEqual(moment.source, .notification)
    }

    func test_source_readsBackEveryKnownCase() {
        for source in SmileMomentSource.allCases {
            let moment = SmileMoment(date: Date(), guideID: "soft-smile", source: source)
            XCTAssertEqual(moment.source, source)
        }
    }

    /// 미래 버전이나 손상된 값이 들어와도 읽기가 실패하지 않아야 한다.
    func test_source_fallsBackToManual_whenRawValueUnknown() {
        let moment = SmileMoment(date: Date(), guideID: "soft-smile", source: .notification)

        moment.sourceRawValue = "widget"

        XCTAssertEqual(moment.source, .manual)
    }

    func test_source_setter_updatesRawValue() {
        let moment = SmileMoment(date: Date(), guideID: "soft-smile", source: .manual)

        moment.source = .notification

        XCTAssertEqual(moment.sourceRawValue, "notification")
    }

    func test_guide_resolvesStoredID() {
        let moment = SmileMoment(date: Date(), guideID: "bright-smile", source: .manual)

        XCTAssertEqual(moment.guide.id, "bright-smile")
        XCTAssertEqual(moment.guide.title, "활짝 미소")
    }

    func test_guide_fallsBackToDefault_whenIDUnknown() {
        let moment = SmileMoment(date: Date(), guideID: "removed-guide", source: .manual)

        XCTAssertEqual(moment.guide.id, "soft-smile")
    }
}
