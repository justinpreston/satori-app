# Satori Cockpit — Feature Roadmap

> Generated: Feb 26, 2026 | Phases ordered by impact × effort

---

## Phase 2A: API Surface Expansion (Week 1-2)

The engine exposes **40+ endpoints**. The app consumes **8**. This phase wires up the most valuable missing data.

### FEAT-001: Equity Curve Chart

**Endpoint:** `GET /api/equity_history` → `[{timestamp, equity}]`

**Spec:**
- Add `Charts` framework dependency (Swift Charts, macOS 13+)
- Line chart with area fill below
- Overlay drawdown periods as shaded red regions
- Time range selector: 1D / 1W / 1M / All
- Tooltip on hover: exact equity + timestamp + daily P&L
- Place on Home dashboard below metric cards
- Auto-update on each WS snapshot (append latest equity point)

**Design:**
- Chart height: 200pt in default mode, expandable to 400pt
- Drawdown shading: `InazumaPalette.red.opacity(0.15)`
- Current equity line: `InazumaPalette.cyan`
- Grid lines: `InazumaPalette.separator.opacity(0.3)`
- Y-axis: dollar amounts, right-aligned
- X-axis: adaptive labels (hours for 1D, dates for 1W+)

**Models:**
```swift
struct EquityPoint: Decodable, Identifiable {
    var id: Date { timestamp }
    let timestamp: Date
    let equity: Double
}
```

**Effort:** 2 days

---

### FEAT-002: Execution Analytics Panel

**Endpoint:** `GET /api/execution` → slippage, latency, fill/rejection rates

**Spec:**
- New sidebar section: "Execution" (icon: `bolt.fill`)
- Cards: avg slippage (bps), avg latency (ms), fill rate %, rejection count
- Slippage distribution histogram (bucket by 1 bps)
- Latency sparkline over time
- Per-strategy breakdown table

**Design:**
- Slippage card: green if < 3 bps, amber 3-10, red > 10
- Latency card: green if < 100ms, amber 100-500ms, red > 500ms
- Use monospaced metrics per Inazuma spec

**Effort:** 1.5 days

---

### FEAT-003: Shadow Mode Dashboard

**Endpoints:** `GET /api/shadow`, `POST /api/admin/shadow/enable`, `POST /api/admin/shadow/disable`

**Spec:**
- Add Shadow toggle in Risk panel (disabled in Phase 1 — now enable)
- Show shadow vs live fill comparison: slippage delta, timing delta
- Drift alert when shadow diverges from live by > threshold
- Shadow-only mode indicator in toolbar

**Design:**
- Shadow data rendered with dashed borders to distinguish from live
- "Shadow Active" pill in toolbar: purple tint
- Drift warning: inline amber banner with bps divergence

**Effort:** 1.5 days

---

### FEAT-004: Correlation Matrix Heatmap

**Endpoint:** `GET /api/correlation` → strategy pair correlation values

**Spec:**
- Add to Risk panel as expandable section
- NxN grid of strategy pairs
- Color scale: blue (negative) → white (zero) → red (positive)
- Click cell → show historical correlation timeseries (future)
- Alert badge when any pair > `correlation_threshold` from config

**Design:**
- Cell size: 40x40pt minimum
- Font: SF Mono 10pt for values
- Diagonal: grayed out (self-correlation = 1.0)
- Threshold breach cells: bold border + pulsing dot

**Effort:** 1.5 days

---

### FEAT-005: Alpha Lab & Factory Panels

**Endpoints:** `GET /api/lab/status`, `/api/lab/proposals`, `/api/lab/analyses`, `/api/lab/drift`, `/api/lab/capital`, `GET /api/factory/status`, `/api/factory/candidates`, `/api/factory/runs`

**Spec:**
- New sidebar section: "Alpha Lab" (icon: `flask.fill`)
- Proposal list with status badges (pending, approved, rejected)
- Mutation analysis results with composite scores
- Drift detection timeline
- Capital allocation view
- Factory candidate promotion flow with approve/reject actions

**Design:**
- Proposal cards: show hypothesis, expected Sharpe, composite score
- Status flow: `Proposed → Analyzed → Backtested → Promoted / Rejected`
- Use Kanban-style columns for pipeline visualization
- Approve/reject: confirmation sheet with rationale text field

**Effort:** 3 days

---

## Phase 2B: Trader Productivity (Week 2-3)

### FEAT-006: Keyboard Shortcuts

