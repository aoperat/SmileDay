import Foundation

/// 보정을 이미 돌렸는지 기억한다.
public protocol ReminderActionBackfillStoring: AnyObject {
    var hasBackfilledReminderActions: Bool { get set }
}

public final class UserDefaultsReminderActionBackfillStore: ReminderActionBackfillStoring {
    private let defaults: UserDefaults
    private let key = "hasBackfilledReminderActions"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var hasBackfilledReminderActions: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}

/// 알림 버튼을 못 받은 기존 예약을 한 번만 다시 등록한다.
///
/// 버튼은 알림에 찍힌 `categoryIdentifier`에서 나온다. 그런데 반복 알림은 한 번 예약되면
/// 기기에 그대로 남아 갱신되지 않으므로, 이 기능이 생기기 전에 예약한 사용자는 설정을 다시
/// 저장하기 전까지 버튼을 영영 못 본다.
///
/// **같은 `groupID`로 다시 등록한다.** 식별자가 `<groupID>-daily-HHmm`로 결정되어 있어서
/// `UNUserNotificationCenter.add`가 같은 식별자의 알림을 덮어쓴다 — 취소하고 새로 만드는
/// 경로를 타지 않으므로 중간에 실패해도 알림이 사라진 구간이 생기지 않고, 새 그룹을 만들지
/// 않으니 지울 옛 그룹도 남지 않는다.
@MainActor
public struct ReminderActionBackfill {
    private let scheduleRepository: SmileReminderScheduleRepository
    private let scheduler: ReminderScheduling
    private let messageStore: ReminderMessageStoring
    private let store: ReminderActionBackfillStoring

    public init(
        scheduleRepository: SmileReminderScheduleRepository,
        scheduler: ReminderScheduling,
        messageStore: ReminderMessageStoring = UserDefaultsReminderMessageStore(),
        store: ReminderActionBackfillStoring = UserDefaultsReminderActionBackfillStore()
    ) {
        self.scheduleRepository = scheduleRepository
        self.scheduler = scheduler
        self.messageStore = messageStore
        self.store = store
    }

    /// 실패하면 표시를 남기지 않는다 — 다음 실행에서 다시 시도한다.
    ///
    /// 알림이 꺼져 있거나 예약이 없으면 다시 등록할 것도 없다. 그 경우에도 표시를 남긴다 —
    /// 사용자가 나중에 알림을 켜면 그 저장 경로가 이미 새 카테고리를 붙여준다.
    @discardableResult
    public func runIfNeeded() async -> Bool {
        guard !store.hasBackfilledReminderActions else { return false }

        guard let schedule = try? scheduleRepository.fetchCurrent() else { return false }

        guard schedule.isEnabled, let pattern = schedule.pattern else {
            store.hasBackfilledReminderActions = true
            return false
        }

        do {
            try await scheduler.scheduleDailyPattern(
                groupID: schedule.notificationGroupID,
                times: pattern.occurrences(),
                messages: messageStore.messages
            )
        } catch {
            return false
        }

        store.hasBackfilledReminderActions = true
        return true
    }
}
