# Decisions log

Append-only. Each entry records what was decided, why, and which open question it resolved (if any).

## D1 — The session lock is best effort (2026-09-27)
Screen pinning, plus an in-app parent gate, plus a timer that survives the app
being killed. No device-owner kiosk mode. It is a courtesy to parents, not a
guarantee: "we do what we can." Why: a consumer app cannot get an unescapable
lock (research: `docs/research/level-authoring-and-kid-lock.md` §B.1).

## D2 — Design stance: interactive screensaver (2026-09-27)
The world runs and is enjoyable to watch without input. Taken from
Cocoreccho!'s own design intent, and the user favours it.

## D3 — Gameplay priority order (2026-09-27)
1. Watching the train and bringing sleepers into it.
2. Exploring the loop's surroundings for more slimes.
3. Fusion, which opens pathways not yet explored.

## D4 — Idle camera follows a slime (2026-09-27)
After a period without input, the camera follows a slime's movement. The user
recalls this from Cocoreccho!; one reviewer describes that game's camera as
static, so we treat this as our own choice either way. The details are O4.

## D5 — Engine: Godot 4 (2026-09-27)
Chosen for the editor and so levels can be built without a custom level
editor. Its risks are still to be tested with prototypes (O14).

## D6 — No custom level editor (2026-09-27)
Levels are Godot scenes built in Godot's editor. Interactive elements are
reusable, programmed components configured through properties, with no
per-level scripts.

## D7 — Session state persists between sessions (2026-09-27)
Saved state is a summary: each slime's type, size and position, plus the state
of every interactive object in the scene. The soft-body shape of a slime is not
saved; it is rebuilt at rest when the game loads. Why: with a 15 min cap, the
world has to be played across several sessions. Partly resolves O8 (the
persistence half).

## D8 — Path model: hybrid route plus free physics (2026-09-27)
Resolves O1.
- The **train** follows the **current loop**, a drawn route.
- Opening a gate changes the loop so it takes in the newly opened area.
- At any time the player can attract slimes away from the loop. Those slimes
  become **free**: they are driven by physics alone.
- A free slime left alone long enough makes its way back to the loop and
  rejoins the train.
- **Level rule:** from anywhere a free slime can reach, following gravity down
  must lead back to the loop.

## D9 — The loop grows gate by gate (2026-09-27)
Resolves O17.
- Opening a gate **extends** the loop. The old route back to the start stays
  in the world but is no longer used.
- The loop now runs as far as the **next unopened gate** (the frontier gate).
- At the frontier gate, the player has to actively work to open it.
  Otherwise the slimes are herded, one way or another, back toward the start
  of the first loop.
- Opened gates stay open.

## D10 — Left-alone and lost slimes (2026-09-27)
Resolves O18.
- A free slime is **left alone** once it has been off screen for more than
  10 s.
- A left-alone slime that hasn't reached the loop within 1 min is **lost**. A
  lost slime is teleported to the start of the loop.
- A free slime that stays on screen is never lost.

## D11 — The train has no slots (2026-09-27)
Resolves O19.
- The train is simply whichever slimes are following the loop. The clumps you
  see are just how many happen to be at the same spot at that moment.
- A slime alone on the loop still follows it.
- A free slime rejoins by reaching the loop.

## D12 — When to save, and airborne slimes on load (2026-09-27)
Resolves most of O20; save-format versioning stays open.
- Save every 15 s, and whenever the app goes to the background.
- A slime saved in mid-air is placed on the ground or at the spot where its
  jump started, whichever is easier to implement. If neither works, it is
  declared lost (D10).

## D13 — Waking sleepers (2026-09-27)
Resolves O2.
- A sleeper wakes **only** when an awake slime touches it.
- The game itself wakes the very first slime.
- Tapping a sleeper calls nearby awake slimes toward it. They wake it. The
  woken slime is free, and in time it joins the train (D8).

