# Train 1 Pod C Worklog (UX)

## Scope

- FIX-006 resilient state enums with unknown fallback
- FIX-008 color-blind accessibility signals
- FIX-009 portable default settings paths
- FIX-011 settings validation and test-connection affordance

## Implementation Checklist

- [ ] Add resilient enum wrappers and unknown handling in UI surfaces
- [ ] Add non-color indicators for status-sensitive metrics
- [ ] Replace user-specific hardcoded path defaults
- [ ] Add inline host/port/url validation in settings UI
- [ ] Add tests for fallback rendering and settings validation

## Risks

- Visual regressions in status-heavy screens
- Validation strictness causing false negatives for valid hosts

## Notes

- Rebase daily onto `codex/train1-integration`.
