# Desktop bench of both ticks (chunk 5N U7), 2026-10-05

Chunk 5N's native tick (`SlimeSolver.step`, one native call per tick)
against the GDScript tick, on the desktop, at HEAD 7043678 (unit U6). The
measuring rules are D142's: the tick at full speed, headless; a slowed run
only with `tools/perf_slow.sh --pin=main`; a phone figure is an estimate
until the phone's perf log settles it (unit U8).

## Machine and method

- **Machine:** AMD Ryzen 5 PRO 8640HS (6 cores, 12 threads), 11 GB, Debian 13
  (Linux 6.12), governor `powersave`, platform profile `balanced`, on mains.
  Godot 4.7.2-stable, the editor binary (a debug build), so the extension
  loaded is `libslime_native.linux.template_debug.x86_64.so` (built with
  `-O2 -ffp-contract=off`, the same optimisation as the release library).
- **Choosing the tick:** `SLIME_TICK=native` or `SLIME_TICK=gdscript` (every
  run printed its `TICK native (SLIME_TICK=native)` or `TICK gdscript
  (SLIME_TICK=gdscript)` line). The GDScript runs had the extension loaded
  too, unused.
- **Load:** `uptime` 1.34 (1 min) before the full-speed bench and 1.64
  after; 1.2 to 1.8 between its runs (the bench itself is about 1). Before
  the slowed runs 1.51, after 5.56; 4.3 to 5.6 between them, which is the
  slowed run's own two busy loops plus the game's threads. Nothing else ran
  in parallel: every Godot run took the same lock
  (`flock /tmp/slime_train-godot.lock`).

### Full speed, headless

```sh
SLIME_TICK=<tick> tools/level.sh bench --fixture=stress-moving --phases
SLIME_TICK=<tick> tools/level.sh bench --fixture=stress-dense --lead-in=3600 --phases
SLIME_TICK=<tick> tools/level.sh bench --fixture=s3-basket-59of60 --phases
SLIME_TICK=<tick> tools/level.sh bench --fixture=stress-still --phases
SLIME_TICK=<tick> tools/level.sh bench --fixture=fresh --phases      # the "start" case
```

