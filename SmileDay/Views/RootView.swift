import SwiftUI
import SwiftData
import CoachingKit

/// 진입 분기. 기준선이 있는지 묻지 않는다 — 카메라 없이 첫 실행부터 쓸 수 있어야 한다.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isLoading = true
    @State private var hasCompletedOnboarding = false
    @State private var loadFailed = false

    private let onboardingStore = UserDefaultsSmileOnboardingStore()

    var body: some View {
        Group {
            if isLoading {
                SplashView()
                    .transition(.opacity)
            } else if loadFailed {
                ZStack {
                    SDColor.cream.ignoresSafeArea()
                    AppDataLoadFailureView {
                        Task { await loadRootState(keepSplashVisible: false) }
                    }
                }
            } else if hasCompletedOnboarding {
                SmileMVPHomeView()
            } else {
                SmileMVPOnboardingView(onFinished: { hasCompletedOnboarding = true })
            }
        }
        // Morning Glow는 밝은 전용 팔레트다. 시스템 다크 모드의 흰 기본 글씨가
        // 흰 카드·크림 배경 위에서 사라지지 않도록 앱 전체를 라이트로 고정한다.
        .preferredColorScheme(.light)
        .animation(.easeInOut(duration: 0.3), value: isLoading)
        .task {
            await loadRootState(keepSplashVisible: true)
        }
    }

    private func loadRootState(keepSplashVisible: Bool) async {
        isLoading = keepSplashVisible
        loadFailed = false

        do {
            let completed = onboardingStore.hasCompletedOnboarding
            // 개별 알림 시절의 사용자는 새 시간창을 직접 확인해야 한다.
            // 새 스케줄이 없으면 기존 pending 알림을 건드리지 않고 설정 단계만 다시 보여준다.
            let hasRepeatSchedule =
                try SmileReminderScheduleRepository(modelContext: modelContext).fetchCurrent() != nil

            hasCompletedOnboarding = completed && hasRepeatSchedule
        } catch {
            loadFailed = true
        }

        // 알림 버튼이 생기기 전에 예약한 사용자는 설정을 다시 저장하기 전까지 버튼을 못 본다.
        // 같은 그룹으로 한 번만 덮어써서 붙여준다. 실패해도 화면을 막지 않는다 — 다음 실행에서
        // 다시 시도한다.
        await ReminderActionBackfill(
            scheduleRepository: SmileReminderScheduleRepository(modelContext: modelContext),
            scheduler: UserNotificationReminderScheduler()
        ).runIfNeeded()
        if keepSplashVisible {
            try? await Task.sleep(for: .seconds(1.3))
        }
        isLoading = false
    }
}
