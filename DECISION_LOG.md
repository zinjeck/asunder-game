# Paladin Decision Log

This log records durable decisions that shape Paladin's gameplay, architecture, state ownership, workflow, extensibility, performance strategy, and debugging. It is not a changelog and does not attempt to preserve every discussion.

## 1. How to Read This Log

- A newer accepted decision overrides an older conflicting decision.
- Superseded entries remain visible so obsolete behavior is not accidentally restored.
- Dates identify when the decision was accepted or most recently refined. They are conversation dates, not necessarily commit dates.
- **Accepted** means the rule is settled design or workflow, whether or not implementation is complete.
- **Partially Implemented** means the direction is accepted and a meaningful subset exists.
- **Superseded** means the entry is historical and must not guide new work except to explain migration.
- **Proposed** means useful planning exists but the user has not settled the full contract.
- **Needs Verification** means code/history is ambiguous or a current user choice is still required.
- “Implementation Notes” describe the inspected checkpoint, not a permanent filename or API contract.
- “Verification Needed” identifies evidence required before claiming the decision is implemented.

When adding a decision:

1. Add it under the most relevant area.
2. Use the date of acceptance or explicit refinement.
3. Link it to the decision it supersedes, when applicable.
4. Describe responsibility and consequences, not a function diff.
5. Update the superseded index if old behavior must remain historically visible.
6. Update `CURRENT_STATE.md` separately when implementation status changes.

## 2. Decision Entry Format

Use this structure, omitting only fields that genuinely add no information:

```text
## Decision Title
**Date:** YYYY-MM-DD
**Status:** Accepted | Superseded | Partially Implemented | Proposed | Needs Verification
**Area:** Domain
**Decision:** What is settled.
**Context:** What problem or conflict prompted it.
**Reasoning:** Why this direction was chosen.
**Consequences:** What future work must preserve.
**Affected Systems:** Conceptual domains.
**Supersedes:** Older decision, if any.
**Implementation Notes:** Current checkpoint evidence, not a permanent code contract.
**Verification Needed:** Remaining proof or decision.
```

## 3. Development Workflow Decisions

### Source-of-truth precedence

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Workflow and continuity  
**Decision:** The newest explicit user correction or accepted design decision has highest authority. Confirmed later chat edits outrank older snapshots. The current repository is authoritative for the checked-out code, while runtime behavior is authoritative for whether that code works.  
**Context:** Paladin changes rapidly through manual edits, uploaded archives, GitHub snapshots, branches, and long conversations. A newer conversation can legitimately be ahead of an uploaded file.  
**Reasoning:** Treating every archive as final would repeatedly restore obsolete rules; treating memory as exact code would invent brittle details.  
**Consequences:** Agents must reconcile date, confirmation, code, documentation, and runtime evidence rather than selecting whichever source is easiest. Unresolvable conflicts must be labeled and brought to the user.  
**Affected Systems:** All project work.  
**Supersedes:** Any implicit “newest file always wins” rule.  
**Implementation Notes:** This precedence is also summarized in `AGENTS.md` and the project instructions.

### Confirmed manual edits remain part of the current state

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Workflow and continuity  
**Decision:** Unless the user reports failure, reversion, or replacement, assume an instructed edit that the user applied or confirmed working remains part of Paladin's current state.  
**Context:** The user frequently applies code manually between uploaded snapshots.  
**Reasoning:** Requiring a new archive after every small edit would be inefficient, while ignoring confirmed changes would cause regressions.  
**Consequences:** Future instructions build on confirmed work. Exact function bodies and signatures still require the newest file before another edit.  
**Affected Systems:** All manually edited code.  
**Verification Needed:** If a later file conflicts, establish whether it is an older baseline or an intentional revert.

### Prefer surgical edits and inspect current dependencies

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Coding workflow  
**Decision:** Inspect relevant current files and dependency edges, then make the smallest coherent change. Whole-file replacement requires the newest source and an explicit warning.  
**Context:** Large scripts evolved rapidly, and copied replacement blocks previously caused duplicate functions, stale assumptions, and compiler errors.  
**Reasoning:** Focused edits preserve user changes and reduce regression surface without forbidding necessary architecture work.  
**Consequences:** Search callers, shared data, indexes, signals, versions, scenes, and autoloads before changing shared systems. Do not bundle unrelated refactors into focused fixes.  
**Affected Systems:** All code; especially `WorldData`, world/city scene controllers, camera, and shared utilities.

### Use Godot-aware file moves; defer splitting until boundaries stabilize

**Date:** 2026-07-09  
**Status:** Accepted  
**Area:** Repository organization  
**Decision:** Move Godot-managed scripts/scenes through the Godot FileSystem dock when practical so references update. The current folder reorganization was accepted, but splitting large existing scripts solely because they are large is deferred.  
**Context:** The user wanted a cleaner repository before scripts grew further, while broad refactors risked breaking working resource paths.  
**Reasoning:** Location cleanup and responsibility extraction are different operations. A stable boundary is more important than line-count reduction.  
**Consequences:** Current paths are navigation anchors, not permanent contracts. Future splits must be justified by ownership and performed as focused, testable changes.  
**Affected Systems:** Scenes, resource paths, `CityRenderer`, `WorldData`, renderer utilities.  
**Verification Needed:** Reassess the temporary “do not split yet” stage constraint when the current Phase 2 production/source work is stable.

### Git history records code; durable repository docs record contracts

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Version control and documentation  
**Decision:** Use Git/GitHub for version history and isolated branches/draft review when applicable. Use `AGENTS.md`, `CURRENT_STATE.md`, and `DECISION_LOG.md` for compressed project contracts and current orientation. Create a handoff before branching away from unfinished work.  
**Context:** Future models cannot safely load every script and transcript at once, and Git diffs do not capture every design reason.  
**Reasoning:** Code history, architecture guidance, current status, and decision rationale serve different purposes.  
**Consequences:** Do not duplicate entire transcripts or code in documentation. Update only the document whose role changed. Final acceptance still requires a runnable local Godot checkout and user testing.  
**Affected Systems:** Repository workflow, future AI sessions.

### User and AI divide runtime and reasoning responsibilities

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Collaboration  
**Decision:** The user owns vision, feel, visual judgment, live Godot testing, and acceptance. The AI owns dependency tracing, architecture reasoning, implementation planning, and careful code changes.  
**Context:** Visual/tactile results and local runtime conditions cannot always be observed by a remote coding model.  
**Reasoning:** Clear responsibility prevents false verification while still using AI for large-system reasoning.  
**Consequences:** The AI must give tests and state what it could not verify. User-reported outcomes are evidence and become the working checkpoint.  
**Affected Systems:** All implementation and review work.

