import SwiftUI
import SwiftData
import UIKit
import CoachingKit

struct SmileMVPHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(NotificationRouter.self) private var notificationRouter

    @State private var viewModel: SmileHomeViewModel?
    @State private var launch: SmileLaunch?
    @State private var isShowingSettings = false
    @State private var isShowingLiveMonitor = false
    @State private var loadFailed = false

    private struct SmileLaunch: Identifiable {
        let id = UUID()
        let source: SmileMomentSource
        let cue: SmileCue
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SDColor.cream.ignoresSafeArea()

                if loadFailed {
                    AppDataLoadFailureView(onRetry: refresh)
                } else if let viewModel {
                    ScrollView {
                        VStack(spacing: 16) {
                            TodayCard(
                                count: viewModel.todayCompletionCount,
                                onStart: { openSmile(source: .manual) }
                            )

                            LiveMonitorCard(onOpen: { isShowingLiveMonitor = true })

                            NextReminderCard(
                                state: viewModel.reminderDelivery,
                                onOpenAppSettings: { isShowingSettings = true },
                                onOpenSystemSettings: {
                                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                    UIApplication.shared.open(url)
                                }
                            )

                            RecentSevenDaysCard(
                                days: viewModel.recentSevenDays,
                                totalCount: viewModel.recentSevenDayTotal
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("스마일데이")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(SDColor.sunDeep)
                    }
                    .accessibilityLabel("설정")
                }
            }
            .navigationDestination(isPresented: $isShowingSettings) {
                // 아래 onChange는 뒤로 가기를 누른 순간 돈다 — 설정의 반영이 아직 지연
                // 중이면 그때 읽은 값은 옛 일정이다. 반영이 끝난 뒤 한 번 더 읽는다.
                SmileMVPSettingsView(onScheduleApplied: refresh)
            }
        }
        .tint(SDColor.sunDeep)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbarBackground(SDColor.cream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            if viewModel == nil {
                viewModel = SmileHomeViewModel(
                    momentRepository: SmileMomentRepository(modelContext: modelContext),
                    scheduleRepository: SmileReminderScheduleRepository(modelContext: modelContext),
                    scheduler: UserNotificationReminderScheduler()
                )
            }
            refresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refresh()
        }
        // 설정 화면은 같은 앱 안에서 밀고 당기므로 scenePhase가 바뀌지 않는다. 갱신하지
        // 않으면 알림을 꺼두고 돌아와도 "다음 알림"이 옛 값 그대로 남는다.
        .onChange(of: isShowingSettings) { _, isShowing in
            guard !isShowing else { return }
            refresh()
        }
        .onChange(of: notificationRouter.pendingSmileGuide, initial: true) { _, payload in
            guard payload != nil else { return }
            openSmile(source: .notification)
            notificationRouter.pendingSmileGuide = nil
        }
        // 앱이 떠 있는 채로 알림 배너의 "웃었어요"를 누르면 scenePhase가 안 바뀌어
        // 오늘 횟수가 옛 값에 머문다. 그 경우에만 여기서 다시 읽는다.
        .onChange(of: notificationRouter.recordedWithoutGuideCount) { _, _ in
            refresh()
        }
        .fullScreenCover(item: $launch) { launch in
            SmileGuideView(
                cue: launch.cue,
                source: launch.source,
                repository: SmileMomentRepository(modelContext: modelContext),
                onCompleted: refresh
            )
        }
        .fullScreenCover(isPresented: $isShowingLiveMonitor) {
            LiveSmileMonitorView()
        }
        .onChange(of: launch == nil) { _, isClosed in
            guard isClosed else { return }
            refresh()
        }
    }

    private func openSmile(source: SmileMomentSource) {
        let selector = SmileCueSelector(store: UserDefaultsSmileCueCursorStore())
        launch = SmileLaunch(source: source, cue: selector.next())
    }

    private func refresh() {
        Task {
            do {
                try await viewModel?.refresh()
                loadFailed = false
            } catch {
                loadFailed = true
            }
        }
    }
}

private struct TodayCard: View {
    let count: Int
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(SharedStrings.todayCountTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SDColor.muted)

                Text("\(count)번")
                    .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(SDColor.ink)

                Text(count == 0 ? SharedStrings.noSmileYetToday : "오늘 웃어본 순간이 하나씩 쌓이고 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(SDColor.muted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("오늘 미소 \(count)번")

            Button(SharedStrings.smileNowAction, action: onStart)
                .buttonStyle(SDPrimaryButtonStyle())
        }
        .sdCard()
    }
}

