import Foundation

/// 알림이 실제로 도착할 수 있는 상태인지.
///
/// 저장된 일정만 보면 앱은 예약을 마쳤다고 믿는다. 하지만 iOS 권한이 없으면 아무것도 오지
/// 않고, 그동안 홈은 "다음 알림 오후 3시"를 계속 보여준다 — 오지 않을 알림을 약속하는 셈이다.
/// 이 앱은 알림 → 5초 → 기록이 전부라 알림이 끊기면 남는 것이 없으므로, 그 차이를 홈에서
/// 드러내고 고칠 방법까지 같이 준다.
public enum ReminderDeliveryState: Equatable, Sendable {
    /// 권한도 일정도 갖춰졌다. 이때만 시각을 약속한다.
    case scheduled(UpcomingReminder)
    /// 일정은 켜져 있는데 iOS 권한이 없다. 가장 조용한 실패라 가장 크게 알려야 한다.
    case blockedByPermission
    /// 아직 물어본 적이 없다. 물어보면 되는 상태다.
    case permissionNotRequested
    /// 사용자가 알림을 꺼뒀거나 쓸 수 있는 일정이 없다.
    case off

    public init(
        authorization: ReminderAuthorizationStatus,
        isScheduleEnabled: Bool,
        nextReminder: UpcomingReminder?
    ) {
        // 꺼둔 것은 사용자의 선택이다. 권한 문제로 바꿔 말하지 않는다.
        guard isScheduleEnabled else {
            self = .off
            return
        }

        switch authorization {
        case .denied:
            self = .blockedByPermission
        case .notDetermined:
            self = .permissionNotRequested
        case .authorized:
            // 권한이 있어도 다음 시각을 못 구하면 약속할 것이 없다.
            self = nextReminder.map(Self.scheduled) ?? .off
        }
    }

    /// 알림이 도착하지 못하는 상태 — 홈이 안내를 띄울지 판단한다.
    public var needsAttention: Bool {
        switch self {
        case .scheduled:
            return false
        case .blockedByPermission, .permissionNotRequested, .off:
            return true
        }
    }
}
