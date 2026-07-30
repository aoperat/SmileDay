import XCTest
@testable import CoachingKit

final class LiveSmileSessionSummaryTests: XCTestCase {
    private func summary(_ timeline: [LiveSmileObservation]) -> LiveSmileSessionSummary {
        LiveSmileSessionSummary(timeline: timeline)
    }

    func test_emptySession_hasNoRatioAndDoesNotDivideByZero() {
        let result = summary([])

        XCTAssertEqual(result.totalSeconds, 0)
        XCTAssertNil(result.smilingRatio, "판정 가능 시간이 0이면 비율이 없다")
        XCTAssertEqual(result.unknownRatio, 0, "세션 길이가 0이어도 NaN을 내보내지 않는다")
    }

    /// 세 값을 모두 다르게 둔다. 세는 대상이 뒤바뀌면 이 테스트 하나로도 잡힌다.
    func test_countsEachObservation() {
        let result = summary([.smiling, .smiling, .smiling, .notSmiling, .notSmiling, .unknown])

        XCTAssertEqual(result.totalSeconds, 6)
        XCTAssertEqual(result.smilingSeconds, 3)
        XCTAssertEqual(result.notSmilingSeconds, 2)
        XCTAssertEqual(result.unknownSeconds, 1)
        XCTAssertEqual(result.usableSeconds, 5)
    }

    /// 분모에서 unknown을 뺀다. 자리를 비운 시간이 낮은 숫자로 돌아오면 안 된다.
    func test_ratioExcludesUnknownFromDenominator() throws {
        let result = summary([.smiling, .notSmiling, .unknown, .unknown])

        XCTAssertEqual(try XCTUnwrap(result.smilingRatio), 0.5, accuracy: 0.0001)
        XCTAssertEqual(result.unknownRatio, 0.5, accuracy: 0.0001)
    }

    /// unknown만 있으면 판정 가능 시간이 0이다.
    func test_ratioIsNil_whenEverythingUnknown() {
        let result = summary([.unknown, .unknown])

        XCTAssertNil(result.smilingRatio)
        XCTAssertEqual(result.unknownRatio, 1, accuracy: 0.0001)
    }

    /// 한 번도 웃지 않은 것과 측정하지 못한 것은 다르다. 전자는 0%, 후자는 값이 없다.
    func test_ratioIsZero_whenUserNeverSmiled() throws {
        let result = summary([.notSmiling, .notSmiling])

        XCTAssertEqual(try XCTUnwrap(result.smilingRatio), 0, accuracy: 0.0001)
    }

    // MARK: - 신뢰 상태

    /// 측정이 없으면 신뢰 여부를 말하지 않는다. 없는 숫자를 두고 "참고만 해주세요"가
    /// 함께 뜨는 조합을 막는 것이 이 상태의 존재 이유다.
    func test_confidence_isNoMeasurement_whenNothingUsable() {
        XCTAssertEqual(summary([]).confidence, .noMeasurement)
        XCTAssertEqual(summary([.unknown, .unknown]).confidence, .noMeasurement)
    }

    func test_confidence_atUsableSecondsBoundary() {
        let justUnder = summary(Array(repeating: .smiling, count: 59))
        let atBoundary = summary(Array(repeating: .smiling, count: 60))

        XCTAssertEqual(justUnder.confidence, .low(ratio: 1), "59초는 짧다")
        XCTAssertEqual(atBoundary.confidence, .reliable(ratio: 1), "60초는 믿는다")
    }

    func test_confidence_whenUnknownExceedsHalf() {
        // 판정 가능 60초 + unknown 61초 → unknown 비율 약 50.4%
        let tooMuchUnknown = summary(
            Array(repeating: .smiling, count: 60) + Array(repeating: .unknown, count: 61)
        )
        // 판정 가능 60초 + unknown 60초 → 정확히 50%, 초과가 아니다
        let exactlyHalf = summary(
            Array(repeating: .smiling, count: 60) + Array(repeating: .unknown, count: 60)
        )

        XCTAssertEqual(tooMuchUnknown.confidence, .low(ratio: 1))
        XCTAssertEqual(exactlyHalf.confidence, .reliable(ratio: 1), "초과일 때만 낮은 신뢰다")
    }
}

