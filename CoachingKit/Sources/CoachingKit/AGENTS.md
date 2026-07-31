<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-29 -->

# CoachingKit (sources)

## Purpose
All package source: SwiftData models, value types, repositories, `@Observable` view models, and the notification-scheduling protocol the app target implements. Flat directory — organization is by naming and dependency cluster, not folders.

The core product is one loop: **repeating reminder → non-judgmental cue → short smile → save the completion time → see today's and the last seven days' counts.** That loop never uses the camera and stores no facial data.

A second, optional mode ("실시간 미소 확인") adds a real-time mouth-corner signal. Its platform-independent half lives here; the ARKit session lives in the app target. It persists nothing.

## Key Files

### Active models
| File | Description |
|------|-------------|
| `SmileMoment.swift` | `@Model` one completed smile: `date`, `guideID`, `sourceRawValue` (+ `SmileMomentSource` = manual/notification/notificationAction). Stores no facial data |
| `SmileReminderSchedule.swift` | `@Model` the single repeating schedule: window start/end, `intervalMinutes`, `isEnabled`, `notificationGroupID`; `pattern` bridges to `SmileReminderPattern` |

### Compatibility-only models (never read by the UI)
Kept solely so an existing user's store still opens. Do not add product logic to them, and do not change their stored properties without a versioned migration design.

| File | Description |
|------|-------------|
| `Baseline.swift` | `@Model` old reference capture (mouth corners, browTension, lighting, angle) |
| `CheckInSession.swift` | `@Model` old scored check-in; `payload`/`payloadVersion` retained verbatim |
| `CareSession.swift` | `@Model` old care-routine playback record |
| `ReminderSetting.swift` | `@Model` old per-time reminder; only `notificationID` is still used, for cancelling |
| `CustomSmileCard.swift` | `@Model` old user-made situation card; `slotRawValue` is stored verbatim and never interpreted |

### Value types
| File | Description |
|------|-------------|
| `SmileCue.swift` | `SmileCue` (id + text) and `SmileCueCatalog.all` — 8 Korean non-judgmental cues. This is the only user-facing guide copy |
| `SmileGuide.swift` | Minimal run unit: `id` + `durationSeconds`; `SmileGuideCatalog.default` is the single guide (`"anytime-soft"`, 5s) |
| `SmileReminderPattern.swift` | `ReminderTime` (validated hour/minute), `SmileReminderPattern` (window + interval, `allowedIntervals`, `.recommended` = 09:00–21:00/180m), `occurrences()` |
| `ReminderNotificationPayload.swift` | Notification `userInfo` round-trip; parses the current shape and the legacy `bucket`/`promptText` shape, returns nil otherwise |
| `SDPalette.swift` | Raw design-token hex values + WCAG luminance/contrast helpers, so contrast is testable (the app target has no test bundle) |
| `LiveSmileSample.swift` | One live frame narrowed to what the signal needs: two mouth-corner coefficients, gaze-offset degrees, optional ambient light. No blend-shape dictionary, no image |
| `LiveSmileMonitoring.swift` | `LiveSmileMonitorEvent` (sample / faceLost / permissionDenied / unsupportedDevice / sessionFailed) and the `@MainActor` session protocol the app implements |

### Live mode logic
| File | Description |
|------|-------------|
| `LiveSmileSignalEvaluator.swift` | Pure calculation: mouth-corner mean, neutral-relative 0–1 signal over `displaySpan`, gaze check against `gazeToleranceDegrees`, darkness check. Clamps everything; asymmetry never subtracts. Also defines `LiveSmileLevel`, whose bands are deliberately **not** equal quarters (0 / 0.10 / 0.30 / 0.60) |
| `LiveSmileGaze.swift` | Pure geometry: how far the face's forward direction is from the direction of the camera. Position never enters the result |
| `LiveSmileMonitorViewModel.swift` | `@Observable` session state: 2s neutral calibration from valid frames only, exponential smoothing, ≤10 publishes/sec, quality-issue priority over the level, hysteresis on level boundaries, resting-time nudges, `recalibrate()`/`stop()` |
| `LiveSmileNudge.swift` | `LiveSmileNudgeSettings` (enabled / interval / haptic) with UserDefaults + InMemory stores, and the `LiveSmileNudging` boundary the app implements with haptics and a local notification |
| `LiveSmileSessionRecorder.swift` | `LiveSmileObservation` 3-state, one-second buckets decided by majority vote, unknown-filled gaps, and `LiveSmileSessionSummary` (ratio over usable time only) |

### Repositories (thin wrappers over `ModelContext` — own all FetchDescriptors)
| File | Description |
|------|-------------|
| `PersistenceSchema.swift` | The SwiftData model list — **all seven models**, active and compatibility-only. Register new `@Model`s here |
| `SmileMomentRepository.swift` | Save/fetch completions; `count(onDayOf:)`, `recentSevenDays(endingOn:)` → `[SmileDayCount]`, `weekActiveDayCount(endingOn:)` |
| `SmileReminderScheduleRepository.swift` | Fetch/save the one current `SmileReminderSchedule` |
| `LegacyReminderRepository.swift` | Read-only: `pendingNotificationIDs()` for cancelling notifications an older build scheduled. No create/update/delete |

