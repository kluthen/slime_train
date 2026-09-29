# Building a level: the tutorial

A series of short pages, one task each, for a level designer who knows the
game but not necessarily its code. Read 00 once, then follow 01 to 11 in
order for a new level, or jump to the page for the task at hand.

| Page | Task |
|---|---|
| [00 Concepts](00-concepts.md) | What a level is made of, in the game's words |
| [01 Scaffold a new level](01-scaffold-a-new-level.md) | One command: the level's folder, its skeleton, its fixture, its test |
| [02 Edit it in the Godot editor](02-edit-in-the-editor.md) | Opening the scene, placing components, units, editing the scene file by text |
| [03 Add a section](03-add-a-section.md) | Everything a new section needs, and what changes in the one before it |
| [04 Interactive objects](04-interactive-objects.md) | Each component: what it does, its fields, the rules it must meet |
| [05 Exploration branches and routes back](05-branches-and-routes-back.md) | A place off the loop, and the way home from it |
| [06 Population](06-population.md) | Sleepers, species per section, the 200 cap |
| [07 Decoration](07-decoration.md) | Scenery that never gets in the way |
| [08 Fixtures and testing](08-fixtures-and-testing.md) | The level's test, its fixtures, test mode, `--at` |
| [09 Check the rules](09-check-the-rules.md) | Reading the checker: PASS, FAIL, MANUAL, N/A |
| [10 The level report](10-the-level-report.md) | Loop length, population, branches, reach |
| [11 Before calling a level done](11-done-checklist.md) | The checklist |

## Before you start

- Run every command from the project's root folder (the one holding
  `project.godot`). Godot 4.7 is on the PATH as `godot`.
- **Run the tools through `tools/level.sh`** (`tools/level.sh check`,
  `report`, `new`, `fixture`, `bench`, then the tool's arguments). It
  imports the project first, so a class added by a pull is known (a tool
  started without that import can stop with `Parse Error: Identifier
  "LevelBuilder" not declared in the current scope`; `godot --headless
  --import` fixes it too, and `tools/test.sh` imports as well), and it
  starts Godot without its banner, so a tool's `--json` is the only thing
  on stdout.
- The pages use a throwaway level, `zz-tutorial`, so every command can be
  copied as is. Use your own level's ID instead (the real first level is
  `01`). A level whose ID starts with `zz-` is a throwaway by convention:
  don't commit one.

## Where things are

- The rules every level must follow: [`specs/level-design.md`](../../specs/level-design.md)
  (rules 1 to 22). The pages cite them by number; the spec is the one
  source, so read their wording there.
- The words: the Terminology table in [`specs/concept.md`](../../specs/concept.md).
- The test level, a worked example of every rule: [`specs/levels/test/README.md`](../../specs/levels/test/README.md)
  and `levels/test/level.tscn`.
- The tools, in depth: [`docs/dev/level-tooling.md`](../dev/level-tooling.md).
- The components' technical notes: `docs/dev/README.md`, "Levels and components".

## Getting help from Claude

Three project skills (`.claude/skills/`) walk through the same tasks with
you and run the tools:

- `new-level`: scaffold a level, run its test and the checker (pages 01, 08, 09).
- `level-content`: add a section, place an interactive object, add a
  decoration (pages 03 to 07).
- `level-review`: review a level against the rules, with what to fix and
  what to look at by eye (pages 09 to 11).

Ask for them by name ("use the level-review skill on level 01") or just
describe the task.