**Spec:**
- `⌘R` — Refresh all data
- `⌘1` through `⌘7` — Navigate sidebar sections
- `⌘,` — Open Settings (already standard)
- `⌘K` — Quick action palette (search commands, strategies, symbols)
- `↑↓` — Navigate table/list rows
- `Space` — Toggle selected strategy detail
- `⌘⇧K` — Kill switch (with confirmation)
- `Escape` — Dismiss sheets/popovers

**Implementation:**
- Use `.commands { CommandGroup { } }` in `SatoriApp.swift`
- Add `KeyboardShortcut` to toolbar buttons
- Quick action palette: modal `TextField` with filtered command list

**Effort:** 1 day

---

### FEAT-007: Menu Bar Widget

**Spec:**
- Persistent menu bar extra showing: equity + daily P&L% + engine status dot
- Click to expand: compact summary (5 lines)
  - Equity: $XXX,XXX (+X.XX%)
  - Positions: N open
  - Risk: DD X.X% | Daily +X.X%
  - Engine: Running | WS: Connected
  - Kill Switch: ○ Clear / ● ACTIVE
- "Open Cockpit" button → activates main window
- "Quick Kill Switch" → confirmation alert → POST /api/admin/kill-switch
- Updates via same WebSocket connection

**Implementation:**
- `MenuBarExtra` with `isInserted` binding
- Share `AppViewModel` between main window and menu bar
- Separate `MenuBarView.swift` in `Features/MenuBar/`

**Design:**
- Menu bar icon: custom Satori glyph (or 🔮 emoji as placeholder)
- Status dot: green/amber/red next to equity
- Compact layout: 240pt wide popover

**Effort:** 1.5 days

---

### FEAT-008: macOS Notifications

**Spec:**
- Push local notifications for:
  - Kill switch triggered (critical)
  - PDT count at 2/3 used (warning)
  - Correlation breach detected (warning)
  - Daily loss > 50% of limit (warning)
  - Strategy state change (info)
  - Trade fills (info, optional — toggleable)
- Notification categories with actions: "Open Cockpit", "Dismiss"
- Respect Do Not Disturb / Focus mode
- Deduplicate: same alert type suppressed for 5 minutes (match server dedup window)

**Implementation:**
- `UNUserNotificationCenter` with category registration
- Subscribe to WS alerts + REST risk polling
- Settings toggle per notification type
- Store notification preferences in `SettingsStore`

**Effort:** 1 day

---

### FEAT-009: Position Detail Popover

**Spec:**
- Click any position row → popover with:
  - Entry price, current price, P&L ($, %)
  - Days held
  - MFE / MAE (max favorable/adverse excursion)
  - Strategy that opened it
  - Stop price / target price
  - Entry time
- "Close Position" button (future — when admin API supports it)

**Design:**
- Popover width: 320pt
- Section dividers between entry info, P&L, and risk
- MFE/MAE as horizontal bar relative to entry price
- Use `.popover(isPresented:)` anchored to row

**Effort:** 1 day

---

### FEAT-010: Guidance Panel

**Endpoint:** `GET /api/guidance` → PositionGuidance events (HOLD/CLOSE/ROLL recommendations)

**Spec:**
- New section in Risk panel or standalone sidebar item
- Show per-position guidance with conviction score
- Recommendations: HOLD (green), CLOSE (red), ROLL (amber)
- If `position_manager.enabled = true`: show auto-execution status
- If disabled: show as advisory-only with manual action buttons

**Design:**
- Card per position with guidance badge
- Conviction bar: 0-100% horizontal progress
- Sorted by conviction descending (highest-conviction recommendations first)

**Effort:** 1 day

---

## Phase 2C: Advanced Risk & Operations (Week 3-4)

### FEAT-011: Kill Switch Confirmation Modal

**Spec:**
- Current: toolbar button fires immediately
- New: `⌘⇧K` or button → modal sheet with:
  - Current portfolio state (equity, positions count, unrealized P&L)
  - Warning text: "This will flatten ALL positions and halt trading"
  - Confirmation: type "KILL" to confirm (like destructive ops)
  - Cancel button (default focused)
- POST to `/api/admin/kill-switch` on confirm
- Log to audit trail

**Design:**
- Sheet: 480x300pt, centered
- Red header bar
- Destructive button style: `.borderedProminent` + `.tint(.red)`

**Effort:** 0.5 day

---

### FEAT-012: Infrastructure Status Panel

**Endpoint:** `GET /api/infrastructure` → task statuses, feed health, OMS rate

**Spec:**
- Add to Home dashboard or dedicated section
- Show: Databento feed status, EventRecorder status, OMS queue depth
- Task list with last-run timestamps and health indicators
- OMS rate limiter state from `/api/oms/rate`