## 4. Project and Engine Decisions

### Official project name is Paladin

**Date:** 2026-07-09  
**Status:** Accepted  
**Area:** Project identity  
**Decision:** The game and Godot project are officially named **Paladin**.  
**Context:** Earlier work used provisional project naming.  
**Reasoning:** A settled identity supports repository, project settings, menu branding, and long-term documentation.  
**Consequences:** User-facing branding should use Paladin. Internal classes and scripts should not be renamed merely for branding.  
**Affected Systems:** Project configuration, repository naming, menu/UI, documentation.  
**Implementation Notes:** The inspected project name, menu title, and documentation use Paladin.

### Historical direction: leave Godot and port early

**Date:** 2026-07-08  
**Status:** Superseded  
**Area:** Engine and language  
**Decision:** The user explored stopping Godot development and porting early so migration would not become harder after the codebase grew.  
**Context:** Concern that a “legit” large game needed a custom engine or C++ and that waiting would create more translation work.  
**Consequences:** Historical only. It does not authorize a port. The replacement decision keeps Godot/GDScript and reserves GDExtension for measured stable hot loops.  
**Affected Systems:** Entire project.  
**Superseded By:** Continue in Godot with GDScript; defer wholesale engine migration.

### Continue in Godot with GDScript; defer wholesale engine migration

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Engine and language  
**Decision:** Continue developing Paladin in Godot with GDScript as the primary language. Do not abandon the current project for a wholesale C++ port or custom engine now. Consider C++ through GDExtension later for stable, measured hot loops.  
**Context:** The user explored leaving Godot and porting early to avoid a larger future migration.  
**Reasoning:** Current performance problems were solvable through architecture and caching, and an early rewrite would discard working systems before their contracts stabilize. Godot can host a portable data-driven simulation core while allowing targeted native optimization later.  
**Consequences:** Keep simulation state reasonably separable from scene presentation. Profile before porting. Do not treat possible future native code as permission to redesign unrelated systems now.  
**Affected Systems:** Entire engine architecture, simulation core, build tooling.  
**Supersedes:** The tentative direction to stop using Godot immediately and the idea of a wholesale early C++ port.  
**Implementation Notes:** Current project targets Godot 4.4 and contains GDScript only.

### Build incrementally around real simulation systems

**Date:** 2026-07-06  
**Status:** Accepted  
**Area:** Product and development strategy  
**Decision:** Build Paladin system by system, prioritizing real state and interactions over fake UI totals or decorative animation.  
**Context:** The long-term ambition includes a world, cities, citizens, resources, logistics, needs, empires, and later conflict systems.  
**Reasoning:** Each new layer must have a trustworthy state model before later layers depend on it.  
**Consequences:** A UI label is not a completed mechanic. Animation must eventually reflect authoritative tasks. Planned phases should follow dependency order even when visual progress temporarily feels slow.  
**Affected Systems:** Project roadmap and definition of done.

### Citizens are data-oriented simulation records before scene actors

**Date:** 2026-07-09  
**Status:** Accepted  
**Area:** Simulation architecture and scale  
**Decision:** Store citizens as centralized persistent data records and process them through ordered simulation systems. Do not create an independent always-active Node, timer, or callback loop for every citizen.  
**Context:** Paladin is intended to support large city populations; an approximate planning ceiling of 2,000 citizens per city has been discussed.  
**Reasoning:** Central data processing is easier to validate, save, schedule, and optimize than thousands of independent scene objects.  
**Consequences:** Visible citizen nodes later represent current data; they do not own canonical needs, jobs, inventory, or task completion. Optimize from measurements rather than prematurely introducing ECS.  
**Affected Systems:** Citizens, scheduling, tasks, movement, animation, persistence, performance.

## 5. Rendering and Visual Decisions

### Shared map visuals are the single authority for world and city base colors

**Date:** 2026-07-08  
**Status:** Accepted  
**Area:** Rendering architecture  
**Decision:** World and city views share map-mode definitions, names, and base tile-color rules. View-specific overlays are allowed, but duplicated base rules should not drift.  
**Context:** World and city ocean/biome colors diverged when each renderer owned a copy.  
**Reasoning:** One authority makes visual fixes propagate and keeps texture-cache invalidation coherent.  
**Consequences:** Change shared biome/resource/map-mode semantics in the shared visual domain; test both views. Bump the visual cache version when cached output meaning changes.  
**Affected Systems:** World rendering, city rendering, map modes, caches, debug inspection.  
**Implementation Notes:** Currently represented by `MapVisuals` and consumed by both texture caches/renderers.

### Share reusable texture-cache and debug-panel behavior

**Date:** 2026-07-09  
**Status:** Accepted  
**Area:** Rendering/debug architecture  
**Decision:** Common map texture building/warmup and debug-panel mechanics should be shared rather than copied between world and city.  
**Context:** Newly duplicated cache and debug code recreated the same drift risk as duplicated colors.  
**Reasoning:** These are shared mechanics with scene-specific providers, not separate gameplay rules.  
**Consequences:** Scene scripts provide colors/text/state; shared helpers own the common lifecycle. Future changes must test cancellation during scene changes.  
**Affected Systems:** Both renderers, texture warmup, debug UI.  
**Implementation Notes:** Current snapshot uses `MapTextureCache` and `DebugPanel` shared utilities.

### Avoid full-map redraws during ordinary camera motion

**Date:** 2026-07-06  
**Status:** Accepted  
**Area:** Rendering performance  
**Decision:** Camera movement and zoom must not force expensive regeneration or full-map redraw work each frame. Static terrain should remain texture-backed; overlays update only when relevant state changes.  
**Context:** Earlier redraw-on-camera movement caused severe lag.  
**Reasoning:** Camera transforms can move already-rendered content without recomputing tile visuals.  
**Consequences:** Camera changes must be tested for hidden redraw calls, cache rebuilds, or per-tile work.  
**Affected Systems:** Camera, world/city rendering, overlays, texture caches.

### Distinguish hover, placement, drag selection, and committed selection

