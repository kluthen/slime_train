# Independent performance review, 2026-09-30

A read-only review by a principal-advisor agent, requested by the user after
the S20 FE session of the same day ([session report](2026-09-30-s20fe-session.md)).
It could read the code and search the web, but not edit or run anything.
The file:line references point to the working tree of 2026-09-30, which
includes the chunk 22 work in progress.
The figures are the reviewer's own estimates; nothing here has been measured
yet. Section 4 lists the measurements that would confirm them.

## Short answer

The phone is not underperforming. The GDScript soft-body tick costs 10–40 ms
per tick in crowded scenes, and the fixed-step loop multiplies that cost by up
to 8 ticks per frame. The chunk 1 spike never measured that regime: it ran one
tick per frame. Rendering is a secondary cost.

The native tick (chunk 5N) is needed. Before it, cap the ticks per frame and
fix two causes specific to certain scenes. Both are cheap.

## 1. Diagnosis

**A. The fixed step amplifies the tick cost; it doesn't absorb it.**
`src/main.gd:65` sets `MAX_TICKS_PER_FRAME := 8`. Together with
`main.gd:225-227` and `src/sim/fixed_step.gd:18-26`, the game runs 60 ticks
per second of real time whatever the frame rate.

- Call the drawing cost D and the tick cost T. In steady state a frame takes
  F = D / (1 − 60T).
- Once T ≥ 16.7 ms, the loop runs into the cap and a frame takes F = D + 8T.
  At T ≈ 30 ms that is about 250 ms, or 3–4 fps.
- At T ≈ 10 ms, frames take about 2.5 times as long, which gives the
  13–20 fps readings.
- The two bands seen on the phone, 13–20 fps and 3–4 fps, are these two
  regimes.

**B. The solver dominates whenever many bodies are active.**

- On the desktop, `tools/bench_slimes.gd` measures 200 mixed slimes at
  14.7 ms per tick, and the level bench's `stress-moving` about 15 ms per
  tick.
- The spike found the phone 2.0–2.1 times slower than the desktop when cold,
  and about 3.4 times slower when throttled. So on the phone, 200 active
  slimes would cost about 31 ms per tick cold and about 50 ms throttled.
- 100 active slimes cost about 15–25 ms per tick. That is the awake pile at
  the loop start (3 fps). The pile can never rest: only slimes in a basket
  or asleep at bedtime may rest (`slime_bodies.gd:933-934`).
- The hot spot is `_solve_contacts` (`slime_bodies.gd:1313-1402`): for each
  pair, each side, each point, one `atan2` and two `length()` calls.

**C. "5 simulated" in the celebration scene hides an active pile (hypothesis).**
The overlay's "simulated" count only covers unparked slimes outside the view
(`debug_counts.gd:26-37`). It never shows whether a slime is active or at
rest.

- A fired basket releases one slime every 0.3 s, that is every 18 ticks
  (`frontier_sets.gd:90`, `404-409`).
- Each release calls `set_body`, then `set_state`
  (`frontier_sets.gd:497-498`), and both wake the whole resting pile
  (`slime_bodies.gd:451-452`, `678-679`, `944-954`).
- A pile needs `REST_TICKS` = 30 still ticks before it rests again
  (`slime_bodies.gd:114`). With a release every 18 ticks, the pile of about
  60 slimes stays active for the whole emptying.
- The dense pile plus the celebration hops put the game in regime A: 4 fps.
- An active count would confirm or refute this (section 4).

**D. Some per-tick work covers all 200 bodies, even parked ones.**

- `centre_of()` is a binary search plus a loop over the ring's points. It
  runs about 6 times per slime per tick: `offscreen.gd:183-193` and
  `411-414`, `train.gd:486-493` (plus a `project()` walk and Dictionary
  records), `frontier_sets.gd:348-357` and `368-379`, `fusion.gd:287-291`.
- The level bench's `start` case costs about 1 ms per tick on the desktop
  with 196 parked, so about 2 ms on the phone: roughly 12% of a frame at
  60 fps. This is the floor that remains after 5N.

**E. Drawing each frame costs little, but nothing is culled.**

- `slime_renderer.gd:201-225` rebuilds the vertices of all 200 slimes,
  parked ones included. The spike measured this at about 0.9 ms on the
  phone.
- `tap_feedback.gd:61-66` draws 200 eye dots, each through `centre_of`.
- `debug_overlay.gd:142` runs `DebugCounts.count()` every frame (string
  parsing per slime, not throttled).
- `frontier_view.gd:107` runs `loop.closest` per switch, per frame.
- `debug_slime_labels.gd:45-57` draws 4 strings for each of the 200 slimes,
  with no culling to the view. That is the 47 → 13 fps, amplified by A.
- The GPU is not the problem: the spike measured the blend at about
  2.6 ms of GPU time and held 60 fps on drawing alone.

**Why the spike looked fast.**

- It ran one tick per frame with vsync off (`spike.gd:76-78`), so its
  48–53 fps were 48–53 ticks per second at 16.7–18.5 ms per tick.
- It already missed 60 fps. Its own verdict was that pure GDScript can't
  hold 200 slimes.
- The game's solver is about 1.7 times heavier than the spike's (terrain,
  friction, touch tracking).
- The game adds logic over all bodies and the extra drawing listed in E.
- When a frame is late, the game runs up to 8 ticks in it; the spike
  would simply have ticked less often.

## 2. Ranked fixes

**Architecture changes**

