# Handoff: health review phase 2a (branch chore/health-quick)

Rotated at about 90k tokens. The brief is the same (phase 2a quick wins); this
file says what is done and what is left. Delete this file in the last commit.

## Done (committed)
- Q6 (3dd854c): `ScreenView.set_to` and `Camera.place` refuse a zoom of 0 or
  less with `push_error`, leaving the view or camera unchanged. Tests updated
  (`test_screen_view.gd`) and added (`test_camera.gd`).
- Q3 (e27bb9c): `tests/unit/test_no_clock_in_sim.gd`, passes.
- Q4 (d181c34): `tick_choice.gd` and `decoration.gd` on the checker's
  TECHNICAL list. No atom covers O96 (decoration): the documentalist needs to
  know; decoration leaves the list once an atom covers O96's answer.
- Q12 (9d5e122): `DebugCounts.touching_by_distance` at depth 4 (helper
  `_append_touching`).
- Q7, Q1, Q8 (e2ccf33):
  - Q7: the readers `species_of` to `points_of` assert a known id. The first
    full run found 608 assert failures, all `state_of`, from 4 callers that
    iterate ids of removed slimes still held in Train's or FreeSlimes'
    records: `Train.follow`, `FreeSlimes.follow`, `Fusion._nudge`,
    `Offscreen._train_room`. They relied on the -1 default (same behaviour,
    not a gameplay bug). They now check `bodies.has()` first, the same
    branch. Targeted runs pass (offscreen_crowd, train_stalled, fusion,
    debug_overlay). The full suite has NOT been re-run since: it may still
    show another caller (the first run was stopped part way, in the e2e
    tests; its last failures, in `test_level_dod1_e2e`, were Train.follow's,
    fixed since).
  - Q1: `##` docs on the 25 public functions. The checker's doc errors are 0.
  - Q8: reason lines on `Offscreen.enabled`, `rest_enabled` and `auto_hops`.

## Left
- Re-run the full suite (both passes) and fix any remaining Q7 caller the
  same way (`has()` first).
- Q2: `src/main.gd:86`, drop "(proposed, chunk 22)" and cite D163. Then
  sweep the "proposed" markers in `src/` (`grep -rn proposed src`, about 41)
  against `specs/decisions.md`, dropping the settled ones.
- Q5: move the header-only ATD tags onto their function or type (the
  checker's `WARN atd ... only on the file header` list, 56 files), by hand,
  then `atd check`.
- Q11: rename `tools/dipjam_probe.gd` to `tools/train_flow_probe.gd` (update
  `docs/dev/README.md` and any tag line naming the file), split `_run` to
  depth 4 or less, its STATE line unchanged.
- O127: in the played test level e2e, assert D128's drain bound per basket
  (quota x 0.3 s + 10 s: basket 2 14.5 s, basket 1 11.8 s).
- The end: checker counts (before: src 35 ERROR, 192 WARN), full suite both
  passes, the 38 hashes on both ticks against `docs/dev/native.md`.

## Checker now
src 7 ERROR (size 1, depth 2, atd 4), was 35.
