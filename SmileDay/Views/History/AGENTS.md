<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-24 -->

# History

## Purpose
The 기록 tab: read-only analytics over saved check-ins — streak/month/7-day-average summary tiles, a weekly Swift Charts bar trend, a tappable monthly check-in heatmap, and per-time-bucket smile scores for the selected day.

## Key Files
| File | Description |
|------|-------------|
| `HistoryView.swift` | `HistoryView` + `SummaryTile`, `MonthHeatmapView` |

## For AI Agents

### Working In This Directory
- Backed by `HistoryViewModel` (CoachingKit); all aggregation (weekly scores, month day-set, streak, `bucketScores(onDayOf:)`) belongs in the VM.
- This is the only screen using Swift Charts; chart axes render Korean because the app pins `ko_KR`.

### Testing Requirements
Aggregation tested via `HistoryViewModelTests`. Verify views with `xcodebuild`.

## Dependencies

### Internal
- CoachingKit: `HistoryViewModel`, `SessionRepository`, `TimeBucket`; `Theme.swift`.

### External
- Swift Charts.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
