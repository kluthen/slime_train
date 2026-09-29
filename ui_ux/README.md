# Slime Train: UI/UX

The interface design for Slime Train, an offline Android game (Godot 4,
landscape locked) for children aged 3 to 5, with a parent behind a 6-digit
code.

The child sees a side-view world with no text: a train of slimes running
along a loop, answered by every tap. The parent sees the only text in the
game: the first-launch setup, the code prompt and settings, reached through
a tap at the top of the screen. The spec that fixes this behaviour is
`specs/versions/v1/master-spec.md`, with its access model and
`specs/personas.md`.

## Status

**No design document yet; the groundwork is done.** The spec has been read
and its interaction surfaces inventoried, and the interface questions they
raised are answered and logged in `decisions.md`. The next stage is
`strategy.md`, then the design system, both in dialogue with the user. The
first-play hint's redesign is parked for v2.
The root is working toward v1. No version has been approved, so there is no
`versions/` folder yet.

## Map

| Document | What it is for |
|---|---|
| `todo.md` | Where the work stands and what comes next. Read it first. |
| `open-questions.md` | Unresolved questions, with stable IDs, and those parked for a later version. |
| `decisions.md` | Append-only log of what was decided and why. Until the tier documents exist, it holds the settled interface answers in full. |
| `surface-inventory.md` | Every interaction surface the v1 spec implies, traced to persona goals and access-model operations. Input for the first design pass, not a design. |

To come, as the design is settled:

| Document | What it will be for |
|---|---|
| `strategy.md` | Why the interface has this shape: personas, context of use, trade-offs, the edge-case policy, the flow index. |
| design-token source | The canonical tokens and component states: a GDScript constants file, `src/ui/tokens.gd`, with the parent surfaces' Theme built from it in code. |
| `motion.md` | When motion earns its place, and how it degrades. |
| `flows/<name>/` | Per flow: `intent.md` (the reasoning) and `handoff.md` (the buildable logic). |
| `screens/<name>/` | Per screen, shared across flows: `intent.md` and `handoff.md`. |
| `archive/`, `versions/` | Closed milestones' working records; approved designs, frozen. |

Names follow the shared conventions of the spec and UI/UX trees.
