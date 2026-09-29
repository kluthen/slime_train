# Slime Train — project instructions

## Project layout

- `specs/`: the spec tree, maintained by spec-writer. Start with `specs/README.md`.
- `ui_ux/`: the UX design tree, maintained by ux-writer (no design yet).
- `docs/research/`: verbatim research reports with their sources.
- `docs/*.atom.md`: ATD declared intent, maintained by documentalist.

## Level design

Tutorial for building a level: `docs/level-design/` (start with its README).
Project skills: `new-level`, `level-content`, `level-review` (`.claude/skills/`).

## Declared intent

This project records its declared intent with ATD: atoms in `docs/*.atom.md`,
linked from code by `@spec-link` / `@test-link`, managed with the `atd`
tool. `documentalist` owns it; leaders gate every change through it (skill
`intent-gating-protocol`).

## Project lexicon: coach the user on it

The canonical terms are listed in the **Terminology** table of
`specs/concept.md`. It is the single source of truth, so keep it current as
terms are added.

When the user misuses a term, or uses an old synonym (for example "type"
instead of "species", "gate" for what is now a "switch", or "path" or "new
loop" for what is now the "loop" or a "section", "defusing spot" for what is
now a "split zone"):

- Understand what they meant and carry on normally. Never block on it.
- At the **end** of your message, add a short, friendly information box that
  gives the proper word and a one-line reminder of the concept. For example:

  > 💡 **Lexicon:** "species" is our word for a kind of slime (it replaces
  > "type"). Only slimes of the same species fuse.

- Stay positive and brief. It's a reminder, not a correction. Leave the box
  out when every term was used correctly.
- In documents, always use the canonical term, whatever word the user used.