Seed 909, 600 timed ticks after each case's lead-in: `stress-moving` and
`s3-basket-59of60` 60 ticks (the bench's default), `stress-dense` 3600 (as
in U0a), `stress-still` until its pile rests (420 ticks, 140 resting),
`start` 600. Three rounds; each round runs every case native then GDScript,
so the two ticks alternate. A figure below is the median of the three runs
of its mean (the bench's `mean_ms` and its `PHASES` line, µs per tick).

**Solver** is what 5N ports: on the GDScript tick the passes integrate,
pairs, contacts, rings, terrain, doors and rest; on the native tick the one
`native` lap (`step`: every pass, the touching list, the marshalling).
**Behaviour** is the rest of the step, all GDScript on both ticks (the
hops and the support reset included).

Both ticks ran the same trajectories: at the end of the timed ticks every
case had the same bodies, physics, parked and resting counts and the same
mean active slimes and pairs on both ticks (the state hashes are equal, see
"Hashes").

### Slowed: `perf_slow.sh --pin=main`

```sh
SLIME_TICK=<tick> tools/perf_slow.sh --pin=main --seconds=62 stress-moving --phase-timers
SLIME_TICK=<tick> tools/perf_slow.sh --pin=main --seconds=62 stress-dense --phase-timers
SLIME_TICK=<tick> tools/perf_slow.sh --pin=main --seconds=240 s3-basket-59of60 --phase-timers
```

Windowed (the Compatibility renderer), seed 1, no frame cap; after 3 s the
main thread alone is pinned to core 11, shared with two busy loops. The
numbers are `perf_summary.py` over the pinned `PERF` lines (t >= 6.9 s).
`s3-basket-59of60` runs 240 s to reach the section 1 crowd the S20 FE
session saw after about 150 s (`2026-10-03-s20fe-session.md`); its lines
are also summarised by the camera's section. No fixture starts with a
section 1 crowd. A slowed run plays in real time, so the two ticks don't
play the same game: the cap of 2 ticks a frame leaves the slower tick
further behind, and the crowds differ (see the physics column).

## Full speed: the numbers

Mean ms per tick, median of three runs; solver and behaviour in µs per
tick.

| Fixture | GDScript tick | Native tick | Change | GDScript solver | Native solver | Solver speed-up | Behaviour (GDScript / native) |
|---|---|---|---|---|---|---|---|
| `stress-moving` | 10.61 ms | 5.65 ms | -47 % | 5141 | 265 | 19.4x | 5462 / 5376 |
| `stress-dense` (lead-in 3600) | 5.68 ms | 4.09 ms | -28 % | 1682 | 92 | 18.4x | 3994 / 3992 |
| `s3-basket-59of60` | 5.81 ms | 3.17 ms | -45 % | 2764 | 146 | 18.9x | 3009 / 3021 |
| `stress-still` | 1.03 ms | 0.83 ms | -19 % | 219 | 22 | 9.7x | 804 / 804 |
| `start` | 0.97 ms | 0.82 ms | -16 % | 190 | 22 | 8.8x | 780 / 794 |

The three runs (mean ms per tick, native; GDScript):

| Fixture | Native runs | GDScript runs | Median per-tick ms (native / GDScript) |
|---|---|---|---|
| `stress-moving` | 5.591, 5.878, 5.646 | 10.196, 10.659, 10.608 | 5.227 / 9.950 |
| `stress-dense` | 4.139, 4.069, 4.088 | 5.720, 5.642, 5.679 | 4.059 / 5.627 |
| `s3-basket-59of60` | 3.172, 3.069, 3.312 | 5.807, 5.765, 5.826 | 3.164 / 5.585 |
| `stress-still` | 0.837, 0.821, 0.830 | 1.027, 1.020, 1.049 | 0.812 / 1.017 |
| `start` | 0.819, 0.800, 0.831 | 0.983, 0.969, 0.972 | 0.808 / 0.960 |

The cases at the end of the timed ticks (the same on both ticks):

| Fixture | Bodies | Physics | Parked | Resting | Active (mean) | Pairs (mean) |
|---|---|---|---|---|---|---|
| `stress-moving` | 200 -> 141 | 140 | 1 | 0 | 165.9 | 318.6 |
| `stress-dense` | 178 -> 175 | 56 | 119 | 0 | 57.7 | 59.4 |
| `s3-basket-59of60` | 200 | 53 | 110 | 0 -> 37 | 66.4 | 151.3 |
| `stress-still` | 200 | 0 | 60 | 140 | 0 | 0 |
| `start` | 200 | 1 | 196 | 0 | 1.0 | 0 |

### Per phase, µs per tick (GDScript / native)

| Phase | Kind | `stress-moving` | `stress-dense` | `s3-basket-59of60` | `stress-still` | `start` |
|---|---|---|---|---|---|---|
| integrate | solver | 346 / 0 | 156 / 0 | 192 / 0 | 51 / 0 | 49 / 0 |
| pairs | solver | 374 / 0 | 109 / 0 | 262 / 0 | 44 / 0 | 20 / 0 |
| contacts | solver | 2055 / 0 | 464 / 0 | 1143 / 0 | 1 / 0 | 2 / 0 |
| rings | solver | 1087 / 0 | 402 / 0 | 509 / 0 | 16 / 0 | 25 / 0 |
| terrain | solver | 836 / 0 | 343 / 0 | 372 / 0 | 18 / 0 | 27 / 0 |
| doors | solver | 360 / 0 | 183 / 0 | 185 / 0 | 82 / 0 | 60 / 0 |
| rest | solver | 73 / 0 | 24 / 0 | 101 / 0 | 6 / 0 | 6 / 0 |
| native | solver | 0 / 265 | 0 / 92 | 0 / 146 | 0 / 22 | 0 / 22 |
| fusion | behaviour | 2962 / 2933 | 1185 / 1187 | 331 / 343 | 5 / 5 | 7 / 7 |
| offscreen | behaviour | 376 / 375 | 1289 / 1294 | 1191 / 1197 | 311 / 310 | 404 / 408 |
| train_follow | behaviour | 565 / 557 | 606 / 606 | 521 / 508 | 37 / 36 | 43 / 43 |
| train_steer | behaviour | 756 / 755 | 261 / 263 | 182 / 183 | 1 / 1 | 8 / 8 |
| frontier | behaviour | 246 / 242 | 260 / 258 | 364 / 368 | 251 / 250 | 133 / 136 |
| loop_start_queue | behaviour | 155 / 159 | 162 / 164 | 131 / 131 | 5 / 5 | 7 / 7 |
| sleepers | behaviour | 127 / 127 | 32 / 32 | 71 / 71 | 1 / 1 | 1 / 1 |
| tidy | behaviour | 66 / 63 | 66 / 66 | 61 / 60 | 49 / 50 | 49 / 51 |
| split_zones | behaviour | 60 / 58 | 50 / 51 | 42 / 41 | 41 / 40 | 41 / 41 |
| camera | behaviour | 38 / 36 | 5 / 5 | 35 / 35 | 29 / 29 | 19 / 18 |
| free_follow | behaviour | 33 / 32 | 35 / 34 | 40 / 38 | 38 / 37 | 37 / 38 |
| auto_hops | behaviour | 31 / 31 | 29 / 28 | 30 / 31 | 25 / 26 | 25 / 26 |
| others (input, session, free_steer, tick_other, free_paced, face_hops, stuck) | behaviour | 16 / 14 | 13 / 12 | 14 / 14 | 12 / 12 | 7 / 7 |

## Reading

- **The solver part runs 18 to 19 times faster in crowds** (`stress-moving`
  19.4x, `s3-basket-59of60` 18.9x, `stress-dense` 18.4x), a little under
  the plan's 20 to 25 times, and about 9 times faster on the still scenes
  (`stress-still` 9.7x, `start` 8.8x), where what is left of it is fixed
  cost (see "The marshalling").
- **The tick drops by 16 to 47 %:** 47 % on `stress-moving` (10.6 to
  5.6 ms), 45 % on `s3-basket-59of60`, 28 % on `stress-dense`, 16 to 19 %
  on the still scenes. U0a's forecast for a 20x solver (`docs/dev/README.md`,
  "Chunk 5N: U0a phase timers") was -28 % on `stress-dense` (4.06 ms): met.
  The plan's "stress-moving ~10.6 -> ~3.5 ms" assumed a smaller behaviour
  part; behaviour there is 5.4 ms (fusion alone 2.9 ms).
