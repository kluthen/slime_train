---
id: domain_simulation_tick
status: DRAFT
type: DOMAIN
layer: BUSINESS
priority: 2
tags: [architecture,rationale,simulation]
human_name: Where the simulation tick runs
version: 1.1
parents:
  - [[domain_architecture_rationale]]
dependents: []
---

# Where the simulation tick runs

## INTENT
Record where the simulation tick runs (GDScript or native code), why, and what stays in GDScript either way.

## THE RULE / LOGIC
The simulation tick was first kept in GDScript: in play a big crowd is mostly a still pile, and resting slimes, sleepers and a full basket's slimes stop being fully simulated (flagged, unresolved: measured, open piles of 40 or more slimes rest only after minutes or never, and an awake slime keeps waking a resting pile, which undercuts the still-pile expectation). A C++ version of the tick (rings, contacts, terrain) was prepared and verified as a contingency, to be adopted only if the whole game measured at the endgame missed its targets on either phone. The targets were missed, and fewer ring points in a crowd helped but was not enough on its own, so the user gave the go (2026-09-30) to build the native tick, built after a pass on what drawing costs. It ships with results deterministic within one build rather than bit-equal to the GDScript tick, saves loading under either tick, and the GDScript tick kept as a fallback (the user's, 2026-10-07). The behaviour around the tick (hops, the call's phases, fusion timing) stays in GDScript either way.

## TECHNICAL INTERFACE
Narrative context only; no code tag. Read by whoever designs ARCHITECTURE-layer atoms for the simulation tick, to understand why the constraint exists before proposing an alternative.

## EXPECTATION
N/A (narrative atom, not independently testable). Its content is corroborated by the ARCHITECTURE-layer atoms that eventually implement this decision, and by the REQUIREMENT/RULE atoms whose behaviour depends on it (e.g. req_platform_and_performance_targets, req_offscreen_simulation).
