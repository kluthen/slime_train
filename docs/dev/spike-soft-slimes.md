# Spike: soft slimes at scale (chunk 1)

Throwaway spike, `spikes/soft-slimes/`. It checks whether the slime approach
in `specs/tech-direction.md` "Slimes" (D91) holds at the cap: a ring of
points joined by springs, in our own code, drawn with a shader that blends
nearby shapes into smooth blobs, with 200 slimes on one screen (D67). The
targets it measures against are in master-spec.md §7: **60 fps on the
reference phone, at least 30 fps on the floor phone with 200 slimes on one
screen.**

Only the desktop has been measured so far. The reference phone (Galaxy S20
FE) and the floor phone (Galaxy A14 class, not bought yet) are still to do,
so chunk 1's "Done when" is only half met (see "Retest on the phones").

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

# Native estimate
g++ -O2 -std=c++17 -o /tmp/native_estimate spikes/soft-slimes/native_estimate.cpp
/tmp/native_estimate 16 1        # points, moving (0|1)
```

Spike arguments (after `--`): `--mode=still|moving`, `--points=N`,
`--draw=blend|direct`, `--field-scale=X`, `--count=200`, `--substeps=2`,
`--iterations=1`, `--step=frame|physics`, `--warmup=S`, `--measure=S`,
`--bench` (quit after measuring) and `--shot=PATH` (save a screenshot).

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

These are desktop numbers. They set **the CPU cost per slime**, and that's
all. How fast a phone's GPU and thermals are can only be measured on the
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

## Retest on the phones

On the S20 FE now, and on the floor phone once bought, with a debug export
of this spike:

- fps and sim ms per tick, still and moving, at 8, 12 and 16 points;
- GPU time of the blend at field scale 1.0 vs 0.5, at the phone's native
  resolution (2400×1080);
- Compatibility vs Mobile;
- throttling: a moving run of 10 minutes or more, fps over time;
- the native tick, once a GDExtension build exists (a small Android build of
  `native_estimate.cpp` through the NDK would give the CPU number sooner).

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
