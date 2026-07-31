# 실시간 확인 세션 그래프와 비율 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> 구현 전 대응 설계 `SmileDay/docs/superpowers/specs/2026-07-30-live-smile-session-graph-design.md`와 상위 설계 `SmileDay/docs/superpowers/specs/2026-07-29-live-smile-monitor-design.md`를 전체 읽는다.

> **2026-07-31 — 스냅샷은 철회됐다.** Task 4·6과 Task 7의 사진 관련 Step, Task 9의 수집 Step은
> 실행됐고 동작했지만 이후 전부 되돌렸다. 아래 본문은 그때 무엇을 왜 만들었는지의 기록으로 남긴다 —
> **지금 코드의 설명이 아니다.** 되돌린 이유는 `specs/2026-07-29-live-smile-monitor-design.md`의 6차 개정에 있다.
> 요약하면, 평소 잘 웃지 않는 사람에게 자기 얼굴 격자를 보여주면 스스로를 판정하게 되고 그건 이 앱의 전제와
> 부딪힌다. 남은 미체크 항목(Task 12)은 이 철회를 반영해 이미 줄여뒀다.

**Goal:** 실시간 확인을 끝냈을 때 그 세션의 타임라인 그래프와 미소 비율을 보여주고, 화면을 닫으면 전부 메모리에서 버린다. (당초 목표에 있던 "분당 1장 스냅샷"은 2026-07-31에 철회했다.)

**Architecture:** 초 단위 집계는 `CoachingKit`의 `LiveSmileSessionRecorder`가 순수 로직으로 담당한다. 프레임마다 `observe`를 받아 1초 칸을 다수결로 확정하고, 프레임이 끊긴 칸은 `unknown`으로 채운다.

**Tech Stack:** Swift 5.10, SwiftUI, ARKit, Observation, XCTest, iOS 17+.

---

### Task 0: 기준 결과 고정

**Files:**

- Read: `SmileDay/docs/superpowers/specs/2026-07-30-live-smile-session-graph-design.md`
- Read: `SmileDay/docs/superpowers/specs/2026-07-29-live-smile-monitor-design.md`
- Read: `AGENTS.md`

- [x] **Step 1: 작업 트리 상태를 기록한다**

이 저장소는 미커밋 변경이 많다. 내 변경과 남의 변경을 섞지 않기 위해 시작 시점을 남긴다.

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git status --short > /tmp/live-graph-baseline.txt
wc -l /tmp/live-graph-baseline.txt
```

- [x] **Step 2: 패키지 테스트 기준을 기록한다**

```bash
cd CoachingKit && swift test 2>&1 | grep -E "Executed [0-9]+ tests|Test Suite 'All tests'"
```

Expected: `Test Suite 'All tests' passed`. 테스트 수를 적어둔다 (이 계획 작성 시점 161개).

- [x] **Step 3: 앱 빌드 기준을 기록한다**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD"
```

Expected: `** BUILD SUCCEEDED **`

---

### Task 1: 관찰 상태와 요약 타입

> **구현 후 개정 (2026-07-30).** 코드 리뷰에서 `isLowConfidence: Bool`이 측정 0인 세션에서 `true`를 반환하는 문제가 나왔다 — 없는 숫자를 두고 신뢰도를 판정하는 셈이고, 타입만 보고 UI를 쓰면 "측정된 시간이 없어요"와 "이 숫자는 참고만 해주세요"가 함께 뜬다. `LiveSmileSessionConfidence`(`noMeasurement` / `low(ratio:)` / `reliable(ratio:)`)로 대체해 그 조합을 표현할 수 없게 했다. 아래 Step 3·5의 코드 블록은 최초 작성분이며, 실제 결과는 커밋 `89566a7`과 `3e5f5b5`를 본다. **Task 8은 개정된 API를 기준으로 쓰여 있다.**

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/LiveSmileSessionRecorder.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/LiveSmileSessionRecorderTests.swift`

- [x] **Step 1: 실패하는 테스트를 쓴다**

`CoachingKit/Tests/CoachingKitTests/LiveSmileSessionRecorderTests.swift`:

```swift
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
        XCTAssertEqual(result.unknownRatio, 0, "세션 길이가 0이어도 0으로 나누지 않는다")
    }

    func test_countsEachObservation() {
        let result = summary([.smiling, .smiling, .notSmiling, .unknown])

        XCTAssertEqual(result.totalSeconds, 4)
        XCTAssertEqual(result.smilingSeconds, 2)
        XCTAssertEqual(result.notSmilingSeconds, 1)
        XCTAssertEqual(result.unknownSeconds, 1)
        XCTAssertEqual(result.usableSeconds, 3)
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
}
```

- [x] **Step 2: 실패를 확인한다**

```bash
cd CoachingKit && swift test --filter LiveSmileSessionSummaryTests
```

Expected: 컴파일 실패 — `cannot find 'LiveSmileObservation' in scope`

- [x] **Step 3: 최소 구현을 쓴다**

`CoachingKit/Sources/CoachingKit/LiveSmileSessionRecorder.swift`:

```swift
import Foundation

/// 1초 칸 하나의 판정.
///
/// `unknown`은 "안 웃었다"가 아니라 "웃었는지 알 수 없다"다. 이 구분이 이 기능의 핵심이다 —
/// 얼굴이 안 보인 시간을 안 웃은 시간으로 적으면 자리를 비운 것이 나쁜 기록이 된다.
public enum LiveSmileObservation: Equatable, Sendable {
    case smiling
    case notSmiling
    case unknown
}

/// 한 세션의 집계. 타임라인 하나에서 전부 계산한다 — 카운터를 따로 들면 배열과 어긋날 수 있다.
public struct LiveSmileSessionSummary: Equatable, Sendable {
    /// 판정 가능 시간이 이보다 짧으면 낮은 신뢰로 본다.
    public static let lowConfidenceUsableSeconds = 60
    /// `unknown` 비율이 이보다 높으면 낮은 신뢰로 본다.
    public static let lowConfidenceUnknownRatio = 0.5

    public let timeline: [LiveSmileObservation]

    public init(timeline: [LiveSmileObservation]) {
        self.timeline = timeline
    }

    /// 요약 헤더에 쓰는 값. 그래프 가로축과 같다.
    public var totalSeconds: Int { timeline.count }
    public var smilingSeconds: Int { timeline.filter { $0 == .smiling }.count }
    public var notSmilingSeconds: Int { timeline.filter { $0 == .notSmiling }.count }
    public var unknownSeconds: Int { timeline.filter { $0 == .unknown }.count }
    public var usableSeconds: Int { smilingSeconds + notSmilingSeconds }

    /// 판정 가능 시간이 0이면 nil. 0으로 나누는 경로를 타입으로 막는다.
    public var smilingRatio: Double? {
        guard usableSeconds > 0 else { return nil }
        return Double(smilingSeconds) / Double(usableSeconds)
    }

