import SwiftUI
import SwiftData
import CoachingKit

/// 알림 중심 MVP의 홈. 점수, 기준선, 얼굴 분석, 기분 기록이 없다.
struct SmileMVPHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(NotificationRouter.self) private var notificationRouter

    @State private var viewModel: SmileHomeViewModel?
    @State private var selectedGuideID: String = SmileGuideCatalog.default.id
    @State private var launch: GuideLaunch?
    @State private var isShowingSettings = false

    /// 가이드 화면을 여는 요청 하나. 알림으로 들어왔는지 홈에서 눌렀는지를 함께 들고 간다.
    private struct GuideLaunch: Identifiable {
        let id = UUID()
        let guide: SmileGuide
        let source: SmileMomentSource
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SDColor.cream.ignoresSafeArea()

                if let viewModel {
                    ScrollView {
                        VStack(spacing: 16) {
                            TodayCard(
                                count: viewModel.todayCompletionCount,
                                guides: viewModel.guides,
                                selectedGuideID: $selectedGuideID,
                                onStart: {
                                    launch = GuideLaunch(
                                        guide: SmileGuideCatalog.guide(id: selectedGuideID),
                                        source: .manual
                                    )
                                }
                            )

                            NextReminderCard(reminder: viewModel.nextReminder)

                            RecentSevenDaysCard(
                                days: viewModel.recentSevenDays,
                                weekActiveDayCount: viewModel.weekActiveDayCount
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
                    }
                    .accessibilityLabel("설정")
                }
            }
            .navigationDestination(isPresented: $isShowingSettings) {
                SmileMVPSettingsView()
            }
        }
        .tint(SDColor.coral)
        .onAppear {
            if viewModel == nil {
                viewModel = SmileHomeViewModel(
                    momentRepository: SmileMomentRepository(modelContext: modelContext),
                    reminderRepository: ReminderRepository(modelContext: modelContext)
                )
            }
            try? viewModel?.refresh()
        }
        // 앱으로 돌아올 때 오늘 횟수와 다음 알림을 다시 계산한다.
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            try? viewModel?.refresh()
        }
        // 알림 탭은 cold launch와 foreground 모두 여기로 들어온다.
        .onChange(of: notificationRouter.pendingSmileGuide, initial: true) { _, payload in
            guard let payload else { return }
            launch = GuideLaunch(guide: payload.guide, source: .notification)
            notificationRouter.pendingSmileGuide = nil
        }
        .fullScreenCover(item: $launch) { launch in
            SmileGuideView(
                guide: launch.guide,
                source: launch.source,
                repository: SmileMomentRepository(modelContext: modelContext),
                onCompleted: { try? viewModel?.refresh() }
            )
        }
        .onChange(of: launch == nil) { _, isClosed in
            // 완료 직후 바로 닫아도 홈 숫자가 갱신되도록 닫힐 때 한 번 더 읽는다.
            guard isClosed else { return }
            try? viewModel?.refresh()
        }
    }
}

private struct TodayCard: View {
    let count: Int
    let guides: [SmileGuide]
    @Binding var selectedGuideID: String
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(SharedStrings.todayCountTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SDColor.muted)

                if count == 0 {
                    Text(SharedStrings.noSmileYetToday)
                        .font(.title3.bold())
                        .foregroundStyle(SDColor.ink)
                } else {
                    Text("\(count)번")
                        .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(SDColor.ink)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("오늘 미소 \(count)번")

            GuidePickerRow(selectedID: selectedGuideID, guides: guides) { guideID in
                selectedGuideID = guideID
            }

            Button(SharedStrings.smileNowAction, action: onStart)
                .buttonStyle(SDPrimaryButtonStyle())
        }
        .sdCard()
    }
}

private struct NextReminderCard: View {
    let reminder: UpcomingReminder?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(SDColor.apricot, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(SharedStrings.nextReminderTitle)
                    .font(.caption)
                    .foregroundStyle(SDColor.muted)

                if let reminder {
                    Text("\(timeText(reminder.date)) · \(reminder.guide.title)")
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

    private func timeText(_ date: Date) -> String {
        date.formatted(.dateTime.locale(SDFormat.koreanLocale).hour().minute())
    }
}

private struct RecentSevenDaysCard: View {
    let days: [SmileDayCount]
    let weekActiveDayCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(SharedStrings.recentSevenDaysTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SDColor.muted)

                Spacer()

                Text("\(SharedStrings.weekActiveDaysTitle) \(weekActiveDayCount)일")
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
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(day.hasSmile ? AnyShapeStyle(SDColor.primaryGradient) : AnyShapeStyle(SDColor.shell.opacity(0.6)))
                    .frame(height: 36)

                if day.count > 0 {
                    Text("\(day.count)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.white)
                }
            }

            Text(weekdayText)
                .font(.caption2)
                .foregroundStyle(SDColor.muted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(dateText) \(day.count)번")
    }

    private var weekdayText: String {
        day.date.formatted(.dateTime.locale(SDFormat.koreanLocale).weekday(.narrow))
    }

    private var dateText: String {
        day.date.formatted(.dateTime.locale(SDFormat.koreanLocale).month().day())
    }
}
