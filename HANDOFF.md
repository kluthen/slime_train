# Handoff: fix/gobble (O91, a slime gobbled by another)

Branch `fix/gobble`, from main cb7e6f5. Commits: 0bd08a1 (the probe tool),
3a27d86 (the fix, its tests, docs). All committed, nothing uncommitted.
Brief: the session scratchpad's `brief-gobble.md`.

## Repro (headless, `tools/gobble_probe.gd`)

`SLIME_TICK=<native|gdscript> flock /tmp/slime_train-godot.lock godot --headless --no-header --path . -s res://tools/gobble_probe.gd -- --fixture=s3-basket-59of60 --seed=1 --ticks=18000`

Before the fix, s3-basket-59of60 seed 1, 18000 ticks, both ticks the same
(hash d0597aaa...): 156 overlaps, 139 lasting 2 s or more, the longest
7810 ticks with centres 0.0 px apart (ids 83/116, from tick 10190 to the
end, two size-1 train slimes of species 0 and 2, on the slide, held=1, at
the slide's end around (296,558)). The stuck net fired 11 times, all
between ticks 3870 and 4836, and never again while pairs sat on one
centre for minutes (not investigated: likely its mover waiting forever for
a free spot at a crowded loop start, LoopStart.free_spot NO_SPOT).

Where the deep overlaps come from (the probe's last-event column):
- parked train proxies (Offscreen._train_proxy) are put on the loop point
  at their progress; a pile with nearly one progress collapses onto one
  spot (tick 1: id 94 moved 42 px onto id 60's spot, still parked), and
  they unpark together (tick 4052: ids 83, 117, 144, 190 unparked at
  (16853,76) on one tick);
- the slide's carry (Train._carry) pushing slimes into the pile at the
  slide's end (x 260-400, y 500-590).

## Root cause

`SlimeBodies._solve_contacts` (and the native `contact_side`,
`native/slime_native/src/solver_contacts.cpp`) pushed a point of ring a
that is inside ring b straight out from b's centre. Once the centres are
closer than a's radius, a's facing points are past b's centre, so the push
moves them away from a's own centre: a is drawn into b, harder the deeper,
until the centres meet; then no point is inside the other and nothing
pushes. Proof (no gravity, no terrain, two size-1 rings of other species):
started 0.1 to 0.9 radius apart they end at 0.0 px within 20 ticks; 1.2
radius apart they part. Same on both ticks.

## The fix (3a27d86)

A point past b's centre (seen from a's: `rel.dot(cb - ca) > 0`) is pushed
along its offset mirrored across the line through b's centre square to the
centres' line: same size, on a's side; friction uses the same normal.
Nothing changes while the centres are at least a's radius apart. GDScript
and C++ line for line (native == GDScript exactly, tested).

After, same run: 69 overlaps, 3 lasting 2 s or more, the longest 300 ticks
(slide-end pile, they part), 0 stuck moves, top speed unchanged (1085
px/s); both ticks the same hash (9f988f1e...). Other runs, native, before
-> after (overlaps / lasting / longest ticks / stuck moves):
stress-dense s1 23/3/220/4 -> 0/0/0/0; stress-moving s1 19/15/700/7 ->
7/0/10/0; s3 seed 2 177/160/8340/11 -> 67/2/240/0; s3 seed 3
136/115/610/12 -> 22/0/20/0.

Risk: deep pairs now part with a pop, about as fast as an overlap of one
radius already did (no gravity: 300-650 px/s apart, against 250-470 for
the overlaps the old code resolved); in the game runs the fastest slime is
unchanged. Same-species pairs put deep inside each other now part rather
than staying merged until they fuse. Off-screen stacking (proxies on one
spot) is not changed: such slimes now part on unpark, off screen.

## Tests (all green at 3a27d86)

`tools/test.sh -gdisable_colors`: 1505/1505 native + 126/126 GDScript
pass, exit 0.
- New: `tests/unit/test_slime_deep_overlap.gd` (fails before the fix,
  2/52 asserts); a deep-pair exact case in `test_native_contacts.gd`.
- Changed: `test_stuck_slimes.gd`, `test_loop_start_queue.gd`,
  `tests/e2e/test_safety_nets_e2e.gd` made stuck pairs by putting two
  rings on one centre, which now part; they hold the pair (net-only
  stepping `_run_held`, or the second ring copied onto the first before
  every tick). 15 tests failed before this adaptation.

Fixture hashes (seed 909, 600/2400 ticks, both ticks equal): only
`stress-moving` changes, new 600 `82a46665c05acbecd6c97c4c56b4bbbdd5708dd94348e0e19e9777d98b14be5e`,
2400 `ff72e960523f27fd6543e9cfa7c98b1c51d5224bb98b5e246ce83f5d724d471f`.
The other 17 are unchanged. `docs/dev/native.md`'s table is NOT
re-recorded (the lead decides).

## Left from the brief

1. Decide whether to keep the fix; if kept, update the `stress-moving` row
   of the "Fixture hashes" table in `docs/dev/native.md`.
2. Push: `git push -u origin fix/gobble` (done at handoff if it succeeded).
3. Spec/atom side (O91, D100, D138c) for the lead: not touched here.
4. Optional follow-ups, not done: why the stuck net stopped moving after
   tick 4836 in the baseline (check `LoopStartQueue.due(sim)` at the end);
   proxies collapsing a pile onto one spot (Offscreen._train_proxy).

## Build notes for this worktree

`tools/build_native.sh` fails here: godot-cpp's archive command is too
long for this path ("Argument list too long"). Workaround used: main's
godot-cpp objects and `libgodot-cpp.linux.template_debug.x86_64.a` copied
in, then SCons' own compile and link commands for slime_native run by hand
(a script made from `scons -n verbose=yes`). The resulting library gives
the same hashes as main's before the fix.