    /// 분모에서 unknown을 뺐으므로 이 값을 화면에 항상 함께 보여준다.
    public var unknownRatio: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(unknownSeconds) / Double(totalSeconds)
    }

    public var isLowConfidence: Bool {
        usableSeconds < Self.lowConfidenceUsableSeconds
            || unknownRatio > Self.lowConfidenceUnknownRatio
    }
}
```

- [x] **Step 4: 통과를 확인한다**

```bash
cd CoachingKit && swift test --filter LiveSmileSessionSummaryTests
```

Expected: `Executed 4 tests, with 0 failures`

- [x] **Step 5: 낮은 신뢰 경계 테스트를 더한다**

`LiveSmileSessionSummaryTests`에 추가:

```swift
    func test_isLowConfidence_atUsableSecondsBoundary() {
        let justUnder = summary(Array(repeating: .smiling, count: 59))
        let atBoundary = summary(Array(repeating: .smiling, count: 60))

        XCTAssertTrue(justUnder.isLowConfidence, "59초는 짧다")
        XCTAssertFalse(atBoundary.isLowConfidence, "60초는 낮은 신뢰가 아니다")
    }

    func test_isLowConfidence_whenUnknownExceedsHalf() {
        // 판정 가능 60초 + unknown 61초 → unknown 비율 약 50.4%
        let tooMuchUnknown = summary(
            Array(repeating: .smiling, count: 60) + Array(repeating: .unknown, count: 61)
        )
        // 판정 가능 60초 + unknown 60초 → 정확히 50%, 초과가 아니다
        let exactlyHalf = summary(
            Array(repeating: .smiling, count: 60) + Array(repeating: .unknown, count: 60)
        )

        XCTAssertTrue(tooMuchUnknown.isLowConfidence)
        XCTAssertFalse(exactlyHalf.isLowConfidence, "초과일 때만 낮은 신뢰다")
    }
```

- [x] **Step 6: 통과를 확인한다**

```bash
cd CoachingKit && swift test --filter LiveSmileSessionSummaryTests
```

Expected: `Executed 6 tests, with 0 failures`

- [x] **Step 7: 커밋**

```bash
git add CoachingKit/Sources/CoachingKit/LiveSmileSessionRecorder.swift \
        CoachingKit/Tests/CoachingKitTests/LiveSmileSessionRecorderTests.swift
git commit -m "feat: add live smile session observation and summary types"
```

---

### Task 2: 1초 칸 다수결

> **구현 후 개정 (2026-07-30).** 아래 Step 1의 `test_bucket_isUnknown_whenNoFrameObserved`는 자기모순이었다 — `finish()`가 `now()`를 읽지 않으므로 `count == 6`과 `last == .unknown`이 동시에 성립할 수 없다. 전체 타임라인을 검증하는 형태로 교체했다.
>
> 그리고 `finish()`가 **마지막 프레임 이후 종료까지의 시간을 버리고 있었다.** 그 끝머리를 빼면 `unknownRatio`의 분모가 줄어 세션이 실제보다 믿을 만해 보인다. 지금은 종료 시점까지 `unknown`으로 채우고, `finish()`는 idempotent다. Step 3의 코드 블록은 최초 작성분이며 실제 결과는 커밋 `65e3e99`과 `b4ea36e`를 본다.
>
> 테스트 시계의 `[unowned self]`도 제거했다. 시계를 `_`로 버리는 테스트에서 즉시 해제되어 크래시한다.

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/LiveSmileSessionRecorder.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/LiveSmileSessionRecorderTests.swift`

- [x] **Step 1: 실패하는 테스트를 쓴다**

`LiveSmileSessionRecorderTests.swift`에 새 클래스를 추가한다:

```swift
final class LiveSmileSessionRecorderTests: XCTestCase {
    /// 테스트가 시간을 직접 옮긴다. 실제 시계에 의존하지 않는다.
    private final class TestClock {
        var date = Date(timeIntervalSince1970: 1_800_000_000)
        var now: () -> Date { { [unowned self] in self.date } }
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

    /// 프레임이 하나도 없는 칸은 모른다. 끊김 직후 종료하면 생긴다.
    func test_bucket_isUnknown_whenNoFrameObserved() {
        let (recorder, clock) = makeRecorder()

        recorder.observe(.smiling)
        clock.date += 5 // 4칸을 건너뛰고 5번째 칸으로 넘어간다
        recorder.observe(.smiling)
        clock.date += 1 // 6번째 칸에는 프레임이 오지 않은 채 종료한다

        let timeline = recorder.finish().timeline

        XCTAssertEqual(timeline.count, 6)
        XCTAssertEqual(timeline.last, .unknown, "프레임 없는 마지막 칸은 모른다")
    }
}
```

- [x] **Step 2: 실패를 확인한다**

```bash
cd CoachingKit && swift test --filter LiveSmileSessionRecorderTests
```

Expected: 컴파일 실패 — `cannot find 'LiveSmileSessionRecorder' in scope`

- [x] **Step 3: 최소 구현을 쓴다**

`LiveSmileSessionRecorder.swift` 파일 끝에 추가:

```swift
/// 프레임을 1초 칸으로 접는다.
///
/// 타이머를 쓰지 않는다. 프레임이 도착할 때 몇 번째 초 칸인지 계산하고, 건너뛴 칸은
/// `unknown`으로 채운다. 별도 처리 없이 "그 시간은 모른다"가 정확히 표현되고,
/// 주입한 `now()`로 전부 테스트된다.
public final class LiveSmileSessionRecorder {
    public static let bucketDuration: TimeInterval = 1

    private let now: () -> Date

    /// 확정된 칸들. 측정 중 그래프가 이 값을 그린다.
    public private(set) var timeline: [LiveSmileObservation] = []

    private var startedAt: Date?
    private var currentBucketIndex = 0
    private var observedFrames = 0
    private var usableFrames = 0
    private var smilingFrames = 0

    public init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    /// 프레임마다 부른다.
    public func observe(_ observation: LiveSmileObservation) {
        let timestamp = now()

        guard let startedAt else {
            self.startedAt = timestamp
            currentBucketIndex = 0
            count(observation)
            return
        }

        let index = Int(timestamp.timeIntervalSince(startedAt) / Self.bucketDuration)
        if index > currentBucketIndex {
            closeCurrentBucket()
            // 프레임이 오지 않은 칸은 모른다고 적는다.
            while timeline.count < index {
                timeline.append(.unknown)
            }
            currentBucketIndex = index
        }

        count(observation)
    }

    /// 마지막 부분 칸을 확정하고 집계한다.
    public func finish() -> LiveSmileSessionSummary {
        guard startedAt != nil else { return LiveSmileSessionSummary(timeline: []) }

        closeCurrentBucket()
        return LiveSmileSessionSummary(timeline: timeline)
    }

    private func count(_ observation: LiveSmileObservation) {
        observedFrames += 1
        if observation != .unknown { usableFrames += 1 }
        if observation == .smiling { smilingFrames += 1 }
    }

    private func closeCurrentBucket() {
        timeline.append(decideCurrentBucket())
        observedFrames = 0
        usableFrames = 0
        smilingFrames = 0
    }

    private func decideCurrentBucket() -> LiveSmileObservation {
        guard observedFrames > 0 else { return .unknown }
        // 절반 미만만 판정 가능하면 그 1초는 믿지 않는다.
        guard Double(usableFrames) >= Double(observedFrames) / 2 else { return .unknown }
        // 동수는 안 웃음으로 — 적게 세는 쪽으로 기운다.
        return smilingFrames * 2 > usableFrames ? .smiling : .notSmiling
    }
}
```

