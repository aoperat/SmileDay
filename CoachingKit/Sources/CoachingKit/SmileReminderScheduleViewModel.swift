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

    /// 바꾸는 즉시 반영할지.
    ///
    /// 설정 화면은 true다 — 토글이나 주기를 바꾼 것 자체가 사용자의 결정이라 저장 버튼을
    /// 한 번 더 누르게 할 이유가 없다. 온보딩은 false다. 거기서는 "시작하기"를 누르기
    /// 전까지 아무것도 예약하지 않아야 하고, 시간을 고르는 중에 권한 대화상자가 떠서도 안 된다.
    private let appliesChangesImmediately: Bool
    /// 마지막 변경 뒤 이만큼 기다렸다가 한 번만 저장한다. 시간 다이얼은 굴리는 동안 값이
    /// 계속 바뀌는데, 매 틱마다 저장하면 스크롤 한 번에 알림 재예약이 수십 번 돈다.
    private let applyDelayNanoseconds: UInt64
    private var pendingApply: Task<Void, Never>?

    public init(
        scheduleRepository: SmileReminderScheduleRepository,
        legacyReminderRepository: LegacyReminderRepository,
        scheduler: ReminderScheduling,
        messageStore: ReminderMessageStoring = UserDefaultsReminderMessageStore(),
        groupIDFactory: @escaping () -> String = { UUID().uuidString },
        appliesChangesImmediately: Bool = false,
        applyDelayNanoseconds: UInt64 = 500_000_000
    ) {
        self.scheduleRepository = scheduleRepository
        self.legacyReminderRepository = legacyReminderRepository
        self.scheduler = scheduler
        self.messageStore = messageStore
        self.groupIDFactory = groupIDFactory
        self.appliesChangesImmediately = appliesChangesImmediately
        self.applyDelayNanoseconds = applyDelayNanoseconds
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
        applyChangesSoon()
    }

    public func updateEnd(hour: Int, minute: Int) {
        endHour = hour
        endMinute = minute
        errorMessage = nil
        applyChangesSoon()
    }

    public func updateInterval(_ minutes: Int) {
        intervalMinutes = minutes
        errorMessage = nil
        applyChangesSoon()
    }

    public func updateEnabled(_ enabled: Bool) {
        isEnabled = enabled
        errorMessage = nil
        // 켤 때만 권한을 묻는다. 끄거나 시간을 바꿀 때 대화상자가 뜨면 안 된다.
        applyChangesSoon(requestAuthorization: enabled)
    }

    /// 마지막 변경에서 잠깐 기다렸다가 한 번만 저장한다.
    ///
    /// 저장은 알림을 전부 다시 등록하고 옛 그룹을 지우는 일이라 가볍지 않다. 시간 다이얼을
    /// 굴리는 동안 매 틱마다 부르면 스크롤 한 번에 그 일이 수십 번 돈다.
    private func applyChangesSoon(requestAuthorization: Bool = false) {
        guard appliesChangesImmediately else { return }

        pendingApply?.cancel()
        pendingApply = Task { [applyDelayNanoseconds] in
            if applyDelayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: applyDelayNanoseconds)
            }
            guard !Task.isCancelled else { return }

            // 앞선 저장이 아직 돌고 있으면 save()가 스스로 물러난다. 그 사이 바뀐 값이
            // 통째로 버려지지 않게 끝나기를 잠깐 기다린다.
            var waited = 0
            while isSaving, waited < 40, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
                waited += 1
            }
            guard !Task.isCancelled else { return }

            await save(requestAuthorization: requestAuthorization)
        }
    }

    /// 대기 중인 반영이 끝나기를 기다린다. 화면을 떠나기 전이나 테스트에서 쓴다.
    public func waitForPendingApply() async {
        await pendingApply?.value
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
