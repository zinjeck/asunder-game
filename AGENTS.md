# Paladin Agent Operating Manual

This file is the durable operating manual for AI and coding agents working on Paladin. It describes project intent, responsibility boundaries, invariants, and safe working practices. It is deliberately not a prose copy of the current implementation. Read current code before changing it, and use `CURRENT_STATE.md` for the present checkpoint and `DECISION_LOG.md` for the history behind settled rules.

## 1. Project Identity

Paladin is a long-term strategy simulation game being built incrementally in Godot 4 with GDScript as the active primary language. The intended scope combines a generated world, local city simulation, persistent individual citizens, physical resources and logistics, workplaces and production, needs and schedules, and eventually multiple cities within larger political or imperial systems.

The project is in an early systems-first prototype stage. The current visuals are intentionally functional and programmatic; the central goal is to make state and simulation rules real before adding decorative behavior. Paladin is expected to grow for years and to support much larger simulations than the current prototype. A prior planning target was roughly 2,000 citizens per city, but that is a scale objective, not a measured guarantee.

Godot and GDScript remain the active development environment. A wholesale custom-engine or C++ rewrite is not the current plan. Portable, profiled hot loops may later move to C++ through GDExtension, but only when measurements and stable boundaries justify it.

## 2. Source of Truth

Use this precedence order whenever sources disagree:

1. The user's most recent explicit statement, correction, or accepted design decision.
2. A later chat change that the user confirmed was implemented or working.
3. The newest dated handoff, `CURRENT_STATE.md`, or applicable accepted entry in `DECISION_LOG.md`.
4. The current repository files for the code snapshot actually being inspected.
5. Older handoffs, transcripts, repository snapshots, plans, and assumptions.

The repository is the source of truth for the code snapshot currently checked out. An upload or GitHub copy is a baseline from the time it was captured; it may not contain later manual edits made during a conversation. Do not silently restore an older implementation merely because it is present in an old archive.

The user's latest explicit design decision can supersede both older documentation and an older snapshot. Conversely, documentation describes intended ownership and behavior; it does not prove that the current code implements that intent. Investigate any difference rather than forcing either side onto the other.

Observed runtime behavior in Godot is the final authority on whether an implementation works. Compiler errors, runtime errors, validator output, performance measurements, and reproducible user observations are evidence. A plausible-looking code review is not runtime verification.

When a conflict cannot be resolved by date or confirmation, preserve both claims, label the uncertainty, and ask the user before making a behavior-changing edit.

## 3. Working Relationship

The user owns the vision, simulation feel, visual judgment, gameplay priorities, runtime testing, and final acceptance. The user often applies surgical edits manually and usually expects subsequent work to build on edits that were previously instructed and not reported as reverted.

The AI owns code reasoning, repository navigation, dependency tracing, architecture analysis, implementation planning, safe code generation, and explicit test instructions. It should translate the user's desired behavior into coherent system changes without pretending that code alone proves visual or tactile quality.

The AI is not expected to claim visual or runtime verification unless it genuinely ran and observed the relevant build. When the user reports that a change works, treat that result as the current checkpoint unless later evidence shows a regression.

The user may restore missing context with transcripts, handoffs, diffs, screenshots, archives, or current files. Missing context is not proof that a prior decision never existed. If exact volatile code details are unavailable, ask for or inspect the newest file rather than reconstructing a function body from memory.

## 4. Editing Rules

### Inspect before editing

- Read the relevant portions of `CURRENT_STATE.md` and `DECISION_LOG.md`.
- Inspect the latest versions of every file that owns or consumes the behavior.
- Search for callers, readers, writers, signals, indexes, version counters, shared constants, and UI observers before changing a shared system.
- Search by conceptual terms as well as exact symbols. A responsibility may have moved during a refactor.
- Check `project.godot`, scene attachments, autoloads, and runtime entry points when scene lifecycle or global state is involved.

### Keep changes coherent and narrow

- Prefer the smallest coherent change that completely implements the requested behavior.
- Prefer surgical edits over whole-file replacement.
- Do not introduce unrelated cleanup or architecture changes during a focused bug fix.
- Do not force a stale snippet into a file that has evolved.
- If replacing an entire script is genuinely necessary, warn that the latest version of that script is required and verify it first.
- Preserve working behavior unless the task explicitly changes it.
- Avoid premature abstraction. Extract a shared responsibility when duplication or coupling is already real, not merely possible.
- Avoid duplicated world/city rules that will predictably drift. Shared map visuals, cache behavior, resource semantics, and simulation invariants should have one conceptual authority.