1. **Native `SlimeBodies.tick` (chunk 5N).**
   - The spike measured native code 20–25 times faster. That puts 200
     moving slimes at about 1–1.6 ms per tick on the phone.
   - It removes B and C at their root, and it is the only fix that meets
     the floor phone.
   - Port integration, pairs, contacts, rings, terrain and rest behind the
     existing interface (D94 designed it for this).
   - Same seed still gives the same result within one build, if compiled
     with `-ffp-contract=off` and without fast-math.
   - The results won't match today's GDScript bit for bit: GDScript locals
     are doubles, while the packed arrays store 32-bit floats. Regenerate
     the fixtures rather than chase parity.
   - Effort: medium to large (large if today's hashes must match).
2. **Cap the ticks per frame at 2 at 1× speed**, keeping the scaling at
   higher debug speeds.
   - When overloaded, the game slows down instead of collapsing: about
     13 fps instead of 4 at T = 30 ms. Light scenes don't change.
   - What a tick does is unchanged, so determinism and test mode's
     `run_ticks` are unaffected. Session timing uses real clocks and stays
     correct.
   - Effort: quick. Do it first.
3. **A lower tick rate with interpolation.** Only if 5N is refused. It
   changes the step size and every tuning counted in ticks, and the spike
   flagged stability risks. Effort: large.
4. **Skip MultiMesh and single-mesh rewrites.** Each field viewport is
   already a single draw call. Moving the ring outline maths into a vertex
   shader or native code saves about 1 ms. Effort: short.

**GDScript fixes** (all keep same-seed determinism; some may change the
hashes, so regenerate the fixtures)

5. **Stop basket releases from keeping the pile awake.** Release from the
   top of the pile, or in one burst, or let the pile rest again faster than
   one release interval. This touches the spec ("lowest id first") and
   D107; the basket release is already in the round-2 playtest issues.
   The celebration would move from 4 fps to about section 3's level.
   Effort: short.
6. **Compute each slime's centre once per tick** into one cached array, and
   keep the train's records in packed arrays instead of Dictionaries. This
   replaces the ~6 `centre_of` passes per slime (D) and roughly halves the
   ~2 ms floor. Effort: short to medium.
7. **Cull the drawing each frame** to unparked or on-screen slimes
   (renderer, eyes, labels), throttle `DebugCounts.count()`, and cache
   `_way()`. About 1–2 ms per frame, and honest debug measurements.
   Effort: quick.
8. **Micro-optimising the GDScript solver** (atan2 and square roots in the
   contacts) gains 1.2–1.5 times at most. Not worth it if 5N is coming.

## 3. Verdict on 5N

**Needed, and not premature.** In normal play, 60–110 bodies are active on
screen: the section 3 bowl at zoom 0.5, a basket emptying, a jam on the
train. In GDScript that costs 10–25 ms per tick on a cold phone, and up to
1.6 times more when throttled. No rendering or algorithm fix gains the 3–5
times needed for 60 fps.

Order:

1. Fix 2 and the measurement work (section 4), in days.
2. Then 5N.
3. Fixes 5 and 7 can run in parallel.
4. After 5N, fix 6 becomes the next bottleneck.

## 4. How to measure

1. **Turn the labels off in every run.** Treat debug-APK numbers as
   relative only. Take acceptance numbers from a release-template export,
   because debug builds do more runtime checks. Log the thermal state, and
   measure both cold and after 5 min (the spike saw a 1.75 GHz cap after
   about 4.5 min).
2. **Extend the PERF line** (`src/debug/perf_log.gd`) with:
   - the ticks per frame;
   - ms per tick timed around `step_simulation()`, versus the rest of the
     frame;
   - an active count (calm and active, not asleep) and the pair count;
   - timers per phase inside `Simulation.step`: offscreen, train,
     `bodies.tick`, fusion, frontier, camera.
3. **Confirm A:** in a debug build, set `MAX_TICKS_PER_FRAME = 1`. Heavy
   scenes should jump to about 1 / (D + T).
4. **Confirm C:** during the celebration the active count should be about 60
   or more, and it should drop if the releases are paused.
5. **Desktop:** add `bench_level` cases for the celebration while releasing
   and for the awake start pile. Multiply the ms per tick by about 2.1 for a
   cold phone and about 3.4 for a throttled one. Use Godot's profiler (in
   the editor, or remote debug on the phone) for script time per function.
6. **GPU:** the Compatibility renderer has no GPU timer on the Adreno 650.
   Use Android GPU Inspector or Snapdragon Profiler, or freeze the
   simulation and read the fps.
7. **At a fresh start**, compare the frame p50 and p95 with
   `process_ms_mean`. If frames alternate between 16.7 and 33 ms, the
   47 fps is vsync beating a frame just over budget, not a 21 ms cost.

Optional: let the overlay show the active count, so a scene's real solver
load is visible on screen.

## 5. Sources

- [Fix Your Timestep! (Gaffer On Games)](https://gafferongames.com/post/fix_your_timestep/): the accumulator, the spiral of death, interpolation.
- [Taming Time in Game Engines (André Leite)](https://andreleite.com/posts/2025/game-loop/fixed-timestep-game-loop/): clamping the accumulator.
- [Godot docs: CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html) and [The Profiler](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html).
- [How to Profile GDScript Performance in Godot 4 (dev.to)](https://dev.to/ziva/how-to-profile-gdscript-performance-in-godot-4-a-2026-guide-16jn): profile exported builds; debug builds do extra checks.
- [godot-proposals #1071](https://github.com/godotengine/godot-proposals/issues/1071): release versus debug template behaviour.
- In the repo: `docs/dev/spike-soft-slimes.md` (phone matrix, soak, native estimate) and `docs/dev/README.md` (bench tables near lines 831 and 2542).
