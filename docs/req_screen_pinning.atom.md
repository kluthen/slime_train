---
id: req_screen_pinning
status: DRAFT
dependents: []
layer: BUSINESS
priority: 4
human_name: Screen pinning
parents:
  - [[req_parent_gate_and_access]]
version: 1.1
type: REQUIREMENT
tags: [screen-pinning]
---

# Screen pinning

## INTENT
Define v1's best-effort mechanism for keeping the child inside the app.

## THE RULE / LOGIC
The app asks Android to pin the screen each time it opens, so the child can't leave with the home or back buttons; leaving goes through the parent code. Android shows its own confirmation every time, which can't be skipped; the parent normally opens the app and hands the phone over. Pinning also ends when the phone restarts. "Each time it opens" means each launch: on first launch, pinning is asked right after setup is completed (setup has explained pinning by then); on every later launch, as soon as the app opens, before the world takes a tap. Coming back from the background doesn't ask again. "Leave" closes the app, so the next open is a launch and asks. Anyone can unpin with Android's gesture unless the phone's 'Ask for PIN before unpinning' setting is on; setup recommends turning it on. If the parent declines pinning, the game still works, every parent button still asks for the code, and the setup screen explains the difference. The back gesture then leaves the app, as Android normally does, like home and recent apps; the session keeps counting and reopening resumes where it was, and setup says so. The one exception: the game runs in sticky immersive mode (no system bars) and keeps the whole edge strips out of the back gesture, so a tap sliding off a strip doesn't leave the app. This is best effort, a courtesy to parents and not a guarantee: there is no device-owner kiosk mode (it would need the phone wiped and provisioned), and a child who knows the phone's PIN can reset the parent code.

## TECHNICAL INTERFACE
Parented to req_parent_gate_and_access.

## EXPECTATION
With screen pinning accepted, the home and back buttons don't take the child out of the app; 'leave' with the correct code does. Pinning is asked right after setup on first launch and at every later launch, not on coming back from the background, and again after 'leave'. With pinning declined, the back gesture leaves the app while the session keeps counting, but a tap sliding off an edge strip doesn't trigger it (definition of done item 25).
