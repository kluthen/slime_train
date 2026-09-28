---
id: req_screen_pinning
status: DRAFT
dependents: []
layer: BUSINESS
priority: 4
human_name: Screen pinning
parents:
  - [[req_parent_gate_and_access]]
version: 1.0
type: REQUIREMENT
tags: [screen-pinning]
---

# Screen pinning

## INTENT
Define v1's best-effort mechanism for keeping the child inside the app.

## THE RULE / LOGIC
The app asks Android to pin the screen each time it opens, so the child can't leave with the home or back buttons; leaving goes through the parent code. Android shows its own confirmation every time, which can't be skipped; the parent normally opens the app and hands the phone over. Pinning also ends when the phone restarts. Anyone can unpin with Android's gesture unless the phone's 'Ask for PIN before unpinning' setting is on; setup recommends turning it on. If the parent declines pinning, the game still works, every parent button still asks for the code, and the setup screen explains the difference. This is best effort, a courtesy to parents and not a guarantee: there is no device-owner kiosk mode (it would need the phone wiped and provisioned), and a child who knows the phone's PIN can reset the parent code.

## TECHNICAL INTERFACE
Parented to req_parent_gate_and_access.

## EXPECTATION
With screen pinning accepted, the home and back buttons don't take the child out of the app; 'leave' with the correct code does (definition of done item 25).
