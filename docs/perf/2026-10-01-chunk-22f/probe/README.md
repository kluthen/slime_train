# Chunk 22f hold probe

A read-only diagnostic of the hold (D147 (4)), written under 22e's rules
(`TrainHold`): what the crowd check and the jam check see at each hop
decision, and what the hop corridor would see there. Findings:
[`../../2026-10-01-chunk-22f.md`](../../2026-10-01-chunk-22f.md).
Since 22f step 3 the game runs the hop corridor: the probe's corridor
columns and the hold starts' causes come from the game's own check
(`TrainHold.check`, read right before the slime steers, after the tick's
holder snapshot, `TrainHold.begin_tick`), and 22e's disc and jam check,
gone from the game, are computed inside the probe (240 px, 30, 24 px) for
comparison. The committed `runs/` are step 2's (22e's rules); `runs/final/` holds the final part-2 build's runs.

- `hold_probe.gd`: loads a fixture in test mode (the same configuration as
  `-- --test-mode --fixture=X --seed=N`) and steps it with the game's own
  step, `game.step_simulation()` (the real `Simulation.step()` and
  `Train.steer()`, as `--run-ticks` does). Since 22g step 0 it copies
  neither, so it cannot drift from the game (22f's copy did: its
  stress-moving hash diverged), and it follows any change to `steer()`'s
  order (22g's `Train.front_first`) for free. To read the decisions it
  turns the Train, in place, into a `ProbeTrain` (an inner subclass,
  swapped in by `set_script` with every member kept) that wraps only
  `_steer_one()` (a hook before and after the real one) and `inherit()`
  (notes the split parts): each decision is read in the exact state its
  own steer sees (holder snapshot taken, hold guard run, the slimes before
  it steered, `set_rest` included). The guard's release and the guard
  window are read at the tick's first hook; everything else after the
  step. A decision: a due train slime standing on something, or a holder
  at a re-check or at its period's end. One CSV row each; a snapshot every
  120 ticks (the Train's hold snapshot, Physics, the largest awake
  cluster); the Train's counters at the end. It still reads the Train's
  privates (`_records`, `TrainHold._released`, `_holders`) and relies on
  `steer()` calling `_steer_one()` per slime; if the Train or the
  Simulation is replaced mid-run it stops with an `ERR` line. Not
  measured: on a tick where no slime steers, the guard window skips the
  tick (the guard's release is still logged).
- The hash check: at the end the probe frees its game, runs a fresh one
  on the same fixture, seed and ticks with `game.step_simulation()` only,
  and prints `PROBE_HASH probe=<8 hex> plain=<8 hex> match=yes|no`. It
  must say `match=yes`; `--no-check` skips it (half the time), `--plain`
  runs the plain step alone (no rows, no hook).
- `hold_analyze.py`: per run, the BEFORE row, readings (a)-(e) with a
  verdict, the hold start and end causes, back-of-queue hops by cause,
  and the corridor's occupancy by queue position with a threshold table.
- `thru.gd`: the throughput probe (22f part 2): steps a fixture with the game's own step and prints a
  `THRU_WIN` row per 600 ticks (loop crossings, stall and stuck moves, hops, the bowl's back half) and a
  `THRU_TOT` line (stall=, stuck=, hops=, guard=); used to calibrate `HOLD_OCCUPANCY`.
- `runs/`: the four runs of 2026-10-01 (`<fixture>-seed<N>.csv`,
  `-snap.csv`, `-totals.json`, `.log`; `-plain.log` the reference hash)
  and `analysis.txt`.

Run (one Godot at a time), from the repository root:

```sh
P=docs/perf/2026-10-01-chunk-22f/probe
godot --headless --path . -s $P/hold_probe.gd -- \
    --fixture=stress-moving --seed=1 --ticks=2400 --out=$P/runs/stress-moving-seed1.csv
# the last line: PROBE_HASH probe=08805799 plain=08805799 match=yes (at 9be1af7)
python3 $P/hold_analyze.py $P/runs/*-seed?.csv
```

A 2400-tick run with the check takes about 50 s on stress-moving and 27 s
on s3-basket-59of60 (the plain run included). At 9be1af7 the plain
hashes are stress-moving `08805799` (seed 1), `9b846317` (seed 2),
s3-basket-59of60 `82343b5f` (seed 1); the probe's own outputs on
s3-basket-59of60 seed 1 equal `runs/final/`'s byte for byte.

Columns: `ahead` train slimes ahead along the loop within 300 px (22e's
queue position; bins 0-2, 3-7, 8-14, 15+); `qpos`/`qsize`/`front` the
slime's place in its touching queue (`TrainQueues`); `count` the crowd
check's count (`awake_count_ahead`), split into `n_train` (awake train
slimes not holding), `n_hold` (awake holders), `n_other` (free and other
slimes); `n_behind` counted but behind along the loop; `n_missed` awake,
in the 240 px disc and ahead along the loop but outside the half-plane;
`n_rest` resting in the half disc (not counted today); `count_rest`,
`count_loop` (ahead along the loop instead of the half-plane),
`count_all_loop` (both: the coordinator's second option). Ahead along
the loop: a train slime by its record's distance, any other slime by
projecting its centre onto the loop within 400 px either side of the
slime's progress (a proxy). Corridor: `occ` occupancy, `n_corr` slimes in
it, `holder_corr` a holder in it outside the stack zone,
`holder_stack_only` holders in it, all in the stack zone, `crowd_corr`
the occupancy above the threshold (since step 3). `outcome`: hop,
pending (aimed, fires next tick: not a decision of its own),
start_crowd/jam/both (step 2's runs: 22e's checks) or
start_crowd/holder/both (since step 3: the corridor's), still, end_clear,
end_cap; `hopped` the hop fired this tick.

**Front-first order (chunk 22g):** both `hold_probe.gd` and `thru.gd` accept the game's
`--loop-buckets` and `--loop-bucket-length=PX` user args (after `--`), for the probe run and its
plain check alike; the game prints `LOOP_BUCKETS on length=…` when they apply.

**Bucket cap (chunk 22i, D151):** both also accept `--bucket-cap` and
`--bucket-cap-density=D` (forwarded the same way; independent of `--loop-buckets`, the bucket
length is `--loop-bucket-length`'s); the game prints `BUCKET_CAP on density=… length=…`. The bucket
loads are read with the switch on or off (`Train.bucket_loads()`, read only):

- `thru.gd`: `THRU_WIN` ends with `bucket_max,buckets_over` (the highest load of any loop bucket
  and the buckets over their cap, at the window's end); `THRU_TOT` ends with `bucket_holds=` (the
  "bucket full" hold starts; -1 from a build without the counter). Every 60 ticks it samples each
  bucket's load, and prints at the end `THRU_BUCKETS samples=… buckets=… density=… max=…
  buckets_over15=… crossings=…`, `THRU_BUCKETS top` (each loaded bucket's highest load / cap),
  `THRU_BUCKETS hist` (samples by load, every bucket's) and one `THRU_BUCKETS over15 tick=…
  bucket=… load=… cap=…` per bucket sampled over 15 after having been sampled at or under its cap
  (the bowl's starting overfill so stays out); `THRU_BUCKETS recut` if a gate opening changed the
  bucket count.
- `hold_probe.gd`: `-snap.csv` gains `bucket_max,buckets_over`; the totals gain
  `bucket_max_max`, `buckets_over_max` (over the snapshots) and, with the Train's counters,
  `bucket_holds`. The `PROBE_HASH` check is unchanged (it must still say `match=yes`).

```sh
P=docs/perf/2026-10-01-chunk-22f/probe
godot --headless --path . -s $P/thru.gd -- --fixture=s3-basket-59of60 --seed=1 --ticks=10000 --bucket-cap
godot --headless --path . -s $P/hold_probe.gd -- --fixture=s3-basket-59of60 --seed=1 --ticks=2400 \
    --out=$P/runs/s3-basket-59of60-seed1-cap.csv --bucket-cap   # the probe makes no directory
```