### Do not invent the repository

- Do not invent node paths, autoloads, files, methods, fields, signals, APIs, resources, scene structures, or input actions.
- Do not assume an uploaded snapshot includes later chat edits.
- Do not infer that an unused constant or stale temporary scene is an active feature.
- Do not make a current function signature into a permanent architectural contract unless it is intentionally public and documented as such.

### Write clear GDScript

- Prefer readable, typed GDScript where that is consistent with nearby code.
- Preserve deterministic integer or fixed-scale arithmetic for simulation quantities when practical. Paladin's current production model intentionally avoids fractional physical resources.
- Keep authoritative mutation behind clear state-owner operations. A renderer or panel should not directly rewrite unrelated simulation dictionaries.
- Maintain indexes, version counters, inverse relationships, capacities, and validators when mutating shared state.
- Fail closed when future data is present but its behavior is not implemented. For example, an input-consuming recipe must not create free output.

### Explain the edit precisely

- State what is being added, removed, or replaced.
- Identify every affected file and responsibility.
- Explain behavior changes separately from refactors.
- Give practical test steps and expected outcomes.
- Disclose anything that could not be run or verified.
- If a previous attempt failed, reassess the underlying state model before stacking speculative patches.

### Protect project structure

When moving Godot-managed scripts or scenes, use the Godot FileSystem dock when possible so resource references are updated. Commit moves and dependent path updates together. Do not split a large script merely to reduce its line count; split only around a stable responsibility boundary and only when the active task can absorb the regression risk.

## 5. Documentation Hierarchy

### `AGENTS.md`

This file contains durable project identity, source-of-truth rules, ownership principles, navigation guidance, safety rules, and agent procedure. It should change rarely. Do not put current task status, exact line numbers, transient tuning values, or copies of implementation details here.

### `CURRENT_STATE.md`

This is the living checkpoint. It records what currently exists, what is working or partial, current file locations, known limitations, technical debt, verification steps, and the immediate roadmap. Update it after a meaningful implementation phase, a major refactor, or a newly confirmed regression.

### `DECISION_LOG.md`

This records accepted, superseded, deferred, and unresolved decisions and their reasoning. Add entries when a system contract, gameplay rule, ownership boundary, workflow, or performance strategy changes. Do not log every bug fix or variable rename.

### Source code and scenes

Code and scenes define the implementation in the checked-out snapshot. They must still be inspected for every substantive change. Code can lag accepted design, and old documentation can lag code; reconcile rather than assuming.

### Handoff documents

Handoffs are time-stamped transition records. They can contain unique context and exact next steps, but a later confirmed change overrides them. Do not treat a handoff as permanently authoritative.

### Git history

Git history explains what changed and can recover earlier implementations. It does not by itself explain why a design choice was accepted. Use diffs and commit history alongside the decision log and current code.

### Conversation transcripts

Transcripts can recover user intent, corrections, and acceptance that never reached the repository. They are supporting evidence, not a substitute for inspecting current files. Preserve only unique durable information in repository documentation; do not copy entire conversations into the repo.

## 6. Project Architecture Orientation

The paths below are current navigation anchors, not permanent contracts. Search by responsibility if a future refactor moves them.

### World generation

World generation creates deterministic tile data from a seed. It owns the pipeline that establishes elevation, climate fields, terrain, biomes, rivers, fertility, and initial resource deposits. It should produce simulation data, not presentation state. At this snapshot, the main implementation is currently located in `scripts/world/generation/WorldGenerator.gd`, with dimensions and tile scale represented by `scripts/map/MapSettings.gd` and tile records represented by `WorldData`.

Changing generated tile semantics can affect rendering, region selection, city-map derivation, resource-source scanning, and future save compatibility. Preserve the distinction between biome and terrain: for example, hills are a land biome while true mountain peaks use mountain terrain.

### World rendering and selection

World presentation displays generated world data, provides map modes, hover inspection, starting-region selection, and scene transition controls. It should consume authoritative world state rather than becoming the long-term owner of simulation. The current `WorldRenderer` is also a prototype coordinator for generation and locking the selected world, so it is not yet a pure renderer.

Shared tile-color semantics currently live in `MapVisuals`, and shared texture build/warmup behavior lives in `MapTextureCache`. Keep those rules shared so world and city views do not drift. Starting-region validity is a gameplay rule, not a color rule.

### City maps