## D14 — Switch vs gate naming; opening a frontier gate (2026-09-27)
Resolves O25 and the basic pattern of O23. The user's "yes" was taken to
confirm the proposed naming and flow.
- **Switch:** redirects the flow at a fork in the loop. **Gate:** the barrier
  at the end of the loop that opens onto a new area.
- The standard frontier pattern: just before the gate, a switch sends the
  train home by default. Flipping it sends the train into a **basket**. The
  basket shows the slimes it still needs as empty slime outlines (no numbers).
  When the basket is full, the gate opens, the basket releases its slimes, and
  the loop now reaches into the new area.

## D15 — How interactive objects are activated (2026-09-27)
- Most interactive objects are operated by **tapping them**.
- A few are driven by **tilting the phone** instead, or by the **presence of
  slimes** (possibly of a specific type) rather than by a tap.
- Tapping an interactive object operates it. A tap anywhere else is a call.

## D16 — Presence objects respond to weight (2026-09-27)
Resolves O26 in principle; each object's actual thresholds are set when that
object is designed.
- Objects that react to slimes on them (basket, bending pathway, …) respond to
  **weight**.
- A slime's weight is the number of base slimes it is made of. A fused slime
  weighs more than a single one.

## D17 — Spring-back bending pathways act as small forks in the loop (2026-09-27)
- A bending pathway that springs back works as a small fork driven by weight.
  A dense clump of the train bends it and takes one branch; a sparse trickle
  leaves it straight and takes the other. How the train happens to be spread
  out opens different ways to explore.
- The call adds control. Calling slimes onto the pathway **holds** them there,
  piling up weight until it bends. Calling them onward **hurries** them
  across, so the weight never builds up and it doesn't bend. This is not a new
  action: it falls out of the call.

## D18 — Rules for branches in the loop (2026-09-27)
Resolves O27.
1. Every branch joins the loop again, further along or back at the start.
   There are no dead-end branches.
2. A slime on any branch is still part of the train (following the route, not
   free).
3. Exploration areas hang off the route, not on it. Slimes reach them only
   by being called (free, physics only), and gravity leads back to the route
   (D8).

## D19 — Tilt (2026-09-27)
Resolves O3.
- The world stays fixed on the screen, and gravity turns with the phone,
  capped at ±45°.
- There is a dead zone of about 10° around neutral, where gravity stays
  straight down.
- Neutral is how the phone was held when the session started. A phone lying
  flat counts as neutral.
- **For now, only free slimes feel tilt.** The train ignores it.
- **Tilt objects always respond to tilt.** Through them, tilt can indirectly
  affect the train, but only a little.
- **Level rule:** the loop is built so the train can travel it with no input
  at all. (proposed reading: this holds at any tilt, whatever state the tilt
  objects are in)

## D20 — Fusion is triggered by prolonged contact (2026-09-27)
Resolves the trigger part of O10.
- Two slimes of the **same species** fuse when they stay in contact longer than
  a threshold of about 3–5 s (to be tuned).
- Most fusion is expected to come from the call, which holds slimes in place,
  or from calling them toward a spot they can't reach, where they pile up.
  Fusion can still happen on its own.
- A natural dip in the loop can nudge slimes toward fusing.

## D21 — Slimes move by hopping (2026-09-27)
- Slimes don't move at an even pace. Every few seconds they make a small hop in
  a direction of their choosing. For train slimes that direction is along the
  loop.

## D22 — Species (2026-09-27)
Resolves O11.
- The first section of the loop has **3 native species**. Each new section
  (opened by a gate) adds one more.
- The mix is meant to keep most slimes small, since only the same species fuse.

## D23 — Slimes split again at the start of the loop (2026-09-27)
- When slimes reach the start of the loop, they split back into base slimes.
  The in-world reason and mechanism are still to be defined (O29).

## D24 — Size (2026-09-27)
- A slime's **size** is the number of base slimes it is made of. That number is
  also its weight (D16).
- Bigger slimes are heavier and a little more powerful. For example, they jump
  higher.
