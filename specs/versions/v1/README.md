# v1 — First release

Status: scoping

The first Android release. One level to discover the game's mechanics.
Items are settled unless tagged (proposed). The decision IDs point to
`../../decisions.md`.

## In scope

**World**
- One level of 4 sections, moderately sized. The theme is very basic and close
  to Cocoreccho!: black "stone" and black "plants" form the ground (D34).
- 6 species: 3 in the first section, plus one per section after it (D22, D48).
  In v1, species differ by **colour only**, since voices need sound (D40,
  D50).
- No failure states. The worst case is a lost slime (D36).
- Level rules: the loop can be travelled with no input, at any size (D19,
  D26). From anywhere reachable, gravity leads back toward the loop (D8).
  Every exploration branch has its own route back (D51). Hints that there is
  something to explore are visible from the loop (D45).

**Slimes**
- The train follows the loop. The game wakes the first slime, and sleepers
  wake on contact (D8, D11, D13).
- Movement by hopping (D21).
- Fusion after 3 s of contact; a hop resets the count (D37). Maximum size 3,
  and slimes that would go over it just bump (D39, D49). Size = weight (D24).
- Free slimes: answering the call, then unsure, then heading back by the
  area's route (D27, D41, D51). Left alone after 10 s off screen, lost after
  1 min (D10).
- Tilt moves free slimes: ±45° cap, a dead zone of about 10° (D19).
  (proposed: in v1. It's a control, not an object.)

**Objects**
- The frontier-gate set: a switch, a basket and a gate (D14, D54).
- A split zone at the start of the loop, where fused slimes split back into
  base slimes (D23, D54).
- (proposed) Plain signposts at forks, which only show directions (D47).

**Controls and camera**
- Tap-to-call (D46).
- The camera runs on rails along the loop, moved with buttons at the left and
  right edges. By default it follows the main stream at forks (D33).
- A call drags the camera toward it (D45).
- The idle camera takes over after 45 s and locks onto a train slime (D32).

**Session and parents**
- A fixed 15 min session. It starts at the first tap (D29, D44).
- Bedtime: in the last minute the light turns to dusk and hops slow down (there
  is no sound in v1). Then the slimes fall asleep (D28).
- After bedtime, a 10 min cooldown, or the parent code, leads to **sunrise**:
  the slimes wake and the world runs in screensaver mode (D44). Opening the app
  from scratch also starts in screensaver mode. The phone's usual screen
  timeout applies there, while the screen stays on during a session (D53).
- The parent gate is a 6-digit code (D30). Screen pinning is best effort (D1).
- Progress is saved every 15 s and when the app goes to the background. There
  is one save per level, and the user can delete a level's save (D7, D12,
  D43).

**Platform and business**
- Godot 4, Android. A Linux build for tests (D5).
- A paid app, about $3–5 (D31).

## Explicitly not in v1

- Sound of any kind (v3).
- Any other interactive object (v2).
- Everything in `../timeline.md`.

## Open for v1

O4, O6, O14, O15, O20, O21, O22, O34 (see `../../open-questions.md`).
