---
id: req_test_level_and_test_mode
status: DRAFT
type: REQUIREMENT
priority: 3
human_name: Test level and test mode
tags: [testing]
parents:
  - [[req_scope_one_level_four_sections]]
dependents: []
version: 1.0
layer: BUSINESS
---

# Test level and test mode

## INTENT
Define the test level and test mode as development and testing tools, distinct from the shipped level.

## THE RULE / LOGIC
The test level (levels/test/) is a compact level designed to exercise the v1 mechanics; it is the testing ground for implementation and the base for end-to-end tests, uses placeholder art, and is not shipped. It follows the same level rules as every other level (see req_level_design_rules). The real first level (levels/01/) is designed later, once enough is built and checked against the test level; v1 ships that level, not the test level. A test mode, available only in the Linux build and debug Android builds (not the release build), loads fixture saves, speeds up or skips time, and injects taps and tilt from a script; it doesn't exist in the release build. All gameplay randomness comes from one seeded generator so test runs repeat exactly.

## TECHNICAL INTERFACE
Parented to req_scope_one_level_four_sections. The real first level's own design is out of scope for this spec (see vision_atd).

## EXPECTATION
The automated end-to-end suite on the test level passes on the Linux build (definition of done item 31). Test mode is absent from release builds.
