# Open questions

Each entry has a stable ID. Once resolved, an entry moves to `decisions.md`.

## Open

| ID | Question | Where |
|---|---|---|
| O14 | Godot risks still to test **on real phones**: **up to 200 slimes** (D67), many on one screen, on the reference phone (S20 FE) and on a floor phone (D71; one has to be bought): the simulation tick's cost, which decides the native-code contingency (D94), the blend's GPU cost at the phone's resolution, and Compatibility vs Mobile; tilt input; Android audio latency (only from v3). Settled: the vector look (D93), the slime approach and renderer on the desktop (D94), and running tests headless on Linux (chunk 3). | tech-direction |
| O22 | Return to the start: how are slimes herded back from an unopened frontier gate (wind, slide, conveyor…)? Every new section needs its own return route. For the first level's design session (D34). | concept |
| O62 | Basket outlet: where a basket releases its slimes after firing, and when emptied by opting out. Part of the basket object's own design, which needs to be planned (not yet). The test level assumes one outlet onto the onward route. | interactive-objects |
| O65 | Minimum zoom: a big framing zone may shrink slimes too far to tap or see. Only matters during play, since idle and screensaver mode ignore framing zones (D80). No proposal yet; to find with the prototype. | tuning |
| O67 | Second finger: the Definition of done says every tap gets a ripple, "including taps that do nothing else", but a second touch while one finger is down is ignored (D66). Does the second finger get a ripple? (ux Q36) | concept |
| O68 | Reopening the app: "opening the app always lands in screensaver mode" contradicts sessions and bedtime surviving a kill, and the access model's "reopening resumes where it was". Which wins, per state (session, bedtime)? (ux Q37) | concept |
| O69 | Which taps start a session: does a tap on the parent zone, an edge button or an object count as the first tap? If the parent zone counts, a parent opening the buttons to leave starts a 15-minute session. (ux Q38) | concept |
| O70 | Edge-button press: is one press a fixed step, or does the camera move while the finger stays down? v1 bans hold gestures, yet leaving a framing zone "takes a slightly longer push". (ux Q39) | concept |
| O71 | First-play hint: does the 10 s count start when screensaver mode shows or when the session starts? Does deleting the level's save bring the hint back? (ux Q40) | concept |
| O72 | Deleting the running level's save: what happens to the live world and the running session, and do the hint and the celebration come back? (ux Q41) | concept |
| O73 | Forgotten code: what "forgot the code?" does on a phone with no screen lock; what happens when Android's prompt is cancelled or fails; whether the new code is typed twice. (ux Q42) | concept |
| O74 | Pinning timing: on first launch, is pinning asked before or after setup (setup explains it)? Does "each time it opens" include coming back from the background? (ux Q44) | tech-direction |
| O75 | Back gesture when pinning is declined: does it let the child leave without the code, or does the app catch it? (ux Q45) | tech-direction |
| O76 | Wrong-code wait: do the count of wrong tries and the 30 s wait survive the prompt closing or the app being killed? Does "forgot the code?" work during the wait? (ux Q46) | concept |
| O77 | Language of the parent-facing text (setup, prompt, settings): which language(s) in v1? (ux Q48) | concept |
| O78 | Slimes against curved terrain: the slime simulation is our own code (D94), and spike 1 only simulated a flat floor and walls. Does it test ring points against the baked terrain points itself (a static grid of segments), or go through Godot's collision shapes (D93)? Its cost isn't in the spike's numbers. Default proposed: the simulation's own test against the baked segments, which moves to native code with the tick. For chunks 4 and 5. | tech-direction |

## Parked (deferred on purpose; revisit later)

| ID | Question | Where |
|---|---|---|
| O12 | Music: port the JS generator to Godot, whether it runs in-process, whether it reacts to the train (D42). | tech-direction |
| O13 | Procedural world generation: scope unknown. | tech-direction |
