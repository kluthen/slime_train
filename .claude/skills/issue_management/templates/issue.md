# Issue: [Short title]

**ID:** `YYYYMMDD_short_slug`
**Ref:** `ISS-NNN`
**Date:** YYYY-MM-DD
**Severity:** Critical / High / Medium / Low
**Status:** Open / In Progress / Resolved / Wont Fix
**Component:** `src/path/to/main_file.gd`
**Affects:** `other files, levels, fixtures`
**Seen on:** desktop or phone (which); debug or release; native or GDScript tick; level and section, or fixture
**Reported by:** the user (playtest) / found while coding

---

## Summary

One paragraph: what goes wrong, where, and why it matters to the player.

---

## What happens

### Expected

What the game should do, in the spec's words where it says so.

### Observed

What the game does instead, as seen (the user's words, quoted, when it was
their report).

### How to reproduce

1. Fixture or save, level, section
2. Taps, tilt, camera moves (a test mode script when there is one)
3. What to look at

Mark the steps that are guessed.

---

## Cause

**Confirmed** or **Lead**: the mechanism, with the files and lines.

```
a code excerpt, an ASCII sketch of the place, or the numbers
```

---

## Spec and intent

- Decisions, open questions, level rules: D…, O…, rule …
- Atoms: `docs/….atom.md`
- Verdict: **code bug** (the code breaks the spec) or **spec gap** (the spec
  is wrong or silent: spec-writer settles it before the fix).

---

## Risk assessment

| Factor | Value |
|---|---|
| Likelihood | Low / Medium / High: how often normal play meets it |
| Impact | Low / Medium / High: what the player sees or loses |
| Detectability | Low / Medium / High: how it shows (on screen, in logs, in a hash) |
| Current mitigation | any safety net that limits it (lost, stuck, stalled…) |

---

## Recommended fix

**Short term:** what can be done now (a level edit, a guard, a constant).

**Medium term:** the code change that fixes it.

**Long term:** what would remove the cause for good.

**Test:** the test or fixture that should catch it again.

---

## Extra data

Results of the investigation: logs, census lines, measures, screenshots
kept in the scratchpad.

---

## References

- Source files (paths from the repo root, with lines)
- Tests and fixtures
- Specs and atoms

---

## Change log

- **YYYY-MM-DD**: filed.
