# Technical direction

Status: draft v18

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
  GDScript; native code is the contingency (D96).
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
- **Scale:** up to 200 slimes per level (D67), with many possibly on one screen.
- **Physics only near the screen** (D69):
  - Off-screen slimes follow the loop at a deterministic pace, as a place
    along the loop. When the view comes near them, they are spawned just
    outside the edge of the view, and physics takes over.
  - Slimes resting in a basket may get a simplified state.
  - Sleepers stop simulating until something touches them. Slimes
    on screen may use fewer points per ring when zoomed out.
  - Off-screen rules (D70): free slimes follow their area's route back, fusion
    and waking happen only on screen, and baskets count weight off screen.

## Simulation performance (D94, D96)

- **The simulation tick is the bottleneck, not drawing.** On the desktop, the
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
  - drawing is not the problem (see "Slimes": at most 5 ms of GPU time,
    alongside the CPU).
- **The tick stays in GDScript (D96)**, on chunk 5's struct-of-arrays layout,
  whose interface is ready for native code.
- **Fallbacks first,** built in chunk 15 (cheaper states):
  - resting slimes (a pile) stop being simulated, contact solving included,
    until something disturbs them;
  - sleepers don't simulate;
  - fewer points per ring when zoomed out;
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
    the rule is kept for v1 and looked at again in chunk 22 (D107).
- **The realistic worst case in play is a mostly still pile** (level rule
  16): a full basket plus the train, not 200 moving slimes. The
  `stress-moving` fixture stays as a measurement, not a target.
- **Native code is the documented, verified contingency, not fired.** A
  GDExtension in C++ (godot-cpp), built with `-ffp-contract=off` so ticks
  repeat from one build to another, for the Linux desktop and, through the
  Android NDK, for Android arm64. Its toolchain and a trivial extension are
  checked in under `native/` (see `docs/dev/native.md`), kept out of the
  test suite and the exports. Estimated on the reference phone: about
  0.8–1.0 ms per tick cold, 1.2–1.6 ms throttled.
- **What would fire it:** chunk 22 measures the real game at the endgame
  (the bowl, a full basket, the train) on both phones, cold and after
  5 minutes. If either phone misses its target (60 fps on the reference
  phone in normal play; at least 30 fps on the floor phone with the largest
  realistic pile), chunk 5N moves the tick (ring solver, contacts, terrain
  contact) to native code behind the same GDScript interface, and chunk 22
  is repeated.
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

## Saving (D7, D12, D43)

- One save file per level. The user can delete one level's save (D43).
- Released levels aren't meant to change. If one does, the update must be
  minor and ship with its migration. Saves are never wiped, and displaced
  slimes count as lost and reappear at the start of the loop (D72).
- The save records the level's version, and slimes, objects and
  gates keep stable IDs across versions.
- Saves are written atomically (write a new file, then swap it in),
  and the previous save is kept as one backup. A save that can't be read falls
  back to the backup, and only then to a fresh start for that level.

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

- Music comes in v2; the rest of sound around v3 for now (D50, D134, O102).
  v1 has no audio.
- Music generator (D42, O12): it is currently a JS app, and porting it to
  Godot is a project of its own.
- Paid levels (D31): Play Billing plus Play Asset Delivery, when the second
  level arrives.

- Procedural world generation: a possible later iteration (O13). Godot scenes
  can be built at runtime, so D6 doesn't rule it out.
