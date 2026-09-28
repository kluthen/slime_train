# Slime Train v1 — Master spec

Status: consolidated early, at the user's request, while two things are still
unsettled: the design of the real first level, and the gaps listed in
"Known gaps". Everything else here is settled, except items tagged
(proposed). Companions: `access-model.md` (who may do what) and
`../../personas.md` (who the game is for). The test level used to build and
check v1 is in `../../levels/test/README.md`.

## 1. Concept and objective

Slime Train is an **"interactive screensaver"** for Android, made for children
aged 3 to 5. A train of squishy slimes hops around a loop through a soft,
curved, side-view world. The child calls slimes off the loop to wake sleeping
slimes, lets same-species slimes fuse into bigger ones, and fills baskets to
open gates, so the loop grows into new sections. It is inspired by LocoRoco
Cocoreccho!.

Design stance:

- **Watching is playing.** The world keeps moving and stays pleasant to watch
  with no input at all. Input adds to it and is never needed to keep things
  alive.
- **Nothing to fail.** There is no failure state, no score and no text for the
  child. The worst case is a slime that got lost and reappears at the start of
  the loop.
- **Every touch is answered.** Any tap anywhere does something visible.
- **Sessions end softly.** A session lasts 15 minutes and ends with the
  slimes falling asleep. Leaving the app needs a parent code.
- **Simple, curved, high contrast, low detail.**

v1's objective is one level in which a child can discover every core
mechanic, a session lock the parent trusts, and a code base built so that
further levels are content rather than code.

## 2. Personas and goals served

Full reference: `../../personas.md`. These personas come from real people.

| ID | Persona | Priority |
|---|---|---|
| P1 | **The newcomer.** A 3-year-old girl who has never played a video game and can't read. She plays on a Samsung Galaxy S20 FE, at home, in the daytime, as a reward or after school. | primary |
| P2 | **The watching sibling.** Her 2-year-old brother, who watches and sometimes pokes the screen at the same time. | secondary |
| P3 | **The early player.** Friends' children, about 4, on a similar phone. They play more on purpose. | secondary |
| P4 | **The parent.** Owns the phone, buys and sets up the game. | supporting |

| Goal | How v1 serves it | Served |
|---|---|---|
| P1.G1 See something pleasant happen and keep watching it | the train runs with no input; the idle camera; screensaver mode | fully |
| P1.G2 Touch the screen and see the world answer straight away | tap-to-call anywhere, a ripple on every tap, slimes in range turn toward the touch | fully |
| P1.G3 Find out on her own what touching does, with no one to explain and no reading | the ripple, and a wordless pulsing hint near the first sleeper on the very first play; the first sleeper sits close to the first awake slime | fully (to confirm in playtests) |
| P1.G4 Never fail, never get stuck | no failure states; the loop runs with no input; a lost slime comes back | fully |
| P2.G1 Watch the slimes | same as P1.G1 | fully |
| P2.G2 Poke the screen without breaking anything | only the first finger counts; every parent button asks for the code | partially: while his sister's finger is down, his poke does nothing. Two calls at once are for later. |
| P3.G1 Play on purpose: call, fuse, fill a basket, open the next section | sleepers, fusion, the switch-plus-basket gate set, four sections | fully |
| P3.G2 Explore off the loop to find more slimes | exploration branches whose hints are visible from the loop; the call drags the camera | fully |
| P4.G1 A calm activity that ends on its own | 15 min sessions, a gentle bedtime, a 10 min cooldown | fully |
| P4.G2 The child can't leave, change or buy anything | screen pinning plus the parent code; no purchases inside v1 | partially: best effort by design (see 5.9) |
| P4.G3 Set it up once, easily | one-time setup at first launch | fully |
| P4.G4 Take the phone back or give more time at will | parent buttons: wake early, leave, settings | fully |

Persona tensions settled for v1:

- **P1 can't read, P4 needs a secure gate.** The parent code is 6 digits. A
  4-year-old (P3) may know digits; that risk is accepted.
- **P2 pokes while P1 plays.** The first touch wins, so P1's play isn't
  hijacked.