final class LiveSmileSessionRecorderTests: XCTestCase {
    /// 테스트가 시간을 직접 옮긴다. 실제 시계에 의존하지 않는다.
    ///
    /// 클로저가 시계를 강하게 붙든다. 시계를 `_`로 버리는 테스트에서도 살아 있어야 한다.
    /// `now`는 저장 프로퍼티가 아니라 계산 프로퍼티라 순환 참조가 생기지 않는다.
    private final class TestClock {
        var date = Date(timeIntervalSince1970: 1_800_000_000)
        var now: () -> Date { { self.date } }
    }

    private func makeRecorder() -> (LiveSmileSessionRecorder, TestClock) {
        let clock = TestClock()
        return (LiveSmileSessionRecorder(now: clock.now), clock)
    }

    /// 그 1초의 프레임 다수결로 칸이 정해진다.
    func test_bucket_takesMajorityOfThatSecondsFrames() {
        let (recorder, clock) = makeRecorder()

        // 0초 칸: 미소 4 / 안 웃음 1
        for observation in [LiveSmileObservation.smiling, .smiling, .smiling, .smiling, .notSmiling] {
            recorder.observe(observation)
        }
        clock.date += 1
        recorder.observe(.notSmiling)

        XCTAssertEqual(recorder.finish().timeline, [.smiling, .notSmiling])
    }

    /// 프레임 하나가 튀어도 칸은 흔들리지 않는다.
    func test_bucket_ignoresSingleStrayFrame() {
        let (recorder, _) = makeRecorder()

        recorder.observe(.notSmiling)
        recorder.observe(.notSmiling)
        recorder.observe(.smiling)

        XCTAssertEqual(recorder.finish().timeline, [.notSmiling])
    }

    /// 동수면 안 웃음으로 본다 — 숫자를 부풀리지 않는 쪽으로 기운다.
    func test_bucket_breaksTieTowardNotSmiling() {
        let (recorder, _) = makeRecorder()

        recorder.observe(.smiling)
        recorder.observe(.notSmiling)

        XCTAssertEqual(recorder.finish().timeline, [.notSmiling])
    }

    /// 판정 가능 프레임이 절반 미만이면 그 칸은 모른다.
    func test_bucket_isUnknown_whenUsableFramesBelowHalf() {
        let (recorder, _) = makeRecorder()

        // 관측 5개 중 판정 가능 2개 → 2 < 2.5
        recorder.observe(.smiling)
        recorder.observe(.smiling)
        recorder.observe(.unknown)
        recorder.observe(.unknown)
        recorder.observe(.unknown)

        XCTAssertEqual(recorder.finish().timeline, [.unknown])
    }

    /// 정확히 절반이면 모른다고 하지 않는다.
    func test_bucket_isDecided_whenUsableFramesExactlyHalf() {
        let (recorder, _) = makeRecorder()

        // 관측 4개 중 판정 가능 2개 → 2 >= 2.0
        recorder.observe(.smiling)
        recorder.observe(.smiling)
        recorder.observe(.unknown)
        recorder.observe(.unknown)

        XCTAssertEqual(recorder.finish().timeline, [.smiling])
    }

    func test_finish_withoutAnyFrame_returnsEmptyTimeline() {
        let (recorder, _) = makeRecorder()

        XCTAssertEqual(recorder.finish().timeline, [])
    }

