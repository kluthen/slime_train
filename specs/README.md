# Slime Train — spec index

Research: `../docs/research/` (verbatim reports with sources).

| Document | Purpose | Status |
|---|---|---|
| `concept.md` | Concept, design stance, gameplay layers, controls, session/parental framing, terminology | draft v27 |
| `slimes.md` | Slime states, movement, size and weight, species, fusion, splitting | draft v15 |
| `interactive-objects.md` | Catalogue of interactive components and how they're activated | draft v9 |
| `tech-direction.md` | Engine, level authoring, slime simulation and its performance, saving, testability, session lock implementation | draft v16 |
| `versions/` | Scope per version (v1–v4…) plus `timeline.md` for features with no version yet (D52) | live |
| `level-design.md` | Rules every level must follow; the checklist for level design sessions | draft v7 |
| `levels/` | One folder per level (D76): `test/` (the test level, draft v6), `01/` (the real first level, not started) | live |
| `versions/v1/master-spec.md` | The v1 master spec, consolidated early (D76), plus `access-model.md` | consolidated; every proposed default approved (D102–D108); O91 (stuck slimes' cause) in Known gaps |
| `versions/v1/build-plan.md` | v1 split into 25 build chunks ordered for testing, each tied to the master spec's Definition of done and the test level's fixtures | draft v10 (approved, D108); chunks 0–15 and 17 done, 16 in progress, 18 next; 23 (small issues from play) is an open list after 22; 5N is a contingency |
| `personas.md` | Who the game is for: P1 the newcomer (3), P2 the watching sibling (2), P3 the early player (4), P4 the parent; goal IDs | draft v6 |
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

- Personas started (from real people): the primary persona is a 3-year-old newcomer to video games, on an S20 FE. Also a 2-year-old watching sibling, 4-year-old early players, and the parent. Played at home as a reward or after school, not before sleep. Tilt stays a bonus (proposed).

- Tilt is only for exploration or fun actions (D64). First-time discovery: a ripple on every tap, and a wordless hint on the very first play (D65). The level rules are collected in `level-design.md`.

- Touches: the first touch wins; two calls at once will be tried later (D66).

- At most 200 slimes per level (in base slimes), possibly many on one screen. Level-of-detail simulation (D67, D69). v3 caps slime voices at 10, shared in proportion (D68).

- Physics only near the screen. Off-screen slimes follow the loop at a deterministic pace and are spawned properly when the view nears them (D69).

- Off-screen rules: free slimes follow their route back, fusion and waking happen only on screen, only free slimes wake sleepers, and sleepers never sit on the loop. Baskets fill off screen, earn a reward animation, and can be abandoned before they're full (D70).
- Phones: S20 FE is the reference; the floor is Galaxy A14 class; if needed the floor rises and the 200 cap stays (D71). Test environments in `tech-direction.md`.

- Saves are never wiped. Released levels aren't meant to change, and any minor update ships with its migration. Displaced slimes count as lost (D72).

- A call lasts until each slime reaches the point (capped at about 8 s), and a new tap replaces it (D73).

- Hopping rules per state: the train bounces unevenly, called slimes hop eagerly, and big slimes hop less often but further (D74).

- Terminology confirmed; "split zone" replaces "defusing spot", and "route back" is added (D75).

- A test level (`levels/test/`) exercises the v1 gameplay and drives the end-to-end tests. Each level gets its own folder; the real first level (`levels/01/`) is designed later. Everything else is consolidated into the v1 master spec and access model (D76).
- Tech additions (approved, D91): seeded randomness, a test mode (fixtures, time skip, scripted taps), atomic saves with one backup, no network permission.

- Completing a level: a one-time celebration; the world stays open (D77). Landscape, locked (D78).
- The return route is part of the loop, with its own rail; it may carry exploration, which later gates must never cut off (D79).
- Screensaver and idle share one zoom and ignore framing zones; framing resumes when control comes back (D80).
- Species: colour only in v1; texture, styling and other palettes later (D81). 60 fps reference, 30 fps floor (D82).
- Wrong code: shake, clear, a 30 s wait after 5 wrong tries; prompt and settings close by themselves (D83). Pinning declined: the game still works (D84). Pinning asked at every launch; setup recommends "Ask for PIN before unpinning" (D85).
- All the master spec's proposed defaults are approved (D91).
- Edge buttons: right is forward along the loop, left is backward, whatever the direction on screen (D90).
- A frontier set is inert once its gate opens (D86). A level's folder stores its design requirements and discussion (D87). Size forks are a size filter (D88); both filters are v2, so v1's only fork is the frontier switch (D89).

- Spikes done on the desktop (chunks 1, 2). Level art: curves baked into polygons and lines, no SVG textures, no plugin (D93). Slimes: ring-of-springs plus blend shader is a go, Compatibility renderer, 12/15/18 points per ring; the GDScript tick is the bottleneck, so chunk 5 uses a native-ready layout and native code is the contingency, decided on the reference phone (D94).

- Reference phone measured (S20 FE): 200 slimes all simulated in GDScript miss 60 fps (about 18 ms per tick at 12 points cold, 27 ms throttled). Native tick deferred, fallbacks first: the tick stays in GDScript, and resting piles, sleepers, full-basket slimes and zoomed-out slimes get cheaper (chunk 15). The realistic worst case is a mostly still pile; the floor phone's target is now 30 fps with the largest realistic pile (a full basket plus the train), not 200 slimes on one screen. A C++ GDExtension is the verified contingency (under `native/`, out of tests and exports), fired only if chunk 22 fails on either phone (chunk 5N). Drawing is fine; Compatibility stays (D96). Slimes test the baked terrain segments themselves, inside the tick (D97). The parent code is never stored in plain text (D98). O14 now waits for the floor phone (to be bought) and chunk 22.

- Defaults for O67–O77 (D95), approved by the user (D102): a second finger gets nothing, not even a ripple; reopening resumes where it was; only a tap on the world starts a session; an edge button steps per press and keeps moving while held (about 1 s of holding leaves a framing zone); the hint's 10 s count from the world's first frame, and a deleted save brings the hint back; deleting the running save reloads the level fresh, timers untouched; forgotten code and wrong-code wait details; pinning asked after setup and at each launch; back leaves the app without pinning; parent text in the phone's language, English otherwise; v1 ships English and French.

- Chunks 10, 12 and 13 built: the values the build chose for the camera, fusion and bumping are in `tuning.md`, (proposed; to try). They raised O79 (the idle camera never zooms in) and O80 (tilt isn't input for the idle clock), both settled in D103, and O81 (edge buttons as full-height strips? settled by D99). The `bump` fixture now holds 2, 2, 3 and 1, so both bumps can happen; chunk 16 regenerates it.

- Chunks 14 and 17 built: the frontier set (switch, basket, gate, the celebration) and the session (wind-down, bedtime, sunrise, the clock rule). Their values are in `tuning.md`, (proposed; to try). They raised O82–O86, settled on 2026-09-29: the session lives in the level's save and deleting the save keeps it (D104); at bedtime baskets pause their releases and rewards and their slimes sleep in place; no opt-out once a basket is full; a gate's lid may shut the old return route (D105); "in a basket" is a fifth slime state (D106).

- Chunk 15 built the off-screen simulation and the cheaper states (parking, resting piles, zoomed-out detail), with section 2 in greybox; chunk 16 (in progress) built section 3, the full 200 and every fixture. Their values are in `tuning.md`, and the test level as built is in `levels/test/README.md` (the cave's route back takes about 46 s; the bowl's shelves and rim are branches with routes back; the rim runs over the plateau; 3-digit sleeper IDs; the added `gate2-open` fixture; `stress-still`'s bowl pile asleep at bedtime; the celebration waits for basket 3). A free slime off screen with no route back near heads for the loop if it is near, or stays put until the lost timer. All approved (D108). They raised O87 (the rest rule's anchor: kept fixed for v1, revisited in chunk 22, D107).

- The user's play reports (2026-09-29) go into chunk 23, an open list of small issues run after chunk 22. Decided the same day: a call whose point is inside a central box (20% by 20% of the screen) doesn't move the camera, and stops a drag (D101); the edge buttons are whole-height strips 10% of the screen's width that never call, below the parent zone (D99, closes O81; ux-writer draws them); two slimes that can't fuse found inside each other for about 2 s are "stuck", a state of its own with the same effect as lost: the smaller train or free slime goes to the loop start (D100). Why it happens is O91, an open investigation.

## Where to resume

The v1 master spec and access model are consolidated early and kept in step with the drafts. The build plan (`versions/v1/build-plan.md`) is approved (D108). The user approved every pending default on 2026-09-29: the first UX review's O67–O77 (D102) and the build's O79–O87 (D103–D107); nothing in the master spec or access model is tagged (proposed) any more. Deferred to a planned design: O62 (basket outlet, with the basket's own design). The build has done chunks 0–15 and 17; 16 is in progress (16c left), then 18. Code the approvals need: chunk 18 keeps the session when a save is deleted (D104); chunk 23 gains 23.4 (the idle camera never zooms in, D103) and 23.5 (baskets at bedtime, D105, to land before chunk 22); chunk 22 revisits the rest rule and aligns the `REST_DRIFT` comment (D107). O91 (why slimes get stuck inside each other) is an open investigation, not urgent. The build's values from chunks 10, 12, 13, 14 and 17 in `tuning.md` are still (proposed; to try). Chunk 5N (the native slime tick) runs only if chunk 22 fails (D96). For prototypes: O14 (now the floor phone only; the reference phone is measured, and the floor phone waits for the purchase), O65 (minimum zoom; slime sizes measured on the reference phone). For the first level's design: O22 (with a note from the test level on routes that climb back into the start basin). Parked: O12, O13. Documentalist ingestion done (docs/*.atom.md); ux-writer has an inventory and questions in `../ui_ux/`, no design yet.
