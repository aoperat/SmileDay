<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-24 | Updated: 2026-07-24 -->

# CoachingKit

## Purpose
Local Swift package containing everything platform-independent in SmileDay: SwiftData `@Model` classes, repositories, `@Observable` view models, and the cue/schedule value types behind the reminder → short smile → completion loop. Imports only Foundation, Observation, and SwiftData — no ARKit or SwiftUI. The package also targets macOS (14+) solely so `swift test` runs on the Mac without an iOS simulator.

## Key Files
| File | Description |
|------|-------------|
| `Package.swift` | Package manifest: iOS 17 / macOS 14, one library target `CoachingKit` + test target |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `Sources/` | Package source (see `Sources/AGENTS.md`) |
| `Tests/` | XCTest suite (see `Tests/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- This is where **all new logic goes, with tests**. The app target only wraps platform APIs.
- Keep the package free of ARKit/SwiftUI imports; the app plugs into the one protocol defined here (`ReminderScheduling`).
- Several `@Model` types are compatibility-only — kept so existing stores still open, never read by the UI. See `Sources/CoachingKit/AGENTS.md` before touching persistence.
- Public API surface throughout (`public` types) — the app target consumes this as a library.

### Testing Requirements
```bash
cd CoachingKit && swift test                      # full suite, runs on macOS
cd CoachingKit && swift test --filter <ClassName> # one test class
```
Suite is XCTest-based: verify `Test Suite 'All tests' passed` in output (the trailing "0 tests in 0 suites" line is the Swift Testing runner, not a failure).

### Common Patterns
- Side-effecting boundaries are protocols with a production impl (UserDefaults / app-provided) and an `InMemory` test impl in-package.
- Persistence is forward-compatible: new `@Model` fields are optional with nil defaults, and failable inits silently drop unknown data (see `ReminderNotificationPayload`).

## Dependencies

### Internal
- Consumed by the app target (`SmileDay/`); protocols here are implemented by `SmileDay/Services/`.

### External
- Foundation, Observation, SwiftData only.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
