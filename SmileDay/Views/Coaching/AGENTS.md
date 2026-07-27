<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-27 -->

# Coaching (미소 시간)

## Purpose
The 미소 flow where daily records are created. `CoachingTabView` coordinates a two-screen sequence: a live AR face-tracking session that only reports whether a face is ready, then a confirmation screen offering an encouragement line, an optional mood, an optional one-line moment note, and a reminder offer.

Scores are still measured and stored for data compatibility but are never shown.

## Key Files
| File | Description |
|------|-------------|
| `CoachingTabView.swift` | Flow coordinator holding `SessionResult`; on completion computes reminder-offer eligibility (`ReminderNudge`) and the `HabitContext`, swaps to `SaveConfirmView`; `onConfirm` saves the reflection then `onFinished` → back to Home |
| `CoachingSessionView.swift` | Capture screen: AR preview, optional deep-link prompt banner, lighting/angle warnings, readiness status text; "오늘의 미소 남기기" saves the check-in via `CoachingViewModel` |
| `SaveConfirmView.swift` | Confirmation screen + `ReminderOfferCard`, `SunFaceView`, `ConfettiDots`: habit encouragement, mood emoji picker, 200-char moment note field, post-check-in reminder offer |

## For AI Agents

### Working In This Directory
- `CoachingSessionView` owns an `ARKitFaceTrackingSession` as `@State`, injects it into `CoachingViewModel`, starts on appear, stops on disappear. Measurement logic belongs in the VM, not the view.
- Never surface a score, a day-over-day delta, or a left/right comparison here. User-facing copy comes from `HabitEncouragementEngine`; `InsightEngine` is **not** for user messages.
- `SaveConfirmView` recomputes its encouragement from `habitContext.withMomentNote(...)` as the user types, since the reflection is saved after the line is first shown.
- A failed reflection save keeps the confirm screen open — the check-in itself is already persisted.
- The deep-link prompt (from a tapped reminder notification) arrives as a string threaded `MainTabView` → `CoachingTabView` → `CoachingSessionView` banner, and is the same value stored as `promptText`.
- The tab bar is hidden while this tab is active; exiting restores it via the `onExit`/`onFinished` closures.

### Testing Requirements
Flow logic lives in `CoachingViewModel`/`HabitEncouragementEngine`/`ReminderNudge` (tested in CoachingKitTests). Verify views with `xcodebuild`.

## Dependencies

### Internal
- CoachingKit: `CoachingViewModel`, `SessionRepository`, `SmileReflection`, `HabitEncouragementEngine`, `ReminderNudge`; Services: `ARKitFaceTrackingSession`, `ARFacePreviewRepresentable`; `FaceGuideOverlay`, `SharedStrings.swift`, `Theme.swift`.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