- **Level rule:** the loop can be travelled by a size 1 slime. A big slime
  can't be stopped from following the loop, although it may take a different
  fork to reach the end.

## D25 — Fusing different species needs a device, and comes later (2026-09-27)
- Fusing slimes of different species (to get new species with special effects)
  takes a slime-activated device. When slimes of the right species are inside
  its area, it fuses them into the new species.
- Not in the first iterations of the app.

## D26 — Level rule restated: every size can travel the loop (2026-09-27)
Supersedes the level-rule wording in D24.
- A slime of any size can travel the loop.
- That doesn't mean every size takes the same fork. Size-dependent forks are
  expected.

## D27 — What a free slime does after a call ends (2026-09-27)
Resolves O28.
- Once the call ends, a free slime is **unsure** for a while: up to about
  15 s, maybe more (to be tuned). It stays put or hops around, without straying
  far from the last call point.
- Then it **heads back** to the loop.
- Physics applies the whole time. On a steep enough slope, its own hopping
  isn't enough to hold it, and it may roll downhill.

## D28 — The session ends with a gentle bedtime (2026-09-27)
Resolves O5.
- **Wind-down** during the last minute: the light drifts toward dusk, the
  music softens, and slimes hop more slowly. No text, no countdown.
- **Bedtime:** when time runs out, slimes settle and fall asleep where they
  are. The game saves, calls stop doing anything, and the sleeping world stays
  on screen.
- **After bedtime, only the parent gate** moves things forward. There is no
  cooldown that lets the child start again alone.
- Bedtime sleep is a **different state** from being a sleeper. At the start of
  the next session the game wakes every bedtime-asleep slime, and they carry
  on where they were. Sleepers still wake only on contact (D13).

## D29 — Fixed 15 min sessions with a 10 min cooldown (2026-09-28)
Partly resolves O6.
- For now every session lasts **15 min**, and that is fixed.
- After bedtime, a new session **can't begin until 10 real-time minutes have
  passed**.
- A later version lets the parent choose the session length.
- How this cooldown fits with D28's "only the parent gate moves things
  forward" is open (O35).

## D30 — The parent gate is a 6-digit code (2026-09-28)
Resolves O7.
- To get past the parent gate, the adult enters a 6-digit code.
- Accepted risk (D1): a child who has watched a parent type the code may learn
  it.
- Who sets the code, and how it is recovered if forgotten, is O34.

## D31 — Business model direction (2026-09-28)
Resolves O16.
- The base game is paid, about **$3–5**. Each new level comes later as a paid
  unlock, about **$2**. (Prices are indicative.)
- Context: the user hopes for about $160–200 of revenue a month. That is a
  business goal, not a spec requirement.
- (proposed) Purchases go behind the parent gate (D30).

## D32 — Idle camera timing (2026-09-28)
Partly resolves O4.
- After **45 s** with no input, the idle camera takes over. It picks a train
  slime and locks onto it.
- A slight cue may come 10 s beforehand. What it looks like is still open
  (O4).

## D33 — The manual camera runs on rails along the loop (2026-09-28)
- The child moves the camera **along the loop** using **left and right
  buttons** at the edges of the screen.
- At a fork, **signposts** show the directions. By default the camera follows
  the main stream.
- A **call** drags the camera toward the call point at a slow, steady pace.
- Open follow-ups: O36 (signposts), O37 (seeing areas off the loop), O38 (the
  edge buttons and the call).

## D34 — First-release scope: one level of 4 sections (2026-09-28)
Resolves O8 and O24.
- The first release ships **one level**, moderately sized: **4 sections**.
- The theme is very basic and stays close to Cocoreccho!: black "stone" and
  black "plants" form the ground. There are few kinds of interaction.
- Its aim is for the child to discover the game's mechanics.
- Pacing: a lap takes a slime a few minutes, but the slimes are spread along
  the loop. Moving the camera along the loop keeps showing travelling slimes,
  and exploring can start anywhere.
