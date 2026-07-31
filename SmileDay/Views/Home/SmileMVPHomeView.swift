import SwiftUI
import SwiftData
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

                            NextReminderCard(reminder: viewModel.nextReminder)

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
                            .foregroundStyle(SDColor.coralDeep)
                    }
                    .accessibilityLabel("설정")
                }
            }
            .navigationDestination(isPresented: $isShowingSettings) {
                SmileMVPSettingsView()
            }
        }
        .tint(SDColor.coralDeep)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbarBackground(SDColor.cream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            if viewModel == nil {
                viewModel = SmileHomeViewModel(
                    momentRepository: SmileMomentRepository(modelContext: modelContext),
                    scheduleRepository: SmileReminderScheduleRepository(modelContext: modelContext)
                )
            }
            refresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
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
        do {
            try viewModel?.refresh()
            loadFailed = false
        } catch {
            loadFailed = true
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

private struct NextReminderCard: View {
    let reminder: UpcomingReminder?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SDColor.ink)
                .frame(width: 32, height: 32)
                .background(SDColor.apricot, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(SharedStrings.nextReminderTitle)
                    .font(.caption)
                    .foregroundStyle(SDColor.muted)

                if let reminder {
                    Text(reminder.date.formatted(.dateTime.locale(SDFormat.koreanLocale).hour().minute()))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SDColor.ink)
                } else {
                    Text(SharedStrings.noReminderYet)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SDColor.muted)
                }
            }

            Spacer()
        }
        .sdCard(padding: 14, cornerRadius: 20)
        .accessibilityElement(children: .combine)
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
            Circle()
                .fill(day.hasSmile ? AnyShapeStyle(SDColor.primaryGradient) : AnyShapeStyle(SDColor.shell))
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