**Date:** 2026-07-08  
**Status:** Accepted  
**Area:** Interaction visuals  
**Decision:** Hover and temporary placement/drag previews use lightweight cursor-like visuals; a committed region or city object uses a distinct persistent outline. The selected starting region is bright cyan, and invalid placement remains clearly red.  
**Context:** Bright preview colors and committed selections were visually ambiguous.  
**Reasoning:** Players must know whether they are inspecting, previewing, or have made a selection.  
**Consequences:** Input refactors must preserve visual state transitions and clear stale overlays. Exact color values and widths remain implementation tuning.  
**Affected Systems:** World region selection, city object selection, placement previews, roads.  
**Supersedes:** Bright purple as the committed starting-region color.

### Debug object names must be small, screen-aware, and footprint-centered

**Date:** 2026-07-08  
**Status:** Accepted  
**Area:** Debug visuals  
**Decision:** Debug labels should fit inside the visible object, stay readable across zoom, and center from the object's footprint rather than assuming every object is a rectangle.  
**Context:** Earlier labels were much too large and poorly centered; future objects may be L- or I-shaped.  
**Reasoning:** Debug text should expose identity without obscuring the map and should not require expensive center-of-area geometry.  
**Consequences:** Use lightweight footprint tile-center averaging or an equivalent stable anchor. Keep labels debug-only.  
**Affected Systems:** City debug drawing, arbitrary footprints, camera zoom.  
**Implementation Notes:** Current snapshot uses screen-aware sizing and average footprint tile centers.

## 6. World Generation Decisions

### Use a deterministic layered world-generation pipeline

**Date:** 2026-07-06  
**Status:** Accepted  
**Area:** World generation  
**Decision:** A seed drives a layered pipeline in which continents/elevation and climate fields produce terrain/biomes, followed by rivers, fertility, and resources. Generated data is separate from rendering.  
**Context:** The earliest prototype mixed small noise experiments and display concerns.  
**Reasoning:** Layered data supports map modes, reproducibility, debug inspection, city derivation, and later simulation.  
**Consequences:** Generation performance refactors should preserve output rules unless a design change is explicit. Seeds must remain reportable and reproducible within a given algorithm version.  
**Affected Systems:** World generator, tile model, rendering, city derivation.

### Hills are land around concentrated mountain peaks

**Date:** 2026-07-07  
**Status:** Accepted  
**Area:** Terrain and biomes  
**Decision:** Most of the outer/weaker former mountain regions become hills. Hills use the hills biome with land terrain; dense interior peak centers remain mountain biome with mountain terrain.  
**Context:** Broad mountain terrain created unrealistic solid blocks and over-restricted city building/movement.  
**Reasoning:** Separating hills from true impassable/high mountain peaks produces more natural ranges and future gameplay variety.  
**Consequences:** Placement and movement logic must use terrain and biome intentionally rather than assuming every mountain-score tile is mountain terrain.  
**Affected Systems:** Generation, rendering, placement, fertility, deposits, future movement.  
**Supersedes:** Treating the whole mountain candidate region as mountain terrain.

### Current rivers are a working heuristic; advanced valley-aware rivers are deferred

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** River generation  
**Decision:** Keep the current heuristic river generator for now. The long-term preference is for rivers to follow plausible valleys and avoid cutting through mountain masses except through real corridors, but the fully intelligent valley-aware algorithm is postponed.  
**Context:** Advanced valley routing was attractive but not important enough to delay city simulation, production, and logistics.  
**Reasoning:** Current rivers are sufficient scaffolding; the advanced problem is expensive and largely independent of the current development frontier.  
**Consequences:** Do not claim the existing valley-source heuristic completes the advanced design. Do not start a broad terrain rewrite during Phase 2 production work.  
**Affected Systems:** World generation, city map terrain, future resource-source logic.  
**Implementation Notes:** Current code uses simple source qualification, mountain penalties, and open-ocean termination.

### Historical starting-region rule: fixed bad-tile limit

**Date:** 2026-07-07  
**Status:** Superseded  
**Area:** World selection  
**Decision:** An early 9×9 selector rejected a region after a small fixed number of “bad” water tiles and counted rivers with other water.  
**Context:** This was the first placement-safety rule.  
**Consequences:** Historical only. Do not restore fixed bad-tile counting or treat rivers as invalid.  
**Affected Systems:** World selection and Dev City region search.  
**Superseded By:** Starting-region validity uses ocean ratio; rivers are exempt.

### Starting-region validity uses ocean ratio; rivers are exempt

**Date:** 2026-07-07  
**Status:** Accepted  
**Area:** World selection and city founding  
**Decision:** The 9×9 starting region is invalid only if it is outside the world or more than 90% of its tiles are ocean. River tiles do not count toward the water restriction.  
**Context:** The prior rule invalidated a region after a small fixed count of water/river tiles, making rivers undesirable and selection unnecessarily strict.  
**Reasoning:** A mostly ocean start is unusable, while river access should be valuable rather than penalized.  
**Consequences:** Exactly 90% or less is valid; with 81 tiles, 73 ocean tiles is invalid. Dev-region selection must use the same semantic rule.  
**Affected Systems:** World selection, Dev City launcher, starting-region UI, city derivation.  
**Supersedes:** Fixed “bad tile” limits and counting river tiles as invalid water.

### City terrain is derived from the selected world region

**Date:** 2026-07-07  
**Status:** Partially Implemented  
**Area:** World-to-city relationship  
**Decision:** A city view is not an unrelated random map; it derives local terrain, climate, fertility, biomes, and deposits from the selected world region while adding finer local detail.  
**Context:** World and city maps need coherent geography and resources.  
**Reasoning:** Strategic location should matter at the local simulation layer.  
**Consequences:** City generation must preserve source provenance and deterministic seed relationships. Later resource providers should query the local derived map rather than inventing output.  
**Affected Systems:** Region locking, city-map generation, resource sources, persistence.  
**Implementation Notes:** Current code deep-copies the selected region and builds a higher-resolution local map.

## 7. City and Empire Decisions

### Cities are persistent simulation entities, not temporary scenes

**Date:** 2026-07-09  
**Status:** Partially Implemented  
**Area:** City architecture  
**Decision:** A city retains identity, map, objects, population, assignments, resources, and simulation progress independently of whether the city scene is currently visible.  
**Context:** Scene transitions should not recreate the economy or erase progress.  
**Reasoning:** Cities must eventually coexist within larger political structures and continue to matter strategically.  
**Consequences:** Scene nodes are views/controllers, not city identity. Long-lived references use stable IDs. Simulation state must eventually serialize.  
**Affected Systems:** City state, scene transitions, clock, production, persistence.  
**Implementation Notes:** Runtime state currently persists only in process-global memory.

