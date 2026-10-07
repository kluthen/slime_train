# Slime Train v1 — Build plan

Status: draft v30 (D166: chunk 24 done but for 24.5's and 24.6's phone numbers: 24.1 met, 0d0935c; 24.2 done, f1861e1, a placeholder look; rule 23's train-queue exclusion done, c0924d9; the release hop done, 75040ed; next: session 7, which closes chunk 22's repeat, then the health review (its read-only phase running); the climb atoms at REVIEW, STABLE the user's to confirm; v29: D165, the user's: 24.8 withdrawn from v1; rule 23 doesn't count a train queue on the loop, item 24.7's follow-up; a released slime hops at once, item 24.3's follow-up, O126 closed; 24g's climb fix kept in v1, O125 closed; running: the two follow-ups and 24.2, then 24.1's record, session 7, the health review; v28: D164: 24.3 done, 18d1a86, basket 3's outlet over slide 3's drop, proposed; rule 23's basket exclusion built, b14f0d5, the test level passing in every section; next 24.8 (running), 24.2, 24.1's record, session 7, the health review; v27: D163: 24g closed, the relay's save and reload fix 5d7409f, merged 578ccff; 24.4 done, 61b8d5f, settled by the user, with 24.5's fixture `loop-start-pile`; 24.7 done, 5509f71, rule 23 now leaving a basket's own fill out, the user's; the tick cap settled and the phone frame budget a headroom target, the user's, so 24.1 gates on the frame rate and records the ticks; chunk 22 repeated on the S20 FE, session 6: DoD 30 met on three fixtures, the repeat open until session 7; the order: the fill's exclusion, 24.3, 24.8, 24.2, 24.1, session 7 and chunk 20's checks by hand, the health review; v26: 5N done, 0f3d027; 24g part A done, a0ffdde, its closure measured, 7595762, the relay across a save and reload being fixed; 22c done, 57d38e7, the hold after a bounce, proposed, D162; O122 answered, its acceptance proposed, D162; next: chunk 22 repeated on the S20 FE; v25: the geyser object and TL2 after v1, the user's, D161: their sections moved under "After v1"; chunk 24g kept as the train's climb (the hold on a climb and the relay, rule 24's run tool without the geyser), proposed, O125; the order after 5N: 24g, 22c, 22 repeated, the rest of 24, the health review; chunk 22's repeat judges DoD 30 with the loop start's crowding set aside, proposed; earlier, v24: chunk 24g restated: the geyser as a level object, the hold on a climb and the relay, the dip nudge unchanged, the start's measures recorded not gated; chunk TL2, the test level's start review, proposed, not a lock gate, its place the user's, O123; D160; earlier, v23: chunk 24g, the geyser and the train's flow off the start, before v1 closes, proposed next after 5N, D159; O91 fixed, 0061ccf; earlier, v22: 22h done, fccbb8e, 96725f1, as-built note under D150; 19w's as-built note under D149; 5N next, D158; earlier, v21: 5N next, after 22h, for headroom, D158; 19w done, fdae364; 22h step A done, fccbb8e; 22m part 2 done, 3b765f3; the real S20 FE of 2026-10-03; earlier, v20: 22l done, 600de6b, 5f6a6b0; 22m's fixture done, 4aac65a, its run tool being built; DoD 30's status on the phone emulation; earlier, v19: 22l: every wake local, D156 (7); `stress-moving`'s abuse target in chunk 22 and 24.1, D153; earlier, v18: the fps session after 0196c25 reverted, D155: chunks 22e, 22f, 22g, 22i, 22j and 22k withdrawn, kept on branch `archive/fps-session-2026-10`; chunk 22d done, 1a539db; new chunks 22l, the local wake, D156, and 22m, the `stress-dense` fixture and the 10,000-tick run tool, D153, D154, both being built with the revert; chunk 19w, the save wipe and the save format before the first store release, D148, D149, and chunk 22h, the loop-start queue, D150, re-entered; the order 19w, 22h, 22l, 22m, 5N, 22c, 22 repeated on the real S20 FE, the rest of 24, the health review, D155; approved by the user, 2026-09-29, D108; chunk 23 moved
before 18 and chunk LD added, D123; LD split into LD1 and LD2, and a
test-level fix for rule 22 (b) before 18, D126; R22 and LD3 done, chunk
TL1 before 18, proposed, D127; chunk 24, the user's second round of
playtest issues, last before the health review, proposed, D128; TL1 done,
D129; chunk 18 done, D130; chunk 19 done, D131; chunk 20 done on the
emulator, D132; chunk 21 done, D133; v1 is the test level only, and
chunk L01, the first real level, moves to v2, D134; v1 is the full MVP,
never in a store, DoD 32 deferred, D135; chunk 22 done, DoD 30 not
met, chunk 5N recommended, D138; chunk 24 gains 24.4 to 24.6, proposed,
D139; crowd detail merged; the order 22b, 5N, 22 repeated, 24, the health
review, proposed, D140; chunk 22c, crowd detail only under load, between
5N and 22's repeat, proposed, D141; chunk 22d, the debug counters,
between 22b and 5N, and chunk 24 gains 24.7 and 24.8, cluster avoidance,
proposed, D143; chunk 22b done, with item 24.6, the slowed-CPU method
`tools/perf_slow.sh --pin=main`, and the user's explicit go on 5N, D142;
D142 approved, and 24.7 and 24.8 approved in direction, D144)

This plan splits `master-spec.md` into build chunks, ordered so that each one
can be **tested as soon as it lands**. The master spec stays the reference for
behaviour. This document only settles the order, the size of each chunk, and
what "tested" means for it. Numbers in brackets such as [DoD 6] are the master
spec's Definition of done criteria (§9). Fixture names come from
`../../levels/test/README.md`.

## Principles

1. **Test backbone first.** Seeded randomness, time control and scripted input
   come before any gameplay, so every later chunk ships with automated
   tests on the Linux build.
2. **Risky things are checked before they are built for real.** The master
   spec's known technical risks (soft slimes at 200, vector look, headless
   tests, tilt) are checked with throwaway spikes first.
3. **Grow the test level with the features.** Section 1 (Meadow) is
   greyboxed early. Sections 2 and 3 are added when the features they
   exercise exist.
4. **The save format comes early**, because test fixtures are saves. It grows
   with each feature instead of arriving at the end.
5. **Desktop before Android.** Everything that can be tested on the Linux
   build is. Android-only work (pinning, device credential, sensors, lifecycle)
   is grouped into its own chunks.
6. **Placeholder interface.** The parent screens get working placeholder UI.
   Their real design comes from the UX track (`ui_ux/`), which has not
   started.
7. Each chunk goes through the six-step workflow below: ATD preflight,
   tests red to green, implement, verify, documents, ATD stewardship.

Sizes are relative: **S** is small, **M** is a few days of focused work,
**L** is large and a candidate to split further when it starts.

## Workflow for every chunk

Every build chunk goes through the same six steps,
in this order. A chunk isn't finished until step 6 is done.

1. **ATD preflight.** The documentalist finds the atoms that govern the
   chunk's area, starting from the chunk's "Atoms" line. It checks that the
   change is grounded in them and flags conflicts or missing coverage. A
   missing or conflicting atom stops the chunk until it is resolved. If the
   gap is in the spec itself, it goes back to spec-writer. ATD covers
   business behaviour only. Technical choices (structure, data formats,
   libraries, tooling) don't go through it: they are recorded in the project
   documentation in step 5.
2. **Tests first, red to green.** Write the tests for the chunk's "Done when"
   criteria first, and see them fail for the right reason. Unit tests go
   where the logic is pure. Scripted scenario tests through test mode, on
   the test level or a test scene, cover behaviour. A fixture that doesn't
   exist yet is created here.
3. **Implement** until the tests pass. Don't change a test to make it pass
   unless the test itself was wrong, and say so when that happens.
4. **Verify.** The chunk's "Done when" criteria hold. The whole suite is
   green, with no regression in earlier chunks. The run is repeatable (same
   seed, same result), and a debug run shows the behaviour on screen.
5. **Documents.** Keep the project documentation current: the README, the
   technical choices made in the chunk and why, how to run the tests, how a level component is configured in the editor, the
   fixture list. A place where the code had to differ from the spec is
   reported to spec-writer, not fixed silently in either one.
6. **ATD stewardship.** For the business behaviour the chunk built, the
   documentalist checks that every atom the chunk
   touched has `@spec-link` tags on the code that implements it and
   `@test-link` tags on the tests that verify it. It confirms the atoms still
   describe what the code does, and advances their status only with the
   user's agreement.

**Technical chunks skip the ATD steps (1 and 6).** They build tooling or
technology, not business behaviour:
- chunk 0 (tooling), chunk 3 (test backbone), chunk 5N (the native
  simulation tick), chunk 21 (the end-to-end suite) and
  chunk LD (the level-design toolkit, D123) still go test first. Chunk 5N changes no behaviour: the existing suite is its
  test. Chunk 0's only test is a trivial one, seen red then green, which proves the runner
  reports failures.
- The spikes (chunks 1 and 2) are throwaway code, so they also skip the
  test-first step. They end by writing their outcome (the numbers, the
  approach chosen) into the project documentation, and into
  `../../tech-direction.md` through spec-writer when it changes the
  spec's technical direction.
- Chunk 22 (performance) checks a business target, the frame rates promised
  on the reference and floor phones, so it keeps both ATD steps.

## Progress

