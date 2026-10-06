# exp/dip-jam, phase 1: hand-off (2026-10-06)

Experiment branch (throwaway until the user picks): the train's dip-nudge jam
(stress-dense's micro hops) and the train's flow past the loop's start
(s3-basket-59of60). No specs, ui_ux or atoms touched.

## State

- Variants behind `SLIME_DIPJAM` (comma-separated tokens, read once; unset = main's
  behaviour, checked: stress-dense 600/2400, stress-moving 600, bump 600/2400 give the
  hashes recorded in docs/dev/native.md, seed 909):
  - `v1` (src/sim/fusion.gd): gathering lets go when the train slime directly behind
    touches it and isn't a partner (another species, or past size 3).
  - `v1s`: v1 for another species only (a same-species slime past size 3 still keeps
    it waiting: keeps the `bump` fixture's 3 + 1 bump, D119).
  - `v2`: the 5 s wait for a partner further back counts the slime's own ticks held
    by gathering on that floor (`Fusion._held`, not in dump()/saves: a production
    version must save it), not the stall mark the queue's push resets.
  - `v3` = v1 + v2, `v3s` = v1s + v2.
  - `v4` (src/sim/train.gd): on a stretch rising 0.2 to 1.0, a standing train slime
    between hops grips 0.9 of its rigid motion per tick (GRIP 0.5 otherwise).
  - `v5` (extra, rejected): a train slime about to hop with the next train slime
    ahead less than half its reach away (not a partner) waits 0.25 s instead.
  - Debug counters `Fusion.fused_count` / `bumped_count` (not state).
- Probe: `tools/dipjam_probe.gd` (class doc has the output). Example:
  `SLIME_DIPJAM=v1s godot --headless --no-header --path . -s res://tools/dipjam_probe.gd --
  --fixture=s3-basket-59of60 --seed=1 --ticks=14000 --late-from=9000
  --hold-view=720,361 --hold-from=9000`.
- s3's flow numbers need the camera held on the start (`--hold-view`): with the idle
  camera, V2 seed 1 and V4 both seeds looked 3x better past 750 px only because the
  camera chased slimes away and the queue was parked (off-screen pace). Held, every
  variant equals the baseline.

## Numbers (native tick)

stress-dense, seed 1, 3600 ticks:

| variant | short | adv med px | gathering/tick | speed px/s | front px/s | slow share | fus/min | bumps | creep px/s |
|---|---|---|---|---|---|---|---|---|---|
| base | 0.93 | 3.8 | 26.0 | 16.3 | 195 | 0.83 | 21 | 15 | 13.6 |
| v1 | 0.93 | 4.2 | 1.7 | 19.2 | 196 | 0.63 | 23 | 4 | 13.3 |
| v1s | 0.95 | 4.0 | 2.3 | 16.4 | 184 | 0.65 | 22 | 16 | 13.6 |
| v2 | 0.94 | 4.2 | 4.1 | 16.8 | 196 | 0.71 | 21 | 9 | 13.3 |
| v3 | 0.93 | 4.2 | 1.8 | 18.0 | 187 | 0.53 | 24 | 4 | 13.5 |
| v3s | 0.94 | 4.1 | 1.5 | 17.3 | 189 | 0.64 | 22 | 5 | 13.3 |
| v4 | 0.90 | 4.0 | 23.9 | 18.0 | 206 | 0.87 | 21 | 11 | 10.6 |
| v3+v4 | 0.93 | 4.3 | 1.8 | 18.8 | 208 | 0.67 | 20 | 4 | 10.7 |
| v5 | 0.76 | 0.0 | 7.3 | 5.1 | 91 | 0.93 | 20 | 31 | 10.6 |

s3-basket-59of60, 14,000 ticks, camera held on the start from 9000; seed 1 / seed 2.
Per 600 ticks from 9000: arrivals, forward crossings of 240 and 750 px.

| variant | arr | x240 | x750 | short | speed px/s | fus/min |
|---|---|---|---|---|---|---|
| base | 17.6 / 18.0 | 7.2 / 7.2 | 2.5 / 3.1 | 0.87 / 0.87 | 40.9 / 42.1 | 17.0 / 16.2 |
| v1 | 18.2 / 17.9 | 7.5 / 7.9 | 2.9 / 2.8 | 0.87 / 0.88 | 40.4 / 41.7 | 17.0 / 16.2 |
| v1s | 18.0 / 17.9 | 7.6 / 7.9 | 2.8 / 2.8 | 0.87 / 0.88 | 40.6 / 41.7 | 17.2 / 16.2 |
| v2 | 18.0 / 17.6 | 7.5 / 7.8 | 2.8 / 2.9 | 0.86 / 0.88 | 41.4 / 40.9 | 16.7 / 16.5 |
| v3 | 18.0 / 17.9 | 7.9 / 7.9 | 2.9 / 3.0 | 0.87 / 0.87 | 40.7 / 42.3 | 17.2 / 15.4 |
| v3s | 18.0 / 17.9 | 7.9 / 7.6 | 2.9 / 3.0 | 0.87 / 0.87 | 40.7 / 42.1 | 17.2 / 14.9 |
| v4 | 17.8 / 17.0 | 7.4 / 7.2 | 2.8 / 3.0 | 0.87 / 0.85 | 40.4 / 42.1 | 15.4 / 11.6 |
| v3+v4 | 17.9 / 17.8 | 7.4 / 8.0 | 2.8 / 2.8 | 0.87 / 0.87 | 40.4 / 41.1 | 16.5 / 14.9 |

Determinism: v3 stress-dense seed 1 run twice on native and once on GDScript: the same
hash (b6999d06...). Tests (`tools/test.sh -gselect=test_fusion`, 38): base, v2, v4 all
pass; v1 and v3 fail 2 (the A, B, A touching row: the front A no longer waits, by
design; and the `bump` fixture's 3 + 1 bump never happens); v1s and v3s fail only the
touching-row test. No stalls in any run.

## What the census shows

- Baseline, 30 s: 32 train slimes held by gathering on the bowl's flat floor (y 76,
  x 15,800 to 17,300), a single file at 35 to 55 px spacing, every slime aiming 150 px
  ahead and landing 4 px on.
- V3, 30 s and 60 s: 2 to 3 held by gathering, but the same file stays on the floor:
  its front is on the bowl's exit climb (rise 0.24 to 0.49, zone s3.frame.basket),
  where slimes advance 0 to 160 px a hop and slide back 10 to 13 px/s between hops.
  The file moves at the climb's pace (about 10 px/s), so the micro hops stay (93 % short).
- s3 late (base, tick 12,000): no nudge at all; arrivals pile three deep in the start's
  split zone, then a single file up the start basin's exit climb (rise 0.72 to 0.75,
  x 660 to 1,200), creeping back 5 to 17 px/s, advance 0 to 10 px a hop.
- V5 shows the queue moves because the slimes behind push it: when they don't hop
  into the slime ahead, speed drops by two thirds.

## Verdict

- The dip nudge is not what jams the train. V1s (or V3s) takes the nudge out of the
  jam (gathering holds -92 %, slow share 0.83 -> 0.65) without hurting fusion
  (21 -> 22 per min) and keeps the 3 + 1 bump; it is the smallest and has no new state.
  But neither it nor any other variant changes the micro hops (still 93 % short) or
  s3's flow past the start (about 3 per 10 s past 750 px against about 18 arriving).
- What jams the train is how fast slimes get up a climb: the bowl's exit (stress-dense)
  and the start basin's exit (s3). V4's stronger grip cuts the slide back by about a
  quarter but gives no flow.

## Next steps (phase 2)

1. The climb: why one hop gains 0 to 160 px on a rise of 0.45 to 0.75 (aimed 150 px
   ahead at the slime above, landing back on the slope); try a hop aimed just past the
   slime ahead on a climb, or a real static grip (cancel gravity along the slope, not a
   share of the motion), measured on x750 with the camera held.
2. Pick v1s for the nudge if the user wants it anyway (then rewrite the touching-row
   test and D119/rule 5's wording; a v2 would need `_held` in dump() and saves).
3. Drop v5.
