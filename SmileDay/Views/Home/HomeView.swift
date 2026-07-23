import SwiftUI
import SwiftData
import CoachingKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HomeViewModel?
    @State private var showReminderNudgeCard = false
    @State private var reminderNudgeTitle = ""
    @State private var reminderNudgeSubtitle = ""
    @State private var isReminderSheetPresented = false

    let baseline: Baseline
    let onStartCoaching: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                greeting

                heroCard

                if let viewModel {
                    WeekStreakCard(
                        days: viewModel.recentWeek,
                        streak: viewModel.streakDays
                    )

                    HStack(spacing: 10) {
                        StatCard(value: "\(viewModel.weekCheckInCount)회", label: "이번 주 체크인")
                        StatCard(
                            value: viewModel.weeklyAverageScore.map { SDFormat.signedDegrees($0) } ?? "—",
                            label: "7일 평균"
                        )
                    }
                }

                if showReminderNudgeCard {
                    ReminderNudgeCard(
                        title: reminderNudgeTitle,
                        subtitle: reminderNudgeSubtitle,
                        onTap: { isReminderSheetPresented = true },
                        onDismiss: {
                            let registered = (try? ReminderRepository(modelContext: modelContext).registeredBuckets()) ?? []
                            ReminderNudge(store: UserDefaultsReminderNudgeState()).dismissHomeCard(registeredBuckets: registered)
                            withAnimation { showReminderNudgeCard = false }
                        }
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .background(SDColor.cream)
        .onAppear {
            let vm = viewModel ?? HomeViewModel(repository: SessionRepository(modelContext: modelContext))
            viewModel = vm
            try? vm.refresh()
            refreshReminderNudge()
        }
        .sheet(isPresented: $isReminderSheetPresented, onDismiss: { refreshReminderNudge() }) {
            ReminderSheet()
        }
    }

    private func refreshReminderNudge() {
        let registered = (try? ReminderRepository(modelContext: modelContext).registeredBuckets()) ?? []
        let hasAnyCheckIn = viewModel?.recentWeek.contains(where: \.checkedIn) ?? false
        let nudge = ReminderNudge(store: UserDefaultsReminderNudgeState())
        let missing = nudge.missingBuckets(registeredBuckets: registered)

        if missing.count == TimeBucket.allCases.count {
            reminderNudgeTitle = "매일 잊지 않게 알려드릴까요?"
            reminderNudgeSubtitle = "원하는 시간에 표정 질문을 보내드려요"
        } else {
            reminderNudgeTitle = "\(missing.map(\.displayName).joined(separator: "·")) 리마인더도 설정해볼까요?"
            reminderNudgeSubtitle = "하루 세 번이면 표정 습관이 더 잘 자리 잡아요"
        }
        showReminderNudgeCard = nudge.shouldShowHomeCard(registeredBuckets: registered, hasAnyCheckIn: hasAnyCheckIn)
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(Date.now.formatted(.dateTime.month(.wide).day().weekday(.wide).locale(SDFormat.koreanLocale)))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(SDColor.muted)

            (Text(greetingPrefix + ",\n오늘도 ")
                + Text("활짝").foregroundStyle(SDColor.coral)
                + Text(" 웃어볼까요?"))
                .font(.title3.bold())
                .foregroundStyle(SDColor.ink)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private var greetingPrefix: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "좋은 아침이에요"
        case 12..<18: "좋은 오후예요"
        default: "좋은 저녁이에요"
        }
    }

    private var heroCard: some View {
        VStack(spacing: 0) {
            if viewModel?.hasCheckedInToday == true {
                ArcGaugeView(score: viewModel?.todayScore, label: "오늘의 입꼬리 각도")
                Label("오늘 체크인을 완료했어요", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(SDColor.mint)
                    .padding(.top, 12)
            } else {
                ArcGaugeView(score: viewModel?.yesterdayScore, label: "어제의 입꼬리 각도")
                Button("오늘의 미소 기록하기") {
                    onStartCoaching()
                }
                .buttonStyle(SDPrimaryButtonStyle())
                .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .sdCard()
    }
}

/// 반원 아크 게이지. 점수(°)를 -10~+10 범위로 아크에 매핑한다.
struct ArcGaugeView: View {
    let score: Double?
    let label: String

    private var progress: Double {
        guard let score else { return 0 }
        return min(max((score + 10) / 20, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            semicircle(trim: 1)
                .stroke(SDColor.shell, style: StrokeStyle(lineWidth: 13, lineCap: .round))

            semicircle(trim: progress)
                .stroke(
                    LinearGradient(colors: [SDColor.apricot, SDColor.coral], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )

            VStack(spacing: 2) {
                if let score {
                    (Text(SDFormat.signedNumber(score))
                        + Text("°").font(.subheadline.bold()).foregroundStyle(SDColor.apricot))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(SDColor.ink)
                        .monospacedDigit()
                } else {
                    Text("아직 기록 전")
                        .font(.headline.bold())
                        .foregroundStyle(SDColor.muted)
                }
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SDColor.muted)
            }
            .padding(.bottom, 2)
        }
        .frame(width: 176, height: 96)
        .padding(.top, 8)
    }

    private func semicircle(trim: Double) -> Path {
        Path { path in
            path.addArc(
                center: CGPoint(x: 88, y: 92),
                radius: 80,
                startAngle: .degrees(180),
                endAngle: .degrees(180 + trim * 180),
                clockwise: false
            )
        }
    }
}

/// 오늘로 끝나는 최근 7일 체크인을 미소 곡선 위 도트로 표시.
/// 롤링 윈도라 주가 바뀌어도 직전 활동이 사라지지 않는다.
struct WeekStreakCard: View {
    let days: [DayCheckIn]
    let streak: Int

    private var todayIndex: Int { days.count - 1 }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("최근 7일 스마일")
                    .font(.subheadline.bold())
                    .foregroundStyle(SDColor.ink)
                Spacer()
                if streak > 0 {
                    Text("연속 \(streak)일째")
                        .font(.caption2.bold())
                        .foregroundStyle(Color(hex: 0x9C6A00))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: 0xFFF3D0), in: Capsule())
                }
            }

            GeometryReader { geometry in
                let rect = CGRect(x: 10, y: 6, width: geometry.size.width - 20, height: 12)

                SmileArc()
                    .stroke(SDColor.shell, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.minY + rect.height / 2)

                ForEach(Array(days.enumerated()), id: \.element.date) { index, day in
                    let point = SmileArc.point(t: CGFloat(index) / CGFloat(max(days.count - 1, 1)), in: rect)
                    Circle()
                        .fill(dotColor(day, isToday: index == todayIndex))
                        .overlay {
                            if index == todayIndex {
                                Circle().stroke(.white, lineWidth: 2)
                            }
                        }
                        .frame(width: index == todayIndex ? 13 : 10)
                        .position(point)
                }
            }
            .frame(height: 32)

            HStack {
                ForEach(Array(days.enumerated()), id: \.element.date) { index, day in
                    Text(day.date.formatted(.dateTime.weekday(.narrow).locale(SDFormat.koreanLocale)))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(index == todayIndex ? SDColor.coralDeep : SDColor.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .sdCard()
    }

    private func dotColor(_ day: DayCheckIn, isToday: Bool) -> Color {
        if day.checkedIn { return SDColor.coral }
        return isToday ? SDColor.apricot : SDColor.shell
    }
}

/// 리마인더 미설정 시간대를 채우도록 유도하는 카드.
struct ReminderNudgeCard: View {
    let title: String
    let subtitle: String
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(SDColor.apricot, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(SDColor.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(SDColor.muted)
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(SDColor.muted)
                    .padding(6)
            }
        }
        .sdCard()
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

/// 홈에서 시트로 띄우는 리마인더 설정 화면. 뷰모델 생성과 refresh를 책임진다.
private struct ReminderSheet: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        NavigationStack {
            if let viewModel {
                ReminderListView(viewModel: viewModel)
            }
        }
        .tint(SDColor.coral)
        .onAppear {
            let vm = viewModel ?? SettingsViewModel(
                reminderRepository: ReminderRepository(modelContext: modelContext),
                sessionRepository: SessionRepository(modelContext: modelContext),
                scheduler: UserNotificationReminderScheduler()
            )
            viewModel = vm
            try? vm.refresh()
        }
    }
}

struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.body, design: .rounded, weight: .heavy))
                .foregroundStyle(SDColor.ink)
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SDColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .sdCard(padding: 0, cornerRadius: 18)
    }
}
