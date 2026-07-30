# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run all CoachingKit tests (pure Swift, runs on macOS — no simulator needed)
cd CoachingKit && swift test

# Run a single test class
cd CoachingKit && swift test --filter SmileMomentRepositoryTests

# Build the iOS app (compile check for SwiftUI views / app-target code)
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build
```

There is no lint configuration. SwiftUI views have no automated tests — a successful `xcodebuild` is the verification for view-layer changes.

Note: the tests are XCTest-based, so the final line of `swift test` output comes from the Swift Testing runner and reads "0 tests in 0 suites passed" — that is not a failure. Check for `Test Suite 'All tests' passed` in the output.

## Architecture

SmileDay is a Korean-language iOS app (iOS 17+, SwiftUI + SwiftData) for people who rarely smile during the day. It helps them smile more often through one short loop. All data stays on-device; there is no server.

The core loop — the product's priority, and the only path that records anything — is:

```
repeating reminder → non-judgmental cue → ~5s smile → save the completion → today's and the last 7 days' counts
```

This loop never uses the camera. Camera access is never part of onboarding and never required to complete a smile.

There is one **optional** side mode, "실시간 미소 확인" (live smile check), reached only from a secondary card on the home screen. While the user explicitly runs it, the TrueDepth camera reports how far the mouth-corner blend shapes have risen from a per-session neutral, shown as a live 0–100 signal. It has hard boundaries:

- The camera view is off by default; a toggle turns it on for that session only. When on, it renders the running `ARSession` through `ARSCNView` — `ARFrame.capturedImage` is never read or converted by hand.
- Nothing is persisted or transmitted — no photos, video, blend shapes, levels, or session times reach SwiftData or UserDefaults, whether the camera view is showing or not. There is no capture button.
- It does not add to the completion count; running the live mode is a different action from completing a smile.
- The score is a sensor reading, not a verdict. It never evaluates appearance, emotion, Duchenne-ness, or left/right symmetry.

The codebase is split into two layers:

- **`CoachingKit/`** — a local Swift package containing everything platform-independent: SwiftData `@Model` classes, repositories wrapping `ModelContext` (`SmileMomentRepository`, `SmileReminderScheduleRepository`, `LegacyReminderRepository`), `@Observable` view models (`SmileHomeViewModel`, `SmileGuideViewModel`, `SmileReminderScheduleViewModel`, `SmileOnboardingViewModel`), and value types (`SmileCue`, `SmileGuide`, `SmileReminderPattern`, `ReminderNotificationPayload`). The package also targets macOS solely so `swift test` runs on the Mac without a simulator. **New logic belongs here with tests**, not in the app target.
- **`SmileDay/`** — the app target: SwiftUI views (`Views/`) and platform services (`Services/`). It implements two CoachingKit protocols: `ReminderScheduling` via `UserNotificationReminderScheduler`, and `LiveSmileMonitoring` via `ARKitLiveSmileMonitor` (the ARKit/AVFoundation boundary for the optional live mode). Views construct view models and inject these concrete services; tests inject fakes.

Persistence has two tiers, both registered in `PersistenceSchema`:

- Active: `SmileMoment` (one completed smile) and `SmileReminderSchedule` (the single repeating schedule).
- Compatibility-only, never read by the UI: `Baseline`, `CheckInSession`, `CareSession`, `ReminderSetting`, `CustomSmileCard`. They exist so an existing user's store still opens. **Do not delete them or change their stored properties** without a versioned-migration design.

App flow: splash → one-time reminder-window onboarding → `SmileMVPHomeView` (today's count, next reminder, recent seven days) → smile guide as a full-screen cover → settings for the reminder schedule. The schedule is registered as repeating daily notifications through `UserNotificationReminderScheduler`; notification taps deep-link through `AppDelegate` → `NotificationRouter` (injected as an environment object) and open the same guide as the manual action. Two legacy paths are deliberately preserved: `cancel(id:)` still rebuilds the identifiers an older build created, and `ReminderNotificationPayload` still parses the old `bucket`/`promptText` payload.

## Conventions

- All user-facing copy is Korean; the app pins `Locale(identifier: "ko_KR")` so dates/chart axes render in Korean too. Shared strings live in `Views/SharedStrings.swift`.
- Health-claim wording is restricted (App Store Guideline 1.4.1): never use copy like "리프팅", "젊어진다", "교정한다", "치료". Use habit-awareness framing instead ("표정 습관을 기록한다").
- No rankings or streak-loss language. A day with zero smiles is neutral, not a failure. User-facing guide copy lives in `SmileCueCatalog`.
- The only number ever shown as a "score" is the live mode's real-time sensor signal, and it is never stored, compared across sessions, or framed as good/bad.
- `SmileGuideCatalog.default.id` (`"anytime-soft"`) is a persisted value — it is stored in `SmileMoment.guideID` and in notification payloads already scheduled on devices. Do not change it.
- Design specs live in `SmileDay/docs/superpowers/specs/`, implementation plans in `SmileDay/docs/superpowers/plans/` (dated markdown files). Consult the relevant spec before extending a feature.
