# 06 Population: sleepers, species, the 200 cap

## What counts

- Every slime starts as the **first slime** (awake, in the start basin) or a
  **sleeper** (asleep, size 1, somewhere off the loop). The population is
  counted in base slimes: first slime + sleepers.
- **At most 200** per level (rule 16). The test level has exactly 200.
- A sleeper belongs to the section its stable ID names (`s2.sleeper.07` is
  section 2's); the first slime counts in section 1.

## Species per section (rule 11)

Section 1 has **exactly 3** species; each later section adds **exactly
one** new species (it may also hold earlier ones); the game has 6 (A to F).
The skeleton uses A, B, C, then D, E, F. A section that adds none, or two,
fails:

```
rule 11  PASS    The first section has 3 native species, and each later section adds one
         note: section 1: A, B, C
         note: section 2 adds D
         note: section 3 adds E
```

## Where they go

- Never on the loop (rule 17): more than 48 px from it.
- The first sleeper within a third of a screen of the first slime (rule 18),
  where the first call and the first-play hint pay off.
- Visible from the loop, or hinted at (rule 9); reachable by calls, without
  tilt (rule 10); on ground that leads back (rule 7); not on a low ledge
  over the loop (rule 22). See [05](05-branches-and-routes-back.md).
- Numbered left to right in their section, from `.01` (rule 20).

## Enough for the baskets

A basket's `quota` is weight: the base slimes the player must have woken by
then. Keep it well under what is available: the level report prints, per
frontier set, the base slimes of the sections so far:

```
set 1 (section 1): switch s1.switch, basket s1.basket, quota 4, opens gate s1.gate; available by then 8 (base slimes of sections 1 to 1)
```

"Available" counts every sleeper, reachable or not. Whether enough of them
can really be woken is the report's progress section: per basket, the base
slimes a called slime can wake by then, growing as same-species pairs fuse
into bigger slimes that hop higher ([10](10-the-level-report.md), reach and
progress). A basket it can't fill is a warning under rule 12 in the
checker ([09](09-check-the-rules.md)).

```
section 1: basket s1.basket, quota 4; awake by then about 6 base slimes (A 2, B 2, C 2), largest size 2: progresses
```

Order matters: section 1 starts with the first slime alone, so put a
sleeper a base slime reaches first, and a second of the first slime's
species early, so the pair can fuse and reach higher.

## Check it

```sh
tools/level.sh report --level=zz-tutorial
```

```
== population ==
section     A    B    C    D    E  total
1           3    2    3    -    -      8
2           1    -    -    3    -      4
3           -    1    -    -    3      4
level       4    3    3    3    3     16
base slimes: 16 of at most 200 (rule 16): PASS
species per section (rule 11: section 1 has 3, each later section adds 1): section 1: A, B, C; section 2 adds D; section 3 adds E: PASS
```

Rule 16's other half, big piles staying mostly still, is a MANUAL item.
Measure it with the level benchmark: it times every tick of the level as
new and of each fixture with a save (make a fixture of the crowded spot
first, [08](08-fixtures-and-testing.md)), and says per case how many
slimes are on screen, simulated off screen, parked off screen
(`off_screen`) or resting, and how many the solver works on (`active`):

```sh
tools/level.sh bench --level=zz-tutorial
tools/level.sh bench --level=zz-tutorial --fixture=gate1-open --ticks=300
```

An example of the output: a real run of the test level's three default
cases (`tools/level.sh bench --level=test`, on the development desktop,
2026-09-30). Your level, your fixtures and your computer give other
numbers; the shape of the lines is the same:

```
RESULT case=start base=200 bodies=200 ticks=600 lead_in=600 rested_at=- median_ms=0.960 p95_ms=1.050 max_ms=1.402 mean_ms=0.970 on_screen=1 simulated=3 off_screen=196 resting=0->0 zoom=1.000 camera_steady=true active=1.0 pairs=0.0
RESULT case=stress-still base=200 bodies=200 ticks=600 lead_in=407 rested_at=407 median_ms=0.983 p95_ms=1.067 max_ms=2.453 mean_ms=0.996 on_screen=139 simulated=1 off_screen=60 resting=140->140 zoom=0.500 camera_steady=true active=0.0 pairs=0.0
RESULT case=stress-moving base=200 bodies=200->133 ticks=600 lead_in=60 rested_at=- median_ms=10.354 p95_ms=12.654 max_ms=14.343 mean_ms=10.693 on_screen=128 simulated=4 off_screen=1 resting=0->0 zoom=0.500 camera_steady=true active=161.8 pairs=292.8
```

`stress-still` is a pile that stays still: 140 resting, nothing active,
about 1 ms a tick. `stress-moving` is the worst moving case on purpose:
all 200 woken as train slimes in section 3's bowl, 162 bodies active on
average, fusing down to 133 bodies, about ten times the cost.

A pile that stays still shows as parked (`off_screen`) or resting slimes,
few `active`, and a low, flat cost per tick (`p95_ms` near `median_ms`);
then play the spot in test mode to see it settle (a pile in a basket
rests).