A city map is a higher-resolution local map derived from the selected world region. It carries local terrain, biome, climate, fertility, and resource information needed by placement and future simulation. At this snapshot, city-map construction is still performed inside the current city scene controller/renderer and the resulting map is retained in runtime session state.

The conceptual owner should be a city-map data or generation responsibility, even if the current code has not yet been split. Future refactors may move generation without changing the contract: renderers display the local map; city systems query it; persistent city state refers to it by stable identity.

### City rendering

City presentation draws the local terrain, roads, buildings, selection, placement previews, debug labels, and city UI. The current `CityRenderer` is a large mixed scene controller that also handles city-map generation, input, placement orchestration, inspection panels, and some lifecycle work. Treat this as a known prototype exception, not a desired rule that all future city systems belong in a renderer.

When extending the city, prefer placing authoritative behavior in the relevant simulation or state-owner domain and letting the renderer observe versioned changes. Do not advance global simulation from the renderer.

### Cities and city state

City state covers founding, the city entity, local objects, occupancy, citizens, assignments, resources, and runtime identity. At this snapshot, much of this is held as session-global state currently represented by static state and operations on `WorldData`.

Cities are intended eventually to participate in larger political or imperial structures. Do not bake assumptions such as “there can only ever be one city” into new system contracts, even though the current prototype exposes a single player city and one active local map.

### Buildings and city objects

Placeable objects are data-driven definitions plus persistent runtime instances. Definitions describe stable capabilities such as footprint, container role, housing, workplace behavior, placement prerequisites, production policies, and visual metadata. Runtime instances hold identity, ownership, footprint, assignments, local storage, and mutable production state.

Building placement should validate map bounds, terrain, and occupancy before committing. Runtime object identity must remain stable, and occupancy/index structures must stay synchronized. Current representative logic is split between the city scene controller and the city-object/state operations in `WorldData`.

### Roads

Roads are persistent city objects whose footprint can be an arbitrary set of tiles. They currently reserve occupancy and render differently from rectangular buildings. Future movement and pathfinding systems may consume road state, but roads do not yet alter travel cost or connectivity.

Do not assume that a road is a normal rectangular building or that it is currently selectable. Any change to road representation must consider occupancy, placement previews, rendering, pathfinding, saving, and object validation.

### Resources

Resources are whole physical quantities identified by stable resource types. The current prototype includes fish, coal, iron, and gold. Resource types are shared across world deposits, building storage, citizen inventories, production recipes, UI, and future hauling.

Adding or changing a resource affects every consumer of the resource registry: container permissions and capacity, recipe validation, inventory initialization, colors/icons, aggregate totals, logistics, consumption, debugging, and persistence.

### Containers and inventories

A container is a physical storage location with a type, allowed resources, capacity, and stored quantities. Current concepts include public city storage, private home storage, workplace storage, personal inventory, and ground piles. A container type expresses access and accounting semantics; it does not imply that resources teleport between containers.

Building storage and citizen carrying are different physical locations. Transfers must preserve quantity, capacity, source, destination, and eventually reservation/access rules. Personal inventories are generic carrying containers, not one-fish-at-a-time animation slots.

### Aggregate city accounting

Citywide totals are derived strategic accounting over eligible physical containers. They are useful for UI and future empire-level queries, but they do not erase location, ownership, access, or hauling requirements. A total of 50 fish does not mean every household can reach those fish or that the fish are in a Stockpile.

At the current checkpoint, eligible non-ground city-object containers contribute to the top resource total. Public Stockpile totals remain separately queryable. Do not replace physical transfers with direct edits to an aggregate number.

### Ground piles

Ground piles are intended to represent loose, tile-local physical resources when workplace storage overflows or resources are otherwise deposited on open tiles. They must not count toward aggregate stored-city totals. Their tile position, resource contents, legal placement, merging, reservations, and source provenance will matter.

The ground-pile domain is currently planned rather than fully implemented. Do not treat the existence of a container constant or overflow policy as evidence that pile state, rendering, or hauling already works.

### Citizens

Citizens are persistent simulation records first and visible actors later. They own individual identity, alive state, needs, home and job references, behavioral/task state, carrying capacity, and personal inventory. The current prototype stores citizen records centrally and does not instantiate one active scene node per citizen.

New citizen behavior must preserve stable IDs, inverse assignment relationships, inventory, needs, and suspended-task context. Avoid broad per-frame searches and one independent timer per citizen; future scale requires centralized, tick-driven data processing and spatial indexes where needed.

### Jobs, schedules, and tasks

