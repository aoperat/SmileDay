import XCTest
@testable import CoachingKit

final class LiveSmileSampleTests: XCTestCase {
    private func sample(
        left: Double = 0.2,
        right: Double = 0.2,
        gazeOffset: Double = 0,
        ambient: Double? = 800
    ) -> LiveSmileSample {
        LiveSmileSample(
            mouthSmileLeft: left,
            mouthSmileRight: right,
            gazeOffsetDegrees: gazeOffset,
            ambientIntensity: ambient
        )
    }

    func test_sample_isEquatableByEveryStoredValue() {
        XCTAssertEqual(sample(), sample())
        XCTAssertNotEqual(sample(left: 0.2), sample(left: 0.3))
        XCTAssertNotEqual(sample(right: 0.2), sample(right: 0.3))
        XCTAssertNotEqual(sample(gazeOffset: 0), sample(gazeOffset: 5))
        XCTAssertNotEqual(sample(ambient: 800), sample(ambient: nil))
    }

    /// 밝기 추정값은 아직 없을 수 있다.
    func test_ambientIntensity_defaultsToNil() {
        let sample = LiveSmileSample(
            mouthSmileLeft: 0.1,
            mouthSmileRight: 0.1,
            gazeOffsetDegrees: 0
        )

        XCTAssertNil(sample.ambientIntensity)
    }

    // MARK: - 이벤트

    func test_event_isEquatable() {
        XCTAssertEqual(LiveSmileMonitorEvent.sample(sample()), .sample(sample()))
        XCTAssertNotEqual(LiveSmileMonitorEvent.sample(sample()), .sample(sample(left: 0.9)))
        XCTAssertEqual(LiveSmileMonitorEvent.faceLost, .faceLost)
        XCTAssertNotEqual(LiveSmileMonitorEvent.faceLost, .sessionFailed)
        XCTAssertNotEqual(LiveSmileMonitorEvent.permissionDenied, .unsupportedDevice)
    }

    /// 값 타입은 액터 경계를 넘어야 한다. 컴파일되면 통과다.
    func test_typesAreSendable() {
        func requireSendable<T: Sendable>(_ value: T) -> T { value }

        XCTAssertEqual(requireSendable(sample()), sample())
        XCTAssertEqual(requireSendable(LiveSmileMonitorEvent.faceLost), .faceLost)
        XCTAssertEqual(requireSendable(LiveSmileLevel.clear), .clear)
    }
}
