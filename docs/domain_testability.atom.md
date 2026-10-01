---
id: domain_testability
status: DRAFT
human_name: Testability built in
type: DOMAIN
layer: BUSINESS
version: 1.0
priority: 2
tags: [architecture,rationale,testing]
parents:
  - [[domain_architecture_rationale]]
dependents: []
---

# Testability built in

## INTENT
Record how testability is built into the game: repeatable randomness and a test mode.

## THE RULE / LOGIC
Testability is built in: all gameplay randomness comes from one seeded generator so test runs repeat exactly within one build (a desktop and an Android build aren't promised identical results if the tick ever moves to native code), and a test mode (Linux build and debug Android builds only) loads fixture saves, speeds up or skips time, and injects taps and tilt from a script.

## TECHNICAL INTERFACE
Narrative context only; no code tag. Read by whoever designs ARCHITECTURE-layer atoms for testing and test mode, to understand why the constraint exists before proposing an alternative.

## EXPECTATION
N/A (narrative atom, not independently testable). Its content is corroborated by the ARCHITECTURE-layer atoms that eventually implement this decision, and by the REQUIREMENT/RULE atoms whose behaviour depends on it (e.g. req_test_level_and_test_mode).
