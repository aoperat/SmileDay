<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-27 -->

# Views

## Purpose
SwiftUI screens for the frequency-first flow. `RootView` gates splash → reminder onboarding → home; home opens the short smile guide, the optional live monitor, and settings. `Theme.swift` is the single design-system source ("Morning Glow" palette).

## Key Files
| File | Description |
|------|-------------|
| `RootView.swift` | App entry gate: splash while loading → reminder onboarding when needed → home |
| `Theme.swift` | Design tokens: `SDColor` palette + gradients, `Color(hex:)`, `SmileArc` shape, `.sdCard()` modifier, `SDPrimaryButtonStyle`/`SDInkButtonStyle`, `SDCloseButton`, `SDFormat` (pinned `ko_KR` locale) |
| `SharedStrings.swift` | Reused Korean copy for the frequency-first flow |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `Home/` | Today's count, next reminder, recent seven-day frequency |
| `Coaching/` | Camera-free smile cue and timer, plus the optional live monitor and its toggleable camera view |
| `Settings/` | Reminder window, interval, notification authorization, data-location copy |
| `Onboarding/` | Purpose introduction and initial reminder-window setup |
| `Splash/` | Branded launch screen (see `Splash/AGENTS.md`) |

`AppStartupFailureView.swift` sits at this level: the fallback screen shown when the SwiftData container cannot be built.

## For AI Agents

### Working In This Directory
- View-model acquisition pattern: `@State private var viewModel: SomeViewModel?`, lazily constructed in `.onAppear` from `@Environment(\.modelContext)`-backed CoachingKit repositories, then `try? vm.refresh()`. VMs are per-view, not shared.
- Only `NotificationRouter` comes through the SwiftUI environment (`@Environment(NotificationRouter.self)`); results flow back up via closures (`onCompleted`, `onFinished`, ...).
- Home presents `SmileGuideView` as a full-screen cover for both manual starts and notification taps, and `LiveSmileMonitorView` as a separate cover for the optional live mode. Notification taps must keep going to the guide, never to the camera.
- All copy is inline Korean string literals; keep it that way unless a string is reused (then `SharedStrings`).
- The only camera view in the app is `LiveSmileCameraPreview`, and only the live monitor may show it — off by default, behind a user toggle. No other screen renders camera output. The live monitor does take one JPEG snapshot per minute, but nothing anywhere saves, exports, or transmits it — it lives only in `LiveSmileMonitorView`'s in-memory `[Data]` array (passed down to the summary screen as a `let`) until that screen closes.
- Any screen that turns the camera on must stop it on close, background, and scene inactive, and must restore `isIdleTimerDisabled` on every exit path.

### Testing Requirements
No view tests. Verify with `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build`.

### Common Patterns
- Container styling via `.sdCard()`; CTAs via `SDPrimaryButtonStyle` (coral gradient pill) / `SDInkButtonStyle`; screen backgrounds use `SDColor.cream`.
- Date formatting goes through `SDFormat.koreanLocale` so output does not follow the device locale.
- `SmileArc` is reused for the splash logo and the guide screen's drawn face.
- `SDColor` only wraps tokens the UI actually uses; raw hex values and their contrast tests live in `CoachingKit/SDPalette.swift`, because the app target has no test bundle. Add a token in both places or not at all.

## Dependencies

### Internal
- CoachingKit frequency/reminder view models and repositories; `Services/` for notification scheduling and routing.
- User-facing copy never shows stored scores, day-over-day deltas, or left/right comparisons — the logic that produced them has been removed, not hidden. The live monitor's 0–100 number is a real-time sensor reading that is never saved or compared.

### External
- SwiftUI, Observation.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
