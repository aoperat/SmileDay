import SwiftUI
import CoachingKit

/// 미소 시간을 마친 뒤의 완료 화면.
///
/// 점수나 전날 대비 변화를 보여주지 않는다. 잠시 웃어본 오늘을 확인해 주고,
/// 원하면 기분과 좋은 순간을 남길 수 있게만 한다. 둘 다 비워도 완료는 온전하다.
struct SaveConfirmView: View {
    /// 리마인더 제안 정보. nil이면 제안 섹션을 그리지 않는다.
    struct ReminderOffer {
        let hour: Int
        let minute: Int
        let onAccept: () async -> Void
        let onDecline: () -> Void
    }

    enum OfferState { case showing, accepted, hidden }

    /// 격려 문구를 만들 행동 이력. 얼굴 측정값은 들어 있지 않다.
    let habitContext: HabitContext
    var reminderOffer: ReminderOffer? = nil
    /// 회고 저장 콜백. 실패하면 false를 돌려주고 화면을 닫지 않는다.
    let onConfirm: (SmileReflection) -> Bool

    @State private var offerState: OfferState = .showing
    @State private var selectedMood: String?
    @State private var momentNote: String = ""
    @State private var saveFailed = false
    @FocusState private var isNoteFocused: Bool

    private static let moods = ["😊", "🙂", "😐", "😞", "😫"]

    private var remainingCharacters: Int {
        SmileReflection.momentNoteLimit - momentNote.count
    }

    /// 저장 전에 보여주는 문구라, 사용자가 한 줄 기록을 쓰면 그 자리에서 함께 바뀐다.
    private var encouragement: String {
        let hasNote = SmileReflection.normalizedMomentNote(momentNote) != nil
        return HabitEncouragementEngine.evaluate(habitContext.withMomentNote(hasNote)).message
    }

