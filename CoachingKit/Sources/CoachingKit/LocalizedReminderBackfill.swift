import Foundation

/// 재예약을 이미 돌렸는지 기억한다.
public protocol LocalizedReminderBackfillStoring: AnyObject {
    var hasBackfilledLocalizedReminders: Bool { get set }
}

public final class UserDefaultsLocalizedReminderBackfillStore: LocalizedReminderBackfillStoring {
    private let defaults: UserDefaults
    private let key = "hasBackfilledLocalizedReminders"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var hasBackfilledLocalizedReminders: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}

/// 옛 빌드가 평문 한국어로 굳혀둔 반복 알림을, 배달 시점에 해석되는 키 기반 알림으로 한 번 갈아끼운다.
///
/// 이 빌드부터 알림 제목·기본 본문은 `localizedUserNotificationString` 키다(스펙 5.1절). 그런데
/// 이미 기기에 예약된 알림은 예약 당시의 평문을 들고 있어 언어를 바꿔도 그대로다. 설정을 다시
/// 저장하기 전까지 영어 기기에 한국어 알림이 계속 온다 — 그래서 업데이트 뒤 한 번 재예약한다.
///
/// `ReminderActionBackfill`과 같은 규칙: 새 그룹 먼저, 저장, 옛 그룹은 마지막. 실패하면 표시를
/// 안 남겨 다음 실행에서 다시 시도한다. 승격(`ReminderMessageMigration`)은 `messageStore.messages`를
/// 읽는 순간 자동으로 먼저 도므로 여기서 따로 부르지 않는다.
@MainActor
public struct LocalizedReminderBackfill {
    private let scheduleRepository: SmileReminderScheduleRepository
    private let scheduler: ReminderScheduling
    private let messageStore: ReminderMessageStoring
    private let store: LocalizedReminderBackfillStoring
    private let groupIDFactory: () -> String

    public init(
        scheduleRepository: SmileReminderScheduleRepository,
        scheduler: ReminderScheduling,
        messageStore: ReminderMessageStoring = UserDefaultsReminderMessageStore(),
        store: LocalizedReminderBackfillStoring = UserDefaultsLocalizedReminderBackfillStore(),
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
    /// 알림이 꺼져 있거나 예약이 없으면 갈아끼울 것도 없다. 꺼져 있는 경우에는 표시를 남긴다 —
    /// 사용자가 나중에 알림을 켜면 그 저장 경로가 이미 키 기반으로 예약한다.
    @discardableResult
    public func runIfNeeded() async -> Bool {
        guard !store.hasBackfilledLocalizedReminders else { return false }

        guard let schedule = try? scheduleRepository.fetchCurrent() else { return false }

        guard schedule.isEnabled, let pattern = schedule.pattern else {
            store.hasBackfilledLocalizedReminders = true
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

        store.hasBackfilledLocalizedReminders = true
        return true
    }
}
