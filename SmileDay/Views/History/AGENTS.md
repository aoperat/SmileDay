<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-27 -->

# History

## Purpose
The 기록 tab: read-only activity view over saved check-ins — streak / month days / moment-note summary tiles, a 7-day Swift Charts bar chart of smile-time counts, a tappable monthly "웃어본 날" calendar, per-time-bucket counts for the selected day, and the list of saved moments.

No scores, degree units, or day-over-day comparisons.

## Key Files
| File | Description |
|------|-------------|
| `HistoryView.swift` | `HistoryView` + `SummaryTile`, `MonthHeatmapView`, private `MomentRow`, `EmptyStateView` |

## For AI Agents

### Working In This Directory
- Backed by `HistoryViewModel` (CoachingKit); all aggregation (`recentActivity`, month day-set, streak, `bucketCounts(onDayOf:)`, `recentMoments`) belongs in the VM.
- The y-axis counts smile times as integers. Never reintroduce a score axis or color-by-score comparison.
- Records saved before the reflection fields existed have nil mood/note; the calendar and activity counts must still render for them.
- Empty states invite an action without implying failure.
- This is the only screen using Swift Charts; chart axes render Korean because the app pins `ko_KR`.

### Testing Requirements
Aggregation tested via `HistoryViewModelTests`. Verify views with `xcodebuild`.

## Dependencies

### Internal
- CoachingKit: `HistoryViewModel`, `SmileDayActivity`, `SmileMomentEntry`, `SessionRepository`, `TimeBucket`; `Theme.swift`.

### External
- Swift Charts.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
