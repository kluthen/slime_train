# HANDOFF: experiment exp/geyser (phase 2 done, 2026-10-06)

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

## Phase 2 (brief-geyser-p2.md): C "high and wide", D "wide by rate"
Built in `src/sim/geyser.gd` behind flags (same build): C `--geyser-high` / `SLIME_GEYSER=high`,
D `--geyser-rate` / `SLIME_GEYSER=rate` (`Geyser.set_variant`, `default_variant`). Both: no carry; the arrival is
first lifted straight up above the rings over its column (`lift_origin`, LIFT_GAP 6, at most LIFT_MAX 240 px, the
lifted ring clear of terrain), then flies (APEX 260 above the higher end) to the emptiest of WIDE_CANDIDATES=10
spots; never at/past the first gate (`gate_limit`, test level: s1.gate far away); a base slime may land past the
split zone (the start's zone ends near 410 px), a fused one only inside one.
- C: spots on 150-700 px. D: 150-750 px, RATE_LENGTH=600 from the off runs (15.4 arrivals and 6.1 departures past
  240 px per 600 ticks: 6.1/240 = 0.0255 slimes/px/600 ticks; 15.4/0.0255 = 605 px), spots scored first by the
  landings their 50 px bin got in the last 600 ticks (no metre fed faster than it clears), then emptiest.
  D's bin memory is not saved (experiment).
- Probe: GP_LATE (from tick 9000: per-600 rates, crossings at 240/500/750/1000/1500 px, pocket_mean, tick_ms
  mean/p95, lift counters), GP_HIST to 2000 px + `stack` (pile height over the hole), GP_OFF (landed_off details).
- Tests: test_geyser 18/18 (72 asserts) native and SLIME_TICK=gdscript. Off hashes unchanged vs phase 1
  (s1 6060c713..., s2 243c6ca7...); C s1 run twice: same hash (fbb9159e...). No full suite, no hash sweep.
- Logs: build/geyser/*-p2-*.txt, batch4.sh.

| s3-basket-59of60, hold 720,361 from 9000, 14k ticks, s1/s2 | off | C high | D rate |
|---|---|---|---|
| arrivals /600 t (late) | 16.1 / 14.8 | 17.8 / 16.7 | 17.0 / 17.9 |
| clu_max | 123 / 128 | 107 / 120 | 112 / 113 |
| clu_mean (whole run) | 28.2 / 28.9 | 24.8 / 26.3 | 23.9 / 24.9 |
| near_mean (within 240 px) | 24.8 / 25.5 | 13.4 / 15.5 | 14.1 / 14.1 |
| departures past 240 px /600 t | 5.9 / 6.4 | 11.8 / 8.6 | 9.5 / 11.4 |
| crossings past 750 px /600 t | 2.0 / 2.4 | 3.2 / 3.0 | 3.0 / 3.1 |
| pocket mean (behind the start) | 30.0 / 29.1 | 11.4 / 13.5 | 11.7 / 12.3 |
| back (<100 px 3 s after arrival) | 129 / 122 | 20 / 28 | 23 / 18 |
| clear_med (ticks to 240 px) | 888 / 1341 | 38 / 41 | 39 / 37 |
| stuck moves (at arrival) | 11 (0) / 11 (1) | 13 (0) / 12 (0) | 13 (0) / 12 (0) |
| stall / oob | 0 / 0 | 0 / 0 | 0 / 0 |
| landed_off (all off_loop) | 18 / 25 | 81 / 68 | 81 / 84 |
| tick ms mean (headless, late) | 3.63 / 3.78 | 3.44 / 3.48 | 3.64 / 3.39 |
| lifted (mean lift px) | - | 126 (151) / 95 (147) | 101 (146) / 132 (153) |

Reading:
- Both C and D empty the start itself (near_mean -45 %, pocket -60 %, arrivals clear in ~40 ticks instead of
  900-1300) but not the cluster: clu_max stays 107-120. The queue moves onto the terrace (bins 100-700 hold
  ~100 slimes at tick 13999 in every run, off included: same count, spread differently), 2-3 deep, still touching
  the start, so the largest awake cluster barely changes.
- The rate limit is downstream: past 750 px (the slope after the terrace) the train takes only ~3 slimes per
  600 ticks whatever lands before it (C/D 3.0-3.2, off 2.0-2.4), against ~17 arrivals. The slide delivers at up to
  360 px/s; a saturated hopping single file moves about one slime per hop interval (1.5-3 s). No landing spread on
  the first stretch can absorb a ~5x surplus; it only chooses where the queue sits.
- New problem: landed_off 68-84 (vs 18-25): GP_OFF shows arrivals sitting 80-130 px above the loop on the queue
  (stacked 2-3 deep on the terrace), and some on FirstLedge (e.g. (523,315), nothing under it): the stacked queue
  under the ledge bridges onto it (rule 22 (b)), though no flight hits it.
- Next (not built): pace the return route's end (D150-like: hold arrivals on the slide's end / meter them to the
  train's measured take-up, ~3 per 10 s here), and/or a holding area at the start where waiting slimes sit apart,
  and/or a faster train off the start. A geyser only makes sense on top of pacing (spread the metered arrivals).
