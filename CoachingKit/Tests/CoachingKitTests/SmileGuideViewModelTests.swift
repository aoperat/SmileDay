import XCTest
import SwiftData
@testable import CoachingKit

@MainActor
final class SmileGuideViewModelTests: XCTestCase {
    /// 기다리지 않는 시계. 카운트다운 전체를 한 번에 흘려보낸다.
    private struct ImmediateClock: SmileGuideClock {
        func tick() async throws {}
    }

    /// 테스트가 1초씩 직접 흘려보내는 시계.
    private final class GateClock: SmileGuideClock, @unchecked Sendable {
        private let lock = NSLock()
        private var pending: [CheckedContinuation<Void, Never>] = []

        func tick() async {
            await withCheckedContinuation { continuation in
                lock.lock()
                pending.append(continuation)
                lock.unlock()
            }
        }

        var pendingCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return pending.count
        }

        /// 다음 tick이 걸릴 때까지 기다렸다가 1초를 흘려보낸다.
        func advanceOneSecond() async {
            while pendingCount == 0 { await Task.yield() }
            resumeOnePendingTick()
        }

        /// 기다리는 tick이 있으면 흘려보내고, 없으면 false. 취소 뒤처럼 tick이 더 이상
        /// 걸리지 않는 상황에서 무한정 기다리지 않으려고 쓴다.
        @discardableResult
        func advanceOneSecondIfPending() async -> Bool {
            for _ in 0..<50 {
                if pendingCount > 0 {
                    resumeOnePendingTick()
                    return true
                }
                await Task.yield()
            }
            return false
        }

