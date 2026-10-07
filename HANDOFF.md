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

## Phase 2 (2026-10-06/07): the climb

Phase 2a was cut off by an API error (529) after its runs; phase 2b (a fresh
executor) reviewed its code, finished the tests and wrote this. Raw outputs, scripts
and the table generator: docs/perf/exp-dipjam-p2/ (`out/m_*` the matrix,
`tests/summary.txt`, `python3 docs/perf/exp-dipjam-p2/table.py m`).

### Variants (SLIME_DIPJAM tokens, src/sim/train.gd, src/sim/slime_bodies.gd)

- `g` hold on a climb: a grounded train slime between hops on the outgoing route, on
  a rise over 0.1 (up to GRIP_MAX_SLOPE), active, has its motion down the slope
  cancelled after GRIP, plus HOLD_LIFT 0.5 of a tick's pull along the slope up it
  (`SlimeBodies.hold_on_slope`). The return route (`_carry`) untouched. Reviewed: does
  what it says; alone on a rise it still slides 1.6 px/s (vs 12.9): exact cancelling
  under the two Verlet substeps would take 0.75 (not tried).
- `h` hop over the queue on a climb: route rising over 0.2 across the reach, the
  usual target a plain ahead target, a non-partner train slime within reach: aims at
  the first free gap past it (OVER_ROOM 4 px from each side, within MAX_REACH_FACTOR
  of the reach), apex raised (6 tries, 12 samples) until the flight clears every
  slime it passes; else the usual hop. Reviewed: does what it says, but it seldom
  fires (DJ_OVER, s3 seed 1: taken 81 of ~2,250 climb hops; cap 719, no_gap 700,
  partner 477, clear 148): a packed queue has no gap within reach, and the reach a
  gap needs exceeds hop_cap().
