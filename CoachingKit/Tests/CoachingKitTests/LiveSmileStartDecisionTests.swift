import XCTest
@testable import CoachingKit

/// 시작을 눌렀을 때 권한과 세션의 순서.
///
/// 예전에는 세션을 먼저 켜고 그 안에서 권한을 물었다. 대화상자가 뜨는 동안 앱이 inactive가
/// 되고, 화면은 그것을 "카메라를 쓰다 벗어났다"로 읽어 세션을 멈춘다. 그래서 처음 쓰는
/// 사람이 허용을 누르고 돌아오면 측정 화면 대신 "측정을 멈췄어요"를 봤다.
final class LiveSmileStartDecisionTests: XCTestCase {
    func test_notDetermined_asksBeforeTouchingTheSession() {
        let decision = LiveSmileStartDecision(
            permission: .notDetermined,
            isFaceTrackingSupported: true
        )

        XCTAssertEqual(decision, .askForPermission)
    }

    func test_granted_startsRightAway() {
        let decision = LiveSmileStartDecision(
            permission: .granted,
            isFaceTrackingSupported: true
        )

        XCTAssertEqual(decision, .startMeasuring)
    }

    /// iOS는 카메라 권한을 한 번만 묻는다. 앱 안에서 다시 물을 수 없으니 설정으로 안내한다.
    func test_denied_explainsInsteadOfEnteringTheMeasuringScreen() {
        let decision = LiveSmileStartDecision(
            permission: .denied,
            isFaceTrackingSupported: true
        )

        XCTAssertEqual(decision, .explainPermissionNeeded)
    }

    /// 기기가 못 하는 일에 권한을 묻지 않는다 — 허용해도 달라지지 않는다.
    func test_unsupportedDevice_neverAsksForPermission() {
        for permission in [LiveSmileCameraPermission.notDetermined, .granted, .denied] {
            let decision = LiveSmileStartDecision(
                permission: permission,
                isFaceTrackingSupported: false
            )

            XCTAssertEqual(
                decision,
                .explainUnsupportedDevice,
                "TrueDepth가 없는 기기에서 권한 \(permission)이 다른 결정으로 이어졌다"
            )
        }
    }
}
