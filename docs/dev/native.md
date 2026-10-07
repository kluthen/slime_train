# Native tick (chunk 5N)

The slime simulation tick is moving to native code: a GDExtension in C++,
`slime_native`, with the GDScript tick kept as the fallback (chunk 5N, D158;
D140, D142). D96 first kept it as a documented, verified contingency; after
chunk 22 the user gave the go (D142), and on 2026-10-03 chose to go native
now, for headroom (D158). This document covers why it was measured, how the
extension is built, loaded and chosen, how to test it, and how the port is
done.

Where the port stands (units U7 and U8): the native solver, `SlimeSolver`,
runs the whole solver part of a tick in one call (`step`), on the five passes ported
line for line (units U1 to U5). It reads and writes a `SlimeBodies` (the
marshalling) and checks it can. On the desktop its results are the GDScript
tick's, bit for bit (the same state hashes), and its solver part runs 18 to
19 times faster in crowds (see "Bench"). The GDScript tick stays as the
fallback, per tick and per pass. On the reference phone (unit U8) the
native tick holds `stress-dense` at 59 fps, where the GDScript tick gets 33
(see "On the phone (unit U8)").

## Why it was measured

200 slimes on one screen, pure GDScript, Compatibility renderer (full
numbers in `docs/dev/spike-soft-slimes.md` and "Slimes" in
`docs/dev/README.md`):

| Tick | Desktop (Ryzen 5 PRO 8640HS) | Reference phone (S20 FE), cold | Reference phone, throttled |
|---|---|---|---|
| Spike, GDScript, 12 points | 8.1–8.8 ms | 16.7–18.5 ms | ~27 ms |
| Chunk 5's tick, GDScript (terrain, friction, touch) | 10–15 ms | ~31 ms (estimated) | ~50 ms (estimated) |
| Spike, C++ line-for-line port | 0.35–0.48 ms | ~0.8–1.0 ms (estimated) | ~1.2–1.6 ms (estimated) |

The phone runs the GDScript tick 2.0–2.1× slower than the desktop cold, 3.4×
once it throttles (after about 4.5 minutes of load). At 60 fps the frame is
16.7 ms, so 200 simulated slimes in GDScript don't fit; in C++ they would.

D96 first kept the tick in GDScript: in play most of a big crowd rests in a
pile or a basket, and the cheaper fallbacks of chunk 15 (resting slimes and
sleepers stop simulating, fewer points when zoomed out, simplified baskets)
remove most of that cost.

## What fired it

Chunk 22 measured the real game at the endgame (the bowl, a full basket,
the train) and failed DoD 30 (D138); crowd detail was not enough on its own,
so the user scheduled chunk 5N (D142). The real S20 FE later passed DoD 30's
targets cold, and the user chose to go native anyway, for headroom (D158).
See `specs/decisions.md` and "Simulation performance" in
`specs/tech-direction.md`.

## Layout

