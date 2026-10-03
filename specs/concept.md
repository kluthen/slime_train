# Concept

Status: draft v40 (local wake widened to every wake, D156 (7); earlier, v39: the fps session after 0196c25 withdrawn, D155, its terms with it; local wake added, D156; move to the loop start and loop-start queue added, stalled amended (no clock while parked), lost reworded, D150, the user's, details proposed; shipped added, save wipe for automated testing only, the save format before the first store release, D149, proposed; save wipe added, D148, approved in direction)

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
  Screensaver mode and the in-session idle camera share one zoom, about
  10–20% wider than normal play; it doesn't stack. While either is locked on a
  slime, framing zones are ignored. When the child takes back control, framing
  resumes if the camera's centre is still in a framing zone (D80). The idle
  cue is the start of that zoom-out (D62). Numbers to tune are in `tuning.md`.
- **Landscape, locked** (D78): a side view, like Cocoreccho!.
- **Manual camera** (D33). The child moves the camera along the loop, like on
  rails, using left and right buttons at the screen edges. At forks,
  signposts show the directions, and by default the camera follows the main
  stream. A call drags the camera toward the call point at a slow, steady
  pace. That is how the child looks off the loop: there is no joystick
  (D45). A call whose point is already near the middle of the screen (a
  central box 20% of its width by 20% of its height) leaves the camera
  where it is (D101). The edge buttons are strips over the screen's
  whole height, 10% of its width from each edge; the parent zone at the top
  wins where they overlap (D99). Plain signposts at forks show which way the loop goes, and larger
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
- A section's **return route**, from its unopened frontier gate back to the
  start, is part of the loop. It has its own camera rail, and it may carry
  exploration opportunities, which opening later gates must never make
  unreachable (D79). The right edge button always moves the camera forward along the
  loop and the left one backward, whatever the direction on screen (D90).
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

Tapping a sleeper calls nearby awake slimes toward it. A tap within 24
screen px of a sleeper's drawing counts as on it; objects' 20 × 20 mm floor
(D109) doesn't apply to sleepers, which are slimes (D126, proposed). A sleeper wakes only
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
and any minor update ships with its migration (D72). Until the app has
shipped (its first store release), the save format may change without a
migration: a build sets aside a save it can't use and starts that level
fresh (D149; the setting aside proposed).

## Controls

- **Tilt** (D19): the world stays fixed on the screen, and gravity turns with
  the phone, up to ±45°, with a dead zone of about 10°. Neutral is how the
  phone was held when the session started; lying flat counts as neutral. For
  now **only free slimes** feel tilt. Tilt objects always respond to it, and
  can affect the train only indirectly and slightly.
- **Level rule:** the loop can be travelled with no input at all.
- **Tapping** the screen **calls** nearby slimes toward that point (D46).
  Hold-and-drag isn't used for the call. Each called slime's call ends when it
  reaches the point, or after about 8 s if it can't. A new tap replaces the
  call (D73). The radius is a tuning value.
  Taps on objects that answer them, on the edge buttons, or on the parent
  zone don't call (D15, D33, D57). A tap on an object that doesn't answer
  taps, or isn't answering right now, is a call (D109). An object's hit area
  is its drawing plus 5 mm a side, at least 20 × 20 mm on the screen at any
  zoom (D109).
- **Every tap gets a visible answer:** a ripple where the finger touched, and
  slimes in range turn toward it. On the very first play, a wordless pulsing
  mark near the first sleeper shows where to tap (D65).
- **Tilt** is only for exploration or fun actions, never needed to make
  progress (D64).
- **The first touch wins** (D66): while one finger is down, other touches are
  ignored, and get nothing at all, not even a ripple (D102). A thumb resting
  on an edge strip for more than about 5 s stops blocking other touches (D110,
  to check in a playtest). Two calls at once will be tried later.
- All the level rules are collected in `level-design.md`.
- Every awake slime in range answers the call, train slimes included, and
  answering makes it free. This follows from D13: at the start the
  only awake slime is on the loop, so train slimes have to answer or no
  sleeper could ever be woken (D91).

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
- **Completing the level** (D77): when the last basket fires, nothing ends. The
  loop is complete and the world stays open, with a one-time celebration.
- 6 species (D48). No sound (D50). The only objects are the frontier-gate set
  and the split zone at the start of the loop (D54). The full v1 scope is in `versions/v1/README.md`.
- Business model (D31): the base game is paid (about $3–5), and new levels
  come later as paid unlocks (about $2).

## The precursor's actions: where they landed

| Precursor action | Now |
|---|---|
| Gates redirecting the flow into a basket | switch plus basket opening a frontier gate (D14, D35) |
| Jumping toward something out of reach | a called slime jumps upward toward a higher call point (D74) |
| Objects activated by slime contact | presence objects, by weight (D16); v2 |
| Zones revealed when slimes approach | reveal zones; v2 |
| Fusing | D20, D37, D49 |
| Defusing | split zones (D38, D75) |
| Waking | a free slime touching a sleeper (D13, D70) |

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
  with no session. A new session begins only at the **first tap** (D44),
  and only a tap that reaches the world (open ground or an object) counts:
  not the parent zone or an edge button (D102). Opening the app starts in
  screensaver mode when no session or bedtime is running; otherwise the app
  resumes where it was, in the state its stored timers give (D102). The phone's
  usual screen timeout applies there, and the screen stays on during a
  session (D53).
- The parent gate is a **6-digit code** (D30). The parent sets it during a
  one-time setup at first launch. If it's forgotten, the phone's own screen
  lock lets the parent set a new one, typed twice. With no screen lock,
  clearing the app's data is the last resort. There is no external service
  (D55, D102).
- The session counts in **real time**. Time spent in the background or on a
  phone call is used up, and the parent can make up for it by waking the
  slimes early (D56).
- **Parent access** (D57): a tap on the **parent zone**, the band along the
  top of the screen, reveals the parent buttons (wake early, leave,
  settings). Every button asks for the code. A tap there doesn't call (D91).
  The buttons hide after 5 s; a tap outside them closes them and still does
  its normal job. The time left is shown to the parent only behind the code
  (D113, D114).
- Later (v4, D58): the parent can turn the code off entirely.

### Bedtime (D28)

- In the **last minute** the light drifts toward dusk and slimes hop more
  slowly. The music softens too, once there is music (v2, D134). No text, no
  countdown.
- At **bedtime**, slimes fall asleep where they are, the game saves, and calls
  stop doing anything. Bedtime ends with the parent code or after the cooldown
  (D44).
- Bedtime sleep is not the same as being a sleeper. At sunrise the game
  wakes every bedtime-asleep slime, and play carries on where it was (D44).

## Terminology

| Term | Meaning |
|---|---|
| slime | one creature, awake or asleep |
| sleeper | a slime that is asleep and not yet in the train |
| train | whichever slimes are following the loop at the moment; no slots, no fixed order |
| loop | the route the train currently follows, from the start to the frontier gate, with forks that always join again; grows when a gate opens |
| loop's start | where the loop begins, inside the start's split zone; also "the start of the loop" or "the loop start"; lost, stuck and stalled slimes are put back there |
| start basin | the area around the loop's start: a **pocket** behind the loop's start (where the first slime wakes and every return route comes home, behind the train), a **ramp** up to the loop's start, and a **terrace** carrying the loop's first stretch (D116, level rule 22) |
| outgoing route | the part of a section's loop that runs away from the start toward its frontier gate; the return route brings the flow back. In a level's scene, the outgoing segment |
| frontier gate | the first unopened gate, where the loop currently ends |
| gate | a barrier at the end of the loop that opens onto a new area |
| switch | redirects the flow at a fork in the loop; operated by tapping |
| basket | collects slimes until their weight fills it, then fires its target (usually a gate) |
| quota | the weight a basket needs before it fires |
| outlet | where a basket releases its slimes, after firing or after an opt-out; its design is still open (O62) |
| release | a basket letting its slimes go, one at a time at its outlet, back onto the train: after firing, and after an opt-out; paused at bedtime (D91, D105) |
| quota outlines | how a basket shows its quota: one empty slime outline per unit of weight, filling in the colour of each slime caught (ux D4). Not "the slime counter" |
| quota pie | *(proposed, D128)* how a basket with a quota above 10 shows it: one pie per 10 of weight, the last holding the rest, a slice filling per unit of weight |
| debug overlay | developer tools over the game, in debug builds only: speed, reset, slime labels, the kill tool, the fps and the **slime counts**: Physics (the slimes that cost physics), On screen, In range (not parked) and Parked (D143, proposed, chunk 22d; before it: on screen : simulated off screen : parked) |
| awake cluster | *(proposed, D143)* a group of touching slimes that all cost physics (awake, not resting, not parked); the **largest awake cluster** is its biggest, in slimes, in the perf log and in level rule 23. Not a resting pile, which costs little |
| local wake | *(D156, chunk 22l)* how a resting pile wakes: every disturbance (a release, a touch faster than 30 px/s, a move to the loop start, a fusion, a split, a slime taken out of the level, a call, a trapdoor, gate or lid opening or shutting, a tilt change, a state change) wakes only the resting slimes it reaches, never the whole pile, and never a sleeper (replaces D96's whole-pile wake) |
| crowd detail | *(proposed, D140, D141)* fewer ring points per slime when many slimes are active (20, 30, 40 or more) or when zoomed out; a size-1 slime goes from 12 points down to 10, 8 or 6. A detail level: 0 (full) to 3. In play, the crowd's part applies only when the device can't keep up: a **detail ceiling** set by the device's load caps it (a good device keeps full points); test mode applies it always |
| frontier set | the signpost, switch, basket and gate that end a section: flip the switch, fill the basket, the gate opens (D14). Inert once its gate is open (D86) |
| trapdoor | the part of a frontier switch that covers its basket: solid while the switch sends the flow onward, open while it is flipped, dropping slimes into the basket |
| lid | the part of a gate that shuts the old return route's entrance once the gate is open (D105) |
| weight | a slime's size seen as load; what presence objects respond to |
| left alone | a free slime off screen for more than 10 s |
| lost | a left-alone slime not back on the loop after 1 min; moved to the loop start (a **move to the loop start**) |
| stuck | two slimes that can't fuse, found inside each other for about 2 s; a state of its own, not "lost", with the same effect: the smaller one goes to the loop start (D100) |
| stalled | a train slime whose progress along the loop hasn't advanced for 60 s, or that left the level's bounds; not "lost", but with the same effect: moved to the loop start and logged (D118, D121). The build says "lost as stalled". *From chunk 22h (D150, the user's):* the 60 s count only while it is simulated; parked, its clock is paused |
| move to the loop start | *(D150, the user's "emergency teleport"; details proposed; chunk 22h)* the one move lost, stuck and stalled slimes take: back on the train, at a random free spot on the loop's first 240 px, inside the start's split zone, never onto another slime. Taken one at a time, through the **loop-start queue** |
| loop-start queue | *(D150, the user's; details proposed; chunk 22h)* the slimes due a move to the loop start, waiting their turn: one move at a time, the next 0.5 to 2 s (random) after the last; first due, first moved (out of bounds first). A waiting slime carries on as it was; one that recovers before its turn leaves without a move. Not a line of train slimes waiting single file on the loop |
| free slime | an awake slime attracted away from the loop, driven by physics alone until it rejoins |
| session | one timed play period (15 min for now) |
| level | a whole world with its own loop, sections and save file; v1 has the test level only (D134) |
| signpost | a sign at a fork showing which way the loop goes |
| large signpost | a signpost that also lets the child pick which branch the camera follows |
| filter | a fork that sends slimes down a branch by species or by size (D88); usually has a signpost next to it |
| population fork | *(proposed, v2, D143)* a fork that sends the next slimes down its emptier branch, to break up crowds; not tapped, has a signpost like every fork |
| screensaver mode | the world running with no session, after sunrise and before the first tap |
| parent zone | the band along the top of the screen, 7 mm high, full width and unmarked; a tap there reveals the parent buttons and never calls (D57, D113). Also called "the top of the screen" or "the top band" |
| edge button | the left or right control that moves the camera along the loop: a strip over the screen's whole height, 10% of its width from the edge, that never calls (D99) |
| framing zone | an area of the level that sets the camera's zoom and position when the camera reaches it |
| activity zone | *(proposed, D143)* where slimes are simulated with full physics while the camera is at a given spot: the view grown by the off-screen margins; parked beyond. A v2 level-design tool shows it |
| camera rail | the path the camera runs along, following the loop; every part of the loop, return routes included, has one (D33, D79) |
| sunrise | the end of bedtime: slimes wake up and screensaver mode begins |
| species | a kind of slime; only the same species fuse (replaces the precursor's "type") |
| call | a tap that draws nearby awake slimes toward a point (D46) |
| unsure | a free slime just after a call ends, lingering near the call point |
| heading back | a free slime making for the loop |
| size | the number of base slimes a slime is made of; equals its weight |
| base slime | a slime of size 1, the unit that sizes, weights, quotas and the 200-slime cap count in; every sleeper is one |
| chain waking | a woken slime waking the sleepers it touches, which wake the ones they touch, so one call wakes a whole touching line (measured: centres 44 px apart wake, 45 px don't; D129) |
| touching line | sleepers placed with their centres at most 44 px apart (the test level uses 38 to 40), so they all wake by chain waking once one does; a line off screen wakes as it comes into view |
| section | the part of a level opened by one gate |
| split zone | a place that splits slimes back into base slimes; the start of the loop has one (replaces "defusing spot") |
| route back | the route an exploration branch provides back to the loop |
| exploration branch | a place off the loop worth a call, such as the tree or the cave; it has its own route back and a hint visible from the loop (D18, D45, D51). Not a fork of the loop |
| decoration | level art that isn't simulated: scenery such as plants and rocks, drawn as curves (D93), that isn't terrain or an object. How it behaves toward slimes, taps and hints is O96 |
| return route | the part of the loop that takes the flow from a section's unopened frontier gate back to the start; has its own rail (D79; how it works is O22) |
| parent gate | the 6-digit code an adult enters to leave, change settings, or end bedtime early |
| bedtime | the end of a session: slimes fall asleep until sunrise (parent code or 10 min); not the same as a sleeper |
| stable ID | the name a save uses to find a placed thing, `<place>.<kind>.<name>` (for example `s1.sleeper.01`); kept once a level is released (D72, level rule 20) |
| test mode | a mode of the Linux and debug Android builds only, never the release: loads a fixture, speeds up or skips time, and injects taps and tilt from a script (D91) |
| fixture | a named starting state for test mode, stored with its level (a save and a sidecar); test tooling, not a player's save |
| save wipe | *(D148, approved in direction, D149; its details proposed; chunk 19w)* a launch flag for **automated test runs only**, `--wipe-save`, in debug builds only: every level's save is deleted at launch, the parent code kept. Never in a release build, never passed by save and restore tests, never used in manual play (there, a level is started over with the parent's **delete**). Not the parent's **delete** of one level's save (D43), and not a wiped save in the sense of "saves are never wiped", which is about a player's build |
| shipped | *(proposed, D149)* the app from its **first store release** on (probably v4; v1 never ships). Before it there is no player's build: the save format may change without a migration, and a save a build can't use is set aside. After it, every save-format change ships with its migration. Not the basket's **release** |
| skeleton | a level just made by the new-level scaffolder: minimal, playable and passing the level rules, for a designer to build on |
