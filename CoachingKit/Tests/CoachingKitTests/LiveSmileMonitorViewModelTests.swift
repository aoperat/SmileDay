import XCTest
@testable import CoachingKit

@MainActor
final class LiveSmileMonitorViewModelTests: XCTestCase {
    /// 호출을 기록하고 테스트가 직접 이벤트를 밀어 넣는 경계 더블.
    private final class FakeMonitor: LiveSmileMonitoring {
        var onEvent: ((LiveSmileMonitorEvent) -> Void)?
        private(set) var startCount = 0
        private(set) var stopCount = 0

        func start() { startCount += 1 }
        func stop() { stopCount += 1 }

        func emit(_ event: LiveSmileMonitorEvent) { onEvent?(event) }
    }

    /// 테스트가 시간을 직접 옮긴다. 실제 시계에 의존하지 않는다.
    ///
    /// 클로저가 시계를 강하게 붙든다. 시계를 `_`로 버리는 테스트에서도 살아 있어야 한다 —
    /// `unowned`로 두면 그런 테스트에서 해제된 참조를 읽고 크래시한다.
    /// `now`는 저장 프로퍼티가 아니라 계산 프로퍼티라 순환 참조가 생기지 않는다.
    private final class TestClock {
        var date = Date(timeIntervalSince1970: 1_800_000_000)
        var now: () -> Date { { self.date } }
    }

    /// 알림 호출을 기록만 하는 경계 더블.
    private final class FakeNudging: LiveSmileNudging {
        private(set) var calls: [Bool] = []

        func nudge(withHaptic: Bool) { calls.append(withHaptic) }
    }

    private func makeViewModel(
        nudgeSettings: LiveSmileNudgeSettings = .default
    ) -> (LiveSmileMonitorViewModel, FakeMonitor, TestClock, FakeNudging) {
        let monitor = FakeMonitor()
        let clock = TestClock()
        let nudging = FakeNudging()
        let viewModel = LiveSmileMonitorViewModel(
            monitor: monitor,
            nudging: nudging,
            nudgeSettings: nudgeSettings,
            now: clock.now
        )
        return (viewModel, monitor, clock, nudging)
    }

    private func sample(
        smile: Double,
        gazeOffset: Double = 0,
        ambient: Double? = 800
    ) -> LiveSmileMonitorEvent {
        .sample(LiveSmileSample(
            mouthSmileLeft: smile,
            mouthSmileRight: smile,
            gazeOffsetDegrees: gazeOffset,
            ambientIntensity: ambient
        ))
    }

    /// 편한 표정 `neutral`로 2초를 채워 보정을 끝낸다.
    private func finishCalibration(
        _ monitor: FakeMonitor,
        _ clock: TestClock,
        neutral: Double = 0.1
    ) {
        monitor.emit(sample(smile: neutral))
        clock.date += LiveSmileMonitorViewModel.calibrationDuration
        monitor.emit(sample(smile: neutral))
    }

    /// 갱신 상한에 걸리지 않게 시간을 흘린 뒤 이벤트를 보낸다.
    private func emitAfterPublishInterval(
        _ monitor: FakeMonitor,
        _ clock: TestClock,
        _ event: LiveSmileMonitorEvent
    ) {
        clock.date += LiveSmileMonitorViewModel.minimumPublishInterval
        monitor.emit(event)
    }

    // MARK: - 생명주기

    func test_start_beginsMonitoringSession() {
        let (viewModel, monitor, _, _) = makeViewModel()

        viewModel.start()

        XCTAssertEqual(monitor.startCount, 1)
        XCTAssertEqual(viewModel.state, .requestingPermission)
        XCTAssertNil(viewModel.level)
    }

    func test_start_isIgnored_whenAlreadyRunning() {
        let (viewModel, monitor, _, _) = makeViewModel()

        viewModel.start()
        viewModel.start()

        XCTAssertEqual(monitor.startCount, 1)
    }

    func test_stop_isSafe_whenNeverStarted() {
        let (viewModel, monitor, _, _) = makeViewModel()

        viewModel.stop()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(monitor.stopCount, 1)
    }

    func test_stop_clearsLevelAndCalibration() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        finishCalibration(monitor, clock)
        emitAfterPublishInterval(monitor, clock, sample(smile: 0.55))
        XCTAssertNotNil(viewModel.level)

