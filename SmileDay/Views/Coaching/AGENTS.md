<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-24 -->

# Coaching

## Purpose
The 코칭 measurement flow where daily records are created. `CoachingTabView` coordinates a two-screen sequence: a live AR face-tracking session scoring the current smile delta against the baseline, then a celebratory save confirmation offering a reminder, a rule-based insight, and a mood picker.

## Key Files
| File | Description |
|------|-------------|
| `CoachingTabView.swift` | Flow coordinator holding `SessionResult`; on completion computes reminder-offer eligibility (`ReminderNudge`) and insight (`InsightEngine`), swaps to `SaveConfirmView`; `onConfirm` → `onFinished` → back to Home |
| `CoachingSessionView.swift` | Live measurement screen + `VerticalGaugeView`: AR preview, real-time smile-delta gauge vs baseline, optional deep-link prompt banner, lighting/angle warnings; "측정 종료" saves the check-in via `CoachingViewModel` |
| `SaveConfirmView.swift` | Confirmation screen + `ReminderOfferCard`, `SunFaceView`, `ConfettiDots`: today vs yesterday delta, optional insight card, mood emoji picker, post-check-in reminder offer |

## For AI Agents

### Working In This Directory
- `CoachingSessionView` owns an `ARKitFaceTrackingSession` as `@State`, injects it into `CoachingViewModel`, starts on appear, stops on disappear. Measurement/scoring logic belongs in the VM, not the view.
- The deep-link prompt (from a tapped reminder notification) arrives as a string threaded `MainTabView` → `CoachingTabView` → `CoachingSessionView` banner.
- The tab bar is hidden while this tab is active; exiting restores it via the `onExit`/`onFinished` closures.

### Testing Requirements
Flow logic lives in `CoachingViewModel`/`InsightEngine`/`ReminderNudge` (tested in CoachingKitTests). Verify views with `xcodebuild`.

## Dependencies

### Internal
- CoachingKit: `CoachingViewModel`, `SessionRepository`, `InsightEngine`, `ReminderNudge`, `ScoreCalculator`; Services: `ARKitFaceTrackingSession`, `ARFacePreviewRepresentable`; `FaceGuideOverlay`, `Theme.swift`.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
