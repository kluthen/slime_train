# Concept

Status: draft v20

## One-liner

Slime Train is an "interactive screensaver" for Android, made for children aged
3–5. A train of squishy slimes travels around a loop through a soft,
curved world. The child gets more slimes to join the train, and the train
opens up the world around it.

Inspiration: LocoRoco Cocoreccho! (research in `docs/research/locoroco-cocoreccho.md`).
The slimes stand in for LocoRoco.

## Design stance

- **Watching is playing.** The world keeps moving and stays pleasant to look
  at without any input. Input adds to it; it is never required to keep
  things alive.
- **Idle camera** (D32, D59). After 45 s with no input, the camera glides to the
  train slime nearest the middle of the view and follows it. If that slime
  fuses, the camera follows the fused slime; if it splits, one of the pieces.
  The cue 10 s beforehand is a slow zoom-out. Any touch takes back control and
  also does its normal job.
- **Automatic framing** (D60). The player never controls the zoom. Where the
  camera is decides the zoom, and sometimes the position. An area that needs a
  wider view pulls the camera gently into place, and leaving it through the
  edge buttons takes a slightly longer delay than usual, to be tested (D61).
  Screensaver mode and the in-session idle camera are both about 10–20% more
  zoomed out than normal play. The idle cue is the start of that zoom-out
  (D62). Numbers to tune are in `tuning.md`.
- **Manual camera** (D33). The child moves the camera along the loop, like on
  rails, using left and right buttons at the screen edges. At forks,
  signposts show the directions, and by default the camera follows the main
  stream. A call drags the camera toward the call point at a slow, steady
  pace. That is how the child looks off the loop: there is no joystick
  (D45). Plain signposts at forks show which way the loop goes, and larger
  signposts let the child pick which branch the camera follows (D47).
- **Simple, curved, high-contrast, low detail.** Theming (desert, forest,
  rivers…) may come later as palette and decoration changes only.

## Gameplay layers, in priority order

1. **The train (primary).** Awake slimes follow the loop, and that is fun to
   watch in itself. Sleeping slimes seen along the way catch the child's eye;
   bringing them into the train is the core action (see "Waking sleepers").
2. **Exploring the loop's surroundings (secondary).** The areas just off the
   loop hold more slimes to find.
3. **Fusion (tertiary).** Two slimes of the same species fuse into a bigger
   one after staying in contact for a while. Bigger slimes are heavier and jump
   higher, which opens pathways not yet explored. See `slimes.md`.

## The loop and free slimes (D8)

- The **train** follows the **current loop**, a drawn route. Physics only
  handles the squish and the bumps.
- Opening a gate makes the loop grow to take in the new area. Only the way
  back to the start is replaced (D9).
- Attracting slimes away from the loop makes them **free**: they are driven
  by physics alone.
- A free slime makes its way back to the loop by physics and rejoins the
  train when it reaches the loop (D11).
- **Left alone:** off screen for more than 10 s. **Lost:** left alone and still
  not back on the loop after 1 min. A lost slime is teleported to the start of
  the loop (D10). A free slime that stays on screen is never lost.
- **The loop has forks** (switches, spring-back bending pathways). Every branch
  joins the loop again, and there are no dead ends. A slime on any branch is
  still part of the train. Exploration areas hang off the route and are reached
  only by calling slimes there (D18).
- **The train has no slots** (D11). It is whichever slimes are following the
  loop, clumped by where they happen to be at that moment. A slime alone on
  the loop keeps following it.

## Waking sleepers (D13)

Tapping a sleeper calls nearby awake slimes toward it. A sleeper wakes only
when a **free slime** (one that answered a call) touches it. Train slimes
never wake sleepers, and sleepers never sit on the loop (D70). Waking happens
only on screen. The woken slime, being free, in time rejoins the train. Slime
states, movement, size, species and fusion are in `slimes.md`.
- **Level rule:** from anywhere a free slime can reach, following gravity down
  leads back to the loop. Every exploration branch has its own route back
  (D51), and hints that there is something to explore are visible from the
  loop (D45).

## Persistence (D7)

Progress carries over between sessions. The saved state holds each slime's
species, size and position, plus the state of every interactive object. It is
saved every 15 s and whenever the app goes to the background. On load, a slime
saved in mid-air is placed on the ground or at its jump start, or declared lost
(D12). Each level has its own save file, and the user can delete one level's
save (D43). Saves are never wiped. A released level isn't meant to change,
and any minor update ships with its migration (D72).

## Controls

- **Tilt** (D19): the world stays fixed on the screen, and gravity turns with
  the phone, up to ±45°, with a dead zone of about 10°. Neutral is how the
  phone was held when the session started; lying flat counts as neutral. For
  now **only free slimes** feel tilt. Tilt objects always respond to it, and
  can affect the train only indirectly and slightly.
- **Level rule:** the loop can be travelled with no input at all.
- **Tapping** the screen **calls** nearby slimes toward that point (D46).
  Hold-and-drag isn't used for the call. Its radius and duration are O21.
  Taps on objects, on the edge buttons, or at the top of the screen (parent
  access) don't call (D15, D33, D57).
- **Every tap gets a visible answer:** a ripple where the finger touched, and
  slimes in range turn toward it. On the very first play, a wordless pulsing
  mark near the first sleeper shows where to tap (D65).
- **Tilt** is only for exploration or fun actions, never needed to make
  progress (D64).
- **The first touch wins** (D66): while one finger is down, other touches are
  ignored. Two calls at once will be tried later.