- **The behaviour is now 95 to 98 % of the native tick** and unchanged
  between the ticks (within 2 %, the noise). Its floor in the crowds is
  fusion (0.3 to 2.9 ms), offscreen (0.4 to 1.3 ms), train_follow (0.5 to
  0.6 ms), train_steer (0.2 to 0.8 ms), frontier (0.25 to 0.37 ms) and the
  loop-start queue (0.13 to 0.16 ms). Porting any of it is outside 5N.

### The marshalling (U6's open risk)

`step` loads every field once and copies each read-write array once per
tick, the per-slime rest arrays included, then stores them back. On a still
scene that copy is most of what the native call does, so it would show
there first. It doesn't: on `stress-still` (200 bodies, 140 resting,
60 parked, no physics slime) the whole `native` lap is 22 µs (21.8 to
24.1 over the three runs) against 219 µs for the GDScript passes, and the
tick is 0.83 ms against 1.03 ms; on `start` (196 parked) 22 µs against
190. The 22 µs hold the reads, the copies, the stores and the passes' loops
over every slime (the walls, the parked and resting slimes), so the
marshalling is at most 22 µs a tick, 2.7 % of the native tick on a still
scene. The native tick is not slower than the GDScript one anywhere. Nothing
was optimised.

## Slowed (`--pin=main`): the numbers