- How slimes are sent back from an unopened frontier gate (O22) will be settled
  in a dedicated session on the first level's design.

## D35 — Switch plus basket is the only frontier-gate pattern for now (2026-09-28)
Resolves O23.
- In the first release, the switch-plus-basket pattern (D14) is the only way to
  open a frontier gate.
- Later levels may add other ways, for example switches hidden along forks and
  reachable only by certain species.

## D36 — No failure states (2026-09-28)
Resolves O9.
- Nothing can go wrong. The worst case is a lost slime, which is teleported
  back to the start of the loop (D10).

## D37 — Fusion timing, for now (2026-09-28)
Resolves O10 until tuning.
- Two slimes fuse after **3 s** of continuous contact.
- A hop that breaks contact resets that count.
- A slime covered by other slimes doesn't hop.
- The value will be tuned through experiments. When a slime decides to hop is
  O40.

## D38 — Specific objects and zones split slimes (2026-09-28)
Resolves O29.
- Splitting happens only at specific **split objects or zones**. The
  precursor's "defusing spot" is one of them.
- (proposed) The start of the loop carries one. That is how D23 happens in
  the world.

## D39 — Maximum size 3, for now (2026-09-28)
Resolves O30.
- A slime's size is at most **3**. It may become 5 later.
- What happens when a fusion would go over the maximum is O39.

## D40 — Species differ by colour and voice (2026-09-28)
Resolves O31.
- In the first release, species differ by **colour** and by **voice**. For
  now a voice is closer to a kind of instrument.
- Behaviour quirks per species may come later.

## D41 — How a free slime heads back (2026-09-28)
Resolves O33.
- A free slime heading back hops **mostly downhill**, but it **knows the
  shortest way to the loop**.
- How it knows that way is O44.

## D42 — The music generator is deferred (2026-09-28)
Parks O12.
- The music generator waits for a later stage. It is currently a JS app, and
  porting it to Godot is a project in its own right.
- What the first release sounds like without it is O41.

## D43 — One save file per level (2026-09-28)
Partly resolves O20.
- Each level has its own save file.
- The user can delete the save of a specific level. (proposed: behind the
  parent gate)
- What happens to a save when an update changes its level is still open (O20).

## D44 — Sunrise: how bedtime ends (2026-09-28)
Resolves O35. Supersedes D28's line "only the parent gate moves things
forward".
- Bedtime ends in one of two ways. Either the **parent enters the code** and
  lets the child play again straight away, or **10 minutes pass** (D29).
- The long default delay is on purpose: it nudges the child to put the phone
  down and do something else.
- **Sunrise:** when bedtime ends, the bedtime-asleep slimes wake up and carry
  on with their lives in **screensaver mode**. This is the world running with
  no session.
- **A session begins only at the first tap on the screen.** The 15 min timer
  starts then.

## D45 — Exploring with a rails camera (2026-09-28)
Resolves O37.
- The camera stays on rails along the loop. A call dragging the camera is the
  way to look off the loop, so there is no joystick, which is hard to use at
  this age.
- **Level rule:** hints that there is something to explore must be visible
  from the loop.
- How fast the camera drags toward a call, and when it goes back, will be tuned
  with a working prototype.

## D46 — The call is tap-to-call (2026-09-28)
Resolves O38 and the choice in O21.
- The call is tap-to-call. Hold-and-drag is dropped as a way to call.
- If the camera ever moves freely later, it would use hold-and-drag, and that
  would replace the edge buttons.
- How the edge buttons look and respond is interface design, for the UX
  design later.

## D47 — Signposts and filters are two objects (2026-09-28)
Resolves O36.
- A **signpost** stands at every fork in the loop. It shows which way the loop
  goes.
- A **larger signpost** also lets the player choose which branch the camera
  follows.
- A **filter** is a kind of fork that sends slimes down a branch by species
  ("all blue slimes go this way"). It usually has a signpost next to it.

