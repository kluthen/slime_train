---
id: domain_soft_slime_simulation
status: DRAFT
version: 1.0
priority: 2
tags: [architecture,rationale,simulation]
parents:
  - [[domain_architecture_rationale]]
human_name: Soft slimes simulated in custom code
type: DOMAIN
layer: BUSINESS
dependents: []
---

# Soft slimes simulated in custom code

## INTENT
Record why slimes are soft bodies simulated in custom code, meeting the terrain through the simulation's own test.

## THE RULE / LOGIC
Slimes are soft: each is a ring of points joined by springs in custom code, with fusion and splitting as operations on the ring; no engine provides this out of the box. Slimes meet the curved terrain through the simulation's own test against the baked terrain outlines, not the engine's collision shapes.

## TECHNICAL INTERFACE
Narrative context only; no code tag. Read by whoever designs ARCHITECTURE-layer atoms for the slime simulation, to understand why the constraint exists before proposing an alternative.

## EXPECTATION
N/A (narrative atom, not independently testable). Its content is corroborated by the ARCHITECTURE-layer atoms that eventually implement this decision, and by the REQUIREMENT/RULE atoms whose behaviour depends on it (e.g. req_slime_states, rule_fusion_contact_time).
