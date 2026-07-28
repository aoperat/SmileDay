import Foundation
import Observation

@Observable
public final class SettingsViewModel {
    public private(set) var reminders: [ReminderSetting] = []
    public private(set) var baselineAgeWeeks: Int?
    /// 아직 확인하지 않았으면 nil. 화면은 확인 전에는 권한 안내를 띄우지 않는다.
    public private(set) var authorizationStatus: ReminderAuthorizationStatus?

    public var shouldRecommendReset: Bool {
        (baselineAgeWeeks ?? 0) >= Baseline.recommendResetThresholdWeeks
    }

    private let reminderRepository: ReminderRepository
    private let sessionRepository: SessionRepository
    private let library: SmileGuideLibrary
    private let scheduler: ReminderScheduling
    private let now: () -> Date

    public init(
        reminderRepository: ReminderRepository,
        sessionRepository: SessionRepository,
        library: SmileGuideLibrary,
        scheduler: ReminderScheduling,
        now: @escaping () -> Date = Date.init
    ) {
        self.reminderRepository = reminderRepository
        self.sessionRepository = sessionRepository
        self.library = library
        self.scheduler = scheduler
        self.now = now
    }

    /// 사용자가 만든 카드까지 포함해 해석한다.
    public func guide(for reminder: ReminderSetting) -> SmileGuide {
        library.guide(id: reminder.guideID)
    }

    public func refresh() throws {
        reminders = try reminderRepository.fetchAll()
        if let baseline = try sessionRepository.fetchLatestBaseline() {
            baselineAgeWeeks = baseline.ageWeeks(now: now())
        } else {
            baselineAgeWeeks = nil
        }
    }

    public func refreshAuthorizationStatus() async {
        authorizationStatus = await scheduler.currentAuthorizationStatus()
    }

    public func addReminder(hour: Int, minute: Int, guideID: String = SmileGuideCatalog.default.id) async throws {
        _ = await scheduler.requestAuthorization()
        let reminder = try reminderRepository.add(hour: hour, minute: minute, guideID: guideID)
        await schedule(reminder)
        try refresh()
        await refreshAuthorizationStatus()
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
            await schedule(reminder)
        } else {
            scheduler.cancel(id: reminder.notificationID)
        }
        try refresh()
    }

    public func updateReminderTime(_ reminder: ReminderSetting, hour: Int, minute: Int) async throws {
        try reminderRepository.updateTime(reminder, hour: hour, minute: minute)
        if reminder.isEnabled {
            await schedule(reminder)
        }
        try refresh()
    }

    public func updateReminderGuide(_ reminder: ReminderSetting, guideID: String) async throws {
        try reminderRepository.updateGuide(reminder, guideID: guideID)
        if reminder.isEnabled {
            await schedule(reminder)
        }
        try refresh()
    }

    /// 앱이 포그라운드로 돌아올 때 호출. 활성화된 모든 리마인더의 향후 알림을 다시 채운다.
    public func refreshAllScheduledReminders() async throws {
        try refresh()
        for reminder in reminders where reminder.isEnabled {
            await schedule(reminder)
        }
    }

    /// 저장된 guideID가 nil이거나 어디에도 없어도 기본 카드로 예약된다.
    private func schedule(_ reminder: ReminderSetting) async {
        await scheduler.scheduleRollingWindow(
            id: reminder.notificationID,
            hour: reminder.hour,
            minute: reminder.minute,
            guide: library.guide(id: reminder.guideID),
            days: reminderRollingWindowDays
        )
    }
}