- **P1's hold on the phone is unknown.** Tilt is a bonus and is never needed
  to make progress.

Goals knowingly deferred: none of the listed goals is deferred; sound (which
would add to P1.G1 and P1.G2) comes in a later version.

## 3. Scope

### In v1

- One level of 4 sections, with a basic theme close to Cocoreccho!: black
  "stone" and black "plants" form the ground. 6 species, told apart by colour.
- Slimes: the train, sleepers, calls, free slimes and their phases, hopping,
  fusion up to size 3, the split zone at the start of the loop, left alone and
  lost.
- Objects: the frontier-gate set (switch, basket, gate), the split zone at
  the start of the loop, and plain signposts at forks (proposed).
- Controls: tap-to-call, tilt for free slimes, edge buttons moving the camera,
  a tap at the top of the screen for parent access.
- Camera: rails along the loop, the call dragging the camera, the idle camera,
  automatic framing and framing zones.
- Session and parents: screensaver mode, 15 min real-time sessions, bedtime,
  a 10 min cooldown, sunrise, the 6-digit parent code with setup and
  recovery, screen pinning.
- Persistence: one save per level, autosave, deleting a level's save.
- A test level (not shipped, proposed) plus a test mode for end-to-end tests.
- Platform: Godot 4, Android; a Linux desktop build for development and tests.
  A paid app at about $3–5, with no purchases inside the app.

### Not in v1

| Item | Where it goes |
|---|---|
| Sound of any kind (effects, species voices, music) | v3 |
| Every other interactive object: bending pathways, other split zones, tilt objects, reveal zones, species filters, switches and baskets outside the frontier set | v2 |
| Large signposts that let the child choose which branch the camera follows | v2 (proposed) |
| Turning the parent code off | v4 |
| A parent-chosen session length and cooldown | later, no version yet |
| A freeform camera (hold and drag, replacing the edge buttons) | later, no version yet |
| Species behaviour quirks, a maximum size of 5, fusing different species | later, no version yet |
| Other frontier-gate patterns | later, no version yet |
| Paid extra levels (about $2 each), theming, a music generator, procedural generation, iOS | later, no version yet |
| Two calls at once | to try later |

## 4. Vocabulary

One term per concept, used everywhere in the code and documents.

| Term | Meaning |
|---|---|
| slime | one creature, awake or asleep |
| sleeper | a slime that is asleep and not yet in the train |
| train | whichever slimes are following the loop at the moment; no slots, no fixed order |
| loop | the route the train currently follows, from the start to the frontier gate, with forks that always join again; grows when a gate opens |
| gate | a barrier at the end of the loop that opens onto a new area |
| frontier gate | the first unopened gate, where the loop currently ends |
| section | the part of a level opened by one gate |
| level | a whole world with its own loop, sections and save file |
| switch | redirects the flow at a fork in the loop; operated by tapping |
| basket | collects slimes until their weight fills it, then fires its target |
| split zone | a place that splits slimes back into base slimes |
| signpost | a sign at a fork showing which way the loop goes |
| species | a kind of slime; only the same species fuse |
| size | the number of base slimes a slime is made of |
| weight | a slime's size seen as load |
| call | a tap that draws nearby awake slimes toward a point |
| free slime | an awake slime drawn away from the loop by a call |
| unsure | a free slime just after its call ends, lingering near the call point |
| heading back | a free slime making for the loop |
| route back | the route an exploration branch provides back to the loop |
| return route | the way a section sends the flow from its unopened frontier gate back to the start |
| left alone | a free slime off screen for more than 10 s |
| lost | a left-alone slime not back on the loop after 1 min |
| framing zone | an area of the level that sets the camera's zoom and position |
| session | one timed play period (15 min) |
| bedtime | the end of a session: slimes fall asleep until sunrise |
| sunrise | the end of bedtime: slimes wake and screensaver mode begins |
| screensaver mode | the world running with no session |
| parent gate | the 6-digit code an adult enters for any parent action |

## 5. Mechanics