### A City Keep founds the current prototype city

**Date:** 2026-07-07  
**Status:** Accepted  
**Area:** City founding  
**Decision:** Placing the City Keep establishes the player city and unlocks city construction. The foundation must remain a real persistent city object.  
**Context:** Founding originally risked becoming a UI flag disconnected from the placed object.  
**Reasoning:** The visual action, city identity, occupancy, and later administrative role should refer to one persistent foundation.  
**Consequences:** A founded city must have one valid Keep; transitions must preserve or recover it; placing another founding object is disallowed.  
**Affected Systems:** Placement, city state, population initialization, validator, UI.

### Cities will participate in larger political or imperial structures

**Date:** 2026-07-09  
**Status:** Accepted  
**Area:** Long-term city/empire architecture  
**Decision:** City data and strategic accounting must be extensible to a future empire/polity layer rather than being inseparable from one player scene.  
**Context:** Paladin's long-term scope is larger than a single isolated settlement.  
**Reasoning:** Stable city identity and derived totals allow later ownership, trade, policy, warfare, and AI without rewriting physical city logistics.  
**Consequences:** Do not hard-code “the only city” assumptions into new public interfaces. Aggregate city totals remain summaries of local state.  
**Affected Systems:** City identity, persistence, resources, future empire/trade/AI.  
**Verification Needed:** Exact polity, ownership, off-screen simulation, and multi-city loading contracts remain future design.

### Local city-map extent is not yet a settled political-boundary contract

**Date:** 2026-07-10  
**Status:** Needs Verification  
**Area:** City maps and boundaries  
**Decision:** The selected world region currently determines the generated local city-map extent, but no final decision says that every local-map edge is the city's permanent legal, political, or expansion boundary.  
**Context:** The prototype needs a bounded local map now, while future cities, territory, annexation, multiple settlements, and empires may distinguish rendered simulation area from jurisdiction.  
**Reasoning:** Treating the current generated rectangle as an eternal political border would freeze an implementation convenience into game design.  
**Consequences:** Placement currently remains inside the active city map. Future territory systems must explicitly define jurisdiction, expansion, neighboring cities, and off-map logistics rather than inferring them from current array bounds.  
**Affected Systems:** City map, placement, ownership, persistence, future empire/territory systems.  
**Verification Needed:** Explicit city-territory and expansion design.

## 8. Resource and Storage Decisions

### Resources remain physical and location-bearing

**Date:** 2026-07-09  
**Status:** Accepted  
**Area:** Resource architecture  
**Decision:** Resources exist in a physical location: a building/container, citizen inventory, or loose tile pile. Strategic totals summarize those locations; they do not replace them.  
**Context:** Abstract city counters would make hauling, access, household supply, workplace overflow, and blockades meaningless.  
**Reasoning:** Paladin's intended depth depends on the difference between owning a resource and having it locally accessible.  
**Consequences:** Transfers conserve quantities and require source/destination capacity. Do not teleport resources by editing a city total.  
**Affected Systems:** Containers, production, citizen inventory, ground piles, hauling, needs, trade, persistence.

### Use generic container roles with resource permissions and capacity

**Date:** 2026-07-09  
**Status:** Partially Implemented  
**Area:** Storage architecture  
**Decision:** Model public Stockpiles, private home storage, workplace storage, personal inventories, and ground piles as distinct container roles. Each physical container determines allowed resources and capacity.  
**Context:** A Stockpile-only implementation would not generalize to homes, workplaces, citizens, or overflow.  
**Reasoning:** A shared container vocabulary supports generic transfer and validation while preserving access semantics.  
**Consequences:** Container type is not a substitute for actual storage permissions. Access, aggregate counting, and physical location remain separate questions.  
**Affected Systems:** Buildings, citizens, production, hauling, UI, validator.  
**Implementation Notes:** Object containers work; personal inventory is scaffolded; ground piles are not implemented.

### Historical accounting: top bar shows public Stockpiles only

**Date:** 2026-07-09  
**Status:** Superseded  
**Area:** Strategic resource accounting  
**Decision:** The first container implementation defined the top resource bar as the sum and capacity of public Stockpiles only; workplace and private storage remained separate.  
**Context:** At that checkpoint Stockpiles were the only functional general storage and production had not yet made workplace inventory strategically visible.  
**Consequences:** Public-Stockpile queries remain useful, but this rule no longer controls the top bar.  
**Affected Systems:** Resource UI, workplace storage, future house storage.  
**Superseded By:** Citywide stored totals include eligible non-ground building containers.

### Citywide stored totals include eligible non-ground building containers

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Strategic resource accounting  
**Decision:** The top city resource total includes resources physically stored in legitimate building containers—public Stockpiles, workplace storage, and future real home/building storage. Open-tile ground piles do not count. Public-Stockpile-only totals remain separately available.  
**Context:** The older top bar showed only public Stockpiles, so fish physically stored at a working fishery disappeared from the city's strategic total.  
**Reasoning:** Citywide accounting should report what the city has stored without pretending all storage is public or mutually accessible.  
**Consequences:** Do not restore the Stockpile-only bar. UI and future empire accounting must retain category/location information when access matters.  
**Affected Systems:** City resource bar, object containers, production, future empire accounting.  
**Supersedes:** “The top resource bar is public Stockpiles only” and “workplace-stored fish is ignored by the city resource bar.”  
**Implementation Notes:** Current aggregate iterates eligible city objects and excludes container types “none” and “ground pile.”

### Citizen-held resources in strategic totals require a later explicit choice

**Date:** 2026-07-10  
**Status:** Needs Verification  
**Area:** Strategic resource accounting  
**Decision:** No final decision is documented on whether nonzero personal citizen inventories should count in the same citywide stored total.  
**Context:** The latest rule explicitly included legitimate building/house/workplace storage and excluded open ground. Current code aggregates city objects only, while personal inventories are separate physical containers.  
**Reasoning:** Carried resources are within the city but may be in transit or privately controlled; either accounting choice has consequences.  
**Consequences:** Do not silently include or exclude citizen inventory once it becomes active. Define separate “stored,” “carried,” “public,” and “loose” categories if necessary.  
**Affected Systems:** Citizen inventory, resource bar, empire accounting, hauling.  
**Verification Needed:** Explicit user decision before carried resources materially affect totals.

