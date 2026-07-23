import Foundation
import Observation

@Observable
public final class SettingsViewModel {
    public private(set) var reminders: [ReminderSetting] = []
    public private(set) var baselineAgeWeeks: Int?
    public var shouldRecommendReset: Bool {
        (baselineAgeWeeks ?? 0) >= 4
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
            let weeks = Calendar.current.dateComponents([.weekOfYear], from: baseline.capturedAt, to: now()).weekOfYear ?? 0
            baselineAgeWeeks = max(weeks, 0)
        } else {
            baselineAgeWeeks = nil
        }
    }

    public func addReminder(hour: Int, minute: Int) async throws {
        _ = await scheduler.requestAuthorization()
        let reminder = try reminderRepository.add(hour: hour, minute: minute)
        await scheduler.scheduleDaily(id: reminder.notificationID, hour: hour, minute: minute)
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
            await scheduler.scheduleDaily(id: reminder.notificationID, hour: reminder.hour, minute: reminder.minute)
        } else {
            scheduler.cancel(id: reminder.notificationID)
        }
        try refresh()
    }
}
