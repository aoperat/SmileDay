<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-27 -->

# Home

## Purpose
The 홈 tab dashboard: today's smile-time status (prompt + CTA, or completion state with the latest moment note), a rolling 7-day smile curve, week stat cards ("이번 주 웃어본 날" / "남긴 좋은 순간"), and a reminder nudge card. Launch pad into a smile time.

No scores are shown here.

## Key Files
| File | Description |
|------|-------------|
| `HomeView.swift` | `HomeView` + reusable components `WeekStreakCard`, `ReminderNudgeCard`, `StatCard`, private `ReminderSheet` |

## For AI Agents

### Working In This Directory
- Backed by `HomeViewModel` (CoachingKit), constructed in `.onAppear` from `SessionRepository`; nudge visibility comes from `ReminderNudge` with a UserDefaults state store.
- `onStartCoaching` closure switches the tab to 미소 — don't navigate directly.
- The hero shows today's prompt from `ReminderPromptCatalog`, picked by day so it stays stable within a day.
- The 4-week baseline recapture nudge was removed from home (it existed for score accuracy). The manual path lives in Settings.
- Missed days in the 7-day curve render grey only — no failure icons or warning colors.

### Testing Requirements
View logic untested; keep logic in `HomeViewModel` (tested in CoachingKitTests). Verify UI changes with `xcodebuild`.

## Dependencies

### Internal
- CoachingKit: `HomeViewModel`, `SessionRepository`, `ReminderNudge`, `ReminderPromptCatalog`, `TimeBucket`; `Theme.swift` tokens; `Coaching/SaveConfirmView` (`SunFaceView`); `Settings/ReminderListView` (wrapped in the reminder sheet).

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
