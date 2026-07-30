import Foundation
import Observation

/// 실시간 확인을 시작할 수 없게 만드는 상황.
public enum LiveSmileFailure: Equatable, Sendable {
    case permissionDenied
    case unsupportedDevice
    case sessionFailed
}

/// 단계보다 먼저 알려야 하는 측정 품질 문제.
public enum LiveSmileQualityIssue: Equatable, Sendable {
    case faceNotFound
    case notFacingCamera
    case tooDark
}

public enum LiveSmileMonitorState: Equatable, Sendable {
    case idle
    case requestingPermission
    case calibrating
    case monitoring
    case qualityIssue(LiveSmileQualityIssue)
    case failed(LiveSmileFailure)
}

/// 실시간 확인 화면의 상태.
///
/// 보정, 안정화, 품질 우선순위, 갱신 빈도 제한을 담당한다. 저장소를 갖지 않는다 —
/// 어떤 경로로 끝나도 단계와 보정값은 메모리에서만 살다 사라진다.
///
/// 숫자를 밖으로 내보내지 않는다. 화면이 쓰는 것은 `level` 하나다.
@MainActor
@Observable
public final class LiveSmileMonitorViewModel {
    /// 편한 표정을 모으는 시간.
    public static let calibrationDuration: TimeInterval = 2
    /// 지수 이동 평균 계수. 낮을수록 부드럽고 느리다.
    public static let smoothingAlpha = 0.2
    /// 단계 갱신 상한(초당 10회).
    public static let minimumPublishInterval: TimeInterval = 0.1
    /// 경계 근처에서 단계가 왕복하지 않게 하는 여유 신호 값.
    public static let levelHysteresis = 0.03
    /// 프레임 간격이 이보다 크면 웃지 않은 시간으로 세지 않는다.
    ///
    /// 얼굴을 놓쳤거나 어두워서 끊긴 동안은 웃는지 알 수 없다. 그 시간까지 세면
    /// 자리에 돌아오자마자 알림이 뜬다.
    public static let maxNudgeFrameGap: TimeInterval = 1

    public private(set) var state: LiveSmileMonitorState = .idle
    /// 보정 중이거나 품질 문제일 때는 nil이다 — 믿을 수 없는 단계를 남겨두지 않는다.
    public private(set) var level: LiveSmileLevel?
    /// 알림이 울린 횟수. 화면이 이 값의 변화를 보고 "Smile!"을 띄운다.
    public private(set) var nudgeCount = 0
    /// 측정 중 그래프가 그리는 타임라인. 확정된 1초 칸만 들어 있다.
    public private(set) var timeline: [LiveSmileObservation] = []
    /// 사진을 집어야 할 때마다 오른다. 화면이 이 변화를 보고 이미지를 만든다.
    ///
    /// 판정은 프레임 경로에서 끝났으므로, 화면이 한 박자 뒤에 캡처해도 방금 쓸 만한
    /// 프레임이 있었다는 사실은 이미 확정돼 있다.
    public private(set) var snapshotRequestCount = 0

    private let monitor: LiveSmileMonitoring
    private let now: () -> Date
    private let nudging: LiveSmileNudging?
    private let nudgeSettings: LiveSmileNudgeSettings

    /// 웃지 않는 단계로 머문 누적 시간. 끊긴 동안은 늘지 않는다.
    private var restingDuration: TimeInterval = 0
    private var lastMonitoringFrameAt: Date?

    /// stop 이후 뒤늦게 도착한 이벤트를 버리기 위한 플래그.
    private var isAcceptingEvents = false
    private var neutralSmileMean: Double?
    private var calibrationSamples: [Double] = []
    private var calibrationStartedAt: Date?
    private var smoothedSignal: Double?
    private var lastPublishedAt: Date?
    /// 세션마다 새로 만든다. 이전 세션 기록이 섞이면 안 된다.
    private var recorder: LiveSmileSessionRecorder

    public init(
        monitor: LiveSmileMonitoring,
        nudging: LiveSmileNudging? = nil,
        nudgeSettings: LiveSmileNudgeSettings = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.monitor = monitor
        self.nudging = nudging
        self.nudgeSettings = nudgeSettings
        self.now = now
        self.recorder = LiveSmileSessionRecorder(now: now)
    }

