# feat/24g, part A: hand-off (in progress)

Chunk 24g part A: the climb fix G (hold on a climb) and R (the relay) ported from
exp/dip-jam (a3ea22f) into main's code as the plain behaviour. Brief: the
orchestrator's brief-24g-a.md. Worktree `.claude/worktrees/24g`, branch feat/24g.

## Steps

- [x] 1. Port G + R (src/sim/train.gd, SlimeBodies.hold_on_slope), probe kept
      (tools/dipjam_probe.gd, no variants; Fusion's debug counters), docs/dev/README.md
      ("Train": Hold on a climb, The relay; tools row). Checked: stress-dense seed 1
      3600 gives exp/dip-jam g,r's hash exactly (1f9fc954...), native and GDScript.
      TODO in step 4: a "Chunk 24g" section in docs/dev/README.md (the README's Train
      paragraph points at it) with the measures.
- [x] 2. Unit tests G and R: tests/unit/test_train_climb.gd (10; 6 pass on main's train.gd,
      the 4 core ones fail there: held, cancel, relayed, wave), both ticks
- [x] 3. Full suite, triage, fixture hashes. Run 1 (at 41dd284): 1514/1515 + 126/126,
      exit 1: test_new_level_e2e's 4-section skeleton, rule 2, a size 2 stalled (G held it
      knocked off the route on a 0.87 climb under a sleeper plate; its hops skimmed the slope
      and GRIP braked them away). Fixed (5b708ef): no hold when knocked off the route;
      test_no_hold_once_knocked_off_the_route. Run 2 (5b708ef): 1516/1516 + 126/126, exit 0.
      Hashes: 11 of 18 changed, both ticks equal, docs/dev/native.md re-recorded.
- [ ] 4. Measure (probe) vs exp/dip-jam's g,r row
- [ ] 5. This file rewritten for part B (the geyser object)
