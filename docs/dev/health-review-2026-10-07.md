# v1 health review, phase 1 (2026-10-07)

A read-only review of the code against `CODING_RULE.md` (rules 1 to 7), at
main `0d0935c`. Nothing in `src/`, `tests/`, `specs/` or the atoms was
changed. Two files were added: this review and `tools/code_health_check.py`,
the checker rule 6 asks for. Phase 2 does the clean-ups, in the order given
at the end.

**Hash safety.** Every clean-up below keeps the state hashes the same unless
it says it is behavioural. A behavioural one needs the user's sign-off
before it is built.

## 1. The rules, one by one

| Rule | Applies? | Current state | Distance from healthy | Proposed fix (size) |
|---|---|---|---|---|
| 1 ATD adherence | Yes | Atoms are linked from 84 src files (565 tags). 1 CONTRACT and 1 VISION atom. Two src files carry no link and aren't on the technical list: `src/components/decoration.gd` and `src/sim/tick_choice.gd`. Four files link more than 10 distinct atoms: `simulation.gd` 21, `main.gd` 15, `slime_bodies.gd` 13, `frontier_sets.gd` 11. In 56 files, some atom is linked only on the file header and on no function or type. 24 test files carry no `@test-link`. No test file uses `@spec-link`. | Medium. The links are there, but often on the header only, and the hub files link too many atoms. | Q5 (header-only tags), S3 (the hub files lose atoms once they are split). Decide decoration and tick_choice (Q4). |
| 2 Time and randomness injected | Yes | Clean. The checker's clock lint finds nothing in `src/sim/`. `tests/unit/test_no_global_random.gd` already refuses global randomness in all of `src/`. No test refuses a clock read in `src/sim/`. In `auto` mode the crowd detail's ceiling comes from a load meter that reads the real clock (`src/platform/load_meter.gd`, D141). It is handed to the sim at a tick boundary, as an input that isn't saved. So a normal-play run doesn't repeat across devices, by design. Test mode uses `always`, so test runs repeat. | None in the code. One gap in the guards. | Q3: a GUT test that mirrors the randomness test for the clock (the checker already does it). |
| 3 Crash early | Yes | Mixed. Loud: `ScreenView.px_per_mm` and `TapDispatcher.hit_area` refuse a bad value with `push_error`. Silent: the `SlimeBodies` readers (`species_of` -1, `size_of` 0, `radius_of` 0.0, `rest_area_of`, `hop_timer_of`, `points_of` empty) answer an unknown id with a default. `ScreenView.set_to` and `Camera.place` turn a zoom of 0 or less into 1.0 without a word. `Train._closest_distance` answers 0.0 without a loop. The ~30 `if x == null: return` guards in src are, with few exceptions, the documented "a level with no loop" case (Train, Fusion, LoopStartQueue, FrontierSets). That's a valid configuration, not a hidden error. | Small to medium. | Q6 (zoom), Q7 (unknown-id readers assert). |
| 4 Strict contracts | Yes | The sanctioned fallback is in place: an unreadable or other-version save is left alone, the level starts fresh and writes are blocked (`rule_saves_never_wiped`, `src/save/save_store.gd`). Save checking (`SaveData.problems`) uses `get(key, default)` to read a key that may be missing, then refuses the save. That's compliant. Save loading (`SaveData.restore` and its helpers, from line 431) has 43 `get(key, default)` calls. Some are keys the format calls optional (`hint_done`, `celebration_done`: "absent: false"). Others aren't checked one by one yet (for example `entry.get("from", [0, 0])` on an off-screen proxy). Records crossing module boundaries are loose Dictionaries: Train's per-slime records, `last_hops`, Offscreen's `away` and proxies, tap targets and hits, level baskets. | Medium. | S4 (restore defaults: documented or direct). Typed records: Train's record first (S1), the others later. |
| 5 Test-first bugs; no test-only branches | Yes | Practised. The switches in `src/sim/` are listed in section 4. Each has a documented reason, and the debug-only modules (`src/test_mode/`, `src/debug/`) stay guarded. | Small. | Q8: one line of reason on each switch that lacks it. |
| 6 Code health | Yes | The checker exists now (section 2). In src: 35 errors and 192 warnings. One file is past 600 effective LOC (`slime_bodies.gd`, 1213) and four are past 400. Three functions nest deeper than 4. 25 public functions have no doc comment. | High for `slime_bodies.gd`. Small for the rest. | S1, S2, Q1, Q2. |
| 7 Change discipline | Yes | Docs are self-sufficient: `docs/dev/*.md` holds no links to chats or tickets. The only URLs are library pages (GUT's documentation, the GodSVG project), and `/tmp` paths appear only as command examples. Docs move with code (the README per chunk). Build output is in `build/`, which is git-ignored. Worktrees are used for experiments (section 5). A stale marker: the doc above `MAX_TICKS_PER_FRAME` (`src/main.gd:86`) still says "(proposed, chunk 22)", though D163 settled the cap. 41 "(proposed)" markers remain in `src/` comments. | Small. | Q2 (the stale marker), and a sweep of the 41 markers against `specs/decisions.md` (in Q2's step). |

