<!-- Parent: ../AGENTS.md -->
<!-- Updated: 2026-07-29 -->

# Home

## Purpose
Frequency dashboard: today's completion count, the next reminder, recent seven-day counts, and a single “지금 한 번 웃기” action.

## Key Files
| File | Description |
|------|-------------|
| `SmileMVPHomeView.swift` | Frequency dashboard, settings navigation, and smile-guide presentation |

## For AI Agents
- Backed by `SmileHomeViewModel`, `SmileMomentRepository`, and `SmileReminderScheduleRepository`.
- Notification taps open the same short guide as the manual action.
- Missed days remain neutral; do not add failure or guilt language.
