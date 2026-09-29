# Surface inventory

Status: working input for the first design pass. This is **not a design**. It
lists every place the v1 master spec implies the interface has to exist, what
the spec already fixes about it, and which persona goals and access-model
operations it serves. Layout, form, tokens and screen structure are all still
open.

Sources, and nothing else:

- `specs/versions/v1/master-spec.md` (the v1 master spec)
- `specs/versions/v1/access-model.md` (who may do what)
- `specs/personas.md` (personas P1 to P4 and their goals)
- `specs/decisions.md` and `specs/tuning.md`, for the spec's answers to the
  interface questions and the build's findings, as of 2026-09-29 (all
  already carried into the master spec)

Goal IDs are the personas document's: P1 is the newcomer (3 years old, the
primary persona), P2 the watching sibling (2), P3 the early player (about 4),
P4 the parent. Operations are the access model's, written
`resource: operation`.

"Fixed by the spec" means settled behaviour the design has to honour.
"States implied" lists the states the spec makes this surface go through. It
isn't a design either, and the set may grow.

## 1. The world (child-facing)

### 1.1 Play view during a session

The level itself, side view, landscape locked, with the train running along
the loop.

- **Fixed by the spec:** no text, no score, no failure state for the child;
  the world keeps running with no input; the child never controls zoom;
  the camera runs on rails with automatic framing and framing zones; the call
  drags the camera slowly toward the call point, except when the call point
  is already inside a box centred on the screen, 20% of its width by 20% of
  its height (measured on the screen): then the camera stays, and such a
  call during a drag stops the drag where it is.
- **Serves:** P1.G1, P1.G2, P1.G4, P2.G1, P3.G1, P3.G2.
- **Operations:** World: `call`, `operate-object`, `move-camera`, `tilt`.
- **States implied:** normal play; camera dragged by a call; camera inside a
  framing zone; idle camera following a slime; wind-down; parent surfaces
  open over a running world.

### 1.2 The tap answer: ripple and slimes turning

- **Fixed by the spec:** every tap gets a visible answer, a ripple where the
  finger touched, and slimes in range turn toward it. The spec says this holds
  for taps that do nothing else too (the top band, the edge strips), and for
  inert taps at bedtime. The one exception: a touch that starts while
  another finger is down gets nothing at all, not even a ripple, and stays
  ignored until it lifts.
- **Serves:** P1.G2, P1.G3, P2.G2.
- **Operations:** answers World: `call`, and every denied tap at bedtime.
- **States implied:** a tap that calls; a tap on an object; a tap on an edge
  strip; a tap on the parent zone; an inert tap at bedtime. (A second finger
  while the first is down has no state: it gets nothing.)

### 1.3 Tap zones

Four zones, checked in this order: the top of the screen (parent zone), the
left and right edge buttons, an interactive object, anywhere else (a call).

- **Fixed by the spec:** the order above; only the last zone calls; object
  hit areas are larger than the drawn object; the first touch wins; no hold,
  drag, pinch or multi-finger gesture (holding an edge button is the same
  press held longer). Each edge button is a strip over the screen's whole
  height, 10% of the screen's width from its edge, running from below the
  top band to the bottom edge; it takes the whole tap, so no object under it
  can be operated and no call is issued there. A sleeper or object near an
  edge has to be brought inward with the camera before it can be tapped.
  Only a tap that reaches the world (a call or an object) starts a session.
  The build's placeholder top band is 64 screen units (about 6.7 mm on the
  reference phone).
- **Serves:** P1.G2, P2.G2, P3.G1, P4.G4.
- **Operations:** Parent buttons: `reveal`; World: `move-camera`,
  `operate-object`, `call`.
- **States implied:** each zone active or inactive by session state (the edge
  buttons are gone at bedtime; the parent zone needs setup done).

### 1.4 Edge buttons

- **Fixed by the spec:** left and right; right always moves the camera
  forward along the loop and left backward, whatever the direction on screen;
  forward on a return route carries the camera round the turn and back toward
  the start; at a fork it follows the main stream; leaving a framing zone
  takes a slightly longer push (about 1 s of holding; a short press stays
  inside); hidden during bedtime, when a tap in a strip is an ordinary tap.
  A press moves the camera at least one fixed step, keeps moving at a
  steady pace while the finger stays down, and eases to a stop on release.
  The loop is circular for the camera: holding one button long enough goes
  all the way round, so neither button ever reaches an end. Each button is
  a whole-height strip, 10% of the screen's width (see 1.3). In screensaver
  mode a press moves the camera and doesn't start a session.
