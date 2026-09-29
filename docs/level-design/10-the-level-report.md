# 10 The level report

A plain summary of the level's numbers, for design decisions: how long the
loop is, who lives where, whether the baskets can fill, what a call
reaches. It judges nothing but rules 11 and 16.

```sh
godot --headless --path . -s res://tools/level_report.gd -- --level=zz-tutorial
godot --headless --path . -s res://tools/level_report.gd -- --level=zz-tutorial --json
```

Exit code 0; 2 on a bad argument or a level that doesn't load. With
`--json`, keep the last line (Godot's banner comes first).

## What it says, section by section

The report on `zz-tutorial` at the end of this tutorial (3 sections, the
lookout added), shortened:

```
level_report: level zz-tutorial (version 1), 3 sections, 16 base slimes
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

```
== reach (a static estimate from the level's shape, to each row's lowest sleeper: play it to be sure) ==
a called hop rises at most (FreeSlimes.max_rise): size 1 133 px, size 2 168 px, size 3 208 px
row 1.1: rise 117 px (from the loop under it): reachable by a called size 1 hop from the loop
row 1.2: rise 186 px (from the loop under it): reachable by a called size 3 hop from the loop
row 1.6: rise 167 px (from the loop under it): reachable by a called size 2 hop from the loop
```

- **Reach:** for each row, how high it is over the loop, against what a
  single called hop of each size rises. It doesn't model climbing in
  several hops (a slope, steps): a row reported "beyond" may still be
  reachable by a climb, and one reported reachable may be blocked by the
  ledge itself (a slime under a floating plate hits its underside). Play it.

## Using it

- Section 1 must start with sleepers the first slime can wake at size 1:
  look for rows "reachable by a called size 1 hop" near the start. The
  skeleton's bump rows (1.2 to 1.5 above) need a size 3, which section 1
  can't make at first: redesign them first.
- A quota close to "available by then" means the player must wake nearly
  everyone: leave room.
- A route back near 10 s makes slimes "left alone" often; near 70 s they
  risk being lost.