### Ground piles are tile-local and excluded from stored-city totals

**Date:** 2026-07-09  
**Status:** Accepted  
**Area:** Ground resources and accounting  
**Decision:** Loose resources on open tiles remain attached to that tile and do not count as city storage or the citywide stored total.  
**Context:** Workplace overflow needs somewhere physical to go without becoming safe strategic inventory.  
**Reasoning:** Exclusion gives hauling and protected storage meaning and prevents dropped output from appearing fully secured.  
**Consequences:** Piles need their own identity, quantities, merge/reservation rules, rendering, and local access. Moving resources into a valid container is the event that changes stored accounting.  
**Affected Systems:** Overflow, ground-pile registry, hauling, UI, validator, saving.

### Historical production destination: workers carry output first

**Date:** 2026-07-09  
**Status:** Superseded  
**Area:** Production and citizen inventory  
**Decision:** An early design placed produced fish into each worker's personal inventory first and sent excess to workplace storage.  
**Context:** This was discussed before global aggregate workplace production existed.  
**Consequences:** Historical only. It must not be mixed into the current tick-driven producer. Citizen inventory remains relevant for later hauling and eating.  
**Affected Systems:** Production, citizen inventory, hauling.  
**Superseded By:** Workplace output enters local workplace storage first.

### Workplace output enters local workplace storage first

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Production and logistics  
**Decision:** Completed production is first stored in the producing workplace's local output container. Citizen inventories are used for carrying/consumption, not as the default first owner of automatically produced output.  
**Context:** An earlier concept put produced fish into workers' personal inventories before workplace storage, but the clock-driven aggregate production system does not model individual work tasks yet.  
**Reasoning:** Workplace-local output gives production one deterministic physical destination and allows later haulers to move batches without inventing per-worker ownership.  
**Consequences:** Production blocks or invokes local overflow when workplace capacity is unavailable. Later visible work must not bypass local storage without a new explicit rule.  
**Affected Systems:** Production, workplace containers, citizen inventory, hauling.  
**Supersedes:** “Workers fill personal inventory with produced fish first; excess enters workplace storage.”

### Overflow remains local and must fail closed

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Production overflow  
**Decision:** When workplace storage is full, output may only merge with a compatible nearby pile or create a pile on a legal tile within the workplace's declared overflow zone. If neither is possible, production blocks.  
**Context:** Unlimited invisible output or teleporting directly to a Stockpile would violate physical logistics.  
**Reasoning:** Local overflow makes capacity and hauling meaningful while preventing resource deletion.  
**Consequences:** Overflow radius is separate from resource-source radius. Piles remain outside stored totals. Capacity and pile placement must be reserved/validated atomically.  
**Affected Systems:** Production, workplace policies, city map, ground piles, hauling, validator.  
**Implementation Notes:** Policy data exists; execution is planned for Phase 2E.

### Physical resources are whole units; unsupported inputs cannot create free output

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Production arithmetic and conservation  
**Decision:** Production may track deterministic internal work units, but physical output quantities are whole integers. Recipes that require inputs must block until real stored-input consumption is implemented.  
**Context:** Floating output accumulation and placeholder input handling can produce rounding drift or free goods.  
**Reasoning:** Integer batches make conservation, capacity, UI, saving, and validation auditable.  
**Consequences:** No fractional fish; no raw float resource accumulation; validate positive whole recipe quantities.  
**Affected Systems:** Recipes, production, containers, UI, validation, persistence.

## 9. Citizen Inventory Decisions

### Citizen inventory is generic and capacity-based

**Date:** 2026-07-09  
**Status:** Partially Implemented  
**Area:** Citizen inventory  
**Decision:** Each citizen has a generic resource inventory with a total carrying capacity. A citizen can carry batches of resources; the model does not create a separate behavior step for every fish.  
**Context:** Hauling each physical unit as its own citizen trip would be both unrealistic for the desired scale and computationally wasteful.  
**Reasoning:** Bounded batch carrying preserves physical logistics without excessive object count.  
**Consequences:** Transfer APIs must enforce whole amounts, total capacity, conservation, and resource compatibility where applicable. Visual carrying later represents quantities already in inventory.  
**Affected Systems:** Citizens, hauling, eating, workplaces, homes, Stockpiles.  
**Implementation Notes:** Citizen records and capacity validation exist; transfer behavior does not.

### Eating consumes personal inventory; taking food and eating are distinct

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Citizen inventory and needs  
**Decision:** A citizen may eat wherever they are if food is already in personal inventory. Withdrawing food from a home or Stockpile is a separate action from consuming it.  
**Context:** Treating a remote city total as directly edible would teleport food and erase access/travel.  
**Reasoning:** The separation supports breaks, urgent hunger, hauling, household supply, and realistic interruption.  
**Consequences:** Hunger logic checks personal inventory first. Acquiring food from another container requires access and eventually a task/travel action.  
**Affected Systems:** Hunger, inventory, tasks, access, homes, Stockpiles.

### Current food-source priority is personal, then home, then public supply

**Date:** 2026-07-09  
**Status:** Accepted  
**Area:** Citizen food access  
**Decision:** When resolving food for a citizen, already carried food is preferred; available home food precedes public Stockpile food; with no accessible food, hunger continues toward starvation behavior.  
**Context:** Personal and household provisioning should matter even though public logistics remains the preferred hauling destination.  
**Reasoning:** Consumption priority and logistics stocking priority answer different questions.  
**Consequences:** Food must be moved into personal inventory before eating. Home supply cannot be implemented before real home storage/access exists. Exact search distance and emergency exceptions remain future design.  
**Affected Systems:** Hunger, homes, Stockpiles, access, tasks, hauling.

## 10. Work and Job Decisions

### Employment, attendance, active work, breaks, and off-duty state are distinct

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Jobs and scheduling  
**Decision:** A persistent job assignment does not mean a citizen is always present or productive. Schedules determine shifts; tasks determine active behavior; breaks and off-duty periods affect availability.  
**Context:** The first production prototype counts assigned living workers immediately, which is sufficient only as a bridge.  
**Reasoning:** Needs, hauling, leisure, and work all require a shared answer to “what is this citizen currently available to do?”  
**Consequences:** Phase 2F must introduce a central productive-eligibility provider used by production, UI, and validation.  
**Affected Systems:** Citizens, jobs, schedules, production, hauling, needs, validator.  
**Implementation Notes:** Employment and inverse worker lists exist; attendance does not.

