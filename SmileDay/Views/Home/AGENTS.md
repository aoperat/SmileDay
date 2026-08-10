<!-- Parent: ../AGENTS.md -->
<!-- Updated: 2026-07-29 -->

# Home

## Purpose
Frequency dashboard plus a neutral monthly completion history. The home keeps today's count, next reminder, recent seven-day counts, and the single “지금 한 번 웃기” action; the recent-seven-days card opens history.

## Key Files
| File | Description |
|------|-------------|
| `SmileMVPHomeView.swift` | Frequency dashboard, settings navigation, and smile-guide presentation |
| `SmileHistoryView.swift` | Monthly completion calendar, month summary, and selected-day count |

## For AI Agents
- Backed by `SmileHomeViewModel`, `SmileMomentRepository`, and `SmileReminderScheduleRepository`.
- History is backed by `SmileHistoryViewModel`; keep zero-count days neutral and do not add streaks, grades, or intensity scales.
- Notification taps open the same short guide as the manual action.
- Missed days remain neutral; do not add failure or guilt language.
