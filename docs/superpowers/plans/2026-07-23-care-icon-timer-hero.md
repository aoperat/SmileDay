# Care Player Icon+Timer-Ring Hero Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the "영상 준비 중" video placeholder in `CarePlayerView` with an icon + countdown-ring hero that reflects the current step, and remove the 3-second dummy `.mp4` files that currently block this placeholder from ever showing.

**Architecture:** `CareStep` gains an explicit `systemImage` field (SF Symbol name), set per step in `CareRoutine.catalog`. `CarePlayerView` gets a new private `StepHeroView` that draws a category-gradient card with a draining circular progress ring (driven by the existing `remainingSeconds` timer state) and the step's icon/title inside it. The existing `if let player { VideoPlayer(...) }` branch is untouched, so real videos will resume working automatically once matching `.mp4` files are added back to `Resources/`.

**Tech Stack:** SwiftUI, SF Symbols, existing `SDColor`/`CareCategory.thumbnailGradient` tokens.

**Note on testing:** `CareStep`/`CareRoutine` are plain data, so this plan adds one XCTest sanity test for the catalog. The `StepHeroView` itself is verified via `xcodebuild build` (compile) and a manual simulator screenshot, matching how `SplashView` was verified — this codebase has no SwiftUI view-snapshot test harness.

---

### Task 1: Add `systemImage` to `CareStep` and the catalog

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/CareRoutine.swift`

- [ ] **Step 1: Add the field and update the catalog**

Replace the full contents of `CoachingKit/Sources/CoachingKit/CareRoutine.swift` with:

```swift
import Foundation

public enum CareCategory: String, CaseIterable, Sendable {
    case lift
    case relax
    case depuff
    case morning

    public var displayName: String {
        switch self {
        case .lift: "입꼬리"
        case .relax: "릴랙스"
        case .depuff: "붓기"
        case .morning: "아침 1분"
        }
    }
}

public enum CareDifficulty: String, Sendable {
    case beginner
    case intermediate

    public var displayName: String {
        switch self {
        case .beginner: "초급"
        case .intermediate: "중급"
        }
    }
}

public struct CareStep: Equatable, Sendable {
    public let title: String
    public let seconds: Int
    public let reps: Int
    /// 히어로 영역에 표시할 SF Symbol 이름.
    public let systemImage: String

    public init(title: String, seconds: Int, reps: Int = 1, systemImage: String) {
        self.title = title
        self.seconds = seconds
        self.reps = reps
        self.systemImage = systemImage
    }
}

public struct CareRoutine: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let category: CareCategory
    public let difficulty: CareDifficulty
    public let steps: [CareStep]
    /// 번들 내 영상 파일 이름(확장자 제외). 파일이 없으면 플레이어가 아이콘 히어로를 보여준다.
    public let videoFileName: String

    public init(
        id: String,
        title: String,
        category: CareCategory,
        difficulty: CareDifficulty,
        steps: [CareStep],
        videoFileName: String
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.difficulty = difficulty
        self.steps = steps
        self.videoFileName = videoFileName
    }

    public var totalSeconds: Int {
        steps.reduce(0) { $0 + $1.seconds * $1.reps }
    }

    public var durationText: String {
        let minutes = Int((Double(totalSeconds) / 60).rounded(.up))
        return "\(minutes)분"
    }
}