### Workplaces expose generic spatial and behavioral policies

**Date:** 2026-07-10  
**Status:** Partially Implemented  
**Area:** Workplace architecture  
**Decision:** Workplace definitions declare production recipe, resource source, work location, work movement, break location, and overflow behavior instead of embedding all logic in Fishing Grounds.  
**Context:** Fisheries, mines, farms, bakeries, and workshops require different spatial behavior.  
**Reasoning:** Generic policy dispatch allows each system to interpret a stable contract without copying a complete production/task loop per building type.  
**Consequences:** Validate policy modes and required fields. Future executors dispatch on policy; they should not branch everywhere on one building type.  
**Affected Systems:** Buildings, production, source providers, schedules, tasks, movement, overflow.  
**Implementation Notes:** Policy dictionaries exist; most have no executor yet.

### Scheduled breaks remain in the work area and support eating/socializing

**Date:** 2026-07-09  
**Status:** Accepted  
**Area:** Work schedules and needs  
**Decision:** Ordinary workplace breaks are scheduled. Workers remain in the workplace's allowed break area and may eat or talk; happiness restoration is a primary purpose. After the break they return to work if still eligible.  
**Context:** An early rule said workers simply did not eat “on the job,” but the user wanted structured breaks rather than leaving the worksite arbitrarily.  
**Reasoning:** Workplace-local breaks preserve schedules and production while creating a real window for needs and social behavior.  
**Consequences:** Break-area policy matters; ordinary breaks are not long-distance errands. Emergency hunger interruption remains a separate path.  
**Affected Systems:** Schedules, workplaces, hunger, happiness, tasks, movement.

### Historical absolute rule: workers do not eat or interrupt during work blocks

**Date:** 2026-07-09  
**Status:** Superseded  
**Area:** Work and needs  
**Decision:** The earlier shorthand prohibited eating while actively working and reserved eating for scheduled breaks.  
**Context:** It corrected an even earlier assumption that workers would casually eat throughout ordinary work.  
**Consequences:** The ordinary-work part remains useful, but the absolute prohibition is replaced: severe graded hunger may suspend work, eat or seek food, and later resume.  
**Affected Systems:** Schedules, hunger, tasks, production eligibility.  
**Superseded By:** Hunger urgency is graded and scheduled breaks are separate from emergency interruption.

### Visible work movement must represent real tasks

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Work behavior and animation  
**Decision:** Citizens should move to legitimate work points, perform actual work state, and change points only when the simulation requires it. Do not add decorative wandering to make workplaces look active.  
**Context:** Animation before task/source semantics would misrepresent production.  
**Reasoning:** Presentation must reflect authoritative behavior so debugging and player expectations remain trustworthy.  
**Consequences:** Fishing workers later choose valid fishing points; station-based workplaces use real stations; animation waits until Phase 2M.  
**Affected Systems:** Tasks, work locations, movement, animation, production.

## 11. Hunger and Needs Decisions

### Hunger urgency is graded and can suspend/resume tasks

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Needs and task priority  
**Decision:** Hunger changes priority gradually. Comfortable or mildly hungry citizens do not automatically abandon ordinary work. Moderate urgency can make eating the next action, and severe urgency can suspend an active task, resolve food, and later resume the task if still valid.  
**Context:** Binary “work until break no matter what” and binary “eat whenever hungry” both produce implausible behavior.  
**Reasoning:** Graded urgency allows schedules and survival needs to coexist while protecting task continuity.  
**Consequences:** A task controller must retain suspended context, inventory, reservations, and workplace contribution state. Hunger priority should be a curve/score, not scattered threshold branches.  
**Affected Systems:** Hunger, tasks, schedules, production, inventory, reservations, movement.  
**Supersedes:** The absolute reading that workers can never eat or interrupt work during an active work block.

### Hunger threshold examples are tuning, not contracts

**Date:** 2026-07-10  
**Status:** Proposed  
**Area:** Needs tuning  
**Decision:** Conversation examples suggested that values around 70–100 should not outweigh ordinary duties, around 50 may cause eating before the next task, and around 30 with no food may justify interrupting current work. These are behavioral anchors, not settled cutoffs.  
**Context:** The user described desired priority at several illustrative hunger levels but explicitly did not settle exact numbers.  
**Reasoning:** The correct curve depends on drain rate, schedule length, food access, and testing.  
**Consequences:** Store tuning centrally and preserve qualitative ordering. Do not hard-code these examples as permanent invariants or duplicate them across systems.  
**Affected Systems:** Hunger scoring, AI/task selection, UI/debug.  
**Verification Needed:** Runtime tuning after Phase 2G exists.

### Scheduled breaks and emergency hunger are separate mechanisms

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Needs and scheduling  
**Decision:** Scheduled breaks are normal restorative windows; emergency hunger is a need-driven task interruption. One must not be implemented as a special case of the other.  
**Context:** Earlier statements about eating only during breaks were too absolute once severe hunger and task resumption were considered.  
**Reasoning:** Citizens should normally follow schedules but must remain capable of survival behavior.  
**Consequences:** Ordinary work does not include arbitrary snacking; carried food enables local emergency eating; food-seeking travel must correctly suspend attendance and later re-evaluate the old task.  
**Affected Systems:** Schedules, breaks, hunger, tasks, production eligibility.

### Happiness recovers through leisure and social opportunities

**Date:** 2026-07-09  
**Status:** Accepted  
**Area:** Needs and social simulation  
**Decision:** Happiness is a citizen need that can decline over time and recover through leisure/social behavior, including ordinary workplace breaks where appropriate.  
**Context:** Breaks should have a purpose beyond temporarily stopping production.  
**Reasoning:** Separating hunger from happiness allows distinct survival and morale pressures.  
**Consequences:** Happiness behavior should consume real schedule time and eventually real interaction opportunities. Exact rates and consequences are unsettled.  
**Affected Systems:** Citizens, schedules, breaks, social tasks, productivity.  
**Verification Needed:** Detailed modifiers, thresholds, and outcomes remain future design.

## 12. Hauling and Logistics Decisions

### Stockpiles are preferred logistics destinations over homes

