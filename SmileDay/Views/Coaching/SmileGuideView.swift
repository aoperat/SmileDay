import SwiftUI
import SwiftData
import CoachingKit

/// 미소 가이드 실행 화면. 카메라를 켜지 않고 권한도 묻지 않는다.
///
/// 화면을 열자마자 세지 않는다. 사용자가 "시작"을 눌러야 카운트다운이 돈다.
struct SmileGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let guide: SmileGuide
    let source: SmileMomentSource
    let repository: SmileMomentRepository
    let onCompleted: () -> Void

    @State private var viewModel: SmileGuideViewModel?

    var body: some View {
        ZStack {
            SDColor.cream.ignoresSafeArea()

            if let viewModel {
                content(viewModel)
            }

            VStack {
                HStack {
                    SDCloseButton {
                        viewModel?.cancel()
                        dismiss()
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .onAppear {
            guard viewModel == nil else { return }
            viewModel = SmileGuideViewModel(
                guide: guide,
                source: source,
                repository: repository,
                onCompleted: onCompleted
            )
        }
    }

    @ViewBuilder
    private func content(_ viewModel: SmileGuideViewModel) -> some View {
        VStack(spacing: 28) {
            Spacer()

            SmileFaceGraphic(isSmiling: isSmiling(viewModel.phase))
                .frame(width: 132, height: 132)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: isSmiling(viewModel.phase))
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text(guide.title)
                    .font(.title2.bold())
                    .foregroundStyle(SDColor.ink)

                Text(guide.instruction)
                    .font(.body)
                    .foregroundStyle(SDColor.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            phaseSection(viewModel)

            Spacer()
        }
    }

    @ViewBuilder
    private func phaseSection(_ viewModel: SmileGuideViewModel) -> some View {
        switch viewModel.phase {
        case .ready:
            VStack(spacing: 12) {
                Text("\(guide.durationSeconds)초 동안 함께 있어요")
                    .font(.footnote)
                    .foregroundStyle(SDColor.muted)

                Button(SharedStrings.guideStartAction) {
                    Task { await viewModel.start() }
                }
                .buttonStyle(SDPrimaryButtonStyle())
                .padding(.horizontal, 40)
            }

        case .running(let remainingSeconds):
            Text("\(remainingSeconds)")
                .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(SDColor.coral)
                // Reduce Motion에서는 숫자만 바뀌고 커지는 전환을 생략한다.
                .contentTransition(reduceMotion ? .identity : .numericText())
                .animation(reduceMotion ? nil : .snappy, value: remainingSeconds)
                .accessibilityLabel("\(remainingSeconds)초 남았어요")

        case .completed:
            VStack(spacing: 14) {
                if viewModel.saveFailed {
                    Text(SharedStrings.guideSaveFailed)
                        .font(.headline)
                        .foregroundStyle(SDColor.coralDeep)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                } else {
                    Text(SharedStrings.guideCompleted)
                        .font(.title3.bold())
                        .foregroundStyle(SDColor.ink)
                }

                Button("닫기") { dismiss() }
                    .buttonStyle(SDInkButtonStyle())
                    .padding(.horizontal, 40)
            }
            .onAppear {
                guard !viewModel.saveFailed else { return }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        }
    }

    private func isSmiling(_ phase: SmileGuideViewModel.Phase) -> Bool {
        phase != .ready
    }
}

/// 코드로 그린 단순한 얼굴. 사용자의 얼굴이 아니라 안내용 그림이다.
struct SmileFaceGraphic: View {
    var isSmiling: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let eyeSize = size * 0.09

            ZStack {
                Circle()
                    .fill(SDColor.sun.opacity(0.35))

                HStack(spacing: size * 0.26) {
                    Circle().fill(SDColor.ink).frame(width: eyeSize, height: eyeSize)
                    Circle().fill(SDColor.ink).frame(width: eyeSize, height: eyeSize)
                }
                .offset(y: -size * 0.12)

                SmileArc(depth: isSmiling ? 0.5 : 0.02)
                    .stroke(SDColor.ink, style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
                    .frame(width: size * 0.44, height: size * 0.16)
                    .offset(y: size * 0.14)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