### @Observable view models (constructor DI, injected `now: () -> Date` + `Calendar`)
| File | Description |
|------|-------------|
| `SmileHomeViewModel.swift` | Today's count, seven-day total and per-day counts, next reminder time. No score, streak-loss, or day-over-day comparison |
| `SmileGuideViewModel.swift` | One guide run: `ready → running(remainingSeconds:) → completed`; saves exactly once on completion, saves nothing on cancel. Clock injected via `SmileGuideClock` |
| `SmileReminderScheduleViewModel.swift` | Edits and saves the repeating schedule, then cancels legacy notification IDs — **only after** the save succeeds |
| `SmileOnboardingState.swift` | `SmileOnboardingViewModel` (confirm / skip) + `SmileOnboardingStoring` with UserDefaults and InMemory stores |

### Cue cycling
| File | Description |
|------|-------------|
| `SmileCueCursorStore.swift` | `SmileCueCursorStoring` (UserDefaults + InMemory) and `SmileCueSelector.next()` for non-repeating cue rotation |

### Protocols the app target implements
| File | Description |
|------|-------------|
| `ReminderScheduling.swift` | `requestAuthorization()`, `currentAuthorizationStatus()`, `scheduleDailyPattern(groupID:times:)`, `cancelGroup(id:)`, `cancel(id:)`; defines `reminderRollingWindowDays = 14`, used only to rebuild the identifiers an old build created |
| `LiveSmileMonitoring.swift` | `onEvent`, `start()`, `stop()`. Duplicate start/stop are no-ops and no event may arrive after `stop()` |

## For AI Agents

### Working In This Directory
- New `@Model` types must be added to `PersistenceSchema.models` or they won't persist.
- **Never remove a compatibility model or rename/retype its stored properties.** Dropping one breaks store opening for existing users; that needs its own versioned-migration design first.
- `SmileGuideCatalog.default.id` (`"anytime-soft"`) is a persisted value — saved `SmileMoment.guideID`s and already-scheduled notification payloads contain it. Do not change it.
- The protocol has no default implementations, so every test fake must implement all five methods; make fakes record calls rather than silently dropping them.
- View models never touch SwiftData directly — go through a repository.
- No stored scores, no appearance/emotion claims. A day with zero smiles is neutral, not a failure.
- `LiveSmileMonitorViewModel` deliberately has no repository dependency. Do not give it one — the live mode must stay unable to persist anything. `LiveSmileNudgeSettings` is stored, but it is a user preference and never holds a measurement.
- The nudge timer sums frame-to-frame deltas and ignores gaps larger than `maxNudgeFrameGap`, so it pauses by construction whenever frames stop (face lost, off-camera, dark). Do not replace it with a wall-clock start date — that would count time the user was away and fire the moment they return.
- Keep the live boundary narrow: if the signal does not need a value, it must not enter `LiveSmileSample`.
- The view model exposes `level`, never a number. The 0–1 signal is an internal precision unit; showing it as a score reintroduces exactly the busyness levels were meant to remove.
- `LiveSmileLevel` bands are intentionally uneven — narrow at the bottom so leaving a resting face registers immediately, wide at the top so nobody is pushed to smile harder. Do not "tidy" them into quarters.
- `gazeOffsetDegrees` is the angle from the face's forward direction to the direction of the camera — not head pose in world space. That is what makes off-centre seating fine; comparing against a fixed axis would flag a user who is looking straight at the camera from the side. `LiveSmileGazeTests` pins this: sitting well off to the side must still read ~0° while facing the camera.
- `gazeToleranceDegrees` is deliberately generous (40°): recognition matters more than precision here. A tighter gate silently kills the whole mode for someone glancing at a propped phone — and it also freezes the nudge timer, so they get no reminder either. Narrow it only with device evidence.
- `LiveSmileSessionRecorder` sums nothing to disk and holds no images — CoachingKit imports no UIKit. Do not add snapshot timing or image requests; the per-minute snapshot feature was removed on 2026-07-31.
- The ratio denominator is usable time, not total time. Changing it to total time would report time away from the camera as time not smiling.

### Testing Requirements
Every file here should have a same-named test in `Tests/CoachingKitTests/`. Run `cd CoachingKit && swift test --filter <ClassName>Tests`.

### Common Patterns
- Every side-effecting boundary is a protocol with UserDefaults production + InMemory test implementations in-package.
- Injected `now: () -> Date` and `Calendar` for deterministic time-based tests.
- Korean comments and all user-facing strings; `Sendable` value types; `public` API surface.

## Dependencies

### Internal
Active chain: `SmileReminderScheduleViewModel` → schedule repository + `ReminderScheduling` (+ `LegacyReminderRepository` for cancellation); `SmileGuideViewModel` → `SmileMomentRepository`; `SmileHomeViewModel` → both repositories. Compatibility models have no inbound references outside `PersistenceSchema` and the migration tests.

### External
- Foundation, Observation, SwiftData only. No ARKit/SwiftUI imports — keep it that way.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