## 2. The checker: `tools/code_health_check.py`

```
tools/code_health_check.py              # every finding, then the summary
tools/code_health_check.py --summary    # the summary only
tools/code_health_check.py --no-info    # src/ only
tools/code_health_check.py --self-test  # the checker's own tests
```

It checks the `.gd` files under `src/`. Their errors give exit code 1.
`tools/` and `tests/` are read for information only: their findings print as
`INFO [level]` and never change the exit code. The module doc lists every
check. In short:

- **size:** effective LOC (non-blank lines that aren't only a comment). WARN
  above 400, ERROR above 600.
- **depth:** a function's deepest block. A statement right in the body is
  depth 0. ERROR above 4. Continuation lines don't count.
- **doc:** a `##` comment right above every `func`, with ATD tags and
  annotations in between skipped. A public function without one is an ERROR.
  A private function, an engine callback or a `test_*` function without one
  is a WARN.
- **atd:** distinct atoms per file. In src, a file with no link that isn't on
  the checker's `TECHNICAL` list is an ERROR. More than 5 atoms is a WARN,
  more than 10 an ERROR. An atom linked only on the file header is a WARN. A
  header tag is one not directly atop a declaration (only comments and
  annotations, no blank line, between the two). In tests, a file with no
  `@test-link` is reported, and a `@spec-link` in a test file is an error.
- **clock** (`src/sim/` only): the Time singleton, `OS.get_ticks_*`,
  `OS.get_unix_time`, `OS.get_system_time_*`, the Engine frame counters, the
  process deltas, the global random functions, `shuffle` and `pick_random`,
  a `RandomNumberGenerator` made outside `src/sim/rng.gd`, `Timer.new`,
  `create_timer` and `Thread.new`. Comments, string literals and function
  definitions (Rng's own `randf()`) are ignored.

`TECHNICAL` (the files allowed no ATD link) holds `src/debug/`,
`src/test_mode/`, `src/test_mode_guard.gd`, and these files: rng,
fixed_step, state_hash, stable_id, polyline, terrain_segments, the slime
renderer, world and demo, placeholder_art and shape_instances.

### Results at 0d0935c

```
Summary
  src: 97 files, 11775 effective LOC
    size  ERROR 1, WARN 4
    depth ERROR 3
    doc   ERROR 25, WARN 126
    atd   ERROR 6, WARN 62
    clock none
    largest: slime_bodies.gd 1213, main.gd 571, save_data.gd 521, camera.gd 460, train.gd 428, slime_census.gd 396
  tools: 31 files, 5100 effective LOC
    size  INFO ERROR 1, INFO WARN 1
    depth INFO ERROR 1
    doc   INFO WARN 16
    atd   INFO WARN 17
  tests: 157 files, 25214 effective LOC
    size  INFO WARN 4
    depth INFO ERROR 1
    doc   INFO ERROR 98, INFO WARN 1780
    atd   INFO 24
  src/ total: 35 ERROR, 192 WARN -> FAIL
```

The src errors in detail:

- **size:** `src/sim/slime_bodies.gd` has 1213 effective LOC. Above 400:
  `main.gd` 571, `save_data.gd` 521, `camera.gd` 460, `train.gd` 428.
  Everything else is under 400, including `frontier_sets.gd` and the new
  `src/platform/load_meter.gd`.
- **depth 5:** `SlimeBodies._build_pairs` (line 1528),
  `SlimeBodies._solve_contacts` (line 1627) and
  `DebugCounts.touching_by_distance` (`src/debug/debug_counts.gd:249`).
- **doc, public functions without `##` (25):**
  - `SlimeBodies`, 12: `points_for`, `ring_radius_for`, `has`, the readers
    `species_of` to `points_of`, `set_state`, `is_parked`;
  - `Train`, 2: `tracks`, `laps_of`;
  - `TerrainSegments`, 2: `segment_count`, `is_empty`;
  - one each: `ScreenView.dump`, `Species.color`, `Rule.make`;
  - two in `PlaceholderArt`;
  - `references()` in four components (loop_segment, route_back, signpost,
    switch).
- **atd:**
  - no link: `decoration.gd` and `tick_choice.gd`;
  - more than 10 atoms: `simulation.gd` 21, `main.gd` 15, `slime_bodies.gd`
    13, `frontier_sets.gd` 11.

In tools: `tools/make_fixture.gd` has 663 effective LOC, and
`tools/dipjam_probe.gd` has 450 effective LOC and a depth of 7 in `_run`.

The 98 tests errors are public helper functions without a doc comment. The
1780 warnings are mostly `test_*` functions, whose names say their intent.

## 3. The known items, checked

- **Size.** See section 2, and S1 and S2 below for the seams.
- **`Train._behind`** (`src/sim/train.gd:774`). It scans every train record
  per take-off: O(take-offs × train slimes) per tick, with a
  `bodies.state_of` (a binary search) per record. Take-offs are a few per
  tick, so this is about one extra scan of the records per take-off. An
  ordered index (the train slimes' distances sorted once per `follow()`,
  then a binary search per take-off) only pays when several slimes take off
  on the same tick. It is cheap to build, but it must keep the exact
  tie-breaks: a gap of 0 counts as a whole lap for a higher id, and an equal
  gap picks the higher id. Build it only if the phase timers show the relay
  matters at stress-dense (Q9: measure first).
  `bodies.train_hopped.has(follower)` is another linear scan in the same
  loop.
- **Stale comment.** `src/main.gd:86`: "(proposed, chunk 22)" above
  `MAX_TICKS_PER_FRAME := 2`. D163 settled it (Q2).
- **Save and reload.** A save from the command line at N ticks, reloaded and
  run to 600, doesn't give the straight run's hash, even on `fresh`. This is
  by design: `SaveData.restore` ends with `MidairLanding.apply` (D12, master
  spec §5.10, DoD 28), which puts every slime in the air down at rest. In a
  live run at tick N, train slimes are mid-hop. The in-process cross-load
  tests pass because they build states with no slime in the air:
  `auto_hops = false`, settled first (for example
  `tests/unit/test_stuck_slimes.gd:239`). Floats aren't the cause:
  `SaveData.exact` carries every float exactly. Nor is the crowd detail: test
  mode runs `always`.
  - Proposed check (Q10): run a fixture to N with auto hops, then compare the
    command line's save-and-reload hash at 600 with the in-process
    `Simulation.from_save(to_save())` at N run to 600. They must be equal.
    Also report how many slimes MidairLanding moved, so a mismatch with zero
    landings flags a real bug (a cache that isn't saved).
- **Quota pies** (`src/frontier/quota_display.gd`, `unit_species()`, and
  `src/frontier/frontier_view.gd:285`). The units fill in ascending id order
  and are worked out again every frame from the slimes in the basket. A
  basket releases `inside[0]`, its lowest id (`FrontierSets._basket_step`),
  so every unit after it moves down by that slime's size, and the colours
  shift.
  - A fix inside the view is hash-safe (it changes no sim state). The view
    keeps each basket's unit list from one frame to the next: a slime that
    leaves leaves holes, which the last units fill, and an arrival adds units
    at the end.
  - The fix changes what the player sees, though. The quota display's doc
    says the units fill in order, so the user decides (section 7).
- **`Offscreen._lose`.** Already public: `Offscreen.lose()`, which
  `src/debug/debug_kill.gd:37` calls directly. Nothing to do.
- **Clock.** grep and the checker agree: no clock or global randomness in
  `src/sim/`. The hits in `src/sim/rng.gd` are its own doc and the seeded
  generator's `randomize()` on its private `RandomNumberGenerator`.
- **Docs self-sufficient.** See rule 7 in section 1. No change needed.

## 4. Switches inside `src/sim/` (rule 5)

| Switch | Default | Set by | Reason | Verdict |
|---|---|---|---|---|
| `Offscreen.enabled` | false | `src/main.gd:1019` (the game), the bench tools | Physics only near the screen is the game's mode. Bare sims in unit tests simulate everything. | Keep. It is a mode of the game, not a test branch. Say so in its doc, which reads only "the game's mode" (Q8). |
| `SlimeBodies.rest_enabled` | true | 5 test files (physics without the resting-pile rule) | Isolates the solver from the rest rule in tests. | Test-only. Propose removing it once those tests can settle with rest on, or keep it with a documented reason (Q8). It costs one branch per tick. |
| `SlimeBodies.auto_hops` | true | 18 test files (`auto_hops = false`) | Deterministic set-ups without the seeded hops. | Test-only, used widely. Keep it, with a documented reason (Q8). |
| `Session.enabled` | false | `Session.open()` (normal play, test mode's "sessions") | A level runs with or without sessions. | Keep. It is a product mode. |
| `Offscreen.detail_ceiling` | `MAX_DETAIL` | The game root before every tick (LoadMeter, D141) | An input, not a switch. | Keep. It is documented. |
| `SlimeBodies.phase_timers` | null | The debug overlay (`src/debug/phase_timers.gd`) | Measurement only, with no clock read in sim. | Keep. It is documented as debug. |
| Train's hop counters, `last_target_kind`, `last_hops` | (always on) | The perf log and the slime census | Debug bookkeeping in product code. It runs in release builds too, but isn't state. | It is a leftover: move it out of `train.gd` with S2. |

## 5. Leftovers

- **Debug code carried as product code:**
  - Train's hop counters and `last_hops` (the census), above;
  - `src/debug/` is guarded by TestModeGuard and loaded at run time. That's
    compliant.
- **Probes in `tools/`.** Both are documented in the tools table of
  `docs/dev/README.md` (lines 91 and 92):
  - `tools/gobble_probe.gd` (O91): keep, it watches deep overlaps;
  - `tools/dipjam_probe.gd`: keep, but rename it `tools/train_flow_probe.gd`
    (its own doc says the name is historical) and split its 7-deep `_run`
    (Q11).
- **Worktrees:** 4 (none deleted).
  - `.claude/worktrees/agent-a3e5c8d4f78183b98`: `exp/geyser`, locked;
  - `.claude/worktrees/agent-a994fc5fd516987db`: `exp/dip-jam`;
  - `.claude/worktrees/agent-aff8de51e283a3ffe`: `fix/gobble`;
  - `.claude/worktrees/pacing`: `exp/pacing`.
- **Branches already merged into main:** 18, all safe to delete when the
  user says.
  - archive/fps-session-2026-10;
  - chore/24g-close;
  - chunk-16-wip;
  - feat/22-labels;
  - feat/22c;
  - feat/24-2;
  - feat/24-3;
  - feat/24-4;
  - feat/24-7;
  - feat/24g;
  - feat/release-hop;
  - feat/rule23-basket;
  - feat/rule23-queue;
  - fix/gobble;
  - fix/hash-view;
  - the three `worktree-agent-*` branches.
- **Branches not merged:** `exp/dip-jam`, `exp/geyser`, `exp/pacing`.
  These are experiments: the geyser waits until after v1.

## 6. Quick wins (under 1 h each)

| # | What | Files | Hash safety |
|---|---|---|---|
| Q1 | Add `##` docs to the 25 public functions without one. | `slime_bodies.gd`, `train.gd`, `terrain_segments.gd`, `screen_view.gd`, `species.gd`, `rule.gd`, `placeholder_art.gd`, 4 components | Comments only. |
| Q2 | Drop "(proposed, chunk 22)" at `src/main.gd:86` and cite D163. Sweep the 41 "(proposed)" markers in `src/` against `specs/decisions.md`, and drop the settled ones. | `src/main.gd`, the files listed by `grep -rn proposed src` | Comments only. |
| Q3 | Add `tests/unit/test_no_clock_in_sim.gd`, which mirrors `test_no_global_random.gd` with the checker's clock patterns. | new test | Adds a test. |
| Q4 | `tick_choice.gd` goes on the checker's technical list (it picks native or GDScript). `decoration.gd` gets the atom of O96 / D123, or the technical list if the decision is that decorations are art only. | `tools/code_health_check.py`, `src/components/decoration.gd` | Comments only. |
| Q5 | Move the header-only ATD tags onto the function or type they cover: 56 files, 1 to 4 atoms each. Do it file by file with the checker's list, in 2 or 3 sittings. | src files the checker lists | Comments only. Run `atd check` after. |
| Q6 | A zoom of 0 or less in `ScreenView.set_to` and `Camera.place`: `push_error` and refuse, as `px_per_mm` already does, instead of a silent 1.0. | `src/sim/screen_view.gd`, `src/sim/camera.gd` | No valid caller passes 0, so the hashes stay. Confirm with the full suite. |
| Q7 | The `SlimeBodies` readers (`species_of` to `points_of`) `assert` a known id (debug builds), keeping the release return. First grep their callers for any that relies on the default. | `src/sim/slime_bodies.gd` | Same hashes if the full suite stays green. A failing assert is a bug found, to be fixed test-first. |
| Q8 | A line of reason on `Offscreen.enabled`, `rest_enabled` and `auto_hops` (section 4). | `offscreen.gd`, `slime_bodies.gd` | Comments only. |
| Q9 | Measure the relay (`Train._relay`/`_behind`) at stress-dense with the phase timers before building any index. | none (a measurement) | Read-only. |
| Q10 | The reload check of section 3: the command line's save-and-reload equals the in-process cross-load, and the count of mid-air landings is printed. | a new test, or `tools/` | Adds a check. |
| Q11 | Rename `tools/dipjam_probe.gd` to `tools/train_flow_probe.gd` and split `_run` to depth 4 or less. | `tools/`, `docs/dev/README.md` | A tool only, so the game's hashes can't change. Its STATE line stays the same. |
| Q12 | Bring depth 5 down to 4 in `DebugCounts.touching_by_distance` (debug, extract a helper). | `src/debug/debug_counts.gd` | Debug only. |

## 7. Structural items

**S1. Split `src/sim/slime_bodies.gd` (1213 → under 600).** Effective LOC
per section, before the internals:

- header and arrays 110;
- native or GDScript tick 17;
- sizes 16;
- creating and removing 61;
- reading 46;
- changing 112;
- saves 60;
- calm and detail 74;
- ticking 148.

The internals hold 569.

The seams, in order:

1. `src/sim/slime_solver.gd`, about 370 LOC: the GDScript solver, as static
   functions over the bodies' arrays. It takes `_integrate`, `_build_pairs`,
   `_solve_contacts`, `_solve_rings`, `_solve_terrain` and `_solve_against`.
   It mirrors the native solver (`solver_contacts.cpp`), and the native
   equivalence tests already pin it. Take the two depth-5 functions down to
   4 while moving them.
2. `src/sim/slime_detail.gd`, about 150 LOC: calm, rest and detail. It takes
   the "calm and detail" section, `_resample`, `_reshape`, `_detail_points`
   and `_rest_offset`.
3. `src/sim/slime_bodies_save.gd`, about 60 LOC: `dump()` and `restore()`
   for the bodies.

What is left (the arrays, create, remove, read, change, the tick's
orchestration, the hops) is about 600 LOC. It goes under 600 once the hop
helpers (`_auto_hops`, `_hop_at`, `_can_hop_at`) move into the tick's file
or stay as a short section. The ATD links split with the code: each file
gets 3 to 6 of the 13 atoms.

- **Risk:** the code moves only, but the GDScript fallback reads its arrays
  through an object reference instead of `self`, which costs a little on the
  GDScript path. The native path, which the phone runs, is untouched.
- **Hashes:** the same float operations in the same order. Prove it with
  `tools/test.sh`, the native equivalence tests and the recorded fixture
  hashes.
- **Size:** 1 to 2 days, one seam per commit.

**S2. Split `src/sim/train.gd` (428 → under 400) and move its debug
bookkeeping out.** The seams:

1. the debug hop bookkeeping: `_count_landing`, the hop counters,
   `last_target_kind` and `last_hops`, about 35 LOC, move to a
   `TrainHopLog` that the perf log and the census read;
2. the climb (the hold on a climb and the relay: `_relay`, `_behind`), about
   35 LOC, moves to `train_climb.gd`, where an index for `_behind` would go
   if Q9 calls for one;
3. steering: `aim`, `hop_target`, `highest_between`, `steer`, about 100 LOC;
4. the placeholder slide (`_carry`), small. It goes when the real slide comes
   with the level art.

Seams 1 and 2 are enough to pass under 400.

- **Risk:** low. Debug values are read only, and the relay acts at the end
  of `follow()` with no state of its own.
- **Hashes:** the same.
- **Typed record:** Train's per-slime record (`_records[id]["distance"]`
  and so on) is the cheapest typed record to make here. It is read on every
  tick, so a typed inner class is faster too. It is not in the hash, as long
  as `dump()` writes the same Dictionary.
- **Size:** half a day to a day.

**S3. Thin the hub files' ATD links, and `main.gd`'s `_ready` (105 LOC).**

- `main.gd` (571 LOC, 15 atoms) loses its debug wiring to a
  `src/debug/debug_wiring.gd` (debug-only, guarded), about 100 LOC:
  - `add_debug_overlay`;
  - `use_debug_labels`;
  - `add_perf_log`;
  - `use_phase_timers`;
  - `use_census`;
  - `wipe_saves`.
  `_ready` splits into argument parsing, level opening and the platform
  hooks.
- `simulation.gd` (21 atoms) keeps the atoms of what it orchestrates, on
  the functions that do it. The atoms of its parts go to the parts.
- `frontier_sets.gd` (11 atoms) drops to 10 or fewer when its tags move to
  functions (Q5).

`save_data.gd` (521 LOC) and `camera.gd` (460 LOC) are warnings only. Their
sections (saving, checking, loading, text) are clean seams, but splitting
them can wait.

- **Hashes:** the same.
- **Size:** about a day.

**S4. The 43 defaults in `SaveData.restore`.** Each one should be either a
key the format documents as optional, with its absent meaning (the save
format's doc in `save_data.gd` and `docs/dev/README.md`), or a direct
`save[key]` that the checker already guarantees. A valid save holds every
key, so this keeps the hashes. A key that turns out neither documented nor
checked is a contract gap: it gets a check, which is a format-contract
change, so it needs the user's warning (rule 4). Size: half a day.

## 8. Proposed order for phase 2

1. Q2, Q1, Q8, Q4 (comments and the checker's list), with one commit.
2. Q3 and Q10 (the new guards), before anything moves.
3. Q6 and Q7 (fail fast), with the full suite.
4. S2 (train.gd), then S1 (slime_bodies.gd), one seam per commit. Check the
   hashes and the native equivalence tests after each.
5. Q5 (tags onto functions), file by file as files are touched, then the
   rest.
6. S3, then S4.
7. Q11, Q12 and Q9 whenever there is time. The `_behind` index only comes
   if Q9 asks for it.

**Behavioural, so the user decides first:**

- the quota pies' colour shift (section 3);
- any save-format check that S4 turns up.

**The user's call, not code:**

- deleting the 18 merged branches and any of the 4 worktrees.

## Not yet reviewed

- S4's one-by-one sort of the 43 restore defaults (only sampled here).
- A full list of the Dictionaries used as records (only Train's, Offscreen's,
  the taps' and the baskets' were named).
- The split seams of `save_data.gd` and `camera.gd` beyond their section
  markers.
- `tools/make_fixture.gd` (663 effective LOC; information only, under
  `tools/`).
