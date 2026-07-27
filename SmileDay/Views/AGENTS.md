<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-24 -->

# Views

## Purpose
All SwiftUI screens, grouped by tab/flow. `RootView` gates the app (splash → onboarding → baseline capture → tabs), `MainTabView` hosts a custom floating pill tab bar over 5 tabs (홈/코칭/케어/기록/설정), and `Theme.swift` is the single design-system source ("Morning Glow" palette).

## Key Files
| File | Description |
|------|-------------|
| `RootView.swift` | App entry gate: splash while loading → `MainTabView` (baseline exists) / `BaselineCaptureView` / `OnboardingIntroView`; loads latest baseline on `.task`, seeds demo data in DEBUG, re-schedules reminders on scenePhase `.active` |
| `MainTabView.swift` | `TabView` (native bar hidden) + `SDTabBar` floating pill bar + `AppTab` enum; hides bar during coaching; consumes `NotificationRouter.pendingCoaching` deep link to jump to coaching with a prompt |
| `Theme.swift` | Design tokens: `SDColor` palette + gradients, `Color(hex:)`, `SmileArc` shape, `.sdCard()` modifier, `SDPrimaryButtonStyle`/`SDInkButtonStyle`, `SDCloseButton`, `SDFormat` (Korean-locale date/degree formatting) |
| `SharedStrings.swift` | Shared Korean copy — currently only `saveFailed`, reused across capture/coaching/care save-error paths |
| `FaceGuideOverlay.swift` | Non-interactive dashed ellipse guide overlaid on the AR camera preview |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `Home/` | 홈 dashboard: gauges, streak, nudge cards (see `Home/AGENTS.md`) |
| `Coaching/` | 코칭 check-in flow: live AR session → save confirmation (see `Coaching/AGENTS.md`) |
| `Care/` | 케어 routine browser + guided player (see `Care/AGENTS.md`) |
| `History/` | 기록 analytics: charts, heatmap (see `History/AGENTS.md`) |
| `Settings/` | 설정: reminders, baseline reset, data privacy (see `Settings/AGENTS.md`) |
| `Onboarding/` | First-run intro + baseline capture (see `Onboarding/AGENTS.md`) |
| `Splash/` | Branded launch screen (see `Splash/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- View-model acquisition pattern: `@State private var viewModel: SomeViewModel?`, lazily constructed in `.onAppear` from `@Environment(\.modelContext)`-backed CoachingKit repositories, then `try? vm.refresh()`. VMs are per-view, not shared.
- Only `NotificationRouter` comes through the SwiftUI environment (`@Environment(NotificationRouter.self)`); results flow back up via closures (`onBaselineSaved`, `onCompleted`, `onStartCoaching`, ...).
- Camera screens own an `ARKitFaceTrackingSession` as `@State`, inject it into their VM, `start()` on appear and `stop()` on disappear.
- Tab flow: Home's `onStartCoaching` switches tab selection to `.coaching`; finishing/exiting coaching returns to `.home`. Baseline re-capture is presented via `fullScreenCover` from both Home (nudge card) and Settings.
- All copy is inline Korean string literals; keep it that way unless a string is reused (then `SharedStrings`).

### Testing Requirements
No view tests. Verify with `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build`.

### Common Patterns
- Container styling via `.sdCard()`; CTAs via `SDPrimaryButtonStyle` (coral gradient pill) / `SDInkButtonStyle`; tab backgrounds `SDColor.cream`, camera screens use black overlays; `.tint(SDColor.coral)` at roots.
- Format numbers/dates through `SDFormat` (avoids "-0.0", keeps Korean locale).
- `SmileArc` shape is reused for the logo, streak curve, and sun face.

## Dependencies

### Internal
- CoachingKit view models, repositories, `InsightEngine`, `ScoreCalculator`, `ReminderNudge`, `BaselineResetNudge`; `Services/` for AR preview and notification routing.

### External
- SwiftUI, Swift Charts (History), Observation.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
