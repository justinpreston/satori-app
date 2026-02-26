# Train 1 Handoff: Pod B (Quality/Contracts)

## Scope IDs

- FIX-001: unit test coverage uplift for non-View code
- Train 1 CI bootstrap for macOS build + tests

## Owned Files (Absolute)

- /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/SatoriTests/*
- /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/.github/workflows/macos-ci.yml
- /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/Satori/Core/Services/Protocols.swift (test seams only)

## Required Additions

1. Test structure
- Add `SatoriTests/ViewModels/` test group.
- Add `SatoriTests/Mocks/` for protocol-conforming mocks.
2. Coverage target
- Raise non-View code line coverage to at least 60%.
3. CI
- Add GitHub Actions workflow for macOS build and test on PR and push to `main`.

## Required Tests

- `AppViewModel` refresh orchestration and error aggregation.
- `HomeViewModel` derived text/state logic.
- `SettingsStore` load/save fallback behavior.
- `RESTClient` URL/query/error handling with mocked session.
- `WebSocketService` reconnect and message-routing behavior.
- `ArtifactStore` indexing and diff calculations.
- `CLIService` event streaming and timeout behavior.

## Acceptance Criteria

1. CI gate runs automatically on GitHub.
2. Failing tests block merge by policy.
3. Coverage report demonstrates >=60% for non-View modules.
4. Test fixtures and mocks are deterministic and isolated.

## Non-Goals

- No runtime feature additions.
- No UI behavior changes except what is needed for testability.
- No server-side changes.