    /// 프레임이 하나도 없는 칸은 모른다. 인식이 끊긴 사이의 시간이 그렇다.
    ///
    /// 끊김 뒤의 프레임이 5번 칸에 들어가는 것까지 함께 확인한다. 건너뛴 칸을 채우면서
    /// 그 프레임을 바로 이어 붙이면 타임라인이 실제 시간보다 짧아진다.
    func test_bucket_isUnknown_whenNoFrameObserved() {
        let (recorder, clock) = makeRecorder()

        recorder.observe(.smiling)
        clock.date += 5 // 1~4번 칸을 건너뛰고 5번 칸으로 넘어간다
        recorder.observe(.smiling)

        XCTAssertEqual(
            recorder.finish().timeline,
            [.smiling, .unknown, .unknown, .unknown, .unknown, .smiling],
            "건너뛴 칸은 안 웃음이 아니라 모른다로 채운다"
        )
    }

    /// 인식이 끊긴 뒤 한참 있다 종료를 눌러도 그 시간이 빠지면 안 된다.
    /// 빠지면 unknown 비율이 낮아져 세션이 실제보다 믿을 만해 보인다.
    func test_finish_recordsTheGapBeforeStopping() {
        let (recorder, clock) = makeRecorder()

        recorder.observe(.smiling)
        clock.date += 3 // 인식이 끊긴 채 3초 뒤 종료

        XCTAssertEqual(
            recorder.finish().timeline,
            [.smiling, .unknown, .unknown, .unknown]
        )
    }

    /// 종료 직후 프레임에서 끝나면 채울 것이 없다 — 빈 칸을 덧붙이지 않는다.
    func test_finish_addsNothing_whenStoppingInTheSameSecond() {
        let (recorder, _) = makeRecorder()

        recorder.observe(.smiling)

        XCTAssertEqual(recorder.finish().timeline, [.smiling])
    }

    func test_finish_isIdempotent() {
        let (recorder, clock) = makeRecorder()
        recorder.observe(.smiling)
        clock.date += 2

        let first = recorder.finish().timeline
        let second = recorder.finish().timeline

        XCTAssertEqual(first, second, "두 번 불러도 칸이 늘지 않는다")
    }

    /// 프레임이 끊긴 30초가 "안 웃은 30초"로 남으면 안 된다.
    func test_gap_fillsSkippedSecondsWithUnknown() {
        let (recorder, clock) = makeRecorder()

        recorder.observe(.smiling)
        clock.date += 30
        recorder.observe(.smiling)

        let timeline = recorder.finish().timeline

        XCTAssertEqual(timeline.count, 31)
        XCTAssertEqual(timeline.first, .smiling)
        XCTAssertEqual(timeline.last, .smiling)
        XCTAssertEqual(timeline.dropFirst().dropLast(), Array(repeating: .unknown, count: 29)[...])
    }

    /// 끊긴 시간은 비율 분모에 들어가지 않는다.
    func test_gap_doesNotLowerTheRatio() throws {
        let (recorder, clock) = makeRecorder()

        recorder.observe(.smiling)
        clock.date += 10
        recorder.observe(.smiling)

        let summary = recorder.finish()

        XCTAssertEqual(try XCTUnwrap(summary.smilingRatio), 1.0, accuracy: 0.0001,
                       "웃은 두 칸만 판정 가능하므로 100%다")
        XCTAssertEqual(summary.totalSeconds, 11)
        XCTAssertEqual(summary.usableSeconds, 2)
    }

    /// 측정 중에는 확정된 칸만 그래프에 나간다.
    func test_timeline_exposesOnlyClosedBuckets() {
        let (recorder, clock) = makeRecorder()

        recorder.observe(.smiling)
        XCTAssertEqual(recorder.timeline, [], "첫 칸은 아직 진행 중이다")

        clock.date += 1
        recorder.observe(.notSmiling)
        XCTAssertEqual(recorder.timeline, [.smiling])
    }

    // MARK: - 스냅샷 슬롯

    /// 첫 장은 측정 시작 직후에 잡는다.
    func test_snapshot_firstSlotOpensImmediately() {
        let (recorder, _) = makeRecorder()

        recorder.observe(.notSmiling)

        XCTAssertTrue(recorder.claimSnapshotSlot())
    }

