# Satori Cockpit Delivery Operating Model

## Branch and Worktree Model

- `main` remains protected and releasable.
- Every train starts from `origin/main`.
- Train branch format: `codex/trainX-integration`.
- Pod branch format: `codex/trainX-pod-<lane>-<scope>`.
- Train 1 branch set:
- `codex/train1-integration`
- `codex/train1-pod-a-reliability`
- `codex/train1-pod-b-quality`
- `codex/train1-pod-c-ux`

## Weekly Train Cadence

1. Monday
- Cut train branches and worktrees from `origin/main`.
- Confirm scope IDs and handoff packets.
2. Tuesday to Thursday
- Pod implementation on pod branches.
- Rebase each pod branch onto `codex/trainX-integration` daily.
3. Friday AM
- Merge pod PRs into `codex/trainX-integration`.
- Run full build + tests + sanitizer pass.
4. Friday PM
- Merge integration PR to `main` if all gates pass.

## Mandatory PR Rules

1. Pod branches only target `codex/trainX-integration`.
2. No direct pod-to-main merges.
3. Integration branch is the only branch allowed to target `main`.
4. Required checks before integration-to-main merge:
- macOS build passes
- macOS tests pass
- No unresolved P0/P1 defects
- Documentation updated for delivered scope IDs

## Required Handoff Packet Fields

Each pod handoff must include:

1. Scope IDs (`FIX-###`, `FEAT-###`)
2. Absolute file ownership list
3. Planned API/interface/type changes
4. Required test additions
5. Acceptance criteria
6. Non-goals

## External Dependency Handling

- App-only scope is the default for this repo.
- Server/config dependencies are tracked as blockers:
- `EXT-FIX-005`: paper config percentage semantics
- `EXT-FIX-012`: API versioning response field
- Blockers are linked to affected app tickets but do not block unrelated app deliveries.

## Build and Test Gates

### Build

```bash
xcodebuild \
  -project /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/Satori.xcodeproj \
  -scheme Satori \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
  build
```

### Test

```bash
xcodebuild \
  -project /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/Satori.xcodeproj \
  -scheme Satori \
  -destination 'platform=macOS' \
  test
```

### Sanitizer (local pre-merge)

- Run Thread Sanitizer in Xcode scheme diagnostics on integration branch before Friday merge.