**Date:** 2026-07-09  
**Status:** Accepted  
**Area:** Logistics priority  
**Decision:** General workplace output and ground-pile cleanup should go to the nearest compatible Stockpile with capacity before private home stocking. Household supply is a later demand-driven flow.  
**Context:** Sending general output to individual homes first would fragment food and make public access unreliable.  
**Reasoning:** Stockpiles provide shared availability and a clear first logistics backbone.  
**Consequences:** Destination selection must distinguish public logistics from household demand. Stockpile balancing is optional later work, not the first hauling goal.  
**Affected Systems:** Hauling, Stockpiles, homes, workplace output, ground piles, access.

### Available citizens perform general hauling

**Date:** 2026-07-09  
**Status:** Accepted  
**Area:** Labor and logistics  
**Decision:** Unemployed and off-shift citizens may perform general hauling. Dedicated hauler/laborer jobs may be introduced later if needed.  
**Context:** Logistics must function before every specialized occupation is designed.  
**Reasoning:** Availability-based labor reuses the citizen schedule model and makes unemployment meaningful.  
**Consequences:** Hauling cannot treat employed citizens as permanently unavailable or permanently free. A central availability query must respect shifts, breaks, urgent needs, and existing tasks.  
**Affected Systems:** Citizens, jobs, schedules, hauling, task selection.

### Tasks and reservations precede visible hauling

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Logistics architecture  
**Decision:** Build explicit tasks and reservations before visible hauling/pathfinding. Prove time and resource transfer abstractly before animation.  
**Context:** Two citizens can otherwise claim the same pile, source quantity, or destination capacity, and visual arrival can become the only source of truth.  
**Reasoning:** Reservations protect conservation; abstract travel exposes state-machine errors without rendering complexity.  
**Consequences:** Task cancellation releases reservations. If no destination capacity exists, resources stay at their source. Visible movement later follows, rather than causes, task progress.  
**Affected Systems:** Ground piles, inventories, Stockpiles, tasks, reservations, movement.  
**Implementation Notes:** Planned for Phases 2K–2M.

## 13. Time and Scheduling Decisions

### One global clock drives ordered simulation systems

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Simulation architecture  
**Decision:** The execution path is one persistent `SimulationClock` that owns time/ticks, one `SimulationCoordinator` that owns system order/performance measurement, one authoritative simulation entry, and ordered domain systems that mutate state. Renderers observe and never advance simulation.  
**Context:** An earlier plan considered advancing time from the city renderer, which would tie simulation to the visible scene and create duplicate or paused worlds.  
**Reasoning:** Global time must persist across scene transitions and drive off-screen-capable systems deterministically.  
**Consequences:** No independent workplace/citizen timers. New systems are added in explicit dependency order. Main menu suspension, new-game reset, pause, and scene resume remain deliberate lifecycle operations.  
**Affected Systems:** Clock, coordinator, production, future schedules/needs/logistics, renderers.  
**Supersedes:** Renderer-owned time advancement and per-workplace timers.  
**Implementation Notes:** Implemented as two autoloads and an ordered entry currently containing production.

### Historical clock plan: advance simulation from the city renderer

**Date:** 2026-07-09  
**Status:** Superseded  
**Area:** Simulation timing  
**Decision:** An early thin-clock proposal placed time fields on shared state and called the advance operation from the visible city renderer.  
**Context:** It was a minimal bridge before persistent autoload ownership was introduced.  
**Consequences:** Historical only. Renderers must not own or advance simulation.  
**Affected Systems:** Clock, scene lifecycle, production.  
**Superseded By:** One global clock drives ordered simulation systems.

### Production uses deterministic worker-time and whole batches

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Simulation timing and production  
**Decision:** Production progress derives from simulation minutes, valid productive workers, and site productivity using deterministic integer work units. Completed recipes produce whole batches.  
**Context:** Frame-time production would vary by performance and scene visibility.  
**Reasoning:** Tick-based work is reproducible, pause/speed compatible, and eventually testable.  
**Consequences:** Pause halts work; speed changes tick delivery rather than multiplying arbitrary per-frame output; scene transitions preserve progress; extra output cannot bypass capacity.  
**Affected Systems:** Clock, production, UI rates, saving, tests.

### Clock coordinates time; schedules and domain behavior remain separate

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Simulation boundaries  
**Decision:** The clock exposes time and tick signals but does not absorb shift logic, citizen priorities, production recipes, or hauling. Domain systems interpret time.  
**Context:** A global clock can become an unmaintainable god object if every timed behavior moves into it.  
**Reasoning:** Separation keeps scheduling and behavior testable and replaceable.  
**Consequences:** Phase 2F adds schedule evaluation as a domain system/provider, not as hard-coded clock branches.  
**Affected Systems:** Clock, schedules, needs, production, logistics.

## 14. Debug and Development-Control Decisions

### Global tilde debug mode persists across scenes

**Date:** 2026-07-08  
**Status:** Accepted  
**Area:** Debug workflow  
**Decision:** Tilde/backtick toggles one global debug flag. World and city expose scene-specific information while honoring the same enabled state across transitions.  
**Context:** Separate scene-local debug toggles lost state and duplicated behavior.  
**Reasoning:** Persistent debug mode supports rapid world/city comparison and remote/manual development.  
**Consequences:** Debug visibility and mutations must be gated by the shared flag. Enabling debug should not regenerate terrain textures or alter normal simulation.  
**Affected Systems:** World/city debug panels, object labels, camera debug keys.  
**Implementation Notes:** Current debug flag is held in session state and used by both renderers.

### Debug-only keyboard zoom uses the shared camera

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Debug input and camera  
**Decision:** While debug mode is enabled, `=` zooms in once and `-` zooms out once per keypress. Mouse-wheel zoom remains unchanged and available outside debug mode. Because both views use the shared strategy camera, the shortcut applies to world and city.  
**Context:** Remote/mobile development needed reliable discrete keyboard zoom without changing normal player controls.  
**Reasoning:** One shared implementation prevents scene drift and keeps the shortcut clearly debug-only.  
**Consequences:** Test both scenes and input consumption. Do not make held keys repeat unless explicitly requested.  
**Affected Systems:** Camera, debug state, world/city input.  
**Implementation Notes:** Present in the inspected snapshot.

### Debug resource injection targets selected public storage

