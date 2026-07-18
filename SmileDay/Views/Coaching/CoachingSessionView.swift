import SwiftUI
import SwiftData
import CoachingKit

struct CoachingSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var trackingSession = ARKitFaceTrackingSession()
    @State private var viewModel: CoachingViewModel?
    @State private var isShowingSummary = false
    @State private var errorMessage: String?

    let baseline: Baseline

    var body: some View {
        ZStack(alignment: .bottom) {
            ARFacePreviewRepresentable(session: trackingSession)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                if let measurement = viewModel?.latestMeasurement {
                    let delta = ScoreCalculator.delta(current: measurement, baseline: baseline.measurement)
                    GaugeView(value: delta)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("완료") {
                    complete()
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
        .sheet(isPresented: $isShowingSummary, onDismiss: {
            dismiss()
        }) {
            if let viewModel, case let .completed(scoreDelta) = viewModel.phase {
                SessionSummarySheet(scoreDelta: scoreDelta)
            }
        }
    }

    private func complete() {
        guard let viewModel else { return }
        do {
            try viewModel.complete()
        } catch {
            errorMessage = SharedStrings.saveFailed
            return
        }
        isShowingSummary = true
    }
}

private struct GaugeView: View {
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("기준선 대비 변화")
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: min(max((value + 1) / 2, 0), 1))
                .tint(.accentColor)
        }
    }
}