- [x] **Step 4: 통과를 확인한다**

```bash
cd CoachingKit && swift test --filter LiveSmileSessionRecorderTests
```

Expected: `Executed 7 tests, with 0 failures`

- [x] **Step 5: 커밋**

```bash
git add CoachingKit/Sources/CoachingKit/LiveSmileSessionRecorder.swift \
        CoachingKit/Tests/CoachingKitTests/LiveSmileSessionRecorderTests.swift
git commit -m "feat: fold live smile frames into one-second buckets by majority"
```

---

### Task 3: 끊긴 구간을 모른다고 채우기

**Files:**

- Modify: `CoachingKit/Tests/CoachingKitTests/LiveSmileSessionRecorderTests.swift`

구현은 Task 2에서 이미 들어갔다. 이 Task는 그 동작을 테스트로 고정한다 — 이 기능의 존재 이유가 여기다.

- [x] **Step 1: 테스트를 쓴다**

`LiveSmileSessionRecorderTests`에 추가:

```swift
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
```

- [x] **Step 2: 통과를 확인한다**

```bash
cd CoachingKit && swift test --filter LiveSmileSessionRecorderTests
```

Expected: `Executed 10 tests, with 0 failures`

- [x] **Step 3: 커밋**

```bash
git add CoachingKit/Tests/CoachingKitTests/LiveSmileSessionRecorderTests.swift
git commit -m "test: pin that interrupted seconds are recorded as unknown"
```

---

