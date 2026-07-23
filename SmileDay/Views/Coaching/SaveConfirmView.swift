import SwiftUI

struct SaveConfirmView: View {
    /// 리마인더 제안 정보. nil이면 제안 섹션을 그리지 않는다.
    struct ReminderOffer {
        let hour: Int
        let minute: Int
        let onAccept: () async -> Void
        let onDecline: () -> Void
    }

    enum OfferState { case showing, accepted, hidden }

    let todayScore: Double
    let yesterdayScore: Double?
    var reminderOffer: ReminderOffer? = nil
    /// 기분 이모지 선택 콜백. nil이면 무드 섹션을 그리지 않는다.
    var onMoodSelected: ((String) -> Void)? = nil
    let onConfirm: () -> Void

    @State private var offerState: OfferState = .showing
    @State private var selectedMood: String?
    private static let moods = ["😊", "🙂", "😐", "😞", "😫"]

    var body: some View {
        ZStack {
            SDColor.cream.ignoresSafeArea()

            ConfettiDots()

            VStack(spacing: 18) {
                Spacer()

                SunFaceView()

                Text("오늘의 기록이 저장되었어요")
                    .font(.headline.bold())
                    .foregroundStyle(SDColor.ink)

                HStack(spacing: 10) {
                    if let yesterdayScore {
                        Text("어제 \(SDFormat.signedDegrees(yesterdayScore))")
                            .foregroundStyle(SDColor.muted)
                        Image(systemName: "arrow.right")
                            .font(.footnote)
                            .foregroundStyle(SDColor.muted)
                    }
                    Text("오늘 \(SDFormat.signedDegrees(todayScore))")
                        .font(.title3.bold())
                        .foregroundStyle(SDColor.coralDeep)
                }
                .font(.body)
                .monospacedDigit()

                if let yesterdayScore, todayScore > yesterdayScore {
                    Text("어제보다 \(SDFormat.signedDegrees(todayScore - yesterdayScore)) 올라갔어요")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(SDColor.mint, in: Capsule())
                }

                if onMoodSelected != nil {
                    VStack(spacing: 8) {
                        Text("지금 기분은 어때요?")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(SDColor.muted)
                        HStack(spacing: 12) {
                            ForEach(Self.moods, id: \.self) { mood in
                                Button {
                                    selectedMood = mood
                                    onMoodSelected?(mood)
                                } label: {
                                    Text(mood)
                                        .font(.system(size: 28))
                                        .opacity(selectedMood == nil || selectedMood == mood ? 1 : 0.35)
                                        .scaleEffect(selectedMood == mood ? 1.15 : 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .animation(.spring(duration: 0.25), value: selectedMood)
                    }
                    .padding(.top, 4)
                }

                if let reminderOffer, offerState != .hidden {
                    ReminderOfferCard(offer: reminderOffer, state: $offerState)
                }

                Button("확인") {
                    onConfirm()
                }
                .buttonStyle(SDPrimaryButtonStyle())
                .frame(width: 240)
                .padding(.top, 8)

                Spacer()
            }
            .padding()
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
    SaveConfirmView(todayScore: 3.0, yesterdayScore: 1.0, onConfirm: {})
}
