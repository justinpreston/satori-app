# Train 1 Handoff: Pod A (Reliability/Core Services)

## Scope IDs

- FIX-002: REST client retry + timeout
- FIX-003: CLI process timeout
- FIX-004: concurrency safety audit (service/viewmodel boundaries)
- FIX-010: WebSocket decode error visibility

## Owned Files (Absolute)

- /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/Satori/Core/Services/RESTClient.swift
- /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/Satori/Core/Services/CLIService.swift
- /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/Satori/Core/Services/WebSocketService.swift
- /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/Satori/Features/App/AppViewModel.swift
- /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/Satori/Core/Services/Protocols.swift
- /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/Satori/Core/Models/CLIModels.swift

## Required API/Type Changes

1. `CLIRequest`
- Add `timeoutSeconds: TimeInterval = 300`.
2. `CLIOutputEvent`
- Add timeout event variant and elapsed duration payload.
3. `WebSocketServiceProtocol`
- Add `decodeErrorPublisher` for surfaced decode errors.
4. `RESTClient` behavior surface
- Add retry policy (`maxRetries`, `backoffBase`, request timeout) with sensible defaults.

## Required Tests

- REST retries on transient network/5xx only.
- REST does not retry on 4xx.
- CLI timeout terminates process and emits timeout event.
- WS decode error threshold produces observable signal.
- AppViewModel surfaces decode/retry related failures without main-thread mutation warnings.

## Acceptance Criteria

1. Refresh cycle does not stack overlapping network refreshes.
2. REST calls time out and retry deterministically on allowed failures.
3. Hung CLI command exits with timeout state and non-success exit semantics.
4. Repeated WS decode failures become user-visible via app banner path.
5. No new actor-isolation or Sendable warnings in touched files.

## Non-Goals

- No UI redesign work.
- No server-side API schema changes.
- No feature roadmap work outside FIX-002/3/4/10.
