# Open questions

Each entry has a stable ID. Once resolved, an entry moves to `decisions.md`.

## Open

| ID | Question | Where |
|---|---|---|
| O14 | Godot risks to test with prototypes: Android audio latency, **up to 200 slimes** (D67) on the floor phone (O50), including many on one screen, tilt input, running end-to-end tests on Linux without a screen, and a vector rendering approach. | tech-direction |
| O20 | Save-file versioning: what happens to a level's save when an update changes that level (proposed: the save records the level version, and an incompatible save is reset)? (One save per level is settled: D43.) | tech-direction |
| O21 | How long a call lasts: a fixed time after the tap, or until the slimes arrive? (Tap-to-call is settled: D46. The radius is a tuning value, see `tuning.md`.) | concept |
| O22 | Return to the start: how are slimes herded back from an unopened frontier gate (wind, slide, conveyor…)? Every new section needs its own return route. For the first level's design session (D34). | concept |
| O32 | Terminology still proposed: "section", "unsure", "heading back", "level" (a whole world with its own loop, sections and save file), "signpost", "filter", "screensaver mode" (the world running with no session), "sunrise" (the end of bedtime), "framing zone". | concept |
| O40 | Hop decision: when and in which direction a slime hops (its rhythm, what stops it, as with a covered slime per D37). | slimes |
| O50 | Target phone: the S20 FE (late 2020, flagship chip at the time, roughly mid-range by today's standards) is the reference phone. Proposed: the performance floor is a common budget phone from a few years back (Galaxy A14 class), reached with level-of-detail simulation; if the O14 prototype can't hold 200 slimes there, raise the floor to S20 FE class. | tech-direction |
| O51 | Off-screen rules (D69). Physics stops off screen, so everything physics normally handles needs a rule there. Proposed: (a) **a free slime** that leaves the screen is placed on the nearest point of its area's route back (D51) and follows it at the deterministic pace; if there is none, it is lost (D10), so "lost" becomes a safety net; (b) **fusion and waking happen only on screen**; (c) level rule: **sleepers never sit on the loop itself**, so waking always needs a call, as it does now, and the train never wakes someone off screen; (d) **baskets** count arriving slimes as weight off screen too; (e) every v2 object must define how it behaves off screen (for example, a bending pathway counts the weight crossing it). | tech-direction, slimes |

## Parked (deferred on purpose; revisit later)

| ID | Question | Where |
|---|---|---|
| O12 | Music: port the JS generator to Godot, whether it runs in-process, whether it reacts to the train (D42). | tech-direction |
| O13 | Procedural world generation: scope unknown. | tech-direction |
