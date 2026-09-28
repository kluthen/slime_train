---
id: req_controls_tap_zones
status: DRAFT
priority: 5
human_name: Controls and tap zones
parents:
  - [[req_loop_and_world]]
dependents:
  - [[req_camera_rails_and_framing]]
  - [[req_first_play_hint]]
  - [[req_parent_gate_and_access]]
  - [[req_tilt_input]]
type: REQUIREMENT
layer: BUSINESS
tags: [controls,input]
version: 1.0
---

# Controls and tap zones

## INTENT
Define the four tap zones, their priority order, and the feedback and safety rules that apply to every touch.

## THE RULE / LOGIC
The screen has four tap zones, checked in this order: (1) the top of the screen reveals the parent buttons and doesn't call; (2) the left and right edge buttons move the camera along the loop and don't call; (3) tapping an interactive object operates it and doesn't call; (4) anywhere else is a call. Every tap gets a visible answer: a ripple where the finger touched, and slimes in range turn toward it. On the very first play, if the child hasn't called after about 10 s, a wordless pulsing mark appears near the first sleeper, and never appears again once the first call is made. The first touch wins: while one finger is down, other touches are ignored. Tilt: the world stays fixed on the screen and gravity turns with the phone, up to plus or minus 45 degrees, with a dead zone of about 10 degrees; neutral is how the phone was held when the session started, and lying flat counts as neutral; only free slimes feel tilt, and tilt is never needed to make progress. No hold, drag, pinch or multi-finger gesture is used in v1.

## TECHNICAL INTERFACE
Parented to req_loop_and_world. Governs req_call_mechanic (zone 4), req_interactive_objects_general (zone 3), req_camera_rails_and_framing (zone 2), and req_parent_gate_and_access (zone 1).

## EXPECTATION
Every tap produces a visible ripple, including taps that do nothing else (definition of done item 15). On a fresh install, if the child hasn't called within about 10 s, a wordless pulsing mark appears near the first sleeper and never appears again once the first call is made (definition of done item 16). While one finger is down, a second touch does nothing (definition of done item 17). Only free slimes respond to tilt, within plus or minus 45 degrees and outside the roughly 10-degree dead zone (definition of done item 8). Opening all gates of the level never requires tilt (definition of done item 12).