Employment, attendance, and active behavior are distinct. A citizen may be employed by a workplace without currently being on shift or contributing productive work. Schedules determine availability and ordinary work/break periods. Tasks describe what a citizen is currently doing and must be suspendable/resumable when urgent needs intervene.

The current prototype implements home/job assignment but not schedules or task execution. Assigned workers currently count as productive as a temporary bridge. Future code must centralize productive eligibility rather than duplicating it across production, UI, and validation.

### Production

Production converts validated worker-time and recipe rules into whole resource batches. The global simulation tick drives production; individual workplaces do not own independent timers. Outputs enter the producing workplace's local storage first. Input-consuming recipes must fail closed until input withdrawal is implemented.

The first working producer is Fishing Grounds. It proves clock-driven progress, capacity blocking, local output storage, and UI reporting. Environmental source scoring, schedules, inputs, overflow, and physical worker tasks remain later extensions.

### Hauling and logistics

Hauling will create explicit physical transfers between source and destination containers. Location, capacity, access, carrying capacity, availability, and reservation state all matter. Stockpiles are the preferred public destination before private homes; home provisioning is a separate later demand layer.

Unemployed or off-shift citizens may perform general hauling, with dedicated labor roles possible later. Task and reservation systems must prevent two citizens from claiming the same resource or capacity. If no destination has capacity, resources remain at the source; aggregate accounting must not silently move them.

### Needs

Citizens own hunger and happiness. Need urgency is graded, not binary. Ordinary hunger should not always override work; urgent hunger may suspend a task, eat from accessible personal inventory or seek food, and later resume the prior task. Exact numeric thresholds are tuning, not architecture.

Scheduled breaks are distinct from emergency need interrupts. Breaks are ordinary workplace-local periods in which workers remain in the work area and may eat or socialize, with happiness restoration as a primary purpose. Taking food and eating food are separate actions.

### Time and simulation scheduling

The simulation clock owns world time, tick emission, pause state, and speed. The simulation coordinator owns ordered execution and performance measurements. Authoritative simulation systems mutate state in a deterministic sequence. At the current snapshot, the execution path is represented by `SimulationClock` to `SimulationCoordinator` to the simulation entry point on `WorldData`, then to ordered systems such as workplace production.

The clock should not absorb citizen, production, hauling, or needs logic. Renderers and UI observe clock and state changes; they do not become the time source. Scene transitions must not create duplicate clocks or reset active simulation accidentally.

### Debug tools and validation

Debug UI, inspectors, developer launch paths, resource injection, validation, and diagnostic labels exist to expose simulation truth. They should be gated from normal gameplay where practical and should not become hidden gameplay mutation paths.

The city-state validator checks cross-index, occupancy, container, citizen, inventory, and assignment invariants. Extend it whenever a new authoritative relationship is introduced. Structural corruption should be an error; transient derived-state differences should be warnings or omitted unless they violate a true invariant.

### User interface

UI displays state, requests player actions, and invokes explicit domain operations. It should not secretly rewrite unrelated dictionaries or maintain a second authoritative resource total. UI refresh should be driven by focused state versions or signals rather than full-map redraws or broad polling where avoidable.

The current prototype creates much of its UI programmatically inside scene scripts. Future scene or UI refactors may change that without changing ownership rules.

### Camera and input

World and city views share the `StrategyCamera2D` behavior. Camera changes can therefore affect both scenes. Camera state is presentation state and is stored separately for world and city transitions.

Input handling must respect UI consumption, placement modes, selection modes, debug gating, and shared camera behavior. Debug-only keyboard zoom must remain separate from ordinary mouse-wheel zoom unless a later decision changes it.

### Persistence

The current “save” terminology refers to in-memory session state retained across scene transitions, not disk persistence. A real save/load system must eventually serialize stable simulation identities and reconstruct indexes, relationships, maps, containers, citizens, schedules, tasks, and clock state.

Do not design new state around un-serializable scene references or assume process-static data is durable. Prefer stable identifiers for long-lived relationships.

## 7. State Ownership Principles

