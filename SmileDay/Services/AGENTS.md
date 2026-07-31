<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-24 -->

# Services

## Purpose
Platform services for local-notification scheduling, notification-tap routing, and the optional live-monitor camera boundary.

## Key Files
| File | Description |
|------|-------------|
| `AppDelegate.swift` | `UIApplicationDelegate` + `UNUserNotificationCenterDelegate` — owns the `NotificationRouter`, registers the reminder notification category, splits taps from the two action buttons, records "웃었어요" without opening the app, shows foreground banners |
| `NotificationRouter.swift` | `@Observable` router holding `pendingSmileGuide` and `recordedWithoutGuideCount` — parses notification `userInfo` and publishes tap/record signals to the home screen |
| `PersistenceController.swift` | The app's single SwiftData `ModelContainer`, held outside the view hierarchy so a background-only launch can reach it |
| `UserNotificationReminderScheduler.swift` | `ReminderScheduling` impl over `UNUserNotificationCenter` — requests authorization, schedules the repeating daily times as one group, and cancels both that group and identifiers an older build created |
| `ARKitLiveSmileMonitor.swift` | `LiveSmileMonitoring` impl over `ARSession` — checks TrueDepth support and camera permission, then reports `LiveSmileSample` (two mouth-corner coefficients, head angles, ambient light) and session/permission events |

## For AI Agents

### Working In This Directory
- Keep these classes thin: schedule math, cue selection, and payload types live in CoachingKit; services only adapt platform APIs to those types.
- Notification deep-link flow: the scheduler stamps each notification with `ReminderNotificationPayload` → `AppDelegate` forwards taps → `NotificationRouter` sets `pendingSmileGuide` → `SmileMVPHomeView` opens the short guide. The home screen only checks that the payload parsed; it does not read its ID fields.
- Notification action flow: the scheduler stamps `ReminderNotificationCategory.identifier` on each notification → `AppDelegate` registers the matching `UNNotificationCategory` at launch → long-pressing the notification shows "웃었어요" / "가이드 열기". Only the second carries `.foreground`; the first must never gain it, because not opening the app is the entire point of the feature.
- **A background action handler cannot give feedback.** `UIFeedbackGenerator` is a documented no-op unless the app is foreground-active (confirmed by an Apple Frameworks engineer), so do not add a haptic to `recordSmileWithoutOpeningTheApp` — it will silently do nothing. The notification disappearing is the confirmation, same as Reminders' "완료로 표시". If explicit feedback is ever wanted, the only options are a follow-up local notification or an app-icon badge.
- That handler reaches SwiftData through `PersistenceController.shared`, not the environment. A notification-action launch never builds `WindowGroup`'s body, so the view hierarchy's container does not exist yet.
- Notification identifier formats are a compatibility contract with builds already installed on devices. `cancelGroup(id:)` clears the `<groupID>-daily-HHmm` space, and `cancel(id:)` clears the old `<id>-<dayOffset>` space using `reminderRollingWindowDays`. Changing either format strands notifications that keep firing. The same applies to `ReminderNotificationAction` raw values and the category identifier — notifications already scheduled on devices carry them.
- `ARKitLiveSmileMonitor` owns the only `ARSession` in the app. For the sample stream it reads `frame.lightEstimate`, the camera transform, and two blend shapes — not `frame.capturedImage`. It requests camera permission only when the user has explicitly started the mode, and delivers events on the main queue per the `LiveSmileMonitoring` contract.
- `frame.capturedImage` is never read. There is no method here that converts a frame to an image, and adding one would give the app a still-image path it deliberately does not have (see the live-mode guardrails in the root `AGENTS.md`).
- It exposes `previewSession` so the optional camera view can draw the session that is already running, and `reassertSampleDelegate()` because `ARSCNView` may claim `session.delegate` and silently kill the sample stream. Neither is a hook for reading frames — the preview draws the live session and keeps nothing.
- `NSCameraUsageDescription` lives in `project.pbxproj` as `INFOPLIST_KEY_NSCameraUsageDescription` in **both** Debug and Release; the app has no checked-in `Info.plist`.

### Testing Requirements
Not unit-tested (platform-bound). Verify with the app build:
```bash
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build
```
Logic worth testing should be pushed down into CoachingKit behind the protocols.

## Dependencies

### Internal
- Implements `ReminderScheduling` from CoachingKit and uses `ReminderNotificationPayload`.

### External
- UserNotifications, UIKit.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