        viewModel.stop()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertNil(viewModel.level)
    }

    /// stop 뒤에 도착한 프레임이 화면을 다시 켜면 안 된다.
    func test_lateEventsAfterStop_areIgnored() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        finishCalibration(monitor, clock)
        viewModel.stop()

        monitor.onEvent?(sample(smile: 0.9))
        monitor.emit(sample(smile: 0.9))

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertNil(viewModel.level)
    }

    // MARK: - 실패

    func test_permissionDenied_failsAndStopsSession() {
        let (viewModel, monitor, _, _) = makeViewModel()
        viewModel.start()

        monitor.emit(.permissionDenied)

        XCTAssertEqual(viewModel.state, .failed(.permissionDenied))
        XCTAssertEqual(monitor.stopCount, 1)
        XCTAssertNil(viewModel.level)
    }

    func test_unsupportedDevice_fails() {
        let (viewModel, monitor, _, _) = makeViewModel()
        viewModel.start()

        monitor.emit(.unsupportedDevice)

        XCTAssertEqual(viewModel.state, .failed(.unsupportedDevice))
    }

    func test_sessionFailed_fails_andIgnoresLaterSamples() {
        let (viewModel, monitor, _, _) = makeViewModel()
        viewModel.start()

        monitor.emit(.sessionFailed)
        monitor.emit(sample(smile: 0.9))

        XCTAssertEqual(viewModel.state, .failed(.sessionFailed))
        XCTAssertNil(viewModel.level)
    }

    // MARK: - 보정

    func test_calibration_staysUntilEnoughValidFrames() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()

        monitor.emit(sample(smile: 0.1))
        clock.date += LiveSmileMonitorViewModel.calibrationDuration - 0.1
        monitor.emit(sample(smile: 0.1))

        XCTAssertEqual(viewModel.state, .calibrating)
        XCTAssertNil(viewModel.level, "보정 중에는 단계를 보여주지 않는다")
    }

    /// 얼굴을 놓쳤거나 품질이 나쁜 프레임은 편한 표정 평균에 들어가면 안 된다.
    func test_calibration_excludesInvalidFrames() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()

        monitor.emit(sample(smile: 0.1))
        monitor.emit(sample(smile: 0.9, gazeOffset: 70))   // 카메라를 안 봄 — 제외
        monitor.emit(.faceLost)                             // 얼굴 없음 — 제외
        monitor.emit(sample(smile: 0.9, ambient: 10))       // 너무 어두움 — 제외
        clock.date += LiveSmileMonitorViewModel.calibrationDuration
        monitor.emit(sample(smile: 0.1))

        // 편한 표정이 0.1로만 잡혔다면 0.55는 신호 1.0이고, 0에서 시작한 smoothing을 거쳐 0.2 → starting.
        // 이탈 프레임까지 평균에 넣었다면 편한 표정이 0.5가 되어 신호가 거의 0 → resting에 머문다.
        emitAfterPublishInterval(monitor, clock, sample(smile: 0.55))

        XCTAssertEqual(viewModel.state, .monitoring)
        XCTAssertEqual(viewModel.level, .starting, "이탈 프레임이 편한 표정 평균에 섞이면 resting에 머문다")
    }

    func test_calibration_completesAndPublishesLevel() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()

        finishCalibration(monitor, clock)

        XCTAssertEqual(viewModel.state, .monitoring)
        XCTAssertEqual(viewModel.level, .resting, "보정 직후에는 편한 표정이므로 가장 낮은 단계다")
    }

    /// 다시 보정하면 이전 편한 표정 값을 쓰지 않는다.
    func test_recalibrate_discardsPreviousNeutral() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        finishCalibration(monitor, clock, neutral: 0.1)

        viewModel.recalibrate()
        XCTAssertEqual(viewModel.state, .calibrating)
        XCTAssertNil(viewModel.level)

        // 이번에는 0.5를 편한 표정으로 잡는다.
        finishCalibration(monitor, clock, neutral: 0.5)
        emitAfterPublishInterval(monitor, clock, sample(smile: 0.5))

        XCTAssertEqual(viewModel.level, .resting, "새 보정값 기준으로는 가장 낮은 단계여야 한다")
    }

    func test_recalibrate_isIgnored_whenNotRunning() {
        let (viewModel, _, _, _) = makeViewModel()

        viewModel.recalibrate()

        XCTAssertEqual(viewModel.state, .idle)
    }

    // MARK: - 안정화

    /// 한 프레임 만에 최고 단계로 뛰지 않는다.
    func test_smoothing_dampensSuddenJumps() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        finishCalibration(monitor, clock)
        XCTAssertEqual(viewModel.level, .resting)

        emitAfterPublishInterval(monitor, clock, sample(smile: 0.55))

        XCTAssertEqual(viewModel.level, .starting, "최대 신호여도 첫 프레임에서 clear로 뛰지 않는다")
    }

    /// 계속 웃고 있으면 단계가 끝까지 올라간다.
    func test_smoothing_reachesTopLevel_whenSustained() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        finishCalibration(monitor, clock)

        for _ in 0..<12 {
            emitAfterPublishInterval(monitor, clock, sample(smile: 0.55))
        }

        XCTAssertEqual(viewModel.level, .clear)
    }

    /// 갱신 상한 안에서는 단계를 바꾸지 않는다.
    func test_publishing_isThrottled() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        finishCalibration(monitor, clock)
        emitAfterPublishInterval(monitor, clock, sample(smile: 0.55))
        let published = viewModel.level

        clock.date += LiveSmileMonitorViewModel.minimumPublishInterval / 2
        monitor.emit(sample(smile: 0.55))

        XCTAssertEqual(viewModel.level, published, "상한 안에서는 단계가 그대로여야 한다")
    }

    // MARK: - 품질 우선순위

    func test_faceLost_hidesLevel() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        finishCalibration(monitor, clock)
        emitAfterPublishInterval(monitor, clock, sample(smile: 0.55))

        monitor.emit(.faceLost)

        XCTAssertEqual(viewModel.state, .qualityIssue(.faceNotFound))
        XCTAssertNil(viewModel.level, "믿을 수 없는 단계를 남겨두지 않는다")
    }

    func test_notFacingCamera_takesPriorityOverLevel() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        finishCalibration(monitor, clock)

        emitAfterPublishInterval(monitor, clock, sample(smile: 0.9, gazeOffset: 70))

        XCTAssertEqual(viewModel.state, .qualityIssue(.notFacingCamera))
        XCTAssertNil(viewModel.level)
    }

    /// 방향이 조명보다 먼저다.
    func test_notFacingCamera_takesPriorityOverDarkness() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        finishCalibration(monitor, clock)

        emitAfterPublishInterval(monitor, clock, sample(smile: 0.5, gazeOffset: 70, ambient: 5))

        XCTAssertEqual(viewModel.state, .qualityIssue(.notFacingCamera))
    }

    func test_darkness_takesPriorityOverLevel() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        finishCalibration(monitor, clock)

        emitAfterPublishInterval(monitor, clock, sample(smile: 0.9, ambient: 20))

        XCTAssertEqual(viewModel.state, .qualityIssue(.tooDark))
        XCTAssertNil(viewModel.level)
    }

    /// 품질 문제가 풀리면 보정을 다시 하지 않고 곧바로 단계로 돌아온다.
    func test_recoveringFromQualityIssue_resumesWithoutRecalibrating() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        finishCalibration(monitor, clock, neutral: 0.1)
        monitor.emit(.faceLost)

        // 끊기기 전 값에서 이어 붙이지 않으므로 이번 프레임의 신호(0.5)가 그대로 단계가 된다.
        emitAfterPublishInterval(monitor, clock, sample(smile: 0.325))

        XCTAssertEqual(viewModel.state, .monitoring)
        XCTAssertEqual(viewModel.level, .holding, "이전 보정값을 그대로 써야 한다")
    }

    // MARK: - 단계 hysteresis

    func test_level_usesPlainBoundaries_whenNoCurrentLevel() {
        XCTAssertEqual(LiveSmileMonitorViewModel.nextLevel(signal: 0, current: nil), .resting)
        XCTAssertEqual(LiveSmileMonitorViewModel.nextLevel(signal: 0.10, current: nil), .starting)
        XCTAssertEqual(LiveSmileMonitorViewModel.nextLevel(signal: 0.30, current: nil), .holding)
        XCTAssertEqual(LiveSmileMonitorViewModel.nextLevel(signal: 0.60, current: nil), .clear)
    }

    /// 경계를 살짝 넘은 것만으로 단계가 바뀌지 않는다.
    func test_level_doesNotAdvance_justPastBoundary() {
        XCTAssertEqual(LiveSmileMonitorViewModel.nextLevel(signal: 0.31, current: .starting), .starting)
        XCTAssertEqual(LiveSmileMonitorViewModel.nextLevel(signal: 0.34, current: .starting), .holding)
    }

    func test_level_doesNotFallBack_justBelowBoundary() {
        XCTAssertEqual(LiveSmileMonitorViewModel.nextLevel(signal: 0.29, current: .holding), .holding)
        XCTAssertEqual(LiveSmileMonitorViewModel.nextLevel(signal: 0.26, current: .holding), .starting)
    }

    /// 경계 위아래를 오가도 단계가 왕복하지 않는다.
    func test_level_doesNotOscillateAroundBoundary() {
        var level: LiveSmileLevel? = .starting

        for signal in [0.29, 0.31, 0.28, 0.32, 0.30, 0.29] {
            level = LiveSmileMonitorViewModel.nextLevel(signal: signal, current: level)
        }

        XCTAssertEqual(level, .starting, "경계 근처 흔들림으로는 단계가 바뀌면 안 된다")
    }

    // MARK: - 웃지 않을 때 알리기

    private func thirtySecondSettings(
        isEnabled: Bool = true,
        isHapticEnabled: Bool = true
    ) -> LiveSmileNudgeSettings {
        LiveSmileNudgeSettings(
            isEnabled: isEnabled,
            intervalSeconds: 30,
            isHapticEnabled: isHapticEnabled
        )
    }

    /// 웃지 않는 프레임을 `seconds`만큼 흘려보낸다. 프레임 간격은 알림 계산 상한 안이다.
    private func emitRestingFrames(
        _ monitor: FakeMonitor,
        _ clock: TestClock,
        seconds: TimeInterval
    ) {
        let step = LiveSmileMonitorViewModel.maxNudgeFrameGap / 2
        var elapsed: TimeInterval = 0
        while elapsed < seconds {
            clock.date += step
            monitor.emit(sample(smile: 0.1))
            elapsed += step
        }
    }

    func test_nudge_firesAfterConfiguredRestingInterval() {
        let (viewModel, monitor, clock, nudging) = makeViewModel(nudgeSettings: thirtySecondSettings())
        viewModel.start()
        finishCalibration(monitor, clock)

        emitRestingFrames(monitor, clock, seconds: 29)
        XCTAssertTrue(nudging.calls.isEmpty, "설정한 간격 전에는 알리지 않는다")

        emitRestingFrames(monitor, clock, seconds: 2)

        XCTAssertEqual(nudging.calls.count, 1)
        XCTAssertEqual(viewModel.nudgeCount, 1)
    }

    /// 계속 웃지 않으면 같은 간격으로 다시 알린다.
    func test_nudge_repeatsAtEachInterval() {
        let (viewModel, monitor, clock, nudging) = makeViewModel(nudgeSettings: thirtySecondSettings())
        viewModel.start()
        finishCalibration(monitor, clock)

        emitRestingFrames(monitor, clock, seconds: 31)
        emitRestingFrames(monitor, clock, seconds: 31)

        XCTAssertEqual(nudging.calls.count, 2)
        XCTAssertEqual(viewModel.nudgeCount, 2)
    }

    /// 한 번 웃으면 처음부터 다시 센다.
    func test_nudge_timerRestartsAfterSmiling() {
        let (viewModel, monitor, clock, nudging) = makeViewModel(nudgeSettings: thirtySecondSettings())
        viewModel.start()
        finishCalibration(monitor, clock)
        emitRestingFrames(monitor, clock, seconds: 29)

        emitAfterPublishInterval(monitor, clock, sample(smile: 0.55))
        XCTAssertEqual(viewModel.level, .starting)

        emitRestingFrames(monitor, clock, seconds: 29)

        XCTAssertTrue(nudging.calls.isEmpty, "웃은 뒤에는 누적 시간이 0부터 다시 시작해야 한다")
    }

    /// 얼굴을 놓친 동안은 웃는지 알 수 없다. 그 시간을 세면 돌아오자마자 알림이 뜬다.
    func test_nudge_pausesWhileFaceIsLost_withoutLosingProgress() {
        let (viewModel, monitor, clock, nudging) = makeViewModel(nudgeSettings: thirtySecondSettings())
        viewModel.start()
        finishCalibration(monitor, clock)
        emitRestingFrames(monitor, clock, seconds: 29)

        monitor.emit(.faceLost)
        clock.date += 600 // 10분 자리를 비운다

        emitRestingFrames(monitor, clock, seconds: 1)
        XCTAssertTrue(nudging.calls.isEmpty, "자리를 비운 시간은 세지 않는다")

        emitRestingFrames(monitor, clock, seconds: 2)
        XCTAssertEqual(nudging.calls.count, 1, "끊기기 전 누적 시간은 남아 있어야 한다")
    }

    func test_nudge_passesHapticSetting() {
        let (viewModel, monitor, clock, nudging) = makeViewModel(
            nudgeSettings: thirtySecondSettings(isHapticEnabled: false)
        )
        viewModel.start()
        finishCalibration(monitor, clock)

        emitRestingFrames(monitor, clock, seconds: 31)

        XCTAssertEqual(nudging.calls, [false])
    }

    func test_nudge_neverFires_whenDisabled() {
        let (viewModel, monitor, clock, nudging) = makeViewModel(
            nudgeSettings: thirtySecondSettings(isEnabled: false)
        )
        viewModel.start()
        finishCalibration(monitor, clock)

        emitRestingFrames(monitor, clock, seconds: 120)

        XCTAssertTrue(nudging.calls.isEmpty)
        XCTAssertEqual(viewModel.nudgeCount, 0)
    }

    /// 다시 보정하면 누적 시간도 버린다.
    func test_nudge_timerResetsOnRecalibrate() {
        let (viewModel, monitor, clock, nudging) = makeViewModel(nudgeSettings: thirtySecondSettings())
        viewModel.start()
        finishCalibration(monitor, clock)
        emitRestingFrames(monitor, clock, seconds: 29)

        viewModel.recalibrate()
        finishCalibration(monitor, clock)
        emitRestingFrames(monitor, clock, seconds: 29)

        XCTAssertTrue(nudging.calls.isEmpty)
    }

    // MARK: - 세션 기록

    func test_recording_marksCalibrationSecondsAsUnknown() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()

        // 보정 중 프레임은 단계를 알 수 없다.
        monitor.emit(sample(smile: 0.1))
        clock.date += 1
        monitor.emit(sample(smile: 0.1))

        XCTAssertEqual(viewModel.timeline, [.unknown])
    }

    func test_recording_marksRestingSecondsAsNotSmiling() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        finishCalibration(monitor, clock)

        emitAfterPublishInterval(monitor, clock, sample(smile: 0.1))
        clock.date += 1
        monitor.emit(sample(smile: 0.1))

        XCTAssertEqual(viewModel.timeline.last, .notSmiling)
    }

    func test_recording_marksSmilingSeconds() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        finishCalibration(monitor, clock)

        // 계속 웃으면 평활을 거쳐 resting을 벗어난다.
        for _ in 0..<12 {
            emitAfterPublishInterval(monitor, clock, sample(smile: 0.55))
        }
        clock.date += 1
        monitor.emit(sample(smile: 0.55))

        XCTAssertEqual(viewModel.timeline.last, .smiling)
    }

    /// 보정을 끝내는 프레임은 `calibrate(with:)`의 unknown 기록과 `publish(signal:)`의 기록이
    /// 겹쳐서 두 번 세지면 안 된다. 그 칸에 이미 판정 불가 프레임이 하나 있으면, 이중 계산이
    /// "판정 가능이 절반 이상"을 "미만"으로 밀어 그 칸을 unknown으로 뒤집는다.
    func test_calibrationCompletingFrame_isRecordedOnlyOnce() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()

        monitor.emit(sample(smile: 0.1)) // t=0: 보정 시작 — 0번 칸에 unknown 1개
        clock.date += 2 // t=2.0 — 2번 칸 경계
        monitor.emit(.faceLost) // 2번 칸에 판정 불가 프레임이 먼저 하나 쌓인다
        clock.date += 0.5 // t=2.5 — 여전히 2번 칸. 보정 시작 후 2.5초 지나 보정이 끝난다
        monitor.emit(sample(smile: 0.1)) // 보정을 끝내는 프레임
        clock.date += 1 // 2번 칸을 닫기 위해 3번 칸으로 넘어간다
        monitor.emit(sample(smile: 0.1))

        XCTAssertEqual(
            viewModel.timeline[2], .notSmiling,
            "보정을 끝내는 프레임은 publish 경로에서 한 번만 기록돼야 한다"
        )
    }

    func test_recording_marksQualityIssueSecondsAsUnknown() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        finishCalibration(monitor, clock)

        monitor.emit(.faceLost)
        clock.date += 3
        monitor.emit(sample(smile: 0.1))

        XCTAssertTrue(viewModel.timeline.contains(.unknown))
    }

    func test_finishSession_returnsSummaryAndStops() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        finishCalibration(monitor, clock)
        clock.date += 1
        monitor.emit(sample(smile: 0.1))

        let summary = viewModel.finishSession()

        XCTAssertGreaterThan(summary.totalSeconds, 0)
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertTrue(viewModel.timeline.isEmpty, "종료하면 화면용 타임라인은 비운다")
    }

    /// 새 세션은 이전 세션 기록을 물려받지 않는다.
    func test_start_beginsFreshTimeline() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        finishCalibration(monitor, clock)
        clock.date += 1
        monitor.emit(sample(smile: 0.1))
        _ = viewModel.finishSession()

        viewModel.start()
        finishCalibration(monitor, clock)

        // 두 번째 세션은 finishCalibration이 딱 두 번의 프레임(t, t+2초)만 보내므로 닫힌 칸은
        // 정확히 2개(0번, 1번)다 — 2번 칸은 보정을 끝내는 프레임이 아직 누적 중이라 열려 있다.
        // 값이 확정적이므로 느슨한 상한 대신 정확한 값으로 고정한다.
        XCTAssertEqual(viewModel.timeline.count, 2, "이전 세션 칸이 남으면 안 된다")
    }

    /// 슬롯 판정은 프레임 경로에서 끝나야 한다. 시작 직후 첫 프레임이 한 장을 요청한다.
    func test_snapshotRequest_risesOnTheFirstUsableFrame() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        finishCalibration(monitor, clock)

        XCTAssertGreaterThan(viewModel.snapshotRequestCount, 0)
    }

    // MARK: - 측정 보존

    /// 시작 전에는 아무것도 기록되지 않았다.
    func test_hasRecordedAnySecond_isFalse_onFreshViewModel() {
        let (viewModel, _, _, _) = makeViewModel()

        XCTAssertFalse(viewModel.hasRecordedAnySecond)
    }

    /// 한 칸이 확정되면 — 보정 중이라 unknown뿐이어도 — 무언가 기록됐다고 본다.
    func test_hasRecordedAnySecond_becomesTrue_onceASecondIsRecorded() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()

        monitor.emit(sample(smile: 0.1))
        clock.date += 1
        monitor.emit(sample(smile: 0.1)) // 앞 칸을 닫는다

        XCTAssertTrue(viewModel.hasRecordedAnySecond)
    }

    /// 프레임이 오기 전에 실패하면(권한 거부 등) 기록된 게 없다 — 요약을 보여줄 이유가 없다.
    func test_hasRecordedAnySecond_isFalse_whenFailureHappensBeforeAnyFrame() {
        let (viewModel, monitor, _, _) = makeViewModel()
        viewModel.start()

        monitor.emit(.permissionDenied)

        XCTAssertFalse(viewModel.hasRecordedAnySecond)
    }

    /// 핵심 회귀 방지: fail()이 화면용 timeline을 비워도, recorder가 들고 있는 기록은 남아야
    /// 세션 실패·인터럽션 뒤에도 요약을 보여줄 수 있다.
    func test_hasRecordedAnySecond_staysTrue_afterFailureClearsPublishedTimeline() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        monitor.emit(sample(smile: 0.1))
        clock.date += 1
        monitor.emit(sample(smile: 0.1))
        XCTAssertTrue(viewModel.hasRecordedAnySecond, "사전 조건")

        monitor.emit(.sessionFailed)

        XCTAssertEqual(viewModel.state, .failed(.sessionFailed))
        XCTAssertTrue(viewModel.timeline.isEmpty, "실패 시 화면용 timeline은 그대로 비운다")
        XCTAssertTrue(viewModel.hasRecordedAnySecond, "recorder는 실패 후에도 기록을 들고 있어야 한다")
    }

    /// finishSession()은 실패 뒤에도 옳은 요약을 낸다 — recorder는 stop()에 영향받지 않는다.
    func test_finishSession_afterFailure_stillReturnsRecordedSummary() {
        let (viewModel, monitor, clock, _) = makeViewModel()
        viewModel.start()
        monitor.emit(sample(smile: 0.1))
        clock.date += 1
        monitor.emit(sample(smile: 0.1))

        monitor.emit(.sessionFailed)
        let summary = viewModel.finishSession()

        XCTAssertGreaterThan(summary.totalSeconds, 0, "실패 전에 기록된 칸이 요약에 남아 있어야 한다")
    }
}
