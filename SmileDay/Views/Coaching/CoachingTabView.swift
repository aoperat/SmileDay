import SwiftUI
import SwiftData
import CoachingKit

struct CoachingTabView: View {
    @Environment(\.modelContext) private var modelContext
    let baseline: Baseline
    var promptText: String? = nil
    let onFinished: () -> Void
    let onExit: () -> Void
    @State private var result: SessionResult?

    struct SessionResult {
        let todayScore: Double
        let yesterdayScore: Double?
        let completedHour: Int
        let completedMinute: Int
        let offerReminder: Bool
    }

    var body: some View {
        if let result {
            SaveConfirmView(
                todayScore: result.todayScore,
                yesterdayScore: result.yesterdayScore,
                reminderOffer: result.offerReminder ? SaveConfirmView.ReminderOffer(
                    hour: result.completedHour,
                    minute: result.completedMinute,
                    onAccept: {
                        let viewModel = SettingsViewModel(
                            reminderRepository: ReminderRepository(modelContext: modelContext),
                            sessionRepository: SessionRepository(modelContext: modelContext),
                            scheduler: UserNotificationReminderScheduler()
                        )
                        try? await viewModel.addReminder(hour: result.completedHour, minute: result.completedMinute)
                    },
                    onDecline: {
                        ReminderNudge(store: UserDefaultsReminderNudgeState()).declineCheckInPrompt(forHour: result.completedHour)
                    }
                ) : nil,
                onMoodSelected: { mood in
                    try? SessionRepository(modelContext: modelContext).updateMoodOnLatestCheckIn(mood)
                }
            ) {
                self.result = nil
                onFinished()
            }
        } else {
            CoachingSessionView(
                promptText: promptText,
                baseline: baseline,
                onCompleted: { today, yesterday in
                    let components = Calendar.current.dateComponents([.hour, .minute], from: .now)
                    let hour = components.hour ?? 9
                    let registered = (try? ReminderRepository(modelContext: modelContext).registeredBuckets()) ?? []
                    let nudge = ReminderNudge(store: UserDefaultsReminderNudgeState())
                    result = SessionResult(
                        todayScore: today,
                        yesterdayScore: yesterday,
                        completedHour: hour,
                        completedMinute: components.minute ?? 0,
                        offerReminder: nudge.shouldOfferAfterCheckIn(registeredBuckets: registered, checkInHour: hour)
                    )
                },
                onExit: onExit
            )
        }
    }
}
