---
id: domain_camera_on_rails
status: DRAFT
human_name: Camera on rails
type: DOMAIN
layer: BUSINESS
version: 1.0
priority: 2
parents:
  - [[domain_architecture_rationale]]
tags: [architecture,rationale,camera]
dependents: []
---

# Camera on rails

## INTENT
Record why the camera runs on rails with automatic framing.

## THE RULE / LOGIC
The camera runs on rails with automatic framing because a 3-year-old can press two edge buttons but can't manage a free camera or zoom.

## TECHNICAL INTERFACE
Narrative context only; no code tag. Read by whoever designs ARCHITECTURE-layer atoms for the camera, to understand why the constraint exists before proposing an alternative.

## EXPECTATION
N/A (narrative atom, not independently testable). Its content is corroborated by the ARCHITECTURE-layer atoms that eventually implement this decision, and by the REQUIREMENT/RULE atoms whose behaviour depends on it (e.g. req_camera_rails_and_framing).
