<!-- Parent: ../AGENTS.md -->
<!-- Updated: 2026-07-29 -->

# Onboarding

## Purpose
Explain the frequency-first purpose and let the user set one daily reminder window with a repeating interval. No camera permission or baseline capture is used.

## Key Files
| File | Description |
|------|-------------|
| `SmileMVPOnboardingView.swift` | Purpose introduction and initial reminder schedule |

## For AI Agents
- Default to 09:00–21:00 every 3 hours.
- A denied notification permission must not block app use.
- Situation labels and facial evaluation do not belong in this flow.
