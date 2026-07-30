import Foundation
import Observation

@MainActor
@Observable
public final class SmileReminderScheduleViewModel {
    public private(set) var startHour = 9
    public private(set) var startMinute = 0
    public private(set) var endHour = 21
    public private(set) var endMinute = 0
    public private(set) var intervalMinutes = 180
    public private(set) var isEnabled = true
    public private(set) var authorizationStatus: ReminderAuthorizationStatus?
    public private(set) var errorMessage: String?
    public private(set) var isSaving = false

    private let scheduleRepository: SmileReminderScheduleRepository
    private let legacyReminderRepository: LegacyReminderRepository
    private let scheduler: ReminderScheduling
    private let messageStore: ReminderMessageStoring
    private let groupIDFactory: () -> String

    public init(
        scheduleRepository: SmileReminderScheduleRepository,
        legacyReminderRepository: LegacyReminderRepository,
        scheduler: ReminderScheduling,
        messageStore: ReminderMessageStoring = UserDefaultsReminderMessageStore(),
        groupIDFactory: @escaping () -> String = { UUID().uuidString }
    ) {
        self.scheduleRepository = scheduleRepository
        self.legacyReminderRepository = legacyReminderRepository
        self.scheduler = scheduler
        self.messageStore = messageStore
        self.groupIDFactory = groupIDFactory
    }

    public var pattern: SmileReminderPattern? {
        guard let start = try? ReminderTime(hour: startHour, minute: startMinute),
              let end = try? ReminderTime(hour: endHour, minute: endMinute) else {
            return nil
        }
        return try? SmileReminderPattern(
            startTime: start,
            endTime: end,
            intervalMinutes: intervalMinutes
        )
    }

    public var occurrenceTimes: [ReminderTime] {
        pattern?.occurrences() ?? []
    }

    public func refresh() throws {
        guard let schedule = try scheduleRepository.fetchCurrent() else { return }
        startHour = schedule.startHour
        startMinute = schedule.startMinute
        endHour = schedule.endHour
        endMinute = schedule.endMinute
        intervalMinutes = schedule.intervalMinutes
        isEnabled = schedule.isEnabled
    }

    public func refreshAuthorizationStatus() async {
        authorizationStatus = await scheduler.currentAuthorizationStatus()
    }

    public func updateStart(hour: Int, minute: Int) {
        startHour = hour
        startMinute = minute
        errorMessage = nil
    }

    public func updateEnd(hour: Int, minute: Int) {
        endHour = hour
        endMinute = minute
        errorMessage = nil
    }

    public func updateInterval(_ minutes: Int) {
        intervalMinutes = minutes
        errorMessage = nil
    }

    public func updateEnabled(_ enabled: Bool) {
        isEnabled = enabled
        errorMessage = nil
    }

    @discardableResult
    public func save(requestAuthorization: Bool = false) async -> Bool {
        guard !isSaving else { return false }
        guard let pattern else {
            errorMessage = "종료 시간은 시작 시간보다 늦어야 해요."
            return false
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        if requestAuthorization {
            _ = await scheduler.requestAuthorization()
        }
        authorizationStatus = await scheduler.currentAuthorizationStatus()

        do {
            let previousGroupID = try scheduleRepository.fetchCurrent()?.notificationGroupID
            let legacyNotificationIDs = try legacyReminderRepository.pendingNotificationIDs()

            if isEnabled {
                // 기존 그룹을 지우기 전에 새 그룹을 전부 등록한다. 등록 실패 시 저장값과
                // 기존 알림을 그대로 남겨 사용자가 알림을 모두 잃지 않게 한다.
                let newGroupID = groupIDFactory()
                do {
                    try await scheduler.scheduleDailyPattern(
                        groupID: newGroupID,
                        times: pattern.occurrences(),
                        messages: messageStore.messages
                    )
                } catch {
                    errorMessage = "알림을 등록하지 못했어요. 기존 알림은 그대로 유지했어요."
                    return false
                }

                do {
                    _ = try scheduleRepository.save(
                        pattern: pattern,
                        isEnabled: true,
                        notificationGroupID: newGroupID
                    )
                } catch {
                    scheduler.cancelGroup(id: newGroupID)
                    throw error
                }

                if let previousGroupID, previousGroupID != newGroupID {
                    scheduler.cancelGroup(id: previousGroupID)
                }
            } else {
                let schedule = try scheduleRepository.save(pattern: pattern, isEnabled: false)
                scheduler.cancelGroup(id: schedule.notificationGroupID)
                if let previousGroupID, previousGroupID != schedule.notificationGroupID {
                    scheduler.cancelGroup(id: previousGroupID)
                }
            }

            // 새 반복 설정이 확정된 뒤에만 예전 개별 알림을 끈다.
            for notificationID in legacyNotificationIDs {
                scheduler.cancel(id: notificationID)
            }
            return true
        } catch {
            errorMessage = "알림 설정을 저장하지 못했어요. 다시 시도해주세요."
            return false
        }
    }
}
