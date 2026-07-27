<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-24 -->

# docs (app)

## Purpose
The bulk of SmileDay's feature documentation: Korean design specs, implementation plans, and analytical reports. Specs and plans pair 1:1 per feature (`YYYY-MM-DD-<feature>-design.md` in `specs/` ↔ `YYYY-MM-DD-<feature>.md` in `plans/`).

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `superpowers/specs/` | Design specs — the "what/why": Korean, header (날짜/상태/배경), goals, Swift type sketches |
| `superpowers/plans/` | Implementation plans — the "how": Korean body with English structural headers (Goal/Task N/Step), `- [ ]` checkboxes, named files, verification commands |
| `reports/` | Dated Korean analytical/status reports (`YYYY-MM-DD-<topic>.md`) with metadata header (작성일/기준 commit/목적) |

## For AI Agents

### Working In This Directory
- Before extending a feature, read its spec in `superpowers/specs/` — key product constraints (e.g. health-claim wording rules, ARKit vs Vision engine choice) are recorded there.
- Keep the `YYYY-MM-DD-` filename prefix and the spec↔plan pairing when adding new feature docs.
- A second, English-language plans tree exists at repo root `docs/superpowers/plans/` for newer UI work.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
