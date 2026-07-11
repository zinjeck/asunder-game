# DECISION_LOG.md

> **Purpose**
>
> Records long-lived design decisions and their rationale. It intentionally avoids milestone tracking.

# Simulation First

**Decision:** Simulation owns authoritative state.

**Reason:** Rendering can be recreated at any time without changing gameplay.

---

# Deterministic Ticks

**Decision:** World progression occurs through deterministic simulation ticks.

**Reason:** Predictability simplifies debugging, validation, multiplayer possibilities, and replayability.

---

# Autonomous Citizens

**Decision:** Citizens act as independent agents instead of scripted animations.

**Reason:** Emergent behavior is a core design goal.

---

# Logistics

**Decision:** Resources move through logistics rather than teleportation.

**Reason:** Transportation itself is meaningful gameplay.

---

# Generic Inventories

**Decision:** Containers expose generic inventory behavior.

**Reason:** Shared inventory logic scales across citizens, buildings, cities, and future systems.

---

# Policy Driven Workplaces

**Decision:** Workplace behavior is described through configurable policies whenever practical.

**Reason:** Reduces hardcoded building behavior and improves extensibility.

---

# Validation

**Decision:** Detect invalid state rather than silently repairing it.

**Reason:** Hidden repairs obscure simulation bugs.

---

# Separation of Concerns

**Decision:** Rendering, simulation, validation, and UI have distinct responsibilities.

**Reason:** Clear ownership reduces coupling and supports future refactoring.

---

# Documentation Philosophy

**Decision:** Repository documentation explains architecture and design intent rather than implementation progress.

**Reason:** Stable documentation remains useful through frequent coding sessions and refactors.