- **Serves:** P3.G2, P1.G1 (looking around), P2.G2 (safe to poke).
- **Operations:** World: `move-camera` (`not-bedtime`).
- **States implied:** default, pressed, held back by a framing zone, hidden
  (bedtime), shown again at sunrise; present in screensaver mode and under the
  idle camera.

### 1.5 Interactive objects

Switch, basket and gate (the frontier-gate set), plus signposts and the split
zone.

- **Fixed by the spec:** the switch sits at the fork before the frontier gate,
  sends the flow back to the start by default, flips on a tap, stays flipped;
  the basket shows the weight it still needs as empty slime outlines that fill
  by weight, plays a reward animation when full, fires its gate, then releases
  its slimes; flipping the switch back before it's full empties the basket;
  once the basket is full the switch stops answering taps, through the
  reward and after; after the gate opens, the switch and basket are inert
  for good; at bedtime a basket's releases pause, its slimes sleep in place
  in it, and a due or playing reward waits for sunrise; a gate may shut the
  old return route's entrance with a lid; signposts aren't interactive; the
  split zone splits every slime entering it.
- **Serves:** P3.G1, P1.G3 (discovering what touching does).
- **Operations:** World: `operate-object`.
- **States implied:** switch default, flipped, not answering (basket full),
  inert; basket empty, filling, full off screen (reward waiting until in
  view), reward, releasing, opting out, asleep at bedtime, inert; gate
  closed, opening, open; lid shut.

### 1.6 First-play hint

