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
| `SmileDay/docs/reports/2026-07-30-project-review.md` | Latest project-wide review: verified status, risks, and recommended priorities |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `CoachingKit/` | Local Swift package: models, repositories, view models, pure logic + all tests (see `CoachingKit/AGENTS.md`) |
| `SmileDay/` | App target: SwiftUI views, platform services, assets, app docs (see `SmileDay/AGENTS.md`) |
| `docs/` | Repo-root implementation plans (English, newer UI work) (see `docs/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- **New logic belongs in `CoachingKit/` with tests**, not in the app target. The app target only gets SwiftUI views and platform-API wrappers.
- All user-facing copy is Korean; locale is pinned to `ko_KR`.
- Health-claim wording is restricted (App Store Guideline 1.4.1): never use "리프팅", "젊어진다", "교정한다", "치료" — use habit-awareness framing ("표정 습관을 기록한다").
- Features have paired design specs and implementation plans under `SmileDay/docs/superpowers/` (`YYYY-MM-DD-<feature>-design.md` ↔ `YYYY-MM-DD-<feature>.md`). Consult the spec before extending a feature.
- Before reporting the project's current status, risks, or next priorities, read `SmileDay/docs/reports/2026-07-30-project-review.md`. Re-verify any item affected by later code changes, and update or supersede the dated report when a new full-project review is performed.

### Testing Requirements
```bash
cd CoachingKit && swift test                     # all package tests (runs on macOS, no simulator)
cd CoachingKit && swift test --filter <ClassName> # single test class
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build  # view-layer verification
```
No lint config. SwiftUI views have no automated tests — a successful `xcodebuild` is the verification for view changes.
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
- **No photo or video capture, and no persistence of frames, blend shapes, or levels — whether or not the camera view is showing.** Nothing from this mode reaches SwiftData or UserDefaults, and nothing is transmitted. Keep "we don't display it" and "we don't store it" separate in copy; only the second is still an absolute.
- Live-mode usage is not a completion. Do not add it to `SmileMoment` counts.
- A device without TrueDepth must keep full access to everything else in the app.
