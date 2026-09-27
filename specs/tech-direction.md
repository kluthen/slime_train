# Technical direction

Status: draft v1

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

## Session lock (D1)

- `startLockTask()` screen pinning through a small Godot Android plugin, plus
  an in-app parent gate and a timer stored on disk (wall clock plus the
  monotonic clock). There is no device-owner kiosk mode.

## Deferred

- Procedural world generation: a possible later iteration (O13). Godot scenes
  can be built at runtime, so D6 doesn't rule it out.
