<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-24 -->

# Home

## Purpose
The 홈 tab dashboard: today/yesterday smile-size arc gauge with a check-in CTA, a rolling 7-day streak smile curve, weekly stat cards, and contextual nudge cards (set up reminders; re-capture an overdue baseline). Launch pad into a coaching session.

## Key Files
| File | Description |
|------|-------------|
| `HomeView.swift` | `HomeView` + reusable components `ArcGaugeView`, `WeekStreakCard`, `ReminderNudgeCard`, `StatCard`, private `ReminderSheet`; presents the reminder sheet and a baseline re-capture `fullScreenCover` |

## For AI Agents

### Working In This Directory
- Backed by `HomeViewModel` (CoachingKit), constructed in `.onAppear` from `SessionRepository`; nudge visibility comes from `ReminderNudge`/`BaselineResetNudge` with UserDefaults state stores.
- `onStartCoaching` closure switches the tab to 코칭 — don't navigate directly.
- Baseline re-capture reuses `Onboarding/BaselineCaptureView` via `fullScreenCover`; on save it bubbles `onBaselineUpdated` up to `RootView`.

### Testing Requirements
View logic untested; keep logic in `HomeViewModel` (tested in CoachingKitTests). Verify UI changes with `xcodebuild`.

## Dependencies

### Internal
- CoachingKit: `HomeViewModel`, `SessionRepository`, `ReminderNudge`, `BaselineResetNudge`, `ScoreCalculator`; `Theme.swift` tokens; `Settings/ReminderListView` (wrapped in the reminder sheet).

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
