# Performance reports

Measurement sessions and performance reviews, kept for later comparison.
The tooling and the bench tables live in `docs/dev/README.md`
("Demo and bench", "Chunk 22").

| Date | Report | What |
|---|---|---|
| 2026-09-30 | [S20 FE session](2026-09-30-s20fe-session.md) | First full-game measurement on the reference phone: collapses to 2–5 fps with crowds on screen |
| 2026-09-30 | [Independent review](2026-09-30-independent-review.md) | Where the time goes (the fixed step's catch-up, the GDScript solver, a basket's releases waking its pile), ranked fixes, native tick verdict |
| 2026-10-03 | branch `archive/fps-session-2026-10` (`bcaa8b7`) | The withdrawn fps session (chunks 22d–22j, D145–D154; D155): its perf reports for 22e, 22f, 22g, 22i, D152 and 22j, the probes and the occupancy and bucket sweeps live on that branch only. Kept on main: the local wake (D156, chunk 22l: s3-basket-59of60 25.4 → 35.0 fps under phone emulation), the hop counters, stress-dense and `tools/thru.gd` (chunk 22m) |
| 2026-10-03 | [S20 FE session](2026-10-03-s20fe-session.md) | Real phone after the local wake (build fdae364): s3-basket-59of60 55.8 fps, stress-dense 41.3, stress-moving 22.6 over the first 60 s, no throttling; DoD 30's three targets pass; s3-basket's later section-1 cluster (80–100) drops to 18–23 fps; a tick costs ~11 ms even with 20–30 physics slimes |