- Every authoritative piece of simulation state must have a clear conceptual owner.
- Renderers display simulation state. Current renderer scripts also contain prototype coordination and UI logic, but new authoritative systems should not be buried there by default.
- UI may request operations and display results; it should not maintain a competing source of truth.
- World tile data is owned by the world-data model produced by world generation.
- City tile data is owned by the active city-map/state model, even though generation is currently orchestrated by the city scene script.
- Runtime buildings, occupancy, citizens, assignments, and local storage are currently owned by the central city/session state represented by `WorldData` operations.
- Inventories own the resources physically stored in them.
- Aggregate city totals are derived accounting, never a physical container and never a transfer mechanism.
- Ground piles remain tile-local and outside stored-city totals.
- Citizens own individual needs, inventory, employment references, and active/suspended task state.
- Workplaces own workplace-local mutable production progress and output storage. Definition policies are shared configuration, not mutable per-instance state unless explicitly copied.
- The clock owns time; the coordinator owns system order; each simulation system owns its domain mutations.
- Debug state must be explicit and must not leak into release behavior.
- Use stable numeric or string identifiers for long-lived entity relationships rather than direct scene-node references.
- When state is duplicated for indexes, caches, inverse relationships, or UI optimization, document which copy is authoritative and validate synchronization.

## 8. Stable Design Invariants

These are high-confidence rules. Do not silently change them.

- Paladin is a systems-first strategy simulation built incrementally in Godot.
- The long-term model includes cities within larger political or imperial structures.
- Simulation state and presentation are distinct, even where current prototype scripts mix coordination responsibilities.
- Global time drives ordered simulation systems. Renderers do not advance simulation.
- Physical resources exist in a location: a container, a citizen inventory, or a loose tile pile. Aggregate totals are summaries, not locations.
- Resources are represented as whole quantities. Production may accumulate internal work progress, but it does not accumulate fractional fish or other fractional physical items.
- Eligible non-ground city-object containers contribute to citywide stored-resource accounting. Public Stockpile accounting remains separately queryable.
- Ground piles are tile-local and do not count toward aggregate stored-city totals.
- Local storage and access remain meaningful even when a city exposes an aggregate total.
- Stockpiles are preferred logistics destinations over private houses. Home stocking is a later, separate demand priority.
- Citizens have generic carrying capacity and can carry batches of resources; they do not require one simulation entity or animation per individual fish.
- Citizens are persistent data records before they become visible animated actors.
- Employment, being on shift, active work, breaks, and off-duty availability are separate concepts.
- Workplaces use policies for resource sources, work locations, movement, breaks, and overflow so future workplace types do not require copied special-case logic.
- Workers have scheduled breaks and ordinarily remain in the workplace area during those breaks. Breaks can support eating and socializing.
- Hunger urgency is graded. Ordinary hunger does not automatically override every task; urgent hunger may suspend and later resume work.
- Taking food, carrying food, and eating food are separate actions.
- Production output enters workplace storage before future overflow or hauling logic acts on it.
- If output has no legal local storage or overflow location, production blocks rather than creating or teleporting resources.
- Shared visual rules should be centralized so world and city views remain consistent.
- Debug behavior should be separable from release behavior and should expose, not conceal, simulation truth.
- Advanced animation should represent real simulation state. Decorative wandering should not be mistaken for implemented work behavior.

Do not promote temporary tuning values—hunger thresholds, production rates, capacities, noise thresholds, colors, or radii—to permanent invariants unless the user explicitly settles them as design contracts.

## 9. Change Safety by System

### World tile or biome changes

Check generation, map colors and texture cache versions, hover/debug inspection, starting-region validity, city-start tile copying, city-map derivation, placement, environmental source providers, resource deposits, and future save compatibility.

### World/city visual changes

Check `MapVisuals`, both renderers, cached texture invalidation, every map mode, resource overlays, debug labels, selection/placement overlays, and warmup behavior. Do not fix a shared color in only one view.

### City storage changes

Check object definitions, per-object storage permissions and capacities, public versus aggregate queries, container version counters, top-bar refresh, object inspection, production output, validator rules, planned ground piles, planned hauling, houses, citizen inventories, and future empire accounting. Never infer physical access from aggregate totals.

### Resource representation changes

Check world deposits, the resource registry, empty-container initialization, recipes, production, citizen inventory, UI order/colors, debug injection, aggregate queries, reservations, hauling, consumption, and saving. Preserve whole-quantity and conservation rules.

### Citizen or assignment changes

Check stable IDs and indexes, citizen-to-object references, object-to-citizen lists, housing and workplace capacities, automatic assignment, productive-worker logic, debug panels, validation, schedules, suspended tasks, and persistence.

### Task or hunger changes

Check job attendance, productive contribution, inventory preservation, food-source selection, reservations, task suspension/resumption, break schedules, happiness, hauling claims, movement, and animation. Do not implement hunger as an isolated boolean that bypasses task state.

### Production changes

