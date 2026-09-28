# Spike: soft slimes at scale (chunk 1)

Throwaway spike, `spikes/soft-slimes/`. It checks whether the slime approach
in `specs/tech-direction.md` "Slimes" (D91) holds at the cap: a ring of
points joined by springs, in our own code, drawn with a shader that blends
nearby shapes into smooth blobs, with 200 slimes on one screen (D67). The
targets it measures against are in master-spec.md §7: **60 fps on the
reference phone, at least 30 fps on the floor phone with 200 slimes on one
screen.**

The desktop and the reference phone (Galaxy S20 FE 5G) have been measured;
see "Reference phone (Galaxy S20 FE 5G)". The floor phone (Galaxy A14 class,
not bought yet) is still to do (see "Retest on the phones").

## Approach

### Simulation (`slime_sim.gd`)

- **One ring per slime.** Size 1 has N points (the `--points` setting), size
  2 has N × 1.25 and size 3 has N × 1.5. The visible radius grows with the
  square root of the size (the area is proportional to it): 18, 25 and 31
  logical pixels. Sizes are spawned 60% / 25% / 15%.
- **Solver: Verlet integration plus position-based constraints**, 2
  substeps × 1 iteration per 60 Hz tick. The constraints on each ring:
  - edge springs, stiffness 0.8;
  - area preservation (the "pressure"), 0.6;
  - shape matching towards the rest circle, rotated to follow the ring,
    0.3, which keeps it round without making it rigid;
  - internal damping towards the slime's mean velocity, 0.1.
- **World:** gravity 1400 px/s², a floor with friction 0.4, walls, global
  damping 0.996, and speed capped at 1200 px/s.
