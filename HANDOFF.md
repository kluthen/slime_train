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
- [ ] 2. Unit tests G and R
- [ ] 3. Full suite, triage, fixture hashes
- [ ] 4. Measure (probe) vs exp/dip-jam's g,r row
- [ ] 5. This file rewritten for part B (the geyser object)