Over the pinned `PERF` lines (t >= 6.9 s). Tick and behaviour: ms per tick;
frame: the frame's `process_ms` mean; outside: the frame's time outside the
ticks (`rest_ms`).

| Fixture | Tick | fps p50 / p5 | Tick ms | Ticks a frame | Frame (process) ms | Outside the ticks ms | Physics (min..max) | Solver µs (share) | Behaviour µs |
|---|---|---|---|---|---|---|---|---|---|
| `stress-moving` | GDScript | 15.6 / 12.4 | 27.04 | 2.00 | 55.2 | 12.1 | 135.9 (125..178) | 12587 (46.9 %) | 14244 |
| `stress-moving` | native | 29.0 / 21.0 | 11.73 | 1.86 | 22.7 | 11.6 | 126.2 (107..170) | 726 (6.3 %) | 10861 |
| `stress-dense` | GDScript | 17.0 / 15.9 | 23.28 | 2.00 | 47.7 | 12.8 | 70.7 (67..78) | 6045 (26.2 %) | 16986 |
| `stress-dense` | native | 22.8 / 20.7 | 15.31 | 1.92 | 30.2 | 12.1 | 69.2 (63..78) | 336 (2.2 %) | 14674 |
| `s3-basket-59of60`, whole | GDScript | 21.9 / 15.3 | 15.99 | 1.93 | 31.9 | 12.3 | 44.8 (6..100) | 4950 (31.4 %) | 10821 |
| `s3-basket-59of60`, whole | native | 31.6 / 23.3 | 10.94 | 1.76 | 20.1 | 12.6 | 56.7 (6..132) | 600 (5.6 %) | 10130 |
| `s3-basket-59of60`, section 3 | GDScript | 22.7 / 15.3 | 15.14 | 1.91 | 30.0 | 12.3 | 37.5 (6..100) | 4304 (28.9 %) | 10614 |
| `s3-basket-59of60`, section 3 | native | 33.7 / 25.6 | 9.71 | 1.68 | 17.1 | 12.7 | 32.8 (6..102) | 512 (5.4 %) | 9013 |
| `s3-basket-59of60`, section 1 | GDScript | 18.9 / 15.1 | 18.65 | 1.98 | 38.0 | 12.2 | 64.4 (9..94) | 6953 (37.8 %) | 11461 |
| `s3-basket-59of60`, section 1 | native | 25.4 / 22.7 | 12.85 | 1.89 | 25.4 | 12.3 | 89.9 (9..132) | 736 (5.8 %) | 11870 |

`s3-basket-59of60` reached section 1 at t = 150 s on the native tick (51
lines there, largest awake cluster up to 122) and at t = 187 s on the
GDScript tick (33 lines, cluster up to 81), the slower tick being further
behind real time.

- **The tick:** -57 % on `stress-moving`, -34 % on `stress-dense`, -32 %
  on `s3-basket-59of60` (-31 % in its section 1 crowd, with 40 % more
  physics slimes on the native run). The solver part runs 17 to 18 times
  faster on `stress-moving` and `stress-dense`, where both runs had the same
  crowd sizes.
- **fps:** `stress-moving` 15.6 -> 29.0, `stress-dense` 17.0 -> 22.8,
  `s3-basket-59of60` 21.9 -> 31.6 (section 1: 18.9 -> 25.4).
- **The behaviour floor, slowed:** 9 to 15 ms a tick on the native tick;
  the biggest phases are fusion (6.2 ms on `stress-moving`, 4.5 ms on
  `stress-dense`), offscreen (3.4 to 3.8 ms on `stress-dense` and
  `s3-basket-59of60`, about 3 times its full-speed cost) and train_follow
  (1.0 to 2.6 ms).
