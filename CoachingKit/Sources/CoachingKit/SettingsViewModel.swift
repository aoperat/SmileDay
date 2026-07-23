import Foundation
import Observation

@Observable
public final class SettingsViewModel {
    public private(set) var reminders: [ReminderSetting] = []
    public private(set) var baselineAgeWeeks: Int?
    public var shouldRecommendReset: Bool {
        (baselineAgeWeeks ?? 0) >= Baseline.recommendResetThresholdWeeks
    }

    private let reminderRepository: ReminderRepository
    private let sessionRepository: SessionRepository
    private let scheduler: ReminderScheduling
    private let now: () -> Date

    public init(
        reminderRepository: ReminderRepository,
        sessionRepository: SessionRepository,
        scheduler: ReminderScheduling,
        now: @escaping () -> Date = Date.init
    ) {
        self.reminderRepository = reminderRepository
        self.sessionRepository = sessionRepository
        self.scheduler = scheduler
        self.now = now
    }

    public func refresh() throws {
        reminders = try reminderRepository.fetchAll()
        if let baseline = try sessionRepository.fetchLatestBaseline() {
            baselineAgeWeeks = baseline.ageWeeks(now: now())
        } else {
            baselineAgeWeeks = nil
        }
    }

    public func addReminder(hour: Int, minute: Int) async throws {
        _ = await scheduler.requestAuthorization()
        let reminder = try reminderRepository.add(hour: hour, minute: minute)
        await scheduler.scheduleRollingWindow(id: reminder.notificationID, hour: hour, minute: minute, days: reminderRollingWindowDays)
        try refresh()
    }

    public func removeReminder(_ reminder: ReminderSetting) throws {
        scheduler.cancel(id: reminder.notificationID)
        try reminderRepository.delete(reminder)
        try refresh()
    }

    public func toggleReminder(_ reminder: ReminderSetting) async throws {
        let newValue = !reminder.isEnabled
        try reminderRepository.setEnabled(reminder, newValue)
        if newValue {
            await scheduler.scheduleRollingWindow(id: reminder.notificationID, hour: reminder.hour, minute: reminder.minute, days: reminderRollingWindowDays)
        } else {
            scheduler.cancel(id: reminder.notificationID)
        }
        try refresh()
    }

    public func updateReminderTime(_ reminder: ReminderSetting, hour: Int, minute: Int) async throws {
        try reminderRepository.updateTime(reminder, hour: hour, minute: minute)
        if reminder.isEnabled {
            await scheduler.scheduleRollingWindow(id: reminder.notificationID, hour: hour, minute: minute, days: reminderRollingWindowDays)
        }
        try refresh()
    }

    /// 앱이 포그라운드로 돌아올 때 호출. 활성화된 모든 리마인더의 향후 알림을 다시 채운다.
    public func refreshAllScheduledReminders() async throws {
        try refresh()
        for reminder in reminders where reminder.isEnabled {
            await scheduler.scheduleRollingWindow(id: reminder.notificationID, hour: reminder.hour, minute: reminder.minute, days: reminderRollingWindowDays)
        }
    }
}
