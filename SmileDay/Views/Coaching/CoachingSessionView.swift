import SwiftUI
import SwiftData
import CoachingKit

struct CoachingSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var trackingSession = ARKitFaceTrackingSession()
    @State private var viewModel: CoachingViewModel?
    @State private var errorMessage: String?

    let baseline: Baseline
    let onCompleted: (Int, Int?) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ARFacePreviewRepresentable(session: trackingSession)
                .ignoresSafeArea()

            FaceGuideOverlay()

            HStack {
                Spacer()
                if let measurement = viewModel?.latestMeasurement {
                    let delta = ScoreCalculator.delta(current: measurement, baseline: baseline.measurement)
                    VerticalGaugeView(value: min(max((delta + 1) / 2, 0), 1))
                        .frame(width: 8, height: 220)
                        .padding(.trailing, 20)
                }
            }

            VStack {
                if viewModel?.isLightingPoor == true {
                    Label("주변이 어둡습니다. 밝은 곳에서 측정해주세요", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(.yellow.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                }
                Spacer()
            }

            VStack(spacing: 16) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    complete()
                } label: {
                    Label("측정 종료", systemImage: "stop")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel?.latestMeasurement == nil || viewModel?.phase != .tracking)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .onAppear {
            let vm = CoachingViewModel(
                session: trackingSession,
                repository: SessionRepository(modelContext: modelContext),
                baseline: baseline
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
        let yesterday = (try? viewModel.yesterdayDelta())?.map(ScoreCalculator.displayScore) ?? nil
        do {
            try viewModel.complete()
        } catch {
            errorMessage = SharedStrings.saveFailed
            return
        }
        if case let .completed(delta) = viewModel.phase {
            onCompleted(ScoreCalculator.displayScore(delta), yesterday)
        }
    }
}

struct VerticalGaugeView: View {
    let value: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Capsule().fill(.white.opacity(0.3))
                Capsule().fill(Color.accentColor)
                    .frame(height: geometry.size.height * min(max(value, 0), 1))
            }
        }
    }
}
