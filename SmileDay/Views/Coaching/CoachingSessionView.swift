import SwiftUI
import SwiftData
import CoachingKit

/// 미소 시간 촬영 화면.
///
/// 얼굴 측정은 저장 시점에 계속 수행하지만 사용자에게 점수나 게이지를 보여주지 않는다.
/// 화면이 하는 일은 얼굴이 잡혔는지 알려주고, 잠시 미소 지을 여유를 주는 것뿐이다.
struct CoachingSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var trackingSession = ARKitFaceTrackingSession()
    @State private var viewModel: CoachingViewModel?
    @State private var errorMessage: String?

    /// 알림 딥링크로 진입한 경우 상단에 이어서 보여줄 질문. 일반 진입은 nil.
    var promptText: String? = nil
    let baseline: Baseline
    /// 완료 시각만 전달한다. 질문은 이 화면을 띄운 쪽이 이미 알고 있다.
    let onCompleted: (Date) -> Void
    let onExit: () -> Void

    /// 얼굴이 잡혀 저장할 수 있는 상태인지.
    private var isFaceReady: Bool { viewModel?.displayedMeasurement != nil }

    private var statusText: String {
        isFaceReady ? SharedStrings.smileInvitation : SharedStrings.alignFaceGuide
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ARFacePreviewRepresentable(session: trackingSession)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            FaceGuideOverlay()
                .accessibilityHidden(true)

            VStack {
                HStack {
                    SDCloseButton { onExit() }
                        .accessibilitySortPriority(0)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 4)

                if let promptText {
                    Text(promptText)
                        .font(.caption.bold())
                        .foregroundStyle(SDColor.ink)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal)
                        .accessibilitySortPriority(4)
                }

                if viewModel?.isLightingPoor == true {
                    GuidanceBanner(text: "조금 어두워요 · 밝은 곳에서 찍어주세요", systemImage: "exclamationmark.circle.fill")
                }
                if viewModel?.isAngleOK == false {
                    GuidanceBanner(text: "얼굴을 정면으로 비춰주세요", systemImage: "face.dashed")
                }
                Spacer()
            }

            VStack(spacing: 12) {
                Text(statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isFaceReady ? SDColor.ink : SDColor.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .animation(.easeInOut(duration: 0.2), value: isFaceReady)
                    .accessibilitySortPriority(2)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(SDColor.coralDeep)
                        .accessibilitySortPriority(1)
                }

                Button(SharedStrings.saveSmileAction) {
                    complete()
                }
                .buttonStyle(SDInkButtonStyle())
                .disabled(!isFaceReady || viewModel?.phase != .tracking)
                .accessibilityHint(isFaceReady ? "" : SharedStrings.alignFaceGuide)
                .accessibilitySortPriority(0)
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
        do {
            try viewModel.complete(promptText: promptText)
        } catch {
            errorMessage = SharedStrings.saveFailed
            return
        }
        guard viewModel.phase == .completed else { return }
        onCompleted(.now)
    }
}

/// 조명·각도처럼 측정 자체를 돕는 안내 배너.
private struct GuidanceBanner: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.bold())
            .foregroundStyle(Color(hex: 0x6B4E00))
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color(hex: 0xFFF0BE).opacity(0.95), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal)
            .accessibilitySortPriority(3)
    }
}
