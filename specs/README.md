# Slime Train — spec index

Starting brief: `../precursor.md`. Research: `../docs/research/` (verbatim reports with sources).

| Document | Purpose | Status |
|---|---|---|
| `concept.md` | Concept, design stance, gameplay layers, controls, session/parental framing, terminology | draft v16 |
| `slimes.md` | Slime states, movement, size and weight, species, fusion, splitting | draft v6 |
| `interactive-objects.md` | Catalogue of interactive components and how they're activated | draft v5 |
| `tech-direction.md` | Engine, level authoring, slime simulation, saving, session lock implementation | draft v6 |
| `versions/` | Scope per version (v1–v4…) plus `timeline.md` for features with no version yet (D52) | live |
| `tuning.md` | Every number left to prototypes, with its starting value | live |
| `open-questions.md` | Register of unresolved decisions (O1…) | live |
| `decisions.md` | Append-only decisions log (D1…) | live |

## Status snapshot

- An "interactive screensaver" for ages 3–5 on Android. Watching the train is the core.
- Priorities: train and sleepers, then exploring, then fusion opening new paths.
- Idle camera: after 45 s it locks onto a train slime (D32). Manual camera: it runs on rails along the loop, moved with buttons at the left and right edges; signposts at forks; a call drags the camera toward it (D33).
- Godot 4. No custom level editor: Godot scenes plus reusable components.
- The session lock is best effort (pinning, parent gate, stored timer).
- Hybrid path (D8): the train follows the current loop; attracted slimes go free under physics and make their way back.
- Level rule: from anywhere reachable, gravity leads back to the loop.
- Progress persists between sessions: slime summaries plus the state of interactive objects. Saved every 15 s and when the app goes to the background (D7, D12).
- The loop grows up to the frontier gate. Without an active attempt to open it, slimes are herded back to the start (D9).
- Free slimes: off screen > 10 s means left alone; still not back after 1 min means lost, and teleported to the start (D10).
- The train has no slots: it's whoever is on the loop (D11).
- Sleepers wake only on contact with an awake slime. Tapping a sleeper calls slimes to it (D13).
- The call is tap-to-call; hold-and-drag is kept for a possible freeform camera later (D46).
- Switch = redirects the flow; gate = the barrier onto a new area. Frontier pattern: flip the switch, fill the basket, the gate opens (D14).
- Most objects are operated by tapping; some by tilt or by the slimes on them. A tap on an object operates it; anywhere else it calls (D15).
- Presence objects respond to weight, which is the number of base slimes in a slime (D16).
- Spring-back bending pathways are weight-driven forks. The call holds or hurries slimes on them (D17).
- The loop is a route with forks. Every branch joins again (no dead ends), slimes on a branch are still the train, and exploration areas hang off the route (D18).
- Tilt affects only free slimes (and tilt objects). ±45° cap, dead zone of about 10°, neutral taken at session start. The loop can be travelled with no input (D19).
- Slimes hop every few seconds (D21). Same species fuse after about 3–5 s of contact (D20). 3 species in the first section, plus one per new section (D22).
- Size = number of base slimes = weight. Big slimes jump higher. Any size can travel the loop, possibly by different forks (D24, D26).
- Slimes split back into base slimes at the loop start (D23). Fusing different species needs a device, and comes later (D25).
- Free slime after a call: unsure for up to about 15 s near the call point, then heads back to the loop. Physics always applies (D27).
- The session ends with a gentle bedtime: a dusk wind-down in the last minute, then slimes fall asleep, and only the parent gate moves things forward (D28).

- Session: a fixed 15 min, then a 10 min cooldown. Parent gate: a 6-digit code (D29, D30).
- Business direction: a paid base game (about $3–5), later levels about $2 each (D31).
- First release: one level of 4 sections with a basic black-on-black Cocoreccho!-like theme. Switch plus basket is the only frontier-gate pattern. No failure states (D34–D36).
- Fusion after 3 s of contact, a hop resets it; maximum size 3; specific objects or zones split slimes; species differ by colour and voice (D37–D40).
- A heading-back slime goes mostly downhill but knows the shortest way (D41). Music generator deferred (D42). One save file per level (D43).

- Bedtime ends with the parent code or after 10 min. Then comes sunrise: the world runs in screensaver mode until the first tap starts a session (D44).
- The rails camera plus the call is how the child explores. Hints must be visible from the loop, and every exploration branch has its own route back (D45, D51).
- Signposts at every fork; larger signposts steer the camera; filters send slimes by species (D47). 6 species in v1 (D48). No fusion over the maximum size (D49).
- Versions (D50, D52): v1 has no sound and only the frontier gate as an object. Objects come in v2, sound around v3. Features with no version yet are in `versions/timeline.md`.

- Screensaver mode also on a fresh app start; usual screen timeout there, screen on during a session (D53).
- v1 objects: the frontier-gate set (switch, basket, gate) plus the split zone at the start of the loop. Everything else is v2 (D54).

- Parent code: set during a one-time setup at first launch, recovered through the phone's own screen lock, no external service (D55).

- Sessions count in real time; interruptions use up time, and the parent can wake the slimes early (D56).
- Parent access: a tap at the top of the screen reveals the parent buttons, and every one asks for the code (D57). Turning the code off comes in v4 (D58).

- Idle camera: the slime nearest the middle of the view, a zoom-out as the cue, any touch takes back control (D59).
- Automatic framing: the player never controls the zoom. Framing zones pull the camera into place, and screensaver mode is about 10–20% wider (D60).

- Leaving a framing zone takes a slightly longer delay (to be tested). The in-session idle camera zooms out like screensaver mode (D61, D62).

## Where to resume

Next: personas (O15). Then save versioning (O20), how long a call lasts (O21), the hop decision (O40), and a dedicated session on the first level's design (O22).