### Task 4: 스냅샷 슬롯

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/LiveSmileSessionRecorder.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/LiveSmileSessionRecorderTests.swift`

- [x] **Step 1: 실패하는 테스트를 쓴다**

`LiveSmileSessionRecorderTests`에 추가:

```swift
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
    func test_snapshot_skipsMinute_whenNoUsableFrameWithinGrace() {
        let (recorder, clock) = makeRecorder()

        recorder.observe(.unknown)
        clock.date += 6
        recorder.observe(.notSmiling)

        XCTAssertFalse(recorder.claimSnapshotSlot(), "5초를 넘겼으므로 이 분은 없다")

        clock.date += 54 // 60초 경계
        recorder.observe(.notSmiling)
        XCTAssertTrue(recorder.claimSnapshotSlot())
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
```

- [x] **Step 2: 실패를 확인한다**

```bash
cd CoachingKit && swift test --filter LiveSmileSessionRecorderTests
```

Expected: 컴파일 실패 — `value of type 'LiveSmileSessionRecorder' has no member 'claimSnapshotSlot'`

- [x] **Step 3: 구현을 더한다**

`LiveSmileSessionRecorder`에 상수와 상태를 추가한다. 기존 `public static let bucketDuration` 아래:

```swift
    /// 스냅샷 슬롯이 열리는 간격.
    public static let snapshotInterval: TimeInterval = 60
    /// 경계 후 이 시간 안에 쓸 프레임이 없으면 그 분은 건너뛴다.
    public static let snapshotGrace: TimeInterval = 5
    /// 메모리 상한. 넘으면 사진만 멈추고 타임라인은 계속 쌓는다.
    public static let maxSnapshots = 120
```

기존 `private var smilingFrames = 0` 아래:

```swift
    private var lastObservation: LiveSmileObservation?
    private var claimedSlot: Int?
    private var snapshotCount = 0
```

`count(_:)` 안에서 마지막 관찰을 기억한다. 기존 메서드를 이렇게 바꾼다:

```swift
    private func count(_ observation: LiveSmileObservation) {
        observedFrames += 1
        if observation != .unknown { usableFrames += 1 }
        if observation == .smiling { smilingFrames += 1 }
        lastObservation = observation
    }
```

그리고 `finish()` 아래에 추가:

```swift
    /// 지금 사진을 잡아야 하면 true. 분당 최대 한 번만 true를 낸다.
    ///
    /// 묻기와 표시하기를 두 단계로 나누지 않는다 — 표시를 잊으면 매 프레임 사진을 찍는다.
    public func claimSnapshotSlot() -> Bool {
        guard snapshotCount < Self.maxSnapshots else { return false }
        guard let startedAt else { return false }
        // 얼굴이 없거나 각도가 벗어난 프레임으로 남기면 얼굴 없는 사진이 된다.
        guard let lastObservation, lastObservation != .unknown else { return false }

        let elapsed = now().timeIntervalSince(startedAt)
        let slot = Int(elapsed / Self.snapshotInterval)
        guard slot != claimedSlot else { return false }

        // 경계에서 너무 멀어졌으면 이번 분은 포기한다.
        let sinceSlotStart = elapsed - Double(slot) * Self.snapshotInterval
        guard sinceSlotStart <= Self.snapshotGrace else { return false }

        claimedSlot = slot
        snapshotCount += 1
        return true
    }
```

- [x] **Step 4: 통과를 확인한다**

```bash
cd CoachingKit && swift test --filter LiveSmileSessionRecorderTests
```

Expected: `Executed 16 tests, with 0 failures`

- [x] **Step 5: 커밋**

```bash
git add CoachingKit/Sources/CoachingKit/LiveSmileSessionRecorder.swift \
        CoachingKit/Tests/CoachingKitTests/LiveSmileSessionRecorderTests.swift
git commit -m "feat: open one live smile snapshot slot per minute"
```

---

### Task 5: ViewModel에 recorder를 연결

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/LiveSmileMonitorViewModel.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/LiveSmileMonitorViewModelTests.swift`

- [x] **Step 1: 실패하는 테스트를 쓴다**

`LiveSmileMonitorViewModelTests`의 마지막 `}` 앞에 추가:

```swift
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

        XCTAssertLessThanOrEqual(viewModel.timeline.count, 3, "이전 세션 칸이 남으면 안 된다")
    }
```

- [x] **Step 2: 실패를 확인한다**

```bash
cd CoachingKit && swift test --filter LiveSmileMonitorViewModelTests
```

Expected: 컴파일 실패 — `value of type 'LiveSmileMonitorViewModel' has no member 'timeline'`

- [x] **Step 3: 관찰 상태를 만드는 코드를 더한다**

`LiveSmileMonitorViewModel.swift`에서 관찰 프로퍼티 아래(`public private(set) var nudgeCount = 0` 다음)에 추가:

```swift
    /// 측정 중 그래프가 그리는 타임라인. 확정된 1초 칸만 들어 있다.
    public private(set) var timeline: [LiveSmileObservation] = []
    /// 사진을 집어야 할 때마다 오른다. 화면이 이 변화를 보고 이미지를 만든다.
    ///
    /// 판정은 프레임 경로에서 끝났으므로, 화면이 한 박자 뒤에 캡처해도 방금 쓸 만한
    /// 프레임이 있었다는 사실은 이미 확정돼 있다.
    public private(set) var snapshotRequestCount = 0
```

저장 프로퍼티 영역(`private var lastMonitoringFrameAt: Date?` 아래)에 추가:

```swift
    /// 세션마다 새로 만든다. 이전 세션 기록이 섞이면 안 된다.
    private var recorder: LiveSmileSessionRecorder
```

`init`에서 초기화한다. 기존 `self.now = now` 아래에 추가:

```swift
        self.recorder = LiveSmileSessionRecorder(now: now)
```

`start()`에서 새 recorder를 만든다. 기존 `resetMeasurement()` 호출 바로 위에 추가:

```swift
        recorder = LiveSmileSessionRecorder(now: now)
```

- [x] **Step 4: 프레임마다 recorder에 넘긴다**

`reportQualityIssue(_:)` 맨 앞에 한 줄 추가한다. 품질 문제 프레임은 모른다고 적는다:

```swift
    private func reportQualityIssue(_ issue: LiveSmileQualityIssue) {
        record(.unknown)
        state = .qualityIssue(issue)
```

`calibrate(with:)`의 `state = .calibrating` 아래에 추가한다. 보정 중에는 단계를 모른다:

```swift
    private func calibrate(with sample: LiveSmileSample) {
        state = .calibrating
        record(.unknown)
        calibrationSamples.append(LiveSmileSignalEvaluator.smileMean(sample))
```

`publish(signal:)`에서 이 프레임의 단계를 계산해 넘긴다. 기존 `smoothedSignal = smoothed` 아래에 추가:

```swift
        // 이 프레임의 단계로 기록한다. 화면에 게시하는 level은 초당 10회로 제한되지만
        // 기록은 제한하지 않는다 — 그건 UI 갱신 제한이지 측정 제한이 아니다.
        let frameLevel = Self.nextLevel(signal: smoothed, current: level)
        record(frameLevel == .resting ? .notSmiling : .smiling)
```

`accumulateRestingTime()` 아래에 헬퍼를 추가:

```swift
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
```

- [x] **Step 5: 세션을 끝내는 메서드를 더한다**

`recalibrate()` 아래에 추가:

```swift
    /// 측정을 끝내고 요약을 낸다. 세션은 멈추지만 요약은 호출자가 들고 있다.
    ///
    /// 저장하지 않는다. 호출자가 화면을 닫으면 그대로 사라진다.
    public func finishSession() -> LiveSmileSessionSummary {
        let summary = recorder.finish()
        stop()
        return summary
    }
```

`resetMeasurement()`에 타임라인 비우기를 더한다. 기존 `lastMonitoringFrameAt = nil` 아래:

```swift
        timeline = []
```

- [x] **Step 6: 통과를 확인한다**

```bash
cd CoachingKit && swift test --filter LiveSmileMonitorViewModelTests
```

Expected: `Executed 38 tests, with 0 failures`

- [x] **Step 7: 패키지 전체 테스트**

```bash
cd CoachingKit && swift test 2>&1 | grep -E "error:|Executed [0-9]+ tests|Test Suite 'All tests'" | tail -3
```

Expected: `Test Suite 'All tests' passed`

- [x] **Step 8: 커밋**

```bash
git add CoachingKit/Sources/CoachingKit/LiveSmileMonitorViewModel.swift \
        CoachingKit/Tests/CoachingKitTests/LiveSmileMonitorViewModelTests.swift
git commit -m "feat: record live smile seconds while monitoring"
```

---

### Task 6: 스냅샷 이미지 만들기

**Files:**

- Modify: `SmileDay/Services/ARKitLiveSmileMonitor.swift`

패키지는 UIKit을 import하지 않으므로 이미지는 앱 타깃이 만든다. 테스트가 없어 빌드로만 검증한다.

- [x] **Step 1: import를 더한다**

파일 맨 위 `import simd` 아래에 추가:

```swift
import CoreImage
import UIKit
```

- [x] **Step 2: 재사용할 CIContext를 둔다**

`private var latestCameraTransform: simd_float4x4?` 아래에 추가:

```swift
    /// 매 호출마다 만들면 비싸다. 분당 1회라도 하나만 두고 재사용한다.
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
```

- [x] **Step 3: 축소 이미지를 내는 메서드를 더한다**

`previewSession` 프로퍼티 아래에 추가:

```swift
    /// 지금 프레임을 축소한 이미지.
    ///
    /// 저장 경로가 없다 — 호출자가 메모리에 들고 있다가 버린다. `AVCapturePhotoOutput`으로
    /// 촬영하는 것이 아니라 이미 돌고 있는 세션의 프레임을 읽으므로 셔터음이 나지 않는다.
    func snapshotImage(height: CGFloat = 320) -> UIImage? {
        guard isActive, let frame = session.currentFrame else { return nil }

        // 전면 카메라 버퍼는 가로 방향으로 들어온다. 세로 화면에 맞게 돌린다.
        let image = CIImage(cvPixelBuffer: frame.capturedImage).oriented(.right)
        let scale = height / image.extent.height
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = ciContext.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
```

설계 문서는 크기를 `240×320`으로 적었다. 여기서는 **높이만 320으로 맞추고 너비는 비율에 맡긴다** — ARKit 버퍼의 종횡비가 기기마다 다르므로 너비를 고정하면 얼굴이 늘어난다. 4:3 버퍼에서는 정확히 240이 되고, 16:9에서는 더 좁아진다. 메모리 추정(장당 약 25KB)은 어느 쪽이든 상한 안이다.

- [x] **Step 4: 빌드를 확인한다**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD"
```

Expected: `** BUILD SUCCEEDED **`

- [x] **Step 5: 프리뷰 경로가 늘지 않았는지 확인한다**

```bash
rg -n 'AVCapturePhotoOutput|UIImageWriteToSavedPhotosAlbum|PHPhotoLibrary|FileManager' \
  SmileDay/Services/ARKitLiveSmileMonitor.swift | grep -v '///'
```

Expected: 결과 없음 — 촬영·저장 경로가 없다.

`grep -v '///'`가 필요하다. Step 3의 문서 주석이 "`AVCapturePhotoOutput`으로 촬영하는 것이 아니다"라고 설명하며 그 이름을 그대로 담고 있어서, 걸러내지 않으면 프라이버시 검사가 자기 주석에 걸려 절대 비지 않는다.

- [x] **Step 6: 커밋**

```bash
git add SmileDay/Services/ARKitLiveSmileMonitor.swift
git commit -m "feat: expose a downscaled frame image for live smile snapshots"
```

---

### Task 7: 문구 추가와 거짓이 된 문구 수정

**Files:**

- Modify: `SmileDay/Views/SharedStrings.swift`
- Modify: `SmileDay/Views/Settings/SmileMVPSettingsView.swift:235`

- [x] **Step 1: 설정 화면의 거짓 문구를 고친다**

`SmileMVPSettingsView.swift` 235번째 줄을 바꾼다.

이전:

```swift
            Text("완료한 시각만 저장해요. 사진과 영상은 찍지도, 저장하지도 않아요.")
```

이후:

```swift
            Text("완료한 시각만 저장해요. 실시간 확인 중 집는 사진은 화면을 닫으면 사라지고, 저장하거나 전송하지 않아요.")
```

- [x] **Step 2: 시작 전 안내에 사진 항목을 더한다**

`SharedStrings.swift`의 `liveMonitorIntroPoints`를 바꾼다.

이전:

```swift
    static let liveMonitorIntroPoints = [
        "전면 카메라가 켜지고, iOS 초록색 표시가 나타나요.",
        "카메라 화면은 기본으로 꺼져 있고, 버튼으로 켜고 끌 수 있어요.",
        "화면을 켜든 끄든 사진·영상·측정값을 저장하지 않아요.",
        "화면을 켜두는 동안 배터리가 평소보다 빨리 줄어요.",
    ]
```

이후:

```swift
    static let liveMonitorIntroPoints = [
        "전면 카메라가 켜지고, iOS 초록색 표시가 나타나요.",
        "카메라 화면은 기본으로 꺼져 있고, 버튼으로 켜고 끌 수 있어요.",
        "끝나면 그동안의 그래프와 1분당 1장의 사진을 보여드려요.",
        "그래프와 사진은 화면을 닫으면 사라져요. 저장하거나 전송하지 않아요.",
        "화면을 켜두는 동안 배터리가 평소보다 빨리 줄어요.",
    ]
```

- [x] **Step 3: 요약 화면 문구를 더한다**

`SharedStrings.swift`의 `liveMonitorNudgeFooter` 아래, `enum`의 마지막 `}` 앞에 추가:

```swift

    // MARK: - 실시간 확인 세션 요약

    static let liveSummaryTitle = "이번 실시간 확인"
    static let liveSummaryRatioLabel = "카메라가 본 동안 미소"
    static let liveSummaryLegendSmiling = "미소"
    static let liveSummaryLegendNotSmiling = "안 웃음"
    static let liveSummaryLegendUnknown = "알 수 없음"
    static let liveSummaryCloseAction = "닫기"
    /// 분모에서 알 수 없음을 뺐으므로 그 비율을 항상 함께 보여준다.
    static let liveSummaryLowConfidence = "인식된 시간이 짧아 이 숫자는 참고만 해주세요."
    static let liveSummaryNoMeasurement = "측정된 시간이 없어요."
    /// 숫자를 값 판단으로 읽지 않도록 함께 둔다.
    static let liveSummaryMeaning = "이 비율은 웃음의 좋고 나쁨이 아니라, 카메라가 입꼬리 움직임을 감지한 시간의 비율이에요."
