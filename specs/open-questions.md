# Open questions

Each entry has a stable ID. Once resolved, an entry moves to `decisions.md`.

## Open

| ID | Question | Where |
|---|---|---|
| O14 | Godot risks to test with prototypes: Android audio latency, **up to 200 slimes** (D67) on a floor phone (D71; one has to be bought), including many on one screen, tilt input, running end-to-end tests on Linux without a screen, and a vector rendering approach. | tech-direction |
| O22 | Return to the start: how are slimes herded back from an unopened frontier gate (wind, slide, conveyor…)? Every new section needs its own return route. For the first level's design session (D34). | concept |
| O52 | Completing a level: what happens when a level's last gate opens? (proposed: nothing ends; the loop is complete and the world stays open, with a one-time celebration. Moving to another level waits for paid levels.) | concept |
| O53 | Camera rails where the loop doubles back: in side view the return route (for example an underground slide) runs back under the outgoing route. (proposed: the rails follow only the outgoing part of the loop; the return route isn't on the rails; when the idle camera's slime goes into it, the camera switches to the nearest train slime on the rails) | concept |
| O54 | Screen orientation. (proposed: landscape, locked; side view like Cocoreccho!) | concept |
| O55 | A wrong parent code. (proposed: the entry shakes and clears; unlimited tries, with a 30 s wait after 5 wrong tries in a row; the code prompt closes after about 15 s with no input. Also: the settings screen closes by itself after a short time with no input) | access model |
| O56 | Colour-blind players: in v1 species differ by colour only (D40, D50). (proposed: each species also gets its own shape detail, such as eyes or a marking, so colour is never the only cue) | slimes |
| O57 | Performance targets. (proposed: 60 fps on the reference phone; at least 30 fps on the floor phone in the worst case of 200 slimes on one screen) | tech-direction |
| O58 | If the parent declines screen pinning at setup (Android asks for confirmation). (proposed: the game still works without pinning, the parent buttons still ask for the code, and setup explains the difference) | concept |
| O60 | When the app asks for screen pinning. Android shows its own "use screen pinning?" confirmation every time, which can't be skipped; pinning ends on a restart, and anyone can unpin with a gesture unless the phone's "Ask for PIN before unpinning" is on (research: `docs/research/level-authoring-and-kid-lock.md`). (proposed: ask each time the app opens, since the parent normally opens it and hands the phone over; setup recommends turning on "Ask for PIN before unpinning") | access model |
| O61 | Size forks: how the drawn loop sends slimes down a branch by size, given it isn't an object. (proposed: a route property "size ≥ N takes this branch", with the terrain drawn to match; allowed in v1) Raised by the test level. | level-design |
| O62 | Basket outlet: where a basket releases its slimes after firing, and when emptied by opting out. (proposed: one outlet per basket, dropping onto the onward route just before the return route's entrance) Raised by the test level. | interactive-objects |
| O63 | The frontier set after its gate opens. (proposed: the switch locks to "onward" and stops responding to taps; the basket shows as done) Raised by the test level. | interactive-objects |
| O64 | Zoom stacking: how the idle and screensaver zoom-out combines with a framing zone's own zoom. (proposed: the 10–20% applies on top of the zone's zoom) Raised by the test level. | concept |
| O65 | Minimum zoom: a big framing zone may shrink slimes too far to tap or see. (proposed: a minimum zoom as a tuning value, which framing zones can't go below) Raised by the test level. | tuning |
| O59 | How level design is run: the contents of `levels/<id>/` (objectives, loop description, content), and how a level goes from text to a Godot scene. | levels |

## Parked (deferred on purpose; revisit later)

| ID | Question | Where |
|---|---|---|
| O12 | Music: port the JS generator to Godot, whether it runs in-process, whether it reacts to the train (D42). | tech-direction |
| O13 | Procedural world generation: scope unknown. | tech-direction |
