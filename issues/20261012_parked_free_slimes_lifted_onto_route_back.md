# Issue: Parked free slimes are lifted onto the tree's route back

**ID:** `20261012_parked_free_slimes_lifted_onto_route_back`
**Ref:** `ISS-001`
**Date:** 2026-10-12
**Severity:** High
**Status:** Open
**Component:** `src/sim/offscreen.gd`
**Affects:** `src/sim/level_data.gd` (`branch_at`), `levels/test/level.tscn` (`s1.branch.tree`, `s1.route-back.tree`), every exploration branch whose box reaches down over the loop
**Seen on:** the user's play session (device and tick not recorded), test level, section 1, at the tree
**Reported by:** the user (playtest)

---

## Summary

Free slimes on the loop under the tree that go off screen are moved **up**
onto the tree's route back, and when several go off screen together they are
queued back along that route, onto the tree's platform. In play, a call toward
the tree's high sleepers that drags the camera up turns 4 slimes on the tree
into 15: the slimes called from the road below are teleported up there. This
breaks the tree as an exploration branch (it should take a big slime or a
mound to reach) and looks like a teleport to the player.

---

## What happens

### Expected

A free slime that goes off screen follows its way back to the loop at the
deterministic pace (master spec §5.3, D69). It never ends up somewhere it
couldn't have reached on screen, and never higher than where it was.

### Observed

The user: "there are a few slimes to catch that are quite high (require
probably a tier 3 slime, or a mound of slimes). Due to the frozen window
being a bit short, my screen went up a bit, and slimes that were 'undercall'
on the road below got teleported onto the s1.route-back.tree. Meaning: I
began with 4 slimes, the screen went up, I came back down, I had 15 such
slimes."

### How to reproduce

1. Test level, section 1, a train of 10 or more slimes on the loop under the
   tree (x 5,300 to 6,800).
2. Tap high on the tree, near the high sleepers on `TreeBough` (about
   6,200, -650). The call frees every awake slime within half a view width,
   train slimes on the road included (see ISS-002).
3. The camera's call drag (D45) moves the view up, toward the call point,
   so the road below leaves the view grown by `PARK_MARGIN` (384 px): the
   freed slimes are parked. *(guessed: whether the drag alone or the framing
   zone `s1.frame.tree` did it.)*
4. Bring the view back down: the slimes stand on the tree's platform and its
   back slope instead of on the road.

A test can do it without the camera: free 11 slimes on the loop at x 6,300
to 6,800, park them with a view far away, step one tick, read their centres.

---

## Cause

**Confirmed** in the code (not yet in a test).

1. **The tree's branch box covers the road.** `s1.branch.tree` is centred at
   (6,048, -505), 1,497.6 × 790: x 5,299 to 6,797, y -900 to -110. The loop
   below runs at y -84 to -124 there (`S1Loop`), drawn at a base slime's
   centre height, so train slimes from about x 6,200 on have their centres
   inside the box, and so does any freed slime hopping up toward a call on
   the tree. `LevelData.branch_at()` then says they are "in the tree".

2. **Off screen, a free slime in a branch is put on the nearest point of its
   route back**, whatever the height between them
   (`Offscreen._way_for()`, `src/sim/offscreen.gd:468-478`). The route back
   runs (5,702, -384) → (6,336, -384) → (6,739, -254) → (6,854, -121),
   along the top of `TreePlatform` and `TreeBack`. From the road at x 6,500
   (centre about y -125) its nearest point is about (6,500, -331), 206 px
   up, inside `ROUTE_NEAR` (288 px): the slime is moved up onto the tree's
   back slope (`_free_proxy()`, line 433, `bodies.translate`).

