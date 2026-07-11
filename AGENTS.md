# AGENTS.md

> **Code is the source of truth.**
>
> This document intentionally describes Paladin's architecture, stable responsibilities, and engineering philosophy. It is **not** an implementation tracker. When this document and the latest code disagree, always trust the newest verified code.

# Project Identity

Paladin is a simulation-first strategy game. Every visible action should originate from deterministic simulation state rather than renderer-owned logic.

The simulation is intended to scale naturally from:
- individual citizens
- workplaces
- cities
- regions
- kingdoms
- empires

without changing the underlying design philosophy.

# Architectural Principles

- Simulation owns truth.
- Rendering visualizes truth.
- UI inspects and requests actions; it does not simulate.
- Validation detects corruption instead of silently repairing it.
- Systems communicate through well-defined ownership rather than reaching into unrelated systems.
- Prefer data-driven behavior over one-off special cases.

# Major Responsibilities

## WorldData
Owns authoritative simulation state and cross-system coordination. Other systems should treat it as the canonical world model.

## Simulation Coordinator
Coordinates deterministic simulation ordering. Systems should execute in a stable order every simulation tick.

## Citizens
Autonomous agents driven by needs, assignments, schedules, logistics, and long-term goals. Citizens should never exist merely as animation objects.

## Workplaces
Represent production and service locations through configurable policies rather than unique subclasses whenever practical.

## Logistics
Responsible for movement of resources between inventories and containers. Resources should move because a citizen (or future transport system) physically moved them.

## Validation
Continuously protects simulation integrity by detecting invalid state early.

## Rendering
Responsible only for visualization, input presentation, debugging tools, and editor interaction.

# Safe Modification Rules

1. Inspect relevant scripts before editing.
2. Prefer surgical edits over large rewrites.
3. Preserve deterministic simulation ordering.
4. Keep rendering independent from simulation logic.
5. Do not duplicate ownership of state.
6. Favor reusable systems over special-case implementations.
7. Treat repository documentation as architectural guidance rather than implementation evidence.
