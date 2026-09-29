---
id: req_camera_shows_gate_opening
status: DRAFT
type: REQUIREMENT
parents:
  - [[req_camera_rails_and_framing]]
priority: 3
tags: [camera,frontier-gate]
version: 1.0
dependents: []
layer: BUSINESS
human_name: Camera shows a gate opening
---

# Camera shows a gate opening

## INTENT
Let the child see a gate open when its basket fires while the gate is out of view, without taking control away from her.

## THE RULE / LOGIC
When a basket fires and its gate is off screen, the camera glides to the gate, in about 1.5 s, to show it opening, and then stays there under normal control. Input stays live throughout: a touch during the glide takes control back and does its normal job. When the gate is already in view, the camera doesn't move.

## TECHNICAL INTERFACE
Parented to req_camera_rails_and_framing. Triggered by a basket firing its gate, as req_switch_basket_gate_set defines it (the firing itself waits until the basket is in view, and for sunrise at bedtime).

## EXPECTATION
When a basket fires with its gate off screen, the camera ends with the gate in view within about 1.5 s; a tap during the glide does its normal job and takes the camera back; with the gate already in view, the camera doesn't move.
