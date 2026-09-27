# Open questions

Each entry has a stable ID. Once resolved, an entry moves to `decisions.md`.

| ID | Question | Where |
|---|---|---|
| O4 | Idle camera: how long before it takes over, which slime it follows, and how the child takes back control. | concept |
| O6 | Timer settings: is the 15 min fixed or set by the parent (at most 15)? Does a session end or pause when the app goes to the background? What exactly can the parent do behind the gate after bedtime (start a new session right away, change settings, leave the app)? | concept |
| O7 | Parent gate design: it must be adult-only, with no maths or reading, since a 4–5 year old may already know digits. | concept |
| O8 | First-release level scope: one big continuous world like Cocoreccho!, or sections? And how big? (Persistence is settled: D7.) | concept |
| O9 | Is there any failure state or hostile creature? (proposed: none) | concept |
| O10 | Fusion leftovers: exact contact duration (3–5 s, to be tuned), and whether a hop that breaks contact resets the timer. (Trigger settled: D20.) | slimes |
| O12 | Music: the generator's language and interface, whether it runs in-process, and whether it reacts to the train (size, types). | tech-direction |
| O13 | Procedural world generation: deferred to a later iteration, scope unknown. | tech-direction |
| O14 | Godot risks to test with prototypes: Android audio latency, 30–50 slimes on a low-end phone, tilt input, running end-to-end tests on Linux without a screen, and a vector rendering approach. | tech-direction |
| O15 | Personas: the child (3–5) and the parent. The personas document is not written yet. | — |
| O16 | Business model: paid app or free first level, and DLC delivery (Play Billing plus Play Asset Delivery) for the first release or later? | — |
| O20 | Save-file versioning: does the save file carry a level/save format version, and how does an old save migrate when a level changes (DLC, updates)? (Timing and airborne slimes are settled: D12.) | tech-direction |
| O21 | The call (touch to attract): tap-to-call (user leans this way) or hold-and-drag to lead? To be settled by trying both in a playable prototype. Also: radius (proposed: about half the screen width, since Cocoreccho!'s third was criticised) and how long a call lasts. | concept |
| O22 | Return to the start: how are slimes herded back from an unopened frontier gate (wind, slide, conveyor…)? This implies every new section needs its own return route. | concept |
| O23 | Gate variations: is the switch-plus-basket pattern (D14) the only way to open a frontier gate, or can other puzzles guard a gate too (fusion size, tilt, a chain of objects)? | interactive-objects |
| O24 | Pacing: the loop only ever gets longer, so a full lap does too. Does that clash with 15 min sessions and the idle camera's appeal? (ties to O8) | concept |
| O29 | The in-world reason and mechanism for slimes splitting at the start of the loop (D23). | slimes |
| O30 | Is there a maximum slime size? | slimes |
| O31 | Do species differ in anything besides fusion compatibility in the first release (colour/shape for sure; voice or sound for music)? | slimes |
| O32 | Terminology still proposed: "section" = the part of the world opened by one gate; "unsure" / "heading back" for the free-slime phases after a call. ("Species" is adopted.) | concept |
| O33 | How a free slime heads back: it hops downhill (random direction on flat ground), or it knows which way the loop is? (proposed: downhill, per the gravity level rule of D8) | slimes |
