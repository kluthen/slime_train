# Slime Train — Coding Standard

**Scope:** the whole repository: `src/`, `tests/`, `tools/`, `levels/`, `native/`. These rules
are **transverse**: they hold whatever the layer. They go **beyond ATD** (which governs
*documentation traceability*); this file governs *how code is written and changed*.

> **Precedence.** This file is the canonical source for the principles below; `CLAUDE.md`,
> `docs/dev/README.md` and the build plan may add local mechanics, never weaken a principle.

The six non-negotiables. Each is **MUST/NEVER**, not a preference.

## 1. ATD adherence

- **No business-layer code change without its ATD anchor.** Before altering a REQUIREMENT or
  RULE behaviour, the governing atom must exist and be settled (documentalist preflight, then
  stewardship, per the build plan's workflow).
- **One CONTRACT + one VISION atom** for the project, settled *before* any business atom changes.
- Every source file that implements business behaviour carries ≥1 ATD link (`@spec-link` on code,
  `@test-link` on tests), placed atop the exact function or type it covers — not only on the file
  header. Test files use `@test-link` only. No phantom links. Purely technical files (RNG, fixed
  step, hashing, test mode, debug tooling, renderers) may carry none.
- Tags in GDScript are written by hand (`# @spec-link [[id]]`); `atd update --spec-link` breaks
  `.gd` files.

## 2. Time and randomness are injected

- **`src/sim/` never reads a clock and never uses global randomness.** Ticks come from the fixed
  60 Hz step; wall and monotonic time enter through the scene layer (`src/save/session_clock.gd`,
  test mode's `TestClock`); every random draw goes through the seeded `Rng` streams. This is what
  keeps a run deterministic (same seed, same state hash) and makes sessions and bedtime testable.
- No ad-hoc timers or threads for scheduled work inside the simulation.

## 3. Crash early, fail fast

- **Defaulting hides critical errors.** No silent failures, no catch-all default values in core
  logic to "keep things running". A clear error beats undefined behaviour.
- Validate inputs at the boundary (level data, save files, test-mode scripts) and reject the invalid
  loudly. Where garbage input can only mean a caller bug, let it surface rather than papering over it.
- Errors are values to handle or propagate, never to swallow.

## 4. Strict contract adherence — no defaulting to save the day

- **Honour the interface exactly.** Do not invent fallbacks, coerce types, or fill missing fields to
  make a call "work". If a contract is violated, fail per the contract — the one sanctioned fallback
  is the save contract itself (an unreadable or other-version save is left untouched, the level
  starts fresh, writes are blocked: `rule_saves_never_wiped`).
- The save format, the fixture format and the test-mode script format are hard contracts. Never
  change them without an explicit user-approved warning and a matching update to
  `docs/dev/README.md` and the relevant ATD atoms in the same change.
- Data records crossing a module boundary (save entries, tap results, off-screen ways) must have a
  documented shape with concrete field types; prefer a typed class over a loose Dictionary when the
  record outlives one function.

## 5. Test-first when fixing bugs

- **Reproduce the error as a test before fixing it.** On any new bug, first write a test at the
  nearest concerned module that fails *because of* the bug. Only then make it pass.
- Tests exercise production code — **no test-only branches in production files**. Test mode
  (`src/test_mode/`) and the debug overlay (`src/debug/`) are debug-build-only modules guarded by
  `TestModeGuard`, not branches; an `enabled` switch in `src/sim/` needs a documented reason.
- Prefer targeted runs (`tools/test.sh -gselect=<name>`) while iterating; the full suite before
  every commit.

## 6. Code health — zero-error standard

Enforced by `tools/code_health_check.py` (to write); treat its errors as blocking.

- **File size:** warn >400 effective LOC (non-blank, non-comment), error >600. Split along domain
  seams before trimming.
- **Nesting depth:** ≤4 levels; refactor beyond.
- **Doc density:** every function has an intent comment; a missing doc on a public function is an
  error. Match the surrounding file's comment density and idiom.
- **ATD density:** ≥1 link per business file, ≤10 distinct atoms per file (warn >5); repeated
  links to the same atom count once. Bypass tokens are for genuine exceptions (vendored code such
  as `addons/gut/`, generated scenes), not for silencing your own.

## 7. Change discipline

- **Docs move with code.** Any change to a format, a component's editor configuration or a
  behaviour updates `docs/dev/README.md` and the ATD atom in the same change.
- **Documentation is self-sufficient — no external references.** No doc (in-code comment, README,
  ATD atom, spec) may point a reader at tickets, chat threads or other out-of-band material. Links
  between parts of the same document set (specs, decisions, atoms) are fine.
- Commit only when asked (the build plan asks for one commit per step); build outputs go to
  `build/` (git-ignored), never committed.
- **Major work starts in a git worktree**, not the checked-out working copy, so concurrent chunks
  don't share a tree. Small fixes don't need one.
- Report outcomes faithfully — if a test fails or a step was skipped, say so with the evidence.

---

*When in doubt: crash loud, honour the contract, write the test first, keep time and randomness
injected, and anchor it in ATD. If a rule seems to force worse code, raise it with the user — do
not quietly route around it.*