```

- [x] **Step 4: 빌드를 확인한다**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD"
```

Expected: `** BUILD SUCCEEDED **`

- [x] **Step 5: 남은 거짓 문구가 없는지 확인한다**

```bash
rg -n '찍지도' SmileDay CoachingKit --glob '*.swift'
```

Expected: 결과 없음.

- [x] **Step 6: 커밋**

```bash
git add SmileDay/Views/SharedStrings.swift SmileDay/Views/Settings/SmileMVPSettingsView.swift
git commit -m "docs: say that live mode takes snapshots without keeping them"
```

---

### Task 8: 요약 화면

**Files:**

- Create: `SmileDay/Views/Coaching/LiveSmileSessionSummaryView.swift`

- [x] **Step 1: 화면을 만든다**

```swift
import SwiftUI
import CoachingKit

/// 실시간 확인이 끝난 뒤 그 세션을 보여주는 화면.
///
/// 저장하지 않는다. 이 화면을 닫으면 타임라인과 사진이 그대로 사라진다.
/// 사진에 미소 여부 색을 칠하지 않는다 — 한 장마다 판정을 붙이면 "안 웃은 나"의 격자가 된다.
struct LiveSmileSessionSummaryView: View {
    let summary: LiveSmileSessionSummary
    let snapshots: [UIImage]
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header

                switch summary.confidence {
                case .noMeasurement:
                    Text(SharedStrings.liveSummaryNoMeasurement)
                        .font(.headline)
                        .foregroundStyle(SDColor.ink)
                case .low(let value):
                    ratio(value, isLowConfidence: true)
                case .reliable(let value):
                    ratio(value, isLowConfidence: false)
                }

                timelineBand

                if !snapshots.isEmpty {
                    snapshotStrip
                }

                Text(SharedStrings.liveSummaryMeaning)
                    .font(.caption)
                    .foregroundStyle(SDColor.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button(SharedStrings.liveSummaryCloseAction, action: onClose)
                    .buttonStyle(SDPrimaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(SDColor.cream)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(SharedStrings.liveSummaryTitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SDColor.muted)

            // 헤드라인은 측정한 시간이다. 그래프 가로축과 같은 값이어야 한다.
            Text(durationText(summary.totalSeconds))
                .font(.title2.bold())
                .foregroundStyle(SDColor.ink)
        }
    }

    /// `unknownRatio`는 분모가 달라서(전체 시간) 미소 비율과 한 막대에 쌓지 않는다.
    /// 두 줄로 따로 둔다.
    private func ratio(_ value: Double, isLowConfidence: Bool) -> some View {
        VStack(spacing: 6) {
            Text("\(Int((value * 100).rounded()))%")
                .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(SDColor.ink)

            Text(SharedStrings.liveSummaryRatioLabel)
                .font(.footnote)
                .foregroundStyle(SDColor.muted)

            Text("\(SharedStrings.liveSummaryLegendUnknown) \(Int((summary.unknownRatio * 100).rounded()))%")
                .font(.caption)
                .foregroundStyle(SDColor.muted)

            if isLowConfidence {
                Text(SharedStrings.liveSummaryLowConfidence)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SDColor.alert)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var timelineBand: some View {
        VStack(spacing: 8) {
            LiveSmileTimelineBand(timeline: summary.timeline)
                .frame(height: 34)

            HStack(spacing: 14) {
                legend(SharedStrings.liveSummaryLegendSmiling, SDColor.coral)
                legend(SharedStrings.liveSummaryLegendNotSmiling, SDColor.shell)
                legend(SharedStrings.liveSummaryLegendUnknown, SDColor.muted.opacity(0.35))
            }
            .font(.caption2)
            .foregroundStyle(SDColor.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SharedStrings.liveSummaryTitle)
    }

    private func legend(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }

    private var snapshotStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 사진에 판정을 붙이지 않는다. 개수만 알려준다.
            Text("1분마다 \(snapshots.count)장")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SDColor.muted)

            LazyVGrid(columns: Array(repeating: GridItem(spacing: 4), count: 5), spacing: 4) {
                ForEach(Array(snapshots.enumerated()), id: \.offset) { _, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 74)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        guard minutes > 0 else { return "\(remainder)초" }
        return remainder == 0 ? "\(minutes)분" : "\(minutes)분 \(remainder)초"
    }
}

/// 1초 칸을 이어 그린 띠. 측정 중과 요약이 같은 그림을 쓴다.
struct LiveSmileTimelineBand: View {
    let timeline: [LiveSmileObservation]

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                ForEach(Array(timeline.enumerated()), id: \.offset) { _, observation in
                    Rectangle().fill(color(observation))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(SDColor.shell.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func color(_ observation: LiveSmileObservation) -> Color {
        switch observation {
        case .smiling: SDColor.coral
        case .notSmiling: SDColor.shell
        case .unknown: SDColor.muted.opacity(0.35)
        }
    }
}
```

