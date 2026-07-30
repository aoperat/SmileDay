import XCTest
@testable import CoachingKit

final class SmileGuideTests: XCTestCase {
    /// 기본 가이드는 5초다. 이 값이 카운트다운 길이가 된다.
    func test_default_lastsFiveSeconds() {
        XCTAssertEqual(SmileGuideCatalog.default.durationSeconds, 5)
        XCTAssertEqual(SmileGuideCatalog.defaultDurationSeconds, 5)
    }

    /// ID가 바뀌면 이미 저장된 완료 기록과 예약된 알림 payload의 의미가 어긋난다.
    func test_default_keepsStableID() {
        XCTAssertEqual(SmileGuideCatalog.default.id, "anytime-soft")
    }

    func test_init_usesDefaultDuration_whenNotGiven() {
        XCTAssertEqual(SmileGuide(id: "anything").durationSeconds, 5)
    }
}
