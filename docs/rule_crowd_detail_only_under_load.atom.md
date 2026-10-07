---
id: rule_crowd_detail_only_under_load
status: REVIEW
layer: BUSINESS
human_name: Crowd detail only when the device can't keep up
parents:
  - [[req_offscreen_simulation]]
dependents: []
version: 1.1
priority: 4
tags: [performance,offscreen,crowd_detail]
type: RULE
---

# Crowd detail only when the device can't keep up

## INTENT
Keep every slime's full ring detail on a device that keeps up, and let a crowd cut ring points only while the device can't.

## THE RULE / LOGIC
In normal play, a crowd may lower its rings' detail only as far as a detail ceiling (0 to 3) allows, and the ceiling follows the device's measured load. About each second of real time the game judges a window: pressed when the frame's work takes more than 85 % of the window's time, or when 3 or more frames ran 2 ticks or more to catch up; calm when the work takes under 60 % and at most 1 frame ran 2 ticks or more; otherwise in the band. A window holding a frame over 250 ms, or run at a debug speed other than 1x, is dropped and changes nothing. The ceiling starts at 0 (full detail) at a fresh start and after a load. A pressed window raises it one step, at most 3; 3 calm windows in a row lower it one step, and the count starts again; a window in the band holds it and restarts the count. A bounce, a pressed window within 10 judged windows after a step down, makes the next step down wait for 60 calm windows in a row instead of 3; a step down that lasts 10 judged windows without a pressed one, or a load, sets the wait back to 3. Neither the ceiling nor the wait is saved.

## TECHNICAL INTERFACE
Parented to req_offscreen_simulation, whose crowd detail takes the higher of the zoom's level and the lower of the crowd's level and this ceiling. Implemented in LoadMeter (src/platform/load_meter.gd: feed, verdict_for, reset), in the scene layer of every build, release included, since the simulation reads no clock. The game root (src/main.gd) hands the ceiling to Offscreen.detail_ceiling (src/sim/offscreen.gd) in step_simulation before every tick, like the tilt, and resets the meter in _use_simulation (a new simulation, a load, a reset). Values: WINDOW_USEC 1 s, LONG_FRAME_USEC 250 ms, PRESSED_SHARE 0.85, PRESSED_MISSED 3, MISSED_TICKS 2, CALM_SHARE 0.60, CALM_MISSED 1, CALM_WINDOWS 3, BOUNCE_WINDOWS 10, BACKOFF_WINDOWS 60. The debug modes that fix the ceiling instead (always at 3, off at 0) and exact repeat are under req_test_level_and_test_mode; the perf log's report of the meter is under req_platform_and_performance_targets.

Settled by the user (2026-10-07, approved as proposed and as built in chunk 22c): this rule as a whole, the load meter's window, the pressed and calm readings, the ceiling's steps, the modes and the hold after a bounce included; the values are the values to build to, still to try. Known risk, accepted with it: after a bounce, crowd detail stays coarser for up to about a minute after the device has recovered.

## EXPECTATION
On a device that keeps up, the ceiling stays 0 and rings keep their full points whatever the crowd. A pressed window raises the ceiling one step and 3 calm windows in a row lower it one; a pressed window within 10 judged windows of a step down makes the next step down wait for 60 calm windows; a dropped window changes nothing; after a load the ceiling is 0 and the wait 3. On a device calm at one ceiling and pressed one step below it, the ceiling makes 5 steps or fewer in 2 minutes after its climb (the reading of a few).
