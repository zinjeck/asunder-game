# CURRENT_STATE.md

> **Purpose**
>
> This document describes how Paladin is intended to behave. It intentionally avoids tracking implementation progress.

# Simulation Philosophy

Paladin models a living society rather than scripted gameplay.

Citizens are autonomous actors that perceive needs, evaluate priorities, travel through the world, transport resources, work, rest, socialize, and eventually participate in military and political systems.

# Time

Simulation advances through deterministic ticks.

Each tick represents authoritative world progression. Rendering may interpolate or redraw freely without affecting simulation.

# Citizens

Citizens should make decisions using competing priorities instead of fixed scripts.

Long-term expectations include:
- needs
- employment
- logistics
- relationships
- schedules
- breaks
- travel
- housing
- happiness
- future family and political systems

# Logistics

Resources always exist somewhere.

They may reside in:
- citizen inventories
- workplace inventories
- stockpiles
- homes
- city storage
- future vehicles

Ground piles intentionally remain physical world objects instead of automatically belonging to cities.

# Production

Production is work-driven rather than timer-driven.

Workers contribute work toward batches according to productivity, workplace policy, available resources, and environmental conditions where applicable.

# Cities

Cities aggregate infrastructure, population, logistics, storage, production, and governance.

Cities should eventually function as members of larger regional and imperial simulations without redesigning their internal logic.

# Rendering

Renderers visualize simulation state, manage presentation, debugging interfaces, selection, camera behavior, and user interaction.

Simulation decisions should remain outside rendering whenever possible.

# Performance

Simulation should remain deterministic, scalable, and measurable.

Optimization should preserve correctness before pursuing speed.
