import SwiftUI
import AVKit
import Combine
import CoachingKit

/// 플레이어 종료 시 CareView로 전달되는 재생 결과.
struct CarePlayResult {
    let completed: Bool
    let completedSteps: Int
    let startedAt: Date
}

struct CarePlayerView: View {
    let practice: SmilePractice
    let onClose: (CarePlayResult) -> Void

    @State private var currentStepIndex = 0
    @State private var remainingSeconds = 0
    @State private var player: AVPlayer?
    @State private var startedAt = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isLastStep: Bool { currentStepIndex >= practice.steps.count - 1 }

    private var currentStep: SmilePracticeStep? {
        practice.steps.indices.contains(currentStepIndex) ? practice.steps[currentStepIndex] : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                SDCloseButton {
                    onClose(CarePlayResult(completed: false, completedSteps: currentStepIndex, startedAt: startedAt))
                }
                Text(practice.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(SDColor.ink)
                Spacer()
            }

            Text(practice.purpose)
                .font(.caption)
                .foregroundStyle(SDColor.muted)

            videoArea

            VStack(alignment: .leading, spacing: 5) {
                // 라벨("n/m 단계")과 일치하도록 진행 중인 단계까지 채운다.
                ProgressView(
                    value: Double(min(currentStepIndex + 1, practice.steps.count)),
                    total: Double(max(practice.steps.count, 1))
                )
                .tint(SDColor.coral)
                HStack {
                    Text("\(min(currentStepIndex + 1, practice.steps.count))/\(practice.steps.count) 단계")
                    Spacer()
                    Text(practice.durationText)
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(SDColor.muted)
                .monospacedDigit()
            }

            Text("함께 해보기")
                .font(.caption.bold())
                .foregroundStyle(SDColor.muted)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(practice.steps.enumerated()), id: \.offset) { index, step in
                        StepRow(
                            number: index + 1,
                            step: step,
                            state: stepState(index),
                            remainingSeconds: index == currentStepIndex ? remainingSeconds : nil
                        )
                    }
                }
            }

            Button(isLastStep ? "마치기" : "다음 단계로") {
                advance()
            }
            .buttonStyle(SDPrimaryButtonStyle())

            Text("마치면 오늘 쉬어간 기록으로 남아요")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SDColor.muted)
                .frame(maxWidth: .infinity)
        }
        .padding(18)
        .background(SDColor.cream)
        .onAppear {
            startedAt = Date()
            resetTimer()
            if let url = Bundle.main.url(forResource: practice.videoFileName, withExtension: "mp4") {
                let player = AVPlayer(url: url)
                self.player = player
                player.play()
            }
        }
        .onDisappear {
            player?.pause()
        }
        .onReceive(timer) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            }
        }
    }

    @ViewBuilder
    private var videoArea: some View {
        if let player {
            VideoPlayer(player: player)
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else if let currentStep {
            StepHeroView(
                category: practice.category,
                step: currentStep,
                remainingSeconds: remainingSeconds,
                totalSeconds: currentStep.seconds * currentStep.reps
            )
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(practice.category.thumbnailGradient)
                .frame(height: 210)
        }
    }

    private func stepState(_ index: Int) -> StepRow.State {
        if index < currentStepIndex { return .done }
        if index == currentStepIndex { return .current }
        return .upcoming
    }

    private func advance() {
        if isLastStep {
            onClose(CarePlayResult(completed: true, completedSteps: practice.steps.count, startedAt: startedAt))
        } else {
            currentStepIndex += 1
            resetTimer()
        }
    }

    private func resetTimer() {
        guard practice.steps.indices.contains(currentStepIndex) else {
            remainingSeconds = 0
            return
        }
        let step = practice.steps[currentStepIndex]
        remainingSeconds = step.seconds * step.reps
    }
}

private struct StepHeroView: View {
    let category: SmilePracticeCategory
    let step: SmilePracticeStep
    let remainingSeconds: Int
    let totalSeconds: Int

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(remainingSeconds) / Double(totalSeconds)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(category.thumbnailGradient)
                .frame(height: 210)

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: step.systemImage)
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                }
                .frame(width: 88, height: 88)
                .animation(.linear(duration: 1), value: progress)

                VStack(spacing: 2) {
                    Text(step.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    if step.reps > 1 {
                        Text("×\(step.reps)")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

private struct StepRow: View {
    enum State {
        case done, current, upcoming
    }

    let number: Int
    let step: SmilePracticeStep
    let state: State
    let remainingSeconds: Int?

    var body: some View {
        HStack(spacing: 10) {
            numberBadge

            Text(step.title)
                .font(.caption.bold())
                .foregroundStyle(state == .current ? SDColor.ink : SDColor.muted)
                .strikethrough(state == .done)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(trailingText)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(state == .current ? SDColor.coralDeep : SDColor.muted)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if state == .current {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SDColor.coral, lineWidth: 2)
            }
        }
    }

    private var numberBadge: some View {
        ZStack {
            switch state {
            case .done:
                Circle().fill(SDColor.mint)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.white)
            case .current:
                Circle().fill(SDColor.coral)
                stepNumberText(color: .white)
            case .upcoming:
                Circle().fill(SDColor.shell)
                stepNumberText(color: SDColor.muted)
            }
        }
        .frame(width: 26, height: 26)
    }

    private func stepNumberText(color: Color) -> Text {
        Text("\(number)")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(color)
    }

    private var trailingText: String {
        let repsPrefix = step.reps > 1 ? "×\(step.reps) · " : ""
        if let remainingSeconds {
            return repsPrefix + "남은 시간 \(remainingSeconds)초"
        }
        let total = step.seconds * step.reps
        return step.reps > 1 ? "\(step.seconds)초 ×\(step.reps)" : "\(total)초"
    }
}