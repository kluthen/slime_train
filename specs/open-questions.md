# Open questions

Each entry has a stable ID. Once resolved, an entry moves to `decisions.md`.

## Open

| ID | Question | Where |
|---|---|---|
| O14 | Godot risks to test with prototypes: Android audio latency, **up to 200 slimes** (D67) on a floor phone (D71; one has to be bought), including many on one screen, tilt input, running end-to-end tests on Linux without a screen, and a vector rendering approach. | tech-direction |
| O22 | Return to the start: how are slimes herded back from an unopened frontier gate (wind, slide, conveyor…)? Every new section needs its own return route. For the first level's design session (D34). | concept |
| O62 | Basket outlet: where a basket releases its slimes after firing, and when emptied by opting out. Part of the basket object's own design, which needs to be planned (not yet). The test level assumes one outlet onto the onward route. | interactive-objects |
| O65 | Minimum zoom: a big framing zone may shrink slimes too far to tap or see. Only matters during play, since idle and screensaver mode ignore framing zones (D80). No proposal yet; to find with the prototype. | tuning |
| O66 | Edge buttons on a return route: it runs right to left on screen, and the loop turns back at the frontier. (proposed: the right button always moves the camera **forward** along the loop and the left button backward, whatever the direction on screen; the camera follows the rail round the turn) | concept |

## Parked (deferred on purpose; revisit later)

| ID | Question | Where |
|---|---|---|
| O12 | Music: port the JS generator to Godot, whether it runs in-process, whether it reacts to the train (D42). | tech-direction |
| O13 | Procedural world generation: scope unknown. | tech-direction |
