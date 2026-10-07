# v1 (full MVP)

Status: master spec consolidated (early, D76)

The consolidated spec is [`master-spec.md`](master-spec.md), with its
companion [`access-model.md`](access-model.md). This page stays the working
scope list with decision IDs. The real first level is not part of it: it is
v2's chunk L01 (`../../levels/01/`, D134).

**v1 is the test level only**, played end to end on the phones, with the
platform, parent, save and performance work of the build plan (D134).
**The full MVP** (D135): all the bare mechanics are validated, the gameplay
loop is there, and it can be tried. Never published to a store. The folder
and the "v1" IDs keep their name, since atoms, code and briefs use them.
Items are settled. The decision IDs point to
`../../decisions.md`.

## In scope

**World**
- The test level (3 sections, 5 species; D134). The real first level's 4
  sections and 6 species move to v2 with it. The theme is very basic and close
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
- Movement by hopping, with each state's hopping rules (D21, D74).
- Fusion after 3 s of contact; a hop resets the count (D37). Maximum size 3,
  and slimes that would go over it just bump (D39, D49). Size = weight (D24).
- Free slimes: answering the call, then unsure, then heading back by the
  area's route (D27, D41, D51). Left alone after 10 s off screen, lost after
  1 min (D10).
- Tilt moves free slimes: ±45° cap, a dead zone of about 10° (D19).
  It's a control, not an object, so it is in v1 (D91).

**Objects**
- The frontier-gate set: a switch, a basket and a gate (D14, D54). A full
  basket earns a reward animation. The player can opt out before it's full by
  flipping the switch back (D70).
- A split zone at the start of the loop, where fused slimes split back into
  base slimes (D23, D54).
- Plain signposts at forks, which only show directions (D47, D91).
- Once its gate opens, a frontier set is inert for good (D86). Completing the
  level brings a one-time celebration; the world stays open (D77).
- No filters in v1: the only fork in the loop is the frontier switch, and every
  size travels the loop the same way (D89).

**Controls and camera**
- Tap-to-call. Every tap shows a ripple, and on the very first play a wordless
  hint appears near the first sleeper (D46, D65). The first touch wins (D66).
  A call lasts until a slime reaches the point, capped at about 8 s, and a new
  tap replaces it (D73).
- The camera runs on rails along the loop, moved with buttons at the left and
  right edges. By default it follows the main stream at forks (D33).
- A call drags the camera toward it (D45).
- The idle camera takes over after 45 s and follows the train slime nearest
  the middle of the view, with a slow zoom-out as the cue (D32, D59).
- Automatic framing: the player never controls the zoom. Framing zones set the
  zoom and position, and leaving one takes a slightly longer delay than usual.
  Screensaver mode and the idle camera are about 10–20% wider (D60, D61,
  D62).

**Session and parents**
- A fixed 15 min session. It starts at the first tap and counts in real time,
  including while the app is in the background (D29, D44, D56).
- Bedtime: in the last minute the light turns to dusk and hops slow down (there
  is no sound in v1). Then the slimes fall asleep (D28).
- After bedtime, a 10 min cooldown, or the parent code, leads to **sunrise**:
  the slimes wake and the world runs in screensaver mode (D44). Opening the app
  starts in screensaver mode unless a session or bedtime is running, which
  it resumes (D102). The phone's usual screen
  timeout applies there, while the screen stays on during a session (D53).
- The parent gate is a 6-digit code, chosen during a one-time setup at first
  launch. It is recovered through the phone's own screen lock, with no external
  service (D30, D55). Screen pinning is best effort (D1). It is requested
  each time the app opens; setup recommends "Ask for PIN before unpinning"
  (D84, D85). A wrong code: shake and clear, a 30 s wait after 5 wrong tries
  (D83).
- A tap at the top of the screen reveals the parent buttons: wake early, leave,
  settings (change the code, delete a level's save). Every button asks for the
  code (D57).
- Progress is saved every 15 s and when the app goes to the background. There
  is one save per level, and the user can delete a level's save (D7, D12,
  D43).

**Platform and business**
- Godot 4, Android. A Linux build for tests (D5). Landscape, locked (D78).
- 60 fps on the reference phone in normal play; at least 30 fps on the floor
  phone with the level's largest realistic pile on one screen, a full basket
  plus the train, mostly still (D82, amended by D96). Met on the reference
  phone on every case measured, normal play included (sessions 6 and 7,
  D163, D167); the floor phone's half is judged on the phone emulation
  until a floor phone exists (the user's, D167; a new measure on current
  main after the health review's splits). On the desktop, section 3 holds a
  steady 60 fps (item 24.1, D166). At most 2 ticks a frame (slow motion
  rather than a collapse); the phone frame budget is a headroom target,
  not a gate (D163).
- A paid app, about $3–5 (D31): for the first store release, probably v4, not v1 (D135, D137).

## Explicitly not in v1

- Sound of any kind: it begins at v2 (music; effects a candidate; D134, D136).
- The real first level, chunk L01 (v2, D134).
- The geyser (a level object, D160) and the review of the test level's
  start (chunk TL2): after v1, first, with v2's level work (the user's,
  D161).
- Any other interactive object (v2).
- Everything in `../timeline.md`.

## Open for v1

O14 (a real floor phone; DoD 30's floor half on the phone emulation meanwhile), O65, O101 and O121 (D167: O107, O127 and O128 closed, and every other proposed decision approved, the user's; O125 and O126 closed by D165, the user's; O122 answered by D162, accepted in D167; O118, O119, O120 and O124 after v1, D161; O123 answered by D161; O91 fixed, D159; O22 and O62 now serve the first real level, v2) (see `../../open-questions.md`). The UX
review's interaction details (O67–O77) are settled (D102), and so are the
build's points O79–O87 (D103–D107).