    var body: some View {
        ZStack {
            SDColor.cream.ignoresSafeArea()

            ConfettiDots()

            ScrollView {
                VStack(spacing: 18) {
                    SunFaceView()

                    Text(SharedStrings.checkInCompleted)
                        .font(.headline.bold())
                        .foregroundStyle(SDColor.ink)

                    Text(encouragement)
                        .font(.subheadline)
                        .foregroundStyle(SDColor.muted)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.2), value: encouragement)

                    moodSection

                    momentNoteSection

                    if let reminderOffer, offerState != .hidden {
                        ReminderOfferCard(offer: reminderOffer, state: $offerState)
                    }

                    if saveFailed {
                        Text(SharedStrings.saveFailed)
                            .font(.caption.bold())
                            .foregroundStyle(SDColor.coralDeep)
                            .multilineTextAlignment(.center)
                    }

                    Button("확인") {
                        confirm()
                    }
                    .buttonStyle(SDPrimaryButtonStyle())
                    .frame(width: 240)
                    .padding(.top, 8)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var moodSection: some View {
        VStack(spacing: 8) {
            Text(SharedStrings.moodQuestion)
                .font(.caption.weight(.bold))
                .foregroundStyle(SDColor.muted)
            HStack(spacing: 12) {
                ForEach(Self.moods, id: \.self) { mood in
                    Button {
                        selectedMood = selectedMood == mood ? nil : mood
                    } label: {
                        Text(mood)
                            .font(.system(size: 28))
                            .opacity(selectedMood == nil || selectedMood == mood ? 1 : 0.35)
                            .scaleEffect(selectedMood == mood ? 1.15 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(moodLabel(for: mood)))
                    .accessibilityAddTraits(selectedMood == mood ? [.isSelected] : [])
                }
            }
            .animation(.spring(duration: 0.25), value: selectedMood)
        }
        .padding(.top, 4)
    }

    private var momentNoteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(SharedStrings.momentNoteQuestion)
                .font(.caption.weight(.bold))
                .foregroundStyle(SDColor.muted)

            TextField(SharedStrings.momentNotePlaceholder, text: $momentNote, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(SDColor.ink)
                .lineLimit(2...4)
                .focused($isNoteFocused)
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onChange(of: momentNote) { _, newValue in
                    // 200자를 넘기면 입력 단계에서 막는다. 저장소도 같은 한도로 한 번 더 정규화한다.
                    if newValue.count > SmileReflection.momentNoteLimit {
                        momentNote = String(newValue.prefix(SmileReflection.momentNoteLimit))
                    }
                }
                .accessibilityLabel(Text(SharedStrings.momentNoteQuestion))
                .accessibilityValue(Text(momentNote.isEmpty ? SharedStrings.momentNoteOptionalHint : momentNote))

            HStack {
                Text(SharedStrings.momentNoteOptionalHint)
                Spacer()
                Text("\(momentNote.count)/\(SmileReflection.momentNoteLimit)")
                    .monospacedDigit()
                    .accessibilityLabel(Text("남은 글자 수 \(remainingCharacters)자"))
            }
            .font(.caption2)
            .foregroundStyle(SDColor.muted)
        }
    }

    private func moodLabel(for mood: String) -> String {
        switch mood {
        case "😊": "아주 좋아요"
        case "🙂": "괜찮아요"
        case "😐": "그저 그래요"
        case "😞": "가라앉아요"
        default: "많이 지쳤어요"
        }
    }

    private func confirm() {
        isNoteFocused = false
        let reflection = SmileReflection(mood: selectedMood, momentNote: momentNote)
        if onConfirm(reflection) {
            saveFailed = false
        } else {
            saveFailed = true
        }
    }
}

/// 체크인 직후 리마인더 설정 제안 카드.
private struct ReminderOfferCard: View {
    let offer: SaveConfirmView.ReminderOffer
    @Binding var state: SaveConfirmView.OfferState

    var body: some View {
        Group {
            if state == .accepted {
                Label("리마인더가 설정되었어요", systemImage: "bell.badge.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(SDColor.mint)
            } else {
                VStack(spacing: 10) {
                    Text("내일도 이 시간(\(String(format: "%02d:%02d", offer.hour, offer.minute)))에 알려드릴까요?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SDColor.ink)

                    HStack(spacing: 10) {
                        Button("나중에") {
                            offer.onDecline()
                            withAnimation { state = .hidden }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SDColor.muted)

                        Button("알림 받기") {
                            Task {
                                await offer.onAccept()
                                withAnimation { state = .accepted }
                            }
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(SDColor.coral, in: Capsule())
                    }
                }
                .padding(14)
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}

/// 웃는 해 얼굴 — 저장 완료 시그니처.
struct SunFaceView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0xFFF6DE), Color(hex: 0xFFE29E)],
                        center: UnitPoint(x: 0.5, y: 0.38),
                        startRadius: 8,
                        endRadius: 90
                    )
                )
                .shadow(color: SDColor.apricot.opacity(0.5), radius: 18, y: 9)

            Circle().fill(SDColor.ink).frame(width: 11)
                .offset(x: -31, y: -15)
            Circle().fill(SDColor.ink).frame(width: 11)
                .offset(x: 31, y: -15)

            SmileArc(depth: 0.9)
                .stroke(SDColor.coral, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .frame(width: 74, height: 13)
                .offset(y: 18)
        }
        .frame(width: 140, height: 140)
    }
}

/// 팔레트 색 점 몇 개로 만든 잔잔한 컨페티.
struct ConfettiDots: View {
    private static let dots: [(color: Color, size: CGFloat, x: CGFloat, y: CGFloat)] = [
        (SDColor.coral, 7, -0.32, -0.34),
        (SDColor.sun, 5, 0.14, -0.39),
        (SDColor.mint, 6, 0.30, -0.26),
        (SDColor.apricot, 5, -0.42, -0.20),
        (SDColor.lilac, 6, -0.10, -0.42),
        (SDColor.coral, 5, 0.38, -0.16),
    ]

    var body: some View {
        GeometryReader { geometry in
            ForEach(Array(Self.dots.enumerated()), id: \.offset) { _, dot in
                Circle()
                    .fill(dot.color.opacity(0.85))
                    .frame(width: dot.size)
                    .position(
                        x: geometry.size.width * (0.5 + dot.x),
                        y: geometry.size.height * (0.5 + dot.y)
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    SaveConfirmView(
        habitContext: HabitContext(
            todayCheckInCount: 1,
            streakDays: 3,
            recentSevenDayCount: 3,
            daysSincePreviousCheckIn: 1,
            hasMomentNote: false
        )
    ) { _ in true }
}
