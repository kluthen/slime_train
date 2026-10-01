---
id: domain_authored_routes
status: DRAFT
human_name: Authored routes
version: 1.0
priority: 2
tags: [architecture,rationale,routes]
dependents: []
type: DOMAIN
layer: BUSINESS
parents:
  - [[domain_architecture_rationale]]
---

# Authored routes

## INTENT
Record why the loop and the routes back to it are authored routes rather than physics or general pathfinding.

## THE RULE / LOGIC
Exploration routes back to the loop are authored level data (paths drawn in the editor), not general pathfinding. The loop itself is a drawn route, not physics, so the train always flows with no input regardless of what physics does; only free slimes are driven by physics alone.

## TECHNICAL INTERFACE
Narrative context only; no code tag. Read by whoever designs ARCHITECTURE-layer atoms for the loop and the routes back, to understand why the constraint exists before proposing an alternative.

## EXPECTATION
N/A (narrative atom, not independently testable). Its content is corroborated by the ARCHITECTURE-layer atoms that eventually implement this decision, and by the REQUIREMENT/RULE atoms whose behaviour depends on it (e.g. req_loop_and_world, rule_loop_travelable_with_no_input, rule_exploration_branch_has_route_back).
