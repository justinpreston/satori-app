# Satori Cockpit (Standalone macOS Client)

Native macOS control plane for Satori.  
This app is a separate client project and does not run inside the engine repository.

## Phase 1 Scope

- Home command center with engine/WS status and core metrics.
- Strategy registry (`/api/strategies` + `/api/strategies/detail`).
- Runs and artifacts browser for `runs/YYYY-MM-DD/strategy/run_id/...`.
- Risk panel (`/api/risk` + `/api/risk/pdt`).
- Universe panel (`/api/universe`).
- Settings for local or remote engine endpoints.
- CLI-driven actions: `backtest`, `validate`, `promote`, and `monitor` (launches TUI in Terminal).
- `Start Shadow` is intentionally disabled in Phase 1.

## Requirements

- macOS 14+.
- Xcode 15+ (project deployment target is `14.0`).
- Reachable DashboardServer endpoint with `/ws` and `/api/*`.
- Installed `satori` CLI executable.

## Project Location

- App root: `/Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp`
- Xcode project: `/Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/Satori.xcodeproj`

## Build and Run

Open in Xcode:

```bash
open /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/Satori.xcodeproj
```

CLI build:

```bash
xcodebuild \
  -project /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/Satori.xcodeproj \
  -scheme Satori \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
  build
```

Run tests:

```bash
xcodebuild \
  -project /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/Satori.xcodeproj \
  -scheme Satori \
  -destination 'platform=macOS' \
  test
```

## First-Time Configuration

Go to `Settings` and configure:

- `API Scheme`: `http` or `https`
- `WebSocket Scheme`: `ws` or `wss`
- `Host`: DNS/IP (can include `host:port`)
- `Port`: integer only (`8780`, not `8,780`)
- `API Base Path` (optional)
- `WebSocket Path` (default `/ws`)
- `CLI path`
- `Engine root`
- `Runs root`
- reconnect base/max seconds

Defaults:

- API: `http://localhost:8780`
- WS: `ws://localhost:8780/ws`
- CLI path: `/Users/jpp5q/Documents/GitHub/satori/.venv/bin/satori`
- Engine root: `/Users/jpp5q/Documents/GitHub/satori`
- Runs root: `/Users/jpp5q/Documents/GitHub/satori/runs`

## Endpoint Contract Used by the App

REST:

- `/api/status`
- `/api/positions`
- `/api/trades?limit=50`
- `/api/risk`
- `/api/risk/pdt`
- `/api/strategies`
- `/api/strategies/detail`
- `/api/universe`

WebSocket:

- `/ws` snapshot messages (`DashboardSnapshot`)
- side-channel alert messages with `"type":"correlation_alert"`

## CLI Mapping

1. Backtest: `satori backtest run --strategy <name> --start <YYYY-MM-DD> --end <YYYY-MM-DD> --config <toml>`
2. Validate: `satori validate --result <result_json> --folds <n> --permutations <n>`
3. Promote: `satori promote <strategy> <returns_csv> <equity_csv> --config <toml> [--override]`
4. Monitor: launches Terminal and runs `satori monitor --url <ws-url>`

## Artifact Layout (Phase 1)

```text
runs/YYYY-MM-DD/strategy_name/run_id/
  metrics.json
  trades.csv
  equity.png
  run_metadata.json
  veto_summary.json
```

## Troubleshooting

### `The data couldn't be read because it isn't in the correct format`

This means one or more API responses did not decode to the expected contract.

- Check the top toolbar issue banner (example: `Refresh issues: status: ... | pdt: ...`).
- Verify endpoint payloads directly:

```bash
curl -s http://<host>:<port>/api/status | jq .
curl -s http://<host>:<port>/api/risk/pdt | jq .
curl -s http://<host>:<port>/api/strategies | jq .
curl -s http://<host>:<port>/api/strategies/detail | jq .
```

- Confirm JSON keys/types match the app models.
- If an endpoint is unavailable, the app keeps running and shows per-endpoint issues.

### WS connected but cards show `N/A`

- WebSocket connection can be healthy while REST endpoints fail decode.
- Use `Refresh` and inspect the issue banner for which endpoint failed.

### Port formatting

- Use raw integer ports only (`8780`).
- The settings UI renders ports without grouping separators.

### TUI launch fails

- Verify `CLI path` exists and is executable:

```bash
/Users/jpp5q/Documents/GitHub/satori/.venv/bin/satori --help
```

- Verify `Engine root` points to the intended working directory.

## Architecture

- UI: SwiftUI (`NavigationSplitView`)
- Pattern: MVVM
- Services: `WebSocketService`, `RESTClient`, `CLIService`, `ArtifactStore`, `SettingsStore`
- Adapter: `DashboardContractAdapter` (current payload shape + forward-compat hook)

## Notes

- Client supports local and remote servers configured by the user.
- App does not mutate engine state directly outside documented CLI actions.
- ATS/network config is permissive for Phase 1 to allow non-TLS endpoints; prefer `https` + `wss` for remote/internet environments.
