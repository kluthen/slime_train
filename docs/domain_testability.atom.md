---
id: domain_testability
status: DRAFT
human_name: Testability built in
type: DOMAIN
layer: BUSINESS
version: 1.1
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
Testability is built in: all gameplay randomness comes from one seeded generator so test runs repeat exactly within one build on one platform. The desktop and the phone give different results even with the same tick, because Android's math library rounds one angle function differently from the desktop's; a desktop tool reproduces the phone's results, and repeating across devices isn't a v1 aim. A test mode (Linux build and debug Android builds only) loads fixture saves, speeds up or skips time, and injects taps and tilt from a script.

## TECHNICAL INTERFACE
Narrative context only; no code tag. The desktop tool that reproduces a phone's state hashes is tools/linux/bionic_libm.sh (a preloaded shim giving a desktop run Android's angle functions). Read by whoever designs ARCHITECTURE-layer atoms for testing and test mode, to understand why the constraint exists before proposing an alternative.

## EXPECTATION
N/A (narrative atom, not independently testable). Its content is corroborated by the ARCHITECTURE-layer atoms that eventually implement this decision, and by the REQUIREMENT/RULE atoms whose behaviour depends on it (e.g. req_test_level_and_test_mode).
