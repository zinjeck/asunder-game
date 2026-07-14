# Paladin Decision Log

This file records architectural decisions and their reasons. It is not a
duplicate of the code or a task tracker.

## 2026-07-14 — Named configuration at high-risk boundaries

Status: Accepted

APIs that receive many confusable configuration or state values use a named
`Dictionary` with required-key and type validation. This applies at setup,
save/founding, and multi-value behavior-request boundaries. It does not apply
automatically to every function with five parameters: short-lived rendering,
generation, and validation helpers keep typed positional parameters when a
dictionary would add allocations in a hot loop or weaken useful type checks.

Applied in this pass to `DebugPanel.setup`, `MapTextureCache.setup`, world-save
locking, city founding, workplace-production state writes, citizen task
activity state writes, work-activity tile choice, and work-dwell requests.

## 2026-07-14 — Debug panel minimize and dependent layout

Status: Accepted

`DebugPanel` owns minimize/expand state, dragging, and the reusable panel
layout. It reports header/content rectangles so dependent controls do not use
coordinates tied to one panel size. The minimize button uses
`MOUSE_FILTER_STOP`; therefore its click cannot propagate into the parent drag
handler and no duplicate manual hit test is needed.

The city citizen-debug UI lives in
`scripts/ui/debug/CitizenDebugPanel.gd`. It owns its button, list panel,
visibility state, signal connections, and layout. `CityRenderer` supplies only
the citizen text callback and asks the component to refresh.

## 2026-07-14 — Incremental CityRenderer decomposition

Status: Accepted

`CityRenderer.gd` is being reduced incrementally rather than rewritten. Region
markers provide immediate navigation. The citizen-debug UI was extracted
first because it was already a self-contained subsystem. Workplace-zone cache
and texture painting is the next extraction candidate, but it remains in place
until that move can be tested independently.

## 2026-07-14 — Development logging policy

Status: Accepted

Use `push_error` for failures that prevent correct behavior and `push_warning`
for recoverable invariant or data problems. Use `print` only for intentional
development/action feedback; noisy progress logging must be conditional on
`WorldData.debug_mode_enabled`. Do not relabel successful actions as warnings.

## 2026-07-14 — Dev-region ocean lookup

Status: Existing decision recorded

Dev-region validation uses an ocean prefix sum so each candidate-region query
is constant time after one preprocessing pass. The superseded per-tile scan is
not retained as a second implementation.