public extension CareRoutine {
    /// 번들 기본 루틴 카탈로그.
    static let catalog: [CareRoutine] = [
        CareRoutine(
            id: "lift-smile",
            title: "입꼬리 리프팅 루틴",
            category: .lift,
            difficulty: .beginner,
            steps: [
                CareStep(title: "손바닥 비벼 데우기", seconds: 30, systemImage: "hands.and.sparkles.fill"),
                CareStep(title: "입꼬리 올려 10초 유지", seconds: 10, reps: 3, systemImage: "mouth.fill"),
                CareStep(title: "광대 쓸어올리기", seconds: 30, systemImage: "hand.draw.fill"),
                CareStep(title: "입꼬리 옆 지그시 원 그리기", seconds: 60, systemImage: "arrow.triangle.2.circlepath"),
            ],
            videoFileName: "care_lift_smile"
        ),
        CareRoutine(
            id: "lift-cheek",
            title: "광대 리프팅 마사지",
            category: .lift,
            difficulty: .beginner,
            steps: [
                CareStep(title: "손바닥 비벼 데우기", seconds: 30, systemImage: "hands.and.sparkles.fill"),
                CareStep(title: "광대뼈 아래 눌러 풀기", seconds: 60, systemImage: "hand.point.down.fill"),
                CareStep(title: "광대 바깥으로 쓸어올리기", seconds: 60, systemImage: "hand.draw.fill"),
                CareStep(title: "관자놀이 지그시 누르기", seconds: 30, reps: 2, systemImage: "hand.point.down.fill"),
            ],
            videoFileName: "care_lift_cheek"
        ),
        CareRoutine(
            id: "relax-brow",
            title: "미간 긴장 풀기",
            category: .relax,
            difficulty: .beginner,
            steps: [
                CareStep(title: "눈썹 위 지그시 누르기", seconds: 30, systemImage: "hand.point.down.fill"),
                CareStep(title: "미간 바깥으로 쓸어내기", seconds: 60, systemImage: "hand.draw.fill"),
                CareStep(title: "눈 감고 깊게 호흡", seconds: 30, systemImage: "lungs.fill"),
            ],
            videoFileName: "care_relax_brow"
        ),
        CareRoutine(
            id: "depuff-morning",
            title: "아침 붓기 케어",
            category: .depuff,
            difficulty: .intermediate,
            steps: [
                CareStep(title: "목 옆 림프 쓸어내리기", seconds: 60, systemImage: "hand.draw.fill"),
                CareStep(title: "턱선 따라 쓸어올리기", seconds: 60, systemImage: "hand.draw.fill"),
                CareStep(title: "눈 밑 가볍게 두드리기", seconds: 60, systemImage: "hand.tap.fill"),
                CareStep(title: "얼굴 전체 바깥으로 쓸기", seconds: 60, reps: 2, systemImage: "hand.draw.fill"),
            ],
            videoFileName: "care_depuff_morning"
        ),
        CareRoutine(
            id: "morning-1min",
            title: "아침 1분 스마일 스트레칭",
            category: .morning,
            difficulty: .beginner,
            steps: [
                CareStep(title: "입 크게 벌려 아·에·이·오·우", seconds: 30, systemImage: "mouth.fill"),
                CareStep(title: "입꼬리 올려 10초 유지", seconds: 10, reps: 3, systemImage: "mouth.fill"),
            ],
            videoFileName: "care_morning_1min"
        ),
    ]
}
```

- [ ] **Step 2: Build CoachingKit to verify it compiles**

Run: `cd CoachingKit && swift build`
Expected: builds with no errors (no output other than compilation progress, exit code 0)

- [ ] **Step 3: Commit**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git add CoachingKit/Sources/CoachingKit/CareRoutine.swift
git commit -m "feat: add per-step systemImage to CareStep catalog"
```

---

### Task 2: Add a catalog sanity test

**Files:**
- Create: `CoachingKit/Tests/CoachingKitTests/CareRoutineTests.swift`

- [ ] **Step 1: Write the test**

```swift
import XCTest
@testable import CoachingKit

final class CareRoutineTests: XCTestCase {
    func test_catalog_everyStepHasNonEmptySystemImage() {
        for routine in CareRoutine.catalog {
            for step in routine.steps {
                XCTAssertFalse(
                    step.systemImage.isEmpty,
                    "\(routine.id) step '\(step.title)' is missing a systemImage"
                )
            }
        }
    }
}
```

- [ ] **Step 2: Run the test**

Run: `cd CoachingKit && swift test --filter CareRoutineTests`
Expected: `Executed 1 test, with 0 failures`

- [ ] **Step 3: Commit**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git add CoachingKit/Tests/CoachingKitTests/CareRoutineTests.swift
git commit -m "test: add catalog sanity test for CareStep systemImage"
```

---

### Task 3: Replace the video placeholder with `StepHeroView`

**Files:**
- Modify: `SmileDay/SmileDay/Views/Care/CarePlayerView.swift`

- [ ] **Step 1: Add a safe `currentStep` accessor**

In `CarePlayerView`, right after the existing `private var isLastStep: Bool { ... }` line, add:

```swift
    private var currentStep: CareStep? {
        routine.steps.indices.contains(currentStepIndex) ? routine.steps[currentStepIndex] : nil
    }