- **Done:** 0 to 17; 1 on the desktop and the reference phone (the
  floor phone waits for its purchase). Chunks 14 and 17 raised O82 to O86
  (the session in the level's save, baskets at bedtime, the switch locked
  once the basket is full, the gate's lid, a state for slimes in a basket),
  settled in D104–D106.
  Chunk 15 built section 2 in greybox with the off-screen simulation.
  Chunk 16 (16a–16f; stewardship d487ae8): section 3 in greybox, the full
  population of 200, every fixture regenerated (with `gate2-open` added),
  the level-rule tests, the level bench, the terrain-contact fix and the
  cave's framing zone (16d), the whole-level DoD 1 test and the developer
  notes (16c-B), the start basin rebuilt so DoD 1 holds (16e), and the
  dip nudge's limited wait so a mixed queue no longer stalls (16f).
  Chunks 15 and 16 raised O87 (the rest rule's anchor), settled in D107;
  chunk 16 raised D116–D119, approved in D120, and O95, settled in D121
  (item 23.13).
- **Done:** chunk 23 (small issues from play, an open list, before 18,
  D123), sub-chunks **23A** safety nets (23.3, 23.13), **23B** taps and
  strips (23.2, 23.6b, 23.8), **23C** camera (23.1, 23.4, 23.10, 23.12)
  and **23D** bedtime baskets and the celebration's mark (23.5, 23.11).
  Their own values and choices, and three additive save-format changes,
  are recorded in D124, approved by the user (D125). **23E** objects and
  taps (23.6, 23.7, 23.9) is merged. Its own readings are in D126
  (proposed). New reports added to the list are placed after 23E.
- **Chunk LD** done: **LD1** (the tools), **LD2** (the tutorial and the
  project skills) and **LD3** (the tutorial's gaps: a playable skeleton,
  the progress estimate under rule 12, `tools/level.sh`, stale fixtures,
  the bench per level; D127). LD1's checker found a rule 22 (b) break on
  the test level (D126), fixed by **R22** (done: the second dip's hollow
  moved over the dip's far slope, D127).
- **TL1** done (D129): the test level is playable from fresh with base
  slimes alone (sleepers in touching lines within a called slime's
  reach; see `../../levels/test/README.md`, section 1).
- **Chunk 18** done (D130; 54873c1, suite 1041/1041): the parent gate and
  settings with a placeholder UI. Its choices where the spec was silent
  are proposed in D130, with its open risks.
- **Chunk 19** done (D131; c39ebc0, suite 1097/1097): persistence
  hardening (the level save's checked backup and read fallback, mid-air
  slimes grounded on load, migration by level version, `parent.json`'s
  mirror). Its choices where the spec was silent are proposed in D131,
  with its open risks.
- **Chunk 20** done on the emulator (D132; 72d3717, suite 1186/1186):
  the Android build and platform integration; DoD 25, 26 and 27 pass on
  the emulator. The checks on the user's S20 FE (tilt feel among them)
  are pending. Its choices where the spec was silent are proposed in
  D132, with its open risks.
- **Chunk 21** done (D133; ec518a0, suite 1198/1198): the end-to-end
  suite; every fixture has a scripted scenario and a same-seed hash test,
  and `tests/e2e/` passes in the exported Linux build [DoD 31]. Its
  choices where the spec was silent are proposed in D133, with its open
  risks.
- **Chunk 22** done (D138; DoD 30 not met). Crowd detail, the user's
  idea, merged after it (D140): helpful, not enough on its own.
- **Chunk 22b** done (D142; 5d9533a, suite 1318/1318, same hashes): the
  drawing pass. Drawing estimated within its 4 ms on the reference phone
  cold, over it throttled (4.2 to 5.3 ms); only chunk 22's repeat closes
  it. Item 24.6 (the debug labels) done with it. The slowed-CPU method is
  now `tools/perf_slow.sh --pin=main`.
- **Chunk 22d** done (1a539db, cherry-picked from 7437fd0 after the
  revert, D155; suite 1330/1330, the 17 hashes unchanged): the debug
  counters (Physics, On screen, In range, Parked on the bar; `resting`
  and `largest_cluster` on the PERF line). Numbers in
  `docs/dev/README.md`, "Chunk 22d". Its as-built record isn't in the
  decisions log.
- **The fps session after 0196c25 was reverted** (D155, 2026-10-03, the
  user's direction): chunks 22e, 22f, 22g, 22i, 22j and 22k are
  withdrawn ("Withdrawn chunks" below), kept verbatim on branch
  `archive/fps-session-2026-10` (at bcaa8b7). Kept from it: 22d, the
  atom split, `rule_saves_never_wiped` 1.1, chunks 19w and 22h (not
  built), the local wake (now 22l) and the `stress-dense` fixture (now
  22m). No number since the S20 FE session of 2026-09-30 comes from the
  phone itself.
- **Chunk 22l** done (600de6b, 5f6a6b0; suite 1339/1339): the local
  wake (D156's as-built note). `s3-basket-59of60`, phone emulation: 25.4
  -> 35.0 fps; only its hash changed.
- **Chunk 22m**, part 1 done (4aac65a; suite 1342/1342): `stress-dense`
  on main, byte for byte the branch's. Phone emulation: `stress-dense`
  22.9 fps (target 30, not met); `stress-moving` 16.1 mean, 5th
  percentile 13.0 (abuse target 15: met on the mean only, O115). Part 2,
  `tools/thru.gd`, the 10,000-tick run tool, done (3b765f3).
- **Chunk 19w** done (fdae364; suite 1365/1365): `--wipe-save` and the
  pre-release set-aside (D148, D149; as-built note under D149, with its
  deviations). Its on-device check (`perf.sh --wipe-save`) is left to
  the user (`docs/perf/2026-10-03-s20fe-session.md`, item 7).
- **Chunk 22h** done (step A fccbb8e, step B 96725f1; suite 1383/1383;
  as-built note under D150): no stall clock while parked; the
  loop-start queue and random free landings. `s3-basket-59of60`, 10,000
  ticks: stall 87 -> 0, stuck 234 -> 11; only `old-version`'s hash
  changed in step B. The start basin crowds when slimes come home:
  evidence for rule 24 (D157) and O117.
- **The real S20 FE, 2026-10-03** (build fdae364,
  `docs/perf/2026-10-03-s20fe-session.md`): DoD 30's three targets pass
  in the first 60 s (55.8, 41.3 and 22.6 fps); a warm section 1 crowd
  of 80 to 100 in `s3-basket-59of60` drops to 18–23 fps after ~151 s,
  and a tick costs ~11 ms even with 20 to 30 physics slimes.
- **Chunk 5N** done (0f3d027; the S20 FE session,
  `docs/perf/2026-10-06-5n-s20fe-session.md`).
- **Chunk 24g** part A done (a0ffdde: the hold on a climb and the
  relay); its closure measures done (7595762, on `chore/24g-close`): the
  fusion drop explained (O122 answered, D162), `stress-dense`'s census,
  the tick cost (+0.4 to +6 % native, mostly the relay's scan; judged
  within noise, D163). **Closed** (D163): the relay's save and reload fix
  landed (5d7409f, merged in 578ccff; ATD 459642e), since
  `SlimeBodies.train_hopped` wasn't state. `Train._behind`'s linear scan
  goes to the health review.
- **Chunk 22c** done (57d38e7; suite 1552/1552 native, 126/126 the
  GDScript pass, the 36 fixture hashes unchanged; as-built note D162):
  the load meter, the detail ceiling, the modes, and the hold after a
  bounce (proposed). Slowed CPU capped at 60 fps: 32 -> 5 ceiling steps
  in 2 min.
- **Watch (D162, proposed):** the lower fusion rate on
  `s3-basket-59of60` (about 17 -> 7.5 per minute) in chunk 22's repeat
  and the playtest; if fusion feels rare, a chunk 24 item.
- **Item 24.4** done (61b8d5f; settled by the user, D163): a displaced
  sleeper stays asleep. **Item 24.5's fixture** `loop-start-pile` done
  with it; its phone run waits for session 7.
- **Item 24.7** done (5509f71): rule 23's measure (`ClusterWatch`), its
  tests, the checker's line, the tutorial and the skill. The test level:
  sections 1 and 2 never above the limit; section 3 above it because of
  basket 3's fill, which the user has since left out of the rule (D163).
- **Chunk 22 repeated on the S20 FE, session 6** (2026-10-07, main
  cfe1dab, `auto`, native tick; D163): `s3-basket-59of60` 59.1 fps cold
  and warm, `stress-dense` 59.1 / 59.1, `stress-moving` 23.0 cold, 59.0
  warm; thermal 0. DoD 30 met on the reference phone for these three
  fixtures; the floor phone unmeasured (O14). Not yet run: the labels'
  cost (24.6), normal play, `loop-start-pile` (24.5), the second native
  basket run, chunk 20's checks by hand: **the repeat stays open until
  session 7**. The phone's hashes differ from the desktop's (bionic's
  `atan2f`; hashes compare within one platform, D163).
- **Rule 23's basket exclusion** done (b14f0d5; D163, the user's; as
  built, D164): `ClusterWatch` leaves out the slimes whose centre is in a
  basket's box. The test level passes rule 23 in every section: section
  3's play 23 slimes, 0.1 s in a row; its drain 5. The
  `s3-basket-59of60` bench reads 37 slimes, 2.6 s in a row, under 5 s.
- **Item 24.3** done (18d1a86; suite 1582/1582 native, 126/126 the
  GDScript pass; D164): the cause was the outlet's clearance, not switch
  3's trapdoor. Basket 3's outlet moved over slide 3's drop, at (535.68,
  -134) (proposed, the orchestrator's acceptance of the build's fix).
  Basket 3 empties 18.4 s after firing (done-when 28 s), basket 2 in
  13.1 s (14.5 s). Raised O126 (baskets 1 and 2 release at the hop pace).
- **Item 24.8 withdrawn from v1** (D165, the user's: "Withdraw it: drop
  24.8 from v1; the experiment patch stays saved; rule 23 is already met
  on the test level."). The experiment (not committed; the patch kept
  outside the repository) failed the played test (2 sleepers left), made
  the loop start's mean cluster worse (53.8 -> 67.6) and needed a new
  save field.
- **Rule 23's train-queue exclusion** done (c0924d9; D165, the user's;
  as built, D166): a train slime the train follows, not due a move to
  the loop's start, with its centre within `Train.OFF_ROUTE` (36 px) of
  its route point, is left out. Every section passes; the drains peak at
  1, section 3's play at 23. Bench: `stress-moving` 133 -> 44,
  `s3-basket-59of60` 37 -> 14, `stress-dense` 48 -> 2. A pile forming on
  the route at an outlet is now rule 24's.
- **The release hop** done (75040ed; D165, the user's, O126; as built,
  D166): `FrontierSets._release` sets `hop_timer` to 0, so a released
  slime hops the tick after it lands. Drains: basket 1 0.60 s, basket 2
  3.65 s, basket 3 18.40 s; 3 of 38 hashes re-recorded. The played test's
  basket 2, filled with base slimes, empties in 8.6 s (bound 14.5 s): the
  base-slime done-when met as measured, not asserted (O127, proposed).
- **Item 24.2** done (f1861e1; D166): quota pies above 10, a slice per
  unit in the caught slime's colour, 6.7 mm at `s3.frame.basket`'s zoom;
  the reward, release and inert states. Placeholder look (ux D4 Q10);
  ux D4's 0.5 s opt-out drain not built, the colours shift along by one
  slime as slimes leave (O128). [DoD 9] reworded to cover the pies.
- **Item 24.1** met (0d0935c; D166; measured only): a steady 60 fps
  through section 3 on the desktop (native p50 / p5 60.0 / 60.0,
  GDScript p5 59.9, the ceiling at 0); the ticks recorded (native median
  / p95: `s3-basket-59of60` 3.15 / 3.47 and 3.28 / 3.47, `loop-start-pile`
  2.51 / 2.83, `stress-dense` 4.14 / 4.37, `stress-moving` 5.38 / 6.82,
  excepted; GDScript 5.6 to 6.0 ms). On the phone, session 6's 59.1 /
  58.7 cold keeps [DoD 30].
- **Chunk 24 done**, except item 24.5's and item 24.6's phone numbers
  (session 7). 24.8 is withdrawn (D165).
- **ATD (dcf8cb4):** the climb atoms (`rule_train_climbs_without_sliding_back`
  1.1, `rule_train_relay_on_take_off` 1.2) are at REVIEW; **STABLE needs
  the user's explicit confirmation**.
- **Now (D166):** 1. the phone's **session 7**, which closes chunk 22's
  repeat: the labels off against on (24.6), normal play,
  `loop-start-pile` (24.5), the second native basket run, chunk 20's
  checks by hand, on a build with 24.3 and the release hop; 2. the
  closing **health review**: its read-only phase is running now, its
  clean-ups come after the phone run.
- **The order as planned in D165 (since done but session 7 and the
  health review):** rule 23's train-queue exclusion, the release hop and
  item 24.2; then item 24.1's record, session 7 with chunk 20's checks by
  hand, the closing health review.
- **Next as planned in D164 (superseded by D165):** 1. item **24.8** (running); 2. item **24.2**, the
  quota pies (a placeholder look until ux-writer's); 3. item **24.1**,
  recording the numbers; 4. the phone's **session 7** (the runs above
  not yet run) and chunk 20's checks by hand; 5. the closing health
  review.
- **The order as planned in D163 (its first two steps since done):** 1.
  `ClusterWatch` leaves a basket's own fill out; 2. item 24.3; 3. 24.8;
  4. 24.2; 5. 24.1; 6. session 7 and chunk 20's checks by hand; 7. the
  health review.
- **The order as planned before D163 (D158; 24g placed by D159, restated by D161, proposed; 5N, 24g and 22c since done):** chunk **5N** (the native tick, now, for headroom, not a missed target:
  the user, "go native"; it ports the local wake), chunk **24g** (the
  train's climb: the hold on a climb and the relay, D160, D161,
  proposed, O125), chunk **22c** (crowd detail only under load,
  proposed, D141), chunk **22 repeated** on the real S20 FE with the
  perf log (DoD 30 judged with the loop start's crowding set aside, the
  user's reading, D161), the rest of chunk **24**, then the closing
  health review. **After v1** (the user's, D161): the geyser object,
  then TL2 (the test level's start review).
- **Two v1 blockers** (the user, 2026-10-06, "mandatory fixes prior
  version lock"; D159): **O91 fixed** (3a27d86, merged 0061ccf; hashes
  re-recorded d48c519): slimes of different species no longer end up
  inside each other; the stuck net stays as a backstop. **The geyser**:
  tried on exp/geyser (throwaway); its "high and wide" form kept, as a
  level object a level places (the user, 2026-10-07, D160), with the
  climb fix (the hold on a climb and the relay, from exp/dip-jam) and
  rule 24's run check: chunk **24g**, proposed next after 5N. **The
  start's crowding is not a blocker** (the user, D160: "that doesn't
  prevent validating this version"): it goes to the test level's review
  (TL2). **D161** (the user, 2026-10-07: "nah test level review comes
  after v1 is finished. same with geyser etc."): the geyser is no longer
  a v1 blocker; it and TL2 come after v1. 24g keeps only the climb fix
  (proposed, O125; kept in v1 by the user, D165).
- **Chunk L01** (the first real level) is **v2**, not this plan (D134):
  v1 is the test level only. The release preset stays as built, with the
  test level left out; v1 (full MVP) is never published (D135).
- **Chunk 24** (the user's second round of playtest issues, an open list;
  proposed, D128): after chunk 22's repeat (D140), the last chunk
  before the closing step, as the user asked. The user's next play
  reports go there. O106, 24.3's question, is answered by the local
  wake (D156, chunk 22l); 24.8, the lean, is withdrawn from v1 (D165).
- **Closing step, last of all:** the coding-rule health review
  (`CODING_RULE.md`'s health and clean-up list), after every other chunk,
  chunk 24 included (D122, kept by D123 and D128). It also looks at
  `Train._behind`'s linear scan (24g's tick cost, D163).

## Overview

| # | Chunk | Size | Depends on | Tested by |
|---|---|---|---|---|
| 0 | Tooling and project setup | S | — | a headless test runs from the command line |
| 1 | Spike: soft slimes at scale | M | 0 | fps measured with 200 slimes (desktop, then phones) |
| 2 | Spike: vector look | S | 0 | a screenshot comparison, and a decision recorded |
| 3 | Test backbone | M | 0 | two identical scripted runs give identical state |
| 4 | Level scaffolding and Meadow greybox | M | 3 | the loop, terrain and IDs load in a test |
| 5 | Slime body | L | 1, 4 | unit tests on rings; a visual demo |
| 5N | Native simulation tick (done, 0f3d027; for headroom, D158; D140, D142, D143, D155) | M | 22h | the whole suite on the native tick; saves load under either tick; chunk 22 repeated |
| 6 | Train and split zone | M | 5 | [DoD 1 partial, 7] |
| 7 | Taps and the call | L | 6 | [DoD 3, 4, 15, 17] |
| 8 | Save format and fixtures | M | 7 | kill-and-reload tests; the first fixtures load [DoD 28 partial] |
| 9 | Sleepers, waking and the first-play hint | S | 8 | [DoD 2, 16]; `fresh` |
| 10 | Fusion and bumping | M | 8 | [DoD 6]; `bump` |
| 11 | Tilt (desktop, injected) | S | 7 | [DoD 8] with scripted tilt |
| 12 | Camera: rails, edge buttons, call drag | M | 7 | [DoD 18 partial] |
| 13 | Camera: framing zones, idle camera, screensaver zoom | M | 12 | [DoD 18, 19] |
| 14 | Frontier set, gates and completion | L | 8, 12 | [DoD 9, 11, 12, 13, 14]; `s1-basket-5of6`, `s1-optout` |
| 15 | Off-screen simulation | L | 14 | [DoD 5, 10]; `s2-cave-return`, `lost`, `s2-basket-offscreen` |
| 16 | Test level sections 2 and 3, full population | M | 15 | [DoD 1] in full; `gate1-open`, `stress-*` |
| 17 | Session, wind-down, bedtime, sunrise | M | 8 | [DoD 20, 21, 22]; `wind-down`, `bedtime`, `sunrise` |
| 18 | Parent gate and settings (placeholder UI) | M | 17 | [DoD 23, 24, 29] |
| 19 | Persistence hardening | M | 16, 18 | [DoD 28]; `midair`, `old-version` |
| 19w | Save wipe flag for development builds, for automated testing (D148, approved in direction, D149), and a save a build can't use set aside before the first store release (proposed, D149) | S | 19; done, fdae364 | unit tests: the flag wipes, no flag keeps, a release build ignores it, refused with a save to load; before shipping a refused save is set aside and the level saves again, after shipping it is kept and writes blocked; perf.sh's option checked by hand; same hashes |
| 20 | Android build and platform integration | L | 18 | [DoD 25, 26, 27]; emulator |
| 21 | End-to-end suite | M | 19 | [DoD 31] |
| 22 | Performance pass on phones (repeated after 5N and 22c, D140, D141) | M | 20, 23 (repeat: 5N, 22c) | [DoD 30] |
| 22b | Drawing pass (done, D142) | M | 22 | the frame's cost outside the tick measured per part and cut; same hash |
| 22d | Debug counters and the largest awake cluster (done, 1a539db, D143) | S | 22b | unit tests of the four counts and the cluster; the PERF line and its summary carry them; same hashes |
| 22h | Moves to the loop start one at a time, to a random free spot; no stall clock while parked (the user's, details proposed, D150; done, fccbb8e, 96725f1) | S | 19w; 22m's run tool | first the same runs on main (the bug likely there too); `s3-basket-59of60` over 10,000 ticks: no stall move of a parked slime, no stuck move within 10 s of a landing, moves at least 30 ticks apart; unit tests of the queue, the pause, the landing spot; same hash across a save and reload mid-queue; changed hashes listed |
| 22l | The local wake, with the `hops` and `short_hops` counters (the user's direction, D156; done, 600de6b, 5f6a6b0) | S | 22d | the counters first; unit tests: a release, a fast touch and a move to the loop start wake only the resting slimes touched, never a sleeper, and every other wake is local too (D156 (7)); `s3-basket-59of60`'s drain without a whole-pile wake, its Physics and phone-emulation fps against the same build without it; changed hashes listed |
| 22m | The `stress-dense` fixture and the 10,000-tick run tool (the user's, details proposed, D153, D154; fixture done, 4aac65a; run tool done, 3b765f3) | S | 22d | the fixture built by `tools/make_fixture.gd`, no format change; 200 train slimes (fewer only if they don't fit before switch 3, reported), 9 per 300 px stretch, the bowl's bottom two at 12, along the loop line; its hash at 600 and 2400 ticks recorded with the others'; its scripted test; the run tool over 10,000 ticks; a first phone-emulation reading |
| 22e–22k | Withdrawn with the fps session (22e, 22f, 22g, 22i, 22j, 22k; D155); kept on branch `archive/fps-session-2026-10`; their ids aren't reused | — | — | — |
| 22c | Crowd detail only under load (proposed, D141; done, 57d38e7, D162) | S | 5N | the load meter's unit tests; same hashes in `always`; `auto` measured on the desktop |
| 24g | The train's climb (D160, D161; kept in v1 by the user, D165; done and closed, a0ffdde, the relay's save and reload fix 5d7409f, merged 578ccff, D163): the hold on a climb and the relay (from exp/dip-jam), rule 24's run tool without the geyser | S | 5N (proposed) | unit tests of the hold and the relay; `s3-basket-59of60` held on the start, seeds 1 and 2, recorded against D159's baseline (not a pass or fail on rules 23 and 24); `stress-dense`'s census; the fusion drop explained (O122); [DoD 1], the `bump` fixture; same hash on both ticks; changed hashes listed; the whole suite |
| — | The geyser object (after v1, D161; once 24g's first part; see "After v1") | M | 24g | not in v1's order |
| TL2 | The test level's start review (after v1, D161; see "After v1") | S–M | 24g, the geyser object | not in v1's order |
| 23 | Small issues (open list) | S per issue | 17, 16 | each issue's own done-when |
| 24 | Playtest issues, round 2 (open list; proposed; done but 24.5's and 24.6's phone numbers, session 7, D166) | S per issue (24.1 may be M) | 22 repeated (after 22b, 22d, 19w, 22h, 22l, 22m and 5N, D140, D143, D155; its session 6 done, session 7 after 24.1, D163) | each issue's own done-when |
| LD | Level-design toolkit (technical) | L | 16 | the checker agrees with the level-rule tests on the test level; a scaffolded level loads, passes its generated tests and appears in test mode |
| TL1 | Test level finishable from fresh (done, D129) | S | LD, R22 | the checker gives 0 warnings on the test level; a scripted play from `fresh` fills basket 1 |

Chunks 1 and 2 can run in parallel with 3. Chunk 22 failed DoD 30, so
chunk 5N now runs (D96, D140; the user's go, D142; now, for headroom,
D158): after chunks 22b, 22d, 19w, 22l, 22m and 22h (all done), before
chunk 22's repeat. Chunks 9, 10
and 11 are independent of each other. Chunk 17 can start as soon as 8 is done, in
parallel with the camera and objects work. Chunk 23 runs first among the
remaining chunks, before 18 (D123), and chunk LD runs in parallel with it.
TL1 ran after both, before 18 (D127; done, D129). After chunk 22, the
order is 22b, 22d, 19w, 22l, 22m, 22h (all done), then 5N, 24g (the train's climb, D160, D161; kept, D165), 22c, 22 repeated on the real S20 FE, then the rest of chunk 24, the
last chunk before the closing health review (D128, D140, D141, D143,
D155, D158; O97 closed by D140). The fps session after 0196c25 (22e to
22k) was withdrawn (D155). The geyser object and TL2 come after v1
(D161), outside this order.

## Chunks

### 0. Tooling and project setup (S)

- The Godot binary reachable from a stable path (the user's choice, see
  "Before starting").
- Project settings match the spec: landscape locked, 2D. The 3D physics
  engine setting that project creation added is irrelevant.
  The renderer is Compatibility, confirmed by spike 1 (D94, D96).
- A folder layout for components, levels, the simulation core, and tests.
- A test framework picked by the implementer, runnable headless from the
  command line.
- **Done when:** `godot --headless` runs one trivial test and returns a
  non-zero exit code when it fails.

### 1. Spike: soft slimes at scale (M, throwaway)

- A ring-of-springs slime and the blending shader, with 200 slimes on one
  screen: still (piled) and moving.
- Measure on the desktop first, then on the reference phone, and on a floor
  phone once one is bought.
- **Status:** done on the desktop (D94) and on the reference phone (D96: the
  tick stays in GDScript, fallbacks first, native code as the contingency).
  The floor phone waits for its purchase.
- **Background reading:** the performance targets and the 200-slime cap in the master spec (no ATD step: technical).
- **Done when:** the numbers are written down, with a go/no-go for the
  approach and the renderer. A no-go comes back to spec-writer before
  chunk 5 starts.

### 2. Spike: vector look (S, throwaway)

- Godot turns SVGs into images at import. Compare polygons and lines drawn in
  code against a vector plugin for crisp curves when zoomed.
- **Done when:** the approach is chosen and written down with its reasons.

### 3. Test backbone (M)

- One seeded random generator for all gameplay randomness.
- A fixed simulation step, so runs don't depend on frame rate.
- **Test mode** (Linux and debug Android builds only): speed up or skip
  time, inject taps and tilt from a script, and load a named fixture (a stub
  until chunk 8).
- A way to dump the simulation state (or a hash of it) for comparisons.
- The headless end-to-end runner. This also settles the risk of running
  end-to-end tests on Linux without a screen.
- **Done when:** the same script and seed run twice give the same state
  hash, and test mode is absent from a release export.

### 4. Level scaffolding and Meadow greybox (M)

- A level scene built from components, with no per-level scripts: the loop as
  a drawn route, terrain from paths and collision polygons, routes back as
  level data, stable IDs, and the level version.
- The shared rule format that components use ("when this basket is full,
  open that gate"), at least as an interface.
- Section 1 (Meadow) of the test level as a greybox with placeholder art.
- **Built:** a terrain component that bakes one curve into both the drawing
  and the collision polygon (D93).
- **Atoms (preflight start):** `req_loop_and_world`, `req_interactive_objects_general`, `req_level_design_rules` and its rules (`rule_no_dead_ends`, `rule_exploration_branch_has_route_back`, `rule_gravity_leads_back_to_loop`, `rule_start_carries_split_zone`, `rule_sleepers_never_on_loop`, `rule_first_sleeper_near_first_awake_slime`), `rule_released_level_stable_with_migration`.
- **Done when:** a test loads the level and finds the loop, the route back and
  every stable ID of section 1.

### 5. Slime body (L)

- Production version of spike 1: a soft body with sizes 1 to 3, six species
  colours (differing in lightness too), hopping as the only movement, and
  hop cadence from the seeded generator.
- Fusion and splitting as ring operations, exposed for later chunks.
- **Built:** the spike's struct-of-arrays layout and 12/15/18 points per
  ring (D94), and the slimes' own contact with the baked terrain segments,
  `TerrainSegments` (D97).
- **Atoms (preflight start):** `req_slime_states`, `req_hopping_behavior`, `req_species_and_colour`, `rule_max_size_three`, `rule_first_section_species_count`.
- **Done when:** unit tests cover ring creation, merging and splitting, and a
  demo scene shows slimes of each size and species hopping.

### 6. Train and split zone (M)

- Train slimes follow the loop by hopping (about 1.5–3 s, random per slime).
  Physics handles only the squish and the bumps.
- The split zone at the start of the loop. The return route is part of the
  loop in section 1 (the placeholder slide).
- The game wakes the first slime.
- **Atoms (preflight start):** `req_loop_and_world`, `req_hopping_behavior`, `rule_split_zone_only_splitter`, `rule_start_carries_split_zone`, `rule_loop_travelable_with_no_input`, `rule_all_sizes_travel_loop_v1`.
- **Done when:** with no input on the Meadow, the train loops for a full
  simulated session and no slime is lost [DoD 1, section 1 only], and
  every slime entering the split zone leaves as base slimes [DoD 7].

### 7. Taps and the call (L)

- Tap dispatch in the spec's order: top of the screen, edge buttons, object,
  open ground. At this stage only open ground does anything.
- The ripple on every tap. The first touch wins.
- The call: the radius, train slimes answering, the three phases of a free
  slime (answering, unsure, heading back by the route back), and rejoining
  the train.
- **Atoms (preflight start):** `req_controls_tap_zones`, `req_call_mechanic`, `req_slime_states`, `rule_exploration_branch_has_route_back`.
- **Done when:** scripted taps satisfy [DoD 3, 4, 15, 17].

### 8. Save format and fixtures (M)

- One save per level: each slime's species, size, state and position, and
  the object states (empty for now), with the level version and stable IDs.
- Autosave every 15 s and when the app goes to the background.
- Fixture loading in test mode. The fixtures are save files.
- **Atoms (preflight start):** `req_persistence_and_saves`, `rule_saves_never_wiped`, `req_test_level_and_test_mode`.
- **Done when:** a kill-and-reload test restores the slimes, and test mode
  loads a hand-made fixture.

### 9. Sleepers, waking and the first-play hint (S)

- A sleeper wakes only when a free slime touches it on screen. Tapping a
  sleeper is a call centred on it.
- The first-play hint: a wordless pulse near the first sleeper after about
  10 s with no call, shown on the first play only.
- **Atoms (preflight start):** `req_waking_sleepers`, `rule_first_sleeper_near_first_awake_slime`, `user_story_newcomer_p1`. No requirement atom covers the first-play hint yet, so the preflight should flag it and the documentalist adds one.
- **Done when:** [DoD 2, 16] pass, starting from `fresh`.

### 10. Fusion and bumping (M)

- Same-species contact for 3 s fuses. A hop that breaks contact resets the
  count. A fusion above size 3 bumps instead. The dip in the loop nudges
  fusion.
- **Atoms (preflight start):** `rule_fusion_contact_time`, `rule_max_size_three`, `rule_dip_may_nudge_fusion`.
- **Done when:** [DoD 6] passes, including `bump` (2 + 2 and 3 + 1).

### 11. Tilt, desktop and injected (S)

- Gravity turns with tilt up to ±45°, with a dead zone of about 10°. Neutral
  is taken at session start, and lying flat counts as neutral. Only free
  slimes feel it.
- The input is injected on desktop here. The real sensor comes in chunk 20.
- **Atoms (preflight start):** `req_controls_tap_zones` (tilt), `req_slime_states`, `rule_tilt_never_required`.
- **Done when:** [DoD 8] passes with scripted tilt.

### 12. Camera: rails, edge buttons, call drag (M)

- The camera on rails along the loop, return routes included. Right always
  means forward along the loop.
- The edge buttons (hidden at bedtime, once chunk 17 exists).
- The call pulls the camera slowly toward the call point.
- **Atoms (preflight start):** `req_camera_rails_and_framing`, `req_controls_tap_zones`, `rule_return_route_per_section`.
- **Done when:** the edge buttons move the camera along the loop in both
  directions, round the frontier turn, and the child has no zoom control.

### 13. Camera: framing zones, idle camera, screensaver zoom (M)

- Framing zones as a level component, including the longer push to leave
  one.
- The idle camera after 45 s, with the zoom-out cue 10 s before, following a
  train slime through fusion and splitting.
- One shared zoom for idle and screensaver mode. Framing zones are ignored
  while either follows a slime, and resume on touch if the camera's centre
  is still in a zone.
- **Atoms (preflight start):** `req_camera_rails_and_framing`, `req_idle_camera_and_screensaver_zoom`, `rule_framing_zone_wherever_wider_view_needed`.
- **Done when:** [DoD 18, 19] pass on the Meadow's framing zones. The minimum
  zoom is still an open point: log what the Meadow's zones show.

### 14. Frontier set, gates and completion (L)

- The switch (stays flipped), the basket (outlines by weight, the reward
  waiting for view, firing, release), the gate (extends the loop and replaces
  the return route), inert for good afterwards, signposts, and the one-time
  celebration.
- Opting out: flipping the switch back releases the slimes and empties the
  basket.
- Object state in the save.
- **Open point:** where a basket releases its slimes is part of the basket's
  own design, which isn't planned yet. Build the test level's assumption (one
  outlet onto the onward route) behind a property, so it can change.
- **Atoms (preflight start):** `req_switch_basket_gate_set`, `req_interactive_objects_general`, `rule_gate_opens_via_switch_basket_set`, `rule_frontier_set_inert_after_gate_open`, `rule_signpost_at_every_fork`, `rule_return_route_per_section`, `rule_return_route_may_carry_exploration`, `rule_tilt_never_required`.
- **Done when:** [DoD 9, 11, 12, 13, 14] pass, with `s1-basket-5of6` and
  `s1-optout`, while the basket is on screen.

### 15. Off-screen simulation (L)

- Physics only on or near the screen. Off-screen train slimes move as
  positions along the loop at a deterministic pace, and spawn just outside the
  view when it comes near.
- Free slimes that leave the screen follow their area's route back. Left
  alone at 10 s, lost at 1 min, and moved to the start.
- Baskets count weight off screen. Fusion and waking happen on screen only.
- Cheaper states (the fallbacks that come before native code, D96): resting
  slimes (a pile) stop being simulated, contact solving included, until
  something disturbs them; sleepers don't simulate; slimes in a full basket
  are simplified; and zoomed-out slimes use fewer points.
- **Atoms (preflight start):** `req_offscreen_simulation`, `rule_left_alone_and_lost`, `req_switch_basket_gate_set` (off-screen filling).
- **Done when:** [DoD 5, 10] pass, with `s2-cave-return`, `lost` and
  `s2-basket-offscreen`. Needs section 2 in greybox, pulled forward from
  chunk 16.

### 16. Test level sections 2 and 3, full population (M)

- Caves and the Big bowl in greybox, all frontier sets, all framing zones, and
  the full population of 200 slimes.
- The level rules checklist run against the test level.
- The fixture pass also regenerates `bump` with the slimes the test level
  now lists (two size-2, one size-3, one size-1), so that both bumps can
  happen.
- **Atoms (preflight start):** `req_level_design_rules` and all 20 rule atoms, `req_scope_one_level_four_sections`, `rule_max_200_slimes_per_level`.
- **Done when:** [DoD 1] holds for the whole level, and `gate1-open`,
  `gate2-open` (added while building), `stress-still` and `stress-moving`
  load. The stress fixtures give desktop
  performance numbers. The end-to-end test from `bump` asserts both bumps
  (2 + 2 and 3 + 1).

### 17. Session, wind-down, bedtime, sunrise (M)

- Screensaver mode, the first tap starting a 15-minute real-time session,
  the dusk wind-down in the last minute, bedtime (the slimes sleep, the game
  saves, taps are inert but still ripple, the edge buttons hide), and sunrise
  after 10 minutes.
- Timers stored with both the wall clock and the monotonic clock.
- **Atoms (preflight start):** `req_session_lifecycle`, `req_actor_roles_and_permissions`, `req_denial_and_stepup_behavior`.
- **Done when:** [DoD 20, 21, 22] pass on desktop with time skipping (the
  "wake early" path waits for chunk 18), with `wind-down`, `bedtime` and
  `sunrise`.

### 18. Parent gate and settings, placeholder UI (M)

- First-launch setup (the code typed twice, the explanations), the top-of-
  screen reveal, wake early (bedtime only), leave, and settings (change the
  code; delete a level's save with a second confirmation).
- A wrong code shakes and clears. After 5 wrong tries in a row there is a
  30 s wait. The prompt closes after about 15 s with no input, and settings
  closes after 30 s with no input, with a warning over the last 10 s
  (D113). Nothing pauses.
- The parent buttons hide after 5 s with no press; a tap outside the open
  buttons or code prompt closes it and does its normal job (D113).
- Setup in four steps (welcome, the code, if you forget it, pinning); the
  code is saved only when setup finishes, and an interruption restarts it
  from the first step (D113).
- **The time left** (session, or until sunrise) in the settings header and
  on the wake-early prompt, never on the parent buttons (D114, new v1
  scope).
- Parent-facing targets at least 9 × 9 mm (D109). Text strings in English
  and French, the French with "vous" (D102, D113).
- The code is stored locally, never in plain text.
- The rules follow `access-model.md`.
- Debug tools: they move below the ingame menu when it appear. 
- **Atoms (preflight start):** `req_parent_gate_and_access`, `req_actor_roles_and_permissions`, `req_denial_and_stepup_behavior`, `req_persistence_and_saves` (deleting a save).
- **The session on delete (D104):** the session lives in the level's save.
  Deleting that save keeps the running session and writes it into the fresh
  save, so deleting the save can't escape bedtime.
- **Done when:** [DoD 23, 24, 29] pass on desktop, including: the buttons
  hiding after 5 s; a scripted tap on the world while the buttons or the
  prompt are open closes them and calls (and starts a session in
  screensaver mode); settings closing at 30 s, a touch at 25 s resetting
  it; setup interrupted at step 3 keeping no code and restarting at step 1;
  the time left matching the session clock in settings and on the
  wake-early prompt. The "forgot the code?" path is stubbed until chunk
  20.

### 19. Persistence hardening (M)

- Atomic writes with one backup, used when the latest save can't be read.
- A slime in mid-air on load: grounded, or put back at the start of its jump,
  or lost.
- Save migration by level version: displaced slimes count as lost (*since item 24.4, D163:* a displaced sleeper stays asleep at its own or the nearest empty sleeper spot; only awake slimes, and a sleeper with no spot left, are lost).
- **The parent code's file too** (`user://parent.json`, proposed, D130):
  the same atomic write and backup, so a damaged file no longer reads as
  "no code" (setup shown again, maybe to the child, and the wait lost).
  The backup of a level's save goes in `SaveStore.delete` with the save.
- **Atoms (preflight start):** `req_persistence_and_saves`, `rule_saves_never_wiped`, `rule_released_level_stable_with_migration`, `req_parent_gate_and_access` (the code's file).
- **Done when:** [DoD 28] passes, including a kill during a write, with
  `midair` and `old-version`, and a damaged `parent.json` keeps the code
  from its backup (proposed, D130).
- **Built** (D131): done; the choices marked proposed there wait for the
  user.

### 19w. Save wipe flag for development builds (S, D148, approved in direction, D149; done, fdae364)

The user (2026-10-01): "Currently we aren't in production, so we may
relax save file deletion in testing. Ensure that a flag can be set so
that if set, the save file is automatically deleted at the begining of a
test session. Of course, when testing save/restore state we need to
remove this flag." And (2026-10-01, D149): "the flag is only for
automated testing. i've the reset button. save format may break between
version. That's our prerogative to ensure migration (if the app has been
shipped, otherwise, we just wipe)." A launch aid for automated test runs
(`perf.sh`, scripted desktop launches), never in a player's build and
never used in manual play: by hand, a level is started over with the
parent's delete of its save. It runs first in D155's order (it shares
`main.gd`'s startup and `docs/dev/README.md` with the chunks around it,
so it doesn't run while another chunk edits them). It touches the persistence
contract's neighbourhood, so it **keeps both ATD steps**. Every rule
below is D148's (approved in direction, D149) or D149's, proposed where
it goes beyond the user's words.

- **Atoms (preflight start, before any code):** `rule_saves_never_wiped`
  (STABLE, on the contract's surface: documentalist checks it first),
  `req_persistence_and_saves`, `domain_saves_per_level`,
  `rule_released_level_stable_with_migration`,
  `req_test_level_and_test_mode`, `domain_testability`, and
  `contract_atd` for D149 (6 (b)). `rule_saves_never_wiped`'s LOGIC
  already carries the wording the user approved (D148's head; the atom's
  1.1, 729fe87).
- **The flag:** `--wipe-save`, a user argument after `--` (on Android,
  in `slime_args`). Never on by default. Per launch, command line only:
  no toggle that stays set (D149, O112 closed).
- **What it wipes:** every file in `user://saves/` (each level's save,
  its `.bak`, `.new` side files, `.unreadable` set-aside files, `.v<n>`
  version copies). `user://parent.json` and its backup are kept. No
  `--wipe-parent`.
- **When:** once per launch, in the main scene's `_ready`, after the
  stores are made and before the level loads and `_resume_play()` reads
  the save. Only the default directory: a store a test gives is never
  wiped by it.
- **Where the code lives:** a debug-only file, for example
  `src/debug/save_wipe.gd`, named by path after `TestModeGuard.allows()`,
  so the release preset leaves it out with `src/debug/*`. Not a
  `SaveStore` method: the store still deletes only on the parent's
  delete; its header gains a pointer to the wipe.
- **Release builds:** the flag is ignored, nothing deleted, one log line
  (`Save wipe: --wipe-save ignored, not a debug build.`).
- **With a save to load** (`--load=PATH`, or a test script's `"load"`):
  refused. Nothing deleted, an error printed, and a debug launch quits
  with exit code 1, like a bad test-mode flag. `--fixture` is no
  conflict.
- **The log line**, on every wipe: `Save wipe (--wipe-save): deleted N
  files from user://saves/; parent.json kept.` A file that can't be
  deleted gets an error line; the launch carries on.
- **`tools/android/perf.sh`:** a `--wipe-save` option, off by default,
  accepted with `--fixture=none` and `--free-play` only (refused with a
  fixture, exit 2); it adds the flag to `slime_args`. Its header's "the
  player's data is never at risk" paragraph is amended for it.
  `tools/perf_slow.sh` gets no option: it only runs fixtures, which never
  read the player's save, and its extra arguments already pass flags
  through.
- **`docs/dev/README.md`:** what the flag wipes and keeps, that it is
  for automated test runs only, how a test run passes it on the desktop
  and through `perf.sh` (no hand-typed adb launch), that manual play
  starts a level over with the parent's delete, and that save and
  restore checks run without it. Its save section also states D149's
  format rule.
- **Save and restore tests never pass it:** the kill-and-reload and
  delete-save tests, `midair`, `old-version`, every fixture, sidecar and
  test script, the end-to-end suite. A guard test checks that no file
  under `tests/`, `levels/*/fixtures/` or the test scripts names the
  flag, its own tests apart.
- **A save a build can't use, before the first store release** (D149,
  proposed): a save `SaveData` refuses (another format number, older or
  newer, or any other reason it gives) is set aside with its backup as
  `.unreadable` (`.2`, `.3`... if taken), the level starts fresh with
  autosave on (no write block), and one log line says so. One switch in
  the code says whether the app has shipped (for example
  `SaveData.SHIPPED`, false until the first store release); with it on,
  today's behaviour stays: the save is left untouched and writes are
  blocked. A file that isn't JSON is set aside as today; an older level
  version still migrates.
- **Unchanged:** the save format itself (still format 1; it may change
  without a migration until the first store release, D149, but this
  chunk doesn't change it), the fixture and test-mode script formats,
  the parent's delete, the simulation.
- **Done when:**
  - **unit tests** (a scratch directory, an explicit guard): the flag
    wipes every kind of file in the directory and leaves `parent.json`
    and its backup, logging one line with the count; no flag keeps every
    file byte-identical; a guard answering "not a debug build" deletes
    nothing and logs the ignored line; with `--load=PATH`, or a test
    script holding `"load"`, nothing is deleted and the error that makes
    a debug launch exit 1 is returned; a game started with the flag on a
    directory holding a save starts fresh (the first-play hint due); a
    store a test gives is never wiped; the guard test above; the release
    preset's exclude filter covers the wipe's file;
  - **unit tests for a save a build can't use** (D149): with the switch
    off, a save of another format number (newer, and older with a
    test-only number) and a format-1 save failing the shape check are
    each set aside with their backup, the level starts fresh, the next
    autosave writes a new save, one log line; with the switch on, the
    same saves are left untouched and writes blocked (today's tests,
    kept); a file that isn't JSON behaves as today; `old-version` still
    migrates;
  - **perf.sh**, by hand on the emulator or the phone: `--free-play
    --wipe-save` starts fresh with the log line in `logcat.txt`;
    `--fixture=<name> --wipe-save` exits 2; without the flag the device's
    save resumes as before;
  - **same hashes** for every fixture; the full suite green;
  - `docs/dev/README.md` and `SaveStore`'s header carry their notes.

**As built** (fdae364, suite 1365/1365): see D149's as-built note. Two
departures: the release build's "ignored" line is logged from `main.gd`
(the wipe's file isn't exported); a test script that can't be read also
refuses the wipe (proposed). `perf.sh --wipe-save` not yet checked on a
device (the user's).

### 20. Android build and platform integration (L)

- Android export, landscape lock, the screen kept on during a session, and
  background and kill lifecycle feeding saves and timers.
- Screen pinning requested at each launch, and "leave" ending it. This needs
  an Android plugin; check how Godot 4.7 plugins call `startLockTask()` early
  in the chunk.
- "Forgot the code?" through Android's system prompt with the device
  credential. Chunk 18's setup text already describes it and pinning, and
  its prompt link is a stub (D130).
- Check on the reference phone that the French parent labels fit
  (D130; or in chunk 22).
- Real tilt from the sensor.
- No network permission in the manifest.
- **Sticky immersive mode**, the world drawn edge to edge with the controls
  inside the safe area, and **the whole edge strips excluded from the back
  gesture** (D112). Check on the reference phone (One UI) that a tap
  sliding off a strip with pinning declined doesn't go back.
- **Atoms (preflight start):** `req_screen_pinning`, `req_parent_gate_and_access` (forgotten code), `req_session_lifecycle` (lifecycle), `rule_no_network_connection`, `req_platform_and_performance_targets`.
- **Done when:** [DoD 25, 26, 27] pass on the emulator, including a swipe
  from a strip with pinning declined staying in the app, and tilt feels
  right on the reference phone.
- **Built** (D132): done on the emulator; the phone checks (D132, 3) wait
  for the user's S20 FE, and the choices marked proposed there wait for
  the user.

### 21. End-to-end suite (M)

- Every fixture in the test level's list has at least one scripted
  end-to-end test, and the suite runs headless on the Linux build.
- **Done when:** [DoD 31] passes, and the suite is repeatable (same seed, same
  result).
- **Built** (D133): DoD 31 passes on the Linux build; four tool-driven
  test files run only in the editor suite, and repeatability is proved per
  fixture (proposed, D133).

### 22. Performance pass on phones (M)

- The real game at the endgame (the bowl, a full basket, the train) on the
  reference phone and the floor phone, each cold and after 5 minutes of play
  (once the phone has throttled), plus normal play.
- `stress-still` and `stress-moving` are measured too and recorded; they are
  measurements, not targets (D96). *Since D153:* `stress-moving` (200
  moving slimes) has an abuse target, not a 30 fps target (no crash, no
  freeze, at least 15 fps), and `stress-dense` a 30 fps target, both in
  [DoD 30], checked at this chunk's repeat on the reference phone.
- **Resting piles (D107):** measure a bedtime pile in the open (it may take
  about a minute to rest with the fixed anchor), and how often an awake slime
  hopping against a pile wakes it; revisit the rest rule if either costs
  the targets. Bring the code comment on `REST_DRIFT` in line with the rule
  (the anchor is fixed where the count started, not a sliding window).
- **The level bench's start (D131):** `tools/bench_level.gd` times from
  `REST_TICK` 670, but the stress pile now rests at about tick 410; fix
  the start before measuring.
- **Atoms (preflight start):** `req_platform_and_performance_targets`, `rule_max_200_slimes_per_level`.
- **Done when:** [DoD 30] holds: 60 fps on the reference phone in normal
  play, and at least 30 fps on the floor phone in the realistic worst case
  (the level's largest pile on one screen: a full basket plus the train,
  mostly still). **If either fails, chunk 5N runs and this chunk is
  repeated.** If the floor phone still can't hold it, the floor rises (D71).
  The 200 cap stays.
- **Built** (D138; 1e98c7a, suite 1267/1267): the tick and drawing fixes
  (the fusion nudge, door passes, the pair loop, off screen, the centre
  cache, drawing culled to near-view), all with identical state hashes;
  the perf log, `--max-ticks-per-frame`, `tools/android/perf.sh`, the
  bench's rest detection and `tools/level.sh rest`; the new fixture
  `s3-basket-59of60`. **DoD 30 is not met** on the reference phone's
  evidence of 2026-09-30, and the floor phone is open: the section 3
  endgame is bound by the GDScript tick (estimated 15 to 17 ms cold, 24 to
  27 ms throttled on the phone), so **chunk 5N is recommended** (not
  started), and this chunk repeats after it. Proposed, for the user: the
  cap of 2 ticks per frame at 1x (**settled**, D163), the phone frame
  budget (simulation at most 8 ms, drawing at most 4 ms, at least 4.7 ms
  left; **a headroom target**, recorded, not a v1 gate, D163), numbers
  from logs only. The rest rule's findings are O105; a fired basket's releases
  waking its pile, O106 (with 24.3); parked asleep slimes stacking, O91 (closed by D159's fix; the stacking itself unchecked, O105's note).
- **Crowd detail** (the user's idea, merged after the chunk; proposed,
  D140): fewer ring points when many slimes are active. On a slowed
  desktop CPU standing in for the phone, `s3-basket-59of60` 16.4 -> 18.0
  fps and `stress-moving` 11.4 -> 12.3 fps; the rest of the frame stays
  about 21 ms (overstated: that run pinned the whole process, putting the
  engine's and the driver's helper threads on the game's core; D142).
  Helpful, not enough on its own.
- **Repeated after 5N and 22c** (D140, D141): on the reference phone with
  the perf log (`tools/android/perf.sh`, labels off), cold and throttled,
  with crowd detail in `auto` (the shipping behaviour; DoD 30 is judged on
  it); the PERF lines show where the device is pressed and the ceiling it
  reaches. The done-when above is unchanged, except that (the user's
  reading, D161: "fps gating is mostly ok if we ignore loop's start
  issue"; wording proposed) DoD 30 is judged **with the loop start's
  crowding set aside**: the windows where slimes coming home crowd the
  loop's start (in `s3-basket-59of60`, its section 1 window once the
  train comes home) are measured and recorded, not gated; they go to
  TL2, after v1. It records which of 24.3 and
  the local wake (22l, D156, O106) have landed by then. It also closes
  chunk 22b's drawing verdict (D142): the PERF line's per-part fields
  give drawing's cost on the phone against the 4 ms, cold and throttled;
  the phone's GPU time can't be read (O14), so the frame rate shows it;
  what is left above 4 ms is recorded, and O108's levers are the user's
  call. It takes item 24.6's phone number too (labels on against off, in
  the same scene).
- **Repeated, session 6** (D163; 2026-10-07, the real S20 FE, main
  cfe1dab, `auto`, native tick, `perf.sh` runs p8-*): `s3-basket-59of60`
  59.1 / 58.7 fps cold (p50 / p5), 59.1 / 58.8 warm, the detail ceiling
  stepped to 1 at 47 s; `stress-dense` 59.1 / 58.9 cold, 59.1 / 58.7
  warm, ceiling 0; `stress-moving` 23.0 / 21.0 cold, 59.0 / 43.9 warm,
  ceiling 3 within 5 s, no thrash. The GDScript tick on
  `s3-basket-59of60`: 21.2 / 16.7 cold, 23.4 / 22.6 warm. A tick about
  10 ms (off screen 4.0, `train_follow` 1.7, fusion 1.0, the frontier
  1.0, the native solver 0.3); battery at most 32.1 °C, thermal status
  0. **DoD 30 is met on the reference phone for these three fixtures**;
  the floor phone is unmeasured (O14). **Not yet run** (session 7, all
  scripted): the labels off against on (24.6's number), normal play,
  `loop-start-pile` (24.5), the second native basket run, chunk 20's
  checks by hand. This chunk's repeat stays open until then (D166: on a
  build with item 24.3 and the release hop, both since session 6). The phone's
  hashes differ from the desktop's (D163: bionic's `atan2f`, through
  crowd detail's resampling; reproduced by `tools/linux/bionic_libm.sh`).
- **DoD 30's status after 22l and 22m** (phone emulation only, not the
  phone; still not met then): `s3-basket-59of60`, the basket scene, reaches
  35.0 fps, past 30 (the floor phone unmeasured, O14); `stress-dense`
  22.9 fps, short of 30; `stress-moving` 16.1 fps on the mean, 13.0 at
  the 5th percentile, so its abuse target hangs on O115.

### 22b. Drawing pass (M, done, D142)

The frame outside the tick: on the slowed desktop CPU standing in for the
phone it cost about 21 ms with or without crowd detail, more than a whole
frame on its own (mostly the slowdown method's, as 22b found; see
"Built"). Runs before chunk 5N. Keeps both ATD steps, like chunk
22 (the frame-rate target).
- **Measure first,** per part, with the perf log: the blend mode's field
  viewports, the eyes, the lines, the frontier view, the debug overlay
  (labels off, as always), on `s3-basket-59of60` and `stress-moving`.
- **Cut what costs,** without changing behaviour (same seed, same hash)
  and without changing the look beyond what the user accepts (a visible
  change goes to spec-writer first).
- **Atoms (preflight start):** `req_platform_and_performance_targets`.
- **Done when:** each part's cost is recorded before and after in the
  project documentation, on the slowed desktop CPU and, where the tooling
  allows, on the reference phone; the frame outside the tick is cut as far
  as the cuts allow, aiming at D138's drawing budget (at most 4 ms on the
  reference phone, proposed); what is left above it is recorded, not
  chased into behaviour changes; the suite passes with identical hashes.
- **Built** (D142; 5d9533a, suite 1318/1318, the 17 hashes identical;
  detail in `docs/dev/README.md`, "Chunk 22b: drawing"): redraw only on
  change (the frontier view, the tap feedback, the edge buttons, test
  mode's and the debug overlay), the slime renderer rebuilding only on
  change and only the seen slimes, instanced eyes and basket slots
  (`ShapeInstances`), the debug labels' text refreshed every 250 ms (item
  24.6); the PERF line's 14 per-part fields, `tools/perf_slow.sh`,
  `tools/compare_frames.py`. Draw calls on `s3-basket-59of60` 482 -> 84.
  **The method:** pinning the whole process to one core also pinned the
  engine's and the driver's helper threads, which inflated the rest of the
  frame (16.7 ms, not 22, with the main thread alone pinned); the
  slowed-CPU method is now `tools/perf_slow.sh --pin=main`, and the phone
  estimate is each part's full-speed desktop cost × 2.1 cold, × 3.4
  throttled. **Verdict (an estimate):** drawing 2.6 to 3.3 ms on the
  phone cold, all four measured scenes within 4 ms; 4.2 to 5.3 ms
  throttled, none within; chunk 22's repeat closes it. Look: the baskets'
  outline feathers differ by at most 1 of 255 (sub-pixel), accepted as
  invisible (proposed). Left: O108 (DIRECT mode, the Mobile renderer, a
  lower field resolution; each a spec change), the skirt loop and the
  render recording (recorded, not scheduled).

### 22d. Debug counters and the largest awake cluster (S, done, 1a539db, D143)

**Built** (7437fd0, cherry-picked onto main after the revert as
1a539db, D155; suite 1330/1330, the 17 hashes unchanged): as below; the
section 3 numbers are in `docs/dev/README.md`, "Chunk 22d" (the first
data for O107).

The user: "try to do these debug changes prior working on 5N", and
"ensure these informations are also available regularily in the logs for
your perusal". Today's bar ("on screen : simulated : off screen") misled:
slimes in a basket count as on screen. Runs after chunk 22b, before 5N,
so 5N and 22's repeat are read with the new counts. Its windowed run uses
the slowed-CPU method, `tools/perf_slow.sh --pin=main`, where it runs
slowed (D142). Debug tooling only
(no atom pins the overlay): no ATD steps; it still goes test first. It
must not run while another chunk edits the debug overlay or the perf log.
- **The bar** (every 250 ms, as now), in slimes: **Physics** (calm ACTIVE,
  not a sleeper: `SlimeBodies.crowd_count()`, the count crowd detail steps
  on), **On screen** (centre in the view, any state), **In range** (not
  parked, any state), **Parked**. On screen and In range overlap.
- **The PERF line** carries `physics`, `on_screen`, `in_range`, `parked`
  (taken at the line), `resting` and `largest_cluster`; `simulated` and
  `off_screen` go; `active` (the window's mean) and `bodies` stay, and
  `active` is aligned on `crowd_count()` (today it also leaves out slimes
  asleep at bedtime, which still cost physics while settling).
  `tools/android/perf_summary.py` reports each count (min, mean, max) and
  the largest cluster's maximum.
- **The largest awake cluster:** the biggest connected group of touching
  Physics slimes, in slimes; touching as D143 defines it (in contact on
  the last tick, or centres within the sum of their radii plus 2 px,
  written down). Once per perf-log period, read only.
- **Done when:** unit tests on a built state count each of the four right
  (a sleeper, a resting pile, a slime in a basket, one parked, one off
  the view but in range, one asleep at bedtime still settling); the
  cluster's tests give 5 for touching groups of 3 and 5, count a chain as
  one group, and leave resting and parked slimes out; the PERF line and
  `perf_summary.py`'s report carry the fields (their tests updated); a
  windowed run's PERF lines through section 3 are recorded in the project
  documentation, the first numbers for O107; the suite passes with
  identical hashes.

### 22h. Moves to the loop start one at a time, to a random free spot (S, proposed, D150; done: step A fccbb8e, step B 96725f1)

The user (2026-10-02), after chunk 22g's stall diagnostic (withdrawn
code, D155; its report, `docs/perf/2026-10-01-chunk-22g.md`, section 5,
is on branch `archive/fps-session-2026-10`): "emergency teleport should
be randomized in position ... emergency teleport should have a cooldown.
between 0.5s to 2s"; a global queue, one move at a time; and the stall
clock paused while a train slime is parked. "Emergency teleport" is the
**move to the loop start** (`LoopStart.move`), shared by lost free
slimes, stuck slimes and stalled train slimes (out of bounds included).
Runs after 19w, 22l and 22m, before 5N (D155, D158); its 10,000-tick
runs use 22m's run tool (`tools/thru.gd`, 3b765f3). It changes three
safety nets' rules, so it **keeps both ATD steps**. It must not run while
another chunk edits the Train, `StuckSlimes` or `Offscreen`. Every rule
and number below is D150's, proposed where it goes beyond the user's
words.

- **Atoms (preflight start):** `rule_stalled_train_slime_moved_to_start`
  (its "on screen or off" changes), `rule_stuck_slimes_moved_to_start`,
  `rule_left_alone_and_lost` (the move waits its turn),
  `req_offscreen_simulation`, `req_slime_states`,
  `req_persistence_and_saves` (to confirm no save key changes).
- **0. Measure on main first.** The withdrawn build showed the bug (87
  and 305 moves on seed 1); its causes are in code the revert kept (the
  single-file parked line, the first free spot of 8), so it most likely
  exists on main too (D150). The same runs on main are 22h's "before",
  and the record says whether they show it.
- **1. The stall clock pauses while parked** (O113's default: every
  parked train slime): each tick a followed slime is parked, its last
  stall mark's tick moves on by one; progress at the off-screen pace
  still marks as today; out of bounds unchanged. No new save key (the
  record's `marked_at` carries it).
- **2. The loop-start queue:** the nets (`Offscreen`'s lost count,
  `Train.follow()`, `StuckSlimes.step`) only find the slimes **due**; one
  queue step, last in `Simulation.step`, moves **one per turn**, the next
  turn 30 to 120 ticks after the last move (the first draw of
  `loop_start:gap:<move tick>`). Out of bounds first, then first due
  first moved, ties by id; a slime whose reason no longer holds at its
  turn leaves without a move and without spending the wait; a queued
  slime carries on as it would meanwhile. A stuck pair's count keeps
  counting while its mover waits. The debug kill tool stays immediate
  and counts as a move. **Derived, not saved:** who is due and since when
  from the nets' saved state, the last move's tick from the three move
  logs; fallback, one additive key (D150, 2).
- **3. A random free landing spot:** a distance along the loop drawn
  uniformly in 0 to 240 px from the start, the centre lifted by the
  slime's size; free when inside a split zone and no ring overlaps (parked
  ones included); up to 8 draws from `loop_start:spot:<tick>`; all taken,
  nobody moves and the head tries again on the next multiple of 30
  ticks. Never onto another slime. With the local wake (22l), the move
  wakes only the resting slimes it touched where it was.
- **Deterministic:** derived streams only; a run with no move to the
  loop start and no parked stall keeps its hash; the same seed gives the
  same moves and spots, also across a save and reload mid-queue.
- **Done when:**
  - `s3-basket-59of60`, seeds 1 and 2, 10,000 ticks: 0 stall moves of a
    slime parked at any tick of its last 60 s; 0 stuck moves of a slime
    within 600 ticks of landing from a move to the loop start; every two
    moves at least 30 ticks apart; every landing free at its tick and on
    the first 240 px of the loop. The stall and stuck counts before (on
    main, step 0) and after are reported, with the bowl's parked line
    (now waiting, not drained by the stall net: not a failure);
  - `stress-moving`: the same checks on the moves; its counts reported,
    never targets (the user's note: a cluster of disproportionate
    dimensions on purpose);
  - unit tests: the parked pause and resume; one move per turn and the
    wait from its stream; the order (out of bounds first, then first
    due); a recovered slime leaving without a move or a wait; lost and
    stuck slimes through the queue; the stuck count going on while its
    mover waits; the spot (first 240 px, free, in a split zone); all 8
    taken and the retry; the kill tool immediate; the same hash across a
    save and reload mid-queue;
  - records: every changed hash listed with its reason; [DoD 1]'s
    whole-level test unchanged; a short 22h section in the perf report;
    the suite passes.

**As built** (step A fccbb8e, step B 96725f1; suite 1383/1383; reviewer
OKAY): see D150's as-built note. Two exceptions to the rules above: the
kill tool and losses found at load time move at once (`spot_now`) and may
land on another slime ("never onto another slime" covers queue moves
only); a save taken while an out-of-bounds slime waits is moved at once
on load (D12), the one exception to "same moves across a reload".

### 22l. The local wake (S, the user's direction, D156; done, 600de6b, 5f6a6b0)

The local wake, re-implemented from chunk 22e's build (4750f12, on
branch `archive/fps-session-2026-10`) without the rules D155 withdrew.
Being built now, with the revert, ahead of its place in the order (19w,
22h, **22l**, 22m, 5N). It changes how piles wake, so it **keeps both ATD
steps**. It must not run while another chunk edits the slime body code.

- **Atoms (preflight start):** `req_offscreen_simulation` (its resting
  text), `req_slime_states`, `req_waking_sleepers`,
  `req_switch_basket_gate_set` (the release).
- **1. The counters first** (debug builds, the PERF line only, read
  only): `hops` and `short_hops` (D156 (4)); `perf_summary.py` reports
  them; the same hashes. Built before the wake changes, so the "before"
  numbers come from the same build.
- **2. The local wake** (D156 (1)): a release, a touch faster than
  `WAKE_SPEED` and a move to the loop start wake only the resting slimes
  they touch; never the whole pile, never a sleeper. Every other wake is
  local too (D156 (7)): a fusion, a split, a slime taken out of the
  level, a call, a trapdoor, gate or lid opening or shutting, and a tilt
  change wake only the resting slimes they reach, a state change only the
  slime itself. Where the code
  changes is the implementer's (on the branch: the slime bodies' wake
  path, the frontier sets' release and disturbance, the wake in
  `LoopStart.move`).
- **3. Not part of it** (D156 (2)): which slimes rest doesn't change
  (pile slimes only), there is no new save key and the save format is
  unchanged. The one-step-neighbour fallback only if piles churn
  (D156 (3)).
- **Done when:**
  - unit tests: a release wakes only the resting slimes the released
    slime touches; a fast touch wakes only those touched; a move to the
    loop start wakes the moved slime and the resting slimes that touched
    it where it was, no others; a sleeper touched by any of them stays
    asleep; a call wakes the resting slimes within its radius and a tilt
    change every resting slime, as before, but none of them wakes the rest
    of a pile it didn't reach (D156 (7));
  - the counters' tests: `hops` and `short_hops` on the PERF line and in
    `perf_summary.py`'s report;
  - `s3-basket-59of60` (seed 1; phone emulation, `tools/perf_slow.sh
    --pin=main --seconds=62`), against the same build without the wake:
    basket 3's drain shows no whole-pile wake, the Physics count drops and
    the fps rises, recorded in the project documentation. The branch's
    numbers (6 -> 0 whole-pile wakes, Physics 80 -> 51, 22.6 -> 27.1 fps,
    tick 15.27 -> 13.22 ms) are what to compare with, not the result;
  - every changed hash listed with its reason; [DoD 1] and the suite
    pass; `docs/dev/README.md` gains a local-wake section.
- **Built** (600de6b the counters, 5f6a6b0 the wake; suite 1339/1339):
  every wake goes through `SlimeBodies._wake_at`, one slime, never a
  sleeper; no separate `LoopStart` wake (the state change wakes the moved
  slime); the fallback not built. Basket 3's drain: whole-pile wakes 6 ->
  0; phone emulation 25.4 -> 35.0 fps, tick 15.0 -> 10.5 ms, Physics 74
  -> 43. Only `s3-basket-59of60`'s hash changed. Details: D156's as-built
  note.

### 22m. The `stress-dense` fixture and the 10,000-tick run tool (S, the user's, details proposed, D153, D154; part 1 done, 4aac65a; part 2, the run tool, done, 3b765f3)

The user (2026-10-02): `stress-moving` "may be too much"; keep it as an
abuse test ("not to crash and keep a minimum of 15fps") and add a fixture
at "what the rules allow + 50%": "stress dense: should have at minimum 30
fps", then thinned (D154). Rebuilt from chunk 22j (ad8cd36, bcaa8b7, on
the branch) with a 300 px constant for its stretches. Being built now,
with the revert, ahead of its place in the order. A test fixture and a
measurement tool only: no game code, no save format change; an ATD peek
(`req_test_level_and_test_mode`, the performance requirement for DoD 30's
new clauses, `rule_max_200_slimes_per_level` on the fixture builder).

- **1. The recipe:** `stress-dense` in `tools/make_fixture.gd` (a recipe
  and a build function beside `stress-moving`'s), with its
  `.fixture.json` sidecar and save under `levels/test/fixtures/`, as
  every fixture. Gates 1 and 2 open; the first slime and the 199
  sleepers woken as size-1 train slimes, each its sleeper's species; not
  at bedtime, no session; switch 3 and basket 3 untouched; the camera on
  the bowl.
- **2. The placement** (D154): the loop's distance from its start (gates
  1 and 2 open) cut into 300 px stretches (a slime's stretch is its
  distance divided by 300, rounded down; a constant in the builder, no
  game code); the two stretches at the bottom of the bowl take 12 each,
  then behind and ahead alternately, behind first, 9 each, to 200; a
  short stretch takes its share; nothing past switch 3 (fewer than 200
  only if they don't fit, reported). Within a stretch the slimes are
  evenly spaced by loop distance and set on the loop as a train slime is
  spawned, not stacked. Stable ID order onto fill order. No draw. The
  branch's save and sidecar use base save keys only and may be taken
  over as they are, if the builder gives them again byte for byte.
- **3. The record:** the count per stretch at load, the total and the
  count in the bowl (70 on the branch; O114), and how the line settles
  (neighbours overlap at these spacings, D154 (2)), in the fixture's
  description and the test level README's row.
- **4. The 10,000-tick run tool** (the branch's `thru.gd`, without the
  fields of the withdrawn rules): runs a fixture headless for a number
  of ticks (10,000 by default) on a seed and reports the stall, stuck and
  lost moves, the train's hops (and whether it hopped in every 600-tick
  window) and the slimes left in the bowl. Debug tooling; where it lives
  is the implementer's, and `docs/dev/README.md` says how to run it. It
  serves D153's "no freeze" reading and 22h's done-when.
- **Known issue (O116):** the fixture-load wrap is not fixed here; the
  scenario test's stress advance check stays as it is.
- **Done when:**
  - the fixture loads with 200 train slimes (or the reported count),
    every stretch at most its fill (12 for the bowl's bottom two, 9 for
    the rest) at load and the filled ones at it (bar the last and any
    short one), none past switch 3;
  - its hash at 600 and 2400 ticks (seed 909) recorded with the others',
    which this chunk doesn't change;
  - a scripted test beside `stress-moving`'s
    (`tests/e2e/test_fixtures_e2e.gd`, `test_fixture_scenarios_e2e.gd`):
    it loads, runs, keeps 200 slimes and the train hops; the level bench
    (`tools/bench_level.gd`) and `tools/perf_slow.sh` accept it;
  - the run tool over 10,000 ticks on `stress-dense` and `stress-moving`
    (seeds 1 and 2), its output recorded;
  - one phone-emulation run (`tools/perf_slow.sh --pin=main --seconds=62
    stress-dense`), reported as a first reading, not a gate (the targets
    are checked at chunk 22's repeat, after 5N); the suite passes.
- **Part 1 built** (4aac65a; suite 1342/1342): the fixture, its
  placement, save/reload and scenario tests; 200, 70 in the bowl; the 17
  other hashes unchanged. First reading (phone emulation, local wake on):
  `stress-dense` 22.9 fps, tick 16.3 ms; `stress-moving` 16.1 fps mean,
  5th percentile 13.0; both at the tick cap. O116 still open (17 slimes
  wrap). **Part 2** (the run tool, 4 above) done, 3b765f3. Details: D154's
  as-built note.

### Withdrawn chunks: 22e, 22f, 22g, 22i, 22j, 22k (D155)

Built or planned during the fps session after 0196c25 and withdrawn by
the revert (D155, 2026-10-03). Kept verbatim on branch
`archive/fps-session-2026-10` (at bcaa8b7); their ids aren't reused.
- **22e** (4750f12): the local wake and the train's first waiting rule
  (D145, D146). The local wake comes back as 22l (D156); the rest is
  dropped.
- **22f** (9be1af7): the waiting rule's second round (D147). Dropped.
- **22g** (6e423b7): a front-first train order behind a switch, and the
  stall diagnostic D150 starts from. Dropped.
- **22i** (e996b8a, with D152's fix, 7d4c702): a density cap on the loop
  (D151, D152). Dropped.
- **22j** (ad8cd36, bcaa8b7): the `stress-dense` fixture (D153, D154).
  Rebuilt as 22m.
- **22k** (planned, never built): a measurement round of 22i's cap off
  and on. Dropped; the stress targets are checked at chunk 22's repeat.

### 22c. Crowd detail only under load (S, proposed, D141; done, 57d38e7, D162)

The user's amendment to crowd detail (D140): "if you've got a good
phone/tablet, why degrade?". A good device keeps full ring points
whatever the crowd; crowd detail applies only while the device can't keep
up. Runs after chunk 5N (which changes how often a device is pressed at
all) and before chunk 22's repeat, which measures it. It changes
`req_offscreen_simulation`'s detail rule, so it keeps both ATD steps. It
must not run while another chunk edits the slime body code.
- **The load meter,** in the scene layer and in every build (not the
  debug-only perf log; `src/sim/` never reads a clock, CODING_RULE §2),
  its clock injected so tests can drive it. Each window of about 1 s:
  pressed, calm or in the band (the values are in `tuning.md`, "Off
  screen, resting piles and detail").
- **The detail ceiling** (0 to 3): up one step per pressed window, down
  one step after 3 calm windows in a row, held in the band; 0 at start and
  after a load. An ACTIVE ring takes max(zoom's, min(crowd level,
  ceiling)), then the pile cap. The ceiling is handed to the simulation at
  a tick boundary, like the tilt, and is never saved; no save key changes.
- **Modes:** `--crowd-detail=auto|always|off` (debug builds; release is
  `auto`). `always` (ceiling 3) is the simulation's default; only the game
  root in normal play turns `auto` on. Test mode accepts the flag; the
  test-mode script format doesn't change.
- **The perf log** gains the ceiling, the crowd level, the detail used,
  the busy share and the missed beats on the PERF line, and a line at each
  ceiling step with its reason; `tools/android/perf.sh` runs `auto` in
  both modes (fixture runs pass `--crowd-detail=auto`), with a way to pick
  another mode.
- **Atoms (preflight start):** `req_offscreen_simulation`,
  `req_test_level_and_test_mode`, `req_platform_and_performance_targets`.
- **Done when:** unit tests drive the meter with an injected clock and
  frame feed (a pressed window steps up, the band holds, 3 calm windows
  step down, at most one step per window, a window with a frame over
  250 ms is dropped, a debug speed other than 1x gives no verdict); the
  whole suite passes with identical hashes (`always` everywhere outside
  normal play), and a guard test checks that test mode defaults to
  `always`; in `auto`, `s3-basket-59of60` stays at ceiling 0 on the
  desktop at its normal clock, and on the slowed CPU (`tools/perf_slow.sh
  --pin=main`, D142) it climbs to the crowd's level
  within about 3 s and makes no more than a few ceiling steps over
  2 minutes (no thrash), recorded in the project documentation; a save
  written in `auto` loads in every mode.
- **As built (D162):** done when met. On the slowed CPU capped at 60 fps
  the ceiling first thrashed (32 steps in 2 min); the hold after a bounce
  (proposed) took it to 5: a pressed window within 10 judged windows
  after a step down makes the next step down wait for 60 calm windows.

### 24g. The train's climb: the hold on a climb and the relay (S, D160, D161; kept in v1 by the user, D165; done, a0ffdde; closed with the relay's save and reload fix, 5d7409f, merged 578ccff, D163)

The user (2026-10-05, the `stress-dense` report, in chunk 24's list):
"movement wise, it fails grossly". D160 (4) found the cause on
exp/dip-jam: the climb, not the dip nudge. **D161 (2026-10-07):** the
geyser, once this chunk's first part, and the test level's start review
come after v1 (the user: "nah test level review comes after v1 is
finished. same with geyser etc."; see "After v1" below); the climb fix
stays in v1, **proposed**: it answers the `stress-dense` report, which
doesn't depend on the loop's start, and the user may drop it (O125).
**D165:** the user kept it ("Keep in v1."); the hold on a climb and
the relay are decided, as built; O125 is closed.
The id stays 24g (its branch, `feat/24g`, already carries it). **Proposed:
next after 5N, before 22c and chunk 22's repeat**, which then measure
the game with it. Its id is a chunk's, not one of chunk 24's numbered
items. It changes the train's hops, so it **keeps both ATD steps**. It
must not run while another chunk edits the Train or `Offscreen`. Every
rule and number below is D160's, proposed where it goes beyond the
user's words.

- **Atoms (preflight start):** `req_hopping_behavior` (gains G and R),
  `rule_dip_may_nudge_fusion` (unchanged: its pending no-jam change is
  withdrawn, D160), `rule_arrivals_clear_faster_than_they_arrive`
  (measured here, not gated), `req_persistence_and_saves` (to confirm no
  save key changes).
- **1. The climb fix: the hold on a climb (G) and the relay (R)** (D160
  (4); from exp/dip-jam 1af507a, tokens `g` and `r`, as production code,
  no environment token): a grounded train slime between hops on the
  outgoing route, on a rise over 0.1, keeps its place; when a train
  slime takes off, the standing one right behind it has its hop timer
  cut to 0.15 s. The return routes' carry is untouched. No new state.
  Hopping over the queue (`h`), `v4` and `v5` are dropped. **The dip
  nudge is unchanged**: V1s only if the user takes it (O121; then the A,
  B, A touching test, rule 5's and D119's wording change with it).
- **2. Rule 24's run tool** (D161: kept here, without the geyser's
  fields; TL2 reuses it after v1): the experiment's probes
  (`tools/dipjam_probe.gd` on exp/dip-jam; from `tools/geyser_probe.gd`
  on exp/geyser, its start counts only) kept as one level run tool
  (renamed if it reads better): per 600 ticks, arrivals at the loop's
  start, departures past 240 and 750 px, the largest awake cluster with
  a slime within 240 px, the mean within 240 px, the pocket's mean,
  ticks to clear 240 px, fusions per minute; the camera held with
  `--hold-view`. `tools/level.sh` and the level review point at it. The
  geyser's launches, refusals and landings are added with the geyser,
  after v1.
- **Baseline (D159 (2), D160 (4)):** `s3-basket-59of60`, the camera held
  on the start from tick 9000, 14,000 ticks, seeds 1 / 2, per 600 ticks
  from 9000, main before 24g: arrivals 17.6 / 18.0, departures past
  750 px 2.5 / 3.1, largest cluster within 240 px 118 / 117, fusions per
  minute 17.0 / 16.2. On exp/dip-jam with G and R: departures past
  750 px 7.8 / 7.6, cluster 98 / 95, fusions about 7.7 (O122).
  `stress-dense`, seed 1, 3600 ticks: speed 16.3 px/s, slow share 0.83
  (with G and R: 23.5).
- **Done when:**
  - unit tests of G and R: a held slime on a rise doesn't slide back
    between hops (and does on the return route's carry as before); a
    take-off cuts the timer of the slime right behind to 0.15 s, and
    not of one out of reach or off the outgoing route;
  - the baseline runs again, both seeds: every number **recorded** in
    the project documentation against the baseline, not a pass or
    fail on rules 23 and 24 (the start's crowding goes to TL2, after
    v1); `stress-dense`'s census again, recorded;
  - the fusion drop explained (O122): a fusion census at the dips with
    and without the relay, recorded; if rule 5 (fusion in dips) or
    [DoD 1] no longer holds, stop and report;
  - [DoD 1], the `bump` fixture's both bumps, no stall; `test_train`,
    `test_fusion` and `test_slime_hops` pass; the same hash on both
    ticks and across a save and reload; tick cost not above the
    baseline's; the changed fixture hashes listed and re-recorded; the
    whole suite passes.

### 23. Small issues (open list)

Small issues the user finds while playing the build. The list stays open:
new reports are added here as they come, each with the spec change it
needs and its own done-when. It runs **next, before chunk 18** (D123): its
items are mechanics fixes and decided behaviour, and landing them before
chunk 22 means the performance pass measures the finished behaviour
(baskets at bedtime, the safety nets). It runs as sub-chunks 23A to 23E
(see "Progress"). Each issue is small (S) and can land on its own. An issue
tagged **(proposed)** still waits for the user's approval; 23.1 to 23.9 are
decided (D99 to D101, D103, D105, D109 to D111, D113); 23.10 to 23.12
come from the master spec's alignment with ux D4 and ux D5; 23.13 is
decided (D121).

**23.1 Call camera dead zone** (reported and decided 2026-09-29; D101;
master spec 5.6).
- A call whose point is already inside a box centred on the screen, 20% of
  its width by 20% of its height, happens as usual (the slimes answer, the
  ripple shows) but doesn't move the camera; during a drag it stops the
  drag where it is. Outside the box, the call drag is unchanged.
- **Done when:** a scripted tap inside the box calls the slimes in range
  and leaves the camera where it was until the answering window ends; a tap
  just outside it drags the camera as before; the box holds at each framing
  zone's zoom (it is measured on the screen); a tap inside the box during
  a drag stops the drag; [DoD 3] and [DoD 18] still pass.

**23.2 Edge buttons as whole-height strips** (reported and decided
2026-09-29; D99, which settles O81; master spec 5.5).
- A tap within 10% of the screen's width from the left or right edge, over
  the whole height below the parent zone, is an edge-button press: step and
  hold as now (D102), right forward and left backward (D90). The strip takes
  the whole tap: no call, and no object under it is operated. The parent
  zone wins in the top corners. Hidden at bedtime as now: a tap there is
  then an ordinary tap. The drawn arrows stay placeholders for `ui_ux/`.
- **Done when:** scripted taps at the top, middle and bottom of each strip
  move the camera and issue no call; a tap just inside the strip's inner
  edge moves the camera and one just past it calls; a tap in a top corner
  opens the parent zone; an object placed under a strip isn't operated; a
  strip tap in screensaver mode doesn't start a session; at bedtime a strip
  tap moves nothing; [DoD 18] and [DoD 20] still pass.

**23.3 Slimes stuck inside each other: safety net** (reported and decided
2026-09-29; D100; master spec 5.2; the real fix is O91, done since, D159).
- Every 0.5 s, pairs of simulated slimes that can't fuse whose centres are
  closer than a quarter of the smaller one's radius are counted; after 4
  checks in a row (about 2 s), the smaller one (a train or free slime; on a
  tie the higher id) is moved to the start of the loop, back on the train,
  and logged with the reason "stuck". Stuck is its own state, not lost
  (D100). Sleepers, slimes in a basket and
  bedtime-asleep slimes are never moved; if neither can be moved, the pair
  is only logged.
- **Done when:** a unit test that places two slimes of different species
  on the same centre sees the smaller one moved after about 2 s and logged
  as "stuck"; a same-species pair that can fuse is left to fuse; a pair
  touching normally is never moved; the same seed gives the same hash; the
  log is in the state dump, so tests and the debug overlay can show every
  rescue.
- **Not in this issue:** finding why it happens (O91, not urgent). When
  it is found, the fix comes with a test that reproduces it, and the safety
  net can be reconsidered.

**23.4 The idle camera never zooms in** (decided 2026-09-29; D103; master
spec 5.6). A change to chunk 13's idle camera.
- Where the camera is already wider than the idle and screensaver zoom
  (inside a wide framing zone), the idle cue and the idle camera keep that
  zoom instead of zooming in. Tilt still doesn't count as input for the idle
  clock (already built).
- **Done when:** in the test level's tree zone (zoom 0.7), the idle cue and
  the idle camera never raise the zoom above 0.7; in a zone narrower than
  the idle zoom, the cue zooms out as before; [DoD 19] still passes.

**23.5 Baskets at bedtime** (decided 2026-09-29; D105; master spec 5.4
and 5.7). A change to chunks 14 and 17. Chunk 22 measures bedtime piles
with it in place (sub-chunk 23D).
- At bedtime a basket's releases pause and resume at sunrise; the slimes in
  it sleep in place (they stay in the basket, shown asleep) and sunrise
  doesn't move them out; a reward that is due or playing waits for sunrise,
  so no gate opens and no celebration plays during bedtime. Saved and in
  the state hash, like the rest of the set's state.
- **Done when:** from `bedtime` with a basket releasing (and, in a second
  test, a full basket in view with its reward due), no slime is released and
  no gate opens until sunrise, then both resume; slimes in the basket stay
  in it through sunrise; a save taken during bedtime reloads the same;
  [DoD 21] and [DoD 9] still pass.

**23.6 Hit areas held on the screen** (decided 2026-09-29; D109; master
spec 5.4). From the UX review (Q4).
- An interactive object's hit area is its drawing plus 5 mm on every side,
  never under 20 × 20 mm, measured on the screen at the current zoom
  (replacing the fixed 24-unit margin).
- **Done when:** at zoom 1, a scripted tap 4 mm outside a switch's drawing
  flips it and one 6 mm outside calls; in `s3.frame.basket` (zoom 0.8), a
  tap near the edge of the 20 × 20 mm floor centred on switch 3 flips it; [DoD 18] still
  passes.

**23.6b The parent zone at 7 mm** (decided 2026-09-29; D113, ux D4;
master spec 5.5).
- The parent zone becomes a band 7 mm high measured on the screen (from the
  64 screen-unit placeholder), full width, unmarked; the edge strips start
  below it.
- **Done when:** on the reference phone's size, a tap 6 mm from the top
  reveals the parent buttons and one 8 mm from the top calls (or, on a
  strip, moves the camera); [DoD 24] still passes.

**23.7 Only what answers a tap takes it** (decided 2026-09-29; D109;
master spec 5.4, 5.5). From the UX review (Q10).
- A tap on a basket, a gate or a signpost, or on a switch whose basket is
  full or whose gate is open, is a call; only a switch whose basket is
  filling takes a tap.
- **Done when:** scripted taps on each of those call the slimes in range
  (and start a session in screensaver mode); a tap on a filling basket's
  switch still flips it; [DoD 11, 13] still pass.

**23.8 A resting thumb on an edge strip** (decided 2026-09-29; D110;
master spec 5.5). From the UX review (Q9). **To check in a playtest.**
- A strip touch held longer than about 5 s keeps moving the camera but
  stops counting as the first touch; the next touch is handled as if no
  finger were down.
- **Done when:** with a scripted strip touch held 6 s, a second touch
  starting after 5 s calls (with its ripple), and one starting before 5 s
  still gets nothing; [DoD 17] still passes. The playtest then says whether
  5 s is right.

**23.9 Objects below the parent zone** (decided 2026-09-29; D111; level
rule 21). From the UX review (Q8).
- A level-rule test: at the rails' framing, every interactive object sits
  fully below the parent zone, on the whole test level.
- **Done when:** the test passes on the test level and fails on a synthetic
  level with a switch under the band.

**23.10 Showing a gate open** (master spec 5.6; ux D4, Q14). Not built:
the camera never moves on its own when a basket fires.
- When a basket fires and its gate is off screen, the camera glides to the
  gate (about 1.5 s) to show it opening, then stays there under normal
  control. Input stays live: a touch takes control back and does its
  normal job. A gate already in view: nothing moves.
- **Done when:** from `s1-basket-5of6` with the camera placed so gate 1 is
  off screen, the basket fires and the camera ends with gate 1 in view
  within about 1.5 s; a scripted tap during the glide calls and takes the
  camera back; with gate 1 already in view the camera doesn't move; same
  seed, same hash.

**23.11 The celebration's lasting mark** (master spec 5.1; ux D4, Q15).
Built: the 4 s burst of rings over the view, with input live and the camera
left alone (nothing in chunk 14 blocks input or moves the camera). Not
built: the lasting mark.
- Once the celebration has played (the level's saved done mark), a small
  lasting mark at the start of the loop shows the level is complete,
  visible to anyone who passes, after a reload too. Its look is ux-writer's
  (ux D4 names bunting as an example; placeholder art until then). Also
  from ux D4: every awake slime on screen does a double hop during the
  burst.
- **Done when:** from `stress-still` (basket 3 full) the celebration plays
  and the mark appears at the start of the loop; it is still there after a
  save and reload, and absent on a level whose celebration hasn't played;
  a tap during the celebration calls as usual and the camera doesn't move
  on its own.

**23.12 The idle camera at bedtime** (master spec 5.6; ux D5, Q18).
Mostly built by the way chunk 13 picks its target: the idle camera starts
only on a train slime, and at bedtime there are none, so it never starts;
one already following keeps the id of a slime that is now asleep and
doesn't move. What isn't checked: the cue or the follow in progress when
bedtime begins.
- At bedtime the idle camera follows no one and the camera travels
  nowhere; it may settle at the idle zoom.
- **Done when:** from `wind-down` with no input, the camera is idle when
  bedtime begins and doesn't travel through the whole cooldown (its
  position stays put; only the zoom may settle); the same with bedtime
  beginning during the idle cue; at sunrise the idle camera follows a train
  slime again.

**23.13 A stalled train slime: safety net** (decided 2026-09-29; D121,
which settles O95; master spec 5.2). A change to chunk 6's stall check in
`Train`, which today only logs. The same move to the start of the loop as
23.3 (stuck) and the lost timer (D10): reuse it rather than add a third.
- A train slime that is stalled (no 24 px of progress in 60 s, or its
  centre out of the level's bounds; D118) is moved to the start of the
  loop and rides the train again. Each case is logged with the reason
  `stalled` or `out_of_bounds`, no longer once per slime; the 60 s count
  starts again from the move. A slime asleep at bedtime is never counted
  as stalled or moved.
- **Done when:** a unit test that wedges a train slime so its progress
  can't advance sees it moved to the start of the loop after 60 s, back on
  the train and logged as `stalled`; one placed out of the level's bounds
  is moved and logged as `out_of_bounds`; wedged again, it is moved and
  logged again; from `wind-down`, no train slime asleep at bedtime is
  moved or logged; the same seed gives the same hash; and the whole-level
  DoD 1 test still fails on any logged stall (its meaning is unchanged:
  no train slime stalls in 15 minutes with no input).

### 24. Playtest issues, round 2 (open list, proposed)

**This list stays open: the user's next play reports are appended here**
(24.4 onward), each with the spec change it needs and its own done-when,
as chunk 23 did. The first three come from the user's own testing
(2026-09-29): nothing major gameplay-wise, but a frame-rate drop in the
last section, an unreadable basket display for a large quota, and a
basket that keeps its slimes once it has fired. The chunk runs **after
chunks 22b, 22d, 19w, 22h, 22l, 22m, 5N, 22c and chunk 22's repeat, the last chunk before the closing
health review**, as the user asked (D128; the order is D140's, which
closes O97). Each item is small (S) unless its
investigation says otherwise, and can land on its own. All three items
are **(proposed)** until the user approves D128. Items with business
behaviour (24.2, 24.3) and the frame-rate target (24.1, like chunk 22)
keep both ATD steps. Items 24.4 to 24.6 come from the user's phone
session on the S20 FE (2026-09-30, `docs/perf/2026-09-30-s20fe-session.md`;
proposed, D139); 24.4 changes save behaviour and 24.5 the frame rate, so
both keep both ATD steps; 24.6 is debug tooling only. Items 24.7 and
24.8 are cluster avoidance (the user, 2026-09-30; D143, approved in
direction, D144, their numbers proposed); they
run after 24.3 and the local wake (chunk 22l, D156, which answers
O106), since a draining basket is today's biggest awake cluster; 24.8 is withdrawn from v1 (D165); it changed hopping behaviour, so it
keeps both ATD steps, and 24.7's rule goes to documentalist once
built (a rule atom under `req_level_design_rules`).

**24.1 The frame rate drops in section 3** (reported 2026-09-29;
proposed, D128; master spec 6 and 7, [DoD 30]; **met, 0d0935c**, D166).
*As measured (D166):* closed with the measurement alone (chunks 22 and
5N had brought section 3 there): a steady 60 fps through section 3 on
the desktop (native p50 / p5 60.0 / 60.0, GDScript p5 59.9, the detail
ceiling at 0); the native ticks inside the 2.4 to 3.8 ms band for
`s3-basket-59of60` (3.15 / 3.47 and 3.28 / 3.47 ms, median / p95) and
`loop-start-pile` (2.51 / 2.83), above it for `stress-dense` (4.14 /
4.37), `stress-moving` excepted (5.38 / 6.82); the GDScript tick 5.6 to
6.0 ms; [DoD 30] holds on session 6. The numbers are in
`docs/dev/README.md`, "Item 24.1: section 3's frame rate". An investigation, then a
fix. The user asked for hard data first, hence the debug overlay's fps
and slime counts (built 2026-09-29).
- **Measure first.** Two sources, recorded before and after the fix in
  the project documentation (`docs/dev/`), at the same camera spots:
  - the **debug overlay** in a windowed run (fps, and the slime counts,
    chunk 22d's names since D143), through section 3 in normal
    play: the bowl with the train and called slimes, and basket 3
    filling, full and releasing;
  - the **level bench** (`tools/level.sh bench --level=test`) on the
    section 3 fixtures (`gate2-open`, `stress-moving`, `stress-still`) and
    on a new fixture with basket 3 at 59 of 60, switch 3 flipped, not at
    bedtime (shared with 24.3; its name is the implementer's), in ms per
    tick (median and p95), with the drawing's share measured separately
    where the bench can't see it (it runs headless).
- **Leads, not conclusions.** The bench already reads about 15 ms per
  tick for `stress-moving` (200 base slimes riding the train out of the
  bowl) on the desktop, headless (`docs/dev/README.md`, 16c-B): nearly the
  whole 16.7 ms frame at 60 ticks a second before anything is drawn.
  Other candidates: contact pair checks as section 3 wakes up to 130 more
  slimes, drawing at the bowl's zoom 0.5 (more slimes on screen), basket
  3's pile not resting or not parked, slimes cycling in and out of basket
  3 (see 24.3).
- **Fix the cause found.** No behaviour change (same seed, same hash);
  a fix that has to change behaviour says so and goes back to
  spec-writer. If the cost is the GDScript tick itself with no fallback
  left, that is chunk 5N's ground (D96): report it rather than start
  native code here. If chunk 22 (or 5N) has already brought section 3 to
  the target, 24.1 closes with the measurement alone.
- **From chunk 22 (D138):** the fixture is `s3-basket-59of60`; the
  endgame is bound by the tick, and 5N is recommended (going ahead, D140).
  *D163 (the user's):* the phone frame budget is a headroom target, not a
  gate, so this item's target follows it: **the frame rate gates, the
  tick is recorded**. On the reference phone chunk 22's repeat already
  reads 59 fps on `s3-basket-59of60` (session 6).
- **Target:** on the desktop (the Linux build at test mode's 1152 × 648
  window), a steady 60 fps on the overlay through section 3 in normal
  play (the gate, proposed); the section 3 bench cases' ms per tick
  (median and p95) **recorded** against the budget's simulation share (a
  desktop tick of about 2.4 to 3.8 ms), not gated (D163; it replaces
  D128's proposed 8 ms at p95), `stress-moving` excepted (its target is
  [DoD 30]'s abuse target on the reference phone, not a 30 fps target,
  D153). The phones' targets stay chunk 22's [DoD 30].
- **Done when:** the before and after numbers (overlay readings and bench
  table, the ticks against the headroom target) are in `docs/dev/`; a
  windowed run through section 3 reads a steady 60 fps;
  the whole suite is green, and the same seed gives the same hash; [DoD
  30] still holds if chunk 22 has run.

**24.2 A quota above 10 shown as pies** (reported 2026-09-29; proposed,
D128; master spec 5.4 and [DoD 9]; the look is ux-writer's, ux D4 Q10;
**done, f1861e1**, D166). *As built (D166):* as below, in a placeholder
look; each pie 6.7 mm across at `s3.frame.basket`'s zoom; the reward
swells in the slimes' colours, the release empties from the end of the
row, inert draws nothing. Not built: ux D4's 0.5 s opt-out drain (the
fill empties one release at a time); the colours shift along by one
slime as slimes leave, the count exact (O128). [DoD 9] reworded to
cover the pies.
Basket 3's 60 outlines run wider than the screen.
- **A quota of 10 or less:** unchanged, one slime outline per unit of
  weight.
- **A quota above 10:** one **quota pie** per 10 of weight, the last
  holding the rest (15: a pie of 10 and a pie of 5; 60: six pies of 10).
  Each pie has one slice per unit of weight. Slices fill in order, the
  first pie first, in the colour of the slime caught (as the outlines
  do, ux D4); a size-3 slime fills three slices, across two pies when it
  has to. A full pie stays full while the basket fills.
- **The other states as ux D4 has them for the outlines:** the reward
  pulses every pie; while the basket releases, slices empty one by one
  with the slimes; inert, the pies are gone. (The build today keeps every
  outline filled once the basket has fired; this item brings outlines
  and pies in line with ux D4.)
- **Readable:** the whole row fits within the basket's width, and each
  pie is at least 6 mm across on the reference phone's screen at the
  basket's framing zoom (proposed). Placeholder art until ux-writer draws
  them.
- **The quota itself:** basket 3's 60 stays on the test level. It is the
  test level's stress case (`stress-still`, chunk 22's largest realistic
  pile, [DoD 30]), and the test level is never released. How large a
  real level's quota may be for a child is O98 (proposed: at most 30 of
  weight per basket on the first level, three pies).
- **Done when:** a unit test of the display's layout: a quota of 6 gives
  6 outlines, 15 gives pies of 10 and 5, 60 gives 6 pies; at weight 23 of
  60, two full pies and 3 slices of the third; a size-3 slime arriving at
  weight 8 fills the first pie and one slice of the second; at
  `s3.frame.basket`'s zoom, basket 3's pies fit within its width and
  each measures at least 6 mm on the reference phone's screen size; the
  reward, release and inert states as above; basket 1 still shows 6
  outlines; [DoD 9] still passes.

**24.3 A fired basket lets its slimes go** (reported 2026-09-29; a bug
against the spec, with proposed details, D128; master spec 5.2 "in a
basket" and 5.4; D86, D91, D105; **done, 18d1a86**, D164).
*As built (D164):* the trapdoor lead didn't hold (it shut before the
fire, and nothing fell back in). The cause was the outlet's clearance: a
released slime rested on the outlet until its hop, then the bowl's train
crossed it. The fix, on the test level only (proposed): basket 3's
outlet over slide 3's drop, at (535.68, -134). Basket 3 is empty in
18.4 s (28 s), basket 2 in 13.1 s (14.5 s), none caught again; the test
is `test_basket_drain_e2e`. The new outlet meets rule 24 as measured; O62
stays open; O126 asks about baskets 1 and 2's pace.
- **Follow-up, the release hop (D165, the user's: "Hop at once"; O126
  closed; done, 75040ed, D166):** *as built:* the hop timer set to 0 on
  release, so it hops the tick after it lands; basket 1 0.60 s, basket 2
  3.65 s, basket 3 18.40 s; 3 of 38 hashes re-recorded. The base-slime
  case has no test of its own; the played test measures it (basket 2
  8.6 s, bound 14.5 s) without asserting the bound (O127, proposed:
  met as measured). The item as written: a slime a basket releases hops away at once
  instead of resting on the outlet until its own hop timer runs out (the
  exact form, its hop timer set to 0 on release, is the build's). It
  changes `req_hopping_behavior` and hashes, so both ATD steps. **Done
  when:** a unit test sees a released slime hop without waiting out a
  hop interval;
  from `s2-basket-offscreen`, basket 2 empties in about 3.7 s (13.1 s
  before); baskets 1 and 2 filled with base slimes (6 and 15) empty
  within D128's bound; basket 3 still within 28 s; the changed hashes
  listed and the fixtures regenerated; the suite passes.
- **What the spec already says, unchanged:** once full, a basket plays
  its reward (waiting until it is in view), fires (its gate opens; basket
  3, with no gate, fires the celebration, D77), then **releases its
  slimes**: one every 0.3 s, lowest id first, at its outlet when the
  outlet is clear (`tuning.md`). Each rides the train again with its size
  and species, under the usual rules (fusion, the split zone). The switch
  and basket are then inert for good and the gate stays open (D86). At
  bedtime the releases pause and resume at sunrise (D105, item 23.5).
  Released slimes are train slimes: available again, never lost or
  stuck. Built in chunk 14; the end-to-end test only covers basket 1
  with 3 slimes.
- **Reproduce first:** a test that fails today, from the fixture 24.1
  adds (`s3-basket-59of60`, built in chunk 22: basket 3 at 59 of 60, not
  at bedtime) and from
  `s2-basket-offscreen` (basket 2).
- **A lead to check first** (unverified, read from the scene, not run):
  basket 3's outlet is a point over switch 3's trapdoor, and a trapdoor
  shuts after firing only once no awake slime is within reach of it; a
  released slime that lands on an open trapdoor falls back into the
  basket, which releases it again, so the basket may never empty. Basket
  2's pit, under its gate, may do the same.
- **With O106 (D138), answered by D156:** each release woke the basket's
  whole pile, which then never rested during the drain. The local wake
  (chunk 22l) makes a release wake only the resting slimes it touches;
  this item uses it when it measures the drain, and keeps the emptying
  fix.
- **Proposed (D128):** a fired basket always empties: no released slime
  falls back into it (its trapdoor is shut, or its outlet is off the
  trapdoor, before the next release), and it is empty within its quota
  × 0.3 s plus 10 s of firing, however busy the outlet. The 0.3 s pace
  stays. Where the outlet is stays O62, the basket's own design; only
  the test level's outlets move if the fix needs it.
- **Done when:** from the new fixture with the camera on basket 3, the
  basket fills, fires (the celebration) and is empty within 28 s, every
  released slime a train slime with its size and species, none back in
  the basket; from `s2-basket-offscreen`, basket 2 fires and is empty
  within 14.5 s; from `bedtime` with a releasing basket nothing leaves
  until sunrise (item 23.5's tests still pass); the same seed gives the
  same hash; [DoD 1] and [DoD 9] still pass.

**24.4 A migration wakes sleepers** (reported 2026-09-30, the phone
session; proposed, D139; **settled by the user and done, 61b8d5f, D163**;
master spec's saving rules, D72, D131). *As built and settled:* a
displaced sleeper goes back to its stable ID's spot (a moved spot, or a
changed species with the save's species kept), else to the nearest empty
sleeper spot, taking its ID; only awake slimes, and a sleeper with no
spot left, are lost. The phone's version-1 save: 105 sleepers lost
before, none after. The
phone's old test save (level version 1: 199 sleepers and 1 train slime)
migrated to version 2 as 103 train slimes and 94 sleepers: about 100
sleepers whose spots no longer exist were made lost and sent **awake** to
the loop start.
- **Proposed:** a sleeper displaced by a migration stays a sleeper, placed
  by its stable ID where it still exists, otherwise at a surviving empty
  sleeper spot. Only awake slimes are made lost.
- **A spec change, not only a fix:** D72 and the master spec say that
  slimes a migration displaces "are treated as lost", with no exception
  for sleepers, and D131 built it so. The change is refined there once the
  user approves.
- **Evidence:** `docs/perf/2026-09-30-s20fe/saves/before-migration.test.json.v1`
  (the phone's save before loading) and `after-migration.test.json` (the
  migrated save with the awake pile). Turn them into a fixture or a test
  when building.
- **Done when:** a test migrating the before save fails today and then
  passes: every sleeper of the old save is still a sleeper after the
  migration, none awake at the loop start; awake slimes displaced by a
  migration are still lost (D72); the `old-version` fixture's tests still
  pass; the same seed gives the same hash.

**24.5 A big awake pile at the loop start collapses the frame rate**
(reported 2026-09-30, the phone session; proposed, D139; [DoD 30]; *its
fixture `loop-start-pile` done with 24.4, 61b8d5f; the phone run waits
for session 7, D163*). About
100 awake slimes piled at the loop start ran at 3 fps on the reference
phone (the debug bar: 12 on screen, 99 simulated, 86 off screen). Awake
slimes out of a basket never rest, and the pile sits near the view, so it
never parks either.
- **Proposed:** that save plays without collapsing: in slow motion at
  worst, thanks to the tick cap (D138's cap of 2 ticks per frame).
- **It follows** 24.4 (which caused this pile) and the resting-pile rules
  (O105); chunk 5N (going ahead, D140) lowers the tick itself.
- **Done when:** the after-migration save (as a fixture), played on the
  reference phone with the perf log (`tools/android/perf.sh`, labels
  off), never runs more than the cap's ticks per frame and stays at or
  above the frame rate the cap gives (no catch-up spiral); the numbers are
  recorded in the project documentation.

**24.6 The debug labels are too expensive** (reported 2026-09-30, the
phone session; proposed, D139; debug builds only). **Done in chunk 22b**
(D142): the labels' text is cached and rebuilt at most every 250 ms
(approved, D144), their places follow every frame, so a label may lag its
slime's state by up to 250 ms. The phone number its done-when asks for is
taken with chunk 22's repeat. On the phone, turning
them on took the game from 36–38 fps to 11–14 fps. Chunk 22 already
redraws them only while shown and labels only the slimes seen near the
screen (D138); they haven't been measured on the phone since.
- **Proposed:** make them cheap: cached text, only near the view, or
  updated less often (the implementer's choice, written down).
- **Unchanged:** debug builds only; performance is always measured with
  the labels off.
- **Done when:** on the reference phone, turning the labels on in the same
  scene costs at most a small share of the frame rate (a number measured
  and recorded with the perf log); the labels still show what they show
  today; the release build still has none.

**24.7 Level rule 23: no spot where many slimes gather awake** (the
user, 2026-09-30; D143, approved in direction, D144, the limit proposed;
`../../level-design.md` rule 23; O107; **done, 5509f71**, D163).
*D163 (the user's):* **a basket's own fill doesn't count**: slimes inside
a basket's box are left out, the pile outside it still counts. **Built,
b14f0d5** (D164): the test level passes rule 23 in every section (section
3's play 23 slimes, 0.1 s in a row; with 24.3 in, its drain 5); the
`s3-basket-59of60` bench reads 37, 2.6 s in a row, under 5 s. Section 3
needs no edit under the proposed limit (O107 (c), narrowed; measured
again once the train is left out, D165; 24.8 withdrawn). The change's done-when was: a unit test where a basket's fill above the limit
alone passes and a pile outside it above the limit fails; the test
level's numbers (each section, each basket's drain) taken again and
recorded; the tutorial pages and the `level-review` skill say so; the
suite passes. As measured before it: sections 1 and 2 never above the
limit; section 3 above it in its play (59, 21.9 s in a row) and its
drain (55, 11.3 s), from basket 3's fill.
The user saw "piles of active slimes" next to basket 3, "legit slow fps".
- **Follow-up, a train queue doesn't count (D165, the user's: "Don't
  count train queues"; done, c0924d9, D166):** *as built:* a followed
  train slime not due a move, centre within `Train.OFF_ROUTE` (36 px) of
  its route point, is left out; every section passes, the drains peak at
  1; the synthetic test's pile now off the route. The item as written: train slimes on the loop's route are
  left out of the count before clustering, the way a basket's fill is
  (proposed reading; a train slime due a move to the loop start is off
  the route and counts; the exact test is the build's). The overlay and
  the PERF line still count every slime. Rule 24's cluster check at an
  arrival spot keeps counting train slimes (proposed, O107 (d)).
  **Done when:** a unit test where a train queue above the limit passes
  and a pile of free slimes above it fails; the test level's numbers
  (each section, each basket's drain, the benches) taken again and
  recorded; the tutorial pages (06, 09) and the `level-review` skill say
  so; the suite passes.
- **The measure:** the level bench's RESULT line takes chunk 22d's count
  names, `largest_cluster` (its maximum over the case) and the seconds
  above the limit; each level's played test (from fresh, filling every
  basket, with each basket's fire-and-drain) checks the rule; the
  level-rules checker's rule 23 line points at both (it can't run the
  simulation), as rule 12's played test is its proof. The `stress-*`
  fixtures are excepted.
- **The limit:** calibrated first from 22d's logs and the bench on the
  test level (is a dense train queue one long cluster? O107), then set in
  `tuning.md`; proposed until then: above 20 slimes for more than 5 s in a
  row fails.
- **The tutorial and the skill:** `docs/level-design/06-population.md`
  (the rule, the shapes to avoid) and `09-check-the-rules.md` (where rule
  23's result comes from), and the `level-review` skill's rule list.
- **The test level:** measured and recorded, not edited (section 3 is the
  stress area, D143); if section 3 still breaks the limit in normal play
  once 24.3 has landed, the user decides on a level edit (O107).
  Its test records rule 23's numbers and doesn't fail on them until then.
- **Done when:** the bench reports `largest_cluster` and the seconds above
  the limit on every case; a synthetic level with a bowl feeding a basket
  fails rule 23 in its played test and the same level with them apart
  passes; the checker's report lists rule 23 with where its result comes
  from; the tutorial pages and the skill carry the rule; the test level's
  numbers (each section, each basket's drain) are in the project
  documentation; the suite passes.

**24.8 The train leans away from clusters: withdrawn from v1** (D165,
the user's: "Withdraw it: drop 24.8 from v1; the experiment patch stays
saved; rule 23 is already met on the test level."). The build's
experiment, not committed: the clusters still over rule 23's limit were
100 % mixed-species train queues in section 3's bowl; the trigger fired
on 70 to 87 % of train hops; the lean halved the train's hops, cut
departures past 750 px from 7.5 to 6.6 per 600 ticks and raised the loop
start's mean cluster from 53.8 to 67.6; it failed the played test (2
sleepers left); it would have needed a new save field. The patch is
kept outside the repository, in the orchestrator's handoff folder. The
text below is the item as it was, kept for the record; it is not built.
*Was:* (the user, 2026-09-30;
D143, approved in direction, D144, the numbers proposed;
`req_hopping_behavior`, O107). "we could favor cluster
reducing activity". *D155:* a replacement for this item was tried and
withdrawn; it stays as written below, unbuilt.
- **Proposed:** when a train slime's hop timer runs out, it counts the
  slimes that cost physics within 96 px (2 base-slime diameters) of its
  hop's target that it can't fuse with (another species, or past the
  maximum size); with 3 or more it waits 0.5 s and looks again, at most 4
  times in a row, then hops anyway. Only train slimes; calls and free
  slimes are unchanged. The values are rows in `tuning.md`.
- **Deterministic:** the count comes from the simulation's state (the
  pair grid or the same cells), the wait is a constant, never a draw.
  Hashes change where a train slime lands near a crowd: the chunk lists
  which changed and why, and regenerates the fixtures.
- **Must still hold:** the dip nudge (rule 5, D119's limited wait: the
  `bump` fixture's bumps), no train slime stalls ([DoD 1], D118), a hop
  comes at most 2 s later than its timer.
- **Done when:** a unit test with a crowd of another species at a train
  slime's landing point sees the hop wait, then happen within 2 s; a
  same-species crowd doesn't delay it; the section 3 bench cases and the
  played run of section 3 show the largest awake cluster and the time
  above the limit before and after, recorded in the project
  documentation; [DoD 1] and the `bump` fixture's tests pass; the same
  seed gives the same hash within the new behaviour.

### LD. Level-design toolkit (L, technical)

Asked for by the user (D123). Tooling for whoever designs a level: no
Definition of done item and no business behaviour, so no ATD steps; it
still goes test first. It runs in parallel with chunk 23 and builds on what
chunk 16 left: the test level, its level-rule tests and the level bench.
Split (D126) into **LD1**, the tools, and **LD2**, the tutorial and the
skills, then **LD3**, the gaps LD2 found (D127). All three are done.

- **Tools.**
  - **A level-rules checker, usable on any level.** For every rule in
    `../../level-design.md` (1 to 22), its report says either *checked by
    code* (pass or fail, with where) or *manual review* (what to look at),
    so no rule is left out silently. It reuses the existing level-rule
    tests' checks rather than duplicating them.
  - **A new-level scaffolder.** It creates a level's tree under
    `levels/<id>/` from the level components, its fixtures, a per-level
    test script (the checker plus a load test), and the level's
    integration into the app, so it can be loaded in test mode.
  - **Other tools that make level design easier**, the implementer's
    proposal, written down in the project documentation (for instance a
    debug overlay of rails, framing zones and routes back, or a quick
    fixture maker).
- **A tutorial for level designers:** a series of short, targeted Markdown
  files in `docs/level-design/` (one topic each: starting a level, the
  loop and sections, exploration branches and routes back, frontier sets,
  framing zones, decoration, checking a level against the rules).
- **Project skills in `.claude/skills/`:** start a new level; add a
  section, an interactive object, or a decorative asset; review a level
  against the level-design rules (it runs the checker and walks through the
  manual-review rules).
- **Decoration** has no settled spec yet: O96. The toolkit builds to its
  proposed default (decoration never collides, never takes a tap, never
  hides an interactive object or a hint) and changes if the user decides
  otherwise.
- **Done when:** the checker reports on the test level and agrees with the
  existing level-rule tests (a rule those tests fail, on a synthetic level,
  the checker fails too); the scaffolder creates a level that loads, passes
  its generated tests and appears in test mode; the tutorial and the
  skills exist and walk through creating a small level end to end.
- **Later, before the first level is released (proposed, D127): rule 20's
  released IDs.** A small checker change, not test-level work (the test
  level is never released). A released level keeps a list of its
  released stable IDs (for example `levels/<id>/released_ids`); the
  checker then asks that every released ID still exists, that new
  sleepers take numbers above the highest released one in their section,
  and applies its order and gap checks to unreleased IDs only; removing a
  released ID needs a `level_version` bump and a save migration.
  **Done when:** a throwaway level with a released-ID list passes with a
  sleeper added above the highest number, and fails with a released ID
  removed without a version bump.

### TL1. Test level finishable from fresh (S, proposed)

**Done (D129).** The done-when below is met: 0 FAIL and 0 warnings; the
new played test `tests/e2e/test_test_level_playable_e2e.gd` fills each
basket with base slimes alone (from `fresh`, `gate1-open`, `gate2-open`;
seeds 1 to 6); fixtures regenerated; suite 922/922. Sleepers were lined
up touching (chain waking) within a called base slime's hop; stable IDs
kept, section 3's renumbered left to right (never released, rule 20).
Deviations from the test level's plan and the choices left for the user
(rule 12's reading, rule 22 (b)'s 130 px house style, basket 3's tight
margin) are in D129.

Proposed in D127: LD3's progress estimate warns on all three sections of
the test level, and probes back it. In section 1 only two sleepers are
within a called base slime's reach, and A, B and C awake can't fuse, so 3
base slimes stand against basket 1's quota of 6; sections 2 and 3 follow.
Content work on `levels/test/level.tscn` (through its generator), no new
behaviour, so no ATD steps; it still goes test first.

- Rework the sleeper placement: ledges lowered or moved within a called
  slime's reach, same-species pairs early in section 1. Keep the stable
  IDs, preferring moves that keep the left-to-right order (fixtures and
  tests name sleepers by ID).
- Every level rule still passes, the population stays 200, and the
  coverage matrix still holds.
- **Done when:** the checker gives 0 FAIL and 0 warnings on the test
  level; a scripted play from `fresh` fills basket 1, and from
  `gate1-open` and `gate2-open` baskets 2 and 3; the fixtures are
  regenerated and the whole suite passes (DoD 1 included).

### 5N. Native simulation tick (done, 0f3d027; D158; D140, D142, D143, D155)

Size M. **Chunk 22 was its trigger** (D96): it failed DoD 30 (D138), and
crowd detail was not enough on its own, which meets the user's
conditional go ("Should it prove unsufficient, we will see how it goes
with 5N"). After chunk 22b the user gave the go outright: "ok schedule
work on 5N after this chunk" (D142). **D158 (2026-10-03):** after the
real S20 FE passed DoD 30's targets, the user chose "go native" now
rather than later. The reasons are headroom, not a missed target: the
user's wish for maximum performance before animations and music, the
warm section 1 crowd (18–23 fps), the ~11 ms per-tick floor, the floor
phone still unmeasured. It runs after chunks 22b, 22d, 19w, 22l, 22m
and 22h (all done); chunk 22c follows (D141), and chunk 22
is then repeated (D140, proposed order). **Scope unchanged:** the
preflight notes that the ~11 ms floor may lie partly in behaviour code
(the train, the loop, hops), which stays in GDScript; porting it would
need its own decision, outside 5N (D158). Technical: no ATD steps. It
must not run while another chunk edits the slime body code.

- **Already in place (the verified contingency):** the toolchain and a
  trivial extension under `native/`, documented in `docs/dev/native.md`,
  kept out of the test suite and the exports.
- The simulation tick moves to a GDExtension in C++ (godot-cpp): the ring
  solver, the contacts between slimes, and the terrain contact against
  `TerrainSegments` (D97).
- The simulation keeps its GDScript interface. Behaviour code (hops, phases,
  calls, fusion timing) stays in GDScript, unchanged.
- **It ports the local wake** (D156, chunk 22l): the native rest pass
  wakes only the resting slimes touched, the GDScript behaviour its
  reference; chunk 22's bounding-box and centre-cache ideas carry over
  (D155).
- Built with `-ffp-contract=off`, for the Linux desktop and, through the
  Android NDK, for Android arm64, both from one build script, and included
  in the Android export.
- Determinism: hashes are compared within one build and platform. The
  native results are deterministic within one build but don't match the
  GDScript version bit for bit, and tests compare runs within one build.
- **Saves and fallback (D140):** a save loads under either tick (a save
  written under one runs on under the other). The GDScript tick is kept
  as a fallback, used when the native extension is missing or fails to
  load.
- **Background reading:** `../../tech-direction.md` "Simulation performance"
  and the reference phone numbers in `docs/dev/spike-soft-slimes.md`.
- **Measuring (D142):** desktop numbers at full speed, headless for the
  tick; a slowed run, if any, with `tools/perf_slow.sh --pin=main` (never
  the whole process pinned, which skews the tick and the frame); a phone
  estimate is the full-speed cost × 2.1 cold, × 3.4 throttled, and only the
  phone's perf log settles it. The factors are the GDScript tick's; the
  native tick's own phone factor is measured on the phone.
- **Done when:** the Linux and Android arm64 extensions build from one
  script; the whole suite passes on the native tick; a save written under
  either tick loads under the other, and the game runs on the GDScript
  tick when the extension is missing; the bench numbers
  (desktop and phone, native against GDScript) are recorded in the project
  documentation; and chunk 22, repeated, passes.

## After v1 (D161)

The user (2026-10-07): "nah test level review comes after v1 is
finished. same with geyser etc." These two come **first after v1 is
finished**, with v2's level work (`../v2/README.md`, "Carried in from
v1"). They are not in v1's order and don't gate v1's lock. Their text
below is D160's, unchanged except where the climb fix (24g) now runs
before them; it is revisited when v2 is scoped.

### The geyser object (once chunk 24g's first part; the user's, details proposed, D159, D160; after v1, D161)

The user (2026-10-06): "we must add the geyser thing when reached to
prevent clustering at start point (it's happening right now)"; then
(2026-10-07, D160): "Ensure the geyser option stays (but not
specifically as the end of the route feature, but as a standalone
"object/effect" that happen to be located there. (so that the object can
be reused elswhere)"; then (D161) after v1. Experiment: branch
`exp/geyser` (8b116e4). It adds a level object, so it **keeps both ATD
steps**. It must not run while another chunk edits the Train,
`LoopStart`, `Offscreen` or the level components. Every rule and number
below is D159's and D160's, proposed where it goes beyond the user's
words. Open: O120, O124.

- **Atoms (preflight start):** `rule_geyser_spreads_arrivals_at_loop_start`
  (DRAFT; D160 makes it an object a level places),
  `req_interactive_objects_general`, `req_offscreen_simulation`,
  `req_level_design_rules` (rules 24 and 25),
  `rule_arrivals_clear_faster_than_they_arrive`,
  `req_persistence_and_saves` (to confirm no save key changes).
- **1. The geyser, a level object** (D160 (1), `interactive-objects.md`).
  Variant C from exp/geyser (`src/sim/geyser.gd`,
  `tests/unit/test_geyser.gd`, `SlimeBodies.launch`; 8b116e4), C only,
  generalised: a component (`src/components/`, like `SplitZone`) read
  into `LevelData`, each placement with its catch box, landing span
  (from, to, px along the loop, ahead of the catch), apex and jitter,
  draws, lift cap (defaults D159's, `tuning.md`) and the switch "fused
  slimes only into a split zone". The trigger is a train slime
  travelling into the catch (not any wrap of the loop, as on the
  branch); a slime put inside it (a move to the loop start, a load) is
  never launched. The limits apply to every placement: the loop's own
  route and a free spot (never on the waiting queue), never onto or
  under a guarded ledge, never at or past a gate, the flight clear of
  the terrain; no usable spot, the plain arrival. Off screen, placed
  directly or left in the single file. No save key. The test level
  places one over its return routes' end (span 150 to 700 px, the
  switch on): on the test level it does what D159's geyser did. A debug
  flag (`--no-geyser`) turns every geyser off for runs and tests.
- **2. Rule 25's checks** in the level-rules checker (`tools/check_level.gd`,
  `tools/level_check/`): fail a span off the loop, behind or over its
  catch, or holding a gate; warn when the fused switch is on with no
  split zone over the span; note (not warn) the share of the span under
  a guarded ledge (O124: TL1's guard test keeps the test level at 0
  warnings). Tests on a small level per check, and the test level's
  result.
- **3. The run tool** (24g's) gains the geyser's launches and refusals
  by reason, and landings off the loop and on guarded ledges.
- **Baseline:** 24g's recorded numbers. On exp/dip-jam with G, R and the
  geyser: departures past 750 px 9.0 / 8.6, cluster 90 / 85, fusions
  5.1 / 5.4 (D160 (4)).
- **Done when:**
  - unit tests of the geyser: a placement's data read from the scene
    (catch, span, apex, draws, lift, switch); a slime travelling into
    the catch is launched and lands on a free loop spot in the span;
    never on the queue, on or under a guarded ledge, at or past a gate;
    with the switch on, a fused slime only in a split zone; a slime put
    inside the catch never launched; a parked slime placed, or left in
    the single file when nothing is free; the same seed gives the same
    landing; two placements on one small level each use their own
    span;
  - rule 25's checker tests pass; the test level shows 0 FAIL and 0
    warnings, its ledge note listed;
  - the baseline runs again, both seeds, every number **recorded**
    against 24g's, not a pass or fail on rules 23 and 24; launched
    slimes never land off the loop or on `FirstLedge`;
  - [DoD 1]; the same hash on both ticks and across a save and reload;
    tick cost not above the baseline's; the changed fixture hashes
    listed and re-recorded; the whole suite passes.
- **Seen, not changed:** the idle camera may follow a launched slime away
  from the start; the build reports it as a by-eye item.

### TL2. The test level's start review (S–M, D160, proposed; after v1, D161)

The user (2026-10-07, D160): "don't stress over the crowding of the
loop's start too much. we need to review the test level design better
to reduce the factors affecting this", and "that doesn't prevent
validating this version". **Where it goes (O123, answered by D161):
after v1** ("nah test level review comes after v1 is finished"), after
the geyser object above, whose placement it weighs. Content work on `levels/test/level.tscn` (through its
generator) and the geyser's placement, no new behaviour; if a fix
needs one (pacing the return route's end, O118, parked), it is the
user's call and its own chunk.

- **The factors, each measured with 24g's run tool** (the camera held on
  the start): the arrival rate against the train's take-up (rule 24's
  check; its window and threshold, O119); the first stretch's room
  (length, width, where the queue sits); its slopes (the start basin's
  exit climb rises 0.72 to 0.75 over x 660 to 1,200); the terrace and
  the pocket behind the loop's start; how many slimes come home at once
  (each section's return route, basket 3's drain); the geyser's
  placement and span (O124, `FirstLedge`); and the start crowd's frame
  rate on the reference phone, which v1's DoD 30 leaves aside (D161 (3)).
- **Then:** level edits proposed to the user, one factor at a time, each
  measured; rules 22 to 25 and TL1's done-when still hold; the coverage
  matrix and the population (200) unchanged unless the user says so.
- **Done when:** the factors and the chosen edits are recorded; O119
  and O124 settled; rule 24's check on the test level recorded, pass or
  fail (a fail stays a known gap of the test level, not a v1 blocker);
  fixtures regenerated, the changed hashes listed, the whole suite
  passes.

## Not in this plan

- **The real first level:** chunk L01, moved to v2 (D134). v1 is the
  test level only.
- **The interface design** of the parent screens, setup and the celebration:
  the UX track. The placeholder UI from chunk 18 is replaced then.
- **Playtesting with children** [DoD 32]: deferred, not an objective of
  the full MVP; it may first need some graphics work (D135).
- **The basket's own design** (where it releases its slimes): a later
  spec session. Chunk 14 keeps it swappable.
- **The geyser object and TL2** (D161): after v1, first, with v2's level
  work; their text is kept above, under "After v1".

## Open questions that block chunks

None. O96 (decoration) shapes part of chunk LD, which builds to its
proposed default until it is decided. The questions the first UX review raised (O67–O77, which chunks 7, 9,
12, 17, 18 and 20 built to) were settled as proposed in D102, and the
build's own points O79–O87 in D103–D107.

## Before starting

- Godot 4.7.2 is reachable as `godot` (a symlink in `~/.local/bin`). The
  project skeleton is committed, without the 3D physics setting. Its other
  settings are adjusted to the spec in chunk 0.
- A floor phone (Galaxy A14 class) has to be bought before spike 1's floor
  run and before chunk 22.
- The native contingency (chunk 5N) uses a C++ toolchain on Linux,
  godot-cpp matching Godot 4.7, and the Android NDK (installed:
  `ndk/28.2.13676358`, per the spike); see `docs/dev/native.md`.
