<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-31 -->

# docs

## Purpose
Every document in the project: design specs, implementation plans, analytical reports, and marketing assets. The Korean feature docs moved here from `SmileDay/docs/` on 2026-07-31.

**This tree must stay outside `SmileDay/`.** That directory is a `PBXFileSystemSynchronizedRootGroup`, so anything under it is picked up automatically as an app resource — the docs tree and a marketing PNG were being copied into `SmileDay.app` until the move. The project file has no `membershipExceptions`, so location is the only protection.

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `superpowers/specs/` | Design specs — the "what/why": Korean, header (날짜/상태/배경), goals, Swift type sketches |
| `superpowers/plans/` | Implementation plans — the "how": Korean body with English structural headers (Goal/Task N/Step), `- [ ]` checkboxes, named files, verification commands |
| `reports/` | Dated Korean analytical/status reports (`YYYY-MM-DD-<topic>.md`) with metadata header (작성일/기준 commit/목적) |
| `marketing/` | Store and social assets. Never referenced from app code |

## Key Files
| File | Description |
|------|-------------|
| `english-copy-deck.md` | Proposed English copy and the tone rules behind it. Not wired into the app — the first release is Korean |

## For AI Agents

### Working In This Directory
- Before extending a feature, read its spec in `superpowers/specs/` — key product constraints (health-claim wording, the live mode's no-image rule, ARKit vs Vision engine choice) are recorded there.
- Keep the `YYYY-MM-DD-` filename prefix and the spec↔plan pairing when adding new feature docs.
- Most documents are Korean; a few older UI plans (care-icon timer hero, launch splash message) are English. Both live here.
- Record a superseded decision as a dated revision section at the top of the original spec rather than rewriting its body. Why something was built matters even after it is removed.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
