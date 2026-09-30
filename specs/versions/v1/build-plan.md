# Slime Train v1 — Build plan

Status: draft v14 (approved by the user, 2026-09-29, D108; chunk 23 moved
before 18 and chunk LD added, D123; LD split into LD1 and LD2, and a
test-level fix for rule 22 (b) before 18, D126; R22 and LD3 done, chunk
TL1 before 18, proposed, D127; chunk 24, the user's second round of
playtest issues, last before the health review, proposed, D128; TL1 done,
D129; chunk 18 done, D130; chunk 19 done, D131; chunk 20 done on the
emulator, D132; chunk 21 done, D133; v1 is the test level only, and
chunk L01, the first real level, moves to v2, D134; v1 is the full MVP,
never in a store, DoD 32 deferred, D135)

This plan splits `master-spec.md` into build chunks, ordered so that each one
can be **tested as soon as it lands**. The master spec stays the reference for
behaviour. This document only settles the order, the size of each chunk, and
what "tested" means for it. Numbers in brackets such as [DoD 6] are the master
spec's Definition of done criteria (§9). Fixture names come from
`../../levels/test/README.md`.

## Principles

1. **Test backbone first.** Seeded randomness, time control and scripted input
   come before any gameplay, so every later chunk ships with automated
   tests on the Linux build.
2. **Risky things are checked before they are built for real.** The master
   spec's known technical risks (soft slimes at 200, vector look, headless
   tests, tilt) are checked with throwaway spikes first.
3. **Grow the test level with the features.** Section 1 (Meadow) is
   greyboxed early. Sections 2 and 3 are added when the features they
   exercise exist.
4. **The save format comes early**, because test fixtures are saves. It grows
   with each feature instead of arriving at the end.
5. **Desktop before Android.** Everything that can be tested on the Linux
   build is. Android-only work (pinning, device credential, sensors, lifecycle)
   is grouped into its own chunks.
6. **Placeholder interface.** The parent screens get working placeholder UI.
   Their real design comes from the UX track (`ui_ux/`), which has not
   started.
7. Each chunk goes through the six-step workflow below: ATD preflight,
   tests red to green, implement, verify, documents, ATD stewardship.

Sizes are relative: **S** is small, **M** is a few days of focused work,
**L** is large and a candidate to split further when it starts.

## Workflow for every chunk

Every build chunk goes through the same six steps,
in this order. A chunk isn't finished until step 6 is done.

1. **ATD preflight.** The documentalist finds the atoms that govern the
   chunk's area, starting from the chunk's "Atoms" line. It checks that the
   change is grounded in them and flags conflicts or missing coverage. A
   missing or conflicting atom stops the chunk until it is resolved. If the
   gap is in the spec itself, it goes back to spec-writer. ATD covers
   business behaviour only. Technical choices (structure, data formats,
   libraries, tooling) don't go through it: they are recorded in the project
   documentation in step 5.
2. **Tests first, red to green.** Write the tests for the chunk's "Done when"
   criteria first, and see them fail for the right reason. Unit tests go
   where the logic is pure. Scripted scenario tests through test mode, on
   the test level or a test scene, cover behaviour. A fixture that doesn't
   exist yet is created here.
3. **Implement** until the tests pass. Don't change a test to make it pass
   unless the test itself was wrong, and say so when that happens.
4. **Verify.** The chunk's "Done when" criteria hold. The whole suite is
   green, with no regression in earlier chunks. The run is repeatable (same
   seed, same result), and a debug run shows the behaviour on screen.
5. **Documents.** Keep the project documentation current: the README, the
   technical choices made in the chunk and why, how to run the tests, how a level component is configured in the editor, the
   fixture list. A place where the code had to differ from the spec is
   reported to spec-writer, not fixed silently in either one.
6. **ATD stewardship.** For the business behaviour the chunk built, the
   documentalist checks that every atom the chunk
   touched has `@spec-link` tags on the code that implements it and
   `@test-link` tags on the tests that verify it. It confirms the atoms still
   describe what the code does, and advances their status only with the
   user's agreement.

**Technical chunks skip the ATD steps (1 and 6).** They build tooling or
technology, not business behaviour:
- chunk 0 (tooling), chunk 3 (test backbone), chunk 5N (the native
  simulation tick, a contingency), chunk 21 (the end-to-end suite) and
  chunk LD (the level-design toolkit, D123) still go test first. Chunk 5N changes no behaviour: the existing suite is its
  test. Chunk 0's only test is a trivial one, seen red then green, which proves the runner
  reports failures.
- The spikes (chunks 1 and 2) are throwaway code, so they also skip the
  test-first step. They end by writing their outcome (the numbers, the
  approach chosen) into the project documentation, and into
  `../../tech-direction.md` through spec-writer when it changes the
  spec's technical direction.
- Chunk 22 (performance) checks a business target, the frame rates promised
  on the reference and floor phones, so it keeps both ATD steps.

## Progress

