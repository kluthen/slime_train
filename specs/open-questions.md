# Open questions

Each entry has a stable ID. Once resolved, an entry moves to `decisions.md`.

## Open

| ID | Question | Where |
|---|---|---|
| O14 | Godot risks to test with prototypes: Android audio latency, 30–50 slimes on a low-end phone, tilt input, running end-to-end tests on Linux without a screen, and a vector rendering approach. | tech-direction |
| O15 | Personas, still open: when and where the phone is handed over, and whether the child holds it or it lies on a table or lap. This affects tilt (D19). (`personas.md` is started.) | personas |
| O20 | Save-file versioning: what happens to a level's save when an update changes that level (proposed: the save records the level version, and an incompatible save is reset)? (One save per level is settled: D43.) | tech-direction |
| O21 | How long a call lasts: a fixed time after the tap, or until the slimes arrive? (Tap-to-call is settled: D46. The radius is a tuning value, see `tuning.md`.) | concept |
| O22 | Return to the start: how are slimes herded back from an unopened frontier gate (wind, slide, conveyor…)? Every new section needs its own return route. For the first level's design session (D34). | concept |
| O32 | Terminology still proposed: "section", "unsure", "heading back", "level" (a whole world with its own loop, sections and save file), "signpost", "filter", "screensaver mode" (the world running with no session), "sunrise" (the end of bedtime), "framing zone". | concept |
| O40 | Hop decision: when and in which direction a slime hops (its rhythm, what stops it, as with a covered slime per D37). | slimes |
| O48 | Two children, two fingers: when there are several touches at once, is each one a call, or does only the first count? (proposed: each touch is its own call, since a sibling poking the screen should also see a response) | concept |
| O49 | First-time discovery: a 3-year-old who has never played a video game and can't read has to find out what a tap does. Is the world alone enough (the first slime wakes near a sleeper, and any tap calls), or is there a wordless hint, such as a pulsing touch mark near a sleeper at the start? | concept |
| O50 | Target phone: the reference phone is a Samsung Galaxy S20 FE, which is not a low-end phone. For a paid Play Store release, what is the minimum phone we support, and what do the O14 performance tests aim at? | tech-direction |

## Parked (deferred on purpose; revisit later)

| ID | Question | Where |
|---|---|---|
| O12 | Music: port the JS generator to Godot, whether it runs in-process, whether it reacts to the train (D42). | tech-direction |
| O13 | Procedural world generation: scope unknown. | tech-direction |
