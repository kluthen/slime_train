# Native tick (contingency, deferred by D96)

The slime simulation tick runs in GDScript. Moving it to native code (a
GDExtension in C++) is the **documented, verified contingency** of D96, not
something the game uses. This document covers why it was measured, what
would fire it, how to build and test it, and how the port would be done.

What is checked in: the toolchain (godot-cpp as a git submodule, an SCons
build, one build script) and a trivial extension, `SlimeNative`, verified on
the desktop and on the reference phone. It is kept out of the test suite and
the exports: `native/` holds a `.gdignore`, so Godot never registers the
extension on its own.

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

D96 still keeps the tick in GDScript: in play most of a big crowd rests in a
pile or a basket, and the cheaper fallbacks of chunk 15 (resting slimes and
sleepers stop simulating, fewer points when zoomed out, simplified baskets)
remove most of that cost.

## What would fire it

Chunk 22 measures the real game at the endgame (the bowl, a full basket, the
train) on both phones, cold and after 5 minutes. If either phone misses its
target (60 fps on the reference phone in normal play; at least 30 fps on the
floor phone with the level's largest realistic pile), chunk 5N moves the
tick to native code, as described in "The port" below, and chunk 22 is
repeated. See D96 in `specs/decisions.md` and "Simulation performance" in
`specs/tech-direction.md`.

## Layout

| Path | What it holds |
|---|---|
| `native/godot-cpp/` | godot-cpp, the C++ bindings, as a git submodule (see below) |
| `native/slime_native/` | The extension: `SConstruct` and `src/` (`SlimeNative`, the entry point) |
| `native/slime_native.gdextension` | The extension's descriptor: entry symbol and one library per platform |
| `native/bin/` | The built libraries (gitignored) |
| `native/.gdignore` | Keeps Godot from scanning `native/`, so the extension stays out of the tests and exports |
| `tools/build_native.sh` | The one build script |
| `tests/native/` | The extension's GUT test and `native_check`, which loads it and prints a report (not in `.gutconfig.json`) |

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
tools/build_native.sh --test              # Linux debug, then the GUT test
tools/build_native.sh -- verbose=yes      # after --, arguments go to SCons
```

The libraries go to `native/bin/libslime_native.<platform>.<target>.<arch>.so`
(`target` is `template_debug` or `template_release`), which is what
`native/slime_native.gdextension` lists (`linux.debug.x86_64`,
`linux.release.x86_64`, `linux.x86_64` as a fallback, `android.debug.arm64`,
`android.release.arm64`). godot-cpp's own static library goes to
`native/godot-cpp/bin/` (ignored by godot-cpp's `.gitignore`).

The first build of each platform and target compiles godot-cpp: about 2
minutes on this machine (12 cores). After that, only the extension's files
rebuild.

Android: the script finds the SDK at `$ANDROID_HOME`, or `~/Android/Sdk`,
and uses the newest NDK under its `ndk/` folder (set `ANDROID_NDK_VERSION`
to choose one). godot-cpp 10 defaults to NDK 28.1.13356709, which isn't the
one installed here (28.2.13676358), so the script always passes
`ndk_version`. The target is API level 24, the minimum SDK of the exports.
The C++ runtime is linked statically (`-static-libstdc++`), so the extension
doesn't depend on the `libc++_shared.so` of Godot's Android template.

## Testing

```sh
tools/build_native.sh --test
```

builds the Linux debug library, then runs `tests/native/` through
`tools/test.sh -gdir=res://tests/native/`, so it keeps `tools/test.sh`'s
guarantees (import first, run marker, exit code). The test loads the
extension at runtime (`GDExtensionManager.load_extension`, in
`tests/native/native_check.gd`), since Godot doesn't register it by itself,
and checks `version()`, `sum()` and the multiply-add probe. It fails, never
skips, when the library is missing or doesn't load.

`tools/test.sh` doesn't build or load the extension, and the default suite
passes without SCons, a compiler or the submodule. The post-run hook of the
default suite still loads `tests/native/test_native_extension.gd` to check
that it parses; it refers to `SlimeNative` only through `ClassDB`, so it
parses without the extension.

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

The game's export doesn't contain the extension (the `.gdignore`), so
checking it on the phone takes a temporary export, reverted afterwards:

1. `tools/build_native.sh --android`.
2. Remove `native/.gdignore`.
3. In `project.godot`, under `run/main_scene`, add
   `run/main_scene.native_check="res://tests/native/native_check.tscn"`.
4. In `export_presets.cfg`, add a copy of the spike preset with its own name,
   `custom_features="native_check"`, another package (for example
   `com.slimetrain.nativecheck`) and another export path.
5. Export it, install it, start it
   (`adb shell am start -n <package>/com.godot.game.GodotAppLauncher`), and
   read `adb logcat -v time -s godot:*`.
6. Put back `.gdignore`, `project.godot` and `export_presets.cfg`, then run
   `godot --headless --import` so `.godot/extension_list.cfg` drops the
   extension. Uninstall the check app.

Done on 2026-09-28 on the Galaxy S20 FE 5G (Android 13), Godot 4.7.2 debug
template:

- the APK held `lib/arm64-v8a/libslime_native.android.template_debug.arm64.so`,
  `assets/native/slime_native.gdextension` and
  `assets/.godot/extension_list.cfg`;
- the log:

  ```
  NATIVE_CHECK version="slime_native 0.1.0 (android.template_debug.arm64)" loaded_at_startup=true
  NATIVE_CHECK sum=7.0 (expected 7)
  NATIVE_CHECK mul_add=0.0 fused=false -> OK (no FMA contraction)
  ```

  So Godot loaded the extension from the APK at startup (not through the
  runtime load), and the arm64 build doesn't fuse multiply-adds;
- the "Android debug" and "Android spike: soft slimes" exports, with
  `.gdignore` back, contain no `slime_native` library, no `.gdextension` and
  no extension list.

## The port (chunk 5N, if it fires)

The GDScript `SlimeBodies` (`src/sim/slime_bodies.gd`) keeps its interface,
so its callers (the simulation, the train, the renderer, the tests) don't
change. Behind it:

- **A native solver class** (replacing `SlimeNative`) owns the per-point
  arrays (`pos`, `prev`, `rest_off`), the per-slime arrays the solver reads
  and writes, the tuning values, the pair grid and the touching pairs, and
  runs the substeps: integrate, pair grid, slime contacts, ring constraints,
  terrain contact. `SlimeBodies.tick()` calls it once per tick.
- **The terrain:** `TerrainSegments` still bakes its segment arrays and grid
  in GDScript at level load, then hands them to the solver once; the
  per-point queries run inside the tick (D97).
- **What stays in GDScript:** hop timers and each slime's random stream (all
  randomness stays in the one seeded generator), the choice of who hops, the
  rare topology changes if they aren't worth porting (`create`, `remove`,
  `merge`, `split`, which compact the arrays), and `dump()`. They reach the
  native arrays through a few calls (set a velocity, reshape a ring, add or
  remove a slice).
- **Reading back:** the renderer and the train read point positions and
  centres through `SlimeBodies` accessors, which copy from the solver once
  per tick.
- **Then it joins the suite:** `native/.gdignore` goes, so Godot registers
  the extension and the exports include it; `tools/test.sh` builds the
  Linux library when it is missing or older than the sources; the
  `tests/unit/test_slime_*.gd` tests run against the native tick unchanged;
  the golden hashes are recorded again.