- [x] **Step 2: 빌드를 확인한다**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD"
```

Expected: `** BUILD SUCCEEDED **`

- [x] **Step 3: 커밋**

```bash
git add SmileDay/Views/Coaching/LiveSmileSessionSummaryView.swift
git commit -m "feat: add live smile session summary screen"
```

---

### Task 9: 모니터 화면에 붙이기

**Files:**

- Modify: `SmileDay/Views/Coaching/LiveSmileMonitorView.swift`

- [x] **Step 1: 상태를 더한다**

`@State private var previousIdleTimerDisabled = false` 아래에 추가:

```swift
    /// 종료를 누른 뒤 보여줄 요약. 화면을 닫으면 사라진다.
    @State private var summary: LiveSmileSessionSummary?
    /// 분당 1장. 저장 경로가 없고 이 배열이 사라지면 사진도 사라진다.
    @State private var snapshots: [UIImage] = []
```

- [x] **Step 2: 요약 분기를 가장 앞에 둔다**

`content(_:)`의 분기를 바꾼다.

이전:

```swift
            if case .failed(let failure) = viewModel.state {
                failureSection(failure)
            } else if !hasStarted {
```

이후:

```swift
            if let summary {
                LiveSmileSessionSummaryView(
                    summary: summary,
                    snapshots: snapshots,
                    onClose: {
                        releaseSession()
                        dismiss()
                    }
                )
            } else if case .failed(let failure) = viewModel.state {
                failureSection(failure)
            } else if !hasStarted {
```

- [x] **Step 3: 종료 버튼이 요약을 띄우게 한다**

`measuringSection(_:)` 안의 종료 버튼을 바꾼다.

이전:

```swift
                Button(SharedStrings.liveMonitorCloseAction) {
                    shutDown()
                    dismiss()
                }
                .buttonStyle(SDPrimaryButtonStyle())
```

이후:

```swift
                Button(SharedStrings.liveMonitorCloseAction) {
                    finishAndShowSummary(viewModel)
                }
                .buttonStyle(SDPrimaryButtonStyle())
```

- [x] **Step 4: 좌상단 닫기도 측정한 게 있으면 요약을 거치게 한다**

`header`를 바꾼다. 측정한 것을 말없이 버리지 않는다.

이전:

```swift
    private var header: some View {
        HStack {
            SDCloseButton {
                shutDown()
                dismiss()
            }
            Spacer()
        }
```

이후:

```swift
    private var header: some View {
        HStack {
            SDCloseButton {
                // 측정한 게 있으면 말없이 버리지 않고 요약을 먼저 보여준다.
                if let viewModel, hasStarted, summary == nil, !viewModel.timeline.isEmpty {
                    finishAndShowSummary(viewModel)
                } else {
                    releaseSession()
                    dismiss()
                }
            }
            Spacer()
        }
```

- [x] **Step 5: 측정 중 띠를 더한다**

`measuringSection(_:)`의 `levelMeter(viewModel.level)` 바로 아래에 추가. 경과 시간은 넣지 않는다 — 설계 §7에서 측정 화면을 조용하게 두기로 했다:

```swift
            if !viewModel.timeline.isEmpty {
                LiveSmileTimelineBand(timeline: viewModel.timeline)
                    .frame(height: 12)
                    .accessibilityHidden(true)
            }
```

- [x] **Step 6: 스냅샷을 모은다**

`measuringSection(_:)`의 `.onChange(of: viewModel.nudgeCount)` 아래에 추가:

```swift
        .onChange(of: viewModel.snapshotRequestCount) { _, count in
            guard count > 0 else { return }
            captureSnapshot()
        }
```

슬롯 판정을 `timeline.count` 변화에 걸지 않는다. 그건 초당 한 번, 프레임과 분리돼 돌아가므로 얼굴이 사라진 뒤에도 낡은 관찰로 슬롯이 열린다. 판정은 ViewModel의 프레임 경로에서 끝내고, 여기서는 이미 확보된 슬롯에 대해 이미지만 만든다.

`snapshotRequestCount`는 **ViewModel 수명 전체의 누적값이고 세션마다 초기화되지 않는다.** 일부러 그렇게 뒀다 — `start()`에서 0으로 되돌리면 그 N→0 변화 자체가 `.onChange`를 깨워서, 프레임이 아직 한 장도 안 온 시점에 캡처가 돈다. 따라서 이 값은 **변화 신호로만** 쓴다. 화면에 "N장 찍었어요"로 쓰거나 개수 계산에 넣으면 안 된다 — 장수는 `snapshots.count`를 쓴다.

그리고 `timeline`에는 **진행 중인 초가 들어 있지 않다.** 확정된 칸만 노출하므로 띠는 실제보다 최대 1초 뒤처지고, 마지막 부분 초는 `finishSession()`의 요약에만 나타난다. 띠 끝이 비어 보이는 것은 버그가 아니다.

- [x] **Step 7: 생명주기 메서드를 더한다**

`shutDown()` 위에 추가:

```swift
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
        snapshots = []
    }

    /// 슬롯은 ViewModel이 프레임 경로에서 이미 확보했다. 여기서는 이미지만 만든다.
    private func captureSnapshot() {
        guard let monitor, summary == nil else { return }
        guard let image = monitor.snapshotImage() else { return }
        snapshots.append(image)
    }
```

- [x] **Step 8: shutDown이 사진도 비우게 한다**

`shutDown()`의 `isShowingNudgeCue = false` 아래에 추가:

```swift
        snapshots = []
```

- [x] **Step 8b: 재시작이 새 세션이 되게 한다**

백그라운드로 나가면 `pauseForSceneChange()`가 세션만 멈추고 사진은 남긴다. 그 상태에서 재시작하면 `viewModel.start()`가 새 recorder를 만들지만 **이전 세션 사진이 그대로 이어져** 새 세션 사진에 섞인다.

`startMeasuring()`의 `hasStarted = true` 아래에 추가:

```swift
        // start()가 새 recorder를 만든다. 이전 세션 사진이 섞이지 않게 함께 버린다.
        snapshots = []
        summary = nil
```

- [x] **Step 9: 빌드를 확인한다**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD"
```

Expected: `** BUILD SUCCEEDED **`

- [x] **Step 10: 패키지 테스트를 확인한다**

```bash
cd CoachingKit && swift test 2>&1 | grep -E "error:|Executed [0-9]+ tests|Test Suite 'All tests'" | tail -3
```

Expected: `Test Suite 'All tests' passed`

- [x] **Step 11: 커밋**

```bash
git add SmileDay/Views/Coaching/LiveSmileMonitorView.swift \
        CoachingKit/Sources/CoachingKit/LiveSmileMonitorViewModel.swift
git commit -m "feat: show the session summary when live smile check ends"
```

---

### Task 10: 문서와 지침 개정

**Files:**

- Modify: `SmileDay/docs/superpowers/specs/2026-07-29-live-smile-monitor-design.md`
- Modify: `AGENTS.md`
- Modify: `SmileDay/Views/Coaching/AGENTS.md`
- Modify: `CoachingKit/Sources/CoachingKit/AGENTS.md`
- Modify: `CoachingKit/Tests/CoachingKitTests/AGENTS.md`
- Modify: `CLAUDE.md`
- Modify: `CLAUDE.ko.md`

- [x] **Step 1: 상위 설계에 5차 개정 이력을 더한다**

`2026-07-29-live-smile-monitor-design.md`의 `## 0. 개정 이력` 바로 아래에 추가:

```markdown
### 2026-07-30 개정 (5차) — 세션 그래프와 비율, 분당 스냅샷

세션이 끝나면 아무것도 남지 않던 문제를 고친다. 자세한 설계는 `2026-07-30-live-smile-session-graph-design.md`에 있고, 여기서는 이 문서의 조항 변경만 적는다.

**약속의 경계가 또 한 겹 갈린다.** 2차 개정에서 "표시하지 않는다"와 "저장하지 않는다"를 분리했고, 이번에는 **"집지 않는다"와 "저장하지 않는다"를 분리한다.**

| 약속 | 이전 | 이후 |
|---|---|---|
| 카메라 영상 표시 | 기본 꺼짐, 토글로 켬 | 변경 없음 |
| 사진을 집는 것 | 하지 않음 | **분당 1장, 세션 한정** |
| 저장·전송 | 하지 않음 | 하지 않음 (변경 없음) |

절대 조항으로 남는 것은 저장·전송 금지뿐이다.
```

- [x] **Step 2: §8의 capturedImage 조항을 고친다**

이전:

```markdown
- 프리뷰는 이미 돌고 있는 세션을 `ARSCNView`로 그리기만 한다. `ARFrame.capturedImage`를 직접 읽어 변환하거나 가공하지 않는다.
```

이후:

```markdown
- 프리뷰는 이미 돌고 있는 세션을 `ARSCNView`로 그리기만 한다.
- `ARFrame.capturedImage`는 **분당 1회 스냅샷을 축소 변환할 때만** 읽는다. 프레임마다 변환하거나 영상으로 잇지 않는다.
```

- [x] **Step 3: §13 범위 제외를 고친다**

이전:

```markdown
- 사진·영상 촬영과 저장
```

이후:

```markdown
- 영상 촬영, 사진·영상 저장, 내보내기·공유
- 고정 창(1분/5분/10분/1시간), 발생 횟수, 날짜별 비교
```

- [x] **Step 4: 루트 AGENTS.md의 절대 조항을 좁힌다**

`AGENTS.md`의 "Optional Live Mode Guardrails"에서 바꾼다.

이전:

```markdown
- **No photo or video capture, and no persistence of frames, blend shapes, or levels — whether or not the camera view is showing.** Nothing from this mode reaches SwiftData or UserDefaults, and nothing is transmitted. Keep "we don't display it" and "we don't store it" separate in copy; only the second is still an absolute.
```

이후:

```markdown
- **Nothing from this mode is persisted or transmitted** — no frames, blend shapes, levels, timelines, or snapshots reach SwiftData, UserDefaults, the filesystem, or the network. This is the one absolute.
- Snapshots are allowed under conditions: one per minute, held in memory for the session only, released when the summary closes, with no capture button, export, or share path. No video capture at all.
- Three claims are now separate in copy — "we don't display it", "we don't take it", "we don't keep it". Only the last is absolute. Do not merge them back into one sentence.
```

- [x] **Step 5: Coaching AGENTS.md를 고친다**

`SmileDay/Views/Coaching/AGENTS.md`에서 바꾼다.

이전:

```markdown
- Build the preview only while the toggle is on, so turning it off costs nothing. Draw the running session with `ARSCNView`; never hand-convert `ARFrame.capturedImage`, and never add a capture/save button.
```

이후:

```markdown
- Build the preview only while the toggle is on, so turning it off costs nothing. Draw the running session with `ARSCNView`.
- `ARFrame.capturedImage` is converted only for the once-a-minute snapshot, via `ARKitLiveSmileMonitor.snapshotImage()`. Never convert per frame, and never add a capture, save, export, or share button.
- The summary screen owns the snapshot array. Closing it must clear both the array and the summary — that is the only thing standing between "session only" and "stored".
```

- [x] **Step 6: 패키지 AGENTS.md에 새 타입을 더한다**

`CoachingKit/Sources/CoachingKit/AGENTS.md`의 "Live mode logic" 표에 행을 더한다:

```markdown
| `LiveSmileSessionRecorder.swift` | `LiveSmileObservation` 3-state, one-second buckets decided by majority vote, unknown-filled gaps, snapshot slots, and `LiveSmileSessionSummary` (ratio over usable time only) |
```

그리고 "Working In This Directory" 목록에 추가:

```markdown
- `LiveSmileSessionRecorder` sums nothing to disk and holds no images — CoachingKit imports no UIKit. The app target owns the snapshot array; the recorder only says when a slot is open.
- The ratio denominator is usable time, not total time. Changing it to total time would report time away from the camera as time not smiling.
```

- [x] **Step 7: 테스트 AGENTS.md에 행을 더한다**

`CoachingKit/Tests/CoachingKitTests/AGENTS.md`의 표에 추가:

```markdown
| `LiveSmileSessionRecorderTests` | Bucket majority (including the exactly-half and tie boundaries), gaps filled with unknown, ratio excluding unknown, empty-session divide-by-zero guards, snapshot slots (one per minute, skipped when no usable frame, stops at the limit without stopping the timeline) |
```

- [x] **Step 8: CLAUDE.md와 CLAUDE.ko.md를 고친다**

`CLAUDE.md`에서 바꾼다.

이전:

```markdown
- Nothing is persisted or transmitted — no photos, video, blend shapes, levels, or session times reach SwiftData or UserDefaults, whether the camera view is showing or not. There is no capture button.
```

이후:

```markdown
- It takes one snapshot per minute and shows a session timeline and smiling ratio when it ends. All of it is memory-only and released when the summary closes.
- Nothing is persisted or transmitted — no photos, video, blend shapes, levels, timelines, or session times reach SwiftData, UserDefaults, the filesystem, or the network. There is no capture, export, or share path.
```

`CLAUDE.ko.md`에서 바꾼다.

이전:

```markdown
- 저장도 전송도 하지 않습니다 — 화면 표시 여부와 무관하게 사진·영상·blend shape·단계·측정 시간이 SwiftData나 UserDefaults에 들어가지 않습니다. 촬영 버튼도 없습니다.
```

이후:

```markdown
- 1분에 1장 사진을 집고, 끝나면 세션 타임라인과 미소 비율을 보여줍니다. 전부 메모리에만 있고 요약 화면을 닫으면 사라집니다.
- 저장도 전송도 하지 않습니다 — 사진·영상·blend shape·단계·타임라인·측정 시간이 SwiftData·UserDefaults·파일 시스템·네트워크로 나가지 않습니다. 촬영·내보내기·공유 경로가 없습니다.
```

- [x] **Step 9: 커밋**

```bash
git add SmileDay/docs/superpowers/specs/2026-07-29-live-smile-monitor-design.md \
        AGENTS.md SmileDay/Views/Coaching/AGENTS.md \
        CoachingKit/Sources/CoachingKit/AGENTS.md \
        CoachingKit/Tests/CoachingKitTests/AGENTS.md \
        CLAUDE.md CLAUDE.ko.md
git commit -m "docs: narrow the live mode absolute to storage and transmission"
```

---

### Task 11: 전체 검증

- [x] **Step 1: 패키지 전체 테스트**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit
swift test 2>&1 | grep -E "error:|XCTAssert|Executed [0-9]+ tests|Test Suite 'All tests'" | tail -4
```

Expected: `Test Suite 'All tests' passed`, 실패 0.

Task 0 기준(170개)에서 최소 33개가 늘어야 한다 — 요약 8, recorder 19, ViewModel 6. 정확한 수를 게이트로 쓰지 않는다. 리뷰에서 놓친 경계가 나오면 테스트가 더 붙기 때문이다. 실제로 Task 1은 6→8, Task 2는 7→10으로 늘었다. **줄어들었다면** 테스트가 사라진 것이므로 그때는 멈추고 확인한다.

- [x] **Step 2: iOS 17 앱 빌드**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD"
```

Expected: `** BUILD SUCCEEDED **`

- [x] **Step 3: 저장 경로가 생기지 않았는지 확인한다**

이 기능의 핵심 약속이다.

```bash
rg -n 'PHPhotoLibrary|UIImageWriteToSavedPhotosAlbum|AVCapturePhotoOutput|write\(to:|URLSession' \
  SmileDay/Views/Coaching SmileDay/Services CoachingKit/Sources/CoachingKit --glob '*.swift' \
  | grep -v '///'

rg -n 'UIImage|Data\(' CoachingKit/Sources/CoachingKit --glob '*.swift'
```

Expected: 두 검색 모두 결과 없음 — 저장·전송 경로가 없고, 패키지는 이미지를 들지 않는다.

`SmileDay/Services`가 검색 대상에 들어가야 한다. 카메라를 만지는 유일한 파일이 거기 있으므로, 빼면 저장 경로가 생겨도 이 검사가 못 잡는다. `grep -v '///'`는 문서 주석이 API 이름을 언급하는 것을 걸러낸다.

- [x] **Step 4: 측정값이 스키마에 들어가지 않았는지 확인한다**

```bash
rg -n 'LiveSmile' CoachingKit/Sources/CoachingKit/PersistenceSchema.swift || echo "(스키마에 없음 — 정상)"
rg -n 'liveSmile|liveSummary' CoachingKit/Sources/CoachingKit/LiveSmileSessionRecorder.swift | grep -i 'userdefaults' || echo "(UserDefaults 사용 없음 — 정상)"
```

Expected: 둘 다 "정상" 출력.

- [x] **Step 5: 금지 표현을 검사한다**

```bash
rg -n '리프팅|젊어진다|교정한다|치료|잘 웃|못 웃|예뻐' SmileDay CoachingKit --glob '*.swift'
```

Expected: `SmileCueTests`의 금지어 목록과 온보딩의 "평소 잘 웃지 않는" 외에는 없다.

- [x] **Step 6: diff 검증**

```bash
git diff --check
git status --short
```

Expected: `git diff --check` 결과 없음.

---

### Task 12: TrueDepth 실기기 QA

**Required:** iOS 17 이상, Face ID/TrueDepth 지원 iPhone. 시뮬레이터는 얼굴 추적이 돌지 않아 이 Task를 대신할 수 없다.

> 2026-07-31 스냅샷 철회로 사진 관련 항목 8개가 사라졌다 — 사진 내용·방향·장수·실제 JPEG 크기·셔터음·메모리 3MB 예산. 코드를 바꿀 수 있었던 QA 항목 두 개(좌우반전 방향, 실제 사진 크기)가 여기 있었으므로, 남은 항목은 전부 확인용이다.

- [ ] 측정 중 띠가 1초에 한 칸씩 오른쪽으로 자란다
- [ ] 종료를 누르면 요약이 나오고, 헤더의 측정 시간이 띠 길이와 맞는다
- [ ] 얼굴을 30초 가리면 그 구간이 띠에서 `알 수 없음`으로 보인다
- [ ] 그 30초가 비율을 떨어뜨리지 않는다 — 분모에서 빠진다
- [ ] 인식이 나쁜 세션에서 낮은 신뢰 안내가 나온다
- [ ] 보정만 하고 종료하면 "측정된 시간이 없어요"가 나온다
- [ ] 요약을 닫고 다시 들어가면 이전 세션의 띠가 없다
- [ ] 앱을 종료·재실행해도 측정 기록이 없다
- [ ] 좌상단 X를 눌렀을 때도 측정한 게 있으면 요약을 거친다
- [ ] 30분 측정 시 발열이 견딜 수준이다 (이미지를 들지 않으므로 메모리는 타임라인뿐이다 — 1시간 세션의 `[LiveSmileObservation]` 3,600개는 수십 KB 수준이다)
- [ ] 측정 중 백그라운드로 나갔다 복귀하면(재실행이 아니라 같은 세션으로 돌아오는 경우) 새 세션이 아니라 그때까지 측정된 것의 요약이 나온다. 측정을 시작하기 전에 나갔다 오면(기록이 없으므로) 재시작 화면이 나온다
- [ ] 측정 중 세션이 인터럽션(예: 전화 수신)으로 끊기면 실패 문구 대신 그때까지 측정된 것의 요약이 나온다. 인터럽션이 측정 시작 전에 일어나면(기록이 없으므로) 실패 화면이 나온다
- [ ] VoiceOver가 요약의 비율과 측정 시간을 읽는다

결과는 `SmileDay/docs/reports/YYYY-MM-DD-live-smile-session-graph-device-verification.md`에 기기, iOS, 빌드, 항목별 PASS/FAIL과 발열 체감만 기록한다. **raw blend shape와 비율 시계열은 저장하지 않는다.**

---

## 완료 체크리스트

- [ ] 대응 Design Spec `2026-07-30-live-smile-session-graph-design.md`의 완료 기준을 모두 충족함
- [x] 1초 칸이 다수결로 확정되고 끊긴 구간이 `unknown`으로 채워짐
- [x] 비율 분모가 판정 가능한 시간이고 `unknown` 비율이 함께 표시됨
- [x] 판정 가능 시간 0과 세션 길이 0에서 0으로 나누지 않음
- [x] 측정 중에는 띠만 자라고 비율·경과 시간은 종료 후에만 나옴
- [x] ~~스냅샷이 분당 1장, 판정 가능 프레임에서만, 색 판정 없이 잡힘~~ — 2026-07-31 철회
- [x] 요약을 닫으면 타임라인이 해제됨
- [x] SwiftData·UserDefaults·파일 시스템·네트워크에 측정값이 나가지 않음
- [x] ~~설정 화면의 "찍지도 않아요"가 사실에 맞게 수정됨~~ — 2026-07-31 철회로 다시 "찍지 않는다"가 사실이 됨
- [x] ~~AGENTS.md의 절대 조항이 저장·전송으로 좁혀짐~~ — 2026-07-31 철회로 촬영 금지가 절대 조항으로 복귀
- [x] `CoachingKit` 전체 테스트 통과
- [x] iOS 17 앱 빌드 통과
- [x] `git diff --check` 통과
- [ ] TrueDepth 실기기 QA 기록 완료
