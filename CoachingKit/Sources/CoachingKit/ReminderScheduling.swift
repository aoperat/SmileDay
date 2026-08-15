import Foundation

/// 예전 버전이 리마인더 하나당 며칠치를 미리 예약해뒀는지.
///
/// 새 예약은 매일 반복 트리거를 쓰므로 이 값으로 예약하지 않는다.
/// `cancel(id:)`가 그때 만들어둔 identifier를 빠짐없이 지우는 데만 남는다.
public let reminderRollingWindowDays = 14

/// 알림 권한 상태. UserDefaults로 추정하지 않고 시스템에 매번 물어본다.
public enum ReminderAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

public protocol ReminderScheduling: AnyObject {
    /// 거부되어도 throw하지 않는다. 호출자가 상태를 보고 안내 문구를 정한다.
    func requestAuthorization() async -> Bool
    func currentAuthorizationStatus() async -> ReminderAuthorizationStatus

    /// 하나의 활동 시간창에서 계산한 시각들을 매일 반복 예약한다.
    ///
    /// 일부만 등록된 채 남지 않도록 구현체가 실패한 요청을 정리한 뒤 오류를 전달한다.
    func scheduleDailyPattern(
        groupID: String,
        times: [ReminderTime],
        messages: [ReminderMessage]
    ) async throws
    func cancelGroup(id: String)

    /// 예전 버전이 예약해둔 개별 알림을 끈다. 새 예약에는 쓰지 않는다.
    func cancel(id: String)
}
