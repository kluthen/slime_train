# v2 — Content, level design and music

Status: themes only (D134); no spec yet; two cluster aids proposed (D143); the geyser, once a parked idea, moved into v1 as a level object (D159, D160)

Themes, set by the user (D134):

- **Content generation** and its tooling.
- **Reusable mechanics:** interactive objects and components built for
  reuse across levels.
- **Level design made as easy as possible** for the level designer.
- **Music**, which the user calls paramount for this kind of game (moved
  from v3; the generator is O12). Sound begins at v2 (D136).
- **Sound effects: a candidate**, decided when v2 is scoped (D136): species
  voices, closer to a kind of instrument (D40), capped at 10 voices shared
  among the species present in proportion (D68), and bedtime's softer
  sound (D28).
- **The first real level(s):** chunk L01, `../../levels/01/`, moved from
  v1 (O99, D134). This level work builds toward the fully implemented
  level of the first store release, probably v4 (D137, O104).

Assigned so far (D50, D54):

- The interactive objects from `../../interactive-objects.md` beyond v1's
  frontier-gate set and loop-start split zone (D54): bending pathway, other
  split zones, tilt objects, reveal zones, and the **filters**, by species
  and by size (D47, D88, D89). Also switches and baskets used anywhere other than a
  frontier gate.
- **Larger signposts** that let the player choose which branch the
  camera follows (D47). They are tapped, so they count as interactive.
- **The first-play hint, revisited** (D115, from the UX review's Q11):
  a demonstrating hand instead of a pulsing mark (O92), whether setup and
  the personas may count on the parent showing the first tap, with a
  line in setup asking for it (O93), and a
  measurable "first sleeper close" rule (O94). v1 keeps the pulsing mark.

Proposed (D143), both serving level rule 23 (no spot where many slimes
gather awake):

- **An activity-zone tool** (theme: level design made as easy as
  possible). The user: "a dev tool that will allow the level designer to
  have an idea given a point on the map, of the active physic computation
  zone". Pick a point or a framing zone, and the tool shows the
  **activity zone** while the camera is there: the view at that zoom
  grown by Offscreen's margins (surely simulated within the near margin,
  288 px; maybe up to the park margin, 384 px; parked beyond). It
  overlays the spots where clusters are expected (baskets and their
  outlets, dips, split zones, narrow ledges on the loop, where sleeper
  shelves drop their slimes), so the designer sees two of them sharing
  one activity zone and spaces them out.
- **A population fork** (theme: reusable mechanics; a cluster-breaking
  object). The user: "One such could simply switch path by population
  within a given fork." A fork that sends the next slimes down its
  emptier branch, counting the slimes on each branch's first stretch; not
  tapped (presence); deterministic (it counts, reads no clock; a tie
  keeps the current way, and it holds a way for a set number of ticks).
  It is a separate object: it has a plain signpost like every fork
  (rule 6) showing where it sends slimes now, and a large signpost may
  stand at it too. It is the spring-back pathway's opposite (D17): that
  sends a dense clump one way, this spreads a crowd over both. To settle
  when v2 is scoped: slimes or weight, which stretch it counts, off
  screen (D70), which branch the camera follows.

*Moved to v1 (D159, D160):* the geyser (once O117, an idea parked here,
D157) is built in v1, chunk 24g, as a level object any level may place
(the user, D160), already a reusable mechanic; v2's levels use it as
they need. Pacing the return route's end is O118, parked (D160).
