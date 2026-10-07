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
version: 1.1
layer: BUSINESS
---

# Test level and test mode

## INTENT
Define the test level and test mode as development and testing tools, distinct from the shipped level.

## THE RULE / LOGIC
The test level (levels/test/) is a compact level designed to exercise the v1 mechanics; it is the testing ground for implementation and the base for end-to-end tests, uses placeholder art, and is not shipped. It follows the same level rules as every other level (see req_level_design_rules). The real first level (levels/01/) is designed later, once enough is built and checked against the test level; v1 ships that level, not the test level. A test mode, available only in the Linux build and debug Android builds (not the release build), loads fixture saves, speeds up or skips time, and injects taps and tilt from a script; it doesn't exist in the release build. All gameplay randomness comes from one seeded generator so test runs repeat exactly.

## TECHNICAL INTERFACE
Parented to req_scope_one_level_four_sections. The real first level's own design is out of scope for this spec (see vision_atd).

Pending the user's sign-off (proposed, not settled; the rule above is what is settled until then; the build already does this): exact repeat holds in two of crowd detail's three modes, not in every run. A debug flag, --crowd-detail=auto|always|off, picks how the detail ceiling of the crowd detail is set (debug builds only; a release build ignores it, says so, and is always auto; a bad value quits with exit code 1). auto follows the device's measured load (rule_crowd_detail_only_under_load) and is normal play's default; always fixes the ceiling at 3, the crowd's level as is, and is the simulation's own default, so test mode, the fixtures, test-mode scripts, the level bench and the tests run it unless a run asks otherwise; off fixes it at 0, the zoom's detail only. Seeded runs repeat exactly (same build, same seed, same state hash) in always and off. A run passed --crowd-detail=auto, as the phone's performance runs are, follows the device's load and doesn't repeat, and its hash isn't a fixture hash. A save written in auto still loads in every mode. Implemented in LoadMeter.parse_args and LoadMeter.ceiling_for (src/platform/load_meter.gd), the game root's crowd_detail_mode and use_crowd_detail (src/main.gd), Offscreen.detail_ceiling's default (src/sim/offscreen.gd) and test mode's argument pass-through (src/test_mode/test_mode.gd); guarded by tests/unit/test_crowd_detail_mode.gd.

## EXPECTATION
The automated end-to-end suite on the test level passes on the Linux build (definition of done item 31). Test mode is absent from release builds.
