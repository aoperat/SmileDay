import SwiftUI
import UIKit
import CoachingKit

/// 실시간 미소 확인 화면.
///
/// 카메라 화면은 기본으로 꺼져 있고 사용자가 토글로 켠다. 켜져 있을 때만 프리뷰 뷰를 만든다.
/// 프레임의 픽셀을 꺼내는 경로가 없다 — 사진을 남기지 않으므로 저장·내보내기·전송할 대상 자체가
/// 없고, 세션이 만드는 것은 메모리에만 있는 1초 칸 타임라인뿐이다.
struct LiveSmileMonitorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel: LiveSmileMonitorViewModel?
    /// 프리뷰가 그릴 세션을 얻으려면 구체 타입을 들고 있어야 한다.
    @State private var monitor: ARKitLiveSmileMonitor?
    /// 카메라 화면은 기본으로 꺼져 있고, 매번 꺼진 상태로 시작한다.
    @State private var isShowingPreview = false
    /// 알림이 울린 직후 잠깐 띄우는 "Smile!" 표시.
    @State private var isShowingNudgeCue = false
    /// 사용자가 시작을 누르기 전에는 카메라를 켜지 않는다.
    @State private var hasStarted = false
    /// 백그라운드로 나가며 멈춘 뒤에는 자동 재개하지 않고 사용자의 재시작을 받는다.
    @State private var needsRestart = false
    @State private var previousIdleTimerDisabled = false
    /// 종료를 누른 뒤 보여줄 요약. 화면을 닫으면 사라진다.
    @State private var summary: LiveSmileSessionSummary?

    var body: some View {
        ZStack {
            SDColor.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if let viewModel {
                    content(viewModel)
                }
            }
        }
        .onAppear {
            guard viewModel == nil else { return }
            let monitor = ARKitLiveSmileMonitor()
            self.monitor = monitor
            viewModel = LiveSmileMonitorViewModel(
                monitor: monitor,
                nudging: LiveSmileNudgeNotifier(),
                nudgeSettings: UserDefaultsLiveSmileNudgeSettingsStore().settings
            )
        }
        .onDisappear(perform: shutDown)
        .onChange(of: scenePhase) { _, phase in
            // 화면을 벗어나면 카메라를 즉시 끈다. 복귀는 사용자가 결정한다.
            guard phase != .active, hasStarted else { return }
            pauseForSceneChange()
        }
        .onChange(of: viewModel?.state) { _, state in
            guard case .some(.failed) = state else { return }
            // 세션은 ViewModel이 이미 멈췄다. 측정한 게 있으면 실패 문구 대신 요약을 먼저
            // 보여준다 — 인터럽션이든 진짜 오류든, 이미 기록된 것을 말없이 버리지 않는다.
            if let viewModel, viewModel.hasRecordedAnySecond, summary == nil {
                finishAndShowSummary(viewModel)
            } else {
                // 측정 전 실패(권한 거부·미지원 기기)는 기록이 없으므로 실패 화면을 그대로 둔다.
                isShowingPreview = false
                restoreIdleTimer()
            }
        }
    }

    private var header: some View {
        HStack {
            SDCloseButton {
                // 측정한 게 있으면 말없이 버리지 않고 요약을 먼저 보여준다.
                if let viewModel, hasStarted, summary == nil, viewModel.hasRecordedAnySecond {
                    finishAndShowSummary(viewModel)
                } else {
                    releaseSession()
                    dismiss()
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    @ViewBuilder
    private func content(_ viewModel: LiveSmileMonitorViewModel) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            if let summary {
                LiveSmileSessionSummaryView(
                    summary: summary,
                    onClose: {
                        releaseSession()
                        dismiss()
                    }
                )
            } else if case .failed(let failure) = viewModel.state {
                failureSection(failure)
            } else if !hasStarted {
                introSection
            } else if needsRestart {
                restartSection
            } else {
                measuringSection(viewModel)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 시작 전

    private var introSection: some View {
        VStack(spacing: 20) {
            Text(SharedStrings.liveMonitorTitle)
                .font(.title2.bold())
                .foregroundStyle(SDColor.ink)

            Text(SharedStrings.liveMonitorEntrySummary)
                .font(.subheadline)
                .foregroundStyle(SDColor.muted)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(SharedStrings.liveMonitorIntroPoints, id: \.self) { point in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("·")
                            .foregroundStyle(SDColor.muted)
                            .accessibilityHidden(true)
                        Text(point)
                            .font(.footnote)
                            .foregroundStyle(SDColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .sdCard()

            Button(SharedStrings.liveMonitorStartAction) {
                startMeasuring()
            }
            .buttonStyle(SDPrimaryButtonStyle())
        }
    }

    // MARK: - 측정 중

    @ViewBuilder
    private func measuringSection(_ viewModel: LiveSmileMonitorViewModel) -> some View {
        VStack(spacing: 22) {
            privacyBadge

            previewToggle

            if isShowingPreview, let session = monitor?.previewSession {
                LiveSmileCameraPreview(session: session) {
                    monitor?.reassertSampleDelegate()
                }
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                // 좌우를 뒤집지 않는다. 카메라가 보는 그대로 보여준다.
                .accessibilityHidden(true)
                .transition(.opacity)
            }

            levelMeter(viewModel.level)

            if !viewModel.timeline.isEmpty {
                LiveSmileTimelineBand(timeline: viewModel.timeline)
                    .frame(height: 12)
                    .accessibilityHidden(true)
            }

            if isShowingNudgeCue {
                nudgeCue
            } else {
                statusText(viewModel)
            }

            Text(SharedStrings.liveMonitorLevelMeaning)
                .font(.caption)
                .foregroundStyle(SDColor.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(SharedStrings.liveMonitorRecalibrateAction) {
                    viewModel.recalibrate()
                }
                .buttonStyle(SDInkButtonStyle())

                Button(SharedStrings.liveMonitorCloseAction) {
                    finishAndShowSummary(viewModel)
                }
                .buttonStyle(SDPrimaryButtonStyle())
            }
        }
        .onChange(of: viewModel.state) { _, _ in announceStatus(viewModel) }
        .onChange(of: viewModel.level) { _, _ in announceStatus(viewModel) }
        .onChange(of: viewModel.nudgeCount) { _, count in
            guard count > 0 else { return }
            showNudgeCue()
        }
    }

    /// 진동이나 알림을 놓쳤어도 화면을 보면 알 수 있게 잠깐 크게 띄운다.
    private func showNudgeCue() {
        AccessibilityNotification.Announcement(SharedStrings.liveMonitorNudgeBody).post()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            isShowingNudgeCue = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.3)) {
                isShowingNudgeCue = false
            }
        }
    }

    /// 카메라 화면은 기본으로 꺼져 있다. 켜는 것도 끄는 것도 사용자가 정한다.
    private var previewToggle: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                isShowingPreview.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isShowingPreview ? "eye.slash" : "eye")
                    .font(.caption.weight(.semibold))
                Text(isShowingPreview
                     ? SharedStrings.liveMonitorHidePreview
                     : SharedStrings.liveMonitorShowPreview)
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(SDColor.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.white, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var privacyBadge: some View {
        Text(SharedStrings.liveMonitorPrivacyBadge)
            .font(.caption.weight(.semibold))
            .foregroundStyle(SDColor.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(SDColor.shell, in: Capsule())
            .multilineTextAlignment(.center)
    }

    /// 단계 표시. 숫자를 보여주지 않는다 — 프레임마다 흔들리는 숫자는 읽기 어렵고 산만하다.
    ///
    /// 채워진 칸 수만 바뀌고, 색은 실패·성공의 빨강/초록이 아니라 살구 → 코랄로 이어진다.
    private func levelMeter(_ level: LiveSmileLevel?) -> some View {
        let filled = level.map { $0.rawValue + 1 } ?? 0

        return VStack(spacing: 14) {
            Text(SharedStrings.liveMonitorLevelLabel)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SDColor.muted)

            HStack(spacing: 8) {
                ForEach(0..<LiveSmileLevel.allCases.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(index < filled ? segmentColor(index) : SDColor.shell)
                        .frame(height: 44)
                }
            }
        }
        .padding(.horizontal, 8)
        // VoiceOver가 프레임마다 값을 읽지 않도록 자주 갱신되는 요소로 표시하지 않는다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SharedStrings.liveMonitorLevelLabel)
        .accessibilityValue(
            filled == 0
                ? "측정 준비 중"
                : "\(LiveSmileLevel.allCases.count)단계 중 \(filled)단계"
        )
        // Reduce Motion에서는 칸이 채워지는 보간을 생략한다.
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: filled)
    }

    /// 아래 칸에서 위 칸으로 갈수록 노랑에서 살구로 옮겨간다.
    private func segmentColor(_ index: Int) -> Color {
        let steps = max(LiveSmileLevel.allCases.count - 1, 1)
        return Color(
            blending: SDPalette.sun,
            with: SDPalette.apricot,
            ratio: Double(index) / Double(steps)
        )
    }

    /// 알림이 울린 직후 잠깐 나타나는 표시. 재촉이 아니라 부르는 말투로 둔다.
    private var nudgeCue: some View {
        VStack(spacing: 4) {
            Text(SharedStrings.liveMonitorNudgeTitle)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(SDColor.sunDeep)

            Text(SharedStrings.liveMonitorNudgeBody)
                .font(.subheadline)
                .foregroundStyle(SDColor.ink)
        }
        .multilineTextAlignment(.center)
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func statusText(_ viewModel: LiveSmileMonitorViewModel) -> some View {
        Text(statusMessage(viewModel))
            .font(.headline)
            .foregroundStyle(isQualityIssue(viewModel.state) ? SDColor.alert : SDColor.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - 중단·실패

    private var restartSection: some View {
        VStack(spacing: 16) {
            Text(SharedStrings.liveMonitorInterrupted)
                .font(.headline)
                .foregroundStyle(SDColor.ink)
                .multilineTextAlignment(.center)

            Button(SharedStrings.liveMonitorStartAction) {
                needsRestart = false
                startMeasuring()
            }
            .buttonStyle(SDPrimaryButtonStyle())
        }
    }

    private func failureSection(_ failure: LiveSmileFailure) -> some View {
        VStack(spacing: 16) {
            Text(failureMessage(failure))
                .font(.headline)
                .foregroundStyle(SDColor.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if failure == .permissionDenied {
                Button(SharedStrings.openSystemSettings) {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(SDInkButtonStyle())
            }

            Button(SharedStrings.liveMonitorCloseAction) {
                shutDown()
                dismiss()
            }
            .buttonStyle(SDPrimaryButtonStyle())
        }
    }

    // MARK: - 문구

    private func statusMessage(_ viewModel: LiveSmileMonitorViewModel) -> String {
        switch viewModel.state {
        case .idle, .requestingPermission, .calibrating:
            return SharedStrings.liveMonitorCalibrating
        case .qualityIssue(.faceNotFound):
            return SharedStrings.liveMonitorFaceNotFound
        case .qualityIssue(.notFacingCamera):
            return SharedStrings.liveMonitorNotFacingCamera
        case .qualityIssue(.tooDark):
            return SharedStrings.liveMonitorTooDark
        case .failed(let failure):
            return failureMessage(failure)
        case .monitoring:
            return levelMessage(viewModel.level)
        }
    }

    private func levelMessage(_ level: LiveSmileLevel?) -> String {
        switch level {
        case .resting, .none: SharedStrings.liveMonitorLevelResting
        case .starting: SharedStrings.liveMonitorLevelStarting
        case .holding: SharedStrings.liveMonitorLevelHolding
        case .clear: SharedStrings.liveMonitorLevelClear
        }
    }

    private func failureMessage(_ failure: LiveSmileFailure) -> String {
        switch failure {
        case .permissionDenied: SharedStrings.liveMonitorPermissionDenied
        case .unsupportedDevice: SharedStrings.liveMonitorUnsupported
        case .sessionFailed: SharedStrings.liveMonitorSessionFailed
        }
    }

    private func isQualityIssue(_ state: LiveSmileMonitorState) -> Bool {
        if case .qualityIssue = state { return true }
        return false
    }

    /// 상태나 피드백 단계가 바뀔 때만 알린다. 숫자 변화는 알리지 않는다.
    private func announceStatus(_ viewModel: LiveSmileMonitorViewModel) {
        AccessibilityNotification.Announcement(statusMessage(viewModel)).post()
    }

    // MARK: - 생명주기

    private func startMeasuring() {
        hasStarted = true
        // start()가 새 recorder를 만든다. 이전 세션 요약이 남지 않게 함께 버린다.
        summary = nil
        previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        // 세워두고 보는 화면이라 측정 중에만 자동 잠금을 막는다.
        UIApplication.shared.isIdleTimerDisabled = true
        viewModel?.start()
    }

    private func pauseForSceneChange() {
        guard let viewModel else { return }
        // 측정한 게 있으면 새로 시작하는 화면 대신 요약을 먼저 보여준다 — 카메라를 끄는 시점은
        // 그대로다, finishSession()도 내부에서 즉시 stop()을 부른다.
        if viewModel.hasRecordedAnySecond, summary == nil {
            finishAndShowSummary(viewModel)
        } else {
            viewModel.stop()
            restoreIdleTimer()
            needsRestart = true
        }
    }

    /// 측정을 끝내고 요약으로 넘어간다. 세션은 멈추지만 화면은 닫지 않는다.
    private func finishAndShowSummary(_ viewModel: LiveSmileMonitorViewModel) {
        let result = viewModel.finishSession()
        isShowingPreview = false
        restoreIdleTimer()
        summary = result
    }

    /// 요약까지 끝난 뒤 전부 버린다.
    private func releaseSession() {
        shutDown()
        summary = nil
    }

    /// 닫기·화면 이탈·실패 등 모든 종료 경로에서 카메라와 자동 잠금을 원래대로 되돌린다.
    private func shutDown() {
        viewModel?.stop()
        restoreIdleTimer()
        hasStarted = false
        needsRestart = false
        // 다음 세션도 카메라 화면이 꺼진 상태로 시작한다.
        isShowingPreview = false
        isShowingNudgeCue = false
    }

    private func restoreIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled
    }
}