Check global tick ordering, pause/speed behavior, worker eligibility, recipe validity, integer work progress, inputs, output capacity, local storage, overflow, city accounting, scene transitions, UI estimates, focused version counters, and validator cache invalidation.

### Ground-pile or hauling changes

Check tile occupancy semantics, local pile identity, merging, reservation quantities, legal overflow zones, source/destination capacity, citizen carry capacity, access permissions, stockpile preference, aggregate exclusion, rendering, and save/load.

### Clock or simulation-order changes

Check autoload initialization, new-game reset, main-menu suspension, scene transitions, pause/speed, maximum work per frame, deterministic order, performance diagnostics, and every system that consumes `minutes_advanced`. Do not add per-scene clocks.

### Camera/input changes

Check both world and city scenes because they share the strategy camera. Test UI interception, raw keys, Godot UI actions, edge scroll, mouse-centered zoom, map bounds, scene-specific saved transforms, placement/selection modes, debug gating, and mobile/remote-development workflows.

### Persistence changes

Check stable IDs, indexes, inverse assignments, maps and seeds, city objects and footprints, storage, citizens, clock, task/reservation state, camera state, schema versioning, and reconstruction validation. Do not serialize texture objects as authoritative simulation data.

## 10. Standard Task Procedure

1. Read `AGENTS.md`.
2. Read the relevant sections of `CURRENT_STATE.md`.
3. Read the relevant accepted and superseded entries in `DECISION_LOG.md`.
4. Inspect the latest current code, scenes, autoloads, and configuration involved.
5. Search all callers, readers, writers, signals, indexes, versions, and shared definitions.
6. State any assumption that affects behavior or scope.
7. Identify the conceptual state owner and presentation consumers.
8. Propose the smallest coherent implementation.
9. Make or provide the change without unrelated refactoring.
10. Report the files and responsibilities affected.
11. Provide focused runtime and regression test steps with expected outcomes.
12. Disclose what was not verified.
13. Update `CURRENT_STATE.md` if the checkpoint materially changed.
14. Add or supersede a `DECISION_LOG.md` entry if a durable rule changed.
15. Change `AGENTS.md` only when a durable project-wide working or architecture principle changed.

## 11. Definition of Done

A task is done only when all applicable conditions are satisfied:

- The code parses or the user has explicit instructions to verify parsing locally.
- Relevant dependencies, callers, data owners, caches, indexes, version counters, and observers were considered.
- The requested behavior is implemented, not merely represented in UI.
- Existing behavior is preserved unless the change intentionally replaces it.
- Resource conservation, capacity, identity, assignment, and lifecycle edge cases are handled.
- Invalid or unsupported future data fails safely.
- The result has practical test steps and expected outcomes.
- Runtime, visual, performance, and persistence claims are limited to what was actually verified.
- Known uncertainty and remaining gaps are disclosed.
- Durable decisions and current-state documentation are updated or explicitly flagged for update.
- The user has enough information to accept or reject the behavior based on an actual Godot run.

## 12. Things the Agent Must Not Do

- Do not claim visual, tactile, performance, compiler, or runtime verification without actually performing it or receiving a reproducible user confirmation.
- Do not invent missing repository structure, node paths, signals, APIs, fields, or files.
- Do not silently reinterpret a settled design rule.
- Do not assume every old conversation rule remains current.
- Do not treat an old snapshot as newer than a later confirmed chat edit.
- Do not restore Stockpile-only top-bar accounting; the current aggregate includes eligible non-ground city-object containers.
- Do not treat aggregate resource totals as proof of local physical access or move resources by editing the aggregate.
- Do not count ground piles as stored city resources.
- Do not make renderers advance simulation or give every workplace/citizen an independent timer.
- Do not turn temporary debug mutation or developer shortcuts into permanent gameplay behavior.
- Do not implement decorative citizen animation as a substitute for tasks, movement, and authoritative state.
- Do not hard-code current hunger examples as permanent thresholds.
- Do not make input-consuming recipes generate output before real input withdrawal exists.
- Do not make broad architecture changes during a small bug fix without explaining and justifying the expansion.
- Do not split scripts or port systems merely to reduce line count.
- Do not prematurely rewrite the project as ECS or port it wholesale to C++.
- Do not store current implementation trivia, line numbers, or temporary tuning in `AGENTS.md`.
- Do not overwrite user changes or unrelated dirty-worktree changes.
- Do not hide a conflict between code, documentation, and confirmed user intent. Record it and resolve it deliberately.
