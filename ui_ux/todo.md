# Todo

Read this first, every session.

## Where the work stands

Stage: **ready for Tier 1**. No design document exists yet, but the
interface questions are answered. The v1 master spec, its access model and
the personas document have been read, and every interaction surface they
imply is inventoried in `surface-inventory.md`, updated on 2026-09-29 with
the spec's answers.

On 2026-09-29:

- the spec answered every question once waiting on `spec-writer` (Q36 to
  Q48, closed in `decisions.md` D1);
- the user approved the proposed answers to Q1 to Q10 and Q12 to Q35,
  written from a young-children's-games angle with outside research; they
  are recorded in full in `decisions.md` D2 to D7, with their sources in
  D2;
- the first-play hint (Q11) is parked for v2: v1 keeps the spec's pulsing
  mark. Its proposal and sources stay in `open-questions.md`.

Spec notes raised under several answers were routed to `spec-writer`
through the coordinator (listed in D2); don't edit `specs/`. The technical
checks under Q1, Q5 and Q32 are for the build and refine the answers
without reopening them.

Inputs used so far: `specs/versions/v1/master-spec.md`,
`specs/versions/v1/access-model.md`, `specs/personas.md`,
`specs/decisions.md` (through D108), `specs/tuning.md`, the build's tap
dispatcher, switch and basket (for the placeholder sizes and tap targets),
and the outside research cited in `decisions.md` D2. The master spec's
personas section is authoritative where it and the personas document
differ.

## Done

- [x] `ui_ux/` tree set up: README, todo, open questions, decisions.
- [x] Surface inventory, traced to persona goals and access-model operations.
- [x] Open questions logged: 35 interface questions and 13 spec gaps.
- [x] The 13 spec gaps closed by the spec; inventory updated (ux D1).
- [x] Proposed answers to the 35 interface questions, with sources.
- [x] The user's review: 34 approved (ux D2 to D7), Q11 parked for v2.

## Next, in order

1. **Tier 1: `strategy.md`**, in dialogue with the user. Problem alignment,
   context of use, mental models, trade-offs, the edge-case policy, the flow
   index. The flow set is decided here, from the inventory and D2 to D7.
   Not delegable.
2. **Tier 2: the design system**, in dialogue with the user: the token
   source as decided in D3 (Q1: `src/ui/tokens.gd`, sizes in mm, the Theme
   built from it in code) and `motion.md`. Its scope is D3 (Q2). Not
   delegable.
3. **Tier 3: flows and screens**, one flow with its screens per unit, each
   through `ux-critic` before it's marked done.

Not started, on purpose: none of these has begun.

## Parked for v2

- Q11, the first-play hint as a demonstrating ghost hand, and setup asking
  the parent to show the first tap. See `open-questions.md`.

## Not started

- `strategy.md`
- the design-token source (`src/ui/tokens.gd`, decided in D3)
- `motion.md`
- `flows/`, `screens/`
