<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-24 -->

# Care

## Purpose
The 케어 tab: browse/filter guided facial-care routines from the bundled catalog, surface a recommendation based on the latest check-in insight, and play routines step-by-step, logging completions and abandonments.

## Key Files
| File | Description |
|------|-------------|
| `CareView.swift` | Routine list + `RecommendationCard`, `CategoryChips`, `RoutineRow`, favorite toggles; launches `CarePlayerView` and records the result |
| `CarePlayerView.swift` | Full-screen guided player + `CarePlayResult`, `StepHeroView`, `StepRow`: optional bundled mp4 or gradient step-hero with countdown ring, per-step timer, "다음 단계로/루틴 완료"; returns the play result to `CareView` |

## For AI Agents

### Working In This Directory
- Backed by `CareViewModel` (CoachingKit): routine catalog is `CareRoutine.catalog` (in-package, not persisted); completions/abandons persist as `CareSession` via `CareRepository`; favorites via `UserDefaultsCareFavorites`.
- The recommendation comes from the latest check-in's `InsightEngine` result mapped to a `CareCategory` — recommendation logic belongs in `CareViewModel`.
- Routine videos are bundled mp4 resources referenced by filename in the catalog; a missing video falls back to the gradient step-hero.

### Testing Requirements
Logic tested via `CareViewModelTests`/`CareRepositoryTests`/`CareRoutineTests` in the package. Verify views with `xcodebuild`.

## Dependencies

### Internal
- CoachingKit: `CareViewModel`, `CareRepository`, `CareRoutine`, `InsightEngine`; `Theme.swift`.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
