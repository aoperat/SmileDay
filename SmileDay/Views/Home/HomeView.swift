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
                        StatCard(value: "\(viewModel.weekCheckInDayCount)일", label: "이번 주 웃어본 날")
                        StatCard(value: "\(viewModel.weekMomentNoteCount)개", label: "남긴 좋은 순간")
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
            reminderNudgeSubtitle = "원하는 시간에 짧은 질문을 보내드려요"
        } else {
            reminderNudgeTitle = "\(missing.map(\.displayName).joined(separator: "·")) 리마인더도 설정해볼까요?"
            reminderNudgeSubtitle = "하루 중 잠시 쉬어갈 시간을 만들어드려요"
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
                + Text("잠시").foregroundStyle(SDColor.coral)
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

    /// 오늘의 미소 시간 상태 카드. 완료 여부와 다음 행동만 보여주고 점수는 쓰지 않는다.
    private var heroCard: some View {
        VStack(spacing: 12) {
            SunFaceView()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            if viewModel?.hasCheckedInToday == true {
                Label("오늘의 미소 시간을 마쳤어요", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(SDColor.mint)

                if let count = viewModel?.todayCheckInCount, count > 1 {
                    Text("오늘 \(count)번 웃어봤어요")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SDColor.muted)
                }

                if let note = viewModel?.latestMomentNote {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(SDColor.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(SDColor.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityLabel(Text("최근 남긴 좋은 순간, \(note)"))
                }

                Button("한 번 더 웃어보기") {
                    onStartCoaching()
                }
                .font(.subheadline.bold())
                .foregroundStyle(SDColor.coralDeep)
            } else {
                Text(todayPrompt)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SDColor.ink)
                    .multilineTextAlignment(.center)

                Button("오늘의 미소 시간") {
                    onStartCoaching()
                }
                .buttonStyle(SDPrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .sdCard()
    }

    /// 지금 시간대의 질문 하나. 홈에서도 알림과 같은 초대 문구를 보여준다.
    private var todayPrompt: String {
        let bucket = TimeBucket(hour: Calendar.current.component(.hour, from: .now))
        let prompts = ReminderPromptCatalog.prompts(for: bucket)
        guard !prompts.isEmpty else { return "잠시 웃어보는 시간을 가져볼까요?" }
        // 하루 안에서는 같은 질문이 유지되도록 날짜로 고른다.
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        return prompts[day % prompts.count].text
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
                Text("최근 7일 미소 시간")
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
    var icon: String = "bell.badge.fill"
    var iconColor: Color = SDColor.apricot
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(iconColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

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
