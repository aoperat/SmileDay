<!-- Parent: ../AGENTS.md -->
<!-- Updated: 2026-07-29 -->

# Settings

## Purpose
Edit the reminder window, repeat interval, and enabled state; show notification authorization and the on-device data-location commitment.

## Key Files
| File | Description |
|------|-------------|
| `SmileMVPSettingsView.swift` | Reminder schedule editor, system-settings link, and on-device privacy copy |

## For AI Agents
- Backed by `SmileReminderScheduleViewModel`; never schedule notifications directly from the view.
- “데이터 저장 위치” and other informational text must use explicit high-contrast palette colors.
- Keep the on-device privacy statement accurate if persistence ever changes.