### 5.1 The world and the loop

- A level is a side-view world. The **loop** is a drawn route that the train
  follows. Physics only handles the squish and the bumps of slimes on it.
- The loop has **forks**. Every branch joins the loop again: there are no
  dead ends. A slime on any branch of the loop is still part of the train.
- **Exploration areas** hang off the loop. Slimes get there only by being
  called.
- The loop runs from the **start** to the **frontier gate**. Unless the child
  is actively filling the frontier basket, the flow at the frontier is sent
  back to the start by that section's return route. What the return route is
  made of (a slide, wind, a conveyor…) is decided per level (see Known gaps).
- **Opening a gate** extends the loop into the new section. Only the part
  that led back to the start is replaced: the old return route stays in the
  world but is no longer used. Gates stay open for good.
- The **start of the loop** carries a split zone.

### 5.2 Slimes

**States**

| State | Behaviour |
|---|---|
| sleeper | Asleep and still. Never sits on the loop. Wakes only when a free slime touches it on screen. The game wakes the very first slime itself. |
| train slime | Awake, following the loop. Ignores tilt. |
| free slime | Awake, away from the loop after answering a call. Driven by physics alone and feels tilt. |
| bedtime-asleep | Asleep because the session ended. Not a sleeper: the game wakes it at sunrise and play carries on. |

**The call and free slimes**

- A tap on open ground is a **call**. Every awake slime within the call radius
  (about half the screen width, proposed) answers it, train slimes included,
  and becomes free. (proposed: this is needed because at the start the only
  awake slime is on the loop.)
- A free slime goes through three phases:
  1. **Answering the call:** it hops toward the call point until it reaches
     it, or gives up after about 8 s. A new tap replaces the call point.
     Answering slimes gather in a clump, which is how fusion usually starts.
  2. **Unsure:** for up to about 15 s after its call ends, it stays near the
     last call point, with small lazy hops.
  3. **Heading back:** it hops back toward the loop, mostly downhill, but
     knowing the shortest way, by following its area's route back. It rejoins
     the train when it reaches the loop.
- Physics applies in every phase. On a steep slope its hops can't hold it and
  it may roll.
- **Left alone:** a free slime off screen for more than 10 s. **Lost:** left
  alone and still not back on the loop after 1 min. A lost slime is moved to
  the start of the loop. A free slime that stays on screen is never lost.
  Because of the level rules, "lost" is a safety net rather than something
  that happens in normal play.

**Waking**

- Tapping a sleeper is a call centred on it.
- A sleeper wakes when a free slime touches it, on screen. Train slimes never
  wake sleepers. The woken slime is free and, in time, heads back to the
  train.

**Hopping**

Slimes move only by hopping.

| State | Hopping |
|---|---|
| train slime | forward along the loop every ~1.5–3 s, with a little random timing per slime so the train bounces unevenly |
| answering a call | toward the call point, a bit more often; it jumps upward when the point is higher, and bigger slimes jump higher |
| unsure | small, lazy hops in random directions near the call point |
| heading back | along its area's route back |
| sleeper, bedtime-asleep, covered by other slimes, resting in a full basket | no hopping |

Bigger slimes hop a little less often, but further and higher. In the last
minute of a session every slime hops more slowly.

**Size, weight and species**

- **Size** is the number of base slimes a slime is made of. It is also its
  **weight**, which is what baskets count.
- The **maximum size is 3**. Two slimes whose sizes add up to more than 3
  just bump into each other.
- 6 **species** in v1: 3 native to the first section, and one more per later
  section. In v1 species differ by colour only (see Known gaps on colour
  blindness).

**Fusion and splitting**

- Two slimes of the same species fuse after **3 s of continuous contact**. A
  hop that breaks contact resets the count. The fused slime's size is the sum
  of the two.
- Fusion mostly happens through the call (slimes clumped at the call point),
  but can happen on its own, and a dip in the loop can nudge slimes into
  fusing.
- Only split zones split slimes. A split zone splits a slime back into base
  slimes instantly. In v1 the only split zone is at the start of the loop.

