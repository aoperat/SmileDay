import SwiftUI
import SwiftData
import CoachingKit

/// 진입 분기. 기준선이 있는지 묻지 않는다 — 카메라 없이 첫 실행부터 쓸 수 있어야 한다.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLoading = true
    @State private var hasCompletedOnboarding = false

    private let onboardingStore = UserDefaultsSmileOnboardingStore()

    var body: some View {
        Group {
            if isLoading {
                SplashView()
                    .transition(.opacity)
            } else if hasCompletedOnboarding {
                SmileMVPHomeView()
            } else {
                SmileMVPOnboardingView(onFinished: { hasCompletedOnboarding = true })
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
        .task {
            async let minimumSplashDuration: Void? = try? Task.sleep(for: .seconds(1.3))

            #if DEBUG
            if CommandLine.arguments.contains("-seedDemoData") {
                try? DemoSeeder.seedIfNeeded(repository: SessionRepository(modelContext: modelContext))
            }
            #endif
            let completed = onboardingStore.hasCompletedOnboarding

            _ = await minimumSplashDuration
            hasCompletedOnboarding = completed
            isLoading = false
        }
        // 로컬 알림은 앞으로 14일치만 예약해두므로 앱이 열릴 때마다 다시 채운다.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                let viewModel = SettingsViewModel(
                    reminderRepository: ReminderRepository(modelContext: modelContext),
                    sessionRepository: SessionRepository(modelContext: modelContext),
                    scheduler: UserNotificationReminderScheduler()
                )
                try? await viewModel.refreshAllScheduledReminders()
            }
        }
    }
}
