import SwiftUI
import SwiftData
import CoachingKit

struct BaselineCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var trackingSession = ARKitFaceTrackingSession()
    @State private var viewModel: BaselineCaptureViewModel?
    @State private var errorMessage: String?

    let onBaselineSaved: (Baseline) -> Void
    /// 저장하지 않고 나가기. nil이면 나가기 버튼을 숨긴다.
    var onCancel: (() -> Void)?

    var body: some View {
        ZStack(alignment: .bottom) {
            ARFacePreviewRepresentable(session: trackingSession)
                .ignoresSafeArea()

            FaceGuideOverlay()

            if let onCancel {
                VStack {
                    HStack {
                        SDCloseButton { onCancel() }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    Spacer()
                }
            }

            VStack(spacing: 16) {
                Text("무표정으로 얼굴을 타원 안에 맞춰주세요")
                    .font(.headline)
                    .foregroundStyle(.white)

                MeasurementTable(measurement: viewModel?.latestMeasurement)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("기준선 저장") {
                    saveBaseline()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel?.latestMeasurement == nil || viewModel?.phase != .tracking)
            }
            .padding()
            .background(.black.opacity(0.4))
        }
        .onAppear {
            let vm = BaselineCaptureViewModel(
                session: trackingSession,
                repository: SessionRepository(modelContext: modelContext)
            )
            viewModel = vm
            vm.start()
        }
        .onDisappear {
            trackingSession.stop()
        }
    }

    private func saveBaseline() {
        guard let viewModel else { return }
        do {
            try viewModel.captureBaseline()
        } catch {
            errorMessage = SharedStrings.saveFailed
            return
        }
        if case let .saved(baseline) = viewModel.phase {
            onBaselineSaved(baseline)
        }
    }
}

private struct MeasurementTable: View {
    let measurement: FaceMeasurement?

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: measurement == nil ? "face.dashed" : "checkmark.circle.fill")
                    .foregroundStyle(measurement == nil ? .yellow : .green)
                Text(measurement == nil ? "얼굴을 찾는 중..." : "얼굴 인식됨")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Spacer()
            }

            MeasurementRow(label: "입꼬리 (왼쪽)", value: measurement?.mouthCornerLeft)
            MeasurementRow(label: "입꼬리 (오른쪽)", value: measurement?.mouthCornerRight)
            MeasurementRow(label: "미간 긴장", value: measurement?.browTension)
        }
        .padding(12)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MeasurementRow: View {
    let label: String
    let value: Double?

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 96, alignment: .leading)

            ProgressView(value: min(max(value ?? 0, 0), 1))
                .tint(.white)

            Text(value.map { String(format: "%.2f", $0) } ?? "--")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 36, alignment: .trailing)
        }
    }
}
