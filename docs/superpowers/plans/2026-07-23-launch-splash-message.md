# Launch Splash Message Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Show a fixed encouraging message ("웃다보면 다 좋아질거야") on a custom splash screen every time the app launches, replacing the current bare `ProgressView()` loading state in `RootView`.

**Architecture:** A new `SplashView` (Morning Glow themed: coral gradient background + `SmileArc` + app name + message) replaces `ProgressView()` in `RootView`'s `isLoading` branch. `RootView`'s `.task` runs the real data fetch concurrently with a fixed 1.3s minimum-display timer (`async let`), waits for both, then fades out via `withAnimation`.

**Tech Stack:** SwiftUI, existing `SDColor`/`SmileArc` design tokens from `SmileDay/Views/Theme.swift`.

**Note on testing:** This codebase has no unit test harness for SwiftUI `View` structs (CoachingKit's tests cover view *models*, not views). Verification for this plan is done via `xcodebuild build` (compile-time check) and manual simulator run, not automated tests.

---

### Task 1: Create SplashView

**Files:**
- Create: `SmileDay/SmileDay/Views/Splash/SplashView.swift`

- [x] **Step 1: Write the view**

```swift
import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            SDColor.primaryGradient
                .ignoresSafeArea()

            VStack(spacing: 20) {
                SmileArc(depth: 0.4)
                    .stroke(SDColor.cream, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 96, height: 48)

                Text("스마일데이")
                    .font(.title.bold())
                    .foregroundStyle(SDColor.cream)

                Text("웃다보면 다 좋아질거야")
                    .font(.subheadline)
                    .foregroundStyle(SDColor.cream.opacity(0.9))
            }
        }
    }
}

#Preview {
    SplashView()
}
```

- [x] **Step 2: Add the file to the Xcode project**

`SmileDay/Views/Splash/SplashView.swift` must be added to the `SmileDay` target. If the project uses folder-reference (synchronized group) file inclusion — check by running:

```bash
grep -n "PBXFileSystemSynchronizedRootGroup" SmileDay.xcodeproj/project.pbxproj | head -5
```

If that pattern is present, new files under `SmileDay/` are picked up automatically and no `.pbxproj` edit is needed. If it's absent (classic `PBXGroup`/`PBXBuildFile` style), add the file to the `SmileDay` target manually in Xcode (File Inspector → Target Membership), since a plan can't safely hand-edit `.pbxproj` build file entries.

- [x] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [x] **Step 4: Commit**

```bash
git add SmileDay/Views/Splash/SplashView.swift SmileDay.xcodeproj
git commit -m "feat: add SplashView with fixed launch message"
```

---

### Task 2: Wire SplashView into RootView with minimum-duration timing

**Files:**
- Modify: `SmileDay/SmileDay/Views/RootView.swift`

- [x] **Step 1: Replace the loading branch and timing logic**

Replace the full contents of `SmileDay/SmileDay/Views/RootView.swift` with:

```swift
import SwiftUI
import SwiftData
import CoachingKit

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var baseline: Baseline?
    @State private var isLoading = true
    @State private var hasSeenIntro = false

    var body: some View {
        Group {
            if isLoading {
                SplashView()
                    .transition(.opacity)
            } else if let baseline {
                MainTabView(baseline: baseline, onBaselineUpdated: { self.baseline = $0 })
            } else if hasSeenIntro {
                BaselineCaptureView(
                    onBaselineSaved: { savedBaseline in
                        baseline = savedBaseline
                    },
                    onCancel: { hasSeenIntro = false }
                )
            } else {
                OnboardingIntroView {
                    hasSeenIntro = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
        .task {
            async let minimumSplashDuration: () = try? Task.sleep(for: .seconds(1.3))

            let repository = SessionRepository(modelContext: modelContext)
            #if DEBUG
            if CommandLine.arguments.contains("-seedDemoData") {
                try? DemoSeeder.seedIfNeeded(repository: repository)
            }
            #endif
            let fetchedBaseline = try? repository.fetchLatestBaseline()

            _ = await minimumSplashDuration
            baseline = fetchedBaseline
            isLoading = false
        }
    }
}
```

This starts the 1.3s timer as a concurrent child task right away, does the (synchronous, `try?`-guarded) demo-seed and baseline fetch as before, then awaits the timer before flipping `isLoading` — so the splash is visible for at least 1.3s regardless of how fast the fetch finishes, and longer if the fetch is slow. The `.animation(value: isLoading)` fades the `SplashView` out when `isLoading` flips to `false`.

- [x] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [x] **Step 3: Run in the simulator and manually verify**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build-for-testing` then launch via `xcrun simctl` (or open in Xcode and hit Run).
Expected: On launch, a coral-gradient splash screen with "스마일데이" and "웃다보면 다 좋아질거야" is visible for roughly 1.3 seconds, then fades into the existing onboarding/main flow.

- [x] **Step 4: Commit**

```bash
git add SmileDay/Views/RootView.swift
git commit -m "feat: show splash message with minimum display duration on launch"
```

---

## Self-Review Notes

- **Spec coverage:** fixed message ✓ (Task 1 Step 1), every-launch (no first-launch-only gating added) ✓, dedicated splash screen with logo/message (not just text under a spinner) ✓ (Task 1), minimum 1.2–1.5s exposure with fade transition ✓ (Task 2), no skip-on-tap added ✓ (none added, matches "out of scope").
- **Placeholder scan:** none found — all steps have full code and exact commands.
- **Type consistency:** `SplashView` referenced in Task 2 matches the struct name defined in Task 1. `SDColor.primaryGradient`, `SDColor.cream`, `SmileArc` match existing names in `Theme.swift`.
