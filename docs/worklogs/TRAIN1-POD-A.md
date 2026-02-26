# Train 1 Pod A Worklog (Reliability)

## Scope

- FIX-002 REST retry/timeout
- FIX-003 CLI timeout handling
- FIX-004 concurrency safety audit
- FIX-010 WebSocket decode error visibility

## Implementation Checklist

- [ ] Add retry policy and timeout support in REST client
- [ ] Add timeoutSeconds to CLIRequest and timeout event in CLIOutputEvent
- [ ] Emit and subscribe to decode errors from WebSocketService
- [ ] Update AppViewModel banner/error handling for reliability events
- [ ] Add/adjust tests for all reliability scenarios

## Risks

- Actor isolation regressions while adding cancellation and timeout paths
- Behavior drift across existing command log flows

## Notes

- Rebase daily onto `codex/train1-integration`.
