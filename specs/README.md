# Slime Train — spec index

Starting brief: `../precursor.md`. Research: `../docs/research/` (verbatim reports with sources).

| Document | Purpose | Status |
|---|---|---|
| `concept.md` | Concept, design stance, gameplay layers, controls, session/parental framing, terminology | draft v9 |
| `slimes.md` | Slime states, movement, size and weight, species, fusion, splitting | draft v3 |
| `interactive-objects.md` | Catalogue of interactive components and how they're activated | draft v2 |
| `tech-direction.md` | Engine, level authoring, slime simulation, session lock implementation | draft v1 |
| `open-questions.md` | Register of unresolved decisions (O1…) | live |
| `decisions.md` | Append-only decisions log (D1…) | live |

## Status snapshot

- An "interactive screensaver" for ages 3–5 on Android. Watching the train is the core.
- Priorities: train and sleepers, then exploring, then fusion opening new paths.
- The idle camera follows a slime.
- Godot 4. No custom level editor: Godot scenes plus reusable components.
- The session lock is best effort (pinning, parent gate, stored timer).
- Hybrid path (D8): the train follows the current loop; attracted slimes go free under physics and make their way back.
- Level rule: from anywhere reachable, gravity leads back to the loop.
- Progress persists between sessions: slime summaries plus the state of interactive objects. Saved every 15 s and when the app goes to the background (D7, D12).
- The loop grows up to the frontier gate. Without an active attempt to open it, slimes are herded back to the start (D9).
- Free slimes: off screen > 10 s means left alone; still not back after 1 min means lost, and teleported to the start (D10).
- The train has no slots: it's whoever is on the loop (D11).
- Sleepers wake only on contact with an awake slime. Tapping a sleeper calls slimes to it (D13).
- The call: tap-to-call vs hold-and-drag, decided by a playtest prototype (O21).
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

## Where to resume

Next session: the session and parent topics, meaning timer settings (O6) and parent gate design (O7). Then the idle camera (O4) and failure states (O9). After that, the personas document (O15) and first-release scope (O8, O24).