### 5.3 Off screen

- Physics runs only for slimes on or near the screen.
- Off screen, a **train slime** is a position along the loop moving at a
  deterministic pace. When the view comes near it, it is spawned just outside
  the view and physics takes over.
- A **free slime** that leaves the screen is placed on the nearest point of
  its area's route back and follows it at the same deterministic pace. If no
  route back is near, it is lost.
- **Fusion and waking happen only on screen.**
- **Baskets** keep counting weight off screen and can fill there.
- (proposed) Sleepers don't simulate until something touches them, slimes in
  a full basket use a simplified state, and slimes on screen may use fewer
  points when zoomed out.

### 5.4 Interactive objects

Every object is a reusable component configured in the Godot editor, and its
state is saved. A tap on an object operates it; a tap anywhere else is a call.
(proposed: hit areas are larger than the drawn object, for small fingers.)

- **Switch.** Stands at the fork just before the frontier gate. By default it
  sends the flow back to the start (by the return route). Tapping it flips it
  so the flow goes into the basket. (proposed: it stays flipped until tapped
  again.)
- **Basket.** Shows the weight it still needs as empty slime outlines, which
  fill by weight (a size-3 slime fills three). When full, it plays a **reward
  animation**, fires its target (the gate), then releases its slimes. It can
  fill off screen. (proposed: the reward and the firing wait until the basket
  is in view.)
- **Opting out.** Flipping the switch back before the basket is full stops the
  filling. (proposed: the slimes inside go back to the loop and the basket
  empties.)
- **Gate.** Opens when its basket fires, extends the loop, and stays open.
- **Split zone.** At the start of the loop; splits every slime that enters it
  into base slimes.
- **Signpost** (proposed). Stands at every fork of the loop and shows which
  way the loop goes. Not interactive.
