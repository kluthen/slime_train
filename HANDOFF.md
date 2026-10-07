# Health review S1: split src/sim/slime_bodies.gd (branch chore/health-s1)

Worktree: .claude/worktrees/health-s1 (from origin/main 51a7752, native libs
copied into addons/slime_native/bin). One seam per executor, one commit per
seam. See docs/dev/health-review-2026-10-07.md, section 7, S1.

## Seams

| Seam | File | State |
|---|---|---|
| 1, the solver | `src/sim/slime_solver.gd` (`SlimeSolverGD`) | done |
| 2, calm, rest and detail | `src/sim/slime_detail.gd` (`SlimeDetail`) | done |
| 3, the bodies' save | `src/sim/slime_bodies_save.gd` | next |

## Seam 1 (done)

- `SlimeSolverGD` (class_name; `SlimeSolver` is the native class): static
  `integrate`, `build_pairs`, `solve_contacts`, `solve_rings`,
  `solve_terrain`, `solve_against`, over the bodies' arrays. SlimeBodies
  keeps every array and thin `_integrate`, `_build_pairs`,
  `_solve_contacts`, `_solve_rings`, `_solve_terrain` that call them (the
  native equivalence tests call those).
- The bodies parameter `b` is untyped: test_native_solver.gd compiles a
  renamed copy of slime_bodies.gd, which isn't a SlimeBodies. Every local
  is typed by hand. Seams 2 and 3 meet the same test if they type it.
- Depth 5 -> 4: `build_pairs` scans each neighbour row's cells as one range
  of `_cell_items` (same pairs, same order); `solve_contacts` turns the push
  guard into a `continue` (`if still or not (d < r)`, NaN-safe).
- ATD: `rule_contact_pushes_slimes_apart` moved to `solve_contacts`
  (`atd check --atom` OK). Its atom text still names
  `SlimeBodies._solve_contacts` (the wrapper exists; documentalist may
  point it at `SlimeSolverGD.solve_contacts`).
- Sizes (effective LOC): slime_bodies.gd 1220 -> 866 (still ERROR > 600,
  12 atoms > 10); slime_solver.gd 413 (WARN > 400: the hoisted, hand-typed
  locals).
- Suite: native 1607/1607, GDScript pass 126/126, exit 0.
- Hashes: 38/38 on the native tick, 38/38 on the GDScript tick
  (docs/dev/native.md's table).
- GDScript tick, stress-dense, `--lead-in=3600 --phases`, median of 3:
  6.106 -> 6.129 ms per tick; solver 1799.5 -> 1776.6 µs. No change
  beyond noise.
- Docs: docs/dev/README.md ("Solver" and three function names), native.md
  ("The port").

## Seam 2 (done)

- `SlimeDetail` (class_name): static `crowd_count`, `park`, `unpark`,
  `wake_resting_in`, `set_detail`, `set_active_detail`, `can_rest`, `rest`,
  `rest_piles`, `_find`, `detail_points`, `rest_offset`, `resample`,
  `reshape`, and `_replace_slice` (the point-slice swap resample and
  reshape shared, same operations in the same order). SlimeBodies keeps
  thin wrappers with the same names (`_rest`, `_resample`, `_reshape`,
  `_can_rest` too: the tests and the solver call them). `_wake_at` and
  `_wake_around` stay in SlimeBodies (every mutation calls them; the
  atom's text names them there). `b` untyped, locals typed by hand.
- Kept in SlimeBodies for speed: `translate`, and the early returns of
  `park` / `unpark` (Offscreen calls them every tick for every slime, on
  both ticks; a first try that moved them whole cost the offscreen phase
  about +54 µs a tick on stress-dense). SlimeDetail.park / unpark take an
  index and do the transition only.
- ATD: `req_offscreen_simulation` moved with the code (6 tags in
  slime_detail.gd, removed from the wrappers; slime_bodies.gd keeps it on
  wake, wake_around, _wake_at, _wake_around, set_body and the header).
  `atd check --atom req_offscreen_simulation` OK. Atom count of
  slime_bodies.gd unchanged (12): seam 2 carried only that atom.
- Sizes (effective LOC): slime_bodies.gd 866 -> 696 (still ERROR > 600,
  12 atoms > 10); slime_detail.gd 244 (clean).
- Suite: native 1607/1607, GDScript pass 126/126, exit 0.
- Hashes: 38/38 native, 38/38 GDScript.
- GDScript tick, stress-dense, `--lead-in=3600 --phases`, median of 3:
  5.906 -> 5.893 ms (median ms/tick); step 5928.8 -> 5915.6 µs; offscreen
  1305.1 -> 1300.5 µs; rest 24.4 -> 24.1 µs. No change beyond noise.
- Docs: docs/dev/README.md (off-screen section intro, crowd detail's
  `_resample`, the phase timers' rest), native.md ("The port", the phone
  hash note's `_resample`).

## Next

Seam 3 (`slime_bodies_save.gd`): `dump()` and `restore()` for the bodies
(`create_with_id`, `body_of`, `set_body`, `dump`), about 60 LOC, per the
review. slime_bodies.gd is at 696: seam 3 brings it to about 640; the hop
helpers (`_auto_hops`, `_hop_at`, `_can_hop_at`) are the rest of the way
under 600. The 12 atoms in slime_bodies.gd are still > 10: seam 3 and the
hop helpers can carry some (req_hopping_behavior with the hops).
