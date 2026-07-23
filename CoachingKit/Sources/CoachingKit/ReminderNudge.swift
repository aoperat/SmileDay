import Foundation

/// 리마인더 설정 유도(넛지)의 노출 상태 저장소. 앱에서는 UserDefaults, 테스트에서는 메모리 구현을 쓴다.
public protocol ReminderNudgeStateStoring: AnyObject {
    /// 체크인 제안을 거절한 버킷들.
    var declinedBuckets: Set<TimeBucket> { get set }
    /// 홈 카드를 닫은 시점의 "빈 버킷" 조합. nil이면 닫은 적 없음.
    var dismissedHomeCardMissingBuckets: Set<TimeBucket>? { get set }
}

public final class UserDefaultsReminderNudgeState: ReminderNudgeStateStoring {
    private static let declinedKey = "reminderNudgeDeclinedBuckets"
    private static let dismissedKey = "reminderNudgeDismissedMissingBuckets"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var declinedBuckets: Set<TimeBucket> {
        get { Set((defaults.stringArray(forKey: Self.declinedKey) ?? []).compactMap(TimeBucket.init(rawValue:))) }
        set { defaults.set(newValue.map(\.rawValue).sorted(), forKey: Self.declinedKey) }
    }

    public var dismissedHomeCardMissingBuckets: Set<TimeBucket>? {
        get {
            guard let raw = defaults.stringArray(forKey: Self.dismissedKey) else { return nil }
            return Set(raw.compactMap(TimeBucket.init(rawValue:)))
        }
        set {
            if let newValue {
                defaults.set(newValue.map(\.rawValue).sorted(), forKey: Self.dismissedKey)
            } else {
                defaults.removeObject(forKey: Self.dismissedKey)
            }
        }
    }
}

public final class InMemoryReminderNudgeState: ReminderNudgeStateStoring {
    public var declinedBuckets: Set<TimeBucket> = []
    public var dismissedHomeCardMissingBuckets: Set<TimeBucket>?
    public init() {}
}

/// 빈 시간대(버킷)를 채우도록 리마인더 유도를 언제 보여줄지 판단한다.
public struct ReminderNudge {
    private let store: ReminderNudgeStateStoring

    public init(store: ReminderNudgeStateStoring) {
        self.store = store
    }

    /// 체크인 저장 화면에서 리마인더 제안을 보여줄지. 체크인 시각의 버킷이 비어 있고 거절한 적 없을 때만.
    public func shouldOfferAfterCheckIn(registeredBuckets: Set<TimeBucket>, checkInHour: Int) -> Bool {
        let bucket = TimeBucket(hour: checkInHour)
        return !registeredBuckets.contains(bucket) && !store.declinedBuckets.contains(bucket)
    }

    public func declineCheckInPrompt(forHour hour: Int) {
        store.declinedBuckets.insert(TimeBucket(hour: hour))
    }

    /// 비어 있는 버킷을 allCases 순서대로. 홈 카드 문구에 쓴다.
    public func missingBuckets(registeredBuckets: Set<TimeBucket>) -> [TimeBucket] {
        TimeBucket.allCases.filter { !registeredBuckets.contains($0) }
    }

    /// 홈에 리마인더 유도 카드를 보여줄지. 닫은 시점과 빈 버킷 조합이 달라지면 다시 보여준다.
    public func shouldShowHomeCard(registeredBuckets: Set<TimeBucket>, hasAnyCheckIn: Bool) -> Bool {
        let missing = Set(missingBuckets(registeredBuckets: registeredBuckets))
        guard !missing.isEmpty, hasAnyCheckIn else { return false }
        return store.dismissedHomeCardMissingBuckets != missing
    }

    public func dismissHomeCard(registeredBuckets: Set<TimeBucket>) {
        store.dismissedHomeCardMissingBuckets = Set(missingBuckets(registeredBuckets: registeredBuckets))
    }
}
