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

# Run the app-target unit tests (needs a simulator; hosted by SmileDay.app)
xcodebuild test -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run a single app-target test class
xcodebuild test -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:SmileDayTests/ReminderIdentifierTests
```

There is no lint configuration.

`SmileDayTests/` covers the app target's **pure logic only** — notification identifier format, `NotificationRouter`, `SDFormat`, the `Color` token wrappers, and `LiveSmileSessionEndReason`. SwiftUI views themselves still have no automated tests; a successful `xcodebuild` remains the verification for view-layer changes. Anything testable without UIKit or ARKit belongs in `CoachingKit` instead.

Note: newer `xcodebuild` prints per-case lines (`Test case '…' passed`) rather than an `All tests` summary — check for `** TEST SUCCEEDED **`. Pipe through `grep -a` if you filter the log; it contains bytes that make `grep` treat it as binary.

Note: the tests are XCTest-based, so the final line of `swift test` output comes from the Swift Testing runner and reads "0 tests in 0 suites passed" — that is not a failure. Check for `Test Suite 'All tests' passed` in the output.

## Architecture

SmileDay is a Korean-language iOS app (iOS 17+, SwiftUI + SwiftData) for people who rarely smile during the day. It helps them smile more often through one short loop. All data stays on-device; there is no server.

The core loop — the product's priority, and the only path that records anything — is:

```
repeating reminder → non-judgmental cue → ~5s smile → save the completion → today's and the last 7 days' counts
```

This loop never uses the camera. Camera access is never part of onboarding and never required to complete a smile.

There is one **optional** side mode, "실시간 미소 확인" (live smile check), reached only from a secondary card on the home screen. While the user explicitly runs it, the TrueDepth camera reports how far the mouth-corner blend shapes have risen from a per-session neutral, shown as a live 0–100 signal. It has hard boundaries:

- The camera view is off by default; a toggle turns it on for that session only. When on, it renders the running `ARSession` through `ARSCNView`. `ARFrame.capturedImage` is never read — the mode produces no still image at all.
- When the session ends it shows a per-second timeline band and a smiling ratio. Both are memory-only and released when the summary closes. A per-minute snapshot grid existed until 2026-07-31 and was removed on purpose: showing users a grid of their own face makes them grade themselves, which the app refuses to do, and the timeline already answers "when". Do not add photos back.
- Nothing is persisted or transmitted — no frames, blend shapes, levels, timelines, or session times reach SwiftData, UserDefaults, the filesystem, or the network. There is no capture, export, or share path.
- It does not add to the completion count; running the live mode is a different action from completing a smile.
- The score is a sensor reading, not a verdict. It never evaluates appearance, emotion, Duchenne-ness, or left/right symmetry.

The codebase is split into two layers:

- **`CoachingKit/`** — a local Swift package containing everything platform-independent: SwiftData `@Model` classes, repositories wrapping `ModelContext` (`SmileMomentRepository`, `SmileReminderScheduleRepository`, `LegacyReminderRepository`), `@Observable` view models (`SmileHomeViewModel`, `SmileGuideViewModel`, `SmileReminderScheduleViewModel`, `SmileOnboardingViewModel`), and value types (`SmileCue`, `SmileGuide`, `SmileReminderPattern`, `ReminderNotificationPayload`). The package also targets macOS solely so `swift test` runs on the Mac without a simulator. **New logic belongs here with tests**, not in the app target.
- **`SmileDay/`** — the app target: SwiftUI views (`Views/`) and platform services (`Services/`). It implements two CoachingKit protocols: `ReminderScheduling` via `UserNotificationReminderScheduler`, and `LiveSmileMonitoring` via `ARKitLiveSmileMonitor` (the ARKit/AVFoundation boundary for the optional live mode). Views construct view models and inject these concrete services; tests inject fakes.

Persistence has two tiers, both registered in `PersistenceSchema`:

- Active: `SmileMoment` (one completed smile) and `SmileReminderSchedule` (the single repeating schedule).
- Compatibility-only, never read by the UI: `Baseline`, `CheckInSession`, `CareSession`, `ReminderSetting`, `CustomSmileCard`. They exist so an existing user's store still opens. **Do not delete them or change their stored properties** without a versioned-migration design.

App flow: splash → one-time reminder-window onboarding → `SmileMVPHomeView` (today's count, next reminder, recent seven days) → smile guide as a full-screen cover → settings for the reminder schedule. The schedule is registered as repeating daily notifications through `UserNotificationReminderScheduler`; notification taps deep-link through `AppDelegate` → `NotificationRouter` (injected as an environment object) and open the same guide as the manual action.

The reminder notification also carries two buttons (`ReminderNotificationAction`, shown when the notification is long-pressed). "가이드 열기" is the tap path above. **"웃었어요" records a `SmileMoment` without opening the app** — iOS wakes the app in the background only, so it reaches SwiftData through `PersistenceController.shared` rather than the view hierarchy's container, and it can give no confirmation at all: `UIFeedbackGenerator` is a documented no-op outside foreground-active, so there is no haptic to add. The notification disappearing is the whole feedback, matching Reminders' "완료로 표시". Those moments are stored as `.notificationAction`, kept separate from `.notification` because that one means the guide's five seconds actually ran. Two legacy paths are deliberately preserved: `cancel(id:)` still rebuilds the identifiers an older build created, and `ReminderNotificationPayload` still parses the old `bucket`/`promptText` payload.

## Conventions

- User-facing copy lives in String Catalogs under `SmileDay/Resources/` — `Localizable` (shared + all notification strings) plus one per screen: `Home`, `Onboarding`, `Settings`, `Coaching`, and `InfoPlist`. Source language is **English** (`developmentRegion = en` — it is the fallback for devices whose preferred languages include neither ko nor en); Korean is the `ko` column. Code references copy only through the Xcode-generated `LocalizedStringResource` symbols (`Text(.todayCountTitle)`, `.Home.smileCount(n)`); never write a key literal. The one exception is data-driven ids (`smileCue.<id>`, `reminderMessage.<id>`), which build the key as a `String` first — `String.LocalizationValue("prefix.\(id)")` treats the interpolation as a format argument and silently returns the key. CoachingKit holds no user-facing strings: SwiftPM copies `.xcstrings` without compiling them, so `String(localized:)` there silently returns the key. `StringCatalogGuaranteeTests` (CoachingKit) parses the catalogs from disk and enforces banned wording in both languages, no missing values, id ↔ key parity for cues and default reminder messages, and distinct/≤100-char defaults; `SmileCueTextTests`/`ReminderMessageResolvedTests` (app target) prove the keys actually resolve. `scripts/check-catalogs.sh` reports `needs_review` counts; `STRICT=1` is the phase-2 release gate.
- Notification title/body/button titles are scheduled as `localizedUserNotificationString(forKey:)` keys and resolve in the device language at delivery (measured). `reminderMessage.<id>`, `notificationAppName`, `reminderAction.<rawValue>`, `liveMonitorNudgeTitle/Body` are therefore a compatibility contract with notifications already on devices — do not rename or delete them, and keep them in the base `Localizable` table (that API has no table parameter). `LocalizedReminderBackfill` re-schedules pre-existing plain-text notifications once after update.
- `ReminderMessage.text` is `nil` for untouched defaults (resolved from the catalog by id) and non-nil only for user-written text, which is never translated. Storage key is `reminderMessages.v2`; `v1` is read for promotion (against a frozen Korean snapshot in `ReminderMessageMigration`, never the catalog) and never written.
- Dates use `Text(_:format:)` so they inherit the injected `\.calendar` (Gregorian + current locale from `SmileDayApp`); durations use `Duration.UnitsFormatStyle` via `SDFormat`. Do not reintroduce a locale pin.
- Do not add `NSCameraUsageDescription` or `CFBundleDisplayName` to `InfoPlist.xcstrings` without keeping the `INFOPLIST_KEY_*` build setting: this project generates its Info.plist and the catalog only overrides values for keys that already exist.
- Health-claim wording is restricted (App Store Guideline 1.4.1): never use copy like "리프팅", "젊어진다", "교정한다", "치료". Use habit-awareness framing instead ("표정 습관을 기록한다").
- No rankings or streak-loss language. A day with zero smiles is neutral, not a failure. Guide cue copy lives in `Resources/Coaching.xcstrings` under `smileCue.<id>`; `SmileCueCatalog` holds only the ids and their order.
- The only number ever shown as a "score" is the live mode's real-time sensor signal, and it is never stored, compared across sessions, or framed as good/bad.
- `SmileGuideCatalog.default.id` (`"anytime-soft"`) is a persisted value — it is stored in `SmileMoment.guideID` and in notification payloads already scheduled on devices. Do not change it.
- Design specs live in `docs/superpowers/specs/`, implementation plans in `docs/superpowers/plans/` (dated markdown files). Consult the relevant spec before extending a feature.
