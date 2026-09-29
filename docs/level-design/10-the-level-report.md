# 10 The level report

A plain summary of the level's numbers, for design decisions: how long the
loop is, who lives where, whether the baskets can fill, what a call
reaches. It judges nothing but rules 11 and 16.

```sh
tools/level.sh report --level=zz-tutorial
tools/level.sh report --level=zz-tutorial --json
```

Exit code 0; 2 on a bad argument or a level that doesn't load. With
`--json`, stdout is the JSON alone (`tools/level.sh` starts Godot without
its banner); the header line and the sections below are its keys.

## What it says, section by section

The report on `zz-tutorial` at the end of this tutorial (3 sections, the
lookout added), shortened:

```
level_report: level zz-tutorial (version 1), 3 sections, 16 base slimes, first slime A
pace: a size-1 slime hops 66.7 px/s off screen (Offscreen.pace), slides 360 px/s (Train.SLIDE_SPEED)
== loop ==
loop at section 1 (gates open: none): 9.18 screens, outgoing 4.54 + return s1.slide 4.64; size-1 lap 93 s
loop at section 2 (gates open: s1.gate): 16.19 screens, outgoing 8.05 + return s2.slide 8.14; size-1 lap 165 s
loop at section 3 (gates open: s1.gate, s2.gate): 23.20 screens, outgoing 11.55 + return s3.slide 11.65; size-1 lap 237 s
```

- **Loop:** its length in every gate state, and a size-1 slime's lap time,
  worked out from the lengths and the paces. The checker's rule 1 notes are
  measured laps in the simulation, so they differ a little (106 s against
  93 s here).

```
== population ==
section     A    B    C    D    E  total
1           3    2    3    -    -      8
...
base slimes: 16 of at most 200 (rule 16): PASS
species per section (...): section 1: A, B, C; section 2 adds D; section 3 adds E: PASS
```

- **Population:** base slimes by section and species, against rules 16
  and 11 ([06](06-population.md)).
- **Sleeper rows:** each row's IDs, species, x span and branch.

```
== exploration branches ==
s1.branch.lookout: x 2.99 to 3.24, y -350 to -210 px; 2 sleepers; route back s1.route-back.lookout 0.29 screens, 5.0 s for a size-1 slime off screen: within left alone (10 s; lost 60 s later)
== frontier sets ==
set 1 (section 1): switch s1.switch, basket s1.basket, quota 4, opens gate s1.gate; available by then 8 (base slimes of sections 1 to 1)
set 3 (section 3): switch s3.switch, basket s3.basket, quota 4, no gate: the celebration, once every basket has fired; available by then 16 (base slimes of sections 1 to 3)
== framing zones ==
s1.frame.lookout: x 2.87 to 3.37, zoom 0.85, offset (0, -60)
```

- **Exploration branches:** each route back's length and time for a size-1
  slime, against left alone (10 s) and lost (60 s later).
- **Frontier sets:** each basket's quota against the base slimes available
  by then (every sleeper counted, reachable or not).
- **Framing zones:** span, zoom, offset.

The last two sections on the freshly scaffolded skeleton (2 sections):

```
== reach (a static estimate from the level's shape, to each row's easiest sleeper: play it to be sure) ==
a called hop rises at most (FreeSlimes.max_rise): size 1 133 px, size 2 168 px, size 3 208 px; it takes off from the loop's point least below the sleeper within a hop's reach sideways (150 px for size 1)
row 1.1: rise 110 px: reachable by a called size 1 hop from the loop
row 1.2: rise 110 px: reachable by a called size 1 hop from the loop
...
== progress (a static estimate: the base slimes a called slime can wake by each basket; play it to be sure) ==
section 1: basket s1.basket, quota 4; awake by then about 6 base slimes (A 2, B 2, C 2), largest size 2: progresses
section 2: basket s2.basket, quota 4; awake by then about 10 base slimes (A 3, B 2, C 2, D 3), largest size 3: progresses
```

- **Reach:** for each row, how high its easiest sleeper is over the loop,
  against what a single called hop of each size rises. The called slime
  takes off from the loop's point least below the sleeper within a hop's
  reach sideways (150 px for a base slime, more for bigger ones), so a
  hollow over a dip is reached from the dip's rim, not from the slope under
  it. It doesn't model obstacles or climbing in several hops (a slope,
  steps): a row reported "beyond" may still be reachable by a climb, and
  one reported reachable may be blocked by the ledge itself (a slime under
  a floating plate hits its underside). Play it.
- **Progress:** per basket, the base slimes a called slime can wake by
  then, and whether they fill its quota. It starts from the first slime,
  wakes every sleeper of the sections so far that a called slime of a size
  the train can make reaches, and every sleeper touching a woken one (a
  woken slime wakes the sleepers it touches: line sleepers up, centres at
  most 44 px apart, and one call wakes the line), lets same-species slimes
  fuse up to size 3 (a pair of A reaches what a lone A can't), and repeats
  until nothing more wakes. "MAY NOT PROGRESS" lists the sleepers out of reach; the
  checker warns about it under rule 12 ([09](09-check-the-rules.md)). The
  level's own test plays section 1 for real ([08](08-fixtures-and-testing.md)).

## Using it

- Section 1 must start with sleepers the first slime can wake at size 1:
  look for rows "reachable by a called size 1 hop" near the start, and for
  "progresses" on section 1's line. A row that needs a size 2 or 3 is
  fine once the train can make one: the progress line says whether it
  can by then.
- A quota close to "available by then" means the player must wake nearly
  everyone: leave room.
- A route back near 10 s makes slimes "left alone" often; near 70 s they
  risk being lost.