    // MARK: - 생명주기

    /// 이미 돌고 있으면 아무 일도 하지 않는다.
    public func start() {
        guard !isAcceptingEvents else { return }

        isAcceptingEvents = true
        recorder = LiveSmileSessionRecorder(now: now)
        resetMeasurement()
        state = .requestingPermission
        monitor.onEvent = { [weak self] event in
            self?.handle(event)
        }
        monitor.start()
    }

    /// 멈춘 상태에서 불러도 안전하다. 단계와 보정값을 모두 버린다.
    public func stop() {
        monitor.onEvent = nil
        monitor.stop()
        isAcceptingEvents = false
        resetMeasurement()
        state = .idle
    }

    /// 편한 표정을 다시 모은다. 이전 보정값과 안정화 상태는 버린다.
    ///
    /// 보정 중에 이미 웃고 있었으면 단계가 잘 오르지 않으므로 사용자가 직접 부른다.
    public func recalibrate() {
        guard isAcceptingEvents else { return }

        resetMeasurement()
        state = .calibrating
    }

    /// 측정을 끝내고 요약을 낸다. 세션은 멈추지만 요약은 호출자가 들고 있다.
    ///
    /// 저장하지 않는다. 호출자가 화면을 닫으면 그대로 사라진다.
    public func finishSession() -> LiveSmileSessionSummary {
        let summary = recorder.finish()
        stop()
        return summary
    }

    // MARK: - 이벤트 처리

    private func handle(_ event: LiveSmileMonitorEvent) {
        guard isAcceptingEvents else { return }

        switch event {
        case .permissionDenied:
            fail(.permissionDenied)
        case .unsupportedDevice:
            fail(.unsupportedDevice)
        case .sessionFailed:
            fail(.sessionFailed)
        case .faceLost:
            reportQualityIssue(.faceNotFound)
        case .sample(let sample):
            handle(sample)
        }
    }

    private func handle(_ sample: LiveSmileSample) {
        // 자세와 조명이 단계보다 먼저다. 흔들린 신호에 단계를 붙이면 사용자가 자기 표정을 탓한다.
        guard LiveSmileSignalEvaluator.isFacingCamera(sample) else {
            reportQualityIssue(.notFacingCamera)
            return
        }
        guard !LiveSmileSignalEvaluator.isTooDark(sample) else {
            reportQualityIssue(.tooDark)
            return
        }

        guard let neutralSmileMean else {
            calibrate(with: sample)
            return
        }

        publish(
            signal: LiveSmileSignalEvaluator.signal(sample: sample, neutralSmileMean: neutralSmileMean)
        )
    }

    /// 정상 프레임만 편한 표정 평균에 들어간다.
    private func calibrate(with sample: LiveSmileSample) {
        state = .calibrating
        record(.unknown)
        calibrationSamples.append(LiveSmileSignalEvaluator.smileMean(sample))

        let startedAt = calibrationStartedAt ?? now()
        calibrationStartedAt = startedAt

        // 유효 프레임이 드물면 그만큼 보정이 길어진다.
        guard now().timeIntervalSince(startedAt) >= Self.calibrationDuration else { return }

        neutralSmileMean = calibrationSamples.reduce(0, +) / Double(calibrationSamples.count)
        calibrationSamples = []
        calibrationStartedAt = nil

        publish(signal: 0)
    }

    private func publish(signal: Double) {
        accumulateRestingTime()

        let smoothed = smoothedSignal.map {
            Self.smoothingAlpha * signal + (1 - Self.smoothingAlpha) * $0
        } ?? signal
        smoothedSignal = smoothed

        // 이 프레임의 단계로 기록한다. 화면에 게시하는 level은 초당 10회로 제한되지만
        // 기록은 제한하지 않는다 — 그건 UI 갱신 제한이지 측정 제한이 아니다.
        let frameLevel = Self.nextLevel(signal: smoothed, current: level)
        record(frameLevel == .resting ? .notSmiling : .smiling)

        // 품질 문제에서 막 돌아왔다면 단계가 사라진 상태이므로 기다리지 않고 바로 보여준다.
        let isResuming = state != .monitoring || level == nil
        state = .monitoring

        if let lastPublishedAt, !isResuming,
           now().timeIntervalSince(lastPublishedAt) < Self.minimumPublishInterval {
            return
        }

        level = Self.nextLevel(signal: smoothed, current: level)
        lastPublishedAt = now()
    }