- **Fixed by the spec:** on the very first play, if the child hasn't called
  after about 10 s, a wordless pulsing mark appears near the first sleeper;
  never again once the first call is made. "The very first play" is the
  world showing on a fresh save of the level (after setup, or after that
  level's save was deleted). The 10 s count from the first frame the world
  shows, and again each time it shows while the hint is due. The first call
  marks it done in the level's save. Never shown during bedtime. The game
  wakes the very first slime itself, and the first sleeper sits close to
  it.
- **Serves:** P1.G3.
- **Operations:** none; `game` behaviour.
- **States implied:** waiting; shown; gone for good.

### 1.7 Idle camera and its cue

- **Fixed by the spec:** after 45 s with no input the camera glides to the
  train slime nearest the middle of the view and follows it; the cue, from
  10 s before, is a slow zoom-out; any touch takes back control and does its
  normal job; only touches count as input (tilting neither holds it off nor
  takes control back); the idle camera and screensaver mode share one
  zoom, 10 to 20% wider, which never zooms in (inside a wider framing zone
  the camera keeps that zoom); framing zones are ignored while following.
- **Serves:** P1.G1, P2.G1.
- **Operations:** World: `move-camera` (`game`).
- **States implied:** cue running; following; control taken back.

### 1.8 World moments

Waking a sleeper, fusion, splitting at the split zone, a lost or stuck slime
reappearing at the start of the loop, slimes restored from a save.

- **Fixed by the spec:** waking and fusion happen only on screen; fusion
  after 3 s of contact; splitting is instant; a lost slime is moved to the
  start of the loop; a stuck slime (two slimes that can't fuse, inside each
  other for about 2 s) is its own state with the same effect: the smaller
  one goes to the start of the loop.
- **Serves:** P1.G1, P1.G4, P3.G1.
- **Operations:** none; world rules.
- **States implied:** each moment's before, during and after. This is motion
  territory more than layout.

### 1.9 Basket reward and gate opening

- **Fixed by the spec:** the reward and the firing wait until the basket is in
  view, and until sunrise if bedtime comes first; the gate then opens for
  good and the loop extends into the new section. The build's reward lasts
  2 s.
- **Serves:** P3.G1.
- **Operations:** none directly; follows World: `operate-object`.
- **States implied:** reward; gate opening; new section reachable.

### 1.10 Level-completion celebration

- **Fixed by the spec:** when the last basket fires, a one-time celebration;
  nothing ends, the world stays open with the loop complete; reloading doesn't
  replay it (deleting the level's save lets it play again); never during
  bedtime; no text for the child. The build's celebration lasts 4 s.
- **Serves:** P3.G1, P1.G4.
- **Operations:** none; `game` behaviour.
- **States implied:** playing once; after (world complete).

## 2. Session states

### 2.1 Screensaver mode

- **Fixed by the spec:** the world runs with no session; opening the app lands
  here after the one-time setup, and on a later open only when no session or
  bedtime is running (otherwise it resumes, see 4.3); it starts on the idle
  camera straight away, at the shared wider zoom; the phone's usual screen
  timeout applies; the edge buttons work here and don't start a session.
- **Serves:** P1.G1, P2.G1.
- **Operations:** Session: `start` (`in-screensaver-mode`).
- **States implied:** after first-launch setup; after sunrise; on a later app
  open with no session or bedtime running (including a cooldown that ran out
  while the app was closed, with no sunrise replayed).

### 2.2 Session start

- **Fixed by the spec:** the first tap in screensaver mode that reaches the
  world (a call or an object; not the top band, not an edge strip) starts a
  15 min real-time session and also acts as a normal tap; the screen stays
  on during a session; tilt's neutral is how the phone was held at that
  moment, and is taken again when a session resumes on reopening.
- **Serves:** P1.G2, P4.G1.
- **Operations:** Session: `start`.
- **States implied:** a single transition; no visible start signal is
  required by the spec.

### 2.3 Wind-down

- **Fixed by the spec:** the last minute; the light drifts toward dusk and
  slimes hop more slowly; no text, no countdown. The build's dusk tint
  covers the world only, not the parent band and buttons.
- **Serves:** P4.G1.
- **Operations:** leads to Session: `end`.

### 2.4 Bedtime

- **Fixed by the spec:** slimes fall asleep where they are (slimes in a
  basket sleep in place in it); the game saves; taps no longer call but
  still show the ripple; the edge buttons are hidden and a tap in their
  strips is an ordinary tap; baskets pause, and no reward, gate opening or
  celebration plays; the phone's screen timeout applies again; the
  first-play hint isn't shown; wake early is available behind the code.
- **Serves:** P4.G1, P4.G4.
- **Operations:** Session: `end` (`game`), `wake-early` (`parent`);
  denied World: `call`, `operate-object`, `tilt`, `move-camera`.
- **States implied:** falling asleep; asleep; screen dimmed or off by the
  phone.

### 2.5 Sunrise

- **Fixed by the spec:** comes 10 real minutes after bedtime began, or on the
  correct code for wake early; slimes wake; screensaver mode begins; baskets
  resume, and a reward that waited plays when its basket is in view. If the
  cooldown ran out while the app was closed, the app opens in screensaver
  mode with no sunrise played (the build's fade lasts 3 s otherwise).
- **Serves:** P4.G1, P4.G4.
- **Operations:** Session: `sunrise` (`game`), `wake-early` (`parent`).
- **States implied:** by cooldown; by wake early; missed while closed.

## 3. Parent surfaces

### 3.1 Parent zone and parent buttons

- **Fixed by the spec:** a tap at the top of the screen reveals the parent
  buttons, doesn't call, and doesn't start a session; three buttons: wake early (shown only during
  bedtime), leave, settings; every button asks for the code before doing
  anything; revealing is harmless and allowed to the child; opening them
  pauses nothing.
- **Serves:** P4.G4, P4.G2, P2.G2.
- **Operations:** Parent buttons: `reveal` (`setup-done`), leading to
  Session: `wake-early`, App exit: `leave`, settings.
- **States implied:** hidden; revealed outside bedtime (two buttons);
  revealed at bedtime (three buttons); bedtime or sunrise arriving while
  revealed; dismissed (how is not specified).

### 3.2 Code prompt

- **Fixed by the spec:** 6 digits; raised by every parent button; a wrong code
  shakes and clears; tries unlimited, but 5 wrong in a row bring a 30 s wait;
  the count and the end of the wait are stored on disk and survive the
  prompt closing and the app being killed; one count for every parent
  button, reset by a correct code or a code reset, starting from 0 after a
  wait; closes after about 15 s with no input; offers "forgot the code?",
  which works during the wait; pauses nothing, and bedtime can arrive while
  it is open; stored never in plain text.
- **Serves:** P4.G2, P4.G4, P2.G2 (poking can't break anything).
- **Operations:** the step-up for every parent-only operation.
- **States implied:** empty; partly entered; wrong (shake and clear); waiting
  (30 s); closed by timeout; correct, handing on to its action; the session
  state changing underneath it.

### 3.3 Wake early

- **Fixed by the spec:** shown only during bedtime; after the code, sunrise
  comes immediately.
- **Serves:** P4.G4.
- **Operations:** Session: `wake-early` (`in-bedtime`).
- **States implied:** available; gone at sunrise.

### 3.4 Leave

- **Fixed by the spec:** after the code, ends screen pinning and closes the
  app, so the next open is a launch and asks for pinning again; the session
  keeps counting in real time afterward.
- **Serves:** P4.G4, P4.G2.
- **Operations:** App exit: `leave`.
- **States implied:** after the code; handing over to Android.

### 3.5 Settings

- **Fixed by the spec:** reached through the code; offers change the code and
  delete one level's save; closes by itself after a short time with no input
  (the spec sets no value: "short, to try"); parent authority ends when it
  closes; the only list is the level saves (one level in v1).
- **Serves:** P4.G4, P4.G3.
- **Operations:** Parent code: `change`; Level save: `delete`.
- **States implied:** open; closing by timeout; session state changing
  underneath it.

### 3.6 Change the code

- **Fixed by the spec:** the new code is entered twice; it takes effect
  immediately and the old one stops working.
- **Serves:** P4.G4.
- **Operations:** Parent code: `change`.
- **States implied:** first entry; second entry; mismatch; done.

### 3.7 Delete a level's save

- **Fixed by the spec:** a second confirmation after the code; resets that
  level only, removing its backup too; if that level is running, it reloads
  fresh at once, as on a fresh install (the first-play hint is due again,
  the celebration can play again); the session or bedtime and their timers
  carry on and are written into the fresh save, so deleting can't dodge
  bedtime.
- **Serves:** P4.G4.
- **Operations:** Level save: `delete`.
- **States implied:** choosing the level; confirming; done, with the world
  behind settings already reloaded.

### 3.8 Forgotten code

- **Fixed by the spec:** "forgot the code?" on the code prompt hands off to
  Android's system prompt for the phone's own screen lock; on success the
  parent types a new code twice, it replaces the old one at once, and the
  parent is back at the code prompt for the action they started, with the
  wrong tries and any wait cleared; cancelling or failing Android's prompt
  returns to the code prompt with nothing changed and no wrong try counted;
  with no screen lock, "forgot the code?" explains that clearing the app's
  data in Android settings is the only way and erases all progress, and
  nothing else happens.
- **Serves:** P4.G4, P4.G3.
- **Operations:** Parent code: `reset` (`passes-phone-lock`).
- **States implied:** Android's prompt shown; passed; cancelled or failed;
  new code, first and second entry, mismatch; back at the code prompt; no
  screen lock on the phone.

## 4. Setup and platform

### 4.1 First-launch setup

- **Fixed by the spec:** appears before anything else, once; the parent types
  the code twice; it explains screen pinning and recommends "Ask for PIN
  before unpinning"; it says plainly that on a phone with no screen lock, a
  forgotten code can only be reset by clearing the app's data, which erases
  all progress; it explains what changes if pinning is declined, including
  that the back gesture then leaves the app; never shown again. Whoever
  holds the phone creates the code. The parent-facing text is in the
  phone's language when v1 has it (English and French), English otherwise.
- **Serves:** P4.G3, P4.G2.
- **Operations:** Parent code: `create` (`first-launch`).
- **States implied:** first entry; second entry; mismatch; explanations;
  done, handing on to screensaver mode; interrupted and resumed (the
  `first-launch` condition holds until a code exists).

### 4.2 Screen pinning request

- **Fixed by the spec:** the app asks Android to pin the screen on each
  launch: on first launch right after setup is completed, on later launches
  as soon as the app opens, before the world takes a tap; coming back from
  the background doesn't ask; Android shows its own confirmation, which
  can't be skipped; pinning ends when the phone restarts; if declined, the
  game still works, every parent button still asks for the code, and the
  back gesture leaves the app as Android normally does (the session keeps
  counting, reopening resumes).
- **Serves:** P4.G2.
- **Operations:** App exit: `pin` (`app-opening`).
- **States implied:** Android's confirmation; accepted; declined; escaped.

### 4.3 App opening and restore

- **Fixed by the spec:** the save restores slimes, objects and gates as of the
  last save; no slime is left in mid-air; a backup save is used if the latest
  can't be read, and if neither can be read that level starts fresh; timers
  survive kills and restarts; the app lands in the state the stored timers
  give: a running session (wind-down included), bedtime with the rest of its
  cooldown, or screensaver mode if none is running (sunrise isn't replayed).
- **Serves:** P1.G4, P4.G1.
- **Operations:** Level save: `load` (`game`).
- **States implied:** loading; restored into screensaver mode, a session
  (wind-down included) or bedtime; restored from the backup; started fresh
  because neither could be read.

### 4.4 Android surfaces the design relies on

Not ours to design, but the flows pass through them: Android's pinning
confirmation, its unpin gesture and toast, the screen-lock system prompt,
the "Ask for PIN before unpinning" setting, and the phone's screen timeout.

## 5. Denial behaviours, by surface

From the access model's denial table.

| Denial | Surface it lands on | What the spec fixes |
|---|---|---|
| A tap at bedtime (`call`, `operate-object`, `tilt`) | 1.2 tap answer, 2.4 bedtime | Visible but inert: ripple shows, slimes stay asleep, no text, no sound |
| `move-camera` at bedtime | 1.4 edge buttons | Buttons hidden; a tap in their strips is an ordinary (inert) tap |
| Any parent-only operation by the child | 3.1 parent buttons, 3.2 code prompt | Button shown; pressing it raises the prompt; nothing happens without the code |
| A wrong code | 3.2 code prompt | Shake and clear; 30 s wait after 5 in a row; closes after about 15 s idle |
| `wake-early` outside bedtime | 3.1 parent buttons | Button not shown |
| Home and back while pinned | 4.2 pinning | Android ignores them |
| Pinning declined | 4.1 setup, 4.2 pinning | Game works; buttons still ask for the code; setup explains the difference |
| The child leaves anyway (back, without pinning) | 4.3 app opening | Nothing blocked; the session keeps counting; reopening resumes |
| A second finger while one is down | 1.2 tap answer, 1.3 tap zones | Ignored entirely: no ripple, and it stays ignored until it lifts |

## 6. Coverage check

**Every persona goal has at least one surface.**

| Goal | Surfaces |
|---|---|
| P1.G1 watch something pleasant | 1.1, 1.7, 1.8, 2.1 |
| P1.G2 touch and see an answer at once | 1.1, 1.2, 1.3, 2.2 |
| P1.G3 find out alone what touching does | 1.2, 1.5, 1.6 |
| P1.G4 never fail, never stuck | 1.1, 1.8, 1.10, 4.3 |
| P2.G1 watch | 1.1, 1.7, 2.1 |
| P2.G2 poke safely | 1.2, 1.3, 1.4, 3.1, 3.2 |
| P3.G1 play on purpose | 1.1, 1.5, 1.9, 1.10 |
| P3.G2 explore off the loop | 1.1, 1.4 |
| P4.G1 calm activity that ends on its own | 2.2, 2.3, 2.4, 2.5 |
| P4.G2 child can't leave, change or buy | 3.1, 3.2, 3.4, 4.1, 4.2 |
| P4.G3 set up once, easily | 3.5, 3.8, 4.1 |
| P4.G4 take the phone back or give more time | 3.1 to 3.8 |

**Every access-model operation is placed.** The ones with no interface of
their own: World: `tilt` (no on-screen control; only free slimes react),
Session: `end` and `sunrise` (game timers, shown through 2.3 to 2.5), Level
save: `write` and `load` (autosave and restore, shown only through 4.3).

## 7. Not surfaces in v1

- **Test mode** (Linux build and debug Android builds only): not in the
  release build; no user-facing design.
- **Sound** of any kind (v3), **purchases** and paid levels (later), turning
  the code off (v4), large signposts that choose a branch (v2), a freeform
  camera (later).