- The switch plus basket is the **only** way to open a gate in v1.
- (proposed) The components share one rule format ("when this basket is full,
  open that gate"). Its design is left to implementation.

### 5.5 Controls

The screen has four tap zones, checked in this order:

1. **The top of the screen:** reveals the parent buttons. Doesn't call.
   (proposed)
2. **The left and right edge buttons:** move the camera along the loop.
   Don't call.
3. **An interactive object:** operates it. Doesn't call.
4. **Anywhere else:** a call.

- **Every tap gets a visible answer:** a ripple where the finger touched, and
  slimes in range turn toward it.
- **First-play hint:** on the very first play, if the child hasn't called
  after about 10 s, a wordless pulsing mark appears near the first sleeper.
- **The first touch wins:** while one finger is down, other touches are
  ignored.
- **Tilt:** the world stays fixed on the screen and gravity turns with the
  phone, up to ±45°, with a dead zone of about 10°. Neutral is how the phone
  was held when the session started; lying flat counts as neutral. Only free
  slimes feel tilt. Tilt is never needed to make progress.
- No hold, drag, pinch or multi-finger gesture is used in v1.

### 5.6 Camera

- **Rails.** The camera moves along the loop, driven by the edge buttons. At a
  fork it follows the main stream by default.
- **Call drag.** A call pulls the camera toward the call point at a slow,
  steady pace. This is how the child looks off the loop; there is no
  joystick. When and how the camera returns to the rails is a tuning value.
- **Automatic framing.** The child never controls the zoom. The camera's place
  decides the zoom, and sometimes the position. **Framing zones** are a level
  component: when the camera reaches one, it gently moves and zooms to that
  zone's framing. Leaving a framing zone through the edge buttons takes a
  slightly longer push than a normal move.
- **Idle camera.** After 45 s with no input, the camera glides to the train
  slime nearest the middle of the view and follows it. If that slime fuses, it
  follows the fused slime; if it splits, one of the pieces. The cue, starting
  10 s before, is a slow zoom-out. Any touch takes back control and also does
  its normal job.
- Screensaver mode and the idle camera are about 10–20% more zoomed out than
  normal play. (proposed: screensaver mode starts on the idle camera straight
  away.)

### 5.7 Session, bedtime and screensaver mode

```
first launch → parent setup → screensaver mode
screensaver mode --first tap--> session (15 min)
session --last minute--> wind-down --15 min reached--> bedtime
bedtime --parent code, or 10 min--> sunrise → screensaver mode
```

- **Screensaver mode:** the world runs with no session. Opening the app always
  lands here (after the one-time setup on first launch). The phone's usual
  screen timeout applies.
- **Session:** starts at the **first tap** in screensaver mode, which also acts
  as a normal tap. It lasts a fixed **15 minutes** of **real time**: time in
  the background or during a phone call is used up. The screen stays on during
  a session.
- **Wind-down:** in the last minute the light drifts toward dusk and slimes hop
  more slowly. No text, no countdown.
- **Bedtime:** slimes fall asleep where they are, the game saves, and taps no
  longer call. The phone's usual screen timeout applies again (proposed).
- **Sunrise** comes when the parent enters the code (wake early) or **10 real
  minutes** after bedtime began. The slimes wake and screensaver mode begins.
  The long delay is on purpose: it nudges the child to put the phone down.
- The session and cooldown timers survive the app being killed or the phone
  restarting: they are stored with both the wall clock and the monotonic
  clock. Changing the phone's clock can defeat them, which is accepted.

### 5.8 Parent gate and parent access

- The **parent code** has 6 digits.
- **First launch:** a one-time setup screen appears before anything else. The
  parent types the code twice. The screen explains screen pinning, and says
  plainly that on a phone with no screen lock, a forgotten code can only be
  reset by clearing the app's data, which erases all progress.
- **Parent access:** a tap at the top of the screen reveals the parent
  buttons: **wake early** (ends bedtime or the cooldown), **leave** (ends
  screen pinning and lets the parent leave the app), and **settings**
  (change the code, delete one level's save). Every button asks for the code
  before doing anything.
- **Forgotten code:** "forgot the code?" on the code prompt hands off to the
  phone's own screen lock through Android's system prompt (PIN, pattern or
  fingerprint). If it succeeds, the parent sets a new code.
- How the buttons and the code prompt look is interface design.
- The full rules are in `access-model.md`.

### 5.9 Screen pinning

- At setup the app asks Android to pin the screen, so the child can't leave
  with the home or back buttons. Leaving goes through the parent code.
- This is **best effort**, a courtesy to parents and not a guarantee. There is
  no device-owner kiosk mode (it would need the phone wiped and provisioned),
  and a child who knows the phone's PIN can reset the parent code.

### 5.10 Persistence

- The save holds each slime's species, size, state and position, and the
  state of every interactive object and gate.
- **One save file per level.** A parent can delete one level's save from the
  settings.
- Saved every 15 s and whenever the app goes to the background.
- On load, a slime saved in mid-air is put on the ground or back at the start
  of its jump, whichever is easier to build; if neither works, it is lost.
- **Saves are never wiped.** A released level isn't meant to change. If one
  does, the change is minor and ships with a save migration; slimes it
  displaces are treated as lost. (proposed: the save records the level's
  version, and slimes, objects and gates have stable IDs.)
- (proposed) Saves are written atomically, and the previous one is kept as a
  backup that is used if the latest can't be read.

### 5.11 Level rules

Every level, the test level included, follows these rules.

1. The loop can be travelled with no input at all.
2. A slime of any size can travel the loop; sizes may take different forks.
3. No dead ends: every branch joins the loop again.
4. The start of the loop carries a split zone.
5. A dip in the loop may nudge same-species slimes into fusing.
6. A signpost stands at every fork.
7. From anywhere a free slime can reach, gravity leads back toward the loop.
8. Every exploration branch includes its own route back to the loop.
9. Hints that there is something to explore are visible from the loop.
10. Tilt is only for exploration or fun, never needed to make progress.
11. The first section has 3 native species; each later section adds one.
12. A frontier gate opens through the switch-plus-basket set.
13. Each section has its own return route to the start from its unopened
    frontier gate.
14. At most 200 slimes per level, counted in base slimes. Where many pile up
    on one screen, they should be mostly still (for example, filling a
    basket).
15. Sleepers never sit on the loop.
16. The first sleeper is close to the first awake slime.
17. Wherever a wider view is needed, a framing zone sets the zoom and position.
18. A released level isn't meant to change; any update is minor, ships with a
    save migration, and keeps stable IDs.

### 5.12 Levels and the test level

- Each level has its own folder in the spec, `levels/<id>/`, holding its
  objectives, its loop description and its content. How a level goes from
  text to a Godot scene is still to be worked out (see Known gaps).
- **The test level** (`levels/test/`) is a compact level designed to exercise
  the v1 mechanics. It is the testing ground for implementation and the base
  for end-to-end tests. It uses placeholder art and is not shipped
  (proposed).
- **The real first level** (`levels/01/`) is designed later, once enough is
  built and checked. v1 ships that level, not the test level.

## 6. Architecture decisions and why

- **Godot 4.** Open source, strong 2D, exports to Android and to a Linux
  desktop build from the same project. Unity and Unreal were ruled out by the
  owner.
- **No custom level editor.** Levels are Godot scenes built in Godot's editor,
  with curved terrain from paths and collision polygons. Every interactive
  element is a reusable, programmed component configured by properties, and
  **there are no per-level scripts**. This keeps extra levels (possibly paid)
  as content rather than code.
- **Soft slimes** (proposed): each slime is a ring of points joined by
  springs, in our own code, drawn with a shader that blends nearby shapes into
  smooth blobs. Fusion and splitting are operations on rings. No engine gives
  this out of the box.
- **Physics only near the screen.** Up to 200 slimes on a mid-range phone
  rules out simulating every slime all the time. Off-screen slimes move along
  authored paths at a deterministic pace; that is also what makes off-screen
  behaviour predictable and testable.
- **Authored routes back, no pathfinding.** Every exploration branch includes
  its route back as level data (proposed: a path drawn in the editor), so a
  heading-back slime never needs general pathfinding.
- **The loop is a route, not physics.** The train follows a drawn route so
  that it always flows with no input, whatever physics does; only free slimes
  are driven by physics alone.
- **Rails camera with automatic framing.** A 3-year-old can press two
  buttons but can't manage a free camera or zoom.
- **Best-effort lock, fully offline.** Screen pinning, our own code, and
  stored clocks cover the real risk (a small child wandering out of the app)
  without asking the parent to provision the phone. Code recovery uses the
  phone's own screen lock, so no server, website or account exists.
  (proposed: no analytics, no ads, no network permission.)
- **One save per level, never wiped.** A parent can reset one level without
  losing others; level updates migrate saves rather than breaking them.
- **Testability** (proposed): all gameplay randomness comes from one seeded
  generator so test runs repeat exactly. A test mode, only in the Linux build
  and debug Android builds, loads fixture saves, speeds up or skips time, and
  injects taps and tilt from a script.

This is a new project; there is no existing code base to fit into.

## 7. Target phones and test environments

- **Reference phone:** Samsung Galaxy S20 FE. **Floor:** a budget phone of the
  Galaxy A14 class. If the floor phone can't hold 200 slimes, the floor rises;
  the 200 cap stays.
- Test environments (proposed):

| Environment | Used for | Not used for |
|---|---|---|
| Linux desktop build | gameplay, level logic, saves, automated end-to-end tests | anything Android-specific |
| Android emulator | the Android lifecycle, screen pinning, the parent flows, save and restore, rough tilt | performance, touch and tilt feel |
| Real phones (reference and floor) | performance, touch and tilt feel, playtests with children | fast iteration |
| Google Play pre-launch report (later) | smoke tests on many real phones | detailed performance work |

## 8. Tuning values

Starting values, to be tuned in prototypes and playtests.

| Value | Start at |
|---|---|
| Fusion contact time | 3 s; a hop resets it |
| Unsure phase | up to about 15 s |
| Left alone | 10 s off screen |
| Lost | 1 min after left alone |
| Call radius | about half the screen width (proposed) |
| Call cap | about 8 s |
| Train hop interval | about 1.5–3 s, random per slime |
| Hop rate answering a call | a bit faster than on the train |
| Idle camera takes over | 45 s without input; cue 10 s before |
| Screensaver and idle zoom | 10–20% wider than normal play |
| Leaving a framing zone | a bit longer than a normal move |
| Camera drag toward a call | slow and steady; return behaviour to try |
| Tilt | ±45° cap, about 10° dead zone |
| Session | 15 min, of which the last minute is the wind-down |
| Cooldown after bedtime | 10 min |
| Autosave | every 15 s |
| First-play hint | after about 10 s with no call |
| Maximum size | 3 |
| Slimes per level | 200 at most, in base slimes |

## 9. Definition of done

v1 is done when every criterion below holds on the release build, on the
reference phone unless stated otherwise, and the real first level (designed
later) passes the level-rules check.

**World and slimes**

1. With no input at all, from a fresh save, the train keeps travelling the
   whole current loop for a full session, and no slime ever becomes lost.
2. A sleeper wakes only when touched, on screen, by a free slime; a train
   slime touching it doesn't wake it.
3. A tap on open ground makes every awake slime within the call radius turn
   toward it and hop toward the point; each gives up after about 8 s if it
   can't reach it; a new tap replaces the point for every answering slime.
4. After its call, a free slime lingers up to about 15 s, then heads back by
   its area's route back and rejoins the train on reaching the loop.
5. A free slime off screen for 10 s is left alone; if it isn't back on the
   loop 1 min later, it reappears at the start of the loop. A free slime kept
   on screen is never lost.
6. Two same-species slimes in contact for 3 s fuse into one whose size is the
   sum; a hop breaking contact resets the count; slimes of different species,
   or whose sizes sum above 3, never fuse.
7. Every slime entering the split zone at the start of the loop leaves it as
   base slimes.
8. Only free slimes respond to tilt, within ±45° and outside a dead zone of
   about 10°.

**Objects**

9. Flipping the frontier switch sends the flow into the basket; its outlines
   fill by weight; when full it plays the reward animation, opens the gate
   and releases its slimes; the loop then extends into the new section and
   the old return route is no longer used.
10. A basket filled while off screen plays its reward and opens the gate
    when it comes into view (proposed behaviour).
11. Flipping the switch back before the basket is full stops the filling
    (with the proposed release of the slimes inside).
12. Opening all gates of the level never requires tilt.

**Controls and camera**

13. Every tap produces a visible ripple, including taps that do nothing else.
14. On a fresh install, if the child hasn't called within about 10 s, a
    wordless pulsing mark appears near the first sleeper; it never appears
    again once the first call is made.
15. While one finger is down, a second touch does nothing.
16. The edge buttons move the camera along the loop; the child can never
    change the zoom; entering a framing zone reframes the camera smoothly.
17. After 45 s with no input the idle camera follows a train slime, with the
    zoom-out cue starting 10 s earlier; any touch takes back control and does
    its normal job.

**Session and parents**

18. A session starts at the first tap in screensaver mode and ends 15 real
    minutes later, including time spent in the background, after a killed
    app, and after a phone restart.
19. The last minute shows the dusk wind-down; at bedtime the slimes fall
    asleep, the game saves, and taps no longer call.
20. Sunrise comes 10 real minutes after bedtime began, or immediately after
    the correct parent code on "wake early"; screensaver mode follows.
21. On first launch the parent setup appears before anything else and
    requires the 6-digit code twice; it is never shown again.
22. Every parent action (wake early, leave, change the code, delete a level's
    save) is refused without the correct code.
23. With screen pinning accepted, the home and back buttons don't take the
    child out of the app; "leave" with the correct code does.
24. "Forgot the code?" lets the parent set a new code after passing the
    phone's own screen lock.
25. The app makes no network connection (proposed).

**Persistence**

26. Killing the app at any moment and reopening it restores slimes, objects
    and gates as of the last save (at most about 15 s old), with no slime
    left in mid-air.
27. Deleting one level's save resets that level only.

**Performance and quality**

28. The performance targets hold on the reference and floor phones (targets
    still to confirm, see Known gaps), including the worst case of 200
    slimes on one screen.
29. The automated end-to-end suite on the test level passes on the Linux
    build.
30. A playtest with the primary persona shows her finding the call on her
    own, with no adult explaining it (goal P1.G3).

## 10. Deferred

Everything in "Not in v1" (section 3) is deliberately out of this version and
tracked in the project's version plan.

## 11. Known gaps

Still undecided. Each has a proposed default that stands until decided.

1. **The real first level's design:** its layout, pacing, section sizes,
   return routes and theme details. It will be designed in its own session,
   in `levels/01/`, once the test level has been built and checked.
2. **How each section's return route to the start works** (a slide, wind,
   a conveyor…). Decided with the first level's design. The test level uses
   underground slides as placeholders.
3. **How level design is run:** exactly what `levels/<id>/` holds, and how a
   level goes from its text description to a Godot scene.
4. **Completing a level:** what happens when the last gate opens. Proposed:
   nothing ends; the loop is complete and the world stays open, with a
   one-time celebration. Moving on to another level waits for paid levels.
5. **Camera rails where the loop doubles back** (in side view, the return
   route runs back under the outgoing route). Proposed: the rails follow only
   the outgoing part of the loop; when the idle camera's slime enters the
   return route, the camera switches to the nearest train slime on the rails.
6. **Screen orientation.** Proposed: landscape, locked; side view like
   Cocoreccho!.
7. **A wrong parent code.** Proposed: the entry shakes and clears; unlimited
   tries, with a 30 s wait after 5 wrong tries in a row; the code prompt
   closes after about 15 s with no input.
8. **Colour-blind players:** species differ by colour only in v1. Proposed:
   each species also gets its own shape detail (eyes or a marking), so colour
   is never the only cue.
9. **Performance targets.** Proposed: 60 frames per second on the reference
   phone; at least 30 on the floor phone in the worst case of 200 slimes on
   one screen.
10. **If the parent declines screen pinning at setup.** Proposed: the game
    still works, the parent buttons still ask for the code, and the setup
    screen explains the difference.
11. **Technical risks to check with prototypes before building for real:**
    200 slimes on the floor phone (many on one screen), tilt input, running
    end-to-end tests on Linux without a screen, and the vector rendering
    approach (Godot turns SVGs into images at import, so crisp curves need
    polygons and lines or a plugin). A floor phone has to be bought for this.
    Android audio latency matters only from the version that adds sound.
12. **When the app asks for screen pinning.** Android shows its own
    confirmation every time an app asks, and it can't be skipped; pinning ends
    when the phone restarts; and anyone can unpin with a gesture unless the
    phone's "Ask for PIN before unpinning" setting is on. Proposed: ask each
    time the app opens (normally the parent opens it and hands the phone
    over), and have setup recommend turning that setting on.
13. **Size forks:** how the drawn loop sends slimes down a branch by size.
    Proposed: a route property "size N or more takes this branch", with the
    terrain drawn to match.
14. **Where a basket releases its slimes,** after firing and after opting
    out. Proposed: one outlet per basket, onto the onward route just before
    the return route's entrance.
15. **The frontier set once its gate is open.** Proposed: the switch locks to
    "onward" and stops responding to taps; the basket shows as done.
16. **Zoom stacking and a minimum zoom.** Proposed: the screensaver and idle
    zoom-out applies on top of a framing zone's zoom, and a minimum zoom (a
    tuning value) keeps slimes large enough to tap and see.
17. **Items tagged (proposed) in this document** are the spec writer's
    defaults, not yet confirmed by the owner. The main ones: train slimes
    answering calls; the call radius; the top-of-screen zone not calling;
    generous hit areas; the switch staying flipped; the basket's reward
    waiting until it's in view and its slimes being released on opting out;
    plain signposts being in v1; the usual screen timeout during bedtime; the
    test level not shipping; stable IDs and atomic saves; the test mode; no
    network permission.