    func test_snapshot_claimsOnlyOncePerMinute() {
        let (recorder, clock) = makeRecorder()

        recorder.observe(.notSmiling)
        XCTAssertTrue(recorder.claimSnapshotSlot())
        XCTAssertFalse(recorder.claimSnapshotSlot(), "같은 분에 두 번 잡지 않는다")

        clock.date += 60
        recorder.observe(.notSmiling)
        XCTAssertTrue(recorder.claimSnapshotSlot(), "다음 분에는 다시 열린다")
    }

    /// 판정 불가 프레임으로 사진을 남기면 얼굴 없는 사진이 된다.
    func test_snapshot_isNotClaimedOnUnknownFrame() {
        let (recorder, _) = makeRecorder()

        recorder.observe(.unknown)

        XCTAssertFalse(recorder.claimSnapshotSlot())
    }

    /// 경계 후 5초 안에 쓸 프레임이 없으면 그 분은 건너뛴다.
    ///
    /// 첫 슬롯은 판정 가능한 첫 프레임에서 바로 열리므로, 유예 검증은 그다음 분 경계로
    /// 옮겨서 확인한다 — 첫 프레임 앞에 unknown 구간을 두면 그 자체가 첫 슬롯 기준점이 되어
    /// "유예를 넘김"을 재현하지 못한다(`test_snapshot_firstSlotUsesFirstJudgeableFrame_evenAfterLeadingUnknownGap` 참고).
    func test_snapshot_skipsMinute_whenNoUsableFrameWithinGrace() {
        let (recorder, clock) = makeRecorder()

        recorder.observe(.notSmiling) // 판정 가능 기준점 — 슬롯 0을 바로 잡는다
        XCTAssertTrue(recorder.claimSnapshotSlot())

        clock.date += 60
        recorder.observe(.unknown) // 경계에 판정 불가 프레임만 있다
        clock.date += 6
        recorder.observe(.notSmiling) // 경계 후 6초 — 유예(5초)를 넘겼다

        XCTAssertFalse(recorder.claimSnapshotSlot(), "5초를 넘겼으므로 이 분은 없다")

        clock.date += 54 // 다음 60초 경계
        recorder.observe(.notSmiling)
        XCTAssertTrue(recorder.claimSnapshotSlot(), "다음 분에는 다시 열린다")
    }

    /// 회귀 재현: 얼굴 인식 전이나 보정 중처럼 unknown이 여러 초 이어져도, 판정 가능한 첫
    /// 프레임에서는 슬롯 0을 바로 잡아야 한다.
    ///
    /// 예전에는 `startedAt`(첫 프레임 시각, unknown 포함)을 기준으로 유예를 쟀다. 그 사이가
    /// 5초(`snapshotGrace`)를 넘으면 보정이 막 끝난 순간에도 유예를 넘긴 것으로 취급돼
    /// 첫 60초 동안 편한 표정 참고 사진을 하나도 못 찍었다.
    func test_snapshot_firstSlotUsesFirstJudgeableFrame_evenAfterLeadingUnknownGap() {
        let (recorder, clock) = makeRecorder()

        recorder.observe(.unknown)
        clock.date += 6 // 유예(5초)보다 길게 unknown이 이어진다 — 얼굴 인식/보정 지연을 흉내낸다
        recorder.observe(.notSmiling) // 판정 가능한 첫 프레임

        XCTAssertTrue(
            recorder.claimSnapshotSlot(),
            "판정 가능한 첫 프레임은 그 앞의 unknown 구간과 무관하게 슬롯 0을 잡아야 한다"
        )
    }