```

- [ ] **Step 2: Replace the `videoArea` computed property**

Replace:

```swift
    @ViewBuilder
    private var videoArea: some View {
        if let player {
            VideoPlayer(player: player)
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(routine.category.thumbnailGradient)
                    .frame(height: 210)

                VStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.95))
                    Text("영상 준비 중 · 아래 단계를 따라 해보세요")
                        .font(.caption2.bold())
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
    }
```

with:

```swift
    @ViewBuilder
    private var videoArea: some View {
        if let player {
            VideoPlayer(player: player)
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else if let currentStep {
            StepHeroView(
                category: routine.category,
                step: currentStep,
                remainingSeconds: remainingSeconds,
                totalSeconds: currentStep.seconds * currentStep.reps
            )
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(routine.category.thumbnailGradient)
                .frame(height: 210)
        }
    }
```

- [ ] **Step 3: Add the `StepHeroView` private struct**

Add this new private struct right after the closing brace of `CarePlayerView` (before `private struct StepRow: View {`):

```swift
private struct StepHeroView: View {
    let category: CareCategory
    let step: CareStep
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
```

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add SmileDay/Views/Care/CarePlayerView.swift
git commit -m "feat: replace care video placeholder with icon+timer-ring hero"
```

---

### Task 4: Remove the dummy video files

**Files:**
- Delete: `SmileDay/Resources/care_relax_brow.mp4`
- Delete: `SmileDay/Resources/care_lift_smile.mp4`
- Delete: `SmileDay/Resources/care_depuff_morning.mp4`
- Delete: `SmileDay/Resources/care_lift_cheek.mp4`
- Delete: `SmileDay/Resources/care_morning_1min.mp4`

- [ ] **Step 1: Delete the files**

```bash
git rm SmileDay/Resources/care_relax_brow.mp4 \
       SmileDay/Resources/care_lift_smile.mp4 \
       SmileDay/Resources/care_depuff_morning.mp4 \
       SmileDay/Resources/care_lift_cheek.mp4 \
       SmileDay/Resources/care_morning_1min.mp4
```

- [ ] **Step 2: Build to verify it still compiles (no code references the removed files directly)**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git commit -m "chore: remove placeholder care routine videos"
```

---

### Task 5: Manual simulator verification

- [ ] **Step 1: Install and launch on simulator**

```bash
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/smileday-build build
APP_PATH=$(find /tmp/smileday-build -name "SmileDay.app" -maxdepth 6 | head -1)
xcrun simctl install "iPhone 17" "$APP_PATH"
BUNDLE_ID=$(defaults read "$APP_PATH/Info" CFBundleIdentifier)
xcrun simctl launch "iPhone 17" "$BUNDLE_ID"
```

- [ ] **Step 2: Navigate to a care routine's player screen and screenshot**

Since there's no UI-automation harness in this repo, do this step by hand in the simulator (Care tab → tap any routine), then capture:

```bash
xcrun simctl io "iPhone 17" screenshot /tmp/care_hero_screenshot.png
```

Expected: the top area shows a category-colored card with a circular icon+ring in the center (no "영상 준비 중" text, no dummy video), and the step title/rep count below the ring.

- [ ] **Step 3: Note completion**

No commit needed for this step — it's verification only, not a code change.

---

## Self-Review Notes

- **Spec coverage:** `systemImage` field ✓ (Task 1), icon mapping per step ✓ (Task 1 catalog), draining timer ring + icon + title/reps hero ✓ (Task 3), category gradient background reused ✓ (Task 3, `category.thumbnailGradient`), video branch untouched ✓ (Task 3 Step 2 keeps `if let player` branch verbatim), `StepRow`/list unchanged ✓ (no task touches it), dummy mp4 deletion ✓ (Task 4), catalog sanity test ✓ (Task 2).
- **Placeholder scan:** none — every step has full code or exact commands.
- **Type consistency:** `StepHeroView` fields (`category: CareCategory`, `step: CareStep`, `remainingSeconds: Int`, `totalSeconds: Int`) match the call site in Task 3 Step 2 exactly. `CareStep.systemImage` name matches between Task 1 and Task 3.
