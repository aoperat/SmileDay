import Foundation

/// 실시간 확인에 필요한 카메라 권한 상태.
public enum LiveSmileCameraPermission: Equatable, Sendable {
    case notDetermined
    case granted
    case denied
}

/// 시작을 눌렀을 때 다음에 할 일.
///
/// 순서가 핵심이다. 예전에는 세션을 먼저 켜고 그 안에서 권한을 물었는데, 권한 대화상자가
/// 뜨는 동안 앱은 inactive가 된다. 화면은 그걸 "카메라를 쓰다가 벗어났다"로 읽고 세션을
/// 멈춰서, 처음 쓰는 사람이 허용을 누르고 돌아오면 측정 화면 대신 "측정을 멈췄어요"를
/// 봤다. 권한은 세션을 켜기 전에 끝낸다.
public enum LiveSmileStartDecision: Equatable, Sendable {
    /// 권한을 먼저 묻는다. 세션은 아직 켜지 않는다.
    case askForPermission
    /// 권한이 이미 있다. 바로 측정을 시작한다.
    case startMeasuring
    /// 앱에서는 되돌릴 수 없다. 설정 앱으로 안내한다.
    case explainPermissionNeeded
    /// TrueDepth가 없는 기기다. 권한을 물을 이유가 없다.
    case explainUnsupportedDevice

    public init(permission: LiveSmileCameraPermission, isFaceTrackingSupported: Bool) {
        // 기기가 못 하는 일에 권한을 묻지 않는다. 허용해도 달라지지 않는다.
        guard isFaceTrackingSupported else {
            self = .explainUnsupportedDevice
            return
        }

        switch permission {
        case .notDetermined: self = .askForPermission
        case .granted: self = .startMeasuring
        case .denied: self = .explainPermissionNeeded
        }
    }
}
