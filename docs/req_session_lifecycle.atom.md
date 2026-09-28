---
id: req_session_lifecycle
status: DRAFT
version: 1.0
type: REQUIREMENT
human_name: Session
tags: [session,bedtime]
parents:
  - [[req_loop_and_world]]
dependents: []
layer: BUSINESS
priority: 5
---

# Session

## INTENT
Define the state machine that carries the app from screensaver mode through a timed session to bedtime and back.

## THE RULE / LOGIC
The flow is: first launch leads to parent setup, then screensaver mode; screensaver mode's first tap starts a session (15 min); the session's last minute is a wind-down, then bedtime begins at 15 min; bedtime ends at the parent code (wake early) or after 10 min, leading to sunrise, which returns to screensaver mode. Screensaver mode: the world runs with no session; opening the app always lands here after the one-time first-launch setup; the phone's usual screen timeout applies. Session: starts at the first tap in screensaver mode, which also acts as a normal tap; it lasts a fixed 15 minutes of real time, so time in the background or during a phone call is used up; the screen stays on during a session. Wind-down: in the last minute the light drifts toward dusk and slimes hop more slowly, with no text and no countdown. Bedtime: slimes fall asleep where they are, the game saves, taps no longer call, the edge buttons are hidden, and the phone's usual screen timeout applies again. Sunrise comes when the parent enters the code (wake early) or 10 real minutes after bedtime began, whichever is first; the slimes wake and screensaver mode begins; the long delay is deliberate, to nudge the child to put the phone down. The session and cooldown timers survive the app being killed or the phone restarting, since they are stored with both the wall clock and the monotonic clock; changing the phone's clock can defeat them, which is accepted.

## TECHNICAL INTERFACE
Parented to req_loop_and_world. Governs req_idle_camera_and_screensaver_zoom (screensaver mode) and req_parent_gate_and_access (wake early).

## EXPECTATION
A session starts at the first tap in screensaver mode and ends 15 real minutes later, including time spent in the background, after a killed app, and after a phone restart (definition of done item 20). The last minute shows the dusk wind-down; at bedtime the slimes fall asleep, the game saves, and taps no longer call (definition of done item 21). Sunrise comes 10 real minutes after bedtime began, or immediately after the correct parent code on wake early; screensaver mode follows (definition of done item 22).
