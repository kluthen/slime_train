# Slime Train v1 (full MVP) — Master spec

Status: consolidated early, at the user's request. Everything here is
settled except the gaps listed in "Known gaps". v1 is the test level only;
the real first level is v2 (D134). v1 is **the full MVP**: all the bare
mechanics are validated, the gameplay loop is there, and it can be tried;
it is never published to a store (D135). The "v1" name stays in folders
and IDs. Companions: `access-model.md` (who may do what) and
`../../personas.md` (who the game is for). The test level used to build and
check v1 is in `../../levels/test/README.md`.

The defaults for the interaction details raised by the first UX review, and
the points the build raised while building, were approved by the user on
2026-09-29, as were the points chunk 16 added (the stalled train slime and
its safety net, 5.2 and Definition of done 1; where a return route meets
the start, now level rule 22 in 5.11), and the details chunk 23's build
chose (23A–23D). The readings chunk 23E took where the spec was silent
(a sleeper's tap margin, where a hit area's floor sits, overlapping hit
areas, which views level rule 21 checks) are tagged (proposed) until the
user approves them, as are the basket's quota pies and its always
emptying once fired, from the user's second round of playtest reports
(5.4, D128). Definition of done 24's line on the time left now matches
5.8 (never on the parent buttons): a wording fix, not a behaviour change
(D130). The save format may change without a migration until the first
store release (5.10, the user's, D149); how a build sets aside a save it
can't use is tagged (proposed). Moves to the loop start go one at a time
to a random free spot, and a parked train slime's stall clock is paused
(5.2, the user's, D150; its details proposed). Every wake of a resting
pile is local: only the slimes reached wake, never the whole pile (5.3,
D156). Definition of done 30 and section 7 carry the two stress targets,
the abuse case's an abuse target of 15 fps, not 30 (D153, D154; how they
are measured proposed). A frame-rate experiment run from 2026-09-30 to 2026-10-02
was withdrawn; only the points above came back from it (D155). Of the
two fixes the user made mandatory before v1 closes (D159), the first is
done: the cause of slimes of different species ending up inside each
other is fixed, the stuck net kept as a backstop (5.2, Known gap 6
closed). The second, the **geyser** (a level object since D160), no
longer is: it comes
**after v1**, with the review of the test level's start (the user's,
D161; section 3, Not in v1). The train's jam off the start is the climb,
fixed by the hold on a climb and the relay (5.2, proposed; chunk 24g,
the train's climb); the dip nudge is unchanged (D160). The start's
crowding is not a v1 blocker (the user's, D160; Known gap 9), and
Definition of done 30 is judged with it set aside (the user's reading,
D161; wording proposed). Test runs repeat exactly except in a run that
asks for normal play's crowd detail, which follows the device's load
(6, Testability; proposed, D162), and only on one platform: the phone and
the desktop give different hashes (6, Testability; D163). A level update
keeps a displaced sleeper asleep at its own or a free sleeper spot, so
only awake slimes, and a sleeper with no spot left, are lost (5.10, the
user's, D163). An overloaded scene plays in slow motion at worst, at most
2 ticks a frame (6, the user's, D163); the phone's frame budget is a
headroom target, recorded, not a Definition of done item (6, D163). The
reference phone meets Definition of done 30 on the three fixtures
measured so far (7, D163).

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
| P2.G2 Poke the screen without breaking anything | only the first finger counts; every parent button asks for the code | partially: while his sister's finger is down, his poke does nothing, not even a ripple. Two calls at once are for later. |
| P3.G1 Play on purpose: call, fuse, fill a basket, open the next section | sleepers, fusion, the switch-plus-basket gate set, four sections | fully |
| P3.G2 Explore off the loop to find more slimes | exploration branches whose hints are visible from the loop; the call drags the camera | fully |
| P4.G1 A calm activity that ends on its own | 15 min sessions, a gentle bedtime, a 10 min cooldown | fully |
| P4.G2 The child can't leave, change or buy anything | screen pinning plus the parent code; no purchases inside v1 | partially: best effort by design (see 5.9) |
| P4.G3 Set it up once, easily | one-time setup at first launch | fully |
| P4.G4 Take the phone back or give more time at will | parent buttons: wake early, leave, settings; the time left, shown behind the code | fully |

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

- The test level only (3 sections, 5 species, told apart by colour), played
  end to end on the phones. Placeholder art; the intended theme is close to
  Cocoreccho!: black "stone" and black "plants" form the ground.
- Slimes: the train, sleepers, calls, free slimes and their phases, hopping,
  fusion up to size 3, the split zone at the start of the loop, left alone and
  lost.
- Objects: the frontier-gate set (switch, basket, gate), the split zone at
  the start of the loop, and plain signposts at forks.
- Controls: tap-to-call, tilt for free slimes, edge buttons moving the camera,
  a tap on the parent zone (the top of the screen) for parent access.
- Camera: rails along the loop, the call dragging the camera, the idle camera,
  automatic framing and framing zones.
- Session and parents: screensaver mode, 15 min real-time sessions, bedtime,
  a 10 min cooldown, sunrise, the 6-digit parent code with setup and
  recovery, screen pinning, and the time left shown to the parent behind the
  code. Parent-facing text in English and French.
- Persistence: one save per level, autosave, deleting a level's save.
- The test level plus a test mode for end-to-end tests; the release build
  leaves both out. v1 is never published (D135).
- Platform: Godot 4, Android; a Linux desktop build for development and tests.
  No purchases inside the app. The price (about $3–5) is for the first
  store release, probably v4, not v1 (D135, D137).

### Not in v1

| Item | Where it goes |
|---|---|
| The real first level, and more levels | v2 |
| Music | v2 |
| Sound effects, species voices | v2 candidates |
| Proper graphics | v3 |
| Every other interactive object: bending pathways, other split zones, tilt objects, reveal zones, filters (forks sorting slimes by species or by size), switches and baskets outside the frontier set | v2 |
| Large signposts that let the child choose which branch the camera follows | v2 |
| The geyser (a level object that launches the train slimes reaching it and spreads their landings along the loop; `../../interactive-objects.md`) and the review of the test level's start, where slimes coming home crowd | after v1, first, with v2's level work (the user's, D161) |
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
| stalled | a train slime that has made no progress along the loop for 1 min, or left the level; moved to the start of the loop |
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
- The **return route** is part of the loop. It has its own camera rail, and
  it may carry exploration opportunities.
- **Opening a gate** extends the loop into the new section. Only the part
  that led back to the start is replaced: the old return route stays in the
  world (it isn't removed) but is no longer used. The gate may shut the old
  route's entrance with a lid; level design then makes sure that exploration
  opportunities on that route stay reachable another way, so they never
  become unreachable. Gates stay open for good.
- **Completing the level:** when the last basket fires, nothing ends. The
  loop is complete and the world stays open, with a one-time celebration
  (input stays live, the camera stays where it is), after which a small
  lasting mark at the start of the loop shows the level is complete.
  During the burst, every awake slime on screen does a double hop. The
  mark appears once the celebration's burst ends.
  Moving on to another level waits for paid levels (a later version).
- The **start of the loop** carries a split zone.

### 5.2 Slimes

**States**

| State | Behaviour |
|---|---|
| sleeper | Asleep and still. Never sits on the loop. Wakes only when a free slime touches it on screen. The game wakes the very first slime itself. |
| train slime | Awake, following the loop. Ignores tilt. |
| free slime | Awake, away from the loop after answering a call. Driven by physics alone and feels tilt. |
| bedtime-asleep | Asleep because the session ended. Not a sleeper: the game wakes it at sunrise and play carries on. |
| in a basket | Caught by a basket. Doesn't hop, isn't part of the train and doesn't answer calls; it settles in the pile until the basket releases it, then rides the train again. |

**The call and free slimes**

- A tap on open ground is a **call**. Every awake slime within the call radius
  (about half the screen width) answers it, train slimes included, and
  becomes free. This is needed because at the start the only awake slime is
  on the loop.
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
- **Stuck:** two slimes that can't fuse whose centres stay almost on top of
  each other for about 2 s are stuck. Stuck is its own state, not "lost",
  with the same effect: the smaller one (only ever a train or free slime) is
  moved to the start of the loop and rides the train again, and each case
  is logged. Its cause (two rings deeper than a radius in each other
  drawn together by the contacts) is fixed; the net stays as a backstop
  (D159).
  "Can't fuse" means the two couldn't fuse right now: another species,
  sizes adding up to more than 3, or one of them not awake; so a
  same-species sleeper caught inside a train slime counts as stuck.
- **Stalled:** a train slime whose progress along the loop hasn't
  advanced 24 px in 60 s, on screen or off (counting only the time it is
  simulated: parked, its clock is paused, D150), or whose centre leaves the
  level's bounds, is stalled. It isn't "lost", but has the same effect:
  it is moved to the start of the loop and rides the train again, and each
  case is logged; the 60 s count starts again from the move. A slime asleep
  at bedtime is never counted as stalled. It is a safety net for play, not
  something that happens in normal play (Definition of done 1).
- A slime moved to the start of the loop, whether lost, stuck or
  stalled, lands at a random free spot on the loop's first stretch, inside
  the start's split zone, never onto another slime. The moves go one at a
  time, the next 0.5 to 2 s (random) after the last, first due first
  moved; a slime that recovers before its turn isn't moved (D150, the
  user's; the order, the stretch and what a waiting slime does are
  proposed; the numbers are in `tuning.md`).

**Waking**

- Tapping a sleeper is a call centred on it. A tap counts as on a
  sleeper within a small margin around its drawing (24 screen px), not
  the 20 × 20 mm floor of objects' hit areas: a sleeper is a slime, and
  such a floor would turn any tap within about 1 cm of it into a call
  centred on it (proposed).
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
| sleeper, bedtime-asleep, covered by other slimes, in a basket (any basket, filling or full) | no hopping |

Bigger slimes hop a little less often, but further and higher. In the last
minute of a session every slime hops more slowly.

A train slime standing between hops on a rise of the outgoing route keeps
its place instead of sliding back (the **hold on a climb**), and when a
train slime takes off, the one standing right behind it hops almost at
once (the **relay**), so a queue moves as a wave (proposed, D160; in v1,
chunk 24g, the train's climb, D161; the
numbers in `tuning.md`).

**Size, weight and species**

- **Size** is the number of base slimes a slime is made of. It is also its
  **weight**, which is what baskets count.
- The **maximum size is 3**. Two slimes whose sizes add up to more than 3
  just bump into each other.
- 6 **species** in v1: 3 native to the first section, and one more per later
  section. In v1 species differ by **colour only**. The 6 colours also differ
  clearly in lightness, which helps colour-blind players at no cost. A texture or styling per species, and other colour palettes, may
  come in later versions.

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
  route back is near, it is lost: it heads straight for
  the loop when the loop is near; otherwise it stays where it is until the
  lost timer (10 s, then 1 min) moves it to the start of the loop.
- **Fusion and waking happen only on screen.**
- **Baskets** keep counting weight off screen and can fill there.
- On screen too, a **resting pile** stops simulating, contacts included,
  until something disturbs it. This is the first fallback for performance
  (section 6). A pile rests once every slime in it has stayed within about a
  pixel of where it started counting; a big pile of base slimes in the open
  may take about a minute to rest, which the performance pass on the phones
  looks at again. Every wake is local (D156): it wakes only the resting
  slimes it reaches, never the rest of their pile, and never a sleeper. A
  release from a basket, a fast touch, a move to the loop start, a fusion,
  a split or a slime taken out of the level wakes the resting slimes
  touching the slime concerned; a call, those within its radius; a
  trapdoor, gate or lid opening or shutting, those within 80 px of it; a
  change of state, the slime itself; a tilt change, each resting slime.
- Sleepers don't simulate until something touches them, slimes in
  a full basket use a simplified state, and slimes on screen may use fewer
  points when zoomed out.

### 5.4 Interactive objects

Every object is a reusable component configured in the Godot editor, and its
state is saved. A tap on an object that answers taps operates it; a tap
anywhere else is a call. **Only something that answers a tap takes it:** a
tap on a basket, a gate, a signpost, or a switch that isn't answering (its
basket full, or inert for good) is a call. **Hit areas** are the drawn
object grown by 5 mm on every side, and never smaller than 20 × 20 mm, both
measured on the screen at the current zoom: zooming out shrinks the drawing,
never the hit area's floor. A hit area still smaller than the floor grows
about the object's centre (proposed). Where two hit areas overlap, the
object whose centre is nearest the tap takes it, among the objects
answering a tap right now: a filling basket's switch takes the tap even
where a basket's centre is nearer, since a basket never answers a tap
(proposed).

- **Switch.** Stands at the fork just before the frontier gate. By default it
  sends the flow back to the start (by the return route). Tapping it flips it
  so the flow goes into the basket. It stays flipped until tapped
  again.
- **Basket.** Shows the weight it still needs as empty slime outlines, which
  fill by weight (a size-3 slime fills three). When full, it plays a **reward
  animation**, fires its target (the gate), then releases its slimes. It can
  fill off screen. The reward and the firing wait until the basket
  is in view. *(Proposed, D128:)* a quota above 10 shows as **quota pies**
  instead of outlines: one pie per 10 of weight, the last holding the
  rest, each filling a slice per unit of weight, all of them within the
  basket's width and each at least 6 mm across on the screen at the
  basket's framing zoom. A fired basket always empties: none of the
  slimes it releases falls back into it, and it is empty within its quota
  × 0.3 s plus 10 s of firing.
- **Opting out.** Flipping the switch back before the basket is full stops the
  filling. The slimes inside go back to the loop and the
  basket empties. Once the basket is **full**, the switch no longer answers
  taps (a tap on it is a call), through the reward and after: there is no
  opting out of a full basket.
- **Baskets at bedtime.** At bedtime a basket's releases pause and resume at
  sunrise. The slimes in it sleep in place: they stay in the basket, shown
  asleep, and sunrise doesn't move them out. A reward that is due or playing
  waits for sunrise too, so no gate opens and no celebration plays during
  bedtime. A basket that reaches its quota during bedtime becomes full only
  at sunrise, and a celebration playing when bedtime begins pauses and
  plays the rest at sunrise.
- **Where a basket releases its slimes** (after firing, and after an opt-out)
  belongs to the basket's own design, which is still to be planned (see Known
  gaps).
- **Gate.** Opens when its basket fires, extends the loop, and stays open.
  From then on, its switch and basket are **inert for good**; they may be
  removed or turned into a landscape feature.
- **Split zone.** At the start of the loop; splits every slime that enters it
  into base slimes.
- **Signpost.** Stands at every fork of the loop and shows which
  way the loop goes. Not interactive.
- **No filters in v1.** The only fork in the loop is the frontier switch, so
  every size travels the loop the same way. Size matters through basket
  weight, and off the loop, where bigger free slimes jump higher.
- The switch plus basket is the **only** way to open a gate in v1.
- The components share one rule format ("when this basket is full,
  open that gate"). Its design is left to implementation.

### 5.5 Controls

The screen has four tap zones, checked in this order:

1. **The parent zone** (a band 7 mm high along the top of the screen, full
   width, unmarked): reveals the parent buttons. Doesn't call.
2. **The left and right edge buttons:** move the camera along the loop.
   Don't call. Each is a strip over the screen's whole height,
   10% of the screen's width from its edge, below the parent zone
   (which wins where they overlap). A tap anywhere in a strip is a press: it
   neither calls nor operates an object under it. While the edge buttons are
   hidden (bedtime), a tap there is an ordinary tap.
3. **An interactive object that answers a tap right now** (in v1, a switch
   whose basket is filling): operates it. Doesn't call.
4. **Anywhere else:** a call.

- **Every tap gets a visible answer:** a ripple where the finger touched, and
  slimes in range turn toward it.
- **First-play hint:** on the very first play, if the child hasn't called
  after about 10 s, a wordless pulsing mark appears near the first sleeper.
  "The very first play" is the world showing on a **fresh save of
  the level**: on first launch, screensaver mode right after setup, or after
  that level's save was deleted. The 10 s count from the **first frame the
  world shows**, not from the session start, and count again each time the
  world shows while the hint is still due. The first call marks the hint as
  done in the level's save; it never appears again for that save. It isn't
  shown during bedtime.
- **The first touch wins:** while one finger is down, other touches are
  ignored. A touch that starts while another finger is down gets
  **nothing at all, not even a ripple**, and stays ignored until it lifts,
  even if the first finger lifts before it. One exception, to check in a
  playtest: a touch on an edge strip held longer than about 5 s (a resting
  thumb) keeps moving the camera but stops counting as the first touch, so
  the next touch is handled as if no finger were down. Only a strip touch
  that was taken as the first touch can become a resting thumb.
- **Tilt:** the world stays fixed on the screen and gravity turns with the
  phone, up to ±45°, with a dead zone of about 10°. Neutral is how the phone
  was held when the session started, or when it resumed on
  reopening the app (see 5.7); lying flat counts as neutral. Only free
  slimes feel tilt. Tilt is never needed to make progress.
- No drag, pinch or multi-finger gesture is used in v1, and no hold gesture
  of its own. Holding an edge button only keeps the camera moving
  (see 5.6): it is the same button, pressed longer.

### 5.6 Camera

- **Landscape, locked.** The game is a side view.
- **Rails.** The camera moves along the loop, return routes included, driven
  by the edge buttons. The right button always moves it **forward** along the
  loop and the left one **backward**, whatever the direction on screen. On a
  return route, forward carries the camera round the turn at the frontier and
  back toward the start. At a fork it follows the main stream by default.
  A press moves the camera **at least one fixed step**; while the
  finger stays down it **keeps moving** at a steady pace, and it eases to a
  stop when the finger lifts.
- **Call drag.** A call pulls the camera toward the call point at a slow,
  steady pace. This is how the child looks off the loop; there is no
  joystick. When and how the camera returns to the rails is a tuning value.
  If the call point is already inside a box centred on the screen, 20% of
  its width by 20% of its height (measured on the screen, whatever the
  zoom), the call happens but the camera doesn't move; such a call during a
  drag stops the drag where it is. A point on the box's edge counts as
  inside, and such a call made while the camera is easing to a stop after
  an edge-button press lets the ease finish.
- **Automatic framing.** The child never controls the zoom. The camera's place
  decides the zoom, and sometimes the position. **Framing zones** are a level
  component: when the camera reaches one, it gently moves and zooms to that
  zone's framing. Leaving a framing zone through the edge buttons takes a
  slightly longer push than a normal move: holding the button a
  little longer, about 1 s; a short press stays inside the zone.
- **Idle camera.** After 45 s with no input, the camera glides to the train
  slime nearest the middle of the view and follows it. If that slime fuses, it
  follows the fused slime; if it splits, one of the pieces. The cue, starting
  10 s before, is a slow zoom-out. Any touch takes back control and also does
  its normal job. Only touches count as input: tilting the phone neither holds
  off the idle camera nor takes control back from it. At bedtime, when every
  slime is asleep, the idle camera follows no one.
- **Showing a gate open.** When a basket fires and its gate is off screen,
  the camera glides to the gate (about 1.5 s) to show it opening, and stays
  there under normal control. Input stays live: a touch takes control back
  and does its normal job. The glide goes straight, at an even
  pace, to the rail point nearest the gate's centre. A gate counts as in
  view only when its whole box is. No show starts while an edge button is
  held. A show replaces a call drag in progress, ends an idle or
  screensaver follow, and restarts the idle clock, so the idle camera can
  take over again 45 s later.
- Screensaver mode and the idle camera share **one zoom**, about 10–20% wider
  than normal play. It doesn't stack with anything, and it **never zooms
  in**: where the camera is already wider (inside a wide framing zone), it
  keeps that zoom. While either follows a
  slime, **framing zones are ignored**. When the child takes back control,
  framing resumes if the camera's centre is still inside a framing zone.
  Screensaver mode starts on the idle camera straight away.

### 5.7 Session, bedtime and screensaver mode

```
first launch → parent setup → screensaver mode
screensaver mode --first tap on the world--> session (15 min)
session --last minute--> wind-down --15 min reached--> bedtime
bedtime --parent code, or 10 min--> sunrise → screensaver mode
reopening the app → the state the stored timers give
```

- **Screensaver mode:** the world runs with no session. Opening
  the app lands here only when **no session or bedtime is running** (and after
  the one-time setup on first launch); otherwise it resumes where it was (see
  "Reopening the app" below). The phone's usual screen timeout applies.
- **Session:** starts at the **first tap** in screensaver mode, which also acts
  as a normal tap. It lasts a fixed **15 minutes** of **real time**: time in
  the background or during a phone call is used up. The screen stays on during
  a session. Only a tap that **reaches the world** starts it: on
  open ground (a call) or on an object (it operates the object). A tap on the
  parent zone or on an edge button doesn't start a session; the edge buttons
  move the camera in screensaver mode as they do in a session.
- **Wind-down:** in the last minute the light drifts toward dusk and slimes hop
  more slowly. No text, no countdown.
- **Bedtime:** slimes fall asleep where they are, the game saves, and taps no
  longer call. Baskets pause too (see 5.4). The edge buttons are hidden, and the phone's
  usual screen timeout applies again.
- **Sunrise** comes when the parent enters the code (wake early) or **10 real
  minutes** after bedtime began. The slimes wake and screensaver mode begins.
  The long delay is on purpose: it nudges the child to put the phone down.
- The session and cooldown timers survive the app being killed or the phone
  restarting: they are stored with both the wall clock and the monotonic
  clock. Changing the phone's clock can defeat them, which is accepted.
- **Reopening the app:** after a kill, a phone restart or a
  return from the background, the app lands in the state its stored timers
  give. A session still running resumes, wind-down included. Bedtime resumes
  with the rest of its cooldown, the slimes asleep. If the cooldown ran out
  while the app was closed, it lands in screensaver mode with the slimes
  awake, without replaying sunrise.

### 5.8 Parent gate and parent access

- The **parent code** has 6 digits. It is stored only on the phone, and
  **never in plain text**.
- **First launch:** a one-time setup appears before anything else, in four
  steps: welcome, the code (typed twice), what happens if it's forgotten, and
  screen pinning. It explains screen pinning, and says plainly that on a
  phone with no screen lock, a forgotten code can only be reset by clearing
  the app's data, which erases all progress. **The code is saved only when
  setup finishes;** an interruption before that restarts setup from the
  first step.
- **Parent access:** a tap on the parent zone reveals the parent
  buttons: **wake early** (ends bedtime or the cooldown), **leave** (ends
  screen pinning and lets the parent leave the app), and **settings**
  (change the code, delete one level's save). Every button asks for the code
  before doing anything. The buttons hide after 5 s with no press; another
  tap on the parent zone restarts the 5 s. A tap outside an open parent
  surface (the buttons or the code prompt) closes it **and does its normal
  job**: it calls, operates an object or moves the camera, and starts a
  session if it reaches the world. Settings and setup fill the screen.
- **Time left:** the time left in the session, or until sunrise during
  bedtime, is shown to the parent only behind the code: in the settings
  header and on the wake-early prompt, never on the parent buttons.
- **Forgotten code:** "forgot the code?" on the code prompt hands off to the
  phone's own screen lock through Android's system prompt (PIN, pattern or
  fingerprint). If it succeeds, the parent sets a new code.
  - The new code is **typed twice**, as at setup. It replaces the old one at
    once. The parent is then back at the code prompt for the action they
    started, with the wrong tries and any wait cleared.
  - **Cancelling or failing** Android's prompt returns to the code prompt,
    with nothing changed and no wrong try counted.
  - On a phone with **no screen lock**, "forgot the code?" explains that
    clearing the app's data in Android settings is the only way, and that it
    erases all progress. Nothing else happens.
- **A wrong code:** the entry shakes and clears. Tries are unlimited, but 5
  wrong tries in a row bring a 30 s wait. The code prompt closes after about
  15 s with no input, and the settings screen closes by itself after **30 s**
  with no input, with a warning over the last 10 s; any touch resets it, and
  the same 30 s covers the screens opened from settings. The wrong-try count and the end of the
  wait are **stored on disk**, so they survive the prompt closing and the app
  being killed. There is one count for every parent button; it resets on a
  correct code or a code reset, and starts again from 0 after a wait.
  "Forgot the code?" works during the wait.
- **Wake early** is shown only during bedtime. **Deleting a level's save**
  asks for a second confirmation after the code.
- Opening the parent buttons or the code prompt pauses nothing: the world
  keeps running and the session keeps counting.
- **Language:** the
  parent-facing text (setup, the code prompt, settings, the forgotten-code
  screens) follows the phone's language when v1 has it, and is in English
  otherwise. v1 ships **English and French**; the French addresses the
  parent as "vous". The child sees no text. Everything the parent taps is at
  least 9 × 9 mm on the screen, with at least 2 mm between neighbours.
- How the buttons and the code prompt look is interface design.
- The full rules are in `access-model.md`.

### 5.9 Screen pinning

- The app asks Android to pin the screen **each time it opens**, so the child
  can't leave with the home or back buttons. Leaving goes through the parent
  code. Android shows its own confirmation every time, which can't be
  skipped; the parent normally opens the app and hands the phone over.
  Pinning also ends when the phone restarts. "Each time it opens"
  means **each launch**: on first launch, right after setup is completed
  (setup has explained pinning by then); on every later launch, as soon as
  the app opens, before the world takes a tap. Coming back from the
  background doesn't ask again. **"Leave" closes the app**, so the next open
  is a launch and asks.
- Anyone can unpin with Android's gesture unless the phone's **"Ask for PIN
  before unpinning"** setting is on. Setup recommends turning it on.
- **If the parent declines pinning,** the game still works, every parent
  button still asks for the code, and the setup screen explains the
  difference. The **back gesture then leaves the app**, as Android
  normally does, like home and recent apps; the session keeps counting and
  reopening resumes where it was. Setup says so. The one exception: the
  game runs in sticky immersive mode (no system bars) and keeps **the whole
  edge strips** out of the back gesture, so a tap sliding off a strip
  doesn't leave the app.
- This is **best effort**, a courtesy to parents and not a guarantee. There is
  no device-owner kiosk mode (it would need the phone wiped and provisioned),
  and a child who knows the phone's PIN can reset the parent code.

### 5.10 Persistence

- The save holds each slime's species, size, state and position, and the
  state of every interactive object and gate.
- **One save file per level.** A parent can delete one level's save from the
  settings. Deleting removes the save **and its backup**. If that
  level is running, it **reloads fresh at once**, as on a fresh install: the
  first-play hint is due again, and the celebration can play again when the
  level is completed again. The session or bedtime and their timers carry on
  untouched.
- **Where the session lives.** While v1 has one level, the session (its
  phase, elapsed time and clock anchor) is kept in the level's save, so a
  killed app resumes where it was. Deleting the level's save keeps the
  running session and writes it into the fresh save, so deleting can't dodge
  bedtime. With several levels (paid levels, later), the session moves to a
  store of its own, outside any level's save.
- Saved every 15 s and whenever the app goes to the background.
- On load, a slime saved in mid-air is put on the ground or back at the start
  of its jump, whichever is easier to build; if neither works, it is lost.
- **Saves are never wiped.** A released level isn't meant to change. If one
  does, the change is minor and ships with a save migration. A sleeper
  it displaces stays asleep: back at its own spot if the level still has
  that sleeper (moved, or of another species now: the saved species is
  kept), otherwise at the nearest empty sleeper spot, which it takes as
  its own. Awake slimes it displaces, and a sleeper left with no spot,
  are treated as lost. The save records the level's
  version, and slimes, objects and gates have stable IDs.
- Saves are written atomically, and the previous one is kept as a
  backup that is used if the latest can't be read. If neither can be read,
  that level starts fresh.
- **The save format before the first store release** (D149). v1 is never
  in a store, so in v1 the save format may change from one build to the
  next without a migration. A save a build can't use is set aside with
  its backup, that level starts fresh and saves again, and one log line
  says so (proposed). Migrations for every format change are owed from
  the first store release on. Level-version migration (above) is
  unchanged.

### 5.11 Level rules

Every level, the test level included, follows these rules.

1. The loop can be travelled with no input at all.
2. A slime of any size can travel the loop. (From the next version, sizes may
   take different forks through a size filter; in v1 every size takes the
   same way.)
3. No dead ends: every branch joins the loop again.
4. The start of the loop carries a split zone.
5. A dip in the loop may nudge same-species slimes into fusing.
6. A signpost stands at every fork.
7. From anywhere a free slime can reach, gravity leads back toward the loop.
8. Every exploration branch includes its own route back to the loop.
9. Hints that there is something to explore are visible from the loop.
10. Tilt is only for exploration or fun, never needed to make progress.
11. The first section has 3 native species; each later section adds one.
12. A frontier gate opens through the switch-plus-basket set. Each
    section's basket can be filled by play from the slimes that can be
    woken by then, starting from a fresh game, fusion included (proposed).
13. Each section has its own return route to the start from its unopened
    frontier gate. It is part of the loop and has its own camera rail.
14. A return route may carry exploration opportunities, but opening a later
    frontier gate must never make them unreachable.
15. Once its gate is open, a frontier set is inert for good; it may be removed
    or become a landscape feature.
16. At most 200 slimes per level, counted in base slimes. Where many pile up
    on one screen, they should be mostly still (for example, filling a
    basket).
17. Sleepers never sit on the loop.
18. The first sleeper is close to the first awake slime.
19. Wherever a wider view is needed, a framing zone sets the zoom and position.
20. A released level isn't meant to change; any update is minor, ships with a
    save migration, and keeps stable IDs. A released level keeps the list
    of its released stable IDs: each must still exist, new sleepers are
    numbered above the highest released one in their section, and
    removing one needs a level version bump and a migration (proposed).
21. At the rails' framing, every interactive object sits fully below the
    parent zone. The views checked are the settled views of the outgoing
    route's rails, framing zones included; the return routes' views aren't
    checked. An object framed above the top of the screen fails too, and
    switches, baskets and gates are all checked (proposed).
22. A return route delivers slimes into the start behind the loop's start,
    travelling the loop's way, never along the loop's first stretch against
    the flow; and nothing a base slime must be called up to overhangs the
    loop where larger slimes pass (a ledge a called size 1 can reach is too
    low for a size 2 or 3 to pass under). A ledge a called base slime
    must reach keeps its underside at least 130 px over any loop ground
    under it (proposed).

### 5.12 Levels and the test level

- Each level has its own folder in the spec, `levels/<id>/`. It is mostly
  storage for that level's design requirements and the discussion about it.
- **The test level** (`levels/test/`) is a compact level designed to exercise
  the v1 mechanics. It is the testing ground for implementation and the base
  for end-to-end tests. It uses placeholder art. It is v1's whole content;
  the release build leaves it out.
- **The real first level** (`levels/01/`) is v2 (chunk L01).

## 6. Architecture decisions and why

- **Godot 4.** Open source, strong 2D, exports to Android and to a Linux
  desktop build from the same project. Unity and Unreal were ruled out by the
  owner.
- **No custom level editor.** Levels are Godot scenes built in Godot's editor,
  with curved terrain from paths and collision polygons. Every interactive
  element is a reusable, programmed component configured by properties, and
  **there are no per-level scripts**. This keeps extra levels (possibly paid)
  as content rather than code.
- **Soft slimes:** each slime is a ring of points joined by
  springs, in our own code, drawn with a shader that blends nearby shapes into
  smooth blobs. Fusion and splitting are operations on rings. No engine gives
  this out of the box. Slimes meet the curved terrain through the
  simulation's own test against the baked terrain outlines, not the engine's
  collision shapes.
- **The slime simulation's tick moves to native code; its interface was
  built ready for it.** Measured on the reference phone, the tick written
  in Godot's scripting language can't hold 60 fps with 200 slimes all
  simulated, and gets slower once the phone throttles after a few
  minutes. The tick was first kept in the scripting language, since in
  play a big crowd was expected to be mostly a still pile, and resting
  slimes, sleepers and a full basket's slimes stop being fully simulated.
  The performance pass on the phone missed its targets at the endgame,
  and fewer ring points in a crowd helped but not enough, so the prepared
  C++ extension (the rings, the contacts, the terrain), built for the
  Linux desktop and for Android, is adopted. *(proposed)* Its results
  repeat within one build but aren't bit-equal to the scripting-language
  tick; a save loads under either tick; the scripting-language tick stays
  as the fallback. The behaviour around the tick (hops, the call's
  phases, fusion timing) stays in the scripting language either way.
  A frame runs at most 2 ticks at normal speed, so an overloaded scene
  plays in slow motion instead of collapsing into a catch-up spiral.
- **Drawing is kept cheap by design,** not assumed cheap: only the slimes
  near the view are drawn, each drawing redraws only when what it shows
  changes, and repeated shapes (eyes, a basket's slots) are one instanced
  draw each. Before that work, drawing cost more of the frame than the
  tick on light scenes. As a headroom target, recorded at each phone
  session but not a gate, its share of the reference phone's frame is at
  most 4 ms and the simulation's at most 8 ms, leaving at least 4.7 ms
  for later animation, music and the system. The renderer is Godot's Compatibility renderer,
  which reaches the most Android phones.
- **Physics only near the screen.** Up to 200 slimes on a mid-range phone
  rules out simulating every slime all the time. Off-screen slimes move along
  authored paths at a deterministic pace; that is also what makes off-screen
  behaviour predictable and testable.
- **Authored routes back, no pathfinding.** Every exploration branch includes
  its route back as level data (a path drawn in the editor), so a
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
  No analytics, no ads, no network permission.
- **One save per level, never wiped.** A parent can reset one level without
  losing others; level updates migrate saves rather than breaking them.
- **Testability:** all gameplay randomness comes from one seeded
  generator so test runs repeat exactly within one build on one platform:
  the desktop and the phone give different results even on the same tick,
  because Android's math library rounds one angle function differently
  (a desktop tool reproduces the phone's results). Repeating across
  devices isn't a v1 aim. *(Proposed, D162:)* that holds in test mode's
  default crowd detail and with crowd detail off; a run that asks for
  normal play's crowd detail, which follows the device's load
  (`--crowd-detail=auto`, the phone's performance runs), doesn't repeat,
  and its hash isn't a fixture's. A test mode, only in the Linux build
  and debug Android builds, loads fixture saves, speeds up or skips time, and
  injects taps and tilt from a script.

The code base is the one built under this plan (`build-plan.md`), in
GDScript on Godot 4.7; new work fits into it. Its layout, how to run the
tests, and the technical choices made while building are in the project's
`docs/dev/README.md`.

## 7. Target phones and test environments

- **Reference phone:** Samsung Galaxy S20 FE. **Floor:** a budget phone of the
  Galaxy A14 class. If the floor phone can't hold 200 slimes, the floor rises;
  the 200 cap stays.
- **Performance targets:** 60 frames per second on the reference phone in
  normal play; at least 30 on the floor phone with the level's largest
  realistic pile on one screen (a full basket plus the train, mostly still).
  The 200-slime cap stays.
  Two moving stress cases on the reference phone: at least 30 fps for the
  dense case (200 train slimes, 3 per 100 px of loop along the loop line,
  the bottom of section 3's bowl at 4, filled from the bowl outward) and,
  for the abuse case (200 moving slimes, all piled in the bowl), an abuse
  target, not a 30 fps target: no crash, no freeze and at least 15 fps.
- **Measured so far:** the reference phone missed its target on the first
  measurement, so the tick moved to native code and the measurement was
  repeated after it (2026-10-07, crowd detail as in normal play): the
  section 3 endgame (basket 3 at 59 of 60) and the dense case at 59 fps
  cold and warm, the abuse case at 23 fps cold and 59 warm, with no
  throttling. Still to measure on it: normal play, a big awake pile at the
  loop's start, and the debug labels' cost. The floor phone still has to
  be bought.
- Test environments:

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
| Call radius | about half the screen width |
| Call cap | about 8 s |
| Train hop interval | about 1.5–3 s, random per slime |
| Hop rate answering a call | a bit faster than on the train |
| Idle camera takes over | 45 s without input; cue 10 s before |
| Screensaver and idle zoom | 10–20% wider than normal play; one zoom for both |
| Minimum zoom in framing zones | to find with the prototype |
| Wrong-code wait | 30 s after 5 wrong tries in a row |
| Code prompt closes by itself | about 15 s with no input |
| Settings closes by itself | 30 s with no input, a warning over the last 10 s |
| Parent buttons hide | after 5 s with no press |
| Hit area of an interactive object | the drawing plus 5 mm a side, at least 20 × 20 mm on the screen |
| Edge-button press | at least one fixed step; a steady pace while held (to try) |
| Leaving a framing zone | holding the edge button about 1 s (to try) |
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
reference phone unless stated otherwise, and the test level passes the
level-rules check. Which build, since the release build has no level and
never ships: O101.

**World and slimes**

1. With no input at all, from a fresh save, the train keeps travelling the
   whole current loop for a full session, and no slime ever becomes lost,
   nor does any train slime stall (5.2): the safety net moving a stalled
   slime doesn't count as a pass.
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
    when it comes into view.
11. Flipping the switch back before the basket is full stops the filling,
    releases the slimes inside back to the loop, and empties the basket.
    Once the basket is full, a tap on the switch doesn't flip it; it calls.
12. Opening all gates of the level never requires tilt.
13. Once a gate is open, tapping its switch doesn't operate it (the tap is
    a call), and its basket takes no more slimes.
14. When the last basket fires, the celebration plays once, and the world
    keeps running with the loop complete; reloading doesn't replay it.

**Controls and camera**

15. Every tap produces a visible ripple, including taps that do nothing else.
    A touch ignored under criterion 17 isn't a tap and shows
    nothing.
16. On a fresh install, if the child hasn't called within about 10 s, a
    wordless pulsing mark appears near the first sleeper; it never appears
    again once the first call is made. The 10 s count from the
    world's first frame, screensaver mode included, and deleting the level's
    save brings the hint back.
17. While one finger is down, a second touch does nothing. Not
    even a ripple, and it stays ignored after the first finger lifts. After
    about 5 s, a touch resting on an edge strip no longer blocks others.
18. The edge buttons move the camera along the loop; the child can never
    change the zoom; entering a framing zone reframes the camera smoothly.
    A press moves at least one fixed step, holding keeps the
    camera moving, and leaving a framing zone takes about 1 s of holding.
    A tap anywhere in an edge strip (the screen's whole height below the
    parent zone, 10% of its width from the edge) moves the camera and never
    calls. A call whose point is inside the central box (20% by 20% of the
    screen) leaves the camera where it is. A tap within an object's hit area
    (its drawing plus 5 mm, at least 20 × 20 mm on the screen at any zoom)
    operates it when it answers taps, and calls otherwise.
19. After 45 s with no input the idle camera follows a train slime, with the
    zoom-out cue starting 10 s earlier; any touch takes back control and does
    its normal job; tilt doesn't count as input; the idle zoom never zooms in
    where the camera is already wider.

**Session and parents**

20. A session starts at the first tap in screensaver mode and ends 15 real
    minutes later, including time spent in the background, after a killed
    app, and after a phone restart. A tap on the parent zone or an
    edge button doesn't start it. Reopening the app during a session or
    bedtime resumes it instead of landing in screensaver mode.
21. The last minute shows the dusk wind-down; at bedtime the slimes fall
    asleep, the game saves, and taps no longer call. During bedtime no basket
    releases a slime or plays its reward; both resume at sunrise.
22. Sunrise comes 10 real minutes after bedtime began, or immediately after
    the correct parent code on "wake early"; screensaver mode follows.
23. On first launch the parent setup appears before anything else and
    requires the 6-digit code twice; it is never shown again. Its
    text is in French on a French phone and in English otherwise. Setup
    runs in four steps, and a setup interrupted before its last step keeps
    no code and starts again from the first step.
24. Every parent action (wake early, leave, change the code, delete a level's
    save) is refused without the correct code. The 30 s wait after
    5 wrong tries survives closing the prompt and killing the app. The
    parent buttons hide after 5 s; a tap outside the buttons or the code
    prompt closes it and also does its normal job; settings close after
    30 s with no input, warning over the last 10 s. The time left (session,
    or until sunrise) shows in settings and on the wake-early prompt, and
    never on the parent buttons.
25. With screen pinning accepted, the home and back buttons don't take the
    child out of the app; "leave" with the correct code does.
    Pinning is asked right after setup on first launch and at every later
    launch, not on coming back from the background. With pinning declined,
    a tap sliding off an edge strip doesn't trigger Android's back
    gesture.
26. "Forgot the code?" lets the parent set a new code after passing the
    phone's own screen lock. The new code is typed twice;
    cancelling Android's prompt changes nothing; with no screen lock, it
    explains that clearing the app's data is the only way.
27. The app makes no network connection.

**Persistence**

28. Killing the app at any moment and reopening it restores slimes, objects
    and gates as of the last save (at most about 15 s old), with no slime
    left in mid-air.
29. Deleting one level's save resets that level only. Its backup
    goes too, and a running level reloads fresh at once while the session
    timers carry on.

**Performance and quality**

30. At least 60 fps on the reference phone in normal play, and at least 30
    fps on the floor phone with the level's largest realistic pile on one
    screen (a full basket plus the train, mostly still), both cold and after
    5 minutes of play. On the reference phone,
    with the camera on section 3's bowl: the test level's dense moving
    case (`stress-dense`: 200 train slimes, 3 per 100 px of loop along
    the loop line, the bowl's bottom at 4, filled from the bowl outward)
    holds at least 30 fps, and its abuse case (`stress-moving`: 200
    moving slimes, all piled in the bowl) meets an abuse target, not a
    30 fps target: no crash, no freeze and at least 15 fps
    *(proposed: the mean over a 62 s run, the 5th percentile reported)*.
    Until the reference phone is measured, the slowed desktop run
    (`tools/perf_slow.sh --pin=main`) stands in. *(The user's reading,
    D161; wording proposed:)* these targets are judged with the loop
    start's crowding set aside: the windows where slimes coming home
    crowd the loop's start (in the `s3-basket-59of60` fixture, its
    section 1 window once the train comes home) are measured and
    recorded, not gated (Known gap 9).
31. The automated end-to-end suite on the test level passes on the Linux
    build.
32. *Deferred, not an objective of the full MVP (D135):* a playtest with
    the primary persona shows her finding the call on her own, with no
    adult explaining it (goal P1.G3). Putting it in children's hands may
    first need some graphics work.

## 10. Deferred

Everything in "Not in v1" (section 3) is deliberately out of this version and
tracked in the project's version plan.

## 11. Known gaps

Still undecided.

1. **The real first level's design** (v2, chunk L01): its layout, pacing,
   section sizes, return routes and theme details, in `levels/01/`.
2. **How each section's return route works** (a slide, wind, a conveyor…).
   Decided with the first level's design. The test level uses underground
   slides as placeholders. Whatever it is made of, it follows level rule
   22 (5.11), the test level's lesson: it delivers slimes into the start
   behind the loop's start, travelling the loop's way.
3. **Where a basket releases its slimes,** after firing and after an opt-out.
   It belongs to the basket object's own design, which is still to be
   planned. The test level assumes one outlet onto the onward route.
4. **A minimum zoom.** A big framing zone may shrink slimes too far to tap or
   see. It only matters during play, since the idle camera and screensaver
   mode ignore framing zones. No proposal yet; to find with the prototype.
   Measured on the reference phone (6.5 inch, 1080 × 2400): a size-1 slime
   is about 5.0 mm across at zoom 1, 4.3 mm at 0.85 and 3.5 mm at 0.7 (the
   test level's two framing zones).
5. **Technical risks to check with prototypes before building for real.**
   Checked on the desktop: the vector look (curves baked into polygons and
   lines; imported SVGs blur when zoomed), soft slimes at 200 with the
   blending shader and the Compatibility renderer, and running end-to-end
   tests on Linux without a screen. Checked on the reference phone: 200
   slimes all simulated miss 60 fps; cheaper states for resting slimes
   came first, then the whole game at the endgame missed its target too,
   so the tick moves to native code (section 6). The floor phone's target
   now applies to the largest realistic pile, not 200 slimes on one screen
   (Definition of done, 30). After the native tick the reference phone
   holds its targets on the three fixtures measured (section 7). Still
   waiting: the floor phone (it has to be bought), normal play on the
   reference phone, the phone's GPU cost of the blending (it can't be read on Android
   with this renderer, so only the frame rate shows it), and tilt input. Android audio
   latency matters only from the version that adds sound.
6. *(Closed, D159.)* Why slimes of different species sometimes ended up
   inside each other: found and fixed; the stuck net stays (5.2).
7. **Whether the stalled measure still fits the real level** (5.2). A
   stalled train slime is moved to the start of the loop, as lost and
   stuck slimes are. Whether 24 px of progress in 60 s is the right
   measure once the real level's return routes exist is to recheck with
   the first level's design.
8. **The release build** (D134, D135). v1 is the test level only and is
   never published; the release build leaves the test level out. Which build
   the Definition of done is checked on is O101; the first store release,
   probably v4, ships a fully implemented level (D137).
9. **The loop's start crowds when slimes come home** (D159, D160, D161).
   On the test level, slimes coming home by the return routes arrive
   faster than the train takes them off the loop's first stretch, so a
   pile grows at the start (the level fails `../../level-design.md` rule 24's check). Not a
   v1 blocker (the user's, D160), and left out of Definition of done 30's
   frame-rate judgement (D161). The review of the test level's start and
   the geyser come after v1 (D161).
