---
id: req_camera_shows_gate_opening
status: DRAFT
type: REQUIREMENT
parents:
  - [[req_camera_rails_and_framing]]
priority: 3
tags: [camera,frontier-gate]
version: 1.1
dependents: []
layer: BUSINESS
human_name: Camera shows a gate opening
---

# Camera shows a gate opening

## INTENT
Let the child see a gate open when its basket fires while the gate is out of view, without taking control away from her.

## THE RULE / LOGIC
When a basket fires and its gate is off screen, the camera glides to the gate, in about 1.5 s, to show it opening, and then stays there under normal control. The glide goes straight, at an even pace, to the camera rail point nearest the gate's centre. A gate counts as in view only when the whole of it is; when it is already in view, the camera doesn't move. No show starts while an edge button is held. Input stays live throughout: a touch during the glide takes control back and does its normal job. A show replaces a call drag in progress and ends an idle-camera or screensaver follow; it restarts the idle clock, so the idle camera can take over again only after the usual 45 s without input.

## TECHNICAL INTERFACE
Parented to req_camera_rails_and_framing. Triggered by a basket firing its gate, as req_switch_basket_gate_set defines it (the firing itself waits until the basket is in view, and for sunrise at bedtime). Interacts with req_idle_camera_and_screensaver_zoom (the idle clock). Implemented in src/sim/camera.gd (Camera.show_gate, mode SHOW, SHOW_SECONDS); the show's progress (show_distance, show_tick) is part of the camera's saved transient state.

## EXPECTATION
When a basket fires with its gate off screen, or only partly in view, the camera ends with the gate in view within about 1.5 s; a tap during the glide does its normal job and takes the camera back; with the gate already wholly in view, or with an edge button held, the camera doesn't move; after a show, the idle camera takes over only 45 s after the show began.