| Path | What it holds |
|---|---|
| `native/godot-cpp/` | godot-cpp, the C++ bindings, as a git submodule (see below) |
| `native/slime_native/` | The extension's sources: `SConstruct` and `src/` |
| `native/slime_native/src/slime_solver.{h,cpp}` | `SlimeSolver`, the native solver: `step`, the passes, `check_schema`, `probe_marshal` |
| `native/slime_native/src/solver_state.{h,cpp}` | The marshalling: the schema (the fields and constants the solver relies on), `SolverState` (`load`, `store`) |
| `native/slime_native/src/solver_*.cpp` | One pass per file: `solver_integrate`, `solver_pairs` (the pair grid), `solver_contacts`, `solver_rings`, `solver_terrain` (with the doors), `solver_rest` (with the local wake) |
| `native/slime_native/src/solver_passes.h` | The passes as `step` runs them, on one `SolverState` for the whole tick; the one-pass methods share the same code |
| `native/slime_native/src/slime_native.{h,cpp}` | `SlimeNative`, the toolchain check (the build's name, the multiply-add probe) |
| `native/.gdignore` | Keeps Godot from scanning `native/` (sources, objects, the godot-cpp checkout) |
| `addons/slime_native/slime_native.gdextension` | The extension's descriptor: entry symbol and one library per platform; Godot registers it at startup |
| `addons/slime_native/bin/` | The built libraries (gitignored) |
| `src/sim/tick_choice.gd` | `TickChoice`: which tick a run uses (see "The tick switch and the fallback") |
| `tools/build_native.sh` | The one build script |
| `tests/unit/test_native_extension.gd`, `tests/unit/native_check.{gd,tscn}` | The toolchain test, and `native_check`, which prints a report (in the default suite) |
| `tests/unit/test_native_solver.gd`, `tests/unit/test_tick_choice.gd` | The solver's boundary, the tick switch |
| `tests/unit/native_equivalence_support.gd`, `tests/unit/native_equivalence_scenes.gd` | The equivalence harness: one pass, GDScript against native, on copies of five scenes (see "Testing") |
| `tests/unit/test_native_{integrate,contacts,rings,terrain,rest}.gd`, `tests/unit/test_native_step.gd` | Each pass, then `step`, against GDScript (see "Testing") |
| `tests/e2e/test_tick_cross_load_e2e.gd` | Saves crossing the ticks (see "Testing") |

## godot-cpp version

**godot-cpp 10.0.0-stable** (commit `507ed9d`), built with
`api_version=4.7`. From version 10, godot-cpp is versioned apart from Godot:
one release targets Godot 4.3 to 4.7 through `api_version`, which picks one
of its bundled `gdextension/extension_api-4-*.json` files. Its 4.7 file was
checked against `godot --dump-extension-api` from Godot 4.7.2: same classes
and the same hash for every method (only the header's patch number differs).
An extension built for 4.7 runs on later 4.x versions, not earlier ones
(`compatibility_minimum = "4.7"`).

It is a submodule rather than vendored code: the checkout is 34 MB, 31 MB of
which are the five API JSON files. After a clone:

```sh
git submodule update --init
```

(or `git clone --recurse-submodules`). To move to a newer release, check out
its tag in `native/godot-cpp` and commit the new submodule commit; change
`api_version` in `native/slime_native/SConstruct` when the Godot version
changes.

## Building

Needs SCons 4 (Python), g++ (Linux) and the Android NDK (Android). SCons
isn't packaged with the project; install it for your user, for example with
uv (what this machine uses; SCons 4.11.1):

```sh
uv tool install scons      # or: pipx install scons, or: pip install --user scons
```

Then:

```sh
tools/build_native.sh                     # Linux x86_64, debug (tests, editor)
tools/build_native.sh --release           # Linux x86_64, release
tools/build_native.sh --android           # Android arm64-v8a, debug (the phone)
tools/build_native.sh --android --release
tools/build_native.sh --android --arch=x86_64   # Android x86_64, debug (the emulator)
tools/build_native.sh --all               # all five, in that order
tools/build_native.sh --test              # Linux debug, then the native tests
tools/build_native.sh -- verbose=yes      # after --, arguments go to SCons
```

The libraries go to
`addons/slime_native/bin/libslime_native.<platform>.<target>.<arch>.so`
(`target` is `template_debug` or `template_release`), which is what the
descriptor lists (`linux.debug.x86_64`, `linux.release.x86_64`,
`android.debug.arm64`, `android.release.arm64`, `android.debug.x86_64`).
godot-cpp's own static library goes to `native/godot-cpp/bin/` (ignored by
godot-cpp's `.gitignore`).

- **Incremental.** The first build of each platform, target and arch
  compiles godot-cpp: about 2 minutes on this machine (12 cores). After
  that only the extension's changed files rebuild; `--all` with nothing to
  do takes about 11 s (SCons reading godot-cpp's build five times).
- **One build at a time.** The script takes a lock (`native/.build.lock`,
  `flock`, gitignored) around its builds, so builds started in parallel (two
  test runs, two agents) run one after the other instead of writing the same
  objects. It lets go before `--test` runs the tests.
- **Who builds.** `tools/test.sh` builds the Linux debug library when it is
  missing or older than its sources; `tools/linux/export.sh` builds it before
  the Linux export; `tools/android/export.sh` builds the Android libraries
  (`debug`: arm64 and x86_64; `release`: arm64). Each then imports
  (`godot --headless --import`), which lists the extension in
  `.godot/extension_list.cfg`, so it loads at startup and the export ships
  it.

Android: the script finds the SDK at `$ANDROID_HOME`, or `~/Android/Sdk`,
and uses NDK 28.2.13676358 (set `ANDROID_NDK_VERSION` to choose another; it
must be installed under the SDK's `ndk/`). It doesn't take the newest NDK
installed: 29.0.14206865 is there for the Gradle build of the exports, and
the extension stays on the NDK it was verified with. godot-cpp 10 defaults
to NDK 28.1.13356709, so the script always passes `ndk_version`. The target
is API level 24, the minimum SDK of the exports. The C++ runtime is linked
statically (`-static-libstdc++`), so the extension doesn't depend on the
`libc++_shared.so` of Godot's Android template: the libraries need only
`libc`, `libm` and `libdl`.

## The tick switch and the fallback

`TickChoice` (`src/sim/tick_choice.gd`) picks the tick of a run, in order:

1. `--tick=gdscript` or `--tick=native` among the user arguments (after
   `--`), in a debug build only. A release build ignores it and prints
   `TICK --tick=<value> ignored, not a debug build.`
2. The environment variable `SLIME_TICK` (`gdscript` or `native`), in any
   build.
3. The default: native when the extension is loaded (`SlimeSolver` is a
   class), else GDScript.

Every run prints one line, `TICK <kind> (<reason>)`, to stderr (a
diagnostic: a tool's stdout, such as `tools/level.sh report --json`, stays
its own), when its first `SlimeBodies` is made: for example `TICK native (default)`,
`TICK gdscript (--tick=gdscript)`, `TICK gdscript (extension missing)`.
A native tick asked for (1 or 2) without the extension gives
`TICK gdscript (extension missing, --tick=native not met)` and an error; an
unknown value is an error and is ignored (the next source decides).
`TickChoice.resolve()` is a pure function of the arguments, the variable,
the build and the extension (tested in `tests/unit/test_tick_choice.gd`);
`TickChoice.current()` is the run's, resolved once.

- **The fallback.** When the library is missing or doesn't load, Godot logs
  an error at startup and goes on; the run gets the GDScript tick
  (`extension missing`), in a release build too. Nothing in the scripts
  names the solver's class but through `ClassDB`, so they parse without the
  extension.
- **Per bodies.** `SlimeBodies.use_native(on) -> bool` switches one
  `SlimeBodies` between the ticks at any time (A/B runs, cross-tick tests);
  `uses_native()` reads it. A new `SlimeBodies` takes the run's tick. It
  returns false, with an error, when the extension is missing or when
  `SlimeSolver.check_schema()` finds a field or constant it can't rely on;
  the GDScript tick then runs on.
- **The dispatch.** `SlimeBodies.tick()` runs the hops and the support
  reset in GDScript, then calls `SlimeSolver.step(bodies, h)` (see "One
  call per tick"): true, the native solver ran the whole solver part of the
  tick. False, the passes run one by one (`_solve`, `_solve_iteration`),
  and each native pass that returns false (`integrate`, `build_pairs`,
  `solve_contacts`, `solve_rings`, `solve_terrain`, `rest`) is replaced by
  its GDScript pass.
- **The fallback per tick and per pass.** `step` and every one-pass method
  return false, with an error, before anything reaches the bodies, when
  they can't read them: a field missing or of another type, sizes that
  don't agree, a point range outside the points, a centre that isn't
  finite, a pair that isn't two slimes, an empty ring with pairs, an
  `angle0` out of [-PI, PI], a terrain or door grid that lists what it
  doesn't have. A refused `step` costs that tick its one call: the tick
  runs pass by pass, and only the passes that refuse too run in GDScript
  (`tests/unit/test_native_step.gd` checks a door the solver can't read,
  far from every slime: the tick is still the GDScript tick, exactly).
- **The phase timers** (debug, `src/debug/phase_timers.gd`). On the native
  tick a tick is timed as `auto_hops`, `tick_other` (the support reset) and
  `native` (`step`, every solver pass in one call): the passes inside it
  aren't timed one by one. `native` counts as solver (`SOLVER_PHASES`). On
  the GDScript tick, and when `step` falls back, the passes are timed one
  by one as before (a native terrain pass as `terrain`, doors included).
- **Saves.** The solver keeps no state between calls (only scratch), and no
  save says which tick wrote it: a save loads and runs on under either tick.

## One call per tick: `step`

`SlimeSolver.step(bodies, h)` is `SlimeBodies._solve` in one call, in its
order: `substeps` times integrate, the pair grid on the first substep, then
`iterations` times the contacts, the rings and the terrain (the shut doors
included); then `_centre_ok` cleared, the rest pass with the local wake, and
the touching list.

- **One read, one write.** `SolverState::load` reads every field once and
  takes a writable copy of each read-write array (one copy each, see "The
  marshalling"); the terrain and the doors are read once
  (`read_terrain_pieces`: a door can't open or shut within a tick). The
  passes run on that state in place, and `store` writes every read-write
  array back once at the end. Nothing is written before then, so a pass
  that fails halfway leaves the bodies as they were.
- **One implementation per pass.** `solver_passes.h` declares the passes on
  a whole tick's state (`integrate_state`, `build_pairs_state`,
  `contacts_state`, `rings_state`, `terrain_state`, `rest_state`); each is
  the same code as its one-pass method (`integrate`, `build_pairs`, ...),
  which reads only the fields it needs and writes back only what it
  changes. The equivalence tests check the one-pass methods, and
  `test_native_step.gd` checks `step` as a whole.
- **No per-tick allocation beyond scratch.** The pair grid, the door boxes
  and the rest pass's union-find are file-level scratch, reused from tick
  to tick (the simulation runs on one thread). Each tick allocates only the
  copies of the arrays it writes (copy-on-write) and the new `_pairs` and
  `_pair_touch`.
- **The touching list is built natively,** in `step`, after the last pass
  that can fail: `Vector2i(id a, id b)` for every pair whose `_pair_touch`
  is set, in pair order, written into the bodies' own `_touching` Array (an
  Array is shared, not copied: resized only when the count changes). It is
  the list `_solve` builds, element for element (the rest pass changes
  neither the pairs nor the ids, so building it after the rest pass gives
  the same list). Native, so that no GDScript loop over the pairs is left in
  a native tick; `test_native_step.gd` compares it with `_solve`'s at every
  tick.
- **The centre cache.** `step` clears `_centre_ok` (every point moved), as
  `_solve` does, and leaves `_centre_cache` as it is: GDScript's
  `centre_of()` refills an entry the first time it is read after a tick, so
  the cache ends every tick exactly as the GDScript tick leaves it.
- **Spec links.** `step` carries the atoms of the passes it runs
  (`req_tilt_input`, `req_slime_states`, `req_waking_sleepers`,
  `req_offscreen_simulation`); `tick()` and `_solve()` carry none of their
  own.

## The marshalling (the copy-on-write boundary)

godot-cpp passes a method's `const PackedXArray &` arguments as copies
(`native/godot-cpp/include/godot_cpp/core/method_ptrcall.hpp`): what C++
writes into an argument array never reaches GDScript. So `SlimeSolver`
takes the `SlimeBodies` object itself and:

- reads each array once per call with `bodies->get(StringName)`
  (`SolverState::load`): the read shares the member's buffer, packed arrays
  being copy-on-write;
- writes through `ptrw()`, which copies a shared buffer once (one copy per
  written array per call);
- writes the read-write arrays back with `bodies->set()`
  (`SolverState::store`): the member then holds the new buffer. A copy of
  the array taken in GDScript before the call keeps the old values.

`SlimeSolver.probe_marshal(bodies, delta)` does exactly that and moves every
point by `delta`; `tests/unit/test_native_solver.gd` checks GDScript sees
the move. The fields are listed once, in `solver_state.cpp`:

- read only: `slime_count`, `first`, `npts`, `state`, `id`, `bound_r`,
  `rest_edge`, `rest_area`, `rest_off`, the tuning scalars (`gravity`,
  `free_down`, `substeps`, `iterations`, the stiffnesses,
  `internal_damping`, `air_drag`, the frictions, `terrain_skin`,
  `max_speed`, `rest_enabled`), `terrain` and `doors` (each
  `TerrainSegments`' `seg_a`, `seg_d`, `seg_inv_len2`, `seg_n`, `seg_na`,
  `seg_nb`, `cell_start`, `cell_items`, `origin`, `inv_cell`, `grid_w`,
  `grid_h`);
- read and written: `pos`, `prev`, `centre`, `angle0`, `_drift`,
  `supported`, `calm`, `still_ticks`, `rest_anchor`, `pile`, `_pairs`,
  `_pair_touch`, `_touching`, `_centre_cache`, `_centre_ok`;
- the constants: the states, the calms, `SUPPORT_NORMAL_Y`, `TOUCH_SKIN`,
  `REST_DRIFT`, `REST_TICKS`, `WAKE_SPEED`.

`SlimeSolver.check_schema(bodies)` returns the problems: a missing field
(`_drift: missing (PackedVector2Array)`), a retyped one
(`calm: PackedInt32Array, expected PackedByteArray`), a missing or changed
constant, a terrain or door missing a field. So renaming or retyping one of
these in `slime_bodies.gd` makes `use_native` refuse the bodies, and the
tests fail, instead of the solver reading an empty array.

## Testing

```sh
tools/test.sh                         # the whole suite on the native tick, then the
                                      # slime tests on the GDScript tick (second pass)
SLIME_TICK=gdscript tools/test.sh     # the whole suite, on the GDScript tick
tools/build_native.sh --test          # Linux debug build, then test_native_*
```

- **The second pass.** After the whole suite on the native tick,
  `tools/test.sh` runs the slime tests again on the GDScript tick
  (`SLIME_TICK=gdscript`, `-gselect=test_slime_`, the other arguments
  kept), so the fallback keeps its own tests. Not after a selection
  (`-gselect`, `-gtest`, `-gunit_test_name`, `-ginner_class`, `-gdir`), nor
  when the first pass ran on the GDScript tick. The exit code is the first
  failing pass's.

`tools/test.sh` sets `SLIME_TICK=native` unless the environment says
otherwise, builds the Linux debug library when it is missing or older than
its sources, and fails (exit code 2) when it can't: it never runs the suite
on the fallback on its own. `test_tick_choice.gd` checks the run's tick is
the one asked for, so a library that is built but doesn't load fails the
suite too. With `SLIME_TICK=gdscript` no library is needed; the native
tests are then pending if it is missing.

- `test_native_extension.gd`: the extension registered at startup (never
  loaded by hand: that would hide a build where it doesn't load),
  `version()`, `sum()`, the multiply-add probe.
- `test_native_solver.gd`: the native write reaching GDScript;
  `check_schema` passing on `SlimeBodies` (with a terrain, a door, none) and
  failing on a renamed field, a renamed or changed constant, a retyped
  field and a door of another class (scripts made from `slime_bodies.gd`'s
  source with one change); `use_native` on, off and refused; the native
  tick against the GDScript tick (240 ticks, a door shut: the same arrays
  and dump, bit for bit).
- `test_native_step.gd`: `step` against `_solve` on every scene of the
  harness for 30 consecutive ticks, each copy run on its own (the
  trajectories), every field exact (the touching list and the cleared
  centre cache included, the caches filled before each tick); two native
  runs bit-equal; bodies it can't read refused before any write (a short
  array; a NaN point, refused by the pair grid after integrate ran); the
  per-tick fallback (see "The tick switch and the fallback").
- `tests/e2e/test_tick_cross_load_e2e.gd`: `s3-basket-59of60` and
  `gate2-open`, run 120 ticks on one tick and saved through the save's
  text, each save loaded under the other tick and run 600 ticks: no NaN,
  the same slimes at the load (ids, species, sizes, states), the
  population kept (per species, counted by size), every centre within the
  terrain's grid; and a save loaded twice under the same tick runs to the
  same hash, on each tick.
- The equivalence harness (`native_equivalence_support.gd`, not a test
  script), for the pass-by-pass tests (units U1 to U5) and `step`'s: a copy of a scene
  brought in GDScript to the moment of a tick when a pass runs
  (`prepared(scene, phase, substep, iteration)`), then the GDScript pass on
  one copy and the native one on another (`check`), every field of
  `SlimeBodies` compared: the positions, centres, angles, drifts and rest
  anchors within 1e-3 px by default (overridable per field), everything
  else exactly; a problem names the scene, the field, the index (and its
  slime) and both values. `phase_supported(phase)` / `skip_reason(phase)`
  keep a test pending when its native pass can't run: a stub (every pass
  was one before units U1 to U5), or a run with `SLIME_TICK=gdscript`
  without the extension. The scenes
  (`native_equivalence_scenes.gd`, built once per run on the GDScript
  tick): the fixtures `stress-moving`, `s3-basket-59of60`, `gate2-open`
  (shut doors), `stress-still` once its pile rests, and a synthetic box
  (detail-3 rings, sleepers and a resting pile with active slimes on them,
  parked slimes, slimes at the first and last index, a point on a segment's
  end, doors shut, far and empty). `test_native_equivalence_harness.gd`
  checks the harness itself: GDScript against GDScript is exact for every
  scene and every pass of a tick, its walk of a tick is `tick()` bit for
  bit, a difference is reported, the copies share no array.

## Determinism: `-ffp-contract=off`

Every file, godot-cpp's included, is compiled with `-O2 -ffp-contract=off
-fno-fast-math` (`native/slime_native/SConstruct`). The optimisation level is
set there, the same for debug and release, rather than by godot-cpp (which
uses `-O3` for release).

- **`-ffp-contract=off`:** the compiler may not fuse `a * b + c` into one
  fused multiply-add. A fused multiply-add rounds once instead of twice, so
  the result depends on the compiler, the target and the optimisation level.
  The NDK's clang fuses by default on arm64: the same line compiles to one
  `fmadd` without the flag and to `fmul` + `fadd` with it (checked with
  `llvm-objdump` on `SlimeNative::mul_add`).
- **No `-ffast-math`:** it reorders and approximates float operations.
- **The probe:** `SlimeNative.mul_add(a, b, c)` returns `a * b + c` for
  operands where rounding twice gives 0 and fusing gives 2^-60. The test
  checks it on the desktop; on x86_64 it holds anyway, since the baseline
  instruction set has no FMA. The phone check below is what proves it on
  arm64.

**Caveat: bit for bit with GDScript only on the same C library.**
GDScript mixes precisions (`float` is a double, `Vector2` components are
32-bit, so is `PackedFloat32Array`); the port follows the same split
operation by operation, so on the desktop the native tick gives the
GDScript tick's state, bit for bit (the same hashes for every fixture).
Its `atan2` still comes from the C library (glibc on Linux, bionic on
Android), as GDScript's does, and its last bits can differ from one
library to another. So state hashes compare within one build: the
same library gives the same run every time, which is what the end-to-end
tests need, and a Linux hash isn't expected to equal an Android one. The flags above keep
basic arithmetic and `sqrt` identical across builds; cross-platform
equality would also need our own `atan2`, `sin` and `cos`.

**Checked on the phone (2026-10-07, main cfe1dab):** `stress-dense` and
`stress-moving` gave the desktop's hashes at 600 ticks, but
`s3-basket-59of60` gave `4c5d03d2…` (desktop `a0223398…`), the same on
both ticks. The cause is `atan2f` (bionic and glibc differ in the last
bit on about 10 % of inputs), reached through `Vector2.angle()` in
`SlimeDetail.resample` (`a0`, the resampled ring's first angle; called
through `SlimeBodies._resample`), which runs
when crowd detail changes a ring's point count; the double `atan2` of the
contact pass differs too but has so far vanished in the float32 store. Not
the view: test mode fixes it at 1152x648. To reproduce a phone hash on the
desktop, `tools/linux/bionic_libm.sh` builds an LD_PRELOAD shim with
bionic's `atan2`, `atan2f`, `sin` and `cos` (it counts the calls that
differ); `LD_PRELOAD=build/bionic_libm/libbionic_libm.so godot --headless
...` gives all three phone hashes. The shim can't reach the native
extension (loaded with RTLD_DEEPBIND), which keeps glibc's `atan2`.

## Checking on the phone

Every export ships the extension now (the descriptor sits in
`addons/slime_native/`, outside `native/.gdignore`), so the game's own APK
is the check: its log starts with the `TICK` line (`adb logcat -v time -s
godot:*`). The debug APK holds
`lib/arm64-v8a/libslime_native.android.template_debug.arm64.so`, the x86_64
one for the emulator, `assets/addons/slime_native/slime_native.gdextension`
and `assets/.godot/extension_list.cfg`; the release APK the arm64 release
library.

The one-off toolchain check of 2026-09-28 (before chunk 5N) went through a
temporary export whose main scene was `native_check` (now
`tests/unit/native_check.tscn`), on the Galaxy S20 FE 5G (Android 13),
Godot 4.7.2 debug template:

- the APK held `lib/arm64-v8a/libslime_native.android.template_debug.arm64.so`,
  the descriptor and `assets/.godot/extension_list.cfg`;
- the log:

  ```
  NATIVE_CHECK version="slime_native 0.1.0 (android.template_debug.arm64)" loaded_at_startup=true
  NATIVE_CHECK sum=7.0 (expected 7)
  NATIVE_CHECK mul_add=0.0 fused=false -> OK (no FMA contraction)
  ```

  So Godot loaded the extension from the APK at startup, and the arm64
  build doesn't fuse multiply-adds.

## The port (chunk 5N)

The GDScript `SlimeBodies` (`src/sim/slime_bodies.gd`) keeps its interface,
so its callers (the simulation, the train, the renderer, the tests) don't
change. Its GDScript solver passes, the ones the native solver mirrors, are
`SlimeSolverGD`'s (`src/sim/slime_solver.gd`, static functions over the
bodies' arrays, called through `SlimeBodies._integrate`, `_build_pairs`,
`_solve_contacts`, `_solve_rings` and `_solve_terrain`). Its GDScript rest
pass is `SlimeDetail.rest` (`src/sim/slime_detail.gd`, with the other calm,
rest and detail code), called through `SlimeBodies._rest`. Its hops are
`SlimeHops`' (`src/sim/slime_hops.gd`) and its saves and dump
`SlimeBodiesSave`'s (`src/sim/slime_bodies_save.gd`), both called through
`SlimeBodies` too. Behind it:

- **The native solver** (`SlimeSolver`) runs the solver part of the tick:
  substeps of integrate, the pair grid (first substep), slime contacts,
  ring constraints, terrain contact (the shut doors too), then the touching
  list and the rest pass with the local wake. It reads and writes the
  `SlimeBodies` arrays (see "The marshalling") and keeps nothing between
  calls but scratch (the pair grid, the door boxes, the rest pass's
  union-find).
- **The terrain:** `TerrainSegments` still bakes its segment arrays and grid
  in GDScript at level load; the solver reads them, read only (D97).
- **What stays in GDScript:** the hop clears and the automatic hops
  (`SlimeHops`; each slime's random stream: all randomness stays in the one
  seeded generator), the support reset, the topology changes (`create`,
  `remove`, `merge`, `split`, `_reshape`, `_resample`), the saves
  (`body_of`, `set_body`) and `dump()` (`SlimeBodiesSave`), the public
  wakes, and all the behaviour code (the train, the calls, fusion,
  Offscreen, the loop-start queue).
- **Pass by pass.** Each pass is ported and tested on its own against the
  GDScript one (units U1 to U5); `step` then runs them all in one call
  (U6). The fixtures' state hashes didn't change: on the desktop the native
  tick gives the GDScript tick's (see "Fixture hashes").

## Bench (unit U7)

The desktop, both ticks, 2026-10-05, at the commit of unit U6. Full report:
`docs/perf/2026-10-05-5n-desktop-bench.md` (the machine, the load, every
run, the per-phase table, the slowed runs, the phone estimate and the open
questions for the phone).

Headless, full speed: `SLIME_TICK=<tick> tools/level.sh bench
--fixture=<name> --phases`, seed 909, 600 timed ticks (`stress-dense` after
a 3600-tick lead-in, the others after their own), the median of three runs,
the two ticks alternating. Mean ms per tick; solver: the GDScript passes,
or the one `native` lap; behaviour: the rest of the step, GDScript on both.

| Fixture | GDScript tick | Native tick | Change | Solver µs (GDScript / native) | Solver speed-up | Behaviour µs (GDScript / native) |
|---|---|---|---|---|---|---|
| `stress-moving` | 10.61 ms | 5.65 ms | -47 % | 5141 / 265 | 19.4x | 5462 / 5376 |
| `stress-dense` | 5.68 ms | 4.09 ms | -28 % | 1682 / 92 | 18.4x | 3994 / 3992 |
| `s3-basket-59of60` | 5.81 ms | 3.17 ms | -45 % | 2764 / 146 | 18.9x | 3009 / 3021 |
| `stress-still` | 1.03 ms | 0.83 ms | -19 % | 219 / 22 | 9.7x | 804 / 804 |
| `start` | 0.97 ms | 0.82 ms | -16 % | 190 / 22 | 8.8x | 780 / 794 |

- **The solver part** runs 18 to 19 times faster in crowds, about 9 times
  on the still scenes, where what is left is fixed cost.
- **The behaviour** (fusion, offscreen, the train, the frontier sets, the
  loop-start queue) is unchanged and is now 95 to 98 % of the native tick.
- **The marshalling** (`step` copies every read-write array once a tick)
  doesn't show: on `stress-still` (no physics slime) the whole native lap,
  copies included, is 22 µs against 219 µs for the GDScript passes. The
  native tick is not slower anywhere.
- **Slowed** (`tools/perf_slow.sh --pin=main --phase-timers`, windowed):
  the tick goes 27.0 -> 11.7 ms on `stress-moving` (15.6 -> 29.0 fps),
  23.3 -> 15.3 ms on `stress-dense` (17.0 -> 22.8 fps), 16.0 -> 10.9 ms on
  `s3-basket-59of60` over 240 s (21.9 -> 31.6 fps; its section 1 crowd
  18.9 -> 25.4 fps).
- **The phone estimate** (D142: the full-speed cost × 2.1 cold, × 3.4
  throttled, the GDScript tick's factors): the native tick 11.9 / 19.2 ms
  on `stress-moving`, 8.6 / 13.9 ms on `stress-dense`, 6.7 / 10.8 ms on
  `s3-basket-59of60` (the GDScript tick 22.3 / 36.1, 11.9 / 19.3,
  12.2 / 19.7). The phone's perf log settles it (unit U8).

### Fixture hashes

The test level's 19 fixtures (18 before item 24.5's `loop-start-pile`), seed 909, headless test mode
(`godot --headless -- --test-mode --level=test --fixture=<name> --seed=909
--run-ticks=<N>`), on Linux x86_64 (this desktop, glibc), 2026-10-05, at
the commit of unit U6. They are the native tick's hashes and, on this
desktop, the GDScript tick's too (checked at 600 and 2400 ticks on both
ticks; unit U6 found the release library's the same). An Android build
isn't expected to give the same (see "Caveat" under "Determinism"); the
earlier hashes recorded with each chunk in `docs/dev/README.md` are each of
that chunk's commit (the `stress-dense` ones of chunk 22m, for example,
changed with chunk 22h step A's `marked_at`).

**Re-recorded with chunk 24g part A (2026-10-07):** the hold on a climb and
the relay (see "Train" in `docs/dev/README.md`) change the train's motion,
so 11 fixtures changed (at 600 ticks, 2400, or both): `bump`, `fresh`,
`lost`, `midair`, `old-version`, `s1-basket-5of6`, `s2-cave-return`,
`s3-basket-59of60`, `stress-dense`, `stress-moving`, `sunrise`; the other 7
are the same. Native and GDScript gave the same hashes for all 18 at 600
and 2400 ticks.

**Re-recorded with the 24g relay fix (2026-10-07):** the relay now cuts
the hop timer at the end of the take-off's tick instead of at the start of
the next one (see "Closure" under "Chunk 24g" in `docs/dev/README.md`), so
a hash taken on a tick when a relay acted shows the cut timer one tick
sooner. 4 hashes changed: `s3-basket-59of60` at 600, `stress-dense` at 600
and 2400, `stress-moving` at 2400; the other 32 are the same. The motion
didn't change: on those three fixtures the state without the hop timers is
the same as before the fix on every tick (to 620, 2400 and 2400 ticks),
and the full hash one tick later is the same too (`s3-basket-59of60` at
601). Native and GDScript gave the same hashes for all 18 at 600 and 2400
ticks.

**Item 24.4 and 24.5 (2026-10-07):** a migration now keeps a displaced
sleeper asleep at its spot (see "Migration by level version" in
`docs/dev/README.md`), so `old-version`'s moved sleeper is put back on its
ledge instead of being lost to the loop start: its hashes changed at 600
and 2400 ticks (its files didn't, but its sidecar's description). The new
`loop-start-pile` (the phone's migrated save) is added. Native and
GDScript gave the same hashes for both at 600 and 2400 ticks; `fresh`,
`bump` and `stress-dense` were checked unchanged (native at 600 and 2400,
GDScript at 600).

**Item 24.3 (2026-10-07):** basket 3's outlet moved over slide 3's drop
(see "A fired basket empties (item 24.3)" in `docs/dev/README.md`), so
only a run where basket 3 releases changes: `s3-basket-59of60` at 2400
ticks (it fires at about tick 675; its 600-tick hash is the same). The
other 37 hashes are the same. Native and GDScript gave the same hashes for
all 19 at 600 and 2400 ticks.

**A released slime hops away at once (O126, 2026-10-07):** a basket's
released slime hops on the tick after it lands at the outlet (see "A
released slime hops away at once (O126)" in `docs/dev/README.md`), so
only a run where a basket releases changes: `s1-basket-5of6` at 600 and
2400 ticks (basket 1 releases before tick 600), `s3-basket-59of60` at 2400
(its 600-tick hash is the same: it fires at about tick 675).
`s2-basket-offscreen` is the same: with the fixture's camera basket 2
waits full off screen and never fires. The other 35 hashes are the same.
Native and GDScript gave the same hashes for all 19 at 600 and 2400 ticks.

**On the phone (unit U8, 2026-10-06):** the S20 FE (arm64, bionic) gave
the 600-tick hashes then recorded (before chunk 24g) for `stress-dense`
and `stress-moving`, on both ticks, two runs each. That wasn't expected:
bionic's `atan2` happened to agree with glibc's on these runs. It says
nothing about the other fixtures, longer runs or other phones, so hashes
are still compared within one build and platform.

| Fixture | 600 ticks | 2400 ticks |
|---|---|---|
| `bedtime` | `5a94fa65bf8e05b9c45cecfe6ab80e1fa9a745d20f21a9398aba739f840f4cd7` | `b02215f37ca327c09f693160e47945184681c5449b3b1d17d8e61252d2cfb749` |
| `bump` | `1baec7ea0f118303108cb808c319aa071586cc5681eb120b3538c8aaebaf3d74` | `7a927e1a51faeb03b4dfad9ddc03872cf9658858c3af61b80af996716e2bc9f3` |
| `fresh` | `b020ee7e6a00991a4cde595463a6d8c53d5ad3d2d36fd18a6b52038ac49178c0` | `5089569bbb36d1ab763d08fe4478ea685de8ddc4d6d8bddafa905722e01e9583` |
| `gate1-open` | `fb471f56be0fc75e99785e9fd0176ec1641eed19b9f2112eab56fbafddad076c` | `87d4a31669d409cbf2d42d006e90f786672a4aed12aba2c8de5d05b7bd53b6b2` |
| `gate2-open` | `c96c61a34602ac84e4ed97ba4caad51ff31d5e605169366a48cf9fa77fa5cc2d` | `12c9da691f6c5135861cac2b637bff6809a9e4ce5288d8ee3b1504e179eb9f96` |
| `lost` | `a25bab8eace16098cb07366bc45b3b8fd14593bed08d496580c15394f7df72c3` | `1a58286b52fea5ff4932da49395243ce3e8fce413c38ee62289b4e7c086cc84c` |
| `midair` | `04734d3f46724b193253dacfd154ae7cefa775a75364b7e8d7afe264f030fc78` | `fc549af11315a0bd59fc8ded2a8880ee49d45479cbb0f0f94fb2ca32a46b45eb` |
| `loop-start-pile` | `dc3f304a64517ed37149cddbb89cc94c8e8f9dae1e786240afdefe215bcc6837` | `cb2da78839842dba988ab190c02a6aa9bf0f74a64a343866e06e71954d9e551c` |
| `old-version` | `419e7f5fc52e5b371d5b95b51b3ff66f2fa40c2e6ac47d65ed60d003842c4f35` | `a0da0b38df6d54a4464ad454c3e730c9b6d4b7b7028ca8c4b27e871a9287e4d7` |
| `s1-basket-5of6` | `162b48841d5b58c383df0855a74e2a3cae70237d5eb9dbdab0585dfc349a8fce` | `67255f6a798f9544cdeb7df0e730a701c0e25709506e02b073ac90ab44445baa` |
| `s1-optout` | `0a01989974e37d78a4b12a08e100a376b330a5297192d3c41baaffd4c8f0ca78` | `4e359fbaa0852076731a22db89186acbfccafde5c565a3db4b0812617a53d1ca` |
| `s2-basket-offscreen` | `df9505ea337f43f30352b7e45a1ecd305344e83062009c5e1e767e83c31e3247` | `fcdb40131c591c9a351e9cc5d90730c87b62da47e65ad5b0e5fc859b1889bcd3` |
| `s2-cave-return` | `ca1245d013105513dcd94f95aeb7109f780987ef9444e5fdfd849929cb0116ea` | `7a48dc0899882e86ab70cf5659195c30454ac793dd1b50d7b51cf4bca1394984` |
| `s3-basket-59of60` | `a02233987e184234274869061b60a9744d72dbe9b4db5f7cfeb3ad5dee1de1cf` | `32991befd59798f46c0a87d710a2b78efeeeb4ce24e164fe65f2ba340032d9a3` |
| `stress-dense` | `c389dd44328edbd31c433dca49a3656a7afdcc6929b141f09de523f11a189228` | `6fd6f0385d09962b19fff68be0178112f59138e65a8f646fe05b2b325ba6aa54` |
| `stress-moving` | `cee540fc61f6a8d76eba240801fafa610d7a65205b2aec896a2df869495c7dd8` | `09a460c88db349712a63aab85d3ccbf290ddfb13c7b17f609ab9bc6d27408381` |
| `stress-still` | `4c50a541d5a60dda72d85cfd5941782b28975e8352d1529ed12eedfdb8aa2f27` | `9efbbc6b1f014895180f7e007b574fd3a03309e29dec2798b913cf0260da49e7` |
| `sunrise` | `8db8d2c83ee28167f22616d7187ab43f8e1bace7d29b88c492a35f7c3429c9eb` | `eb0221091629c9fc6d09df861653a62b048e1b34f6f77c1de66c1cd002c2b785` |
| `wind-down` | `1f6ba0b95667450033a0bf6d9fd123d23ea46fc2a6ae664fd731a32bda2a50eb` | `801144a13df0b9c9422e87ae353786d1c6c5e9c3973a61d67e6995c1aa92b851` |

## On the phone (unit U8)

The S20 FE, 2026-10-06, the debug APK of cb7e6f5, both ticks in ABBA order
(`tools/android/perf.sh --phase-timers --tick=<tick>`, seed 1, a 5 min run;
`stress-still` 2 min). Full report:
`docs/perf/2026-10-06-5n-s20fe-session.md`, with the conditions, every
window, the phone factors, U7's five open questions, the hashes, the census
and what is left for chunk 22's repeat. The fps column is the mean over
the first 60 s; the step split (µs per tick) is from the same window.
Rows marked "slow phone" ran while the phone ran about 1.6 times slower
than on 2026-10-03 (thermal status 0; see the report). Both ticks of those
fixtures ran in that state.

| Fixture | fps, GDScript → native | Tick ms, GDScript → native | Solver µs, GDScript passes → native lap | Behaviour µs (native tick) |
|---|---|---|---|---|
| `stress-dense` | 32.8 → 59.0 | 15.06 → 11.30 | 4320 → 283 | 10849 |
| `stress-moving` (slow phone) | 13.2 → 23.2 | 34.99 → 18.74 | 15786 → 700 | 17857 |
| `s3-basket-59of60` (slow phone) | 21.4 → 35.7 | 20.71 → 13.54 | 7897 → 418 | 12936 |
| `stress-still` | 55.6 → 59.1 | 6.71 → 5.42 | 2218 → 316 | 4830 |

- **The native lap's phone factor** (phone µs / the desktop bench's) is
  2.6 to 3.1 in crowds, about the GDScript solver's own. On the resting
  `stress-still` it is 11.6 (22 → 256 µs). On the phone the native lap
  has a fixed part of about 0.2 to 0.25 ms a tick (the loads, the copies,
  the stores, the loops over all 200 slimes). That is still 3.8 times less
  than the GDScript passes (968 µs) and 2 to 6 % of the step.
- **The behaviour is the floor:** 9.5 to 10.8 ms a tick on `stress-dense`
  and more in the other crowds, on either tick. It alone misses D138's
  8 ms simulation budget. Porting it is outside 5N.
- **DoD 30's stress targets pass on the native tick:** `stress-dense`
  59.0 fps cold and 59.1 warm (target 30); `stress-moving` 23.2 cold, p5
  18.4 (target 15), measured on the slow phone. Release-template numbers
  can't be taken: the perf log and test mode are debug-only. The native
  library is built with the same flags in debug and release.
