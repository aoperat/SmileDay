<!-- Generated: 2026-07-24 | Updated: 2026-07-27 -->

# SmileDay

## Purpose
Korean-language iOS app (iOS 17+, SwiftUI + SwiftData) for people who do not smile often. It helps users increase the frequency and repetition of intentionally smiling through a short reminder → cue → guided smile → completion loop. All data stays on-device; there is no server.

The codebase is split into a platform-independent Swift package (`CoachingKit/`) holding all models, view models, and logic, and a thin app target (`SmileDay/`) holding SwiftUI views and platform services. Legacy persistence models remain in the package for existing-data compatibility.

The core loop never uses the camera. One optional side mode ("실시간 미소 확인") does, under strict limits — see the guardrails below.

## Key Files
| File | Description |
|------|-------------|
| `CLAUDE.md` | Claude Code guidance: build/test commands, architecture summary, conventions |
| `SmileDay.xcodeproj` | Xcode project for the app target (scheme: `SmileDay`) |
| `docs/reports/2026-07-31-release-readiness-review.md` | Latest project-wide release review: verified status, submission gates, risks, and recommended priorities |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `CoachingKit/` | Local Swift package: models, repositories, view models, pure logic + all tests (see `CoachingKit/AGENTS.md`) |
| `SmileDay/` | App target: SwiftUI views, platform services, assets (see `SmileDay/AGENTS.md`) |
| `docs/` | All design specs, implementation plans, reports, and marketing assets (see `docs/AGENTS.md`). Kept out of `SmileDay/` so it is not bundled into the app |

## For AI Agents

### Working In This Directory
- **New logic belongs in `CoachingKit/` with tests**, not in the app target. The app target only gets SwiftUI views and platform-API wrappers.
- All user-facing copy is Korean; locale is pinned to `ko_KR`.
- Health-claim wording is restricted (App Store Guideline 1.4.1): never use "리프팅", "젊어진다", "교정한다", "치료" — use habit-awareness framing ("표정 습관을 기록한다").
- Features have paired design specs and implementation plans under `docs/superpowers/` (`YYYY-MM-DD-<feature>-design.md` ↔ `YYYY-MM-DD-<feature>.md`). Consult the spec before extending a feature.
- Before reporting the project's current status, risks, or next priorities, read `docs/reports/2026-07-31-release-readiness-review.md`. Re-verify any item affected by later code changes, and update or supersede the dated report when a new full-project review is performed.

### Testing Requirements
```bash
cd CoachingKit && swift test                     # all package tests (runs on macOS, no simulator)
cd CoachingKit && swift test --filter <ClassName> # single test class
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build  # view-layer verification
xcodebuild test -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'   # app-target unit tests (SmileDayTests)
```
No lint config. `SmileDayTests/` covers the app target's pure logic only (notification identifier format, `NotificationRouter`, `SDFormat`, `Color` token wrappers, `LiveSmileSessionEndReason`). SwiftUI views still have no automated tests — a successful `xcodebuild` is the verification for view changes. Put anything testable without UIKit/ARKit in `CoachingKit` instead.
Note: `swift test` output ends with the Swift Testing runner's "0 tests in 0 suites passed" line — not a failure; the suite is XCTest-based, so check for `Test Suite 'All tests' passed`.

### Common Patterns
- MVVM: SwiftUI views (app target) + `@Observable` view models (package) + repositories over SwiftData `ModelContext`.
- Protocol-based dependency injection at every side-effecting boundary (`ReminderScheduling`, `...Storing` state stores) so package tests run without `UNUserNotificationCenter`.
- `now: () -> Date` and `Calendar` injected for deterministic time-based tests.

## Dependencies

### External
- Apple frameworks only: SwiftUI, SwiftData, UserNotifications, Observation. No third-party packages.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->

## Product North Star

- SmileDay exists for people who do not smile often in everyday life.
- Its primary outcome is to help them **increase the frequency and repetition of intentionally smiling during the day**.
- Completion counts and reminders support that behavior; facial scores, appearance evaluation, emotion improvement claims, and elaborate categorization do not.
- Prefer the shortest loop: reminder → brief, non-judgmental cue → a few seconds of smiling → completion.
- When a feature competes with this outcome, keep the behavior loop and remove or defer the competing feature.

## Optional Live Mode Guardrails

"실시간 미소 확인" is a secondary, explicitly-started mode. It must stay inside these lines:

- The reminder → cue → 5s smile → completion loop stays the priority and stays camera-free. Camera access never becomes an onboarding step or a requirement for recording a completion.
- The camera runs only while the user has explicitly started the mode, and stops on close, background, or scene inactive.
- Show only the mouth-corner sensor signal. No appearance, emotion, impression, Duchenne, symmetry, age, or wrinkle evaluation.
- The camera view is **off by default** and opens only when the user toggles it on. It is never persisted across sessions and never on at launch.
- **Nothing from this mode is persisted or transmitted** — no frames, blend shapes, levels, or timelines reach SwiftData, UserDefaults, the filesystem, or the network. This is the one absolute.
- **No still image is produced at all.** `ARFrame.capturedImage` is never read; the mode's only output is the in-memory 1-second timeline. A per-minute snapshot grid was built and then removed on 2026-07-31 — a grid of the user's own face makes them grade themselves, which is exactly what this app refuses to do, and the timeline already answers "when". Do not reintroduce it; the timeline is the summary's visual.
- Two claims stay separate in copy — "we don't display it" (conditional: the preview is user-toggled) and "we don't keep it" (absolute). Do not merge them into one sentence.
- Live-mode usage is not a completion. Do not add it to `SmileMoment` counts.
- A device without TrueDepth must keep full access to everything else in the app.
