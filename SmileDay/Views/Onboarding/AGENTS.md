<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-24 -->

# Onboarding

## Purpose
First-run experience: a 3-page paged intro (concept, on-device privacy + medical disclaimer, capture prep) followed by neutral-expression baseline capture. `BaselineCaptureView` is also reused by the re-capture flows in Home and Settings.

## Key Files
| File | Description |
|------|-------------|
| `OnboardingIntroView.swift` | 3-page paged intro ending in a 시작하기 button (`onStart`) |
| `BaselineCaptureView.swift` | ARKit capture screen: lighting/angle reliability banners, live measurement table, 1s stability gating; saves via `BaselineCaptureViewModel`; optional `onCancel` distinguishes first-run (no cancel) from reset flows |

## For AI Agents

### Working In This Directory
- The intro's page 2 carries the medical disclaimer required by the app's positioning (no treatment/lifting claims — see root `AGENTS.md` wording rules). Don't remove or weaken it.
- Capture gating (stability, lighting, angle) lives in `BaselineCaptureViewModel` — the view only renders phase/banner state.
- Flow state (`hasSeenIntro`, saved baseline) is owned by `RootView`; completion is reported via `onStart`/`onBaselineSaved` closures.

### Testing Requirements
Gating logic tested via `BaselineCaptureViewModelTests`. Verify views with `xcodebuild`.

## Dependencies

### Internal
- CoachingKit: `BaselineCaptureViewModel`, `SessionRepository`; Services: `ARKitFaceTrackingSession`, `ARFacePreviewRepresentable`; `FaceGuideOverlay`, `Theme.swift`.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
