---
id: req_session_lifecycle
status: DRAFT
version: 1.1
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
The flow is: first launch leads to parent setup, then screensaver mode; the first tap on the world in screensaver mode starts a session (15 min); the session's last minute is a wind-down, then bedtime begins at 15 min; bedtime ends at the parent code (wake early) or after 10 min, leading to sunrise, which returns to screensaver mode; reopening the app lands in the state the stored timers give. Screensaver mode: the world runs with no session; opening the app lands here only when no session or bedtime is running (and after the one-time setup on first launch); otherwise it resumes where it was; the phone's usual screen timeout applies. Session: starts at the first tap in screensaver mode, which also acts as a normal tap; only a tap that reaches the world starts it, on open ground (a call) or on an object (it operates the object); a tap on the parent zone or on an edge button doesn't, though the edge buttons move the camera in screensaver mode as they do in a session. It lasts a fixed 15 minutes of real time, so time in the background or during a phone call is used up; the screen stays on during a session. Wind-down: in the last minute the light drifts toward dusk and slimes hop more slowly, with no text and no countdown. Bedtime: slimes fall asleep where they are, the game saves, taps no longer call, baskets pause (their releases and any due reward wait for sunrise, per req_switch_basket_gate_set), the edge buttons are hidden, and the phone's usual screen timeout applies again. Sunrise comes when the parent enters the code (wake early) or 10 real minutes after bedtime began, whichever is first; the slimes wake and screensaver mode begins; the long delay is deliberate, to nudge the child to put the phone down. The session and cooldown timers survive the app being killed or the phone restarting, since they are stored with both the wall clock and the monotonic clock; changing the phone's clock can defeat them, which is accepted. Reopening the app, after a kill, a phone restart or a return from the background, lands in the state its stored timers give: a running session resumes, wind-down included; bedtime resumes with the rest of its cooldown, the slimes asleep; if the cooldown ran out while the app was closed, it lands in screensaver mode with the slimes awake, without replaying sunrise.

## TECHNICAL INTERFACE
Parented to req_loop_and_world. Governs req_idle_camera_and_screensaver_zoom (screensaver mode) and req_parent_gate_and_access (wake early).

## EXPECTATION
A session starts at the first tap in screensaver mode and ends 15 real minutes later, including time spent in the background, after a killed app, and after a phone restart; a tap on the parent zone or an edge button doesn't start it; reopening the app during a session or bedtime resumes it instead of landing in screensaver mode (definition of done item 20). The last minute shows the dusk wind-down; at bedtime the slimes fall asleep, the game saves, and taps no longer call; during bedtime no basket releases a slime or plays its reward, and both resume at sunrise (definition of done item 21). Sunrise comes 10 real minutes after bedtime began, or immediately after the correct parent code on wake early; screensaver mode follows (definition of done item 22).
