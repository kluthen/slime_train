# Todo

Read this first, every session.

## Where the work stands

Stage: **ingest and prepare**. No design has been done. The v1 master spec,
its access model and the personas document have been read, and every
interaction surface they imply is inventoried in `surface-inventory.md`.
The questions already visible are in `open-questions.md`. The decisions log
is empty.

Inputs used so far, and only these: `specs/versions/v1/master-spec.md`,
`specs/versions/v1/access-model.md`, `specs/personas.md`. The master spec's
personas section is authoritative where it and the personas document differ.

The user has said the real UI/UX work starts later. Don't start designing
without them.

## Done

- [x] `ui_ux/` tree set up: README, todo, open questions, decisions.
- [x] Surface inventory, traced to persona goals and access-model operations.
- [x] Open questions logged: 35 interface questions and 13 spec gaps.

## Next, in order

1. **Spec gaps back from `spec-writer`.** The "Waiting on spec-writer" group in
   `open-questions.md`. The ones that shape flows most are what reopening
   lands on, which taps start a session, the edge-button press, and the
   pinning order at first launch. Check whether they came back before the
   first design session.
2. **Tier 1: `strategy.md`**, in dialogue with the user. Problem alignment,
   context of use, mental models, trade-offs, edge-case policy, flow index.
   The flow set is decided here, from the inventory. Not delegable.
3. **Tier 2: the design system**, in dialogue with the user. Settle first
   where the token source lives in Godot and what the system covers.
   `ui_common.css` (or its Godot equivalent) and `motion.md` are not
   started. Not delegable.
4. **Tier 3: flows and screens**, one flow with its screens per unit, each
   through `ux-critic` before it's marked done.

## Not started

- `strategy.md`
- the design-token source (format undecided)
- `motion.md`
- `flows/`, `screens/`
