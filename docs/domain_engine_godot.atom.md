---
id: domain_engine_godot
status: DRAFT
version: 1.0
priority: 2
parents:
  - [[domain_architecture_rationale]]
dependents: []
type: DOMAIN
tags: [architecture,rationale,engine]
human_name: Engine choice: Godot 4
layer: BUSINESS
---

# Engine choice: Godot 4

## INTENT
Record why Godot 4 is the engine Slime Train is built on.

## THE RULE / LOGIC
Godot 4 was chosen for its open-source licence, strong 2D support, and exports to both Android and a Linux desktop build from the same project (Unity and Unreal were ruled out by the project owner).

## TECHNICAL INTERFACE
Narrative context only; no code tag. Read by whoever designs ARCHITECTURE-layer atoms that depend on the engine, to understand why the constraint exists before proposing an alternative.

## EXPECTATION
N/A (narrative atom, not independently testable). Its content is corroborated by the ARCHITECTURE-layer atoms that eventually implement this decision, and by the REQUIREMENT/RULE atoms whose behaviour depends on it (e.g. req_platform_and_performance_targets).
