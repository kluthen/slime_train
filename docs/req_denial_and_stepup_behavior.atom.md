---
id: req_denial_and_stepup_behavior
status: DRAFT
version: 1.0
type: REQUIREMENT
priority: 3
tags: [access-model,denial]
layer: BUSINESS
human_name: Denial and step-up behaviour
parents:
  - [[req_actor_roles_and_permissions]]
dependents: []
---

# Denial and step-up behaviour

## INTENT
Define what happens, visibly, when a disallowed action is attempted, and what step-up confirmation a parent action needs.

## THE RULE / LOGIC
A tap during bedtime (call, operate-object, tilt) is visible but inert: the ripple still shows, slimes stay asleep, and nothing else happens, with no text and no sound, so every tap still gets an answer while bedtime stays calm. The edge buttons (move-camera) are hidden during bedtime, since there is nothing to explore while everyone sleeps. Any parent-only operation (wake-early, leave, change, delete) attempted by a child is visible but blocked: the button is shown, and pressing it raises the code prompt, but nothing happens without the correct code; the parent has to find the buttons without instructions, and the code is the only guard. A wrong code makes the entry shake and clear; tries are unlimited, but 5 wrong tries in a row bring a 30 s wait, and the prompt closes after about 15 s with no input. The wake-early button is shown only during bedtime, since there is nothing to wake otherwise. Home and back are ignored by Android while the screen is pinned. If the parent declines pinning, the game still works, every parent button still asks for the code, and setup explains the difference. If the child leaves the app anyway (pinning declined or escaped, or the power button), nothing is blocked in the app: the session keeps counting in real time, and reopening the app resumes where it was, since the timer can't be dodged by leaving. No denial is logged and nothing is ever locked for good; the only slowdown is the 30 s wait after 5 wrong codes in a row. Step-up: every parent-only operation requires the code immediately before it; deleting a level's save also asks for a second confirmation; changing the code asks for the new code twice; resetting the code requires the phone's own screen lock. There is no audit trail: nothing is logged, and there is no analytics and no network.

## TECHNICAL INTERFACE
Parented to req_actor_roles_and_permissions.

## EXPECTATION
Every denial described above is reproducible: a bedtime tap ripples but does nothing else; a child pressing any parent-only button raises the code prompt and is blocked without the correct code; 5 wrong codes in a row trigger a 30 s wait.
