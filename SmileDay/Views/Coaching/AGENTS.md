<!-- Parent: ../AGENTS.md -->
<!-- Updated: 2026-07-29 -->

# Coaching (미소 가이드 · 실시간 확인)

## Purpose
Two screens, deliberately separate:

- **`SmileGuideView`** — the core loop. Camera-free: show one non-judgmental cue, wait for an explicit start, run a brief timer, save one completion.
- **`LiveSmileMonitorView`** — the optional live check. Shows a real-time mouth-corner signal as four filled segments — never a number — with the camera view off by default behind a toggle, and saves nothing.

## Key Files
| File | Description |
|------|-------------|
| `SmileGuideView.swift` | Cue, timer, completion feedback, and `SmileMoment` persistence through `SmileGuideViewModel` |
| `LiveSmileMonitorView.swift` | Level meter, camera-view toggle, quality guidance, recalibrate/close, idle-timer and scene-phase lifecycle |
| `LiveSmileCameraPreview.swift` | `ARSCNView` wrapper that exists only while the toggle is on; draws the already-running session and restores the sample delegate |

## For AI Agents

### Both screens
- Never evaluate the user's face, appearance, emotion, or smile quality.
- Keep the loop short and easy to repeat.

### `SmileGuideView`
- Opening the screen does not count; completion is recorded only after the started timer finishes.
- This screen must never turn on the camera, and notification taps must keep landing here.

### `LiveSmileMonitorView`
- The camera starts only after the user taps start on this screen — not on appear, and never from a notification.
- The camera view is off by default and resets to off every session. Do not persist the toggle, and do not open the screen with a face already on it.
- Build the preview only while the toggle is on, so turning it off costs nothing. Draw the running session with `ARSCNView`; never hand-convert `ARFrame.capturedImage`, and never add a capture/save button.
- `ARSCNView` may take over the session delegate, which would silently stop the sample stream. `LiveSmileCameraPreview` calls back so the monitor can re-assert it — keep that path if you touch either file.
- Nothing is persisted, with or without the camera view showing. This screen has no repository and must not gain one; live usage is not a completion.
- Stop the session and restore `isIdleTimerDisabled` on every exit path — close, `onDisappear`, scene inactive, background, and failure.
- Coming back from the background shows a restart button; it never resumes the camera on its own.
- Quality problems (face lost, not facing the camera, too dark) take priority over the level, and the meter empties while they show.
- The camera view is never mirrored — it shows what the camera sees.
- When `nudgeCount` changes, show the `Smile!` cue briefly and post an accessibility announcement. The haptic and notification are the view model's job, not the view's.
- Do not show a numeric score. Levels exist because a per-frame number is busy and reads as a verdict.
- The user does not need to be centred in frame — the check is whether they are looking toward the camera. Keep the copy consistent with that.
- The privacy line "카메라 사용 중 · 영상과 점수는 저장하지 않아요" stays visible for the whole session.
- Accessibility: the score is not a frequently-updating live region; announce only quality-state and feedback-stage changes. Reduce Motion drops the gauge interpolation.

## Dependencies
- CoachingKit: `SmileCue`, `SmileGuideViewModel`, `SmileMomentRepository`, `LiveSmileMonitorViewModel`, `LiveSmileMonitoring`.
- `Services/ARKitLiveSmileMonitor` for the ARKit boundary.
- Shared `Theme.swift` and `SharedStrings.swift`.