- `r` the relay (phase 2a's extra): when a train slime takes off, the standing train
  slime right behind it (within its reach of touching it, on the outgoing route) has
  its hop timer cut to 0.15 s: it follows into the room just made, a wave down the
  queue.
- Combos: g,h; g,h,v1s; g,r; g,r,v1s; g,h,r.

### s3-basket-59of60 (seed 1 / seed 2, 14,000 ticks, camera held on the start from 9000)

Per 600 ticks from 9000: arr (arrivals), x240 / x750 (forward crossings). clu: the
largest awake cluster with a slime within 240 px of the start (rule 23's limit is
20), max and mean; >20 run: its longest run above 20, s (the late part is 83 s).
Climb speeds: the start basin's exit (loop 460-1150) ; the bowl's exit (17580-18180).
Slide: grounded train slimes between hops on a rise, px/s down the route (negative
is up), in brackets those touching no slime. stuck/stall/oob/lost were 0 in every run.

| variant | arr | x240 | x750 | clu max | clu mean | >20 run s | short | adv med | climb start ; bowl px/s | slide (alone) | fus/min | stack/landings |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| base | 17.6 / 18.0 | 7.2 / 7.2 | 2.5 / 3.1 | 118 / 117 | 80 / 81 | 79 / 80 | 0.87 / 0.87 | 1.7 / 1.5 | 26 / 31 ; 17 / 14 | 2.0 / 2.3 (12.9 / 13.3) | 17.0 / 16.2 | 2148/3571, 2215/3678 |
| g | 17.5 / 17.5 | 7.6 / 8.1 | 3.2 / 3.2 | 112 / 111 | 75 / 73 | 77 / 75 | 0.85 / 0.85 | 2.3 / 2.3 | 35 / 34 ; 17 / 20 | -4.8 / -5.2 (1.6 / 1.5) | 13.6 / 13.6 | 2055/3559, 1913/3457 |
| h | 15.2 / 17.2 | 7.0 / 7.5 | 2.2 / 2.8 | 121 / 116 | 80 / 73 | 83 / 76 | 0.88 / 0.86 | 1.4 / 1.7 | 27 / 30 ; 15 / 15 | 1.5 / 2.1 (12.7 / 12.6) | 12.3 / 13.9 | 2185/3602, 1999/3449 |
| g,h | 16.9 / 16.8 | 7.1 / 7.0 | 3.2 / 3.1 | 110 / 111 | 64 / 65 | 70 / 71 | 0.84 / 0.82 | 2.5 / 2.5 | 33 / 33 ; 19 / 24 | -4.5 / -4.6 (1.6 / 1.5) | 11.8 / 11.8 | 1749/3339, 1743/3275 |
| g,h,v1s | 16.4 / 16.5 | 7.1 / 7.2 | 3.5 / 3.1 | 108 / 113 | 62 / 66 | 71 / 73 | 0.83 / 0.83 | 2.7 / 2.5 | 38 / 35 ; 19 / 24 | -4.4 / -4.7 (1.7 / 1.6) | 12.3 / 9.8 | 1737/3394, 1806/3402 |
| r | 18.1 / 17.5 | 10.6 / 10.0 | 6.5 / 5.4 | 99 / 99 | 64 / 74 | 72 / 79 | 0.85 / 0.88 | 2.8 / 2.3 | 38 / 33 ; 31 / 29 | 4.4 / 3.2 (11.2 / 11.4) | 9.5 / 11.6 | 3667/6870, 4176/7432 |
| **g,r** | 18.1 / 18.2 | 11.4 / 11.9 | **7.8 / 7.6** | 98 / 95 | 60 / 61 | 74 / 76 | 0.86 / 0.85 | 4.3 / 3.9 | 36 / 38 ; 33 / 31 | -5.5 / -5.6 (-0.2 / -0.2) | 7.7 / 7.2 | 3536/6939, 3688/7024 |
| g,r,v1s | 18.5 / 18.2 | 11.6 / 11.2 | 7.8 / 7.0 | 95 / 99 | 63 / 65 | 74 / 75 | 0.85 / 0.86 | 3.9 / 3.8 | 46 / 35 ; 34 / 32 | -5.9 / -5.7 (0.1 / -0.1) | 9.5 / 8.5 | 3716/7145, 3726/7198 |
| g,h,r | 18.1 / 17.8 | 12.2 / 10.4 | 7.8 / 8.1 | 102 / 89 | 70 / 57 | 78 / 73 | 0.87 / 0.83 | 3.3 / 4.8 | 38 / 49 ; 35 / 37 | -5.7 / -5.2 (-0.2 / 1.1) | 8.7 / 8.7 | 4224/7752, 3226/6683 |

### stress-dense (seed 1, 3600 ticks)

| variant | speed px/s | slow | short | adv med | fus/min | bumps | gathering | bowl climb px/s | slide (alone) | stack/landings | over taken |
|---|---|---|---|---|---|---|---|---|---|---|---|
| base | 16.3 | 0.83 | 0.93 | 3.8 | 21 | 15 | 26.0 | 20.6 | 4.1 (10.7) | 59/1140 | 0 |
| g | 19.3 | 0.78 | 0.90 | 4.2 | 22 | 16 | 26.1 | 24.5 | -2.7 (1.7) | 55/1088 | 0 |
| h | 16.1 | 0.83 | 0.93 | 3.8 | 22 | 18 | 26.2 | 19.5 | 3.7 (10.2) | 64/1138 | 19 |
| g,h | 19.2 | 0.77 | 0.91 | 4.2 | 22 | 14 | 26.2 | 24.3 | -2.7 (1.7) | 55/1084 | 4 |
| g,h,v1s | 22.2 | 0.58 | 0.93 | 4.3 | 21 | 17 | 2.2 | 26.0 | -2.8 (1.5) | 82/1540 | 10 |
| r | 23.6 | 0.64 | 0.92 | 4.2 | 26 | 9 | 30.0 | 41.2 | 2.9 (9.1) | 201/1410 | 0 |
| g,r | 23.5 | 0.73 | 0.93 | 4.0 | 20 | 10 | 30.3 | 40.4 | -4.1 (1.3) | 65/1350 | 0 |
| g,r,v1s | 35.3 | 0.02 | 0.93 | 7.7 | 32 | 20 | 5.7 | 35.7 | -5.1 (0.3) | 247/2333 | 0 |
| g,h,r | 23.3 | 0.74 | 0.94 | 3.9 | 20 | 15 | 30.2 | 41.1 | -4.3 (1.5) | 62/1340 | 9 |

Determinism: g,r,v1s stress-dense 3600 run twice native and once GDScript, and g,h
1200 native and GDScript: equal hashes (0db68385..., ea266084...).

Tests (tools/test.sh -gselect=test_train 41, test_fusion 38, test_slime_hops 12, per
variant, tests/summary.txt): all pass for base, g, h, g,h, r, g,r, g,h,r; g,h,v1s and
g,r,v1s fail 1 in test_fusion (the A, B, A touching row: the front A no longer waits,
V1s's known, by-design break from phase 1).

### Reading

- G alone does what it is for (the slide alone 12.9 -> 1.6 px/s, the start's climb
  26 -> 35 px/s) but barely moves the flow (x750 2.8 -> 3.2): a held slime still
  waits for its timer.
- H is nearly inert: the gap it needs is seldom there or within hop_cap(); alone it
  is slightly worse than base.
- The relay is what moves the queue: r alone x750 2.8 -> 6.0, g,r 7.7 (2.7x base),
  the bowl's climb 2x, stress-dense speed 16 -> 24. G adds to it (no slide between
  the wave's hops) and cuts r's stacking on stress-dense (201 -> 65 of ~1,400).
- With V1s on top, stress-dense un-jams fully (g,r,v1s: slow share 0.83 -> 0.02,
  speed 35 px/s, fus/min 21 -> 32), s3 unchanged.
- **Recommended: g,r** (all three tests pass, no new state, two small hooks), with
  v1s on top if the user takes V1s (then its test and D119/rule 5's wording change).
- **The start still crowds**: arrivals ~18 per 600 ticks against ~7.7 leaving past
  750 px (2.3x); the largest cluster within 240 px stays 89 to 121 slimes in every
  variant (rule 23's limit 20), above 20 for ~75 of the late 83 s.
- Risks: fusions per minute on s3 fall with the flow (17 -> 7.7 with g,r; stress-dense
  holds 20-32); not explained yet (slimes past each other faster, fewer meet in a
  dip?). r's relay makes a wave: more hops (landings x2) and more stacking on s3
  (stack share about 0.5 of landings, as base's 0.6).

### g,r combined with the geyser (throwaway commit 05e9d15; revert it to drop)

Geyser C copied from exp/geyser 8b116e4 (`git diff main...8b116e4`, code only:
docs/perf/exp-dipjam-p2/geyser.patch is that diff); the dip-jam probe prints the
Geyser's counters (DJ_GEYSER). SLIME_GEYSER=off gives g,r's own hash (d73e7181...,
seed 1), so "off" is the table above. Base + geyser reproduces exp/geyser's report
exactly (launched/refused 75/96 ; 62/110, rejects route 1036/457 ...): the copy is
faithful. s3-basket-59of60, seed 1 / seed 2, same measure (outputs `out/gy_*`):

| run | arr | x240 | x750 | clu max | clu mean | >20 run s | fus/min | launched / refused | rejects route / ledge / room / flight |
|---|---|---|---|---|---|---|---|---|---|
| base, off | 17.6 / 18.0 | 7.2 / 7.2 | 2.5 / 3.1 | 118 / 117 | 80 / 81 | 79 / 80 | 17.0 / 16.2 | - | - |
| base, geyser | 17.8 / 17.8 | 7.4 / 7.8 | 3.4 / 2.9 | 119 / 121 | 76 / 77 | 74 / 72 | 14.4 / 13.9 | 75/96 ; 62/110 | 1036/457/18/5 ; 1037/458/14/2 |
| g,r, off | 18.1 / 18.2 | 11.4 / 11.9 | 7.8 / 7.6 | 98 / 95 | 60 / 61 | 74 / 76 | 7.7 / 7.2 | - | - |
| g,r, geyser | 18.2 / 18.2 | 12.2 / 11.8 | 9.0 / 8.6 | 90 / 85 | 51 / 50 | 65 / 56 | 5.1 / 5.4 | 72/116 ; 69/122 | 1118/549/26/6 ; 1141/495/49/23 |

- The geyser adds a little on top of g,r (x750 +1.1, cluster mean 60 -> 50) but does
  **not** find more free spots: it still launches only 36 to 38 % of the arrivals
  (base 36 to 44 %). Its rejects are the spots' geometry (off the route, under
  FirstLedge), which the flow doesn't change; "room" (a spot taken) even rises
  (18 -> 26 / 49). The start still crowds (cluster 85 to 90 against 20; arrivals
  18 vs 8.8 past 750 px).
- Fusions per minute drop further (7.7 -> 5.1).
- Tests with g,r + geyser: test_geyser 19/19, test_train 41/41.

### Next

- The start's crowd is not a climb-pace problem any more: with g,r the start's climb
  runs 36 px/s and the queue leaves at ~8 per 600 ticks, but ~18 arrive. Only fewer
  or slower arrivals at the return route's end (O118's pacing, rule 24's rate check)
  or more room/exits off the start can match it.
- If g,r is kept: explain the fusion drop on s3 first (fusion census at the dips with
  and without the relay), then production versions (no env token), docs and atoms.
