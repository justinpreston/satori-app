# Train 1 Tracker

## Branches

- Integration: `codex/train1-integration`
- Pod A: `codex/train1-pod-a-reliability`
- Pod B: `codex/train1-pod-b-quality`
- Pod C: `codex/train1-pod-c-ux`

## Weekly Cadence Checklist

### Monday

- [x] Sync baseline from `origin/main`
- [x] Create worktrees and train branches
- [x] Publish handoff packets for Pods A/B/C
- [ ] Open draft PRs from each pod branch to integration branch

### Tuesday to Thursday

- [ ] Pod A daily rebase to integration
- [ ] Pod B daily rebase to integration
- [ ] Pod C daily rebase to integration
- [ ] Mid-week build and test sanity on integration

### Friday AM

- [ ] Merge Pod A PR
- [ ] Merge Pod B PR
- [ ] Merge Pod C PR
- [ ] Run full build + test matrix
- [ ] Run sanitizer verification

### Friday PM

- [ ] Open integration PR to `main`
- [ ] Confirm all merge gates passed
- [ ] Merge to `main`
- [ ] Document carry-over to Train 2

## External Blockers (App-only scope)

- [ ] EXT-FIX-005 created and linked
- [ ] EXT-FIX-012 created and linked

## Notes

- App-only execution remains default for train completion.
- Server/config dependencies are tracked, not implemented in this repository.
