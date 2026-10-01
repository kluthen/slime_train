# Technical direction

Status: draft v29 (chunk 22e built: the local wake, the hold with D145's numbers, the save key `train.hold`, user-approved, format 1, D145, D146's as-built notes; the save format may break until the first store release, a save a build can't use set aside then, the save wipe for automated testing only, D149, proposed where beyond the user's words; a save wipe flag for development builds, chunk 19w, D148, approved in direction; chunk 22f, the hold's second round, before 5N, which ports its rest rules, D147, proposed; the hold and the local wake in chunk 22e, before 5N, which ports them, D146, proposed; the hold, D145, proposed)

Research: `docs/research/tech-stack.md`, `docs/research/level-authoring-and-kid-lock.md`.
Spike write-ups: `docs/dev/spike-vector-look.md` (chunk 2, desktop),
`docs/dev/spike-soft-slimes.md` (chunk 1, desktop and reference phone).

## Engine

- **Godot 4** is the engine (D5). Unity and Unreal are excluded.
- Primary target: native Android. A Linux desktop and/or web build of the
  same project exists to iterate faster and to run end-to-end tests.
- **Renderer: Compatibility** (D94, D96). Forward Mobile gave the same look
  and frame rate on the desktop; Compatibility reaches the most Android
  phones. On the reference phone both renderers hold 60 fps on drawing
  alone, and Forward Mobile saves under 1 ms of render CPU time. The Mali-GPU
  floor phone is still the real test of the choice (O14).
- Choosing Godot came with risks to test with small prototypes. Where they
  stand:
  - **Vector look: settled (D93).** Level art is drawn from curves baked into
    polygons and lines (see "Level authoring"). Godot turns imported SVGs into
    images, which blur when the camera zooms in, and no runtime vector plugin
    exists for Godot 4.7.
  - **Soft slimes at 200: settled on the desktop (D94) and measured on the
    reference phone (D96):** the tick stays in GDScript with the fallbacks
    first, native code as the contingency; the floor phone is pending (see
    "Simulation performance").
  - **Running tests without a screen: settled** in chunk 3 (headless Godot,
    see `docs/dev/README.md`).
  - **Still to test on real phones (O14):** the floor phone, the real game
    on both phones (chunk 22), tilt input, and Android audio latency
    (only from v2, when music arrives, D134).

## Level authoring

- **No custom level editor** (D6). Levels are Godot scenes built in Godot's
  own editor. Curved terrain uses Path2D/Curve2D with collision polygons.
- **Vector look (D93).** Terrain and other level art (plants, rocks,
  decoration) are drawn as Path2D/Curve2D curves in the editor. At load, each
  curve is baked once into a Polygon2D fill and a Line2D outline (antialiased,
  round joints), which stay crisp at 4× zoom. Imported SVG textures are not
  used for level art: they blur when zoomed. A reusable terrain component
  bakes one curve into both the drawing and the collision shape from the same
  points, so an author draws one curve per terrain piece. The bake interval is
  fixed at load, fine enough for the closest zoom the camera reaches.
- **Slimes against terrain (D97):** the slime simulation (our own code, not
  Godot's physics) tests ring points against the baked terrain itself. At
  level load the baked terrain polygons become segment arrays with outward
  normals and a static grid of cells; each ring point is pushed out of the
  nearest segment. Godot's collision shapes are not used for slimes. This
  code is part of the tick, and would move to native code with it if the
  contingency fires (D96).
- Every interactive element (gate, basket, switch, reveal zone, split zone…)
  is a **reusable, programmed component** configured through its properties
  in the editor. There are no per-level scripts, so extra levels (possible
  paid DLC) stay content rather than code.
- The rule schema these components share (for example "basket holds 5 or
  more slimes, so gate G opens") is yet to be designed.

## Slimes (D91)

- Each slime is simulated as a ring of points joined by springs, using our own
  code rather than a physics-engine feature, and drawn with a shader that
  blends nearby shapes into smooth blobs. Fusing and splitting become
  operations on those rings. No engine provides this out of the box (see
  research). Spike 1 confirmed the approach on the desktop: stable at 200
  slimes, still and moving (D94).
- **Points per ring (D94):** 12 for size 1, 15 for size 2, 18 for size 3.
  8 looks visibly polygonal; 16 costs about 25% more for little visible gain.
- **Simulation layout (D94):** struct of arrays. Points live in packed arrays
  (position, previous position, rest offset); each slime is a range of points
  (first point, point count) plus its own packed per-slime values (size,
  species, radius, rest area…). Fusing and splitting rewrite ranges. This
  layout would let the tick move to native code without changing its interface
  (see "Simulation performance").
- **Solver (D94):** Verlet integration with position constraints (edge
  springs, area preservation, shape matching, internal damping), 2 substeps
  per 60 Hz tick. Contact pairs between slimes come from a uniform grid on
  slime centres, rebuilt once per tick. The spike's settings are a starting
  point, tuned for stability, not yet for the game's feel. The tick is
  GDScript today; it moves to native code in chunk 5N (the user's go,
  D140, D142), the GDScript tick kept as the fallback.
- **Drawing (D94):** each slime is drawn as a soft field blob into two
  SubViewports (one species per colour channel, three per viewport), one draw
  call per viewport. A full-screen composite shader thresholds the fields and
  colours each pixel by the strongest species, so same-species slimes that
  touch merge into one blob and different species stay separate. About 1 ms
  of GPU time for 200 slimes on the desktop's integrated GPU. On the
  reference phone at 2400×1080: about 5 ms with full-resolution fields and
  2.6 ms at half resolution, which looks the same and is what the game uses
  (it saves battery and heat; the frame rate isn't at stake). Where two species'
  fields are equal the colour can flicker; a tie-break is needed.
  *The rest of the drawing (chunk 22b, D142):* only the slimes near the
  view are drawn; each drawing node (the frontier view, the tap feedback
  and eyes, the edge buttons, the overlays) redraws only when what it
  shows changes; repeated shapes (the eyes, a basket's quota slots) are
  one instanced draw each. The DIRECT mode (each slime drawn on its own,
  no blend) stays for headless runs and debugging; using it in play,
  another renderer or a lower field resolution is O108.
- **Scale:** up to 200 slimes per level (D67), with many possibly on one screen.
- **Physics only near the screen** (D69):
  - Off-screen slimes follow the loop at a deterministic pace, as a place
    along the loop. When the view comes near them, they are spawned just
    outside the edge of the view, and physics takes over.
  - Slimes resting in a basket may get a simplified state.
  - Sleepers stop simulating until something touches them. Slimes
    on screen may use fewer points per ring when zoomed out, or when many
    slimes are active and the device can't keep up (crowd detail,
    proposed, D140, D141).
  - Off-screen rules (D70): free slimes follow their area's route back, fusion
    and waking happen only on screen, and baskets count weight off screen.

## Simulation performance (D94, D96)

- **The simulation tick is the bottleneck on busy scenes** (on light
  scenes, before chunk 22b, drawing cost more of the frame than the tick;
  D142). On the desktop, the
  GDScript tick takes about 11 ms for 200 slimes at 16 points per ring (about
  8–9 ms at 12), with no game logic around it; contacts between slimes are more
  than half of it. A line-for-line C++ port of the same tick is 20–25× faster
  (about 0.35–0.5 ms).
- **Measured on the reference phone (D96)**, Galaxy S20 FE 5G, 200 slimes,
  pure GDScript, Compatibility:
  - at 12 points per ring, about 17–18 ms per tick cold (48–53 fps with
    nothing else in the frame); only 8 points reaches 60 fps, leaving about
    3 ms for the rest of the game;
  - after about 4 minutes of load the phone throttles (big cores capped at
    1.75 GHz) and the 12-point tick settles at about 27 ms (33 fps), steady;
  - the phone is 2.0–2.1× slower than the desktop cold, 3.4× throttled;
  - the game's real tick (chunk 5: terrain contact, friction, touch
    tracking) costs 1.7× the spike's: about 31 ms cold, 50 ms throttled;
  - the slimes' blend is not the problem on the GPU (see "Slimes": at most
    5 ms of GPU time, alongside the CPU); the rest of the drawing's CPU
    cost was, until chunk 22b (D142).
- **The tick stayed in GDScript (D96)**, on chunk 5's struct-of-arrays layout,
  whose interface is ready for native code; it moves to native code in
  chunk 5N (D140, D142).
- **Fallbacks first,** built in chunk 15 (cheaper states):
  - resting slimes (a pile) stop being simulated, contact solving included,
    until something disturbs them;
  - sleepers don't simulate;
  - fewer points per ring when zoomed out, or in a crowd (D140);
  - slimes in a full basket are simplified.
  - As built (chunk 15; values in `tuning.md`): slimes beyond a margin
    around the view are parked (not simulated, not even as walls). A pile
    rests only when it is made of slimes in a basket or asleep at bedtime
    (awake slimes hop); a resting slime is a wall to the others, and the
    whole touching pile wakes together when disturbed. Slimes in a full basket
    rest as a pile rather than getting a state of their own. Measured on the
    desktop (headless): a full basket of 60 with 20 train slimes beside it,
    3.8 ms per tick with resting off, 0.97 ms with it on (0.81 ms zoomed
    out); the test level with 110 slimes and the camera at the start,
    2.6 ms per tick with every slime simulated, 1.9 ms with off-screen
    parking (86 parked). A big pile of base slimes in the open rests slowly;
    the rule is kept for v1 and looked at again in chunk 22 (D107);
    measured there, revisiting it is O105 (D138).
- **Crowd detail (proposed, D140; the user's idea):** on a screen full of
  slimes the chaos hides rounder shapes, so rings take fewer points as the
  crowd grows. Detail levels 0 (full) to 3 (for size 1: 12, 10, 8 and 6
  points; values in `tuning.md`). The crowd is the ACTIVE non-sleeper
  slimes after the parking: level 1 from 20, 2 from 30, 3 from 40, down
  only 5 below each step. The level used is the higher of the zoom's and
  the crowd's (zoomed out gives at least level 2). Only ACTIVE rings are
  reshaped, so a resting pile is never woken by it; pile slimes stop at
  level 2. The count comes from the simulation's state, never from time,
  so runs repeat. Saves store each body's `detail` and the off-screen
  `crowd_level` (an old `low: true` loads as level 2). Measured on a
  slowed desktop CPU standing in for the phone: `s3-basket-59of60`
  16.4 -> 18.0 fps (tick 21 -> 17.7 ms), `stress-moving` 11.4 -> 12.3 fps
  (33 -> 30 ms); about 4 to 5 ms of each tick doesn't depend on points,
  and the rest of the frame is about 21 ms either way (overstated by that
  run's method, D142). Helpful, not enough on its own.
- **Crowd detail only when the device can't keep up (proposed, D141; the
  user's amendment, chunk 22c):** a good device keeps full ring points
  whatever the crowd. A load meter in the scene layer (every build; not
  the debug-only perf log) judges each window of about 1 s: **pressed**
  (busy share above 85 %, or 3 or more frames that ran 2 ticks), **calm**
  (below 60 % and at most 1 such frame), or in the band. It moves a
  **detail ceiling**, 0 to 3: up one step per pressed window, down one
  step after 3 calm windows in a row, held in the band; it starts at 0.
  An ACTIVE ring takes max(zoom's, min(crowd level, ceiling)), then the
  pile cap. The busy share is the frame's work (the ticks plus the rest of
  `_process`) over the window's real time, so it reads the same at 60 or
  120 Hz. The ceiling is an input handed over at a tick boundary, like the
  tilt; `src/sim/` never reads a clock. Modes, `--crowd-detail=auto|always|off`
  (debug builds; release is `auto`): `auto` in normal play; `always` (the
  ceiling at 3, D140's behaviour) is the simulation's default, so test
  mode, fixtures, scripts, the bench and the tests keep their hashes;
  `off` (the ceiling at 0). No new save key: the ceiling isn't saved.
- **The realistic worst case in play is a mostly still pile** (level rule
  16): a full basket plus the train, not 200 moving slimes. The
  `stress-moving` fixture stays as a measurement, not a target. *Under
  question (D140, O105, O106):* open piles rest slowly or never, and a
  fired basket's releases keep its pile awake. *Proposed (D143):* level
  rule 23 keeps levels free of spots where many slimes gather awake, and
  the train holds before a crowd or a jam, holding slimes resting, with a
  local wake (chunk 22e, before 5N, D146; rule 23 in chunk 24, item 24.7;
  D145, proposed); chunk 22f, before 5N, reworks the hold (the hop
  corridor, the holder rule, no hop through a crowd, the hold guard, rest
  by contact and on the ground; D147, proposed), and 5N ports its rest
  rules; a
  cluster the player builds stays possible, covered by crowd detail and
  the tick cap.
- **Native code was the documented, verified contingency; it is now
  adopted as chunk 5N, after chunks 22d and 22e** (D140, D143, D146; the user's explicit
  go after chunk 22b, D142: "ok schedule work on 5N after this chunk").
  A GDExtension in C++ (godot-cpp), built with `-ffp-contract=off` so ticks
  repeat from one build to another, for the Linux desktop and, through the
  Android NDK, for Android arm64. Its toolchain and a trivial extension are
  checked in under `native/` (see `docs/dev/native.md`), kept out of the
  test suite and the exports. Estimated on the reference phone: about
  0.8–1.0 ms per tick cold, 1.2–1.6 ms throttled.
- **What fired it** (it did: D138): chunk 22 measures the real game at the endgame
  (the bowl, a full basket, the train) on both phones, cold and after
  5 minutes. If either phone misses its target (60 fps on the reference
  phone in normal play; at least 30 fps on the floor phone with the largest
  realistic pile), chunk 5N moves the tick (ring solver, contacts, terrain
  contact) to native code behind the same GDScript interface, and chunk 22
  is repeated.
- **Chunk 22 as built (D138):** the cheap fixes are done, each with the
  same state hash (the fusion nudge, door passes, the pair loop, off
  screen, the centre cache, drawing culled to near-view). Desktop tick:
  `stress-moving` 27.6 -> 10.35 ms, `s3-basket-59of60` 9.5 -> about 7.9.
  **The reference phone misses DoD 30** on the evidence of 2026-09-30
  (a hand-played session, before the last fixes), and the section 3
  endgame is bound by the tick: estimated 15 to 17 ms cold, 24 to 27 ms
  throttled on the phone. **Chunk 5N is recommended** (not started);
  chunk 22 repeats after it.
- **Chunk 22b as built (D142): the drawing pass.** Redraw only on
  change, only the seen slimes rebuilt, instanced eyes and basket slots
  (see "Slimes", Drawing); draw calls on `s3-basket-59of60` 482 -> 84; the
  same hashes; the baskets' outline feathers differ by at most 1 of 255,
  accepted as invisible (approved, D144). Drawing a 60 fps frame now costs 1.2
  to 1.6 ms on the desktop; estimated on the reference phone, 2.6 to
  3.3 ms cold (within the 4 ms budget on all four measured scenes) and
  4.2 to 5.3 ms throttled (over it); only chunk 22's repeat on the phone
  closes it. The phone's GPU time can't be read with this renderer on
  Android (O14).
- **How performance is measured (D142, approved, D144).** The slowed desktop
  CPU is `tools/perf_slow.sh --pin=main`: only the main thread pinned to
  a core with busy loops. Pinning the whole process (chunk 22's and
  D140's runs) also put the engine's and the GL driver's helper threads
  on the game's core and inflated the rest of the frame (the "about
  21 ms" was 16.7 with the main thread alone pinned) and skewed the
  tick; `--pin=process` is kept only to compare with those numbers. A
  phone estimate is a part's full-speed desktop cost × 2.1 cold, × 3.4
  throttled (the GDScript tick's factors; the engine's C++ and the phone
  driver may scale otherwise). The phone's perf log settles every number
  (D138).
- **Chunk 22e as built (4750f12; D146's as-built note):** the local wake
  and the hold, with D145's numbers (the first calibration kept them).
  Basket 3's drain no longer wakes its pile whole (0 whole-pile wakes
  against 6; Physics during the drain 84 -> 48); Physics on the desktop
  `s3-basket-59of60` 79.9 -> 51.2, `stress-moving` 134 -> 123; tick
  7.27 -> 6.68 ms and 9.68 -> 10.17 ms (the hold's checks cost about
  0.8 ms a tick in that crowd). The short-hop share didn't drop (95 %,
  77 %): chunk 22f reworks the hold (D147). Estimated on the reference
  phone, the simulation still misses its 8 ms on both bowl fixtures
  (about 21 and 14 ms cold). As built, the rest pass rewrites the still
  count and the rest anchor of every active slime that may not rest,
  each tick: a cost for 22c to watch, and 5N ports it.
- **Next (proposed order, D140, D143, D142, D146, D147, D148):** chunks
  22d (the debug counters, D143) and 22e are done; then 19w, 22f, then
  chunk 5N: results deterministic within one build
  (not bit-equal to the GDScript tick); saves load under either tick; the
  GDScript tick stays as a fallback. Then chunk 22c, crowd detail only
  under load (D141). Then chunk 22 repeated on the reference phone with
  the perf log, in `auto`.
- **The cap on ticks per frame: 2 at 1x** (proposed, D138; was 8): an
  overloaded scene plays in slow motion instead of collapsing into the
  catch-up spiral; the cap scales with the debug speed.
- **A frame budget on the reference phone** (proposed, D138), so that
  meeting DoD 30 now leaves room for v2's music and animated objects: per
  16.7 ms frame, the simulation at most 8 ms, drawing at most 4 ms, and at
  least 4.7 ms left. On the desktop, the simulation's share is a tick of
  at most about 3.8 ms (phone cold) or 2.4 ms (throttled).
- **Pending:** the floor phone, once it is bought (O14). The floor decision
  rests on its measurement (D71). The 200-slime cap stays (D67).
- Not covered by the spike: game logic, the camera and the UI, which share
  the same frame budget (chunk 22 measures the whole game).

## Target phones (D71)

- Reference: Samsung Galaxy S20 FE. Floor: a budget phone (Galaxy A14 class).
  If the floor can't hold 200 slimes, the floor rises and the cap stays.
- **Performance targets (D82, D96):** 60 fps on the reference phone in normal
  play; at least 30 fps on the floor phone with the level's largest
  realistic pile on one screen (a full basket plus the train, mostly still).
- **Landscape, locked** (D78).

## Test environments (D91)

| Environment | Good for | Not good for |
|---|---|---|
| Linux desktop build | gameplay, level logic, saves, automated end-to-end tests; fastest to iterate | anything Android-specific |
| Android emulator | the Android lifecycle (background, phone-call interruptions), screen pinning, the parent-gate flow, save and restore, rough tilt through virtual sensors | **performance** (it runs on the PC's processor and graphics), audio latency, how touch and tilt feel |
| Real phones (S20 FE, a floor phone) | performance (O14), audio latency, touch and tilt feel, playtests with children | fast iteration |
| Google Play pre-launch report (later) | automatic smoke tests on a range of real phones when uploading to a test track | detailed performance work |
  - Chunk 22 tests the realistic worst case on the floor phone: the largest
    pile on one screen (D96).
  - **Phone sessions capture numbers through logs** (the user's rule,
    2026-09-30; proposed, D138): the perf log (`--perf-log`, debug builds),
    logcat and `tools/android/perf.sh`; screenshots only for visual bugs.

## Saving (D7, D12, D43)

- One save file per level. The user can delete one level's save (D43).
- Released levels aren't meant to change. If one does, the update must be
  minor and ship with its migration. Saves are never wiped, and displaced
  slimes count as lost and reappear at the start of the loop (D72).
- The save records the level's version, and slimes, objects and
  gates keep stable IDs across versions.
- **What a train slime's record adds** (chunk 22e, D145, D146; the key
  approved by the user): `save["slimes"][i]["train"]["hold"]`, an
  integer, the tick the slime's hold began, written only while it holds
  (absent: it doesn't hold). Additive, format 1: an older save loads with
  no hold. A value that isn't a whole number >= 0 makes the save invalid.
  The full key list is `docs/dev/README.md`, "What a save holds".
- Saves are written atomically (write a new file, then swap it in),
  and the previous save is kept as one backup. A save that can't be read falls
  back to the backup, and only then to a fresh start for that level.
- **The save format before the first store release** (D149; the user's:
  "save format may break between version ... if the app has been shipped,
  otherwise, we just wipe"). Until the app has shipped, a save-format
  change may break older saves: no migration, no special approval. From
  the first store release on, the format is a hard contract and every
  change ships with its migration. *(Proposed:)* a breaking change bumps
  the format number; before shipping, a save a build refuses (another
  format, or any other reason `SaveData` gives) is set aside with its
  backup as `.unreadable`, the level starts fresh with autosave on, and
  one log line says so. After shipping, such a save is left untouched and
  that level's writes are blocked, as today. Whether the app has shipped
  is one switch in the code, turned on at the first store release. An
  older level version is still migrated (above). Fixture and test-mode
  script formats are unchanged (still hard contracts); a breaking save
  change also has to convert the fixtures, which are saves.

## Testability (D76, D91)

- **Seeded randomness:** all gameplay randomness (hop timing, unsure hops)
  comes from one random generator with a seed, so a test run can be repeated
  exactly.
- **Repeatable runs:** state hashes are compared between runs of the same
  build. If the native contingency is ever adopted (D96), a native build
  won't match the GDScript version bit for bit, nor Linux match Android, so
  tests compare runs within one build.
- **Test mode** (Linux build and debug Android builds only, never in the
  release build): load a named fixture save, speed up or skip time (session
  timer, cooldown, phase timers), and inject taps and tilt from a script.
  End-to-end tests drive the test level (`levels/test/`) this way.
- Fixture saves for the test level are listed in `levels/test/README.md`.
- **Save wipe** *(D148, chunk 19w, approved in direction, D149; its
  details proposed; the user: "the flag is only for automated testing")*:
  in a debug build only, the launch flag `--wipe-save` deletes every file
  in `user://saves/` at startup, before any save is read;
  `user://parent.json` is kept. **For automated test runs only**
  (`perf.sh --wipe-save`, a scripted desktop launch); in manual play, a
  level is started over with the parent's delete of its save. A
  per-launch flag, nothing that stays set. Ignored with a log line in a
  release build, refused with a save to load (`--load`), never on by
  default, never passed by save and restore tests. It is not a save store
  path and no update path: saves are still never wiped in a player's
  build. The format rule is above (D149).

## Camera (D33, D60)

- The camera runs on rails along the loop, return routes included (D79).
  Framing zones are ignored while the idle camera or screensaver mode follows
  a slime (D80). Zoom and framing are computed from
  the camera's position and the mode (screensaver mode is about 10–20% wider).
- Framing zones are a reusable level component with properties for
  zoom, position and the delay before the camera leaves (D61). They are authored like
  any other component, with no per-level scripts (D6).

## Slime navigation

- A heading-back slime follows the route back that is built into every
  exploration branch as part of the level (D41, D51). That route is authored
  level data, like the loop, so there is no general pathfinding. It is
  drawn as a path in the Godot editor.

## Session lock (D1)

- `startLockTask()` screen pinning through a small Godot Android plugin, plus
  an in-app parent gate and a timer stored on disk (wall clock plus the
  monotonic clock). There is no device-owner kiosk mode.
- **Pinning is requested each time the app opens** (D85): at each launch,
  right after setup on the first one, and not on coming back from the
  background; "leave" closes the app (D102). Android's
  confirmation can't be skipped. Setup recommends Android's "Ask for PIN
  before unpinning". If the parent declines pinning, the game still works and
  the code still guards the parent buttons (D84); the back gesture then
  leaves the app as usual (D102), except from the edge strips (D112).
- **Sticky immersive mode** (no status or navigation bar; the world draws
  edge to edge). The edge strips' and parent zone's tap zones stay on the
  screen's edges; the parent's controls (buttons, the code prompt,
  settings) stay inside the safe area (proposed, D132). It lets the app
  exclude **the whole edge strips** from Android's back gesture (D112):
  `setSystemGestureExclusionRects` on the game's view, through the Android
  plugin. Built in chunk 20: the usual 200 dp cap doesn't apply while the
  bars are hidden (D132).
- The wrong-try count and the end of the 30 s wait are stored on disk, so
  they survive the prompt closing and the app being killed (D102).
- Parent-facing text follows the phone's language when v1 has it, English
  otherwise; v1 ships English and French (D102).
- **The session lives in the level's save** while v1 has one level: its
  phase, elapsed time and clock anchor, so a killed app resumes where it
  was; deleting the level's save keeps the running session (D104).
- Recovering the parent code uses Android's device-credential prompt
  (BiometricPrompt, which also accepts the PIN or pattern). There is no server
  (D55).
- More broadly, the app runs **fully offline**, with no account and
  no backend. D55 settles this for the parent code; paid unlocks will go
  through Google Play only (D31). No analytics, no ads, no network
  permission in v1.
- The same stored clocks enforce the 10 min cooldown after bedtime (D29).
  Changing the device clock can defeat it, which is acceptable under D1.

## Deferred

- Sound begins at v2: music, with effects a candidate (D134, D136).
  v1 has no audio.
- Music generator (D42, O12): it is currently a JS app, and porting it to
  Godot is a project of its own.
- Paid levels (D31): Play Billing plus Play Asset Delivery, when the second
  level arrives.

- Procedural world generation: a possible later iteration (O13). Godot scenes
  can be built at runtime, so D6 doesn't rule it out.
