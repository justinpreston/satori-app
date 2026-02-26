# Satori macOS Mockups v2

## 1. Visual System Definition

### Color Tokens

- `accent`: Use system accent (`Color.accentColor`) for primary emphasis, focused controls, selected rows.
- `background/base`: Window background (`NSColor.windowBackgroundColor`).
- `background/raised`: Elevated pane/card background (`NSColor.controlBackgroundColor`).
- `separator`: Divider and hairline borders (`NSColor.separatorColor`).
- `text/primary`: Primary text (`NSColor.labelColor`).
- `text/secondary`: Secondary metadata (`NSColor.secondaryLabelColor`).
- `text/muted`: Tertiary/supporting text (`NSColor.tertiaryLabelColor`).
- `status/success`: `NSColor.systemGreen`.
- `status/warning`: `NSColor.systemOrange`.
- `status/error`: `NSColor.systemRed`.

Light and dark mode are fully dynamic through system semantic colors.

### Typography Scale

- Window title: SF Pro 20 semibold
- Section heading: SF Pro 13 semibold
- Body: SF Pro 13 regular/medium
- Secondary metadata: SF Pro 12 regular
- Monospaced metric value: SF Mono 12-28 semibold/bold
- Caption/helper: SF Pro 11 regular

### Spacing System

- Base grid: 8pt
- Compact spacing: 4pt
- Standard control group spacing: 8pt
- Section spacing: 16pt
- Window content inset: 20pt
- Sidebar padding: 14pt
- Inspector section spacing: 12pt

### Component Rules

- Toolbar: keep global actions (`Refresh`, connectivity state) in toolbar trailing group.
- Sidebar rows: 36pt target row height, selected rows use subtle accent-tinted background.
- Cards/surfaces: 12pt corner radius, 1px separator stroke, minimal shadow only on hover/elevation.
- Table/list rows: preserve readable density and avoid stacked card rows where table semantics are better.
- Inputs: rounded rect with semantic background and separator border.
- Empty states: `ContentUnavailableView` with one primary CTA.
- Error states: inline red status text near failing section plus retry action in toolbar.

## 2. Screen Specs

## Mockup A: Main Dashboard Window (Sidebar + Metrics Table + Inspector)

### Layout Breakdown

- Region 1: Toolbar (top)
- Region 2: Sidebar navigation (left, min 220, ideal 260)
- Region 3: Main content (center, min 720)
- Region 4: Inspector panel (right, min 300, ideal 340)
- Region 5: Optional footer status strip

Collapse priorities:
1. Inspector collapses first
2. Sidebar collapses second
3. Main content remains primary region

### Component Inventory

- Toolbar: `Refresh`, run/action menu, engine status, WS latency, issue banner text
- Sidebar: section list (`Home`, `Strategies`, `Runs`, `Risk`, `Universe`, `Settings`) + compact account summary
- Content (Dashboard): metric summary row, live metrics `Table`, recent alerts list
- Inspector: selected row details, risk posture, quick actions

### Alignment and Rhythm Rules

- Left-align headings and first column baselines.
- Keep card/table gutters aligned on an 8pt grid.
- Use fixed numeric column widths for price/percent/PnL fields.

### State Variants

- Default: neutral semantic background with separator strokes
- Hover: subtle raised background and stronger separator contrast
- Active/selected: accent-tinted fill + accent leading cue in sidebar/table
- Focused: macOS focus ring on text fields/primary interactive controls
- Disabled: 55-65% opacity text and controls
- Loading: skeleton row placeholders for table, dimmed inspector placeholders

### Empty State

- Title: "No live metrics yet"
- Message: "Connect to engine and refresh to populate live telemetry."
- Primary CTA: `Refresh`
- Secondary CTA: `Open Settings`

### Error State

- Inline section message at top of content pane: `Risk endpoint unavailable`
- Recovery actions: `Retry` in toolbar, `Open Settings` as secondary

## Mockup B: Strategy Workspace (Master/Detail)

### Layout Breakdown

- Left pane: searchable strategy list with segmented sort control
- Right pane: detail with configuration summary, gate status, runs list
- No persistent inspector; detail pane owns inspection

### Component Inventory

- Search field in toolbar-style container
- Segmented control for sorting
- Strategy list rows with state pill + Sharpe value
- Detail sections: Header, Gate Status, Equity preview, Config summary, Recent runs, Artifacts

### Alignment and Rhythm Rules

- Maintain single vertical axis in detail pane.
- Keep section headers 16pt above section body.
- Ensure list row metadata aligns to trailing timestamps.

### State Variants

- Selected row: accent background tint + left 3px accent marker
- Hover row: raised fill and clearer border
- Focused search: standard macOS focus ring
- Empty selection: `ContentUnavailableView`

### Empty State

- "Select a strategy"
- "Choose a strategy from the list to inspect health and run history."

### Error State

- Detail header warning line when strategy detail is missing.
- Keep list usable even if detail endpoint fails.

## Mockup C: Settings Window

### Layout Breakdown

- Dedicated settings window using grouped `Form`
- Sections: Engine Connection, Paths, Reconnect, Validation
- Min width 520, min height 420

### Component Inventory

- Text fields for host/port/paths
- Picker for scheme
- Stepper or numeric field for reconnect values
- Validation summary rows with state color and helper copy

### Alignment and Rhythm Rules

- Follow form row label/value alignment.
- Use grouped section spacing; avoid card-within-card layering.

### State Variants

- Focused form field: ring and higher contrast border
- Invalid value: inline error text + red semantic tint
- Disabled actions until required fields validate

### Empty State

- Not applicable

### Error State

- Per-field inline validation messages
- Preserve prior valid values until user confirms save

## 3. Interaction Details

- Hover behavior: only interactive rows/surfaces raise slightly; no glow.
- Focus rings: rely on native macOS rings for fields and key controls.
- Keyboard navigation:
- `Command+R` refreshes data.
- Arrow keys navigate sidebar/list/table selections.
- `Command+,` opens settings.
- Motion:
- Selection/hover transitions: 120-160ms ease out.
- Avoid ambient background animation and decorative motion.

## 4. SwiftUI Mapping

### Mockup A Mapping

- Window shell: `NavigationSplitView`
- Sidebar: `List(selection:)`
- Content metrics: `VStack` + `Grid` or `LazyVGrid`
- Live metrics: `Table`
- Inspector: `.inspector(isPresented:)` with contextual detail view
- Toolbar: `.toolbar { ToolbarItemGroup(...) }`
- Commands: `.commands` for refresh/settings shortcuts

### Mockup B Mapping

- Split region: `HSplitView` or second-level `NavigationSplitView`
- Strategy list: `ScrollView` + `LazyVStack` (or `List` if row actions are simple)
- Detail sections: `VStack` + semantic section headers
- Empty state: `ContentUnavailableView`

### Mockup C Mapping

- Settings window: `Settings { Form { Section { ... } } }`
- Inputs: `TextField`, `Toggle`, `Picker`, `Stepper`
- Validation: inline `Text` with semantic foreground style and helper labels

## 5. Implementation Notes

- Preserve existing view-model/data flow; refine only visual tokens and UI composition.
- Move from hardcoded hex palette to semantic system-backed color tokens for true light/dark support.
- Remove forced dark mode and heavy decorative background effects.
- Keep monospaced typography for metrics/logs while shifting labels/body to SF Pro defaults.
- Replace glow-heavy elevation with subtle separators + restrained shadows.
