import Foundation

/// 베이스라인 재촬영 유도(넛지)의 스누즈 상태 저장소. 앱에서는 UserDefaults, 테스트에서는 메모리 구현을 쓴다.
public protocol BaselineResetNudgeStateStoring: AnyObject {
    var snoozedUntil: Date? { get set }
}

public final class UserDefaultsBaselineResetNudgeState: BaselineResetNudgeStateStoring {
    private static let snoozedUntilKey = "baselineResetNudgeSnoozedUntil"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var snoozedUntil: Date? {
        get { defaults.object(forKey: Self.snoozedUntilKey) as? Date }
        set { defaults.set(newValue, forKey: Self.snoozedUntilKey) }
    }
}

public final class InMemoryBaselineResetNudgeState: BaselineResetNudgeStateStoring {
    public var snoozedUntil: Date?
    public init() {}
}

/// 기준선(베이스라인) 재촬영을 홈 화면에서 언제 권할지 판단한다.
/// 리마인더 넛지(ReminderNudge)와 달리 4주마다 반복되는 권유라 영구 dismiss 대신 스누즈를 쓴다.
public struct BaselineResetNudge {
    private let store: BaselineResetNudgeStateStoring

    public init(store: BaselineResetNudgeStateStoring) {
        self.store = store
    }

    /// shouldRecommendReset이 true이고 스누즈 기간이 지났으면 카드를 보여준다.
    public func shouldShowHomeCard(shouldRecommendReset: Bool, now: Date) -> Bool {
        guard shouldRecommendReset else { return false }
        guard let snoozedUntil = store.snoozedUntil else { return true }
        return now >= snoozedUntil
    }

    /// "나중에" 탭 시 호출. 기본 7일 스누즈.
    public func snooze(now: Date, days: Int = 7) {
        store.snoozedUntil = Calendar.current.date(byAdding: .day, value: days, to: now)
    }

    /// 재촬영을 실제로 완료했을 때 호출.
    public func clearSnooze() {
        store.snoozedUntil = nil
    }
}
