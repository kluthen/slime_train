---
name: level-content
description: Add or change content in an existing Slime Train level (levels/<id>/level.tscn) - a new section, an interactive object (sleeper, switch, basket, gate, signpost, framing zone, exploration branch, route back, split zone, loop segment, terrain), or a decoration - by guiding the designer in the Godot editor or editing the scene file, then checking the result with the level-rules checker and the level's test. Use this whenever the user wants to add, place, move, configure or remove anything in a level, design a branch or a ledge, add sleepers, make a basket or gate work, or asks for a new kind of object (it explains why that is v2 scope), even if they don't name the component.
---

# Level content

Three guided flows on an existing level: **A** add a section, **B** place
or configure an interactive object, **C** add a decoration. Each ends with
the same checks. The how-to lives in the tutorial, `docs/level-design/`;
read the page named in each flow before acting, and send the user there
for more.

The user is a level designer who may not know the code. Use the project's
words (Terminology in `specs/concept.md`): species, section, loop, return
route, frontier set, switch, basket, gate, split zone, sleeper,
exploration branch, route back, framing zone, decoration. Cite level rules
by number, with the wording of `specs/level-design.md`, read there (never
from memory: the rules change; the checker's short titles are summaries). Run every command from the project root.

## Ground rules

- **Content only.** A level holds only the components in
  `src/components/`; nothing inside `levels/<id>/` is a script (D6). Don't
  edit `src/`, `tools/` or `tests/` for a content request: if a tool is
  wrong, report the command and its output.
- **A new kind of object** (what a user may call a new object type) is v2 scope:
  say so, compose what the user wants from existing components if possible,
  and name what the real thing would take: a decision in the spec first
  (spec-writer: what it does, which rules it must meet), then a component
  and its simulation (a coding chunk).
- **Decoration** follows O96's proposed default (D123): it never collides,
  never takes a tap, and one drawn in front must never hide an object or a
  hint. Anything a slime stands on is `Terrain`.
- **Stable IDs** `<place>.<kind>.<name>`, unique; sleepers numbered from
  `.01` left to right per section (renumber those to the right when
  inserting one, only before release: rule 20).
- **Units:** the scene holds px; 1 screen = 1152 px; y grows downward.

## How to make the change

Pick with the user:

- **They edit in the editor** (the recommended way for a real level): give
  step-by-step instructions from `docs/level-design/02-edit-in-the-editor.md`
  (open with `godot --path . -e res://levels/<id>/level.tscn`; afterwards
  `git checkout project.godot`).
- **You edit the scene file**: read `level.tscn` first, then follow
  "Edit the scene file as text" in `02-edit-in-the-editor.md`: reuse the
  file's `[ext_resource]` ids (add one for a component it doesn't use yet),
  put new `Curve2D` sub-resources above the first `[node]`, leave out
  `unique_id` and `script` lines, keep the `Loop`'s segments in loop order.
  Group new nodes under a plain `Node2D` (the skeleton groups by section:
  `Section2/Lookout`, `Section1/Decoration`; any depth works).

Before editing, run the fast check once so you know which findings were
already there:
`tools/level.sh check --level=<id> --fast`

## Flow A: add a section

Read `docs/level-design/03-add-a-section.md` and follow its list. In short,
for a new last section N+1 after section N: ground for it and room for its
return route home; section N's frontier set gets `sN.gate` (with its
`entrance_lid`), `sN.basket` targets it (`on_full_object`, `outlet`
`onward_route`), `sN.slide` names it (`gate_id`); new `s<N+1>.loop` joining
`sN.loop`'s end, and `s<N+1>.slide` home behind the loop's start; the new
frontier set (last: no gate, the basket's target is the celebration);
sleepers with the one new species; framing zones only where a wider view
is needed (optional; judged by eye). If the level is still
the untouched skeleton, re-scaffolding with one more section is simpler
(the `new-level` skill); confirm before deleting anything. Editing as
text, the page's "borrowing the skeleton's geometry" trick (a throwaway
`zz-ref-<name>` level, diffed with `unique_id=` stripped, its resource ids
renamed to yours) gives the new section's pieces; remove the reference
level, its test and the test's `.uid` afterwards.

Rules to look at: 1, 3, 11, 12, 13, 14, 16, 21, 22. The fixtures change:
`gate<N>-open` is new.

## Flow B: place or configure an interactive object

Find the component in `docs/level-design/04-interactive-objects.md` (its
fields and the rules it must meet); for an exploration branch, its route
back, a ledge or sleepers off the loop, read
`05-branches-and-routes-back.md` too, in particular "Reach, and rule 22":
a ledge a base slime can reach can't overhang the loop outside the split
zone. For sleepers, `06-population.md` (species per section, the 200 cap,
quotas).

After the checks, look at it where the child will: `godot --path . -- --test-mode --level=<id> --seed=1 --at=<its stable id>`
(add `--fixture=gate<k>-open` for a later section), and read the level
report's reach, branch, frontier-set and progress lines for it.

## Flow C: add a decoration

Follow `docs/level-design/07-decoration.md`: a `Decoration` with a closed
outline, a `fill_color`, `in_front` off unless it must be in front. Rule 9
is the one the checker enforces on it (`--rule=9`).

## Checks, every flow

1. `tools/level.sh check --level=<id> --fast`
   while iterating; then the full checker (no `--fast`) once it's clean.
   Exit 0 no FAIL, 1 a FAIL. Fix every new FAIL; the finding says what and
   where (`09-check-the-rules.md`). A new `warn:` under rule 12 means a
   section may no longer fill its basket: say so and play it.
2. `tools/level.sh fixture --level=<id>`
   to rewrite the fixtures (a fixture saved before the change misses what
   the level gained; the level's test fails on it, "fixture X is older than
   the level"). Hand-made fixtures have to be redone by hand
   (`08-fixtures-and-testing.md`).
3. `tools/test.sh -gdisable_colors -gselect=test_level_<id>` (it also plays
   section 1 to its basket full).
4. `tools/level.sh report --level=<id>`
   when population, reach, quotas or routes back changed: every section
   should still "progress".

## Report to the user

What changed (the stable IDs added or changed, and where in screens), the
checker's summary line and any FAIL left with its fix, the test result,
the `manual:` items this change touches with an `--at=` command for each,
and anything to play by hand. Don't commit unless asked.
