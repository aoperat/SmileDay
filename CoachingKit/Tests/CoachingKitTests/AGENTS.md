<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-29 -->

# CoachingKitTests

## Purpose
XCTest suite for the whole package — one same-named test file per source area. SwiftData-backed tests use an in-memory `ModelContainer`; side-effecting boundaries use the InMemory store variants and fake `ReminderScheduling` implementations.

## Key Files
| File | Covers |
|------|--------|
| `PersistenceSchemaMigrationTests` | **The compatibility safety net.** All seven models registered; stores written with older schemas reopen with every stored value intact. Uses `ModelContext` and stored properties directly so it survives repository deletions |
| `SmileMomentTests`, `SmileMomentRepositoryTests` | Completion model round-trip; save/fetch, per-day counts, seven-day fill, week active-day counts |
| `SmileReminderPatternTests`, `SmileReminderScheduleRepositoryTests` | Time validation, interval/window rules, occurrence generation; current-schedule persistence |
| `SmileReminderScheduleViewModelTests` | Save → schedule → cancel ordering, including "legacy notifications are cancelled only after a successful save" |
| `SmileGuideTests`, `SmileGuideViewModelTests` | Default guide id/duration; countdown state machine, save-exactly-once, cancel saves nothing, late ticks never complete |
| `SmileHomeViewModelTests`, `SmileOnboardingStateTests` | Home counts and next-reminder math; onboarding confirm/skip and permission-denied paths |
| `SmileCueTests` | Cue catalog copy rules (no appearance, emotion, or quality claims) |
| `ReminderNotificationPayloadTests` | Current and legacy (`bucket`/`promptText`) payload parsing; unopenable payloads stay nil |
| `LegacyReminderRepositoryTests` | Legacy notification IDs returned for cancellation, disabled reminders included |
| `CustomSmileCardTests` | Compatibility model: stored properties only, no card interpretation |
| `SDPaletteTests` | WCAG contrast floors for text, button, and chip color pairings |
| `LiveSmileSampleTests` | Live boundary value types: equality across every stored value, `Sendable`, event cases |
| `LiveSmileSignalEvaluatorTests` | Neutral-relative signal, clamping of out-of-range and non-finite input, asymmetry not penalized, the gaze boundary (asserted against `gazeToleranceDegrees`, plus a floor test so nobody quietly tightens it), unknown ambient light not treated as dark, and that `LiveSmileLevel` bands widen toward the top rather than being equal quarters |
| `LiveSmileMonitorViewModelTests` | Calibration excluding invalid frames, smoothing (one frame never jumps to the top level; sustained smiling reaches it), publish throttling, quality-issue priority, recalibrate discarding the old neutral, events after `stop()` ignored, level hysteresis, and nudges (fires on interval, repeats, restarts after a smile, pauses while the face is lost without losing progress, honours the haptic and enabled flags) |
| `LiveSmileNudgeTests` | Nudge settings defaults, snapping an unknown interval to the nearest allowed value, UserDefaults round-trip that keeps an explicit `false` |
| `LiveSmileGazeTests` | That off-centre seating still reads as facing the camera (the product requirement), that looking away reads large, and that the result is independent of where the camera sits in world space |

## For AI Agents

### Working In This Directory
- Suite is XCTest (`XCTestCase`), not Swift Testing — keep new tests XCTest for consistency.
- Use injected `now: () -> Date` and `Calendar` for deterministic time-based assertions; never sleep or rely on wall-clock. `SmileGuideViewModelTests` shows the gated-clock pattern for countdown tests.
- For persistence tests, build an in-memory container from `PersistenceSchema.schema`.
- `PersistenceSchemaMigrationTests` must not depend on repositories or convenience APIs that could be deleted — keep it on `ModelContext` and stored properties.
- Scheduler fakes must implement all five `ReminderScheduling` methods (the protocol has no default implementations) and record their calls.
- Live-mode tests drive a fake `LiveSmileMonitoring` and an injected clock; never start a real `ARSession` or wait on wall-clock time.
- New source files get a same-named `<Name>Tests.swift` here.

### Testing Requirements
```bash
cd CoachingKit && swift test                      # all
cd CoachingKit && swift test --filter <ClassName> # one class
```
Check for `Test Suite 'All tests' passed` (the trailing "0 tests in 0 suites" line is the Swift Testing runner, not a failure).

Test count is not a quality target — the 2026-07-29 dead-code cleanup dropped the suite from 390 to 91 tests by deleting features, not coverage. The live-monitor work then brought it to 135.

## Dependencies

### Internal
- `@testable`-level access to `CoachingKit` (public API), InMemory store variants shipped in the source target.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