    /// 두 번째 슬롯도 여전히 판정 가능한 첫 프레임을 기준으로 60초마다 열린다.
    func test_snapshot_slotsOpenPerMinuteFromFirstJudgeableFrame() {
        let (recorder, clock) = makeRecorder()

        recorder.observe(.unknown)
        clock.date += 6
        recorder.observe(.notSmiling) // 판정 가능 기준점
        XCTAssertTrue(recorder.claimSnapshotSlot())

        clock.date += 59 // 기준점 기준 59초 — 아직 다음 분이 아니다
        recorder.observe(.notSmiling)
        XCTAssertFalse(recorder.claimSnapshotSlot())

        clock.date += 1 // 기준점 기준 정확히 60초
        recorder.observe(.notSmiling)
        XCTAssertTrue(recorder.claimSnapshotSlot(), "판정 가능 기준점부터 60초가 지나면 다음 슬롯이 열린다")
    }

    /// 판정 가능한 프레임이 세션 동안 한 번도 없으면 슬롯이 영영 열리지 않는다.
    func test_snapshot_neverOpensSlot_whenNoFrameIsEverJudgeable() {
        let (recorder, clock) = makeRecorder()

        recorder.observe(.unknown)
        clock.date += 120
        recorder.observe(.unknown)

        XCTAssertFalse(recorder.claimSnapshotSlot())
    }

    // MARK: - 시계 역행

    /// 시계가 거꾸로 가도(NTP 보정 등) 이미 닫힌 칸 수보다 적은 인덱스로 되돌아가지 않는다.
    func test_observe_backwardClockDoesNotRegressBucketIndex() {
        let (recorder, clock) = makeRecorder()

        recorder.observe(.smiling)
        clock.date += 10
        recorder.observe(.smiling) // 0~9번 칸이 닫히고 10번 칸이 열린다
        clock.date -= 5 // 시계가 5초 되돌아간다
        recorder.observe(.smiling)

        let timeline = recorder.finish().timeline
        XCTAssertEqual(timeline.count, 11, "되돌아간 시계가 이미 닫힌 칸 수를 줄이면 안 된다")
    }

    /// 슬롯 번호는 반드시 증가해야 한다. `!=` 비교만으로는 시계가 되돌아가 이전 슬롯 번호로
    /// 돌아왔을 때 이미 잡은 분을 다시 열어준다.
    func test_snapshot_backwardClockDoesNotReopenAClaimedSlot() {
        let (recorder, clock) = makeRecorder()

        recorder.observe(.notSmiling)
        XCTAssertTrue(recorder.claimSnapshotSlot()) // 슬롯 0

        clock.date += 60
        recorder.observe(.notSmiling)
        XCTAssertTrue(recorder.claimSnapshotSlot()) // 슬롯 1

        clock.date -= 60 // 시계가 되돌아가 다시 슬롯 0 경계로 온다
        recorder.observe(.notSmiling)
        XCTAssertFalse(recorder.claimSnapshotSlot(), "이미 잡은 슬롯 0을 다시 열면 안 된다")
    }

    func test_snapshot_stopsAtLimit() {
        let (recorder, clock) = makeRecorder()

        for _ in 0..<LiveSmileSessionRecorder.maxSnapshots {
            recorder.observe(.notSmiling)
            XCTAssertTrue(recorder.claimSnapshotSlot())
            clock.date += 60
        }

        recorder.observe(.notSmiling)
        XCTAssertFalse(recorder.claimSnapshotSlot(), "상한을 넘으면 더 잡지 않는다")
    }

    /// 사진이 멈춰도 기록은 계속된다.
    func test_snapshot_limitDoesNotStopTimeline() {
        let (recorder, clock) = makeRecorder()

        for _ in 0..<LiveSmileSessionRecorder.maxSnapshots {
            recorder.observe(.notSmiling)
            _ = recorder.claimSnapshotSlot()
            clock.date += 60
        }
        recorder.observe(.smiling)

        XCTAssertGreaterThan(recorder.finish().totalSeconds, LiveSmileSessionRecorder.maxSnapshots)
    }
}
