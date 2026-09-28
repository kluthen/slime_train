# Technical direction

Status: draft v6

Research: `docs/research/tech-stack.md`, `docs/research/level-authoring-and-kid-lock.md`.

## Engine

- **Godot 4** is the engine (D5). Unity and Unreal are excluded.
- Primary target: native Android. A Linux desktop and/or web build of the
  same project exists to iterate faster and to run end-to-end tests (O14).
- Choosing Godot comes with risks to test with small prototypes (O14):
  Android audio latency, cost of the slime simulation on low-end phones,
  running tests without a screen, and live vector rendering. Godot turns SVGs
  into images at import time, so crisp curves mean using Polygon2D/Line2D or
  a plugin.

## Level authoring

- **No custom level editor** (D6). Levels are Godot scenes built in Godot's
  own editor. Curved terrain uses Path2D/Curve2D with collision polygons.
- Every interactive element (gate, basket, switch, reveal zone, defuse spot…)
  is a **reusable, programmed component** configured through its properties
  in the editor. There are no per-level scripts, so extra levels (possible
  paid DLC) stay content rather than code.
- The rule schema these components share (for example "basket holds 5 or
  more slimes, so gate G opens") is yet to be designed.

## Slimes (proposed)

- Each slime is simulated as a ring of points joined by springs, using our own
  code rather than a physics-engine feature, and drawn with a shader that
  blends nearby shapes into smooth blobs. Fusing and splitting become
  operations on those rings. (proposed; no engine provides this out of the
  box, see research)

## Saving (D7, D12, D43)

- One save file per level. The user can delete one level's save. Versioning
  across level updates is O20.

## Camera (D33, D60)

- The camera runs on rails along the loop. Zoom and framing are computed from
  the camera's position and the mode (screensaver mode is about 10–20% wider).
- (proposed) Framing zones are a reusable level component with properties for
  zoom, position and the delay before the camera leaves (D61). They are authored like
  any other component, with no per-level scripts (D6).

## Slime navigation

- A heading-back slime follows the route back that is built into every
  exploration branch as part of the level (D41, D51). That route is authored
  level data, like the loop, so there is no general pathfinding. (proposed:
  drawn as a path in the Godot editor)

## Session lock (D1)

- `startLockTask()` screen pinning through a small Godot Android plugin, plus
  an in-app parent gate and a timer stored on disk (wall clock plus the
  monotonic clock). There is no device-owner kiosk mode.
- Recovering the parent code uses Android's device-credential prompt
  (BiometricPrompt, which also accepts the PIN or pattern). There is no server
  (D55).
- (proposed) More broadly, the app runs **fully offline**, with no account and
  no backend. D55 settles this for the parent code; paid unlocks will go
  through Google Play only (D31).
- The same stored clocks enforce the 10 min cooldown after bedtime (D29).
  Changing the device clock can defeat it, which is acceptable under D1.

## Deferred

- Sound in general comes around v3 (D50). v1 has no audio.
- Music generator (D42, O12): it is currently a JS app, and porting it to
  Godot is a project of its own.
- Paid levels (D31): Play Billing plus Play Asset Delivery, when the second
  level arrives.

- Procedural world generation: a possible later iteration (O13). Godot scenes
  can be built at runtime, so D6 doesn't rule it out.
