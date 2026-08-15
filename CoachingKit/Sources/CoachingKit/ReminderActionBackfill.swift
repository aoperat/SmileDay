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
/// **새 `groupID`로 전부 등록한 뒤 저장값을 교체하고, 마지막에 옛 그룹을 취소한다.**
/// 같은 identifier를 덮어쓰다가 중간에 실패하면 scheduler의 부분 등록 롤백이 이미 존재하던
/// 요청까지 지울 수 있다. 새 그룹을 쓰면 실패한 요청만 정리되고 옛 알림은 온전히 남는다.
@MainActor
public struct ReminderActionBackfill {
    private let scheduleRepository: SmileReminderScheduleRepository
    private let scheduler: ReminderScheduling
    private let messageStore: ReminderMessageStoring
    private let store: ReminderActionBackfillStoring
    private let groupIDFactory: () -> String

    public init(
        scheduleRepository: SmileReminderScheduleRepository,
        scheduler: ReminderScheduling,
        messageStore: ReminderMessageStoring = UserDefaultsReminderMessageStore(),
        store: ReminderActionBackfillStoring = UserDefaultsReminderActionBackfillStore(),
        groupIDFactory: @escaping () -> String = { UUID().uuidString }
    ) {
        self.scheduleRepository = scheduleRepository
        self.scheduler = scheduler
        self.messageStore = messageStore
        self.store = store
        self.groupIDFactory = groupIDFactory
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

        // 등록·저장·옛 그룹 취소의 순서는 ReminderGroupSwap이 지킨다. 어느 단계에서 실패하든
        // 여기서 할 일은 같다 — 표시를 남기지 않고 물러나 다음 실행에서 다시 시도한다.
        do {
            try await ReminderGroupSwap(
                scheduleRepository: scheduleRepository,
                scheduler: scheduler,
                groupIDFactory: groupIDFactory
            ).run(
                pattern: pattern,
                messages: messageStore.messages,
                previousGroupID: schedule.notificationGroupID
            )
        } catch {
            return false
        }

        store.hasBackfilledReminderActions = true
        return true
    }
}