/// 보조 행동. 기본 CTA인 `지금 한 번 웃기`보다 약하게 둔다.
///
/// TrueDepth가 없는 기기에서도 카드는 그대로 보인다 — 열어봐야 알 수 있는 사실로
/// 홈의 다른 기능을 가리지 않는다. 사용할 수 없으면 모니터 화면이 그렇게 안내한다.
private struct LiveMonitorCard: View {
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SDColor.ink)
                    .frame(width: 32, height: 32)
                    .background(SDColor.sun, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(SharedStrings.liveMonitorTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SDColor.ink)

                    Text(SharedStrings.liveMonitorEntrySummary)
                        .font(.caption)
                        .foregroundStyle(SDColor.muted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SDColor.muted)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .sdCard(padding: 14, cornerRadius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityHint(SharedStrings.liveMonitorEntrySummary)
    }
}

/// 다음 알림 시각, 또는 알림이 오지 못하는 이유와 고치는 방법.
///
/// 예약된 일정만 보고 시각을 적으면, iOS 권한이 꺼진 사용자에게 오지 않을 알림을 약속하게
/// 된다. 그래서 `ReminderDeliveryState`가 판단한 결과만 그린다.
private struct NextReminderCard: View {
    let state: ReminderDeliveryState
    let onOpenAppSettings: () -> Void
    let onOpenSystemSettings: () -> Void

    var body: some View {
        // 알림이 오지 못하는 상태에서는 카드 전체가 버튼이다. 작은 글씨를 정확히 누르게
        // 하는 것보다, 눈에 걸린 곳을 그냥 누르면 고치러 가는 편이 맞다.
        Group {
            if state.needsAttention {
                Button(action: action) { card }
                    .buttonStyle(.plain)
                    .accessibilityHint(SharedStrings.reminderTurnOnAction)
            } else {
                card
            }
        }
    }

    private var card: some View {
        HStack(alignment: state.needsAttention ? .top : .center, spacing: 12) {
            Image(systemName: state.needsAttention ? "bell.slash.fill" : "bell.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SDColor.ink)
                .frame(width: 32, height: 32)
                .background(state.needsAttention ? SDColor.shell : SDColor.apricot, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(SDColor.muted)

                if case .scheduled(let reminder) = state {
                    Text(reminder.date.formatted(.dateTime.locale(SDFormat.koreanLocale).hour().minute()))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SDColor.ink)
                } else {
                    Text(detail)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SDColor.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(SharedStrings.reminderTurnOnAction)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SDColor.sunDeep)
                        .padding(.top, 6)
                }
            }

            Spacer(minLength: 0)

            if state.needsAttention {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SDColor.muted)
                    .accessibilityHidden(true)
            }
        }
        .sdCard(padding: 14, cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch state {
        case .scheduled: SharedStrings.nextReminderTitle
        case .blockedByPermission: SharedStrings.reminderBlockedTitle
        case .permissionNotRequested: SharedStrings.reminderNotRequestedTitle
        case .off: SharedStrings.reminderOffTitle
        }
    }

    private var detail: String {
        switch state {
        case .scheduled: ""
        case .blockedByPermission: SharedStrings.reminderBlockedDetail
        case .permissionNotRequested: SharedStrings.reminderNotRequestedDetail
        case .off: SharedStrings.reminderOffDetail
        }
    }

    /// 권한이 거부된 상태는 앱 안에서 되돌릴 수 없다 — iOS는 한 번만 묻는다. 그때만
    /// 설정 앱으로 보내고, 나머지는 앱 안의 설정 화면에서 해결된다.
    private var action: () -> Void {
        switch state {
        case .blockedByPermission: onOpenSystemSettings
        case .scheduled, .permissionNotRequested, .off: onOpenAppSettings
        }
    }
}

private struct RecentSevenDaysCard: View {
    let days: [SmileDayCount]
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(SharedStrings.recentSevenDaysTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SDColor.muted)

                Spacer()

                Text("총 \(totalCount)번")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SDColor.ink)
            }

            HStack(spacing: 6) {
                ForEach(days) { day in
                    DayDot(day: day)
                }
            }
        }
        .sdCard()
    }
}

private struct DayDot: View {
    let day: SmileDayCount

    var body: some View {
        VStack(spacing: 5) {
            // 노랑은 흰 카드 위에서 1.5:1이라 채운 점만으로는 형태가 읽히지 않는다.
            // 테두리가 윤곽을 만든다 — `sunDeep`은 흰 배경에서 5.4:1이다.
            // 빈 점에는 테두리를 두지 않는다. 그 차이가 "웃은 날"의 표시다.
            Circle()
                .fill(day.hasSmile ? AnyShapeStyle(SDColor.primaryGradient) : AnyShapeStyle(SDColor.shell))
                .overlay {
                    if day.hasSmile {
                        Circle().strokeBorder(SDColor.sunDeep, lineWidth: 2)
                    }
                }
                .frame(height: 32)

            Text(day.count > 0 ? "\(day.count)" : "·")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(day.count > 0 ? SDColor.ink : SDColor.muted)

            Text(day.date.formatted(.dateTime.locale(SDFormat.koreanLocale).weekday(.narrow)))
                .font(.caption2)
                .foregroundStyle(SDColor.muted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(day.date.formatted(.dateTime.locale(SDFormat.koreanLocale).month().day())) \(day.count)번"
        )
    }
}
