import Foundation

/// 실시간 확인 세션에서 일어나는 일.
///
/// 앱 타깃의 ARKit 구현이 이 이벤트만 올려보낸다. 각도와 조명은 `sample` 안의 값으로
/// 판정하므로 별도 이벤트가 아니다 — 얼굴을 놓쳤는지, 세션 자체가 못 도는지만 구분한다.
public enum LiveSmileMonitorEvent: Equatable, Sendable {
    /// 얼굴을 추적 중이며 이번 프레임의 값이 들어왔다.
    case sample(LiveSmileSample)
    /// 얼굴을 놓쳤다. 화면 밖으로 나갔거나 가려졌다.
    case faceLost
    /// 카메라 권한이 없다. 사용자가 설정에서 바꿔야 한다.
    case permissionDenied
    /// TrueDepth가 없어 이 기기에서는 쓸 수 없다.
    case unsupportedDevice
    /// 세션이 실패하거나 중단됐다.
    case sessionFailed
}

/// 실시간 확인 세션의 경계.
///
/// 계약:
/// - `start()`를 이미 도는 중에 다시 불러도 안전하게 무시한다.
/// - `stop()`을 멈춘 상태에서 불러도 안전하게 무시한다.
/// - `stop()` 뒤에는 `onEvent`를 부르지 않는다.
/// - 이벤트는 메인 액터에서 전달한다.
@MainActor
public protocol LiveSmileMonitoring: AnyObject {
    var onEvent: ((LiveSmileMonitorEvent) -> Void)? { get set }
    func start()
    func stop()
}
