---
id: req_tilt_input
status: DRAFT
parents:
  - [[req_controls_tap_zones]]
dependents: []
priority: 4
human_name: Tilt input
tags: [controls,tilt]
version: 1.0
type: REQUIREMENT
layer: BUSINESS
---

# Tilt input

## INTENT
Define the tilt input itself: how it is read from the phone's held angle, and turned into gravity direction for free slimes.

## THE RULE / LOGIC
The world stays fixed on the screen and gravity turns with the phone, up to plus or minus 45 degrees from neutral, with a dead zone of about 10 degrees around neutral where gravity doesn't turn. Neutral is how the phone was held when the session started; lying the phone flat also counts as neutral. Only free slimes feel tilt; train slimes and every other state ignore it. (proposed, D95) Neutral is taken again when a session resumes, not only at the session's original start.

## TECHNICAL INTERFACE
Parented to req_controls_tap_zones, whose zone-4 (call) area names tilt only as part of the shared controls description; this atom is tilt's dedicated record. Constrained by rule_tilt_never_required (no level may require tilt) and by req_slime_states (only free slimes feel tilt).

## EXPECTATION
Only free slimes respond to tilt, within plus or minus 45 degrees and outside the roughly 10-degree dead zone; lying the phone flat reads as neutral (definition of done item 8). (proposed, D95, pending the user's approval) Neutral is re-taken whenever a session resumes, not just at its original start.
