import SwiftUI
import SwiftData
import CoachingKit

struct CoachingSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var trackingSession = ARKitFaceTrackingSession()
    @State private var viewModel: CoachingViewModel?
    @State private var errorMessage: String?

    let baseline: Baseline
    let onCompleted: (Double, Double?) -> Void
    let onExit: () -> Void

    private var liveDelta: Double? {
        viewModel?.displayedMeasurement.map {
            ScoreCalculator.delta(current: $0, baseline: baseline.measurement)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ARFacePreviewRepresentable(session: trackingSession)
                .ignoresSafeArea()

            FaceGuideOverlay()

            // 게이지는 ZStack의 bottom 정렬과 무관하게 오른쪽 세로 중앙에 둔다.
            HStack {
                Spacer()
                if let delta = liveDelta {
                    VStack(spacing: 7) {
                        Text(SDFormat.signedDegrees(delta * 10))
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(SDColor.coralDeep)
                            .monospacedDigit()
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.92), in: Capsule())

                        VerticalGaugeView(value: min(max((delta + 1) / 2, 0), 1))
                            .frame(width: 10, height: 200)
                    }
                    .padding(.trailing, 20)
                }
            }
            .frame(maxHeight: .infinity)

            VStack {
                HStack {
                    SDCloseButton { onExit() }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 4)

                if viewModel?.isLightingPoor == true {
                    Label("조금 어두워요 · 밝은 곳에서 측정해 주세요", systemImage: "exclamationmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Color(hex: 0x6B4E00))
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: 0xFFF0BE).opacity(0.95), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal)
                }
                if viewModel?.isAngleOK == false {
                    Label("얼굴을 정면으로 비춰주세요", systemImage: "face.dashed")
                        .font(.caption.bold())
                        .foregroundStyle(Color(hex: 0x6B4E00))
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: 0xFFF0BE).opacity(0.95), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal)
                }
                Spacer()
            }

            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("지금 미소 크기")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SDColor.muted)
                    Spacer()
                    Text(liveDelta.map { SDFormat.signedDegrees($0 * 10) } ?? "—")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(SDColor.coralDeep)
                        .monospacedDigit()
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(SDColor.coralDeep)
                }

                Button("측정 종료") {
                    complete()
                }
                .buttonStyle(SDInkButtonStyle())
                .disabled(viewModel?.displayedMeasurement == nil || viewModel?.phase != .tracking)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background {
                UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26)
                    .fill(.white.opacity(0.94))
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .onAppear {
            let vm = CoachingViewModel(
                session: trackingSession,
                repository: SessionRepository(modelContext: modelContext),
                baseline: baseline,
                metricKeys: .arKit
            )
            viewModel = vm
            vm.start()
        }
        .onDisappear {
            trackingSession.stop()
        }
    }

    private func complete() {
        guard let viewModel else { return }
        let yesterday = (try? viewModel.yesterdayDelta())?.map(ScoreCalculator.displayValue) ?? nil
        do {
            try viewModel.complete()
        } catch {
            errorMessage = SharedStrings.saveFailed
            return
        }
        if case let .completed(delta) = viewModel.phase {
            onCompleted(ScoreCalculator.displayValue(delta), yesterday)
        }
    }
}

struct VerticalGaugeView: View {
    let value: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Capsule().fill(.white.opacity(0.45))
                Capsule().fill(SDColor.gaugeGradient)
                    .frame(height: geometry.size.height * min(max(value, 0), 1))
            }
        }
    }
}
