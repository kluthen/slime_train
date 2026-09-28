---
id: req_actor_roles_and_permissions
status: DRAFT
tags: [access-model,roles]
parents:
  - [[req_parent_gate_and_access]]
version: 1.0
type: REQUIREMENT
priority: 4
human_name: Actor roles and permissions
dependents:
  - [[req_denial_and_stepup_behavior]]
layer: BUSINESS
---

# Actor roles and permissions

## INTENT
Define the three roles that act inside Slime Train and what each is allowed to do.

## THE RULE / LOGIC
There are three actors, global to the app with no per-level roles. child: anyone touching the screen without having just entered the parent code; this is the default, since there is no login, so every touch is the child's unless a code was entered for it. parent: whoever has just entered the correct parent code; it is an authority for one action, not a mode that stays on, and it doesn't stack with itself or with child for a given action. game: the app itself acting on its own (timers, autosave, sunrise, first-launch setup, asking Android for screen pinning); not a person, always present. The phone's own screen lock is not an actor; passing it is only a condition used to reset a forgotten code. Permissions by resource: World (call, operate-object, move-camera, tilt) is allowed to child and parent alike while in-session (and move-camera is also driven by game for the idle camera and automatic framing), and denied to game otherwise, since playing is the same for everyone regardless of role. Session: start is child/parent while in screensaver mode; end, sunrise are game-only, triggered by their timers; wake-early is parent-only, and only during bedtime. Parent buttons: reveal is available to child/parent once setup is done; pressing a button is what turns a child into a parent, by raising the code prompt. App exit: leave is parent-only; pin is game-only, triggered whenever the app opens. Parent code: create is available to whoever holds the phone at first launch (no code exists yet); change is parent-only; reset requires passing the phone's own screen lock. Level save: write and load are game-only (autosave and load); delete is parent-only; nobody reads or edits a save directly.

## TECHNICAL INTERFACE
Parented to req_parent_gate_and_access, which this atom formalises as a role/permission model. Restated from the access model document's actor list, resource table, and permission matrix.

## EXPECTATION
No action outside this permission matrix succeeds: e.g. child never triggers session end, sunrise, autosave, load, pin, or delete; game never calls, operates an object, or tilts.