- **Contacts between slimes:** a uniform grid on slime centres (80 px cells,
  counting sort) builds a list of candidate pairs once per tick. For each
  pair, the points of ring A that face B are tested against B's radial
  profile (the ring's radius at that angle). A point that is inside moves
  out by half the overlap, and ring B as a whole moves back by the same
  amount, so momentum is kept and B doesn't dent. Denting both rings
  exploded at this step size; the rigid reaction settles.
- **Hops:** each slime hops every 1.5–3 s (a bit slower for bigger sizes),
  upwards at 520–680 px/s with up to ±160 px/s sideways.
- **Data layout: struct of arrays.** Per-point `PackedVector2Array`s (`pos`,
  `prev`, `rest_off`) and per-slime packed arrays (`first`, `npts`, `size`,
  `species`, `ring_radius`, `rest_area`, …), so the inner loops don't touch
  objects or dictionaries.

With 200 slimes the still mode settles into a resting pile (mean speed
0.01–0.04 px per tick, ring areas within about 3% of rest), and the moving
mode stays stable with every slime hopping.

### Drawing: the blend (`field.gdshader`, `blend.gdshader`)

- Each slime is drawn as a soft "field" blob: a triangle fan over its ring,
  plus a thin outer skirt where the field fades to zero.
- The fields go into **two SubViewports**, one per group of three species,
  one species per colour channel, added together (`blend_add`). All the
  slimes of a viewport are **one draw call**
  (`canvas_item_add_triangle_array`) with static indices and colours: each
  frame only the vertex positions change.
- **A full-screen composite shader** reads both fields, thresholds them
  (a metaball-style blend), colours each pixel with the species whose field
  is strongest, and darkens a thin rim and the seam between two species.
  **Same-species slimes that touch merge into one blob; different species
  stay visibly separate.**
- The fields can be rendered at a fraction of the screen resolution
  (`--field-scale`); at 0.5 the look is essentially the same.
- **Fallback, measured:** `--draw=direct` draws the same meshes straight
  onto the screen with a soft edge (`direct.gdshader`), without blending.
  It saves about half the GPU time of the blend, but the blend is cheap
  enough that the fallback isn't needed.

Six flat placeholder colours, one per species: `#f4d63b`, `#8fd95a`,
`#4fc6de`, `#f28a3a`, `#d4549c`, `#5a47b3`.

### Measuring (`spike.gd`)

- **Lockstep:** one simulation tick per rendered frame, with vsync off and
  no frame cap, so the fps reflects the true cost of one tick plus one
  frame. At 60 fps that would be 60 ticks per second, the game's rate.
- After a warm-up, the spike averages over the measurement window and
  prints one `RESULT` line:
  - the fps and frame time;
  - the sim time per tick;
  - the time to build the draw data;
  - the render CPU and GPU time
    (`RenderingServer.viewport_get_measured_render_time_gpu`, which works on
    Compatibility too);
  - the number of point-vs-ring contact tests.
- **Native estimate (`native_estimate.cpp`):** a line-for-line C++ port of
  the same tick, with the same setup, to see what native code would cost.
  Its pile matches the GDScript one (pile top 414 vs 413 px, the same mean
  speed).

## Running it

```sh
# Interactive: Space toggles still/moving, D toggles blend/direct, P cycles 8/12/16 points
godot --path . spikes/soft-slimes/spike.tscn

# One measured run that exits on its own
godot --path . --rendering-method gl_compatibility --resolution 1920x1080 \
  spikes/soft-slimes/spike.tscn -- --bench --mode=moving --points=12 --draw=blend

# The whole matrix (2 renderers x 2 modes x 3 point counts x 3 draw variants, ~7 min)
spikes/soft-slimes/run_bench.sh

# The same matrix for one renderer in a single process (what the phone runs)
godot --path . spikes/soft-slimes/spike.tscn -- --matrix [--soak=600] [--draw-only]

# Native estimate
g++ -O2 -std=c++17 -o /tmp/native_estimate spikes/soft-slimes/native_estimate.cpp
/tmp/native_estimate 16 1        # points, moving (0|1)
```

Spike arguments (after `--`): `--mode=still|moving`, `--points=N`,
`--draw=blend|direct`, `--field-scale=X`, `--count=200`, `--substeps=2`,
`--iterations=1`, `--step=frame|physics`, `--warmup=S`, `--measure=S`,
`--bench` (quit after measuring), `--shot=PATH` (save a screenshot),
`--matrix` (every mode × points × draw case in turn, then the first case
again as a drift check), `--soak=S` (then a moving run of S seconds with a
`SOAK` line every 10 s) and `--draw-only` (a settled pile with the
simulation frozen, so the frame is bound by drawing). Each matrix case
starts from a fresh pile and warms up for at least 4 s and 400 ticks.

**On a phone:** export the preset "Android spike: soft slimes" (see
`docs/dev/README.md` "Android export (debug)"). With no command line, the
spike runs `--matrix --soak=600` (about 15 minutes) and quits; the results
are the `RESULT` and `SOAK` lines in `adb logcat -s godot:*`. Other options
go into the preset's `command_line/extra_args` after `--`, for example
`--rendering-method mobile -- --draw-only`.

## Desktop

| | |
|---|---|
| CPU | AMD Ryzen 5 PRO 8640HS (Zen 4, 6 cores / 12 threads), laptop |
| GPU | AMD Radeon 760M (integrated), Mesa 25.0.7: radeonsi OpenGL 4.6, RADV Vulkan 1.4.305 |
| RAM | ~11 GB usable |
| OS | Debian 13, kernel 6.12, Wayland |
| Godot | 4.7.2 |
| Window | 1920×1131 (the window manager added 51 px to the requested 1080); world 1152×648 logical |

Each run logged the 1-minute load average; the matrix ran at load < 2.3.
An earlier run with another heavy process on the machine was up to 2×
slower and was discarded.

## Numbers

200 slimes, blend draw at field scale 1.0, lockstep. Total points: 3640 at
16 points per ring, 2730 at 12, 1820 at 8. GPU time is given for the three
draw variants: blend with full-resolution fields, blend with half-resolution
fields, and direct (no blend).

| Renderer | Mode | Points | fps | frame ms | sim ms / tick | draw build ms | GPU ms: blend 1.0 / blend 0.5 / direct |
|---|---|---|---|---|---|---|---|
| Compatibility | still | 16 | 81.6 | 12.26 | 10.97 | 0.53 | 1.10 / 0.85 / 0.53 |
| Compatibility | still | 12 | 101.8 | 9.82 | 8.75 | 0.41 | 1.04 / 0.81 / 0.50 |
| Compatibility | still | 8 | 134.8 | 7.42 | 6.58 | 0.28 | 0.94 / 0.73 / 0.42 |
| Compatibility | moving | 16 | 87.2 | 11.47 | 10.26 | 0.53 | 1.10 / 0.84 / 0.55 |
| Compatibility | moving | 12 | 110.4 | 9.05 | 8.08 | 0.39 | 1.02 / 0.78 / 0.50 |
| Compatibility | moving | 8 | 141.2 | 7.08 | 6.22 | 0.28 | 0.94 / 0.71 / 0.42 |
| Mobile | still | 16 | 81.6 | 12.26 | 11.18 | 0.57 | 1.08 / 0.79 / 0.47 |
| Mobile | still | 12 | 101.7 | 9.83 | 8.91 | 0.44 | 1.00 / 0.73 / 0.44 |
| Mobile | still | 8 | 136.9 | 7.30 | 6.59 | 0.30 | 0.87 / 0.65 / 0.33 |
| Mobile | moving | 16 | 88.9 | 11.25 | 10.21 | 0.56 | 1.07 / 0.79 / 0.48 |
| Mobile | moving | 12 | 110.2 | 9.07 | 8.17 | 0.42 | 0.96 / 0.72 / 0.40 |
| Mobile | moving | 8 | 143.2 | 6.98 | 6.28 | 0.30 | 0.86 / 0.65 / 0.34 |

- Render CPU time: ~0.1 ms on Compatibility, ~0.03 ms on Mobile.
- **The fps is the same for all three draw variants** (within noise): the
  frame is bound by the simulation on the CPU, not by drawing.
- The still pile costs a little more than the moving one: every slime is in
  contact with its neighbours.

**Where the sim time goes** (GDScript, 16 points, still, per tick): contacts
~5.9 ms, rings ~2.9 ms, integration ~0.9 ms, grid ~0.5 ms, walls and floor
~0.5 ms. That's ~720 candidate pairs and ~4700 point tests per pass. At 8
points the contacts are still 3.7 ms: the pair count, not the point count,
dominates.

**Native estimate** (same algorithm in C++, `-O2`, one core):

| Points | still, ms / tick | moving, ms / tick | vs GDScript |
|---|---|---|---|
| 16 | 0.45 | 0.48 | ~21–24× faster |
| 12 | 0.35 | 0.41 | ~20–25× faster |
| 8 | 0.28 | 0.30 | ~21–24× faster |

## Go / no-go

### The approach: GO, with the simulation tick in native code

**The ring-of-springs slime plus the species-field blend shader is a GO.**
It looks right (same-species neighbours merge, the pile packs like foam),
it is stable at 200 slimes both still and moving, and the drawing is cheap:
about 1 ms of GPU time on an integrated desktop GPU, one draw call per field
viewport.

**A simulation written in pure GDScript is a NO-GO for 200 slimes on one
screen on the phones.** It already takes 6–11 ms per tick on this desktop,
with no game logic around it. The same algorithm in native code takes
0.3–0.5 ms. So the GO depends on the simulation tick being native code
(a GDExtension in C++).

That is a change of technical direction: `specs/tech-direction.md` says
"our own code" without saying the language, and the rest of the project is
GDScript. **It is reported for spec-writer to decide, not settled here.**
What it brings:

- the godot-cpp toolchain in the build;
- the Android NDK for the Android export (chunk 20);
- `-ffp-contract=off` (no fused multiply-add) so ticks give the same results
  from one build to another; the state hash is already compared on one
  platform only (see "State dump and hash" in `README.md`).

If native code is refused, the fallbacks are, from most to least effective
(each one has a cost in game design or looks):

- **sleep resting slimes** (stop simulating slimes that have been still for
  a while, as D69 already allows in a basket);
- **run the physics at 30 Hz** and interpolate the drawing;
- **reduce the points per ring**;
- **reduce the number of slimes simulated on screen**.

Even with all of them, the floor phone looks out of reach in GDScript (see
below).

### The renderer: GO for Compatibility

Forward Mobile (Vulkan) was run on the same matrix with a window: same look,
and the same fps within noise (its GPU time is 2–20% lower, but the GPU
isn't the bottleneck). Nothing here justifies switching.
**Compatibility stays**: it reaches the most Android phones, and Vulkan
drivers on cheap Mali GPUs are a known risk. This is to be confirmed on the
phones.

## What the numbers mean for the phones

These are desktop numbers, written before the phone was measured; the
measured S20 FE numbers are in "Reference phone (Galaxy S20 FE 5G)" below
and replace the S20 FE row here. They set **the CPU cost per slime**, and
that's all. How fast a phone's GPU and thermals are can only be measured on the
phone.

Rough single-core ratios against this desktop are about 2.2–2.7× slower for
the S20 FE (Snapdragon 865 or Exynos 990), and about 6× slower for an A14 4G
(Helio G80) or ~2.7× for the A14 5G (Exynos 1330). **These ratios are
estimates from memory of public benchmarks, not measured.**

| | Budget per frame | GDScript sim (8–16 points) | Native sim (16 points) |
|---|---|---|---|
| S20 FE (reference, 60 fps) | 16.7 ms | ~16–27 ms: fails at 12 and 16, borderline at 8 | ~1.3 ms |
| A14 4G (floor, 30 fps) | 33 ms | ~40–65 ms: fails | ~3 ms |

The budget also has to hold the rest of the game (logic, camera, terrain,
UI), so a simulation that takes the whole frame isn't enough. The blend's
GPU cost on phone GPUs at 2400×1080 is unknown; half-resolution fields are
the lever if it matters.

## Reference phone (Galaxy S20 FE 5G)

Measured on 2026-09-28 with a debug export of this spike (preset "Android
spike: soft slimes"), Compatibility renderer, 200 slimes, lockstep.

| | |
|---|---|
| Phone | Samsung Galaxy S20 FE 5G, SM-G781B, Android 13 |
| SoC | Snapdragon 865 (`kona`): 1× Cortex-A77 2.84 GHz, 3× A77 2.42 GHz, 4× A55 1.80 GHz |
| GPU | Adreno 650: OpenGL ES 3.2 (Compatibility), Vulkan 1.1.128 (Mobile) |
| Screen | 2400×1080 physical, 60 Hz mode (the phone's "standard" setting; 120 Hz is available) |
| As seen by the spike | window 2400×1080, viewport 2400×1080, screen scale 1.8; world **1440×648** logical |
| Conditions | on USB power (charging), room temperature, thermal status 0 (none) at the start |

The world is wider than on the desktop (1440 vs 1152 logical pixels: the
`canvas_items` stretch with `expand` keeps the 648 px height and widens to
the 20:9 screen), so the pile is lower and wider. It has ~10% fewer contact
tests than the desktop's, which slightly flatters the phone.

**Vsync can't be turned off on the phone:** `VSYNC_DISABLED` has no effect
and the frame rate stops at 60 (59.0 in the table). Below 60 the fps still
shows the real cost (the swap chain doesn't lock to 30); above it, only the
sim ms per tick does.

### Matrix (cold)

Run straight after launch; the first case, repeated at the end (4 minutes
later), gave the same result (38.5 fps, 23.31 ms), so there was no throttling
during the matrix.

| Mode | Points | fps: blend 1.0 / blend 0.5 / direct | sim ms / tick | draw build ms | render CPU ms: blend / direct | phone ÷ desktop (sim) |
|---|---|---|---|---|---|---|
| still | 16 | 38.7 / 38.9 / 39.4 | 23.2 | 1.1–1.2 | 0.65 / 0.38 | 2.11× |
| still | 12 | 47.8 / 49.1 / 50.2 | 18.1–18.5 | 0.8–0.9 | 0.64 / 0.35 | 2.08× |
| still | 8 | 59.0 / 59.0 / 59.0 (cap) | 13.6 | 0.6–0.7 | 0.60 / 0.35 | 2.06× |
| moving | 16 | 42.4 / 42.4 / 43.2 | 21.0 | 1.1–1.2 | 0.66 / 0.38 | 2.05× |
| moving | 12 | 52.7 / 52.6 / 53.9 | 16.7 | 0.9–1.0 | 0.66 / 0.36 | 2.06× |
| moving | 8 | 59.0 / 59.0 / 59.0 (cap) | 12.5 | 0.6–0.7 | 0.57 / 0.35 | 2.01× |

The sim cost doesn't depend on the draw variant; the small fps gain of
`direct` is its lower render CPU time (0.3 ms). **The phone runs the
GDScript tick 2.0–2.1× slower than the desktop**, a little better than the
2.2–2.7× estimated below.

### Throttling (soak)

A moving run at 12 points with the blend at full resolution, started right
after the matrix (so about 4 minutes of full load before it), for 10
minutes:

| Time into the soak | fps | sim ms / tick |
|---|---|---|
| 0–10 s | 51.2 | 17.2 |
| 50–60 s | 39.5 | 22.5 |
| 90–100 s | 32.9 | 27.2 |
| 100–590 s | 32.5–33.1 | 27.0–27.5 (steady) |

At about 4.5 minutes of sustained load the thermal status went from 0 to 1
("light") and the phone capped its big and prime cores at 1.75 GHz (from
2.42 and 2.84 GHz; `scaling_max_freq`). 2.84 / 1.75 = 1.62, which is the
slowdown measured (27.3 / 16.7 = 1.64). The cap then held: steady at ~27 ms
for 8 minutes, not getting worse. The temperatures stayed moderate
(processor 38–44 °C, skin 37–39 °C, battery 34–35 °C). The cap follows the
sustained load, not heat you can feel. **Throttled, the phone is ~3.4× slower
than the desktop** (27.3 vs 8.08 ms).

### Drawing cost on the phone's GPU

Compatibility (OpenGL ES) returns 0 for
`viewport_get_measured_render_time_gpu` on the Adreno 650: no GPU timer.
Two other measurements, with the simulation frozen on a settled 12-point
pile (`--draw-only`), so the frame is bound by drawing:

| Draw | Mobile (Vulkan): GPU ms | Compatibility: fps | Compatibility: GPU busy (sysfs) |
|---|---|---|---|
| blend, fields at 1.0 | **4.97** | 59.2 (cap) | ~20–24% |
| blend, fields at 0.5 | **2.63** | 59.1 (cap) | ~19% |
| direct | **1.36** | 59.1 (cap) | ~11% |

- The Vulkan timings are exact per frame. The Compatibility busy
  percentages (`/sys/class/kgsl/kgsl-3d0/gpu_busy_percentage`, sampled every
  5 s) are rough: they depend on the GPU clock the governor chose. They are
  in the same range or lower than Mobile's (~40% during its blend 1.0 case).
- Both renderers hold the 60 fps cap on drawing alone, at every variant.
- These runs came after the soak, with the CPU cap still on (so the draw
  build took ~3 ms instead of ~1 ms).
- Forward Mobile runs on this phone (Vulkan 1.1) with a lower render CPU
  time (0.14–0.24 ms vs 0.5–1.1 ms).

### Conclusion against D94

- **Pure GDScript does not hold 60 fps with 200 slimes on the reference
  phone.** At the chosen 12 points per ring (D94), the tick alone takes
  18.1 ms still and 16.7 ms moving: 48–53 fps with nothing else in the
  frame. Only 8 points reaches the 60 fps cap (12.5–13.6 ms), and that
  leaves 3 ms for everything else. After about 4.5 minutes of play the phone
  throttles, and the 12-point tick settles at ~27 ms (33 fps). 8 points
  would then take ~21 ms (~45 fps). The real tick of chunk 5 (terrain
  segments, friction, touch tracking) is also heavier than the spike's:
  14.7 ms against 8.75 ms on the desktop for the mixed-size pile
  (`tools/bench_slimes.gd`), so ~31 ms cold and ~50 ms throttled on this
  phone.
- **So the measurement triggers D94's native contingency:** D94 defers the
  choice to "the first measurement on the reference phone", and this is it.
  The same tick in C++ costs 0.35–0.48 ms on the desktop, so about 0.8–1.0
  ms on this phone cold and 1.2–1.6 ms throttled (at the ratios measured
  here). That leaves most of the frame to the game even when throttled. The
  cheaper fallbacks (resting slimes stop simulating, fewer points when zoomed
  out, a 30 Hz tick) can't close a gap this size alone: the throttled tick
  is 1.6× the whole 60 fps frame budget. **This goes to spec-writer to
  record; it is not settled here.**
- **The floor phone (A14 class, not measured).** The estimate for the
  reference phone was a little pessimistic (2.2–2.7× measured as
  2.0–2.1×). Taking the floor estimates below as they are:
  - **A14 4G (Helio G80, ~6× the desktop, ~2.9× this phone):** a 12-point
    GDScript spike tick is ~50 ms cold (20 fps), and chunk 5's tick is
    ~88 ms. It fails 30 fps by far.
  - **A14 5G (Exynos 1330, ~2.7× the desktop):** ~24 ms cold for the spike
    tick, which fits 33 ms only before throttling and before the game's
    heavier tick (~40 ms). It fails too.

  Budget phones throttle as well, likely at least as early. In native code
  (~0.35–0.48 ms × 6 ≈ 2–3 ms, more when throttled), both fit 30 fps.
- **The blend's cost doesn't matter for the frame rate on this phone:** the
  GPU works alongside the CPU, and at most 5 ms per frame at full-resolution
  fields is far from 16.7 ms. It still matters for the battery and for heat:
  half-resolution fields (what `SlimeRenderer` uses) halve it to 2.6 ms and
  look the same. The direct fallback (1.4 ms) isn't needed.
- **Renderer: Compatibility stays (D94).** Both renderers run on the
  Adreno 650 and hold the cap on drawing alone. Mobile's lower render CPU
  time (~0.5–0.9 ms saved) is small next to the tick. The Mali-GPU floor phone
  is still the real test of the choice.

## Retest on the phones

Done on the S20 FE (see above): fps and sim ms per tick at 8, 12 and 16
points, still and moving; the blend's GPU cost at field scale 1.0 vs 0.5 at
2400×1080 (on Mobile/Vulkan; Compatibility has no GPU timer there);
Compatibility vs Mobile on drawing; a 10-minute soak.

Still to do:

- **The floor phone**, once bought: the same export as is (matrix + soak,
  about 15 minutes). On a Mali GPU, also the `--draw-only` run on
  Compatibility and on Mobile (Vulkan driver risk).
- **The native tick on the S20 FE:** a small Android build of
  `native_estimate.cpp` through the NDK (`ndk/28.2.13676358` is installed)
  pushed with `adb` and run from `adb shell`, before the GDExtension exists.
  Same on the floor phone.
- **The Compatibility GPU time** stays unmeasured on Adreno (no timer
  query). If it ever matters, use a GPU profiler (Android GPU Inspector or
  Snapdragon Profiler).
- **120 Hz:** the phone was in its 60 Hz mode. With 120 Hz on, the game
  should still cap itself at 60 (to check in chunk 22, with the frame pacing).
- **The whole game at 200 slimes**, throttled, in chunk 22 (the performance
  pass): terrain, game logic, camera and UI share the frame. The spike
  doesn't cover them.

## To carry into chunk 5

- **The data layout:** struct of arrays, packed arrays per point and per
  slime, with a ring as a range (`first`, `npts`) in the point arrays. It
  maps directly onto native code, and splitting or fusing is a matter of
  rewriting ranges.
- **The solver:** Verlet + position-based constraints, 2 substeps × 1
  iteration at the fixed 60 Hz tick, with the settings above. Contacts with a
  rigid reaction on the other ring; a broadphase grid on the centres,
  rebuilt once per tick.
- **Points per ring:** 12 for size 1 (15 for size 2, 18 for size 3). 8
  looks visibly polygonal; 16 costs 25% more for little visible gain. Fewer
  points when zoomed out is an option if needed.
- **The blend:** species fields in the colour channels of two SubViewports
  at half resolution, one static-index triangle array per viewport, and a
  composite shader that thresholds and picks the strongest species. The
  per-frame skirt computation (0.3–0.5 ms in GDScript) can go into native
  code or the vertex shader.
- **Open points in the spike's quality:**
  - the physics is tuned only enough to be stable and to look plausible, not
    for the game's feel;
  - where two species overlap with equal fields, the colour choice can
    flicker (a tie-break is needed);
  - the numbers vary by a few percent between runs, and much more when
    other processes load the machine (hence the logged load average).