    /// 웃지 않는 단계로 머문 시간을 재고, 설정한 간격을 넘으면 알린다.
    ///
    /// 직전 프레임과의 간격을 더하는 방식이라 끊긴 구간은 자동으로 빠진다.
    /// 알린 뒤에는 0부터 다시 세므로, 계속 웃지 않으면 같은 간격으로 다시 알린다.
    private func accumulateRestingTime() {
        let timestamp = now()
        let previous = lastMonitoringFrameAt
        lastMonitoringFrameAt = timestamp

        guard nudgeSettings.isEnabled, let nudging else { return }

        // 단계를 알 수 없는 동안(보정 중, 품질 문제 직후)은 누적하지도 초기화하지도 않는다.
        guard let level else { return }
        // 한 번이라도 웃으면 처음부터 다시 센다.
        guard level == .resting else {
            restingDuration = 0
            return
        }
        guard let previous else { return }

        let delta = timestamp.timeIntervalSince(previous)
        guard delta > 0, delta <= Self.maxNudgeFrameGap else { return }

        restingDuration += delta
        guard restingDuration >= Double(nudgeSettings.intervalSeconds) else { return }

        restingDuration = 0
        nudgeCount += 1
        nudging.nudge(withHaptic: nudgeSettings.isHapticEnabled)
    }

    /// recorder에 넘기고, 칸이 새로 확정됐을 때만 화면용 타임라인을 갱신한다.
    ///
    /// 스냅샷 슬롯도 여기서 확보한다. `claimSnapshotSlot()`은 마지막으로 넘긴 관찰을 믿으므로
    /// 프레임 경로 밖에서 부르면 안 된다 — 얼굴이 사라진 뒤에도 낡은 `notSmiling`이 남아
    /// 가드를 통과하고, 얼굴 없는 사진이 찍힌다.
    private func record(_ observation: LiveSmileObservation) {
        recorder.observe(observation)

        if recorder.claimSnapshotSlot() {
            snapshotRequestCount += 1
        }

        guard recorder.timeline.count != timeline.count else { return }
        timeline = recorder.timeline
    }

    private func reportQualityIssue(_ issue: LiveSmileQualityIssue) {
        record(.unknown)
        state = .qualityIssue(issue)
        // 원인을 안내하는 동안 마지막 단계를 남겨두면 그 값이 현재 표정으로 읽힌다.
        level = nil
        // 단계가 사라졌다 다시 나타나므로, 끊기기 전 값에서 이어 붙이지 않고 지금 프레임에서 다시 쌓는다.
        smoothedSignal = nil
        lastPublishedAt = nil
        // 끊긴 구간이 웃지 않은 시간으로 세지 않도록 기준점만 버린다.
        // 누적값은 남긴다 — 잠깐 고개를 돌렸다고 처음부터 다시 셀 이유는 없다.
        lastMonitoringFrameAt = nil
        // 보정값도 유지한다.
    }

    private func fail(_ failure: LiveSmileFailure) {
        monitor.onEvent = nil
        monitor.stop()
        isAcceptingEvents = false
        resetMeasurement()
        state = .failed(failure)
    }

    private func resetMeasurement() {
        level = nil
        neutralSmileMean = nil
        calibrationSamples = []
        calibrationStartedAt = nil
        smoothedSignal = nil
        lastPublishedAt = nil
        restingDuration = 0
        lastMonitoringFrameAt = nil
        timeline = []
    }

    /// 경계를 살짝 넘나드는 것만으로 단계가 바뀌지 않게 한다.
    static func nextLevel(signal: Double, current: LiveSmileLevel?) -> LiveSmileLevel {
        let candidate = LiveSmileLevel.containing(signal: signal)
        guard let current, candidate != current else { return candidate }

        if candidate.rawValue > current.rawValue {
            return signal >= candidate.lowerBound + levelHysteresis ? candidate : current
        }
        return signal < current.lowerBound - levelHysteresis ? candidate : current
    }
}
