import Foundation

/// 리마인더 설정 유도(넛지)의 노출 상태 저장소. 앱에서는 UserDefaults, 테스트에서는 메모리 구현을 쓴다.
public protocol ReminderNudgeStateStoring: AnyObject {
    var hasDeclinedCheckInPrompt: Bool { get set }
    var hasDismissedHomeCard: Bool { get set }
}

public final class UserDefaultsReminderNudgeState: ReminderNudgeStateStoring {
    private static let declinedKey = "reminderNudgeDeclinedCheckInPrompt"
    private static let dismissedKey = "reminderNudgeDismissedHomeCard"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var hasDeclinedCheckInPrompt: Bool {
        get { defaults.bool(forKey: Self.declinedKey) }
        set { defaults.set(newValue, forKey: Self.declinedKey) }
    }

    public var hasDismissedHomeCard: Bool {
        get { defaults.bool(forKey: Self.dismissedKey) }
        set { defaults.set(newValue, forKey: Self.dismissedKey) }
    }
}

public final class InMemoryReminderNudgeState: ReminderNudgeStateStoring {
    public var hasDeclinedCheckInPrompt: Bool = false
    public var hasDismissedHomeCard: Bool = false
    public init() {}
}

/// 리마인더 유도를 언제 보여줄지 판단한다.
public struct ReminderNudge {
    private let store: ReminderNudgeStateStoring

    public init(store: ReminderNudgeStateStoring) {
        self.store = store
    }

    /// 체크인 저장 화면에서 리마인더 제안을 보여줄지.
    public func shouldOfferAfterCheckIn(reminderCount: Int) -> Bool {
        reminderCount == 0 && !store.hasDeclinedCheckInPrompt
    }

    /// 홈에 리마인더 유도 카드를 보여줄지.
    public func shouldShowHomeCard(reminderCount: Int, hasAnyCheckIn: Bool) -> Bool {
        reminderCount == 0 && hasAnyCheckIn && !store.hasDismissedHomeCard
    }

    public func declineCheckInPrompt() {
        store.hasDeclinedCheckInPrompt = true
    }

    public func dismissHomeCard() {
        store.hasDismissedHomeCard = true
    }
}