- All the level rules are collected in `level-design.md`.
- Every awake slime in range answers the call, train slimes included, and
  answering makes it free. (proposed: this follows from D13. At the start the
  only awake slime is on the loop, so train slimes have to answer or no
  sleeper could ever be woken.)

## Interactive objects

See `interactive-objects.md`. Most are operated by tapping them; a few are
driven by tilt or by the slimes on them (D15). The standard frontier-gate
pattern is a switch plus a basket (D14).

## First release (D34, D35, D36)

- **One level of 4 sections**, moderately sized. The theme is very basic and
  close to Cocoreccho!: black "stone" and black "plants" form the ground.
  There are few kinds of interaction. Its aim is for the child to discover the
  game's mechanics.
- Pacing: a lap takes a slime a few minutes, but the slimes are spread along
  the loop. Moving the camera along the loop keeps showing travelling slimes.
- The only way to open a frontier gate is the switch-plus-basket pattern.
- **No failure states.** The worst case is a lost slime, teleported back to the
  start of the loop.
- 6 species (D48). No sound (D50). The only objects are the frontier-gate set
  and the split zone at the start of the loop (D54). The full v1 scope is in `versions/v1/README.md`.
- Business model (D31): the base game is paid (about $3–5), and new levels
  come later as paid unlocks (about $2).

## Candidate actions (from precursor, each still to be specified)

Gates redirecting the flow (for example into a waiting basket that opens the
next section), jumping toward a tapped target that is out of reach, objects
activated by slime contact, zones revealed when slimes approach, fusing,
defusing spots, waking by contact.

## Session and parental controls

A session is limited to at most 15 minutes, and leaving the app requires an
adult-only operation. This is **best effort, a courtesy to parents and not a
guarantee** (D1): Android screen pinning, our own parent gate, and a timer that
survives the app being killed.

- A session lasts a fixed **15 min** (D29). Letting the parent choose the length
  comes later.
- Bedtime ends either when the parent enters the code or after **10 real-time
  minutes** (D29, D44). The long delay is on purpose: it nudges the child to put
  the phone down.
- **Sunrise:** the slimes wake up and the world runs in **screensaver mode**,
  with no session. A new session begins only at the **first tap** (D44).
  Opening the app from scratch also starts in screensaver mode. The phone's
  usual screen timeout applies there, and the screen stays on during a
  session (D53).
- The parent gate is a **6-digit code** (D30). The parent sets it during a
  one-time setup at first launch. If it's forgotten, the phone's own screen
  lock lets the parent set a new one. With no screen lock, clearing the app's
  data is the last resort. There is no external service (D55).
- The session counts in **real time**. Time spent in the background or on a
  phone call is used up, and the parent can make up for it by waking the
  slimes early (D56).
- **Parent access** (D57): a tap at the top of the screen reveals the parent
  buttons (wake early, leave, settings). Every button asks for the code. A tap
  there doesn't call (proposed).
- Later (v4, D58): the parent can turn the code off entirely.

### Bedtime (D28)

- In the **last minute** the light drifts toward dusk and slimes hop more
  slowly. The music softens too, once there is sound (v3, D50). No text, no
  countdown.
- At **bedtime**, slimes fall asleep where they are, the game saves, and calls
  stop doing anything. Bedtime ends with the parent code or after the cooldown
  (D44).
- Bedtime sleep is not the same as being a sleeper. At the next session the
  game wakes every bedtime-asleep slime, and play carries on where it was.

## Terminology

| Term | Meaning |
|---|---|
| slime | one creature, awake or asleep |
| sleeper | a slime that is asleep and not yet in the train |
| train | whichever slimes are following the loop at the moment; no slots, no fixed order |
| loop | the route the train currently follows, from the start to the frontier gate, with forks that always join again; grows when a gate opens |
| frontier gate | the first unopened gate, where the loop currently ends |
| gate | a barrier at the end of the loop that opens onto a new area |
| switch | redirects the flow at a fork in the loop; operated by tapping |
| basket | collects slimes until their weight fills it, then fires its target (usually a gate) |
| weight | a slime's size seen as load; what presence objects respond to |
| left alone | a free slime off screen for more than 10 s |
| lost | a left-alone slime not back on the loop after 1 min; teleported to the loop start |
| free slime | an awake slime attracted away from the loop, driven by physics alone until it rejoins |
| session | one timed play period (15 min for now) |
| level | a whole world with its own loop, sections and save file; the first release ships one (proposed) |
| signpost | a sign at a fork showing which way the loop goes; a larger one lets the child pick the camera's branch (proposed) |
| filter | a fork that sends slimes down a branch by species; usually has a signpost next to it (proposed) |
| screensaver mode | the world running with no session, after sunrise and before the first tap (proposed) |
| framing zone | an area of the level that sets the camera's zoom and position when the camera reaches it (proposed) |
| sunrise | the end of bedtime: slimes wake up and screensaver mode begins (proposed) |
| species | a kind of slime; only the same species fuse (replaces the precursor's "type") |
| call | a tap that draws nearby awake slimes toward a point (D46) |
| unsure | a free slime just after a call ends, lingering near the call point (proposed) |
| heading back | a free slime making for the loop (proposed) |
| size | the number of base slimes a slime is made of; equals its weight |
| section | the part of the world opened by one gate (proposed) |
| parent gate | the 6-digit code an adult enters to leave, change settings, or end bedtime early |
| bedtime | the end of a session: slimes fall asleep until sunrise (parent code or 10 min); not the same as a sleeper |
