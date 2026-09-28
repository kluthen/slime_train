# Open questions

Each entry has a stable ID. Once resolved, an entry moves to `decisions.md`.

## Open

| ID | Question | Where |
|---|---|---|
| O4 | Idle camera: which train slime it picks, how the child takes back control (proposed: any touch), and what the cue 10 s beforehand looks like with no text (proposed: a slow, gentle zoom-out). (The 45 s delay is settled: D32.) | concept |
| O6 | Session details: does the 15 min keep counting while the app is in the background (proposed: yes, in real time)? Besides letting the child play again (D44), what can the parent do behind the gate (leave the app, delete a save, settings)? (Length, cooldown and sunrise are settled: D29, D44.) | concept |
| O14 | Godot risks to test with prototypes: Android audio latency, 30–50 slimes on a low-end phone, tilt input, running end-to-end tests on Linux without a screen, and a vector rendering approach. | tech-direction |
| O15 | Personas: the child (3–5) and the parent. The personas document is not written yet. | — |
| O20 | Save-file versioning: what happens to a level's save when an update changes that level (proposed: the save records the level version, and an incompatible save is reset)? (One save per level is settled: D43.) | tech-direction |
| O21 | Call tuning: radius (proposed: about half the screen width, since Cocoreccho!'s third was criticised) and how long a call lasts. (Tap-to-call is settled: D46.) | concept |
| O22 | Return to the start: how are slimes herded back from an unopened frontier gate (wind, slide, conveyor…)? Every new section needs its own return route. For the first level's design session (D34). | concept |
| O32 | Terminology still proposed: "section", "unsure", "heading back", "level" (a whole world with its own loop, sections and save file), "signpost", "filter", "screensaver mode" (the world running with no session), "sunrise" (the end of bedtime). | concept |
| O34 | Parent code: who sets it and when (proposed: the parent, at first launch, typed twice), and how it's recovered if forgotten. | concept |
| O40 | Hop decision: when and in which direction a slime hops (its rhythm, what stops it, as with a covered slime per D37). | slimes |
| O45 | Screensaver mode: does opening the app from scratch also show screensaver mode until the first tap (proposed: yes)? Does the screen stay awake in screensaver mode, or does the phone's usual screen timeout apply (proposed: the usual timeout outside a session, and the screen stays on during a session)? | concept |
| O46 | v1 objects: the v1 frontier gate opens through a switch and a basket (D35), so do those two come with v1? And does the split zone at the start of the loop (D23, D38) stay in v1? Without it, fused slimes never split, and everything drifts toward size 3. | versions/v1 |

## Parked (deferred on purpose; revisit later)

| ID | Question | Where |
|---|---|---|
| O12 | Music: port the JS generator to Godot, whether it runs in-process, whether it reacts to the train (D42). | tech-direction |
| O13 | Procedural world generation: scope unknown. | tech-direction |
