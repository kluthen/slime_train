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
version: 1.1
---

# Controls and tap zones

## INTENT
Define the four tap zones, their priority order, and the feedback and safety rules that apply to every touch.

## THE RULE / LOGIC
The screen has four tap zones, checked in this order. (1) The parent zone: a band 7 mm high along the top of the screen, measured on the screen, full width and unmarked; a tap there reveals the parent buttons and doesn't call. (2) The left and right edge buttons: each is a strip over the screen's whole height, 10% of the screen's width from its edge, below the parent zone (the parent zone wins where they overlap, in the top corners). A tap anywhere in a strip is a press that moves the camera along the loop: it neither calls nor operates an object under it. While the edge buttons are hidden (bedtime), a tap there is an ordinary tap. (3) An interactive object that answers a tap right now (in v1, only a switch whose basket is filling): the tap operates it and doesn't call. (4) Anywhere else: a call. Every tap gets a visible answer: a ripple where the finger touched, and slimes in range turn toward it. On the very first play of a fresh save, a wordless pulsing hint appears near the first sleeper if the child hasn't called after about 10 s (its full rule is req_first_play_hint). The first touch wins: while one finger is down, other touches are ignored; a touch that starts while another finger is down gets nothing at all, not even a ripple, and stays ignored until it lifts, even if the first finger lifts before it. One exception, to be checked in a playtest: a touch on an edge strip held longer than about 5 s (a resting thumb) keeps moving the camera but stops counting as the first touch, so the next touch is handled as if no finger were down. Tilt turns gravity for free slimes only and is never needed to make progress (its full rule is req_tilt_input). No drag, pinch or multi-finger gesture is used in v1, and no hold gesture of its own: holding an edge button only keeps the camera moving, as the same button pressed longer.

## TECHNICAL INTERFACE
Parented to req_loop_and_world. Governs req_parent_gate_and_access (zone 1), req_camera_rails_and_framing (zone 2), req_interactive_objects_general (zone 3) and req_call_mechanic (zone 4); req_first_play_hint and req_tilt_input hold the full rules for the hint and for tilt.

## EXPECTATION
Every tap produces a visible ripple, including taps that do nothing else; a touch ignored under the first-touch rule isn't a tap and shows nothing (definition of done item 15). While one finger is down, a second touch does nothing, not even a ripple, and stays ignored after the first finger lifts; after about 5 s, a touch resting on an edge strip no longer blocks others (definition of done item 17). A tap anywhere in an edge strip (the screen's whole height below the parent zone, 10% of its width from the edge) moves the camera, never calls and operates no object under it; at bedtime, with the strips hidden, a tap there is an ordinary tap (definition of done item 18). A tap less than 7 mm from the top of the screen reveals the parent buttons; one just below the band calls or, on a strip, moves the camera. A tap on an object that doesn't answer taps right now is a call. Only free slimes respond to tilt, and opening all gates never requires tilt (definition of done items 8 and 12).
