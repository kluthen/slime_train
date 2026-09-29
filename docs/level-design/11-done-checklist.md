# 11 Before calling a level done

Work down the list; each line says how to check it. The `level-review`
skill runs most of it for you.

## The files

- [ ] `levels/<id>/level.tscn`, `levels/<id>/fixtures/` and
      `tests/e2e/levels/test_level_<id>.gd` (with its `.uid`) are all there,
      and nothing else: no script inside `levels/<id>/` (D6).
- [ ] `project.godot` is unchanged (`git status`: nothing you didn't mean,
      [02](02-edit-in-the-editor.md)).
- [ ] No throwaway `levels/zz-*` level or its test is left over.
- [ ] The root's `level_id` is the folder's name; `level_version` is 1
      until release.

## The rules

- [ ] The full checker has no FAIL (exit 0):
      `tools/level.sh check --level=<id>`
      ([09](09-check-the-rules.md)), and no warning left unplayed: a rule
      12 warning (a section that may not progress) is settled by playing
      that section.
- [ ] Every `manual:` line and every MANUAL rule looked at in test mode,
      with `--at=<stable id>` on the thing it's about: hints that read as
      something to explore (rule 9), ground with no sleeper leading back
      (rule 7), no tilt needed (rule 10), exploration on a return route a
      lid shuts (rule 14), frontier sets kept as landscape not blocking the
      loop (rule 15), big piles still (rule 16), where a wider view is needed
      (rule 19), low ledges holding no sleeper (rule 22).
- [ ] The rules re-read in [`specs/level-design.md`](../../specs/level-design.md):
      a rule newer than the checker is checked by hand.

## The numbers

- [ ] The level report ([10](10-the-level-report.md)): at most 200 base
      slimes; each quota well under "available by then"; every section
      "progresses" in the progress section; section 1 has sleepers a size 1
      reaches near the start; routes back well under "lost".

## The tests and the fixtures

- [ ] Fixtures rewritten after the last change:
      `tools/level.sh fixture --level=<id>`,
      and any hand-made fixture redone ([08](08-fixtures-and-testing.md)).
- [ ] The level's test passes (section 1 played to its basket full, no
      fixture older than the level):
      `tools/test.sh -gdisable_colors -gselect=test_level_<id>`.
- [ ] The whole suite still passes: `tools/test.sh`.

## Played

- [ ] Played in test mode from `fresh` through section 1, and from each
      `gate<k>-open` through the next section, down to the celebration:
      every basket can be filled with slimes the player can really wake.
- [ ] The first call and the first sleeper pay off within seconds (rule 18).

## Written down

- [ ] The level's design (sections, areas, population, fixtures, how it
      meets each rule) is written like the test level's
      ([`specs/levels/test/README.md`](../../specs/levels/test/README.md)):
      that document belongs to spec-writer, in `specs/levels/<id>/`.
- [ ] Once released, the level never changes but for minor updates with a
      save migration, keeping every stable ID (rule 20).
