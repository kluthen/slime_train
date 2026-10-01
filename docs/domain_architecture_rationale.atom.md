---
id: domain_architecture_rationale
status: DRAFT
tags: [architecture,rationale]
parents: []
dependents:
  - [[domain_authored_routes]]
  - [[domain_camera_on_rails]]
  - [[domain_drawing]]
  - [[domain_engine_godot]]
  - [[domain_level_authoring]]
  - [[domain_parent_lock_offline]]
  - [[domain_physics_near_screen]]
  - [[domain_saves_per_level]]
  - [[domain_simulation_tick]]
  - [[domain_soft_slime_simulation]]
  - [[domain_testability]]
version: 2.0
type: DOMAIN
layer: BUSINESS
priority: 2
human_name: Architecture rationale
---

# Architecture rationale

## INTENT
Record why v1's foundational technical decisions were made, as context for architecture atoms that will implement them; this atom is the index, and each decision with its reason lives in one child atom.

## THE RULE / LOGIC
Slime Train started with no prior code base; the code base is now the one built for v1, and new work fits into it. Its architecture decisions and their reasons are recorded one decision per child atom (this atom's dependents): the engine, level authoring, the soft slimes' simulation, where the simulation tick runs, drawing, physics only near the screen, authored routes, the camera, the parent lock, saves, and testability. This atom adds no decision of its own.

## TECHNICAL INTERFACE
Narrative context only; no code tag. Read, with its child atoms, by whoever designs ARCHITECTURE-layer atoms for these subsystems, to understand why a constraint exists before proposing an alternative. Specs and notes that cite this atom by id still land here, and the child atoms say the rest.

## EXPECTATION
N/A (narrative index atom, not independently testable). Every architecture decision and its reason sits in exactly one child atom, each parented to this one; this atom stays short.