**Date:** 2026-07-09  
**Status:** Accepted  
**Area:** Production/storage testing  
**Decision:** Debug resource-add controls require debug mode and a selected compatible public Stockpile; they respect local capacity. They are not gameplay income.  
**Context:** Storage and UI needed reproducible manual test data before hauling existed.  
**Reasoning:** Mutating a real selected container exercises the same capacity/accounting path instead of editing an abstract counter.  
**Consequences:** Keep the shortcut gated and visibly diagnostic. Future test fixtures may replace it, but normal simulation must not rely on it.  
**Affected Systems:** Debug input, Stockpiles, containers, resource bar.

### Validators and focused version counters are long-term debug armor

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Validation and observability  
**Decision:** Cross-system relationships need explicit validators, and UI/debug observers should use focused change versions or signals instead of treating every mutation as a generic refresh.  
**Context:** Stable IDs, inverse assignments, occupancy, storage, production, and future reservations create failure modes that visual inspection cannot reliably detect.  
**Reasoning:** Invariant checks localize corruption; focused versions avoid unnecessary work and stale panels.  
**Consequences:** New authoritative relationships add validation and correct invalidation. Cache keys must cover every state category the validator reads.  
**Affected Systems:** City state, production, citizens, UI, future tasks/logistics.  
**Implementation Notes:** Core city validation and focused versions exist; workplace validation/version caching is the immediate gap.

## 15. Deferred and Rejected Directions

### Advanced valley-aware river generation is postponed

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Deferred world generation  
**Decision:** Do not replace the current river system with a major valley/catchment algorithm during the city-simulation phase.  
**Reasoning:** It is a large independent task and does not unblock production, citizens, or logistics.  
**Revisit when:** World geography becomes the active development frontier or current rivers block a required mechanic.

### Wholesale custom-engine, C++ port, and premature ECS rewrite are deferred/rejected

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Deferred engine architecture  
**Decision:** Do not rewrite Paladin wholesale in C++, abandon Godot now, or introduce ECS merely because the project is expected to become large.  
**Reasoning:** Current systems and performance fixes remain viable in data-oriented GDScript; stable hot loops have not been profiled at target scale.  
**Revisit when:** Reproducible profiling shows a stable subsystem cannot meet requirements, at which point GDExtension or a more specialized representation can be evaluated narrowly.

### Visible citizens and animation wait for authoritative tasks

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Deferred presentation  
**Decision:** Do not add wandering citizen sprites as a shortcut. Visible citizens, pathfinding, movement, and basic animation are Phase 2M, after tasks/reservations and abstract travel.  
**Reasoning:** Animation without state creates misleading behavior and forces later systems to conform to a fake movement loop.  
**Revisit when:** Phase 2L proves task timing, sources, destinations, inventory transfer, and interruptions.

### Hauling, schedules, hunger, and movement do not leapfrog source correctness

**Date:** 2026-07-10  
**Status:** Accepted  
**Area:** Roadmap sequencing  
**Decision:** Finish Phase 2C validation and Phase 2D environmental source/productivity before ground overflow, schedules, hunger, inventory transfers, hauling, or movement.  
**Reasoning:** Later systems must know what is produced, where it exists, and why a workplace is productive.  
**Revisit when:** Production validation and source scoring pass their completion gates.

### Real disk save/load is deferred until state contracts stabilize

**Date:** 2026-07-10  
**Status:** Proposed  
**Area:** Persistence roadmap  
**Decision:** Keep the in-memory scene-transition prototype during the current simulation buildout; design real serialization after stable IDs and key resource/task relationships exist.  
**Reasoning:** Serializing volatile dictionary schemas too early creates migration work and may freeze poor ownership.  
**Consequences:** Current “save” terminology must never be presented as disk persistence. New data should still be designed with serializability and stable IDs in mind.  
**Verification Needed:** The exact persistence milestone, format, and versioning policy are not yet accepted.

## 16. Superseded Decision Index

| Old decision or rule | Replacement | Date/sequence | Affected systems |
| --- | --- | --- | --- |
| Newest uploaded/repository snapshot automatically overrides chat changes | Source priority uses latest explicit decision and confirmed edits above older snapshots; current code still controls exact implementation | Refined 2026-07-10 | All workflow |
| Leave Godot immediately / port the project wholesale to C++ | Continue Godot/GDScript; consider measured GDExtension hot loops later | Explored 2026-07-08, settled 2026-07-10 | Engine, all code |
| The entire mountain candidate zone uses mountain terrain | Outer/weaker region is hills on land; only concentrated peaks are mountain terrain | 2026-07-07 | Generation, placement, movement |
| A small fixed number of water/river tiles invalidates a 9×9 start | Only more than 90% ocean invalidates; rivers are exempt | 2026-07-07 | Region selection, Dev City |
| Committed starting-region border is bright purple | Committed selection is bright cyan; invalid preview stays red | 2026-07-07 | World interaction visuals |
| World and city maintain separate copies of base color rules | Shared map visual authority with explicit view-specific overlays | 2026-07-08 | Rendering and caching |
| World/city texture cache and debug-panel mechanics remain copied | Shared cache and debug-panel utilities | 2026-07-09 | Rendering/debug architecture |
| Top resource bar shows public Stockpiles only | Bar shows eligible non-ground city-object storage; public totals remain separate | 2026-07-10 | Resource UI, workplace/home storage, empire accounting |
| Workplace-stored fish is ignored by the city total | Workplace storage contributes to aggregate citywide stored accounting | 2026-07-10 | Fishing Grounds, resource bar |
| Produced fish enters each worker's personal inventory first | Production enters the workplace's local output storage first; citizen inventory later supports carrying/eating | 2026-07-10 | Production, citizens, hauling |
| Workers can never eat or interrupt during an active work block | Ordinary eating occurs during scheduled breaks or from carried food; severe graded hunger may suspend and later resume work | Refined 2026-07-10 | Hunger, schedules, tasks, production |
| Hunger is a binary task override | Hunger uses graded priority; exact thresholds remain tunable | 2026-07-10 | Needs, task selection |
| City renderer advances the world clock | Persistent autoload clock emits ticks; coordinator runs ordered systems; renderers observe | 2026-07-10 | Time, production, scenes |
| Each workplace can own an independent timer | One global simulation clock drives all workplace progress | 2026-07-10 | Production and performance |
| Animated citizens can be added early for visible progress | Animation waits until authoritative tasks, abstract travel, and pathfinding phases | 2026-07-10 | Citizens, movement, presentation |
| Ground overflow can be treated as city storage or invisible capacity | Ground piles are local physical state, excluded from stored totals; no legal location means production blocks | 2026-07-10 | Production, piles, hauling, accounting |
