import SwiftUI
import SwiftData
import CoachingKit

struct BaselineCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var trackingSession = ARKitFaceTrackingSession()
    @State private var viewModel: BaselineCaptureViewModel?
    @State private var errorMessage: String?

    let onBaselineSaved: (Baseline) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ARFacePreviewRepresentable(session: trackingSession)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("무표정으로 카메라를 바라봐주세요")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("이 앱은 의학적 효과를 보장하지 않습니다. 심한 비대칭이나 안면마비가 의심되면 전문의 상담을 권장합니다.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

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
