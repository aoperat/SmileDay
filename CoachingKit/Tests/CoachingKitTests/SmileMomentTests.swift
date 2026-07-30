import XCTest
@testable import CoachingKit

final class SmileMomentTests: XCTestCase {
    func test_init_storesSourceRawValue() {
        let moment = SmileMoment(date: Date(), guideID: "anytime-soft", source: .notification)

        XCTAssertEqual(moment.sourceRawValue, "notification")
        XCTAssertEqual(moment.source, .notification)
    }

    func test_source_readsBackEveryKnownCase() {
        for source in SmileMomentSource.allCases {
            let moment = SmileMoment(date: Date(), guideID: "anytime-soft", source: source)
            XCTAssertEqual(moment.source, source)
        }
    }

    /// 미래 버전이나 손상된 값이 들어와도 읽기가 실패하지 않아야 한다.
    func test_source_fallsBackToManual_whenRawValueUnknown() {
        let moment = SmileMoment(date: Date(), guideID: "anytime-soft", source: .notification)

        moment.sourceRawValue = "widget"

        XCTAssertEqual(moment.source, .manual)
    }

    func test_source_setter_updatesRawValue() {
        let moment = SmileMoment(date: Date(), guideID: "anytime-soft", source: .manual)

        moment.source = .notification

        XCTAssertEqual(moment.sourceRawValue, "notification")
    }

    /// 기록은 ID만 들고 있다. 지난 버전이 남긴 ID여도 손대지 않고 그대로 보관한다.
    func test_storesGuideIDVerbatim() {
        let moment = SmileMoment(date: Date(), guideID: "removed-guide", source: .manual)

        XCTAssertEqual(moment.guideID, "removed-guide")
    }
}
