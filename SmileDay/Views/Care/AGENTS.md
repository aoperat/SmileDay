<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-27 -->

# Care (쉬어가기)

## Purpose
The 쉬어가기 tab: browse/filter short pause-and-breathe content from the bundled catalog, surface a recommendation based on the time of day, and play a practice step-by-step, logging completions and abandonments.

Filenames still say "Care" so Xcode project references stay intact, but the domain types are `SmilePractice*`.

## Key Files
| File | Description |
|------|-------------|
| `CareView.swift` | Practice list + `RecommendationCard`, `CategoryChips`, `PracticeRow`, favorite toggles; launches `CarePlayerView` and records the result |
| `CarePlayerView.swift` | Full-screen guided player + `CarePlayResult`, `StepHeroView`, `StepRow`: optional bundled mp4 or gradient step-hero with countdown ring, per-step timer, "다음 단계로/마치기"; returns the play result to `CareView` |

## For AI Agents

### Working In This Directory
- Backed by `SmilePracticeViewModel` (CoachingKit): the catalog is `SmilePractice.catalog` (in-package, not persisted); completions/abandons persist as `CareSession` via `CareRepository`; favorites via `UserDefaultsSmilePracticeFavorites`.
- Recommendations come from the time bucket and whether the user already rested today — **never** from facial metrics or scores. Recommendation logic belongs in `SmilePracticeViewModel`.
- Categories describe intent (`pause`/`recall`/`breathe`/`connect`), not facial areas. Content must not promise muscle, lymph, puffiness, symmetry, or score changes.
- New practice IDs use the `smile-` prefix so they cannot collide with legacy `CareSession.routineID` values. Legacy favorites are ignored for display via `visibleFavoriteIDs` but never erased from UserDefaults.
- Practice videos are bundled mp4 resources referenced by filename in the catalog; a missing video falls back to the gradient step-hero.

### Testing Requirements
Logic tested via `SmilePracticeViewModelTests`/`SmilePracticeTests`/`CareRepositoryTests` in the package. Verify views with `xcodebuild`.

## Dependencies

### Internal
- CoachingKit: `SmilePracticeViewModel`, `SmilePractice`, `CareRepository`, `TimeBucket`; `Theme.swift`.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
