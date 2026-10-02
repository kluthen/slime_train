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
  `-- --test-mode --fixture=X --seed=N`) and steps it with
  `Simulation.step()` replicated call for call, `Train.steer()`'s loop
  replicated too, so each decision is read in the exact state its own
  steer sees. A decision: a due train slime standing on something, or a
  holder at a re-check or at the cap. One CSV row each; a snapshot every
  120 ticks (the Train's hold snapshot, Physics, the largest awake
  cluster); the Train's counters at the end. It uses the Train's privates
  (`_records`, `_hold`, `_steer_one`) and Simulation's (`_pending_input`,
  `_apply_input`, `_face_hops`, `_tidy`): if either step changes, the
  hash check below fails and the probe must follow.
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
# the reference: must print the same hash as the probe's RESULT line
godot --headless --path . -- --test-mode --fixture=stress-moving --seed=1 --run-ticks=2400
python3 $P/hold_analyze.py $P/runs/*-seed?.csv
```

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
