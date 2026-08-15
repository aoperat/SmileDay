import XCTest
import SwiftData
@testable import CoachingKit

/// 저장에 실패한 완료를 다시 기록하는 경로.
///
/// 이전에는 "다시 시도해주세요"라고 안내하면서 화면에는 닫기만 있어, 안내한 행동을 할 수
/// 없었다. 5초를 다시 세게 하지 않고 같은 완료를 그대로 재저장한다.
@MainActor
final class SmileGuideRetrySaveTests: XCTestCase {
    private struct ImmediateClock: SmileGuideClock {
        func tick() async throws {}
    }

    private struct SaveError: Error {}

    /// 지정한 횟수만큼 실패한 뒤 성공하는 저장소.
    private final class FlakyRepository: SmileMomentRecording {
        private(set) var attempts: [(guideID: String, source: SmileMomentSource, date: Date)] = []
        private(set) var saved: [SmileMoment] = []
        private var failuresRemaining: Int

        init(failuresRemaining: Int) {
            self.failuresRemaining = failuresRemaining
        }

        @discardableResult
        func save(guideID: String, source: SmileMomentSource, date: Date) throws -> SmileMoment {
            attempts.append((guideID, source, date))
            if failuresRemaining > 0 {
                failuresRemaining -= 1
                throw SaveError()
            }
            let moment = SmileMoment(date: date, guideID: guideID, source: source)
            saved.append(moment)
            return moment
        }
    }

    private func completedViewModel(
        repository: SmileMomentRecording,
        now: @escaping () -> Date,
        onCompleted: (() -> Void)? = nil
    ) async -> SmileGuideViewModel {
        let viewModel = SmileGuideViewModel(
            guide: SmileGuideCatalog.default,
            source: .manual,
            repository: repository,
            clock: ImmediateClock(),
            now: now,
            onCompleted: onCompleted
        )
        await viewModel.start()
        return viewModel
    }

    private let completedAt = Date(timeIntervalSince1970: 1_785_000_000)

    func test_completion_marksSaveFailed_whenRepositoryThrows() async {
        let repository = FlakyRepository(failuresRemaining: 1)

        let viewModel = await completedViewModel(repository: repository, now: { self.completedAt })

        XCTAssertEqual(viewModel.phase, .completed)
        XCTAssertTrue(viewModel.saveFailed)
        XCTAssertTrue(repository.saved.isEmpty)
    }

    func test_retrySave_recordsTheCompletion_andClearsTheFailure() async {
        let repository = FlakyRepository(failuresRemaining: 1)
        let viewModel = await completedViewModel(repository: repository, now: { self.completedAt })

        viewModel.retrySave()

        XCTAssertFalse(viewModel.saveFailed)
        XCTAssertEqual(repository.saved.count, 1)
        XCTAssertEqual(repository.saved.first?.guideID, SmileGuideCatalog.default.id)
        XCTAssertEqual(repository.saved.first?.source, .manual)
    }

    /// 한참 뒤에 눌러도 웃은 시각은 처음 완료한 그때다. 자정을 넘겨 누르면
    /// 재시도 시각으로 기록될 경우 웃은 날짜가 바뀐다.
    func test_retrySave_keepsTheOriginalCompletionTime() async {
        let repository = FlakyRepository(failuresRemaining: 1)
        var clockReading = completedAt
        let viewModel = await completedViewModel(repository: repository, now: { clockReading })

        clockReading = completedAt.addingTimeInterval(60 * 60 * 8)
        viewModel.retrySave()

        XCTAssertEqual(repository.saved.first?.date, completedAt)
    }

    func test_retrySave_notifiesCompletion_soTodayCountRefreshes() async {
        let repository = FlakyRepository(failuresRemaining: 1)
        var completionCallbacks = 0
        let viewModel = await completedViewModel(
            repository: repository,
            now: { self.completedAt },
            onCompleted: { completionCallbacks += 1 }
        )
        let afterFailedCompletion = completionCallbacks

        viewModel.retrySave()

        XCTAssertEqual(completionCallbacks, afterFailedCompletion + 1)
    }

    func test_retrySave_staysFailed_whenTheStoreIsStillUnavailable() async {
        let repository = FlakyRepository(failuresRemaining: 2)
        let viewModel = await completedViewModel(repository: repository, now: { self.completedAt })

        viewModel.retrySave()

        XCTAssertTrue(viewModel.saveFailed)
        XCTAssertTrue(repository.saved.isEmpty)
        XCTAssertEqual(repository.attempts.count, 2)
    }

    /// 재시도가 성공한 뒤 또 누르거나, 애초에 성공한 완료에서 눌러도 두 번 세지 않는다.
    func test_retrySave_doesNothing_whenAlreadySaved() async {
        let repository = FlakyRepository(failuresRemaining: 1)
        let viewModel = await completedViewModel(repository: repository, now: { self.completedAt })
        viewModel.retrySave()

        viewModel.retrySave()
        viewModel.retrySave()

        XCTAssertEqual(repository.saved.count, 1)
        XCTAssertEqual(repository.attempts.count, 2)
    }

    func test_retrySave_doesNothing_whenCompletionSucceededFirstTime() async {
        let repository = FlakyRepository(failuresRemaining: 0)
        let viewModel = await completedViewModel(repository: repository, now: { self.completedAt })

        viewModel.retrySave()

        XCTAssertFalse(viewModel.saveFailed)
        XCTAssertEqual(repository.attempts.count, 1)
    }

    /// 카운트다운을 끝내지 않았으면 재시도할 완료 자체가 없다.
    func test_retrySave_doesNothing_beforeCompletion() {
        let repository = FlakyRepository(failuresRemaining: 1)
        let viewModel = SmileGuideViewModel(
            guide: SmileGuideCatalog.default,
            source: .manual,
            repository: repository,
            clock: ImmediateClock(),
            now: { self.completedAt }
        )

        viewModel.retrySave()

        XCTAssertEqual(viewModel.phase, .ready)
        XCTAssertTrue(repository.attempts.isEmpty)
    }
}
