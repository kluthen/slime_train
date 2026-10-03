# Native tick (chunk 5N)

The slime simulation tick is moving to native code: a GDExtension in C++,
`slime_native`, with the GDScript tick kept as the fallback (chunk 5N, D158;
D140, D142). D96 first kept it as a documented, verified contingency; after
chunk 22 the user gave the go (D142), and on 2026-10-03 chose to go native
now, for headroom (D158). This document covers why it was measured, how the
extension is built, loaded and chosen, how to test it, and how the port is
done.

Where the port stands (unit U0b): the toolchain, the loading, the tick
switch and the fallback are in place. The native solver, `SlimeSolver`,
reads and writes a `SlimeBodies` (the marshalling) and checks it can; its
passes are stubs that return false, so every pass still runs in GDScript and
the results are the GDScript tick's, bit for bit.

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
| `native/slime_native/src/solver_*.cpp` | One pass per file: `solver_integrate`, `solver_contacts` (the pair grid and the contacts), `solver_rings`, `solver_terrain` (with the doors), `solver_rest` (with the local wake) |
| `native/slime_native/src/slime_native.{h,cpp}` | `SlimeNative`, the toolchain check (the build's name, the multiply-add probe) |
| `native/.gdignore` | Keeps Godot from scanning `native/` (sources, objects, the godot-cpp checkout) |
| `addons/slime_native/slime_native.gdextension` | The extension's descriptor: entry symbol and one library per platform; Godot registers it at startup |
| `addons/slime_native/bin/` | The built libraries (gitignored) |
| `src/sim/tick_choice.gd` | `TickChoice`: which tick a run uses (see "The tick switch and the fallback") |
| `tools/build_native.sh` | The one build script |
| `tests/unit/test_native_extension.gd`, `tests/unit/native_check.{gd,tscn}` | The toolchain test, and `native_check`, which prints a report (in the default suite) |
| `tests/unit/test_native_solver.gd`, `tests/unit/test_tick_choice.gd` | The solver's boundary, the tick switch |

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
  reset in GDScript, then calls `SlimeSolver.step(bodies, h)`: true, the
  native solver ran the whole solver part of the tick. False, the passes run
  one by one (`_solve`, `_solve_iteration`), and each native pass that
  returns false (`integrate`, `build_pairs`, `solve_contacts`,
  `solve_rings`, `solve_terrain`, `rest`) is replaced by its GDScript pass.
  With the debug phase timers on, a native terrain pass is timed as
  `terrain` (doors included), and a native `step` isn't timed pass by pass.
- **Saves.** The solver keeps no state between calls (only scratch), and no
  save says which tick wrote it: a save loads and runs on under either tick.

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
tools/test.sh                         # the whole suite, on the native tick
SLIME_TICK=gdscript tools/test.sh     # the whole suite, on the GDScript tick
tools/build_native.sh --test          # Linux debug build, then test_native_*
```

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
  source with one change); `use_native` on, off and refused; the stub
  passes falling back (native on and off, 240 ticks: the same arrays and
  dump).

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

**Caveat: the native tick won't match the GDScript tick bit for bit.**
GDScript mixes precisions (`float` is a double, `Vector2` components are
32-bit, so is `PackedFloat32Array`), and a C++ port won't round at
exactly the same places. Its `atan2`, `sin` and `cos` also come from the C
library (glibc on Linux, bionic on Android), whose last bits can differ. So
state hashes compare within one build: the same library gives the same run
every time, which is what the end-to-end tests need. Golden hashes recorded
with the GDScript tick have to be recorded again after the port, and a
Linux hash isn't expected to equal an Android one. The flags above keep
basic arithmetic and `sqrt` identical across builds; cross-platform
equality would also need our own `atan2`, `sin` and `cos`.

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
change. Behind it:

- **The native solver** (`SlimeSolver`) runs the solver part of the tick:
  substeps of integrate, the pair grid (first substep), slime contacts,
  ring constraints, terrain contact (the shut doors too), then the touching
  list and the rest pass with the local wake. It reads and writes the
  `SlimeBodies` arrays (see "The marshalling") and keeps nothing between
  calls but scratch (the pair grid, the door boxes).
- **The terrain:** `TerrainSegments` still bakes its segment arrays and grid
  in GDScript at level load; the solver reads them, read only (D97).
- **What stays in GDScript:** the hop clears and the automatic hops (each
  slime's random stream: all randomness stays in the one seeded generator),
  the support reset, the topology changes (`create`, `remove`, `merge`,
  `split`, `_reshape`, `_resample`), the saves (`body_of`, `set_body`),
  `dump()`, the public wakes, and all the behaviour code (the train, the
  calls, fusion, Offscreen, the loop-start queue).
- **Pass by pass.** Each pass is ported and tested on its own against the
  GDScript one (units U1 to U5); `step` then runs them all in one call
  (U6), and the golden hashes are recorded again for the native tick.
