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

    /// 카드 이름은 저장하지 않는다. 기록은 ID만 들고 있고 이름 해석은 `SmileGuideLibrary`가 한다.
    /// 그래야 사용자가 만든 카드로 남긴 기록도 이름을 찾을 수 있다.
    func test_storesGuideIDVerbatim() {
        let moment = SmileMoment(date: Date(), guideID: "removed-guide", source: .manual)

        XCTAssertEqual(moment.guideID, "removed-guide")
    }
}
