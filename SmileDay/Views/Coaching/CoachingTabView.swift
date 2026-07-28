import SwiftUI
import SwiftData
import CoachingKit

/// 미소 시간 탭: 촬영 → 완료/회고 흐름을 잇는다.
struct CoachingTabView: View {
    @Environment(\.modelContext) private var modelContext
    let baseline: Baseline
    var promptText: String? = nil
    let onFinished: () -> Void
    let onExit: () -> Void
    @State private var result: SessionResult?

    struct SessionResult {
        let completedHour: Int
        let completedMinute: Int
        let offerReminder: Bool
        /// 격려 문구를 만들 행동 이력.
        let habitContext: HabitContext
    }

    var body: some View {
        if let result {
            SaveConfirmView(
                habitContext: result.habitContext,
                reminderOffer: result.offerReminder ? SaveConfirmView.ReminderOffer(
                    hour: result.completedHour,
                    minute: result.completedMinute,
                    onAccept: {
                        let viewModel = SettingsViewModel(
                            reminderRepository: ReminderRepository(modelContext: modelContext),
                            sessionRepository: SessionRepository(modelContext: modelContext),
                            library: SmileGuideLibrary(
                                modelContext: modelContext,
                                hiddenStore: UserDefaultsHiddenSmileGuideStore()
                            ),
                            scheduler: UserNotificationReminderScheduler()
                        )
                        try? await viewModel.addReminder(hour: result.completedHour, minute: result.completedMinute)
                    },
                    onDecline: {
                        ReminderNudge(store: UserDefaultsReminderNudgeState()).declineCheckInPrompt(forHour: result.completedHour)
                    }
                ) : nil,
                onConfirm: { reflection in
                    // 저장에 실패하면 완료 화면을 닫지 않는다. 체크인 자체는 이미 저장되어 있다.
                    do {
                        try SessionRepository(modelContext: modelContext)
                            .updateReflectionOnLatestCheckIn(reflection)
                    } catch {
                        return false
                    }
                    self.result = nil
                    onFinished()
                    return true
                }
            )
        } else {
            CoachingSessionView(
                promptText: promptText,
                baseline: baseline,
                onCompleted: { completedAt in
                    result = makeResult(completedAt: completedAt)
                },
                onExit: onExit
            )
        }
    }

    /// 체크인 저장 이후의 후속 작업. 리마인더 제안이 실패해도 완료 경험을 잃지 않도록
    /// 각 단계는 실패 시 조용히 기본값으로 넘어간다.
    private func makeResult(completedAt: Date) -> SessionResult {
        let components = Calendar.current.dateComponents([.hour, .minute], from: completedAt)
        let hour = components.hour ?? 9
        let repository = SessionRepository(modelContext: modelContext)
        let registered = (try? ReminderRepository(modelContext: modelContext).registeredBuckets()) ?? []
        let nudge = ReminderNudge(store: UserDefaultsReminderNudgeState())

        // 집계를 읽지 못해도 완료 경험은 유지한다. 이때는 중립적인 기본 문구가 나온다.
        let fallbackContext = HabitContext(
            todayCheckInCount: 1,
            streakDays: 1,
            recentSevenDayCount: 1,
            daysSincePreviousCheckIn: 1,
            hasMomentNote: false
        )
        let habitContext = (try? repository.fetchLatestCheckIn())
            .flatMap { try? repository.habitContext(for: $0) } ?? fallbackContext

        return SessionResult(
            completedHour: hour,
            completedMinute: components.minute ?? 0,
            offerReminder: nudge.shouldOfferAfterCheckIn(registeredBuckets: registered, checkInHour: hour),
            habitContext: habitContext
        )
    }
}