        private func resumeOnePendingTick() {
            lock.lock()
            let continuation = pending.removeFirst()
            lock.unlock()
            continuation.resume()
        }
    }

    private func makeRepository() throws -> SmileMomentRepository {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return SmileMomentRepository(modelContext: ModelContext(container))
    }

    private func savedMoments(_ repository: SmileMomentRepository) throws -> [SmileMoment] {
        try repository.fetch(from: .distantPast, to: .distantFuture)
    }

    private func waitUntil(
        _ condition: () -> Bool,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<1000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail(message, file: file, line: line)
    }

    // MARK: - 상태 머신

    func test_initialPhase_isReady_andDoesNotStartOnItsOwn() throws {
        let repository = try makeRepository()
        let viewModel = SmileGuideViewModel(
            guide: SmileGuideCatalog.default,
            source: .manual,
            repository: repository,
            clock: ImmediateClock()
        )

        XCTAssertEqual(viewModel.phase, .ready)
        XCTAssertTrue(try savedMoments(repository).isEmpty)
    }

    func test_start_countsDownFromGuideDuration() async throws {
        let clock = GateClock()
        let viewModel = SmileGuideViewModel(
            guide: SmileGuideCatalog.default,
            source: .manual,
            repository: try makeRepository(),
            clock: clock
        )

        let run = Task { await viewModel.start() }
        await waitUntil({ viewModel.phase == .running(remainingSeconds: 5) }, "시작하면 5초부터 시작해야 한다")

        await clock.advanceOneSecond()
        await waitUntil({ viewModel.phase == .running(remainingSeconds: 4) }, "1초 뒤 4가 되어야 한다")

        await clock.advanceOneSecond()
        await waitUntil({ viewModel.phase == .running(remainingSeconds: 3) }, "2초 뒤 3이 되어야 한다")

        viewModel.cancel()
        await clock.advanceOneSecondIfPending()
        _ = await run.value
    }

    func test_start_reachingZero_completes() async throws {
        let viewModel = SmileGuideViewModel(
            guide: SmileGuideCatalog.default,
            source: .manual,
            repository: try makeRepository(),
            clock: ImmediateClock()
        )

        await viewModel.start()

        XCTAssertEqual(viewModel.phase, .completed)
    }

    // MARK: - 저장

    func test_completion_savesExactlyOnce_withGuideAndSource() async throws {
        let repository = try makeRepository()
        let completedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = SmileGuideViewModel(
            guide: SmileGuideCatalog.guide(id: "morning-greeting"),
            source: .notification,
            repository: repository,
            clock: ImmediateClock(),
            now: { completedAt }
        )

        await viewModel.start()

        let saved = try savedMoments(repository)
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.guideID, "morning-greeting")
        XCTAssertEqual(saved.first?.source, .notification)
        XCTAssertEqual(saved.first?.date, completedAt)
        XCTAssertFalse(viewModel.saveFailed)
    }

    func test_manualEntry_savesManualSource() async throws {
        let repository = try makeRepository()
        let viewModel = SmileGuideViewModel(
            guide: SmileGuideCatalog.guide(id: "anytime-pause"),
            source: .manual,
            repository: repository,
            clock: ImmediateClock()
        )

        await viewModel.start()

        XCTAssertEqual(try savedMoments(repository).first?.source, .manual)
    }

    /// 시작 연타로 카운트다운이 겹치거나 두 번 저장되면 안 된다.
    func test_start_calledTwiceConcurrently_savesOnce() async throws {
        let repository = try makeRepository()
        let viewModel = SmileGuideViewModel(
            guide: SmileGuideCatalog.default,
            source: .manual,
            repository: repository,
            clock: ImmediateClock()
        )

        async let first: Void = viewModel.start()
        async let second: Void = viewModel.start()
        _ = await (first, second)

        XCTAssertEqual(try savedMoments(repository).count, 1)
    }

    /// 완료 후 화면이 다시 그려지며 start가 불려도 추가 저장이 없어야 한다.
    func test_start_afterCompletion_doesNotSaveAgain() async throws {
        let repository = try makeRepository()
        let viewModel = SmileGuideViewModel(
            guide: SmileGuideCatalog.default,
            source: .manual,
            repository: repository,
            clock: ImmediateClock()
        )

        await viewModel.start()
        await viewModel.start()
        await viewModel.start()

        XCTAssertEqual(try savedMoments(repository).count, 1)
        XCTAssertEqual(viewModel.phase, .completed)
    }

    func test_completion_callsCallbackExactlyOnce() async throws {
        var callbackCount = 0
        let viewModel = SmileGuideViewModel(
            guide: SmileGuideCatalog.default,
            source: .manual,
            repository: try makeRepository(),
            clock: ImmediateClock(),
            onCompleted: { callbackCount += 1 }
        )

        await viewModel.start()
        await viewModel.start()

        XCTAssertEqual(callbackCount, 1)
    }

    // MARK: - 취소

    func test_cancel_midCountdown_doesNotSave_andReturnsToReady() async throws {
        let clock = GateClock()
        let repository = try makeRepository()
        let viewModel = SmileGuideViewModel(
            guide: SmileGuideCatalog.default,
            source: .manual,
            repository: repository,
            clock: clock
        )

        let run = Task { await viewModel.start() }
        await waitUntil({ viewModel.phase == .running(remainingSeconds: 5) }, "카운트다운이 시작되어야 한다")
        await clock.advanceOneSecond()
        await waitUntil({ viewModel.phase == .running(remainingSeconds: 4) }, "1초가 흘러야 한다")

        viewModel.cancel()

        XCTAssertEqual(viewModel.phase, .ready)
        await clock.advanceOneSecondIfPending() // 버려진 tick
        _ = await run.value
        XCTAssertTrue(try savedMoments(repository).isEmpty, "중간에 닫으면 기록하지 않는다")
    }

    /// 취소 후 남아 있던 tick이 뒤늦게 완료 처리하면 안 된다.
    func test_cancel_thenLateTicks_neverComplete() async throws {
        let clock = GateClock()
        let repository = try makeRepository()
        let viewModel = SmileGuideViewModel(
            guide: SmileGuideCatalog.default,
            source: .manual,
            repository: repository,
            clock: clock
        )

        let run = Task { await viewModel.start() }
        await waitUntil({ viewModel.phase == .running(remainingSeconds: 5) }, "카운트다운이 시작되어야 한다")
        viewModel.cancel()

        // 버려진 tick 하나가 뒤늦게 돌아온다. 그 뒤로는 tick이 더 걸리지 않아야 한다.
        let advancedLateTick = await clock.advanceOneSecondIfPending()
        _ = await run.value
        let advancedAgain = await clock.advanceOneSecondIfPending()

        XCTAssertTrue(advancedLateTick)
        XCTAssertFalse(advancedAgain, "취소된 카운트다운은 계속 돌면 안 된다")
        XCTAssertEqual(viewModel.phase, .ready)
        XCTAssertTrue(try savedMoments(repository).isEmpty)
    }

    /// 취소하고 다시 시작하면 처음부터 세고, 완료는 한 번만 저장된다.
    func test_cancel_thenRestart_countsFromFullDuration_andSavesOnce() async throws {
        let repository = try makeRepository()
        let clock = GateClock()
        let viewModel = SmileGuideViewModel(
            guide: SmileGuideCatalog.default,
            source: .manual,
            repository: repository,
            clock: clock
        )

        let first = Task { await viewModel.start() }
        await waitUntil({ viewModel.phase == .running(remainingSeconds: 5) }, "카운트다운이 시작되어야 한다")
        await clock.advanceOneSecond()
        await waitUntil({ viewModel.phase == .running(remainingSeconds: 4) }, "1초가 흘러야 한다")
        viewModel.cancel()
        await clock.advanceOneSecondIfPending()
        _ = await first.value

        XCTAssertEqual(viewModel.phase, .ready)

        let second = Task { await viewModel.start() }
        await waitUntil({ viewModel.phase == .running(remainingSeconds: 5) }, "다시 시작하면 5초부터여야 한다")
        for _ in 0..<5 { await clock.advanceOneSecond() }
        _ = await second.value

        XCTAssertEqual(viewModel.phase, .completed)
        XCTAssertEqual(try savedMoments(repository).count, 1)
    }

    func test_cancel_afterCompletion_keepsCompletedPhase() async throws {
        let repository = try makeRepository()
        let viewModel = SmileGuideViewModel(
            guide: SmileGuideCatalog.default,
            source: .manual,
            repository: repository,
            clock: ImmediateClock()
        )

        await viewModel.start()
        viewModel.cancel()

        XCTAssertEqual(viewModel.phase, .completed)
        XCTAssertEqual(try savedMoments(repository).count, 1)
    }
}
