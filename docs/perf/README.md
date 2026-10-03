# Performance reports

Measurement sessions and performance reviews, kept for later comparison.
The tooling and the bench tables live in `docs/dev/README.md`
("Demo and bench", "Chunk 22").

| Date | Report | What |
|---|---|---|
| 2026-09-30 | [S20 FE session](2026-09-30-s20fe-session.md) | First full-game measurement on the reference phone: collapses to 2–5 fps with crowds on screen |
| 2026-09-30 | [Independent review](2026-09-30-independent-review.md) | Where the time goes (the fixed step's catch-up, the GDScript solver, a basket's releases waking its pile), ranked fixes, native tick verdict |
| 2026-10-03 | branch `archive/fps-session-2026-10` (`bcaa8b7`) | The withdrawn fps session (chunks 22d–22j, D145–D154; D155): its perf reports for 22e, 22f, 22g, 22i, D152 and 22j, the probes and the occupancy and bucket sweeps live on that branch only. Kept on main: the local wake (D156, chunk 22l: s3-basket-59of60 25.4 → 35.0 fps under phone emulation), the hop counters, stress-dense and `tools/thru.gd` (chunk 22m) |
