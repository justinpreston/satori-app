# Train 1 Handoff: Pod C (UX/Product Surface)

## Scope IDs

- FIX-006: resilient strategy/engine/alert state enums
- FIX-008: color-blind accessible status indicators
- FIX-009: remove hardcoded local default paths
- FIX-011: settings URL/port validation + connection test affordance

## Owned Files (Absolute)

- /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/Satori/Core/Models/AppModels.swift
- /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/Satori/Features/Settings/SettingsView.swift
- /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/Satori/UI/InazumaDesignSystem.swift
- /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/Satori/Features/Home/HomeView.swift
- /Users/jpp5q/Desktop/ai-projects/Satori/SatoriCockpitApp/Satori/Features/Strategies/StrategiesView.swift

## Required API/Type Changes

1. Add resilient enums with unknown fallback:
- `StrategyState`
- `EngineSeverity`
- `AlertSeverity`
2. Update settings model to support validation outputs:
- host validity
- port range validity
- computed URL validity
3. Replace hardcoded default engine paths with runtime home-directory-based resolution.

## Required Tests

- Unknown strategy/engine/alert values render neutral fallback style and label.
- Invalid host/port combinations prevent save and show inline validation.
- Path defaults are generated from current user home, not hardcoded user names.
- Color-differentiated states also include non-color signal (symbol/prefix/shape).

## Acceptance Criteria

1. Unknown server state strings never crash and never render blank status.
2. Settings page provides immediate validation feedback and blocks invalid save.
3. Home/strategy metrics include directional indicators beyond color only.
4. Default settings are portable across machines without user-specific hardcoded paths.

## Non-Goals

- No roadmap feature work from FEAT-001 onward.
- No CLI/service retry implementation (Pod A scope).
- No CI/pipeline implementation (Pod B scope).