**Design:**
- Traffic light indicators per subsystem
- "Last healthy" timestamp with relative time ("2 min ago")

**Effort:** 1 day

---

### FEAT-013: Multi-Account View

**Endpoint:** `GET /api/accounts` → per-account equity, risk, positions

**Spec:**
- Account switcher in toolbar or sidebar header
- Per-account risk limits displayed independently
- Aggregate view: combined equity across all accounts
- Account-specific position and trade filtering

**Design:**
- Account selector: segmented control or dropdown
- Account badge colors for visual differentiation
- Aggregate mode: stacked equity chart

**Effort:** 2 days

---

### FEAT-014: Walk-Forward Visualization

**Endpoint:** `GET /api/strategies/{name}/walk_forward` → fold-by-fold results

**Spec:**
- Add to Strategy detail view
- Show walk-forward folds as timeline
- Per-fold: in-sample Sharpe, out-of-sample Sharpe, degradation %
- Highlight folds where OOS Sharpe < threshold
- Overall walk-forward ratio with pass/fail indicator

**Design:**
- Horizontal timeline with fold segments
- Green segments: passed validation
- Red segments: failed
- Tooltip per fold with detailed metrics

**Effort:** 1.5 days

---

### FEAT-015: OMS Queue Monitor

**Endpoint:** `GET /api/oms/rate` → queue depth, rate limit state, rejected orders

**Spec:**
- Live queue depth gauge in Infrastructure or Home
- Alert when queue > 50% of `oms_queue_depth` config
- Show rate-limited order count
- Backpressure indicator: green/amber/red

**Design:**
- Circular gauge or vertical bar showing queue fill level
- Orders/second throughput metric

**Effort:** 0.5 day

---

## Phase 3: Polish & Distribution (Week 4+)

### FEAT-016: Keychain Integration

**Spec:**
- Store API keys, engine credentials in macOS Keychain
- Migrate from `UserDefaults` for sensitive fields
- Use `Security` framework `SecItemAdd`/`SecItemCopyMatching`
- Prompt for Keychain access on first use
- Support Touch ID / Apple Watch unlock for extra security

**Effort:** 1 day

---

### FEAT-017: First-Run Setup Assistant

**Spec:**
- On first launch (no saved settings): wizard flow
  1. "Where is your Satori engine?" → file picker or URL entry
  2. Auto-detect: scan common paths, test `/health` endpoint
  3. "Test connection" → green checkmark
  4. "Configure notifications" → toggle categories
  5. "Ready to go" → open Home

**Effort:** 1 day

---

### FEAT-018: Export & Sharing

**Spec:**
- Export equity curve as PNG/PDF
- Export trade log as CSV
- Export risk report as PDF
- Share via macOS share sheet
- Copy metrics to clipboard (formatted for Telegram/Slack)

**Effort:** 1 day

---

### FEAT-019: App Sandbox & Notarization

**Spec:**
- Enable App Sandbox entitlements
- Network client entitlement for engine communication
- File access: read-only to runs directory (user-selected)
- Code sign with Developer ID
- Notarize for Gatekeeper
- DMG distribution with drag-to-Applications

**Effort:** 1 day

---

## Roadmap Summary

| Phase | Items | Effort | Priority |
|-------|-------|--------|----------|
| **Fixes** | FIX-001 through FIX-012 | ~8 days | 🔴 Before any features |
| **2A: API Expansion** | FEAT-001 through FEAT-005 | ~10 days | 🟡 High value |
| **2B: Trader UX** | FEAT-006 through FEAT-010 | ~5.5 days | 🟡 High impact |
| **2C: Advanced** | FEAT-011 through FEAT-015 | ~5.5 days | 🟢 After paper validation |
| **3: Polish** | FEAT-016 through FEAT-019 | ~4 days | 🔵 Pre-distribution |

**Total estimated effort:** ~33 days of development

**Recommended sprint plan:**
- **Sprint 1 (Week 1):** FIX-001 through FIX-005 (critical fixes + config bug)
- **Sprint 2 (Week 2):** FIX-006 through FIX-012 + FEAT-006 (keyboard shortcuts)
- **Sprint 3 (Week 3):** FEAT-001 (equity chart) + FEAT-002 (execution) + FEAT-007 (menu bar)
- **Sprint 4 (Week 4):** FEAT-003 (shadow) + FEAT-004 (correlation) + FEAT-008 (notifications)
- **Sprint 5+:** Remaining features prioritized by paper trading needs
