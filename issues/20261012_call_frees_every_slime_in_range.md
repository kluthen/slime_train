# Issue: The call frees every awake slime in range, not the 10 nearest

**ID:** `20261012_call_frees_every_slime_in_range`
**Ref:** `ISS-002`
**Date:** 2026-10-12
**Severity:** Medium
**Status:** Open
**Component:** `src/sim/free_slimes.gd`
**Affects:** `src/sim/simulation.gd` (`call_radius`, the tap's call), the camera's call drag, ISS-001
**Seen on:** the user's play session, test level, section 1, at the tree
**Reported by:** the user (playtest)

---

## Summary

The user expects a call to free at most about 10 slimes: the free slimes in
range first, then the nearest train slimes. The game frees **every** awake
slime within the call radius (half the view's width), which at a zoomed-out
framing can be most of the train. The cap was the user's idea of 2026-10-01
and was never written into the specs, so nothing built it.

---

## What happens

### Expected

The user: "i expected the call only to work on the ten nearest freed (and
then non freed) slimes (so a maximum of 10-ish slimes undercall)". As the
idea was given on 2026-10-01: the free slimes in range answer first, then the
nearest train slimes, up to 10 in all.

### Observed

Every awake slime (train or free) whose centre is within the call radius of
the call point answers it and becomes free. At the tree (`s1.frame.tree`,
zoom 0.7) the radius is about 823 px on a 1,152 px wide view, more on a
phone: a call on the tree freed the train on the road below (at least 11
slimes, seen through ISS-001).

### How to reproduce

1. Any fixture with a long train, for example a section 1 train of 20.
2. Tap open ground near the train.
3. Count the answering slimes (the debug labels, or
   `FreeSlimes.answer_call()`'s return): all the slimes within half a view
   width, with no cap.

---

## Cause

**Confirmed**: built as specified. `FreeSlimes.answer_call()` loops over
every slime and frees each awake one within `radius`
(`src/sim/free_slimes.gd:163-183`); `Simulation.call_radius()` is
`CALL_RADIUS_SCREENS` (0.5) × the view's width (`src/sim/simulation.gd:487`).

```gdscript
for slime_id in bodies.ids():
    ...
    if bodies.centre_of(slime_id).distance_to(point) <= radius:
        bodies.set_state(slime_id, SlimeBodies.FREE)
```

---

## Spec and intent

- Master spec §5.2: "Every awake slime within the call radius (about half
  the screen width) answers it, train slimes included, and becomes free."
- D46 (tap-to-call), D73 (a new tap replaces the call), `specs/tuning.md`
  (call radius about half the screen width).
- Atom: `docs/req_call_mechanic.atom.md`.
- Verdict: **spec gap**. The code follows the spec; the user's cap is in no
  decision, no open question and no chunk. spec-writer opens it (proposed
  default below), then a chunk builds it.

---

## Risk assessment

| Factor | Value |
|---|---|
| Likelihood | High: every call near a long train |
| Impact | Medium: the train empties at every call, the crowd of free slimes costs physics, and it feeds ISS-001 |
| Detectability | High: visible on screen |
| Current mitigation | none |

---

## Recommended fix

**Short term:** spec-writer records the rule. Proposed default, from the
user's words: a call frees at most `CALL_MAX` = 10 slimes, counted in base
slimes or in slimes (to settle); the free slimes in range answer first,
nearest first, then the nearest train slimes; the rest stay as they are.
Slimes still answering an earlier call but out of range keep taking the new
point (D73) and count toward the 10 (to settle).

**Medium term:** in `answer_call()`, gather the candidates in range, sort
free first then by distance (ties by id, so it stays deterministic), take
the first 10. Wake the resting piles as today (`Offscreen` wakes every
resting slime within the radius, which can stay).

**Long term:** none beyond the rule.

**Test:** a unit test: 20 train slimes and 3 free slimes in range, one call:
exactly 10 answer, the 3 free ones among them, the 7 nearest train slimes
for the rest. Fixture hashes that make a call will change; list them.

---

## Extra data

- The idea's first mention: the user's ideas for the bowl, 2026-10-01
  (idea 2), noted "still open, not built" on 2026-10-03.

---

## References

- `src/sim/free_slimes.gd:163` (`answer_call`)
- `src/sim/simulation.gd:487-569` (`call_radius`, the tap's call)
- `src/sim/offscreen.gd` (`_disturb`, the call's local wake)
- `specs/versions/v1/master-spec.md` §5.2 (line 264)
- Related: ISS-001

---

## Change log

- **2026-10-12**: filed from the user's report; the call checked in the code
  and the specs.
