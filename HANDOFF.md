# Health review S1: split src/sim/slime_bodies.gd (branch chore/health-s1)

Worktree: .claude/worktrees/health-s1 (from origin/main 51a7752, native libs
copied into addons/slime_native/bin). One seam per executor, one commit per
seam. See docs/dev/health-review-2026-10-07.md, section 7, S1.

## Seams

| Seam | File | State |
|---|---|---|
| 1, the solver | `src/sim/slime_solver.gd` (`SlimeSolverGD`) | done |
| 2, calm, rest and detail | `src/sim/slime_detail.gd` | next |
| 3, the bodies' save | `src/sim/slime_bodies_save.gd` | to do |

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

## Next

Seam 2 (`slime_detail.gd`): the "Calm and detail" section, `_resample`,
`_reshape`, `_detail_points`, `_rest_offset`, per the review. Seam 3 after.
Then slime_bodies.gd should approach 600 with the hop helpers.
