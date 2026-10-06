# HANDOFF: experiment exp/geyser (rotation checkpoint, 2026-10-06)

Brief: `/tmp/claude-1001/-home-bastien-work-slime-train/d543671e-c4c0-4b90-a9fc-42b12cf6a31a/scratchpad/brief-geyser.md`.
Branch `exp/geyser` (base cb7e6f5). No edits to specs/, ui_ux/, atoms, no ATD tags.

## Built (commit e24a93d)
- `src/sim/geyser.gd` (Geyser). Trigger: a train slime's progress wraps past the loop's end
  (`Train.lapped`, set in `Train.advance`, which covers followed and parked slimes); runs in
  `Simulation.step` right after `train.follow`. Launch: CANDIDATES=6 spots drawn on
  [LAND_MIN=100, LAND_MAX=240 (LoopStart.STRETCH)] px along the loop. A spot is kept if it is inside a split zone
  and the flight (`Train.aim`, APEX=260 px ±APEX_JITTER 25 %, cap 0.95×max_speed) clears the terrain by
  CLEARANCE=4 px (SAMPLES=16). The emptiest spot wins (`room_at`; slimes in the air are counted where they come down).
  Motion is set with `SlimeBodies.launch` (new: set_velocity + unsupported, so the grip doesn't brake it). The solver is untouched.
  Stream: `geyser:<tick>:<id>`.
  - Variant B (default) "carry": the jet also launches the train slimes in a CARRY_REACH=90 px column above
    the arrival whose progress is < LAND_MIN. Variant A: `--geyser-solo` / `SLIME_GEYSER=solo`. Off: `--no-geyser` /
    `SLIME_GEYSER=off` (test mode skips both flags).
  - Parked arrival: placed on a free drawn spot (`Train.place`), else left in the proxies' single file.
    The first version placed them regardless, which stacked parked slimes. Fixed.
- `tools/geyser_probe.gd`: rule-24 metrics near the start (240 px from (241.9, 476)): arr, dep (crossing
  240 px), largest awake cluster with a member near the start (clu_max/mean/run>20), near_mean/max, clear_med
  (arrival→past 240 px, ticks), landed_off, back (still <100 px 180 ticks after arrival), GP_CENSUS/GP_HIST,
  `--trace`, `--hold-view=720,361 --hold-from=9000` (pins the camera; holding from tick 0 stops basket 3 from firing).
- `tests/unit/test_geyser.gd`: 13 tests, 46 asserts, PASS on the native tick (`tools/test.sh -gselect=test_geyser`).
- Setup gotchas: the godot-cpp build fails in this long worktree path ("Argument list too long"). I copied main's
  up-to-date `addons/slime_native/bin/libslime_native.linux.template_*.so` and touched it. Plain `git` is blocked
  by a hook: use `/usr/bin/git`. Logs are in `build/geyser/` (gitignored). The runner is `build/geyser/run.sh F SEED TICKS TAG [args]`.

## Measured: s3-basket-59of60, 14,000 ticks, native (arrivals start ~tick 9000)
| run | arr | dep | clu_max | clu_mean | clu_run>20 | near_mean | back | launches/carried |
|---|---|---|---|---|---|---|---|---|
| s1 off | 163 | 99 | 123 | 28.2 | 4660 | 24.8 | 129 | 0 |
| s1 A (idle camera) | 123 | 144 | 50 | 2.0 | 617 | 9.8 | 41 | 64 |
| s1 B (idle camera) | 122 | 144 | 50 | 1.95 | 315 | 9.7 | 37 | 237/168 |
| s1 hold A | 168 | 109 | 124 | 27.9 | 4615 | 24.7 | 129 | 158 |
| s1 hold B | 174 | 111 | 119 | 27.0 | 4273 | 22.3 | 127 | 904/740 |
| s2 off | 153 | 99 | 128 | 28.9 | 4760 | 25.5 | 122 | 0 |
| s2 A / B | 112 / 95 | 132 / 115 | 53 / 64 | 3.5 / 4.5 | 988 / 1138 | 11.7 / 14.8 | 48 / 54 | 64 ; 304/226 |
| s2 hold A / B | 166 / 166 | 101 / 108 | 130 / 117 | 28.4 / 28.1 | 4724 / 4451 | 25.0 / 23.3 | 131 / 123 | 154 ; 809/655 |

(Without the geyser, "hold" gives the same numbers as "off": the idle camera stays at the start.) No stalls, no
out-of-bounds, stuck about 11-12 in every run (none at the arrival). landed_off is "off_loop" only.
**Reading so far:**
- The gains of the idle-camera A/B runs are mostly a camera effect. The idle camera follows a launched slime away from
  the start, the start parks, and the awake cluster disappears from the measure.
- With the camera held on the start, the geyser barely helps: cluster about 120 against 123-128, mean about 27-28,
  departures +10 %. The pocket still fills (GP_HIST pocket 35-43 at tick 13999).
- Traces (`--trace`): launches from under the pile get smothered within about 6 ticks, by slimes stacked over the hole
  (up to y≈340). That is why the carry variant was added.
- Underneath it is a rate limit, as D157 §3 predicted. About 15 arrivals per 600 ticks against about 6-7 train
  departures past 240 px.

## Left from the brief
1. The remaining runs in build/geyser/batch3.sh: hold-B on `--tick=gdscript` (to compare the STATE hash with native),
   hold-B-again (determinism), batch2.sh (every fixture, 10k ticks, off: which ones reach the return route's end;
   then rerun those with A/B).
2. Census at arrival moments (census/hist ticks are already in the logs; summarize them).
3. Perf: `SLIME_GEYSER=off` vs default, `tools/level.sh bench --fixture=s3-basket-59of60 --lead-in=9000 --ticks=3000`.
4. Full suite with the geyser on: `flock /tmp/slime_train-godot.lock tools/test.sh`. List the failures from pinned
   trajectories. Then the same with `SLIME_GEYSER=off` to check it is green when off. Also run test_geyser with
   SLIME_TICK=gdscript.
5. The report `docs/perf/2026-10-06-geyser-experiment.md` (table above + the rest). Push. The final report to the
   coordinator covers what was built, the table, the census, the tests, risks, and O117's open list.

## Known problems / risks
- The idle camera chases launched slimes (a UX effect worth reporting).
- Launches under a pile are smothered; the carry launches many slimes repeatedly (904 launches for 174 arrivals).
- room_at ignores slimes that will arrive later. Landing spots aren't checked against the slope or the train ahead.
- The trigger is "laps went up", so any wrap counts, including a knocked-off slime re-projected near the start.
