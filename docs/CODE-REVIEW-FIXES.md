# Satori Cockpit — Code Review Fix Specs

> Generated: Feb 26, 2026 | Source: iOS/macOS crew review + API contract audit

---

## FIX-001: Unit Test Coverage (Critical)

**Problem:** 5% test coverage (247 lines across 5 files). Core business logic — ViewModels, services, risk calculations — has zero tests.

**Scope:**
- `AppViewModel` — test refresh cycle, error aggregation, CLI dispatch
- `HomeViewModel` — test derived state (engine state text, market status, colors)
- `RESTClient` — test URL construction, error mapping, query param encoding (mock URLSession)
- `WebSocketService` — test reconnect backoff, message routing, disconnect cleanup
- `ArtifactStore` — test directory scanning, metrics parsing, diff calculation
- `SettingsStore` — test persistence, default fallback, URL construction edge cases
- `CLIService` — test process spawning, output streaming, timeout behavior

**Target:** 60%+ line coverage on non-View code.

**Implementation:**
- Add `SatoriTests/ViewModels/` directory
- Use protocol-based injection (protocols already exist) for mock services
- Add `MockRESTClient`, `MockWebSocketService` conforming to existing protocols
- Test error paths — decode failures, network timeouts, malformed JSON

**Effort:** 2-3 days

---

## FIX-002: REST Client Retry + Timeout (Critical)

**Problem:** REST calls fire once with no retry. Network blip = stale UI until manual refresh.

**Scope:** `RESTClient.swift`

**Implementation:**
- Add configurable retry policy: `maxRetries: Int = 2`, `backoffBase: TimeInterval = 1.0`
- Add request timeout: `timeoutInterval: TimeInterval = 10.0`
- Retry on 5xx and network errors only (not 4xx)
- Expose per-endpoint error state to ViewModels for inline UI feedback
- Add `CancellationToken` support so refresh doesn't stack

**Effort:** 0.5 day

---

## FIX-003: CLI Process Timeout (Critical)

**Problem:** `CLIService.run()` spawns a `Process` with no hard timeout. A hung backtest blocks the UI forever.

**Scope:** `CLIService.swift`

**Implementation:**
- Add `timeout: TimeInterval = 300` parameter to `CLIRequest`
- Start a `Task.sleep` race alongside process execution
- On timeout: `process.terminate()`, emit `.timeout` event, set `exitCode = -1`
- UI: show elapsed timer on running commands, red timeout banner

**Effort:** 0.5 day

---

## FIX-004: Concurrency Safety Audit (Critical)

**Problem:** `AppViewModel` is `@MainActor` but spawns tasks that mutate shared state. `RESTClient` is an actor but callers may not properly isolate access.

**Scope:** All ViewModels + Services

**Implementation:**
- Audit every `Task { }` block for `@MainActor` isolation
- Ensure `@Published` properties are only mutated on MainActor
- Replace any remaining Combine `sink` closures with `@MainActor`-isolated `receive(on:)`
- Add `@Sendable` annotations where closures cross isolation boundaries
- Run Thread Sanitizer in Xcode Scheme → Diagnostics

**Effort:** 1 day

---

## FIX-005: Surge Paper Config Stop Loss Bug (Bug)

**Problem:** `paper.toml` has `stop_loss_pct = 5.0` and `take_profit_pct = 7.0` for Surge. Code uses these as fractions (`entry * (1.0 - stop_loss_pct)`), so 5.0 = 500% = never fires.

**Scope:** `~/github/satori/configs/paper.toml`

**Fix:**
```toml
stop_loss_pct = 0.05    # was 5.0 (500% — never fires)
take_profit_pct = 0.07  # was 7.0 (700% — never fires)
```

**Effort:** 5 minutes

---

## FIX-006: Strategy State Enum Exhaustiveness (Important)

**Problem:** Server emits freeform state strings. Swift `switch` statements don't handle unknown values — will crash or show blanks.

**Scope:** `InazumaDesignSystem.swift`, `StrategiesView.swift`, `HomeView.swift`

**Implementation:**
- Define `StrategyState` enum with `init(rawValue:)` that maps known strings and falls back to `.unknown`
- Use `.unknown` case with neutral styling (gray dot, "UNKNOWN" label)
- Same pattern for `EngineSeverity`, `AlertSeverity`

**Effort:** 0.5 day

---

## FIX-007: Artifact Scanning Performance (Important)

**Problem:** `ArtifactStore.indexRuns()` does recursive filesystem scan on the UI thread. Large `runs/` directory will freeze the app.

**Scope:** `ArtifactStore.swift`

**Implementation:**
- Move scan to background actor
- Add in-memory cache with file watcher (`DispatchSource.makeFileSystemObjectSource`) for invalidation
- Paginate results (load 50 most recent, lazy-load older)
- Show skeleton rows during scan

**Effort:** 1 day

---

## FIX-008: Color-Blind Accessibility (Important)

**Problem:** P&L uses red/green only. 8% of male users can't distinguish.

**Scope:** `InazumaDesignSystem.swift`, all views using `pnl_color`

**Implementation:**
- Add directional indicators alongside color: ▲/▼ arrows, +/- prefix
- Use shape differentiation: filled circle for profit, outline for loss
- Add SF Symbols: `arrow.up.right` (green), `arrow.down.right` (red)
- Optional: `accessibilityAddTraits(.isHeader)` on key metrics
- Test with Xcode Accessibility Inspector color filters

**Effort:** 0.5 day

---

## FIX-009: Hardcoded Default Paths (Important)

**Problem:** `AppSettings.default` contains `/Users/jpp5q/Documents/GitHub/satori/...` paths.

**Scope:** `AppModels.swift`

**Implementation:**
- Replace with runtime resolution: `FileManager.default.homeDirectoryForCurrentUser`
- Check common locations: `~/Documents/GitHub/satori`, `~/github/satori`, `~/.local/share/satori`
- Show "not found" warning in Settings if resolved path doesn't exist
- Add first-run setup assistant that asks for engine location

**Effort:** 0.5 day

---

## FIX-010: WebSocket Error Visibility (Important)

**Problem:** Decode errors on WS messages are silently swallowed to keep connection alive. Repeated contract mismatches go unnoticed.

**Scope:** `WebSocketService.swift`

**Implementation:**
- Add `decodeErrorPublisher: AnyPublisher<Error, Never>`
- Count consecutive decode errors; after 5, surface banner: "Dashboard contract mismatch — check engine version"
- Log raw message snippet (first 200 chars) on decode failure for debugging
- Reset counter on successful decode

**Effort:** 0.5 day

---

## FIX-011: Settings URL Validation (Nice-to-have)

**Problem:** Port field accepts any string. Host field allows malformed URLs that silently produce `nil` URLs.

**Scope:** `SettingsView.swift`, `AppModels.swift`

**Implementation:**
- Validate port range (1-65535) with inline error
- Test URL construction on every edit, show green checkmark or red X
- Add "Test Connection" button that pings `/health` endpoint
- Disable Save/Apply if URL is invalid

**Effort:** 0.5 day

---

## FIX-012: Schema Versioning (Nice-to-have)

**Problem:** No version field in API contract. Breaking server changes cause silent decode failures.

**Scope:** Server (`dashboard/server.py`) + Client (`APIModels.swift`)

**Implementation:**
- Server: add `"api_version": "1.0"` to `/api/status` response
- Client: check version on first successful status fetch
- If major version mismatch: show persistent banner "Engine API v2.x — update Cockpit app"
- Store last-known-good version for change detection

**Effort:** 0.5 day (both sides)
