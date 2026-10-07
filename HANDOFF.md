# Chunk 22c hand-off (crowd detail only under load, D141)

Branch feat/22c, worktree `.claude/worktrees/22c`. Rotated at the
coordinator's request, during phase 3. Brief: the orchestrator's
`brief-22c.md` (scratchpad); scope: build plan "### 22c".

## State

- **Phase 1, done** (commit e8e383c): `src/platform/load_meter.gd`
  (`LoadMeter`, a Node, scene layer, every build; injected `clock`,
  `feed(busy_usec, ticks, speed)`; ~1 s windows; pressed / calm / band /
  dropped; ceiling 0..3; `stepped` signal; `parse_args` for
  `--crowd-detail`; `ceiling_for(mode)`). `Offscreen.detail_ceiling`
  (default 3, not in dump nor saves); `detail_level()` =
  max(zoom's, min(crowd, ceiling)). `src/main.gd`: `load_meter` child,
  `crowd_detail` (flag), `crowd_detail_mode()` (flag, else `always` in
  test mode, `auto` in normal play), `use_crowd_detail()` (release:
  ignored, says so; bad value: quit 1), `frame_speed`, the ceiling handed
  over in `step_simulation()` before `simulation.step()`, `load_meter.reset()`
  in `_use_simulation()`. Test mode accepts `--crowd-detail`.
  Tests: `tests/unit/test_load_meter.gd` (15),
  `tests/unit/test_crowd_detail_mode.gd` (7, the `always` guard),
  `tests/unit/test_offscreen_crowd.gd` (+4: ceiling caps, zoom under
  ceiling 0, not state nor saved, a save written in auto loads in every
  mode).
- **Phase 2, done** (commit 4fc34b6): PERF line gains `ceiling
  crowd_level detail busy missed` (after the parts, before `phases`);
  PERF_INFO gains `crowd_detail=<mode>` (printed deferred, so test mode's
  mode shows); `PERF_CEILING t= from= to= reason= busy= missed=
  crowd_level=` at each step, in `auto` only. `tools/android/perf.sh
  --crowd-detail=auto|always|off` (default auto, both modes), PERF_CEILING
  kept in perf.log. docs/dev/README.md: detail-levels paragraph, perf log
  fields, perf.sh option.
- **Phase 3, partly done:**
  - Full suite (after step 2): 1544/1544 native + 126/126 GDScript pass,
    exit 0 (scratch log full2.log). Re-run only if code changes.
  - Fixture hashes: 18 fixtures x 600/2400, seed 909: 36/36 identical on
    the native tick and 36/36 on the GDScript tick (vs docs/dev/native.md).
  - Desktop measures: done, NOT yet written into docs/dev/ (left to do).

## Measures so far (logs under build/perf/ in this worktree, git-ignored)

1. Normal clock, `tools/perf_slow.sh --full-speed --max-fps=60
   --seconds=120 s3-basket-59of60 --crowd-detail=auto`
   (`desktop-s3-basket-59of60-full-20261007-101823.log`): ceiling 0 the
   whole run, 0 steps; busy 0.25-0.36 (mean 0.30), missed 0, fps 58-60,
   crowd level up to 3. **Passes.**
2. Slowed, `tools/perf_slow.sh --pin=main --seconds=120 s3-basket-59of60
   --crowd-detail=auto` (uncapped, vsync off)
   (`desktop-s3-basket-59of60-slow-main-20261007-102104.log`): 0->3 at
   t=4.0, 5.0, 6.0 (the first 3 windows after the pin at ~3 s: **climbs
   within ~3 s**); held at 3 for 54 s at steady load; 16 steps in 2 min,
   most after t=57 when the crowd thins (physics 96 -> 10), plus a 0-1-0-1
   bounce at t=70-75.
3. Slowed and capped, same with `--max-fps=60`
   (`desktop-s3-basket-59of60-slow-main-20261007-105536.log`): climbs 0->3
   at t=4-6, but **32 steps in 2 min**: it cycles 3->0 over ~9 s then back
   up, at crowd level 3 throughout the first minute. **Thrash: fails "no
   more than a few steps".**

## Finding (for the leader; no spec change made)

The busy share never reaches the band on the slowed desktop (0.22-0.67
uncapped, 0.22-0.55 capped), so every verdict comes from missed beats,
which have almost no band (calm <= 1, pressed >= 3). At ceiling 3 the
device is calm (missed 0) -> 3 calm windows step down -> at a lower
ceiling it misses 3-13 beats -> pressed -> up. D141's no-thrash argument
rests on the busy band (60-85 %), which doesn't engage here. Options to
raise (spec-writer decides, not the executor): a hold-off after a pressed
step (e.g. more calm windows before stepping down below the last pressed
level), or a busy-share threshold that reflects the slowed main thread.
The phone may differ (vsync on); chunk 22's repeat measures it.

## Left in phase 3

- Write the measures and the finding into docs/dev/README.md: a new
  section "## Chunk 22c: crowd detail only under load" (referenced already
  from the detail-levels paragraph and the perf-log/perf.sh docs), placed
  before "## Technical choices" or after "## Chunk 24g": the meter, the
  ceiling, the modes, the PERF fields, the three runs above, the hashes.
- Commit "22c step 3: ...", push, report (<= 25 lines) per the brief.

## Decisions taken (to report as deviations or choices)

- A dropped window changes nothing (neither breaks nor counts in the calm
  run); a pressed window at ceiling 3 still resets the calm run.
- A missed beat = a frame that ran >= 2 ticks (at 1x; other speeds drop).
- `auto` also applies to a test-added game in normal play (the literal
  "game root in normal play"); the suite stayed green.
- PERF_CEILING printed in `auto` only; `busy`/`missed` on the PERF line are
  the meter's last window (any mode), not the perf log's window.
- No perf_summary.py change (it ignores the new fields and PERF_CEILING).

## Gotchas

- Godot runs under `flock /tmp/slime_train-godot.lock`; perf.sh never.
- After adding a class_name, `godot --headless --import --path .` once.
- rtk truncates long grep output: use `rtk proxy` or a python script.
- Hash check: `--test-mode --level=test --fixture=F --seed=909
  --run-ticks=N`, both `SLIME_TICK=native` (default) and `gdscript`.
