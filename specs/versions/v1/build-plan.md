# Slime Train v1 — Build plan

Status: draft v10 (approved by the user, 2026-09-29, D108)

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
  simulation tick, a contingency) and chunk 21 (the end-to-end suite) still
  go test first. Chunk 5N changes no behaviour: the existing suite is its
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

- **Done:** 0 to 15 and 17; 1 on the desktop and the reference phone (the
  floor phone waits for its purchase). Chunks 14 and 17 raised O82 to O86
  (the session in the level's save, baskets at bedtime, the switch locked
  once the basket is full, the gate's lid, a state for slimes in a basket),
  settled in D104–D106.
  Chunk 15 built section 2 in greybox with the off-screen simulation.
- **In progress:** 16. Done so far: section 3 in greybox, the full
  population of 200, every fixture regenerated (with `gate2-open` added),
  the suite green. Left: the level-rule tests, the whole-level DoD 1 test,
  the level bench, the developer notes and the intent tags. Chunks 15 and
  16 raised O87 (the rest rule's anchor), settled in D107.
- **Next:** 18. (5N is a contingency, run only if chunk 22 fails,
  D96.) Chunk 23 (small issues from play) is an open list, run after 22;
  its item 23.5 (baskets at bedtime) lands before 22.

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
| 22 | Performance pass on phones | M | 20 | [DoD 30] |
| 23 | Small issues (open list) | S per issue | 22 | each issue's own done-when |

Chunks 1 and 2 can run in parallel with 3. Chunk 5N is not in the
sequence: it runs only if chunk 22's measurement fails (D96). Chunks 9, 10
and 11 are independent of each other. Chunk 17 can start as soon as 8 is done, in
parallel with the camera and objects work.

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
- **Atoms (preflight start):** `req_persistence_and_saves`, `rule_saves_never_wiped`, `rule_released_level_stable_with_migration`.
- **Done when:** [DoD 28] passes, including a kill during a write, with
  `midair` and `old-version`.

### 20. Android build and platform integration (L)

- Android export, landscape lock, the screen kept on during a session, and
  background and kill lifecycle feeding saves and timers.
- Screen pinning requested at each launch, and "leave" ending it. This needs
  an Android plugin; check how Godot 4.7 plugins call `startLockTask()` early
  in the chunk.
- "Forgot the code?" through Android's system prompt with the device
  credential.
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

### 21. End-to-end suite (M)

- Every fixture in the test level's list has at least one scripted
  end-to-end test, and the suite runs headless on the Linux build.
- **Done when:** [DoD 31] passes, and the suite is repeatable (same seed, same
  result).

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
needs and its own done-when. It runs **after chunk 22**, so it doesn't
disturb the performance measurement; an issue can be pulled forward if it
blocks testing. Each issue is small (S) and can land on its own. An issue
tagged **(proposed)** still waits for the user's approval; 23.1 to 23.9 are
decided (D99 to D101, D103, D105, D109 to D111).

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
and 5.7). A change to chunks 14 and 17. **Pull it forward: land it before
chunk 22**, which measures bedtime piles.
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

- **The real first level:** its design session comes after chunk 16, once the
  test level has been played. v1 ships that level, not the test level.
- **The interface design** of the parent screens, setup and the celebration:
  the UX track. The placeholder UI from chunk 18 is replaced then.
- **Playtesting with children** [DoD 32]: after chunks 20 and 22, on the
  real first level.
- **The basket's own design** (where it releases its slimes): a later
  spec session. Chunk 14 keeps it swappable.

## Open questions that block chunks

None. The questions the first UX review raised (O67–O77, which chunks 7, 9,
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
