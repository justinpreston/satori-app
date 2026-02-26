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
- [x] Open draft PRs from each pod branch to integration branch

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

- [x] EXT-FIX-005 created and linked
- [x] EXT-FIX-012 created and linked

## Live Links

- Pod A Draft PR: https://github.com/justinpreston/satori-app/pull/1
- Pod B Draft PR: https://github.com/justinpreston/satori-app/pull/2
- Pod C Draft PR: https://github.com/justinpreston/satori-app/pull/3
- Pod A Tracking Issue: https://github.com/justinpreston/satori-app/issues/7
- Pod B Tracking Issue: https://github.com/justinpreston/satori-app/issues/8
- Pod C Tracking Issue: https://github.com/justinpreston/satori-app/issues/9
- External Blocker EXT-FIX-005: https://github.com/justinpreston/satori-app/issues/4
- External Blocker EXT-FIX-012: https://github.com/justinpreston/satori-app/issues/5

## Notes

- App-only execution remains default for train completion.
- Server/config dependencies are tracked, not implemented in this repository.
