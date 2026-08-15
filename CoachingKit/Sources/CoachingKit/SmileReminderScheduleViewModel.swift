import Foundation
import Observation

@MainActor
@Observable
public final class SmileReminderScheduleViewModel {
    /// 시작이 종료보다 늦어도 된다 — 자정을 넘는 창이다. 같은 시각만 만들 수 없다.
    /// 화면 두 곳(온보딩·설정)이 같은 문구를 써야 해서 여기 둔다.
    public static let invalidPatternMessage = "시작 시간과 종료 시간을 다르게 정해주세요."

    // 아직 저장된 일정이 없는 사용자가 처음 보는 값. 제품이 권하는 시간창 하나에서 나온다 —
    // 추천을 바꾸려면 `SmileReminderPattern.recommended`만 고치면 화면까지 따라온다.
    // (`SmileReminderSchedule`의 같은 숫자는 저장소 마이그레이션 계약이라 별개다.)
    public private(set) var startHour = SmileReminderPattern.recommended.startTime.hour
    public private(set) var startMinute = SmileReminderPattern.recommended.startTime.minute
    public private(set) var endHour = SmileReminderPattern.recommended.endTime.hour
    public private(set) var endMinute = SmileReminderPattern.recommended.endTime.minute
    public private(set) var intervalMinutes = SmileReminderPattern.recommended.intervalMinutes
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
    /// 아직 알림에 반영되지 않은 변경이 있는지. `flushPendingApply()`가 한 번 더 저장할지 판단한다.
    private var hasUnappliedChanges = false
    /// 대기 중인 반영이 권한까지 물어야 하는지. 여러 변경이 묶이면 한 번이라도 켰으면 묻는다.
    private var pendingRequestAuthorization = false

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
        SmileReminderPattern(
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            intervalMinutes: intervalMinutes
        )
    }

    public var occurrenceTimes: [ReminderTime] {
        pattern?.occurrences() ?? []
    }

    /// 자정을 넘는 시간창인지. 화면이 "종료 시간은 다음 날"이라고 알려줄 때 쓴다 —
    /// 22:00~02:00을 실수로 읽지 않게 한다.
    public var crossesMidnight: Bool {
        pattern?.crossesMidnight ?? false
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

    /// 알림 문구가 바뀌었을 때 부른다.
    ///
    /// 반복 알림은 예약 시점의 문구를 본문에 박아 들고 기기에 남는다 — 다시 예약하지 않으면
    /// 사용자가 메시지 관리에서 무엇을 바꾸든 옛 문구가 계속 울린다. 예전에는 설정 화면의
    /// "저장"이 그 재예약을 맡았는데, 바꾸는 즉시 반영으로 바뀌며 그 버튼이 사라졌다.
    ///
    /// 알림이 꺼져 있으면 예약된 것이 없으므로 아무 일도 하지 않는다. 나중에 켜면 그 저장
    /// 경로가 이미 최신 문구를 읽어간다.
    public func applyMessageChange() {
        guard isEnabled else { return }
        applyChangesSoon()
    }

    /// 마지막 변경에서 잠깐 기다렸다가 한 번만 저장한다.
    ///
    /// 저장은 알림을 전부 다시 등록하고 옛 그룹을 지우는 일이라 가볍지 않다. 시간 다이얼을
    /// 굴리는 동안 매 틱마다 부르면 스크롤 한 번에 그 일이 수십 번 돈다.
    private func applyChangesSoon(requestAuthorization: Bool = false) {
        guard appliesChangesImmediately else { return }

        hasUnappliedChanges = true
        // 묶인 변경 중 하나라도 켜기였으면 권한을 묻는다. 끄기나 시간 변경이 뒤따랐다고
        // 방금 켠 사용자에게 물어볼 기회를 잃으면 안 된다.
        pendingRequestAuthorization = pendingRequestAuthorization || requestAuthorization

        pendingApply?.cancel()
        pendingApply = Task { [applyDelayNanoseconds] in
            if applyDelayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: applyDelayNanoseconds)
            }
            guard !Task.isCancelled else { return }

            await waitWhileSaving()
            guard !Task.isCancelled else { return }

            await applyNow()
        }
    }

    /// 대기 중인 반영이 끝나기를 기다린다. 테스트에서 쓴다.
    public func waitForPendingApply() async {
        await pendingApply?.value
    }

    /// 대기 중인 반영을 지연 없이 지금 끝낸다. 화면을 떠나기 전에 부른다.
    ///
    /// 여기서 기다리지 않으면 홈이 아직 저장되지 않은 일정을 읽어 "다음 알림"에 옛 시각을
    /// 그린다. 시간을 바꾸자마자 뒤로 나가는 것은 흔한 조작이라 지연이 끝나기를 기다릴 수 없다.
    public func flushPendingApply() async {
        if let pending = pendingApply {
            // 지연을 건너뛰게 하고, 이미 저장에 들어갔다면 그 저장이 끝날 때까지 기다린다.
            pending.cancel()
            await pending.value
            pendingApply = nil
        }

        guard hasUnappliedChanges else { return }
        await waitWhileSaving()
        await applyNow()
    }

    /// 앞선 저장이 아직 돌고 있으면 save()가 스스로 물러난다. 그 사이 바뀐 값이 통째로
    /// 버려지지 않게 끝나기를 잠깐 기다린다.
    private func waitWhileSaving() async {
        var waited = 0
        while isSaving, waited < 40, !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 50_000_000)
            waited += 1
        }
    }

    /// 저장하지 못했으면 반영되지 않은 변경으로 되돌려 둔다 — 다음 변경이나 flush가 다시 시도한다.
    private func applyNow() async {
        let requestAuthorization = pendingRequestAuthorization
        pendingRequestAuthorization = false
        hasUnappliedChanges = false

        if await save(requestAuthorization: requestAuthorization) == false {
            hasUnappliedChanges = true
            pendingRequestAuthorization = requestAuthorization
        }
    }

    @discardableResult
    public func save(requestAuthorization: Bool = false) async -> Bool {
        guard !isSaving else { return false }
        guard let pattern else {
            errorMessage = SmileReminderScheduleViewModel.invalidPatternMessage
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
                // 등록·저장·옛 그룹 취소의 순서는 ReminderGroupSwap이 지킨다. 여기서는
                // 어디서 실패했는지에 따라 사용자에게 할 말만 고른다.
                do {
                    try await ReminderGroupSwap(
                        scheduleRepository: scheduleRepository,
                        scheduler: scheduler,
                        groupIDFactory: groupIDFactory
                    ).run(
                        pattern: pattern,
                        messages: messageStore.messages,
                        previousGroupID: previousGroupID
                    )
                } catch ReminderGroupSwap.Failure.scheduling {
                    errorMessage = "알림을 등록하지 못했어요. 기존 알림은 그대로 유지했어요."
                    return false
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