- **Outside the ticks:** 11.6 to 12.8 ms a frame on both ticks (drawing and
  the engine, on the slowed main thread): the native tick doesn't change
  it. Every crowded run still runs close to 2 ticks a frame, so the
  simulation stays behind real time on this emulation.
- Raw logs: `build/perf/desktop-<fixture>-slow-main-20261005-*.log`
  (gitignored, not kept).

## The phone estimate (D142)

The full-speed cost × 2.1 (the reference phone, cold) and × 3.4
(throttled). These factors were measured on the GDScript tick (spike 1,
`docs/dev/spike-soft-slimes.md`); the native code's own phone factor is
U8's to measure. The native-tick estimate applies them to the native lap
too, which is an assumption; it hardly matters, the native lap being 2 to
5 % of the native tick.

| Fixture | GDScript tick, cold / throttled | Native tick, cold / throttled | of which behaviour | of which native solver |
|---|---|---|---|---|
| `stress-moving` | 22.3 / 36.1 ms | 11.9 / 19.2 ms | 11.3 / 18.3 | 0.56 / 0.90 |
| `stress-dense` | 11.9 / 19.3 ms | 8.6 / 13.9 ms | 8.4 / 13.6 | 0.19 / 0.31 |
| `s3-basket-59of60` | 12.2 / 19.7 ms | 6.7 / 10.8 ms | 6.3 / 10.3 | 0.31 / 0.50 |
| `stress-still` | 2.2 / 3.5 ms | 1.7 / 2.8 ms | 1.7 / 2.7 | 0.05 / 0.07 |
| `start` | 2.0 / 3.3 ms | 1.7 / 2.8 ms | 1.7 / 2.7 | 0.05 / 0.07 |

For comparison, the S20 FE's measured debug-APK phase split of 2026-10-03
(`2026-10-03-s20fe-phases.md`, whole runs, GDScript tick) put the tick at
14.1 ms on `stress-dense`, 12.1 ms on `s3-basket-59of60` and 18.4 ms on
`stress-moving`, and the behaviour alone at 8.4 to 10.2 ms. Those runs
played 1 to 2 minutes of game from the fixture, so their crowds are not
the bench's; they say the same thing: on the phone, the native tick's floor
is the GDScript behaviour, about 8 to 11 ms a tick in the crowds.

## Hashes

All 18 fixtures of the test level, seed 909, headless test mode
(`--test-mode --level=test --fixture=<name> --seed=909 --run-ticks=<N>`), at
600 and 2400 ticks: the same hashes on the native tick and on the GDScript
tick, on this desktop, and the same on the native tick as U6's lists.
Recorded in `docs/dev/native.md` ("Fixture hashes"), as Linux hashes.

## Open questions for U8 (the phone)

1. **The native code's phone factor.** The solver lap is 92 to 265 µs at
   full speed on the desktop; what is it on the S20 FE (release template,
   cold and warm)? D142's 2.1 / 3.4 are the GDScript tick's.
2. **The behaviour floor on the phone,** release template: the debug APK
   put it at 8.4 to 10.2 ms (2026-10-03). If it alone breaks D138's 8 ms in
   the crowds, the next step is a spec decision (porting behaviour code is
   outside 5N).
3. **fps in the cases that matter:** `stress-dense` (target 30 fps),
   `stress-moving` (15 fps), `s3-basket-59of60` and its section 1 crowd
   after about 150 s (18 to 23 fps on 2026-10-03), on both ticks.
4. **Android hashes:** the native tick's state hashes on the phone are not
   expected to equal the Linux ones (the C library's `atan2`); two phone runs
   of one fixture should give the same hash.
5. **The marshalling on arm64:** on the desktop `step` costs 22 µs on a
   still scene; on the phone, does the native lap of `stress-still` stay
   well under the GDScript passes' (about 0.5 ms estimated)?
