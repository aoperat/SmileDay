<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-24 -->

# docs (repo root)

## Purpose
Repo-root documentation tree holding newer implementation plans written in English (UI-focused work such as care-icon timer hero and launch splash message). The bulk of feature docs — Korean plans, design specs, and reports — live in `SmileDay/docs/` instead; this root tree currently has plans only, with no matching `specs/`.

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `superpowers/plans/` | Implementation plans, `YYYY-MM-DD-<feature>.md`, English, task-checkbox format with named files and verification commands |

## For AI Agents

### Working In This Directory
- Every document is `YYYY-MM-DD-` prefixed; keep that convention.
- Plans follow the superpowers format: Goal / Architecture / Task N steps with `- [ ]` checkboxes and explicit verification commands (`swift test`, `xcodebuild`).
- When looking for a feature's design rationale, check `SmileDay/docs/superpowers/specs/` — root plans may not have a companion spec.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
