import SwiftUI

struct SaveConfirmView: View {
    let todayScore: Double
    let yesterdayScore: Double?
    let onConfirm: () -> Void

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
