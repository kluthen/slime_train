---
id: req_platform_and_performance_targets
status: DRAFT
tags: [platform,performance]
dependents: []
version: 1.1
type: REQUIREMENT
layer: BUSINESS
priority: 4
human_name: Platform and performance targets
parents:
  - [[req_scope_one_level_four_sections]]
---

# Platform and performance targets

## INTENT
Define the target platform, phones and performance v1 must hit, and where each is tested.

## THE RULE / LOGIC
Platform: Godot 4, targeting Android, with a Linux desktop build for development and tests; v1 is a paid app at about 3 to 5 dollars, with no purchases inside the app. Reference phone: Samsung Galaxy S20 FE. Floor phone: a budget phone of the Galaxy A14 class; if the floor phone can't hold 200 slimes, the floor rises, but the 200-slime cap stays. Performance targets: 60 frames per second on the reference phone in normal play; at least 30 fps on the floor phone with the level's largest realistic pile on one screen (a full basket plus the train, mostly still), measured both cold and after 5 minutes of play. The 200-slime cap stays. 200 moving slimes on one screen is an abuse test with an abuse target, not a 30 fps target: on the reference phone it must not crash or freeze and must keep at least 15 fps. The 30 fps target is the dense moving case's (200 train slimes packed along the loop line). Test environments: the Linux desktop build is used for gameplay, level logic, saves and automated end-to-end tests, but not anything Android-specific; the Android emulator is used for the Android lifecycle, screen pinning, the parent flows, save and restore, and rough tilt, but not performance or touch/tilt feel; real phones (reference and floor) are used for performance, touch and tilt feel, and playtests with children, but not fast iteration; the Google Play pre-launch report (later) is used for smoke tests on many real phones, not detailed performance work.

## TECHNICAL INTERFACE
Parented to req_scope_one_level_four_sections.

Pending the user's sign-off (proposed, not settled; the rule and expectation above are what is settled): the expectation would add the two stress targets on the reference phone, with the camera on section 3's bowl of the test level: the dense moving case holds at least 30 fps, and the abuse case (200 moving slimes, all piled in the bowl) doesn't crash or freeze and keeps at least 15 fps. The dense moving case is 200 size-1 train slimes along the loop line, 3 per 100 px of loop and 4 per 100 px at the bottom of the bowl, filled from the bowl outward, none at or past switch 3. Proposed, how they are measured: a target is met on the mean frame rate over a 62 s run, with the 5th percentile reported alongside; "no freeze" means a 10,000-tick run ends without an error and the train hops in every 600-tick window; until the reference phone is measured, a slowed desktop run that emulates the phone stands in. Measuring tools (debug only, no effect on the simulation or saves): the per-period performance log line with its train-hop and short-hop counts, the level benchmark, the 10,000-tick throughput run, and the stress fixtures' builder; in src/debug/, src/sim/train.gd, src/sim/slime_bodies.gd and tools/.

## EXPECTATION
At least 60 fps on the reference phone in normal play, and at least 30 fps on the floor phone with the level's largest realistic pile on one screen (a full basket plus the train, mostly still), cold and after 5 minutes of play (definition of done item 30).