- **Done:** 0 to 17; 1 on the desktop and the reference phone (the
  floor phone waits for its purchase). Chunks 14 and 17 raised O82 to O86
  (the session in the level's save, baskets at bedtime, the switch locked
  once the basket is full, the gate's lid, a state for slimes in a basket),
  settled in D104–D106.
  Chunk 15 built section 2 in greybox with the off-screen simulation.
  Chunk 16 (16a–16f; stewardship d487ae8): section 3 in greybox, the full
  population of 200, every fixture regenerated (with `gate2-open` added),
  the level-rule tests, the level bench, the terrain-contact fix and the
  cave's framing zone (16d), the whole-level DoD 1 test and the developer
  notes (16c-B), the start basin rebuilt so DoD 1 holds (16e), and the
  dip nudge's limited wait so a mixed queue no longer stalls (16f).
  Chunks 15 and 16 raised O87 (the rest rule's anchor), settled in D107;
  chunk 16 raised D116–D119, approved in D120, and O95, settled in D121
  (item 23.13).
- **Done:** chunk 23 (small issues from play, an open list, before 18,
  D123), sub-chunks **23A** safety nets (23.3, 23.13), **23B** taps and
  strips (23.2, 23.6b, 23.8), **23C** camera (23.1, 23.4, 23.10, 23.12)
  and **23D** bedtime baskets and the celebration's mark (23.5, 23.11).
  Their own values and choices, and three additive save-format changes,
  are recorded in D124, approved by the user (D125). **23E** objects and
  taps (23.6, 23.7, 23.9) is merged. Its own readings are in D126
  (proposed). New reports added to the list are placed after 23E.
- **Chunk LD** done: **LD1** (the tools), **LD2** (the tutorial and the
  project skills) and **LD3** (the tutorial's gaps: a playable skeleton,
  the progress estimate under rule 12, `tools/level.sh`, stale fixtures,
  the bench per level; D127). LD1's checker found a rule 22 (b) break on
  the test level (D126), fixed by **R22** (done: the second dip's hollow
  moved over the dip's far slope, D127).
- **TL1** done (D129): the test level is playable from fresh with base
  slimes alone (sleepers in touching lines within a called slime's
  reach; see `../../levels/test/README.md`, section 1).
- **Chunk 18** done (D130; 54873c1, suite 1041/1041): the parent gate and
  settings with a placeholder UI. Its choices where the spec was silent
  are proposed in D130, with its open risks.
- **Chunk 19** done (D131; c39ebc0, suite 1097/1097): persistence
  hardening (the level save's checked backup and read fallback, mid-air
  slimes grounded on load, migration by level version, `parent.json`'s
  mirror). Its choices where the spec was silent are proposed in D131,
  with its open risks.
- **Chunk 20** done on the emulator (D132; 72d3717, suite 1186/1186):
  the Android build and platform integration; DoD 25, 26 and 27 pass on
  the emulator. The checks on the user's S20 FE (tilt feel among them)
  are pending. Its choices where the spec was silent are proposed in
  D132, with its open risks.
- **Chunk 21** done (D133; ec518a0, suite 1198/1198): the end-to-end
  suite; every fixture has a scripted scenario and a same-seed hash test,
  and `tests/e2e/` passes in the exported Linux build [DoD 31]. Its
  choices where the spec was silent are proposed in D133, with its open
  risks.
- **Next: 22** onward. (5N is a contingency, run only if chunk 22 fails,
  D96.)
- **Chunk L01** (the first real level) is **v2**, not this plan (D134):
  v1 is the test level only. The release preset stays as built, with the
  test level left out; v1 (full MVP) is never published (D135).
- **Chunk 24** (the user's second round of playtest issues, an open list;
  proposed, D128): after chunk 22 (and 5N if it runs), the last chunk
  before the closing step, as the user asked. The user's next play
  reports go there.
- **Closing step, last of all:** the coding-rule health review
  (`CODING_RULE.md`'s health and clean-up list), after every other chunk,
  chunk 24 included (D122, kept by D123 and D128).

## Overview

| # | Chunk | Size | Depends on | Tested by |
|---|---|---|---|---|
| 0 | Tooling and project setup | S | — | a headless test runs from the command line |
| 1 | Spike: soft slimes at scale | M | 0 | fps measured with 200 slimes (desktop, then phones) |
| 2 | Spike: vector look | S | 0 | a screenshot comparison, and a decision recorded |
| 3 | Test backbone | M | 0 | two identical scripted runs give identical state |
| 4 | Level scaffolding and Meadow greybox | M | 3 | the loop, terrain and IDs load in a test |
| 5 | Slime body | L | 1, 4 | unit tests on rings; a visual demo |
| 5N | Native simulation tick (contingency, only if 22 fails) | M | 22 failing | the whole suite on the native tick; chunk 22 repeated |
| 6 | Train and split zone | M | 5 | [DoD 1 partial, 7] |
| 7 | Taps and the call | L | 6 | [DoD 3, 4, 15, 17] |
| 8 | Save format and fixtures | M | 7 | kill-and-reload tests; the first fixtures load [DoD 28 partial] |
| 9 | Sleepers, waking and the first-play hint | S | 8 | [DoD 2, 16]; `fresh` |
| 10 | Fusion and bumping | M | 8 | [DoD 6]; `bump` |
| 11 | Tilt (desktop, injected) | S | 7 | [DoD 8] with scripted tilt |
| 12 | Camera: rails, edge buttons, call drag | M | 7 | [DoD 18 partial] |
| 13 | Camera: framing zones, idle camera, screensaver zoom | M | 12 | [DoD 18, 19] |
| 14 | Frontier set, gates and completion | L | 8, 12 | [DoD 9, 11, 12, 13, 14]; `s1-basket-5of6`, `s1-optout` |
| 15 | Off-screen simulation | L | 14 | [DoD 5, 10]; `s2-cave-return`, `lost`, `s2-basket-offscreen` |
| 16 | Test level sections 2 and 3, full population | M | 15 | [DoD 1] in full; `gate1-open`, `stress-*` |
| 17 | Session, wind-down, bedtime, sunrise | M | 8 | [DoD 20, 21, 22]; `wind-down`, `bedtime`, `sunrise` |
| 18 | Parent gate and settings (placeholder UI) | M | 17 | [DoD 23, 24, 29] |
| 19 | Persistence hardening | M | 16, 18 | [DoD 28]; `midair`, `old-version` |
| 20 | Android build and platform integration | L | 18 | [DoD 25, 26, 27]; emulator |
| 21 | End-to-end suite | M | 19 | [DoD 31] |
| 22 | Performance pass on phones | M | 20, 23 | [DoD 30] |
| 23 | Small issues (open list) | S per issue | 17, 16 | each issue's own done-when |
| 24 | Playtest issues, round 2 (open list; proposed) | S per issue (24.1 may be M) | 22, and 5N if it runs | each issue's own done-when |
| LD | Level-design toolkit (technical) | L | 16 | the checker agrees with the level-rule tests on the test level; a scaffolded level loads, passes its generated tests and appears in test mode |
| TL1 | Test level finishable from fresh (done, D129) | S | LD, R22 | the checker gives 0 warnings on the test level; a scripted play from `fresh` fills basket 1 |

Chunks 1 and 2 can run in parallel with 3. Chunk 5N is not in the
sequence: it runs only if chunk 22's measurement fails (D96). Chunks 9, 10
and 11 are independent of each other. Chunk 17 can start as soon as 8 is done, in
parallel with the camera and objects work. Chunk 23 runs first among the
remaining chunks, before 18 (D123), and chunk LD runs in parallel with it.
TL1 ran after both, before 18 (D127; done, D129). Chunk 24 runs after 22
(and 5N if it runs), the last chunk before the closing health review
(D128, proposed; O97 asks whether 24.1 and 24.3 should run before 22
instead).

## Chunks

### 0. Tooling and project setup (S)

- The Godot binary reachable from a stable path (the user's choice, see
  "Before starting").
- Project settings match the spec: landscape locked, 2D. The 3D physics
  engine setting that project creation added is irrelevant.
  The renderer is Compatibility, confirmed by spike 1 (D94, D96).
- A folder layout for components, levels, the simulation core, and tests.
- A test framework picked by the implementer, runnable headless from the
  command line.
- **Done when:** `godot --headless` runs one trivial test and returns a
  non-zero exit code when it fails.

### 1. Spike: soft slimes at scale (M, throwaway)

- A ring-of-springs slime and the blending shader, with 200 slimes on one
  screen: still (piled) and moving.
- Measure on the desktop first, then on the reference phone, and on a floor
  phone once one is bought.
- **Status:** done on the desktop (D94) and on the reference phone (D96: the
  tick stays in GDScript, fallbacks first, native code as the contingency).
  The floor phone waits for its purchase.
- **Background reading:** the performance targets and the 200-slime cap in the master spec (no ATD step: technical).
- **Done when:** the numbers are written down, with a go/no-go for the
  approach and the renderer. A no-go comes back to spec-writer before
  chunk 5 starts.

### 2. Spike: vector look (S, throwaway)

- Godot turns SVGs into images at import. Compare polygons and lines drawn in
  code against a vector plugin for crisp curves when zoomed.
- **Done when:** the approach is chosen and written down with its reasons.

### 3. Test backbone (M)

- One seeded random generator for all gameplay randomness.
- A fixed simulation step, so runs don't depend on frame rate.
- **Test mode** (Linux and debug Android builds only): speed up or skip
  time, inject taps and tilt from a script, and load a named fixture (a stub
  until chunk 8).
- A way to dump the simulation state (or a hash of it) for comparisons.
- The headless end-to-end runner. This also settles the risk of running
  end-to-end tests on Linux without a screen.
- **Done when:** the same script and seed run twice give the same state
  hash, and test mode is absent from a release export.

### 4. Level scaffolding and Meadow greybox (M)

- A level scene built from components, with no per-level scripts: the loop as
  a drawn route, terrain from paths and collision polygons, routes back as
  level data, stable IDs, and the level version.
- The shared rule format that components use ("when this basket is full,
  open that gate"), at least as an interface.
- Section 1 (Meadow) of the test level as a greybox with placeholder art.
- **Built:** a terrain component that bakes one curve into both the drawing
  and the collision polygon (D93).
- **Atoms (preflight start):** `req_loop_and_world`, `req_interactive_objects_general`, `req_level_design_rules` and its rules (`rule_no_dead_ends`, `rule_exploration_branch_has_route_back`, `rule_gravity_leads_back_to_loop`, `rule_start_carries_split_zone`, `rule_sleepers_never_on_loop`, `rule_first_sleeper_near_first_awake_slime`), `rule_released_level_stable_with_migration`.
- **Done when:** a test loads the level and finds the loop, the route back and
  every stable ID of section 1.

### 5. Slime body (L)

- Production version of spike 1: a soft body with sizes 1 to 3, six species
  colours (differing in lightness too), hopping as the only movement, and
  hop cadence from the seeded generator.
- Fusion and splitting as ring operations, exposed for later chunks.
- **Built:** the spike's struct-of-arrays layout and 12/15/18 points per
  ring (D94), and the slimes' own contact with the baked terrain segments,
  `TerrainSegments` (D97).
- **Atoms (preflight start):** `req_slime_states`, `req_hopping_behavior`, `req_species_and_colour`, `rule_max_size_three`, `rule_first_section_species_count`.
- **Done when:** unit tests cover ring creation, merging and splitting, and a
  demo scene shows slimes of each size and species hopping.

### 6. Train and split zone (M)

- Train slimes follow the loop by hopping (about 1.5–3 s, random per slime).
  Physics handles only the squish and the bumps.
- The split zone at the start of the loop. The return route is part of the
  loop in section 1 (the placeholder slide).
- The game wakes the first slime.
- **Atoms (preflight start):** `req_loop_and_world`, `req_hopping_behavior`, `rule_split_zone_only_splitter`, `rule_start_carries_split_zone`, `rule_loop_travelable_with_no_input`, `rule_all_sizes_travel_loop_v1`.
- **Done when:** with no input on the Meadow, the train loops for a full
  simulated session and no slime is lost [DoD 1, section 1 only], and
  every slime entering the split zone leaves as base slimes [DoD 7].

### 7. Taps and the call (L)

- Tap dispatch in the spec's order: top of the screen, edge buttons, object,
  open ground. At this stage only open ground does anything.
- The ripple on every tap. The first touch wins.
- The call: the radius, train slimes answering, the three phases of a free
  slime (answering, unsure, heading back by the route back), and rejoining
  the train.
- **Atoms (preflight start):** `req_controls_tap_zones`, `req_call_mechanic`, `req_slime_states`, `rule_exploration_branch_has_route_back`.
- **Done when:** scripted taps satisfy [DoD 3, 4, 15, 17].

### 8. Save format and fixtures (M)

- One save per level: each slime's species, size, state and position, and
  the object states (empty for now), with the level version and stable IDs.
- Autosave every 15 s and when the app goes to the background.
- Fixture loading in test mode. The fixtures are save files.
- **Atoms (preflight start):** `req_persistence_and_saves`, `rule_saves_never_wiped`, `req_test_level_and_test_mode`.
- **Done when:** a kill-and-reload test restores the slimes, and test mode
  loads a hand-made fixture.

### 9. Sleepers, waking and the first-play hint (S)

- A sleeper wakes only when a free slime touches it on screen. Tapping a
  sleeper is a call centred on it.
- The first-play hint: a wordless pulse near the first sleeper after about
  10 s with no call, shown on the first play only.
- **Atoms (preflight start):** `req_waking_sleepers`, `rule_first_sleeper_near_first_awake_slime`, `user_story_newcomer_p1`. No requirement atom covers the first-play hint yet, so the preflight should flag it and the documentalist adds one.
- **Done when:** [DoD 2, 16] pass, starting from `fresh`.

### 10. Fusion and bumping (M)

- Same-species contact for 3 s fuses. A hop that breaks contact resets the
  count. A fusion above size 3 bumps instead. The dip in the loop nudges
  fusion.
- **Atoms (preflight start):** `rule_fusion_contact_time`, `rule_max_size_three`, `rule_dip_may_nudge_fusion`.
- **Done when:** [DoD 6] passes, including `bump` (2 + 2 and 3 + 1).

### 11. Tilt, desktop and injected (S)

- Gravity turns with tilt up to ±45°, with a dead zone of about 10°. Neutral
  is taken at session start, and lying flat counts as neutral. Only free
  slimes feel it.
- The input is injected on desktop here. The real sensor comes in chunk 20.
- **Atoms (preflight start):** `req_controls_tap_zones` (tilt), `req_slime_states`, `rule_tilt_never_required`.
- **Done when:** [DoD 8] passes with scripted tilt.

### 12. Camera: rails, edge buttons, call drag (M)

- The camera on rails along the loop, return routes included. Right always
  means forward along the loop.
- The edge buttons (hidden at bedtime, once chunk 17 exists).
- The call pulls the camera slowly toward the call point.
- **Atoms (preflight start):** `req_camera_rails_and_framing`, `req_controls_tap_zones`, `rule_return_route_per_section`.
- **Done when:** the edge buttons move the camera along the loop in both
  directions, round the frontier turn, and the child has no zoom control.

### 13. Camera: framing zones, idle camera, screensaver zoom (M)

- Framing zones as a level component, including the longer push to leave
  one.
- The idle camera after 45 s, with the zoom-out cue 10 s before, following a
  train slime through fusion and splitting.
- One shared zoom for idle and screensaver mode. Framing zones are ignored
  while either follows a slime, and resume on touch if the camera's centre
  is still in a zone.
- **Atoms (preflight start):** `req_camera_rails_and_framing`, `req_idle_camera_and_screensaver_zoom`, `rule_framing_zone_wherever_wider_view_needed`.
- **Done when:** [DoD 18, 19] pass on the Meadow's framing zones. The minimum
  zoom is still an open point: log what the Meadow's zones show.

### 14. Frontier set, gates and completion (L)

- The switch (stays flipped), the basket (outlines by weight, the reward
  waiting for view, firing, release), the gate (extends the loop and replaces
  the return route), inert for good afterwards, signposts, and the one-time
  celebration.
- Opting out: flipping the switch back releases the slimes and empties the
  basket.
- Object state in the save.
- **Open point:** where a basket releases its slimes is part of the basket's
  own design, which isn't planned yet. Build the test level's assumption (one
  outlet onto the onward route) behind a property, so it can change.
- **Atoms (preflight start):** `req_switch_basket_gate_set`, `req_interactive_objects_general`, `rule_gate_opens_via_switch_basket_set`, `rule_frontier_set_inert_after_gate_open`, `rule_signpost_at_every_fork`, `rule_return_route_per_section`, `rule_return_route_may_carry_exploration`, `rule_tilt_never_required`.
- **Done when:** [DoD 9, 11, 12, 13, 14] pass, with `s1-basket-5of6` and
  `s1-optout`, while the basket is on screen.

### 15. Off-screen simulation (L)

- Physics only on or near the screen. Off-screen train slimes move as
  positions along the loop at a deterministic pace, and spawn just outside the
  view when it comes near.
- Free slimes that leave the screen follow their area's route back. Left
  alone at 10 s, lost at 1 min, and moved to the start.
- Baskets count weight off screen. Fusion and waking happen on screen only.
- Cheaper states (the fallbacks that come before native code, D96): resting
  slimes (a pile) stop being simulated, contact solving included, until
  something disturbs them; sleepers don't simulate; slimes in a full basket
  are simplified; and zoomed-out slimes use fewer points.
- **Atoms (preflight start):** `req_offscreen_simulation`, `rule_left_alone_and_lost`, `req_switch_basket_gate_set` (off-screen filling).
- **Done when:** [DoD 5, 10] pass, with `s2-cave-return`, `lost` and
  `s2-basket-offscreen`. Needs section 2 in greybox, pulled forward from
  chunk 16.

### 16. Test level sections 2 and 3, full population (M)

- Caves and the Big bowl in greybox, all frontier sets, all framing zones, and
  the full population of 200 slimes.
- The level rules checklist run against the test level.
- The fixture pass also regenerates `bump` with the slimes the test level
  now lists (two size-2, one size-3, one size-1), so that both bumps can
  happen.
- **Atoms (preflight start):** `req_level_design_rules` and all 20 rule atoms, `req_scope_one_level_four_sections`, `rule_max_200_slimes_per_level`.
- **Done when:** [DoD 1] holds for the whole level, and `gate1-open`,
  `gate2-open` (added while building), `stress-still` and `stress-moving`
  load. The stress fixtures give desktop
  performance numbers. The end-to-end test from `bump` asserts both bumps
  (2 + 2 and 3 + 1).

### 17. Session, wind-down, bedtime, sunrise (M)

- Screensaver mode, the first tap starting a 15-minute real-time session,
  the dusk wind-down in the last minute, bedtime (the slimes sleep, the game
  saves, taps are inert but still ripple, the edge buttons hide), and sunrise
  after 10 minutes.
- Timers stored with both the wall clock and the monotonic clock.
- **Atoms (preflight start):** `req_session_lifecycle`, `req_actor_roles_and_permissions`, `req_denial_and_stepup_behavior`.
- **Done when:** [DoD 20, 21, 22] pass on desktop with time skipping (the
  "wake early" path waits for chunk 18), with `wind-down`, `bedtime` and
  `sunrise`.

### 18. Parent gate and settings, placeholder UI (M)

- First-launch setup (the code typed twice, the explanations), the top-of-
  screen reveal, wake early (bedtime only), leave, and settings (change the
  code; delete a level's save with a second confirmation).
- A wrong code shakes and clears. After 5 wrong tries in a row there is a
  30 s wait. The prompt closes after about 15 s with no input, and settings
  closes after 30 s with no input, with a warning over the last 10 s
  (D113). Nothing pauses.
- The parent buttons hide after 5 s with no press; a tap outside the open
  buttons or code prompt closes it and does its normal job (D113).
- Setup in four steps (welcome, the code, if you forget it, pinning); the
  code is saved only when setup finishes, and an interruption restarts it
  from the first step (D113).
- **The time left** (session, or until sunrise) in the settings header and
  on the wake-early prompt, never on the parent buttons (D114, new v1
  scope).
- Parent-facing targets at least 9 × 9 mm (D109). Text strings in English
  and French, the French with "vous" (D102, D113).
- The code is stored locally, never in plain text.
- The rules follow `access-model.md`.
- Debug tools: they move below the ingame menu when it appear. 
- **Atoms (preflight start):** `req_parent_gate_and_access`, `req_actor_roles_and_permissions`, `req_denial_and_stepup_behavior`, `req_persistence_and_saves` (deleting a save).
- **The session on delete (D104):** the session lives in the level's save.
  Deleting that save keeps the running session and writes it into the fresh
  save, so deleting the save can't escape bedtime.
- **Done when:** [DoD 23, 24, 29] pass on desktop, including: the buttons
  hiding after 5 s; a scripted tap on the world while the buttons or the
  prompt are open closes them and calls (and starts a session in
  screensaver mode); settings closing at 30 s, a touch at 25 s resetting
  it; setup interrupted at step 3 keeping no code and restarting at step 1;
  the time left matching the session clock in settings and on the
  wake-early prompt. The "forgot the code?" path is stubbed until chunk
  20.

### 19. Persistence hardening (M)

- Atomic writes with one backup, used when the latest save can't be read.
- A slime in mid-air on load: grounded, or put back at the start of its jump,
  or lost.
- Save migration by level version: displaced slimes count as lost.
- **The parent code's file too** (`user://parent.json`, proposed, D130):
  the same atomic write and backup, so a damaged file no longer reads as
  "no code" (setup shown again, maybe to the child, and the wait lost).
  The backup of a level's save goes in `SaveStore.delete` with the save.
- **Atoms (preflight start):** `req_persistence_and_saves`, `rule_saves_never_wiped`, `rule_released_level_stable_with_migration`, `req_parent_gate_and_access` (the code's file).
- **Done when:** [DoD 28] passes, including a kill during a write, with
  `midair` and `old-version`, and a damaged `parent.json` keeps the code
  from its backup (proposed, D130).
- **Built** (D131): done; the choices marked proposed there wait for the
  user.

### 20. Android build and platform integration (L)

- Android export, landscape lock, the screen kept on during a session, and
  background and kill lifecycle feeding saves and timers.
- Screen pinning requested at each launch, and "leave" ending it. This needs
  an Android plugin; check how Godot 4.7 plugins call `startLockTask()` early
  in the chunk.
- "Forgot the code?" through Android's system prompt with the device
  credential. Chunk 18's setup text already describes it and pinning, and
  its prompt link is a stub (D130).
- Check on the reference phone that the French parent labels fit
  (D130; or in chunk 22).
- Real tilt from the sensor.
- No network permission in the manifest.
- **Sticky immersive mode**, the world drawn edge to edge with the controls
  inside the safe area, and **the whole edge strips excluded from the back
  gesture** (D112). Check on the reference phone (One UI) that a tap
  sliding off a strip with pinning declined doesn't go back.
- **Atoms (preflight start):** `req_screen_pinning`, `req_parent_gate_and_access` (forgotten code), `req_session_lifecycle` (lifecycle), `rule_no_network_connection`, `req_platform_and_performance_targets`.
- **Done when:** [DoD 25, 26, 27] pass on the emulator, including a swipe
  from a strip with pinning declined staying in the app, and tilt feels
  right on the reference phone.
- **Built** (D132): done on the emulator; the phone checks (D132, 3) wait
  for the user's S20 FE, and the choices marked proposed there wait for
  the user.

### 21. End-to-end suite (M)

- Every fixture in the test level's list has at least one scripted
  end-to-end test, and the suite runs headless on the Linux build.
- **Done when:** [DoD 31] passes, and the suite is repeatable (same seed, same
  result).
- **Built** (D133): DoD 31 passes on the Linux build; four tool-driven
  test files run only in the editor suite, and repeatability is proved per
  fixture (proposed, D133).

### 22. Performance pass on phones (M)

- The real game at the endgame (the bowl, a full basket, the train) on the
  reference phone and the floor phone, each cold and after 5 minutes of play
  (once the phone has throttled), plus normal play.
- `stress-still` and `stress-moving` are measured too and recorded; they are
  measurements, not targets (D96).
- **Resting piles (D107):** measure a bedtime pile in the open (it may take
  about a minute to rest with the fixed anchor), and how often an awake slime
  hopping against a pile wakes it; revisit the rest rule if either costs
  the targets. Bring the code comment on `REST_DRIFT` in line with the rule
  (the anchor is fixed where the count started, not a sliding window).
- **The level bench's start (D131):** `tools/bench_level.gd` times from
  `REST_TICK` 670, but the stress pile now rests at about tick 410; fix
  the start before measuring.
- **Atoms (preflight start):** `req_platform_and_performance_targets`, `rule_max_200_slimes_per_level`.
- **Done when:** [DoD 30] holds: 60 fps on the reference phone in normal
  play, and at least 30 fps on the floor phone in the realistic worst case
  (the level's largest pile on one screen: a full basket plus the train,
  mostly still). **If either fails, chunk 5N runs and this chunk is
  repeated.** If the floor phone still can't hold it, the floor rises (D71).
  The 200 cap stays.

### 23. Small issues (open list)

Small issues the user finds while playing the build. The list stays open:
new reports are added here as they come, each with the spec change it
needs and its own done-when. It runs **next, before chunk 18** (D123): its
items are mechanics fixes and decided behaviour, and landing them before
chunk 22 means the performance pass measures the finished behaviour
(baskets at bedtime, the safety nets). It runs as sub-chunks 23A to 23E
(see "Progress"). Each issue is small (S) and can land on its own. An issue
tagged **(proposed)** still waits for the user's approval; 23.1 to 23.9 are
decided (D99 to D101, D103, D105, D109 to D111, D113); 23.10 to 23.12
come from the master spec's alignment with ux D4 and ux D5; 23.13 is
decided (D121).

**23.1 Call camera dead zone** (reported and decided 2026-09-29; D101;
master spec 5.6).
- A call whose point is already inside a box centred on the screen, 20% of
  its width by 20% of its height, happens as usual (the slimes answer, the
  ripple shows) but doesn't move the camera; during a drag it stops the
  drag where it is. Outside the box, the call drag is unchanged.
- **Done when:** a scripted tap inside the box calls the slimes in range
  and leaves the camera where it was until the answering window ends; a tap
  just outside it drags the camera as before; the box holds at each framing
  zone's zoom (it is measured on the screen); a tap inside the box during
  a drag stops the drag; [DoD 3] and [DoD 18] still pass.

**23.2 Edge buttons as whole-height strips** (reported and decided
2026-09-29; D99, which settles O81; master spec 5.5).
- A tap within 10% of the screen's width from the left or right edge, over
  the whole height below the parent zone, is an edge-button press: step and
  hold as now (D102), right forward and left backward (D90). The strip takes
  the whole tap: no call, and no object under it is operated. The parent
  zone wins in the top corners. Hidden at bedtime as now: a tap there is
  then an ordinary tap. The drawn arrows stay placeholders for `ui_ux/`.
- **Done when:** scripted taps at the top, middle and bottom of each strip
  move the camera and issue no call; a tap just inside the strip's inner
  edge moves the camera and one just past it calls; a tap in a top corner
  opens the parent zone; an object placed under a strip isn't operated; a
  strip tap in screensaver mode doesn't start a session; at bedtime a strip
  tap moves nothing; [DoD 18] and [DoD 20] still pass.

**23.3 Slimes stuck inside each other: safety net** (reported and decided
2026-09-29; D100; master spec 5.2; the real fix is O91).
- Every 0.5 s, pairs of simulated slimes that can't fuse whose centres are
  closer than a quarter of the smaller one's radius are counted; after 4
  checks in a row (about 2 s), the smaller one (a train or free slime; on a
  tie the higher id) is moved to the start of the loop, back on the train,
  and logged with the reason "stuck". Stuck is its own state, not lost
  (D100). Sleepers, slimes in a basket and
  bedtime-asleep slimes are never moved; if neither can be moved, the pair
  is only logged.
- **Done when:** a unit test that places two slimes of different species
  on the same centre sees the smaller one moved after about 2 s and logged
  as "stuck"; a same-species pair that can fuse is left to fuse; a pair
  touching normally is never moved; the same seed gives the same hash; the
  log is in the state dump, so tests and the debug overlay can show every
  rescue.
- **Not in this issue:** finding why it happens (O91, not urgent). When
  it is found, the fix comes with a test that reproduces it, and the safety
  net can be reconsidered.

**23.4 The idle camera never zooms in** (decided 2026-09-29; D103; master
spec 5.6). A change to chunk 13's idle camera.
- Where the camera is already wider than the idle and screensaver zoom
  (inside a wide framing zone), the idle cue and the idle camera keep that
  zoom instead of zooming in. Tilt still doesn't count as input for the idle
  clock (already built).
- **Done when:** in the test level's tree zone (zoom 0.7), the idle cue and
  the idle camera never raise the zoom above 0.7; in a zone narrower than
  the idle zoom, the cue zooms out as before; [DoD 19] still passes.

**23.5 Baskets at bedtime** (decided 2026-09-29; D105; master spec 5.4
and 5.7). A change to chunks 14 and 17. Chunk 22 measures bedtime piles
with it in place (sub-chunk 23D).
- At bedtime a basket's releases pause and resume at sunrise; the slimes in
  it sleep in place (they stay in the basket, shown asleep) and sunrise
  doesn't move them out; a reward that is due or playing waits for sunrise,
  so no gate opens and no celebration plays during bedtime. Saved and in
  the state hash, like the rest of the set's state.
- **Done when:** from `bedtime` with a basket releasing (and, in a second
  test, a full basket in view with its reward due), no slime is released and
  no gate opens until sunrise, then both resume; slimes in the basket stay
  in it through sunrise; a save taken during bedtime reloads the same;
  [DoD 21] and [DoD 9] still pass.

**23.6 Hit areas held on the screen** (decided 2026-09-29; D109; master
spec 5.4). From the UX review (Q4).
- An interactive object's hit area is its drawing plus 5 mm on every side,
  never under 20 × 20 mm, measured on the screen at the current zoom
  (replacing the fixed 24-unit margin).
- **Done when:** at zoom 1, a scripted tap 4 mm outside a switch's drawing
  flips it and one 6 mm outside calls; in `s3.frame.basket` (zoom 0.8), a
  tap near the edge of the 20 × 20 mm floor centred on switch 3 flips it; [DoD 18] still
  passes.

**23.6b The parent zone at 7 mm** (decided 2026-09-29; D113, ux D4;
master spec 5.5).
- The parent zone becomes a band 7 mm high measured on the screen (from the
  64 screen-unit placeholder), full width, unmarked; the edge strips start
  below it.
- **Done when:** on the reference phone's size, a tap 6 mm from the top
  reveals the parent buttons and one 8 mm from the top calls (or, on a
  strip, moves the camera); [DoD 24] still passes.

**23.7 Only what answers a tap takes it** (decided 2026-09-29; D109;
master spec 5.4, 5.5). From the UX review (Q10).
- A tap on a basket, a gate or a signpost, or on a switch whose basket is
  full or whose gate is open, is a call; only a switch whose basket is
  filling takes a tap.
- **Done when:** scripted taps on each of those call the slimes in range
  (and start a session in screensaver mode); a tap on a filling basket's
  switch still flips it; [DoD 11, 13] still pass.

**23.8 A resting thumb on an edge strip** (decided 2026-09-29; D110;
master spec 5.5). From the UX review (Q9). **To check in a playtest.**
- A strip touch held longer than about 5 s keeps moving the camera but
  stops counting as the first touch; the next touch is handled as if no
  finger were down.
- **Done when:** with a scripted strip touch held 6 s, a second touch
  starting after 5 s calls (with its ripple), and one starting before 5 s
  still gets nothing; [DoD 17] still passes. The playtest then says whether
  5 s is right.

**23.9 Objects below the parent zone** (decided 2026-09-29; D111; level
rule 21). From the UX review (Q8).
- A level-rule test: at the rails' framing, every interactive object sits
  fully below the parent zone, on the whole test level.
- **Done when:** the test passes on the test level and fails on a synthetic
  level with a switch under the band.

**23.10 Showing a gate open** (master spec 5.6; ux D4, Q14). Not built:
the camera never moves on its own when a basket fires.
- When a basket fires and its gate is off screen, the camera glides to the
  gate (about 1.5 s) to show it opening, then stays there under normal
  control. Input stays live: a touch takes control back and does its
  normal job. A gate already in view: nothing moves.
- **Done when:** from `s1-basket-5of6` with the camera placed so gate 1 is
  off screen, the basket fires and the camera ends with gate 1 in view
  within about 1.5 s; a scripted tap during the glide calls and takes the
  camera back; with gate 1 already in view the camera doesn't move; same
  seed, same hash.

**23.11 The celebration's lasting mark** (master spec 5.1; ux D4, Q15).
Built: the 4 s burst of rings over the view, with input live and the camera
left alone (nothing in chunk 14 blocks input or moves the camera). Not
built: the lasting mark.
- Once the celebration has played (the level's saved done mark), a small
  lasting mark at the start of the loop shows the level is complete,
  visible to anyone who passes, after a reload too. Its look is ux-writer's
  (ux D4 names bunting as an example; placeholder art until then). Also
  from ux D4: every awake slime on screen does a double hop during the
  burst.
- **Done when:** from `stress-still` (basket 3 full) the celebration plays
  and the mark appears at the start of the loop; it is still there after a
  save and reload, and absent on a level whose celebration hasn't played;
  a tap during the celebration calls as usual and the camera doesn't move
  on its own.

**23.12 The idle camera at bedtime** (master spec 5.6; ux D5, Q18).
Mostly built by the way chunk 13 picks its target: the idle camera starts
only on a train slime, and at bedtime there are none, so it never starts;
one already following keeps the id of a slime that is now asleep and
doesn't move. What isn't checked: the cue or the follow in progress when
bedtime begins.
- At bedtime the idle camera follows no one and the camera travels
  nowhere; it may settle at the idle zoom.
- **Done when:** from `wind-down` with no input, the camera is idle when
  bedtime begins and doesn't travel through the whole cooldown (its
  position stays put; only the zoom may settle); the same with bedtime
  beginning during the idle cue; at sunrise the idle camera follows a train
  slime again.

**23.13 A stalled train slime: safety net** (decided 2026-09-29; D121,
which settles O95; master spec 5.2). A change to chunk 6's stall check in
`Train`, which today only logs. The same move to the start of the loop as
23.3 (stuck) and the lost timer (D10): reuse it rather than add a third.
- A train slime that is stalled (no 24 px of progress in 60 s, or its
  centre out of the level's bounds; D118) is moved to the start of the
  loop and rides the train again. Each case is logged with the reason
  `stalled` or `out_of_bounds`, no longer once per slime; the 60 s count
  starts again from the move. A slime asleep at bedtime is never counted
  as stalled or moved.
- **Done when:** a unit test that wedges a train slime so its progress
  can't advance sees it moved to the start of the loop after 60 s, back on
  the train and logged as `stalled`; one placed out of the level's bounds
  is moved and logged as `out_of_bounds`; wedged again, it is moved and
  logged again; from `wind-down`, no train slime asleep at bedtime is
  moved or logged; the same seed gives the same hash; and the whole-level
  DoD 1 test still fails on any logged stall (its meaning is unchanged:
  no train slime stalls in 15 minutes with no input).

### 24. Playtest issues, round 2 (open list, proposed)

**This list stays open: the user's next play reports are appended here**
(24.4 onward), each with the spec change it needs and its own done-when,
as chunk 23 did. The first three come from the user's own testing
(2026-09-29): nothing major gameplay-wise, but a frame-rate drop in the
last section, an unreadable basket display for a large quota, and a
basket that keeps its slimes once it has fired. The chunk runs **after
chunk 22 (and 5N if it runs), the last chunk before the closing health
review**, as the user asked (D128; O97 asks whether 24.1 and 24.3 should
run before chunk 22 instead). Each item is small (S) unless its
investigation says otherwise, and can land on its own. All three items
are **(proposed)** until the user approves D128. Items with business
behaviour (24.2, 24.3) and the frame-rate target (24.1, like chunk 22)
keep both ATD steps.

**24.1 The frame rate drops in section 3** (reported 2026-09-29;
proposed, D128; master spec 6 and 7, [DoD 30]). An investigation, then a
fix. The user asked for hard data first, hence the debug overlay's fps
and slime counts (built 2026-09-29).
- **Measure first.** Two sources, recorded before and after the fix in
  the project documentation (`docs/dev/`), at the same camera spots:
  - the **debug overlay** in a windowed run (fps, and the slimes on
    screen : simulated off screen : parked), through section 3 in normal
    play: the bowl with the train and called slimes, and basket 3
    filling, full and releasing;
  - the **level bench** (`tools/level.sh bench --level=test`) on the
    section 3 fixtures (`gate2-open`, `stress-moving`, `stress-still`) and
    on a new fixture with basket 3 at 59 of 60, switch 3 flipped, not at
    bedtime (shared with 24.3; its name is the implementer's), in ms per
    tick (median and p95), with the drawing's share measured separately
    where the bench can't see it (it runs headless).
- **Leads, not conclusions.** The bench already reads about 15 ms per
  tick for `stress-moving` (200 base slimes riding the train out of the
  bowl) on the desktop, headless (`docs/dev/README.md`, 16c-B): nearly the
  whole 16.7 ms frame at 60 ticks a second before anything is drawn.
  Other candidates: contact pair checks as section 3 wakes up to 130 more
  slimes, drawing at the bowl's zoom 0.5 (more slimes on screen), basket
  3's pile not resting or not parked, slimes cycling in and out of basket
  3 (see 24.3).
- **Fix the cause found.** No behaviour change (same seed, same hash);
  a fix that has to change behaviour says so and goes back to
  spec-writer. If the cost is the GDScript tick itself with no fallback
  left, that is chunk 5N's ground (D96): report it rather than start
  native code here. If chunk 22 (or 5N) has already brought section 3 to
  the target, 24.1 closes with the measurement alone.
- **Target (proposed):** on the desktop (the Linux build at test mode's
  1152 × 648 window), a steady 60 fps on the overlay through section 3
  in normal play, and the section 3 bench cases at most 8 ms per tick at
  p95 (half the frame, leaving the rest to drawing), `stress-moving`
  excepted (a measurement, not a target, D96). The phones' targets stay
  chunk 22's [DoD 30].
- **Done when:** the before and after numbers (overlay readings and bench
  table) are in `docs/dev/`; the section 3 bench cases hold the tick
  budget above; a windowed run through section 3 reads a steady 60 fps;
  the whole suite is green, and the same seed gives the same hash; [DoD
  30] still holds if chunk 22 has run.

**24.2 A quota above 10 shown as pies** (reported 2026-09-29; proposed,
D128; master spec 5.4 and [DoD 9]; the look is ux-writer's, ux D4 Q10).
Basket 3's 60 outlines run wider than the screen.
- **A quota of 10 or less:** unchanged, one slime outline per unit of
  weight.
- **A quota above 10:** one **quota pie** per 10 of weight, the last
  holding the rest (15: a pie of 10 and a pie of 5; 60: six pies of 10).
  Each pie has one slice per unit of weight. Slices fill in order, the
  first pie first, in the colour of the slime caught (as the outlines
  do, ux D4); a size-3 slime fills three slices, across two pies when it
  has to. A full pie stays full while the basket fills.
- **The other states as ux D4 has them for the outlines:** the reward
  pulses every pie; while the basket releases, slices empty one by one
  with the slimes; inert, the pies are gone. (The build today keeps every
  outline filled once the basket has fired; this item brings outlines
  and pies in line with ux D4.)
- **Readable:** the whole row fits within the basket's width, and each
  pie is at least 6 mm across on the reference phone's screen at the
  basket's framing zoom (proposed). Placeholder art until ux-writer draws
  them.
- **The quota itself:** basket 3's 60 stays on the test level. It is the
  test level's stress case (`stress-still`, chunk 22's largest realistic
  pile, [DoD 30]), and the test level is never released. How large a
  real level's quota may be for a child is O98 (proposed: at most 30 of
  weight per basket on the first level, three pies).
- **Done when:** a unit test of the display's layout: a quota of 6 gives
  6 outlines, 15 gives pies of 10 and 5, 60 gives 6 pies; at weight 23 of
  60, two full pies and 3 slices of the third; a size-3 slime arriving at
  weight 8 fills the first pie and one slice of the second; at
  `s3.frame.basket`'s zoom, basket 3's pies fit within its width and
  each measures at least 6 mm on the reference phone's screen size; the
  reward, release and inert states as above; basket 1 still shows 6
  outlines; [DoD 9] still passes.

**24.3 A fired basket lets its slimes go** (reported 2026-09-29; a bug
against the spec, with proposed details, D128; master spec 5.2 "in a
basket" and 5.4; D86, D91, D105).
- **What the spec already says, unchanged:** once full, a basket plays
  its reward (waiting until it is in view), fires (its gate opens; basket
  3, with no gate, fires the celebration, D77), then **releases its
  slimes**: one every 0.3 s, lowest id first, at its outlet when the
  outlet is clear (`tuning.md`). Each rides the train again with its size
  and species, under the usual rules (fusion, the split zone). The switch
  and basket are then inert for good and the gate stays open (D86). At
  bedtime the releases pause and resume at sunrise (D105, item 23.5).
  Released slimes are train slimes: available again, never lost or
  stuck. Built in chunk 14; the end-to-end test only covers basket 1
  with 3 slimes.
- **Reproduce first:** a test that fails today, from the fixture 24.1
  adds (basket 3 at 59 of 60, not at bedtime) and from
  `s2-basket-offscreen` (basket 2).
- **A lead to check first** (unverified, read from the scene, not run):
  basket 3's outlet is a point over switch 3's trapdoor, and a trapdoor
  shuts after firing only once no awake slime is within reach of it; a
  released slime that lands on an open trapdoor falls back into the
  basket, which releases it again, so the basket may never empty. Basket
  2's pit, under its gate, may do the same.
- **Proposed (D128):** a fired basket always empties: no released slime
  falls back into it (its trapdoor is shut, or its outlet is off the
  trapdoor, before the next release), and it is empty within its quota
  × 0.3 s plus 10 s of firing, however busy the outlet. The 0.3 s pace
  stays. Where the outlet is stays O62, the basket's own design; only
  the test level's outlets move if the fix needs it.
- **Done when:** from the new fixture with the camera on basket 3, the
  basket fills, fires (the celebration) and is empty within 28 s, every
  released slime a train slime with its size and species, none back in
  the basket; from `s2-basket-offscreen`, basket 2 fires and is empty
  within 14.5 s; from `bedtime` with a releasing basket nothing leaves
  until sunrise (item 23.5's tests still pass); the same seed gives the
  same hash; [DoD 1] and [DoD 9] still pass.

### LD. Level-design toolkit (L, technical)

Asked for by the user (D123). Tooling for whoever designs a level: no
Definition of done item and no business behaviour, so no ATD steps; it
still goes test first. It runs in parallel with chunk 23 and builds on what
chunk 16 left: the test level, its level-rule tests and the level bench.
Split (D126) into **LD1**, the tools, and **LD2**, the tutorial and the
skills, then **LD3**, the gaps LD2 found (D127). All three are done.

- **Tools.**
  - **A level-rules checker, usable on any level.** For every rule in
    `../../level-design.md` (1 to 22), its report says either *checked by
    code* (pass or fail, with where) or *manual review* (what to look at),
    so no rule is left out silently. It reuses the existing level-rule
    tests' checks rather than duplicating them.
  - **A new-level scaffolder.** It creates a level's tree under
    `levels/<id>/` from the level components, its fixtures, a per-level
    test script (the checker plus a load test), and the level's
    integration into the app, so it can be loaded in test mode.
  - **Other tools that make level design easier**, the implementer's
    proposal, written down in the project documentation (for instance a
    debug overlay of rails, framing zones and routes back, or a quick
    fixture maker).
- **A tutorial for level designers:** a series of short, targeted Markdown
  files in `docs/level-design/` (one topic each: starting a level, the
  loop and sections, exploration branches and routes back, frontier sets,
  framing zones, decoration, checking a level against the rules).
- **Project skills in `.claude/skills/`:** start a new level; add a
  section, an interactive object, or a decorative asset; review a level
  against the level-design rules (it runs the checker and walks through the
  manual-review rules).
- **Decoration** has no settled spec yet: O96. The toolkit builds to its
  proposed default (decoration never collides, never takes a tap, never
  hides an interactive object or a hint) and changes if the user decides
  otherwise.
- **Done when:** the checker reports on the test level and agrees with the
  existing level-rule tests (a rule those tests fail, on a synthetic level,
  the checker fails too); the scaffolder creates a level that loads, passes
  its generated tests and appears in test mode; the tutorial and the
  skills exist and walk through creating a small level end to end.
- **Later, before the first level is released (proposed, D127): rule 20's
  released IDs.** A small checker change, not test-level work (the test
  level is never released). A released level keeps a list of its
  released stable IDs (for example `levels/<id>/released_ids`); the
  checker then asks that every released ID still exists, that new
  sleepers take numbers above the highest released one in their section,
  and applies its order and gap checks to unreleased IDs only; removing a
  released ID needs a `level_version` bump and a save migration.
  **Done when:** a throwaway level with a released-ID list passes with a
  sleeper added above the highest number, and fails with a released ID
  removed without a version bump.

### TL1. Test level finishable from fresh (S, proposed)

**Done (D129).** The done-when below is met: 0 FAIL and 0 warnings; the
new played test `tests/e2e/test_test_level_playable_e2e.gd` fills each
basket with base slimes alone (from `fresh`, `gate1-open`, `gate2-open`;
seeds 1 to 6); fixtures regenerated; suite 922/922. Sleepers were lined
up touching (chain waking) within a called base slime's hop; stable IDs
kept, section 3's renumbered left to right (never released, rule 20).
Deviations from the test level's plan and the choices left for the user
(rule 12's reading, rule 22 (b)'s 130 px house style, basket 3's tight
margin) are in D129.

Proposed in D127: LD3's progress estimate warns on all three sections of
the test level, and probes back it. In section 1 only two sleepers are
within a called base slime's reach, and A, B and C awake can't fuse, so 3
base slimes stand against basket 1's quota of 6; sections 2 and 3 follow.
Content work on `levels/test/level.tscn` (through its generator), no new
behaviour, so no ATD steps; it still goes test first.

- Rework the sleeper placement: ledges lowered or moved within a called
  slime's reach, same-species pairs early in section 1. Keep the stable
  IDs, preferring moves that keep the left-to-right order (fixtures and
  tests name sleepers by ID).
- Every level rule still passes, the population stays 200, and the
  coverage matrix still holds.
- **Done when:** the checker gives 0 FAIL and 0 warnings on the test
  level; a scripted play from `fresh` fills basket 1, and from
  `gate1-open` and `gate2-open` baskets 2 and 3; the fixtures are
  regenerated and the whole suite passes (DoD 1 included).

### 5N. Native simulation tick (contingency, only if chunk 22 fails)

Size M. Not in the ordered sequence: **chunk 22 is its trigger** (D96). It
runs only if chunk 22's measurement of the real game fails on either phone,
and chunk 22 is then repeated. Technical: no ATD steps. It must not run
while another chunk edits the slime body code.

- **Already in place (the verified contingency):** the toolchain and a
  trivial extension under `native/`, documented in `docs/dev/native.md`,
  kept out of the test suite and the exports.
- The simulation tick moves to a GDExtension in C++ (godot-cpp): the ring
  solver, the contacts between slimes, and the terrain contact against
  `TerrainSegments` (D97).
- The simulation keeps its GDScript interface. Behaviour code (hops, phases,
  calls, fusion timing) stays in GDScript, unchanged.
- Built with `-ffp-contract=off`, for the Linux desktop and, through the
  Android NDK, for Android arm64, both from one build script, and included
  in the Android export.
- Determinism: hashes are compared within one build and platform. The
  native results don't match the GDScript version bit for bit, and tests
  compare runs within one build. Whether the GDScript tick is kept alongside
  (for instance as a reference) is the implementer's call, written down in
  the project documentation.
- **Background reading:** `../../tech-direction.md` "Simulation performance"
  and the reference phone numbers in `docs/dev/spike-soft-slimes.md`.
- **Done when:** the Linux and Android arm64 extensions build from one
  script; the whole suite passes on the native tick; the bench numbers
  (desktop and phone, native against GDScript) are recorded in the project
  documentation; and chunk 22, repeated, passes.

## Not in this plan

- **The real first level:** chunk L01, moved to v2 (D134). v1 is the
  test level only.
- **The interface design** of the parent screens, setup and the celebration:
  the UX track. The placeholder UI from chunk 18 is replaced then.
- **Playtesting with children** [DoD 32]: deferred, not an objective of
  the full MVP; it may first need some graphics work (D135).
- **The basket's own design** (where it releases its slimes): a later
  spec session. Chunk 14 keeps it swappable.

## Open questions that block chunks

None. O96 (decoration) shapes part of chunk LD, which builds to its
proposed default until it is decided. The questions the first UX review raised (O67–O77, which chunks 7, 9,
12, 17, 18 and 20 built to) were settled as proposed in D102, and the
build's own points O79–O87 in D103–D107.

## Before starting

- Godot 4.7.2 is reachable as `godot` (a symlink in `~/.local/bin`). The
  project skeleton is committed, without the 3D physics setting. Its other
  settings are adjusted to the spec in chunk 0.
- A floor phone (Galaxy A14 class) has to be bought before spike 1's floor
  run and before chunk 22.
- The native contingency (chunk 5N) uses a C++ toolchain on Linux,
  godot-cpp matching Godot 4.7, and the Android NDK (installed:
  `ndk/28.2.13676358`, per the spike); see `docs/dev/native.md`.
