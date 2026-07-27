<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-24 -->

# Settings

## Purpose
The 설정 tab (NavigationStack List): reminder management, baseline re-capture with age/recommendation, an on-device data-privacy explainer, and a placeholder account row.

## Key Files
| File | Description |
|------|-------------|
| `SettingsView.swift` | `SettingsView` + `SettingsRow`: links to reminder list and data location, baseline-reset row; presents baseline re-capture `fullScreenCover` |
| `ReminderListView.swift` | Reminder management + private `ReminderEditSheet`: one-tap suggested times for missing buckets, enable toggle, swipe-delete, add via DatePicker, time editing. Also reused by Home's reminder sheet |
| `DataLocationView.swift` | Static informational List: all data stays on-device (SwiftData), nothing transmitted, deleted with the app |

## For AI Agents

### Working In This Directory
- Backed by `SettingsViewModel` (CoachingKit), which wires reminder CRUD to `ReminderScheduling` (authorization + rolling 14-day window). Never schedule notifications directly from views.
- Baseline reset recommendation text comes from `Baseline.ageWeeks`/`isOverdueForReset` via the VM.
- `DataLocationView` copy is a privacy commitment — keep it accurate if persistence ever changes.

### Testing Requirements
Logic tested via `SettingsViewModelTests`/`ReminderRepositoryTests`. Verify views with `xcodebuild`.

## Dependencies

### Internal
- CoachingKit: `SettingsViewModel`, `ReminderRepository`, `TimeBucket`; Services: `UserNotificationReminderScheduler`; `Onboarding/BaselineCaptureView` (re-capture), `Theme.swift`.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
