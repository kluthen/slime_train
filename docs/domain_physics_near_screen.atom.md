---
id: domain_physics_near_screen
status: DRAFT
layer: BUSINESS
version: 1.0
human_name: Physics only near the screen
type: DOMAIN
priority: 2
tags: [architecture,rationale,simulation]
parents:
  - [[domain_architecture_rationale]]
dependents: []
---

# Physics only near the screen

## INTENT
Record why physics only runs near the screen and how off-screen slimes move instead.

## THE RULE / LOGIC
Physics only runs near the screen, because simulating up to 200 slimes at once on a mid-range phone at all times is not feasible; off-screen slimes move along authored paths at a deterministic pace, which also makes their behaviour predictable and testable.

## TECHNICAL INTERFACE
Narrative context only; no code tag. Read by whoever designs ARCHITECTURE-layer atoms for off-screen movement, to understand why the constraint exists before proposing an alternative.

## EXPECTATION
N/A (narrative atom, not independently testable). Its content is corroborated by the ARCHITECTURE-layer atoms that eventually implement this decision, and by the REQUIREMENT/RULE atoms whose behaviour depends on it (e.g. req_offscreen_simulation, rule_max_200_slimes_per_level).
