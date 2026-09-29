---
id: req_idle_camera_and_screensaver_zoom
status: DRAFT
type: REQUIREMENT
layer: BUSINESS
human_name: Idle camera and screensaver zoom
tags: [camera,screensaver]
parents:
  - [[req_camera_rails_and_framing]]
dependents: []
priority: 4
version: 1.1
---

# Idle camera and screensaver zoom

## INTENT
Define the camera's automatic behaviour when nobody has given input for a while, and its shared zoom with screensaver mode.

## THE RULE / LOGIC
After 45 s with no input, the camera glides to the train slime nearest the middle of the view and follows it; if that slime fuses, it follows the fused slime, and if it splits, one of the pieces. The cue, starting 10 s before the idle camera takes over, is a slow zoom-out. Any touch takes back control and also does its normal job (call, camera move, or object operation, per req_controls_tap_zones). Only touches count as input: tilting the phone neither holds off the idle camera nor takes control back from it. At bedtime, when every slime is asleep, the idle camera follows no one. Screensaver mode and the idle camera share one zoom, about 10-20% wider than normal play; it doesn't stack with anything, and it never zooms in: where the camera is already wider (inside a wide framing zone), the cue and the idle camera keep that zoom. While either follows a slime, framing zones are ignored; when the child takes back control, framing resumes if the camera's centre is still inside a framing zone. Screensaver mode starts on the idle camera straight away.

## TECHNICAL INTERFACE
Parented to req_camera_rails_and_framing. Interacts with req_session_lifecycle (screensaver mode).

## EXPECTATION
After 45 s with no input the idle camera follows a train slime, with the zoom-out cue starting 10 s earlier; any touch takes back control and does its normal job; tilt doesn't count as input; the idle zoom never zooms in where the camera is already wider (definition of done item 19). At bedtime, with every slime asleep, the idle camera follows no slime.
