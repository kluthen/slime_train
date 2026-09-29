# Todo

Read this first, every session.

## Where the work stands

Stage: **ingest and prepare, with proposals**. No design has been done. The
v1 master spec, its access model and the personas document have been read,
and every interaction surface they imply is inventoried in
`surface-inventory.md`, updated on 2026-09-29 with the spec's answers.

The spec gaps came back: every "Waiting on spec-writer" question was
answered by the spec and is closed in `decisions.md`. The 35 interface
questions stay open, but on 2026-09-29 the user asked for proposed answers
from a young-children's-games angle, and each one now carries a
**Proposed answer** in `open-questions.md`, pending the user. Some raise a
note for `spec-writer` where the spec itself would have to change.

Inputs used so far: `specs/versions/v1/master-spec.md`,
`specs/versions/v1/access-model.md`, `specs/personas.md`,
`specs/decisions.md` (through the entries of 2026-09-29), `specs/tuning.md`,
the build's tap dispatcher and switch (for the placeholder sizes), and
outside research on young children's touch interaction (cited in
`open-questions.md`). The master spec's personas section is authoritative
where it and the personas document differ.

Proposals are not decisions. Don't treat any of them as settled, and don't
start designing without the user.

## Done

- [x] `ui_ux/` tree set up: README, todo, open questions, decisions.
- [x] Surface inventory, traced to persona goals and access-model operations.
- [x] Open questions logged: 35 interface questions and 13 spec gaps.
- [x] The 13 spec gaps closed by the spec (2026-09-29); inventory updated.
- [x] A proposed answer for each of the 35 interface questions, with
      sources (2026-09-29), pending the user.

## Next, in order

1. **The user reviews the proposals** in `open-questions.md`. Start with the
   ones flagged "look here first" in that file's summary. Each one the user
   accepts or changes becomes a `decisions.md` entry and leaves the file.
2. **Route the spec notes to `spec-writer`**: the proposals tagged
   "[spec note]" in `open-questions.md` ask for a spec change or a spec
   check, and aren't ours to settle.
3. **Tier 1: `strategy.md`**, in dialogue with the user. Problem alignment,
   context of use, mental models, trade-offs, edge-case policy, flow index.
   The flow set is decided here, from the inventory. Not delegable.
4. **Tier 2: the design system**, in dialogue with the user. Where the token
   source lives in Godot (Q1) and what the system covers (Q2) come first.
   Not delegable.
5. **Tier 3: flows and screens**, one flow with its screens per unit, each
   through `ux-critic` before it's marked done.

## Not started

- `strategy.md`
- the design-token source (format proposed under Q1, not decided)
- `motion.md`
- `flows/`, `screens/`