## D48 — Six species in the first release (2026-09-28)
Resolves O42.
- 3 species in the first section plus one per section, over 4 sections, gives
  6 species. That is accepted.

## D49 — No fusion over the maximum size (2026-09-28)
Resolves O39.
- If two slimes would fuse past the maximum size (2 + 2, or 3 + 2, with a
  maximum of 3), they don't fuse. They just bump.

## D50 — Version split for sound and objects (2026-09-28)
Resolves O41.
- **v1 has no sound at all.** Sound, including species voices (D40), comes
  around **v3**.
- **Interactive objects come in v2**, except the frontier gate, which is in v1.
  What exactly the v1 frontier gate includes is O46.

## D51 — Each exploration area has its own way back (2026-09-28)
Resolves O44.
- **Level rule:** every exploration branch includes its own route back to the
  loop. The level designer builds it into the level.
- A slime heading back follows that route (D41).

## D52 — Features are tracked by version (2026-09-28)
- Each version's scope lives in `versions/<version>/README.md`.
- Features that don't have a version yet go in `versions/timeline.md`.
- Features can be moved to a later version at any time. A move is logged here.

## D53 — Screensaver mode details (2026-09-28)
Resolves O45.
- Opening the app from scratch also shows **screensaver mode** until the first
  tap starts a session.
- In screensaver mode the phone's **usual screen timeout** applies. During a
  session the screen stays on.
- (proposed) Screensaver mode shows the idle camera straight away.

## D54 — v1 objects (2026-09-28)
Resolves O46. Refines D50.
- v1 ships the **frontier-gate set**: a switch, a basket and a gate, plus a
  **split zone at the start of the loop** (D23, D38), so fused slimes still
  split back into base slimes.
- Every other object moves to v2: bending pathways, filters, large signposts,
  tilt objects, reveal zones, and other split zones or defusing spots.
- Plain signposts are not interactive and stay in v1 (proposed, D47).

## D55 — Setting and recovering the parent code (2026-09-28)
Resolves O34.
- **First launch:** a one-time setup screen for the parent appears before the
  first screensaver mode. The parent chooses the 6-digit code, typing it twice,
  and the screen explains screen pinning. After that, the app always opens
  into screensaver mode (D53).
- **Changing the code:** behind the parent gate.
- **Forgotten code:** "forgot the code?" hands off to the phone's own screen
  lock (PIN, pattern or fingerprint, through Android's system prompt). If that
  succeeds, the parent sets a new code.
- **No screen lock on the phone:** the only way out is clearing the app's data
  in Android settings, which erases all progress. The setup screen says so
  plainly.
- Accepted limitation (D1): a child who knows the phone's PIN can reset the
  code. There is no perfect solution.
- **No external service.** There is no website, account or server behind
  this.

## D56 — Sessions count in real time (2026-09-28)
Resolves O6.
- A session lasts 15 minutes of real time from the first tap, whether the app
  is visible or not.
- Sending the app to the background, a phone call and so on use up session
  time. That is accepted.
- If needed, the parent makes up for it by waking the slimes early (D44).

## D57 — Parent access from the top of the screen (2026-09-28)
- A tap at the **top of the screen** reveals the parent buttons: settings,
  leave the app, and so on.
- Pressing **any** of those buttons asks for the parent code first.
- (proposed) The parent actions are: **wake early** (ends bedtime or the
  cooldown), **leave** (ends screen pinning), and **settings**, which holds
  changing the code and deleting a level's save.
- (proposed) A tap at the top reveals the buttons and doesn't call. That makes
  the top of the screen a fourth tap zone, after objects, the edge buttons and
  the call (D15, D33, D46).
- How the buttons look and how long they stay is interface design (UX).

## D58 — Option to turn the parent code off, in v4 (2026-09-28)
- The parent may choose to have **no code** at all, for example to play
  themselves. The code is then never asked for, and waking early takes just a
  tap. This can be changed in the settings.
- Assigned to **v4**.
