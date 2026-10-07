---
id: req_platform_and_performance_targets
status: DRAFT
tags: [platform,performance]
dependents: []
version: 1.4
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
Platform: Godot 4, targeting Android, with a Linux desktop build for development and tests; v1 is a paid app at about 3 to 5 dollars, with no purchases inside the app. Reference phone: Samsung Galaxy S20 FE. Floor phone: a budget phone of the Galaxy A14 class; if the floor phone can't hold 200 slimes, the floor rises, but the 200-slime cap stays. Performance targets: 60 frames per second on the reference phone in normal play; at least 30 fps on the floor phone with the level's largest realistic pile on one screen (a full basket plus the train, mostly still), measured both cold and after 5 minutes of play. The 200-slime cap stays. 200 moving slimes on one screen is an abuse test with an abuse target, not a 30 fps target: on the reference phone it must not crash or freeze and must keep at least 15 fps. The 30 fps target is the dense moving case's (200 train slimes packed along the loop line). A frame runs at most 2 simulation ticks at normal speed (a faster debug speed scales the cap: 2 times the speed, rounded up), so an overloaded scene plays in slow motion instead of collapsing into a catch-up spiral. Headroom target, measured and recorded at each phone session but not a v1 gate and not part of the definition of done (the frame-rate targets are the gate): per 16.7 ms frame on the reference phone, the simulation takes at most 8 ms and drawing at most 4 ms, leaving at least 4.7 ms for later animation, music and the system. Test environments: the Linux desktop build is used for gameplay, level logic, saves and automated end-to-end tests, but not anything Android-specific; the Android emulator is used for the Android lifecycle, screen pinning, the parent flows, save and restore, and rough tilt, but not performance or touch/tilt feel; real phones (reference and floor) are used for performance, touch and tilt feel, and playtests with children, but not fast iteration; the Google Play pre-launch report (later) is used for smoke tests on many real phones, not detailed performance work.

## TECHNICAL INTERFACE
Parented to req_scope_one_level_four_sections. The tick cap is MAX_TICKS_PER_FRAME (2) in src/main.gd, scaled with the speed by FixedStep.max_ticks_for in src/sim/fixed_step.gd (the user's, 2026-10-07). The frame budget's simulation share corresponds, on the desktop, to a tick of about 2.4 to 3.8 ms; desktop tick numbers are recorded against it, not gated.

Pending the user's sign-off (proposed, not settled; the rule and expectation above are what is settled): the expectation would add the two stress targets on the reference phone, with the camera on section 3's bowl of the test level: the dense moving case holds at least 30 fps, and the abuse case (200 moving slimes, all piled in the bowl) doesn't crash or freeze and keeps at least 15 fps. The dense moving case is 200 size-1 train slimes along the loop line, 3 per 100 px of loop and 4 per 100 px at the bottom of the bowl, filled from the bowl outward, none at or past switch 3. Proposed, how they are measured: a target is met on the mean frame rate over a 62 s run, with the 5th percentile reported alongside; "no freeze" means a 10,000-tick run ends without an error and the train hops in every 600-tick window; until the reference phone is measured, a slowed desktop run that emulates the phone stands in. Measuring tools (debug only, no effect on the simulation or saves): the per-period performance log line with its train-hop and short-hop counts, the level benchmark, the 10,000-tick throughput run, the stress fixtures' builder, and the train-flow probe (tools/train_flow_probe.gd) with its fusion and bump counters; in src/debug/, src/sim/train.gd, src/sim/slime_bodies.gd, src/sim/fusion.gd and tools/.

Also pending (the user's reading, its wording proposed): every frame-rate target above is judged with the loop start's crowding set aside. The windows where slimes coming home crowd the loop's start (in the s3-basket-59of60 fixture, its section 1 window once the train comes home) are measured and recorded, not gated; every other target and number is unchanged. That crowding and its frame rate are reviewed after v1, with the test level's start and the geyser.

Also pending (proposed with crowd detail under load, chunk 22c; the build already does this): every frame-rate target above, definition of done item 30 included, is judged in crowd detail's auto mode, the shipping behaviour (rule_crowd_detail_only_under_load), when the reference phone's measurement is repeated. The performance log's PERF line also reports the detail ceiling, the crowd's level, the detail used, and the load meter's last busy share and missed beats, in any mode; its PERF_INFO line reports crowd_detail=<mode>; in auto, each ceiling step prints a PERF_CEILING line with its reason. The phone's performance script (tools/android/perf.sh) takes --crowd-detail=auto|always|off, auto by default in both of its modes so a fixture run measures auto too, and keeps the PERF_CEILING lines in perf.log; always or off are for comparison. In src/debug/perf_log.gd and tools/android/perf.sh.

## EXPECTATION
At least 60 fps on the reference phone in normal play, and at least 30 fps on the floor phone with the level's largest realistic pile on one screen (a full basket plus the train, mostly still), cold and after 5 minutes of play (definition of done item 30).
