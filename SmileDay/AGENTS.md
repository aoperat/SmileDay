<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-24 -->

# SmileDay (app target)

## Purpose
The iOS app target: SwiftUI views and platform services. Contains no business logic — view models, repositories, and persistence live in the `CoachingKit` package. This layer builds the frequency-first UI, implements local notifications and the optional live-monitor camera boundary, and wires everything together in `SmileDayApp`.

## Key Files
| File | Description |
|------|-------------|
| `SmileDayApp.swift` | `@main` App — wires AppDelegate via adaptor, reads the shared container from `PersistenceController`, hosts `RootView` with `ko_KR` locale, injects `NotificationRouter` into the environment |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `Views/` | Splash, onboarding, home, smile guide, and settings screens (see `Views/AGENTS.md`) |
| `Services/` | Local notifications and notification-tap routing (see `Services/AGENTS.md`) |
| `Assets.xcassets/` | App icons (light/dark/tinted) and asset catalog |
| `docs/` | Korean design specs, implementation plans, and reports (see `docs/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- The project uses folder-synchronized groups, so a new `.swift` file needs no `project.pbxproj` edit. Build settings (for example `INFOPLIST_KEY_*`) still do, in **both** Debug and Release.
- Do not put logic here that could live in CoachingKit; views should delegate to package view models.
- The core loop never requests camera access. Only the optional live-monitor mode does, and only after the user explicitly starts it — see the guardrails in the repo-root `AGENTS.md`.

### Testing Requirements
No automated tests for this target. Verify with:
```bash
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build
```

### Common Patterns
- Views lazily construct their CoachingKit view model in `.onAppear` from `@Environment(\.modelContext)`-backed repositories.
- Only `NotificationRouter` is shared via SwiftUI environment; everything else is constructed per-view.

## Dependencies

### Internal
- `CoachingKit` package (models, view models, repositories, protocols).

### External
- SwiftUI, SwiftData, UserNotifications.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