3. **The queue sends the others further up.** Every new proxy on a route
   back is put a slime's width (48 px for size 1) *behind* every proxy
   already there (`_queue()`, line 462: `way["along"] = ahead["along"] -
   spacing`). Behind on the route means toward its start, the top of the
   tree. With 11 slimes parked together, the last one is 10 × 48 = 480 px
   back along the route, onto `TreePlatform` at y -384:

   ```
   y   -650          [TreeBough]  ← the high sleepers
       -384   x──x──x──x──x──x──x──x──x──x─╮   ← queued proxies, along -= 48 each
                [TreePlatform]               ╲  TreeBack
       -125  ══════════ road (S1Loop) ═══════●══ ← where the slimes were
             5,300                    6,500  6,800
   ```

   If the queue is longer than the route behind the first point, `along`
   goes below 0 and `Polyline.point_at()` clamps it to the route's first
   point: several slimes then share one spot (5,702, -384), inside each
   other.

4. When the view comes back before they reach the route's end (a slow
   proxy pace, about 1,234 px of route), they are simulated again where
   they stand: on the tree.

---

## Spec and intent

- Master spec §5.3: "A free slime that leaves the screen is placed on the
  nearest point of its area's route back". The code does what it says.
- D69 (off-screen simulation), D18 / D45 / D51 (exploration branches and
  their routes back), level rule 8 (every branch has a route back).
- Atoms: `docs/req_offscreen_simulation.atom.md`,
  `docs/rule_exploration_branch_has_route_back.atom.md`,
  `docs/rule_left_alone_and_lost.atom.md`.
- Verdict: **spec gap** as much as a code bug. The spec never says a parked
  free slime may only be placed where it could get to (not above it, not
  across terrain), nor where the queue grows, nor what a branch's "area" is
  when its box overlaps the loop. spec-writer should settle the rule;
  the level rules may also want "a branch's box doesn't reach over the
  loop".

---

## Risk assessment

| Factor | Value |
|---|---|
| Likelihood | High: calling toward a high branch is the branch's whole point, and the call drag moves the camera there |
| Impact | High: slimes teleported up; the branch's challenge (a big slime or a mound) is skipped; slimes may land inside each other |
| Detectability | Medium: obvious on screen when it happens, silent in the logs (no "lost", no "stuck") |
| Current mitigation | none; the stuck net (D100) would separate slimes placed on one spot after about 2 s |

---

## Recommended fix

**Short term:** shrink `s1.branch.tree`'s box so its bottom stays above the
road (bottom edge above about y -200), so road slimes are never "in the
tree". A level edit; check the level rules and the level's test after.

**Medium term:** in `Offscreen._way_for()`, only take a route back point that
is **not higher** than the slime (or within a small rise), and otherwise
fall back to the loop's nearest point; in `_queue()`, never push a proxy
behind the point it was put on (queue it ahead, or let it wait there).
Clamp `along` at 0 in any case.

**Long term:** spec-writer states the rule for a parked free slime's way back
(only places it could reach; what "its area" is), and the level-rules
checker flags a branch box that covers the loop.

**Test:** a unit test in the style of `tests/unit/test_offscreen_slopes.gd`:
11 free slimes on the loop under the tree, parked in one tick, none placed
higher than it was, none two on one spot.

---

## Extra data

- Route back length: 634 + 424 + 176 ≈ 1,234 px.
- Size-1 ring radius 21 px, `EDGE` 3 px: queue spacing 48 px.
- The call radius at the tree's framing zoom (0.7) on a 1,152 px wide view:
  0.5 × 1,152 / 0.7 ≈ 823 px; wider on a phone (the aspect expands). So a
  call on the tree reaches most of the road under it.

---

## References

- `src/sim/offscreen.gd:414-478` (`_free_proxy`, `_queue`, `_way_for`)
- `src/sim/level_data.gd:155` (`branch_at`)
- `src/sim/polyline.gd:23` (`point_at` clamps below 0)
- `levels/test/level.tscn:808-829` (the tree: branch, route back, frame)
- `specs/versions/v1/master-spec.md` §5.3 (lines 366-378)
- Related: ISS-002 (the call frees every slime in range)

---

## Change log

- **2026-10-12**: filed from the user's report; cause read in the code.
