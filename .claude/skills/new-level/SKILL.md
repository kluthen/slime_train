---
name: new-level
description: Start a new Slime Train level from nothing - its folder and skeleton scene (levels/<id>/level.tscn), its fresh fixture, its own test script, and its integration into the game (test mode, the tools, the tests) - then run its test, the level-rules checker and the level report, and point to the next design steps. Use this whenever the user wants to create, start, scaffold, initialise or set up a level (for example "start level 01", "make me a new level with 3 sections", "a new map/world to try an idea"), or asks how a new level gets registered, loaded or tested, even if they don't say "scaffold".
---

# New level

Guide a level designer (who may not know the code) through creating a new
level with the project's scaffolder, and prove it works. The tutorial this
skill follows is `docs/level-design/` (pages 01, 08, 09, 10); send the user
there for the details rather than repeating them.

Use the project's words (the Terminology table in `specs/concept.md`):
species, section, loop, return route, frontier set, switch, basket, gate,
split zone, sleeper. Run every command from the project root.

## Ground rules

- A level is content, not code (D6): nothing but `level.tscn` and
  `fixtures/` inside `levels/<id>/`. Never write a script there.
- There is nothing to register by hand. `LevelCatalog`
  (`src/level_catalog.gd`) finds `levels/<id>/level.tscn` by convention; no
  list, no `project.godot` entry, no menu. Choosing a level exists only in
  test mode and the tools (v1 ships one level; a normal run still loads the
  test level). Don't add a level menu or touch `src/`: that is out of v1
  scope.
- Never run the scaffolder on an existing level; it refuses anyway. To start
  over, the user deletes `levels/<id>/` and
  `tests/e2e/levels/test_level_<id>.gd` (and `.uid`) first; confirm before
  deleting anything.
- Don't commit unless asked. If a tool fails in a way the tutorial doesn't
  explain, report the exact command and output; don't patch `tools/` or
  `src/`.

## Steps

1. **Settle the ID and the section count.** Ask if not given, and confirm:
   - ID: lowercase letters and digits, words joined by hyphens (`01`,
     `my-level`), not `test`, and `levels/<id>/` must not exist
     (`ls levels/`). An ID starting with `zz-` is a throwaway, never
     committed.
   - Sections: 1 to 4 (section 1 has 3 species, each later one adds one, of
     the game's 6: rule 11). If `specs/levels/<id>/README.md` exists, take
     the count from it. Scaffolding all sections now is less work than
     adding them later.

2. **Scaffold:**
   `tools/level.sh new --id=<id> --sections=<n>`
   Exit 0 written, 1 refused (already exists), 2 bad arguments, 3 a write
   failed. `tools/level.sh` imports the project first, so a class added by a
   pull is known (run bare, a tool can stop with `Parse Error: Identifier
   "..." not declared` until `godot --headless --import`).

3. **Explain what exists now**, briefly: `levels/<id>/level.tscn` (the
   skeleton: the start basin, and per section a dip in the loop with a
   hollow on each rim holding two sleepers, a frontier set, the return
   route home), `levels/<id>/fixtures/fresh.fixture.json`,
   `tests/e2e/levels/test_level_<id>.gd` (the test run in step 4 imports
   first and adds its `.uid`; all of these get committed, unless the level
   is a `zz-` throwaway). And how the game finds it (ground rules above).
   The scaffolder prints its own short "Next steps"; follow this skill's
   order instead.

4. **Prove it works**, and show the key lines of each:
   - the fixtures to start at each section:
     `tools/level.sh fixture --level=<id>`
     (exit 0; rewrites `fresh` and writes one `gate<k>-open` per gate, that
     is sections minus 1, since the last basket fires the celebration: with
     2 sections, `gate1-open`. Each is a sidecar `<name>.fixture.json` plus
     a save `<name>.json`. With 1 section there is only `fresh`);
   - the level's test: `tools/test.sh -gdisable_colors -gselect=test_level_<id>`
     (expect `6/6 passed.`, about 15 s: one test plays section 1 to its
     basket full with scripted calls, one checks no fixture is older than
     the level);
   - the checker: `tools/level.sh check --level=<id>`
     (exit 0 no FAIL, 1 a FAIL, 2 can't run; on the fresh skeleton expect
     `21 PASS, 0 FAIL, 1 MANUAL, 0 N/A, 0 warnings`: rule 19 MANUAL with no
     framing zone);
   - the level report: `tools/level.sh report --level=<id>`
     (exit 0; its header names the first slime's species (A); expect rules
     16 and 11 PASS, every row under `== reach ==` reachable by a called
     size 1 hop, and every section "progresses" under `== progress ==`.
     Its lap times are worked out from lengths and paces, so they differ a
     little from the checker's measured laps).

5. **Tell the truth about the skeleton.** It passes the checker and each
   section can be played to its basket (the report's progress section; the
   level's test plays section 1), but it is a placeholder, not a design:
   one dip and four sleepers per section, no exploration branch, no
   framing zone. When the user reshapes it, keep the progress lines at
   "progresses" and the level's test green: a sleeper moved out of a
   called base slime's hop (`docs/level-design/05-branches-and-routes-back.md`,
   "Reach, and rule 22") can leave a basket unfillable.

6. **Point to the next steps:**
   - play it: `godot --path . -- --test-mode --level=<id> --seed=1`
     (`--fixture=gate1-open` starts at section 2 once step 4 wrote it;
     `--at=<stable id>` puts the camera on a thing);
   - edit it in the editor: `godot --path . -e res://levels/<id>/level.tscn`
     (then `git diff project.godot`: don't commit an editor change there by
     accident);
   - the tutorial, `docs/level-design/README.md`, pages 02 to 11;
   - the `level-content` skill (sections, objects, decoration) and the
     `level-review` skill (the rules).

## Report to the user

What was created (the three paths), the test and checker results with
their key lines, the skeleton caveat, and the next steps. Keep it short.
