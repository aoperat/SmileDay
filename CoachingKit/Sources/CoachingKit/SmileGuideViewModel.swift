import Foundation
import Observation

/// 카운트다운 1초. 테스트가 실제로 5초를 기다리지 않도록 경계를 분리한다.
public protocol SmileGuideClock: Sendable {
    func tick() async throws
}

public struct RealTimeSmileGuideClock: SmileGuideClock {
    public init() {}

    public func tick() async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
}

/// 가이드 한 번의 실행 상태.
///
/// 표정을 측정하지 않는다. 타이머를 끝까지 본 것이 완료이고, 중간에 닫으면 기록하지 않는다.
@MainActor
@Observable
public final class SmileGuideViewModel {
    public enum Phase: Equatable {
        case ready
        case running(remainingSeconds: Int)
        case completed
    }

    public private(set) var phase: Phase = .ready
    /// 저장이 실패하면 완료 문구 대신 이 사실을 알린다.
    public private(set) var saveFailed = false

    public let guide: SmileGuide

    private let source: SmileMomentSource
    private let repository: SmileMomentRepository
    private let clock: SmileGuideClock
    private let now: () -> Date
    private let onCompleted: (() -> Void)?

    /// 취소되었거나 다시 시작된 카운트다운이 뒤늦게 완료 처리하지 않도록 하는 세대 번호.
    private var runToken = 0
    private var hasSaved = false

    public init(
        guide: SmileGuide,
        source: SmileMomentSource,
        repository: SmileMomentRepository,
        clock: SmileGuideClock = RealTimeSmileGuideClock(),
        now: @escaping () -> Date = Date.init,
        onCompleted: (() -> Void)? = nil
    ) {
        self.guide = guide
        self.source = source
        self.repository = repository
        self.clock = clock
        self.now = now
        self.onCompleted = onCompleted
    }

    /// 화면을 열자마자가 아니라 사용자가 "시작"을 눌렀을 때만 카운트다운이 돈다.
    /// ready가 아니면 아무 일도 하지 않으므로 연타해도 카운트다운이 겹치지 않는다.
    public func start() async {
        guard phase == .ready else { return }

        runToken += 1
        let token = runToken
        var remaining = guide.durationSeconds
        phase = .running(remainingSeconds: remaining)

        while remaining > 0 {
            do {
                try await clock.tick()
            } catch {
                return
            }
            // 기다리는 사이에 닫혔거나 다시 시작됐다면 이 카운트다운은 버린다.
            guard token == runToken else { return }
            remaining -= 1
            phase = .running(remainingSeconds: remaining)
        }

        complete()
    }

    /// 화면을 닫을 때 호출. 진행 중이던 카운트다운은 기록 없이 버린다.
    public func cancel() {
        guard phase != .completed else { return }
        runToken += 1
        phase = .ready
    }

    private func complete() {
        // 화면 재표시나 중복 완료로 두 번 저장되거나 콜백이 두 번 불리지 않게 한 번만 통과시킨다.
        guard phase != .completed else { return }

        if !hasSaved {
            do {
                try repository.save(guideID: guide.id, source: source, date: now())
                hasSaved = true
                saveFailed = false
            } catch {
                saveFailed = true
            }
        }

        phase = .completed
        onCompleted?()
    }
}
