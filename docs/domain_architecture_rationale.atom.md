---
id: domain_architecture_rationale
status: DRAFT
tags: [architecture,rationale]
parents: []
dependents: []
version: 1.0
type: DOMAIN
layer: BUSINESS
priority: 2
human_name: Architecture rationale
---

# Architecture rationale

## INTENT
Record why v1's foundational technical decisions were made, as context for architecture atoms that will implement them.

## THE RULE / LOGIC
Slime Train is a new project with no prior code base to fit into. Its architecture decisions and their reasons: Godot 4 was chosen for its open-source licence, strong 2D support, and exports to both Android and a Linux desktop build from the same project (Unity and Unreal were ruled out by the project owner). There is no custom level editor: levels are Godot scenes built in Godot's own editor, with curved terrain from paths and collision polygons, and every interactive element is a reusable, property-configured component with no per-level scripts, so that extra levels (possibly paid) stay content rather than code. Slimes are soft: each is a ring of points joined by springs in custom code, drawn with a shader that blends nearby shapes into smooth blobs, with fusion and splitting as operations on the ring; no engine provides this out of the box. The simulation tick stays in GDScript, with a verified native-code contingency held in reserve rather than adopted (D96). Physics only runs near the screen, because simulating up to 200 slimes at once on a mid-range phone at all times is not feasible; off-screen slimes move along authored paths at a deterministic pace, which also makes their behaviour predictable and testable. Exploration routes back to the loop are authored level data (paths drawn in the editor), not general pathfinding. The loop itself is a drawn route, not physics, so the train always flows with no input regardless of what physics does; only free slimes are driven by physics alone. The camera runs on rails with automatic framing because a 3-year-old can press two edge buttons but can't manage a free camera or zoom. The parent lock is best-effort and fully offline: screen pinning, custom code, and stored clocks cover the real risk of a small child wandering out of the app, without requiring the parent to provision the phone as a managed device; code recovery goes through the phone's own screen lock, so no server, website or account exists, and there is no analytics, no ads and no network permission. Saves are one per level and never wiped, so a parent can reset one level without losing others, and level updates migrate saves rather than breaking them. Testability is built in: all gameplay randomness comes from one seeded generator so test runs repeat exactly, and a test mode (Linux build and debug Android builds only) loads fixture saves, speeds up or skips time, and injects taps and tilt from a script.

## TECHNICAL INTERFACE
Narrative context only; no code tag. Read by whoever designs ARCHITECTURE-layer atoms for these subsystems, to understand why the constraint exists before proposing an alternative.

## EXPECTATION
N/A (narrative atom, not independently testable). Its content is corroborated by the architecture ARCHITECTURE-layer atoms that eventually implement each decision, and by the REQUIREMENT/RULE atoms whose behaviour depends on it (e.g. req_offscreen_simulation, req_persistence_and_saves).
