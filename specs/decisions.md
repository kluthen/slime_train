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

## D59 — Idle camera details (2026-09-28)
Resolves O4.
- **Which slime:** the train slime nearest the middle of the current view, so
  the camera glides to it rather than cutting away.
- **Keeping it:** if that slime fuses, the camera follows the fused slime. If
  it splits at the start of the loop, the camera takes one of the pieces.
  Otherwise the camera stays on the same slime.
- **Taking back control:** any touch. That touch also does its normal job (a
  call, operating an object, and so on).
- **The cue 10 s before:** a slow, gentle zoom-out, with no text or sound.
- Screensaver mode uses the same idle camera (D53).

## D60 — Automatic camera framing (2026-09-28)
- **The player never controls the zoom.** Zoom, and sometimes position, are
  set automatically from where the camera is.
- An area may need a wider view. When the camera reaches it, the camera
  gently moves and zooms out to fit.
- The edge buttons can still leave such an area, but not straight away. Like a
  dip, the player has to push to get out of the framed position.
- **Screensaver mode** is zoomed out further than normal play, by about
  **10–20%** (to be tuned).
- (proposed) Level designers mark these areas as **framing zones**. A framing
  zone is a reusable level component (D6) with properties for zoom, position
  and how strongly it holds the camera. It ships in v1.

## D61 — Leaving a framing zone: a slightly longer delay (2026-09-28)
Amends D60.
- Instead of pushing, the resistance when leaving a framing zone may simply be
  a **slightly longer delay than usual** before the camera moves out when an
  edge button is pressed.
- To be tested in a prototype.

## D62 — The in-session idle camera also zooms out (2026-09-28)
Resolves O47.
- The idle camera during a session uses screensaver mode's wider zoom.
- The cue 10 s before is simply the start of that zoom-out. The first touch
  zooms back in.

## D63 — Context of use for the personas (2026-09-28)
Resolves O15.
- The child plays at home in the daytime: **as a reward for good behaviour, or
  for a little while after school**. It is not a before-sleep routine.
- A reward has to end without a fight, which D28's gentle bedtime supports.
- (proposed) Tilt is a bonus and never needed to make progress. How the phone
  is held isn't known, and playtests will show whether a 3-year-old tilts at
  all.

## D64 — Tilt is for exploration and fun (2026-09-28)
- Tilt is used **only for exploration or fun actions**. It is never needed to
  make progress along the loop or to open a frontier gate.
- This is a **level design requirement** (see `level-design.md`). It applies
  to v2's tilt objects too.

## D65 — First-time discovery (2026-09-28)
Resolves O49.
- **Every tap gets a visible answer:** a soft ripple where the finger
  touched, even when no slime is in range. Slimes in range visibly turn toward
  the tap before they hop.
- **A wordless hint, only on the very first play:** if no call has happened
  after about 10 s, a gentle pulsing touch mark appears next to the first
  sleeper. It goes away for good after the first call that wakes a sleeper.
- **Level rule:** the first sleeper is placed close to the first awake slime.
- After that, the world teaches the rest: waking, the train, fusion.

## D66 — The first touch wins, for now (2026-09-28)
Resolves O48.
- Only the **first finger** on the screen counts. While it's down, other
  touches are ignored. Once it lifts, the next new touch counts.
- This also takes care of a palm pressed on the screen: the first contact
  point wins.
- Two calls at once (for example, both siblings) will be tried later as an
  experiment (see `tuning.md`).

## D67 — At most 200 slimes per level (2026-09-28)
- A level holds **at most 200 slimes**. This is a hard cap in level design.
- (proposed) The cap counts **base slimes**, so a size-3 slime counts as 3.
- Many of them can end up on one screen, mostly when the loop is broken to fill
  a basket. They are pooled there and barely moving.
- This raises the performance target of the O14 prototype from 30–50 slimes to
  200 (see O50).

## D68 — Slime voices are capped at 10 (v3) (2026-09-28)
- Beyond 10 slimes, sounds are capped. **Up to 10 voices** play, shared among
  the species present in proportion to how many of each there are.
- (proposed) "Present" means the slimes on screen.
- This is part of v3 (sound, D50).

## D69 — Physics only near the screen (2026-09-28)
Settles the level-of-detail approach proposed with D67.
- Slime physics runs **only for slimes on or near the screen**.
- **Off-screen slimes just follow the loop at a deterministic pace.** When the
  view comes near them, they are properly spawned and physics takes over.
- Slimes resting in a basket may also get a simplified state.
- Side benefit: off-screen positions are just a place along the loop. That is
  easy to save (D7) and repeatable in automated tests.
- Rules for what happens off screen are O51.

## D70 — Off-screen rules (2026-09-28)
Resolves O51. Refines D13 and D14.
- **Free slimes off screen:** a free slime that leaves the screen is placed on
  the nearest point of its area's route back (D51) and follows it at the
  deterministic pace. If there's no route nearby, it is lost (D10). "Lost" is
  now a safety net.
- **Fusion and waking happen only on screen.**
- **Waking (refines D13):** a sleeper wakes only when a **free slime** touches
  it, meaning a slime that answered a call. Train slimes never wake sleepers.
- **Level rule:** sleepers never sit on the loop itself.
- **Baskets:** a basket can reach its quota off screen. It still needs a final
  activation: filling it earns a **reward animation**, and the basket fires
  its target (usually the gate). (proposed) The reward and the firing wait
  until the basket is in view.
- **Opting out:** the player can stop filling a basket at any time before it's
  full, by flipping the switch back. (proposed) The slimes already inside are
  released back to the loop, and the basket empties.
- **v2 objects:** each one must define how it behaves off screen.

## D71 — Target phones (2026-09-28)
Resolves O50.
- The **S20 FE** (late 2020, roughly mid-range by today's standards) is the
  reference phone for development and playtests.
- The **performance floor** is a budget phone from a few years back (Galaxy
  A14 class), reached through physics only near the screen (D69).
- If the O14 prototype can't hold 200 slimes on the floor phone, the floor
  rises to S20 FE class. The 200 cap (D67) stays.

## D72 — Level updates and saves (2026-09-28)
Resolves O20.
- The intent is **never to update a released level**. If an update does
  happen, it should only be a minor change.
- **Saves are never wiped.**
- Slimes displaced by an update are treated as **lost** and reappear at the
  start of the loop (D10).
- **Any level update must ship with its migration.**
- (proposed) To make that possible, the save records the level's version, and
  slimes, objects and gates keep stable IDs across versions.

## D73 — How long a call lasts (2026-09-28)
Resolves O21.
- **Each called slime's call ends on its own**, when it reaches the call point
  or after a cap of about **8 s** if it can't get there. That slime then goes
  into its unsure phase (D27).
- **A new tap replaces the call.** The new point takes over for every slime in
  range of it (D66).
- Called slimes gather in a clump at the call point. That is the natural way
  to get same-species fusion going (D20, D37).

## D74 — How slimes hop (2026-09-28)
Resolves O40.
- **Train slime:** hops forward along the loop every ~1.5–3 s. Each slime has
  a little random timing, so the train bounces unevenly.
- **Answering a call:** hops toward the call point, a bit more often. If the
  point is higher up, it jumps upward, and bigger slimes jump higher (D24).
- **Unsure:** small, lazy hops in random directions near the call point (D27).
- **Heading back:** hops along its area's route back (D41, D51).
- **No hopping:** sleepers, bedtime-asleep slimes, slimes covered by others
  (D37), and slimes resting in a full basket (D69).
- **Size:** bigger slimes hop a little less often, but further and higher.
- **Bedtime wind-down:** every slime hops more slowly (D28).
- All the numbers are tuning values.

## D75 — Terminology confirmed (2026-09-28)
Resolves O32.
- Adopted: **level, section, unsure, heading back, signpost, large signpost,
  filter, screensaver mode, sunrise, framing zone**.
- **Split zone** is the only term for a place that splits slimes back into base
  slimes. It replaces "defusing spot" (and "split object").
- **Route back** is added: the route an exploration branch provides back to the
  loop.

## D76 — A test level, per-level folders, and consolidating v1 now (2026-09-28)
- The spec writer designs a **test level**. It is a compact level that
  exercises most v1 gameplay and is the testing ground for implementation. It
  is not the real first level.
- **The real first level's design comes later.** A lot has to be built and
  checked first.
- Each level gets its own folder, `levels/<id>/` (the real first level will be
  `levels/01/`), holding its objectives, its loop description and its content.
  The test level lives in `levels/test/`. How level design is run is still to
  be worked out (O59).
- **Everything except the real first level's design goes into the v1 master
  spec now.**

## D77 — Completing a level (2026-09-28)
Resolves O52.
- When a level's last basket fires, nothing ends. The loop is complete and the
  world stays open, with a **one-time celebration**. Moving on to another level
  waits for paid levels.

## D78 — Orientation (2026-09-28)
Resolves O54.
- **Landscape, locked.** Side view, like Cocoreccho!.

## D79 — The return route is part of the loop (2026-09-28)
Resolves O53.
- A section's **return route** (from its unopened frontier gate back to the
  start) is part of the loop. It has **its own camera rail**, and the idle
  camera follows its slime through it like anywhere else.
- A return route **may carry exploration opportunities**.
- **Level rule:** opening a later frontier gate must never make such an
  exploration opportunity unreachable. (What "reachable" means is up to each
  level's design.)
- Term adopted: **return route** (it was proposed in draft).

## D80 — Idle and screensaver zoom, and framing zones (2026-09-28)
Resolves O64. Refines D60 and D62.
- Screensaver mode and the idle camera use **the same zoom**. It doesn't stack
  with anything.
- While the idle camera or screensaver mode is locked on a slime, **framing
  zones are ignored**.
- When the child takes back control, framing resumes if the camera's centre is
  still inside a framing zone.

## D81 — Species look: colour only in v1 (2026-09-28)
Resolves O56.
- In v1, species differ by **colour only**.
- Later versions may give each species its own texture or styling, and may
  offer other colour palettes (for colour-blind players). Behaviour quirks per
  species were already planned for later.

## D82 — Performance targets (2026-09-28)
Resolves O57.
- **60 fps** on the reference phone. **At least 30 fps** on the floor phone in
  the worst case of 200 slimes on one screen.

## D83 — A wrong parent code (2026-09-28)
Resolves O55.
- The entry shakes and clears. Tries are unlimited, but 5 wrong tries in a row
  bring a 30 s wait.
- The code prompt closes after about 15 s with no input. The settings screen
  also closes by itself after a short time with no input.

## D84 — If the parent declines screen pinning (2026-09-28)
Resolves O58.
- The game still works without pinning, every parent button still asks for the
  code, and the setup screen explains the difference.

## D85 — When the app asks for screen pinning (2026-09-28)
Resolves O60.
- The app asks for pinning **each time it opens**. Android's own confirmation
  can't be skipped, and the parent is normally the one opening the app and
  handing the phone over.
- Setup recommends turning on Android's **"Ask for PIN before unpinning"**,
  since otherwise anyone can unpin with a gesture.

## D86 — The frontier set once its gate is open (2026-09-28)
Resolves O63.
- Once a frontier gate has opened, its switch and basket are **inert for
  good**. They may be removed or turned into a landscape feature; that is up
  to art and level design.

## D87 — What a level's folder is for (2026-09-28)
Resolves O59.
- `levels/<id>/` is mostly storage for that level's **design requirements and
  the discussion about it**.

## D88 — Size forks are a kind of filter (2026-09-28)
Partly resolves O61; the version question stays open (O61).
- A fork that sends slimes down a branch **by size** is a filter, like the
  species filter, but by size. "Filter" now covers both.

## D89 — Filters are v2 (2026-09-28)
Resolves O61.
- Both filters, by **species** and by **size** (D88), come in **v2**.
- In v1, the only fork in the loop is the frontier switch, and every size
  travels the loop the same way. Size still matters in v1 through basket
  weight, and through bigger free slimes jumping higher off the loop.
- The level rule "different sizes may take different forks" applies from v2.

## D90 — Edge buttons on the rails (2026-09-28)
Resolves O66. Refines D33 and D79.
- The **right** edge button always moves the camera **forward** along the
  loop, and the **left** button **backward**, whatever the direction on
  screen.
- On a return route, which runs right to left on screen, "forward" carries the
  camera round the turn at the frontier and back toward the start. Holding
  one button long enough goes all the way round the loop.

## D91 — The master spec's proposed defaults are approved (2026-09-28)
- The user approved every default tagged (proposed) in the v1 master spec and
  access model. They are now settled:
  - calls also pull train slimes off the loop; a call radius of about half
    the screen width;
  - a tap at the top of the screen only reveals the parent buttons;
    generous hit areas on objects;
  - a switch stays flipped until tapped again; a basket filled off screen
    waits until it's in view to play its reward and fire; on opting out, the
    slimes inside go back to the loop and the basket empties;
  - plain signposts at forks in v1; large signposts in v2;
  - v1's species colours also differ in lightness;
  - during bedtime, taps show a ripple only, the edge buttons and "wake
    early" are hidden, and the usual screen timeout applies;
  - deleting a level's save asks for a second confirmation; the world and
    the session keep running while a parent prompt is open;
  - screensaver mode starts on the idle camera;
  - the test level never ships;
  - saves record the level's version and use stable IDs, are written
    atomically, and keep one backup;
  - seeded randomness and a test mode (Linux and debug builds only), with
    the test level's fixture saves;
  - fully offline: no analytics, no ads, no network permission;
  - the technical direction: soft slimes as spring rings drawn with a
    blending shader, sleepers not simulated until touched, routes back drawn
    as editor paths, framing zones as a level component, one shared rule
    format for components, and the test-environments table.

## D92 — The declared-intent contract binds v1, with three guarantees (2026-09-28)

- The contract in the declared intent (ATD) binds **v1 only**. Later versions
  may revise it.
- Its first guarantees are the three rules the documentalist proposed:
  **saves are never wiped**, **no network connection**, and **no in-app
  purchases**. Paid levels and billing come with later versions, whose
  contracts can change the last two.
- Why: the user said the contract only binds v1, so rules that are true for
  v1 can be guaranteed even if a later version changes them.

## D93 — Vector look: curves baked into polygons and lines (2026-09-28)
Partly resolves O14 (the vector rendering approach). Spike: chunk 2,
`docs/dev/spike-vector-look.md`.
- Terrain and level art are drawn from **Path2D/Curve2D curves** authored in
  the editor and **baked at load into Polygon2D fills and Line2D outlines**.
  They stay crisp at 4× zoom and cost about the same to draw as a sprite.
- **Imported SVG textures are not used for level art:** Godot turns them into
  images at import, and they blur when the camera zooms in.
- **No vector plugin:** none renders vector shapes at runtime for Godot 4.7.
- A terrain component bakes one curve into both the drawing and the collision
  shape, so an author draws one curve per terrain piece.
- Why: crisp at every zoom, fits the flat, curved, high-contrast look (D34), and
  adds no dependency.

## D94 — Slime simulation: approach, renderer, points per ring, native contingency (2026-09-28)
Partly resolves O14 (desktop only; the phones are still to measure). Spike:
chunk 1, `docs/dev/spike-soft-slimes.md`.
- **The ring-of-springs slime with the species-field blend shader is a go.**
  On the desktop it is stable at 200 slimes, still and moving, and drawing
  costs about 1 ms of GPU time.
- **The renderer stays Compatibility.** Forward Mobile gave the same look and
  frame rate. To confirm on the phones.
- **Points per ring:** 12 for size 1, 15 for size 2, 18 for size 3.
- **The simulation tick is the bottleneck.** In GDScript it takes about 11 ms
  per tick for 200 slimes at 16 points on the desktop; a line-for-line C++
  port is 20–25× faster. Extrapolated (not measured) phone costs put pure
  GDScript over budget for 200 slimes on one screen on both phones.
- **Chunk 5 builds the simulation in GDScript** with the spike's
  struct-of-arrays layout: packed arrays, rings as ranges of points, Verlet
  integration with position constraints, and a grid for contact pairs. The
  tick can then move to a GDExtension without changing its interface.
- **Native code is the planned contingency,** decided at the first
  measurement on the reference phone (Galaxy S20 FE), which needs the Android
  build (chunk 20). If adopted: godot-cpp, `-ffp-contract=off` so ticks repeat
  exactly, and the Android NDK in chunk 20.
- **Cheaper fallbacks come first:** resting slimes stop being simulated
  (contact solving included) until disturbed, since the 200-on-screen case
  is mostly still (level rule 16); fewer points when zoomed out; a 30 Hz tick.
- **Still pending:** measurements on the reference phone now and on the floor
  phone once bought, and with them the floor decision (D71). The 200 cap stays
  (D67).
- Why: the approach looks right and holds at the cap; building the layout
  for native code from the start keeps the contingency cheap without
  committing the project to a C++ toolchain before a phone has been measured.

## D95 — Proposed defaults for the UX review's interaction details (2026-09-28)
**Proposed, pending the user's approval.** Addresses O67–O77, which stay open
until the user approves or changes these defaults in one pass. Set while the
user was away, so the build chunks they block (7, 9, 12, 17, 18, 20) can
close: the build follows them unless the user overrules them, as with the
defaults later approved in D91. They are written into the v1 master spec and
access model, tagged (proposed).
- **O67, second finger:** a touch that starts while another finger is down
  gets nothing at all, not even a ripple, and stays ignored until it lifts,
  even after the first finger lifts. "The first touch wins" stays absolute.
- **O68, reopening the app:** it resumes where it was, in the state the
  stored timers give: a running session (wind-down included), bedtime with
  the rest of its cooldown, or screensaver mode if the cooldown ran out
  meanwhile (sunrise isn't replayed). Screensaver mode only when no session or
  bedtime is running. Tilt's neutral is taken again when a session resumes.
- **O69, which taps start a session:** a tap that reaches the world, on open
  ground (a call) or an object (it operates it). Not the parent zone or an
  edge button; the edge buttons still move the camera in screensaver mode.
- **O70, edge-button press:** at least one fixed step per press; the camera
  keeps moving at a steady pace while the finger stays down and eases to a
  stop on release. Leaving a framing zone takes about 1 s of holding; a short
  press stays inside. Holding is the same button pressed longer, not a new
  gesture.
- **O71, first-play hint:** the 10 s count from the first frame the world
  shows on a fresh save of the level (screensaver mode right after setup),
  and again each time the world shows while the hint is due. The first call
  marks it done in the level's save, so deleting the save brings it back.
  Not shown during bedtime.
- **O72, deleting the running level's save:** the level reloads fresh at
  once, as on a fresh install; the hint is due again and the celebration can
  play again. The session or bedtime and their timers carry on. Deleting
  removes the backup too.
- **O73, forgotten code:** with no screen lock, "forgot the code?" explains
  that clearing the app's data is the only way and that it erases all
  progress. Cancelling or failing Android's prompt returns to the code prompt,
  with nothing changed and no wrong try counted. The new code is typed twice;
  the parent is then back at the code prompt for the action they started,
  with the wrong tries and any wait cleared.
- **O74, pinning timing:** on first launch, right after setup is completed;
  on every later launch, before the world takes a tap. Coming back from the
  background doesn't ask again. "Leave" closes the app, so the next open is a
  launch and asks.
- **O75, back without pinning:** the back gesture leaves the app as Android
  normally does; the session keeps counting and reopening resumes. Setup says
  so. The alternative, catching back alone, is left for the user.
- **O76, wrong-code wait:** the count and the end of the wait are stored on
  disk and survive the prompt closing and the app being killed. One count for
  every parent button, reset by a correct code or a code reset, starting from
  0 after a wait. "Forgot the code?" works during the wait.
- **O77, language (a guess, for the user to confirm):** parent-facing text in
  the phone's language when v1 has it, English otherwise; v1 ships English
  and French.
- Why: each follows the design stance (watching is playing, nothing to fail,
  every touch is answered, sessions end softly, simple) and the personas:
  leaving the app or deleting a save never dodges bedtime (P4.G1), a parent
  is never stuck (P4.G3, P4.G4), and the 2-year-old's poke changes nothing
  for his sister (P2.G2). The one exception to "every touch is answered" is
  the second finger (O67), where "the first touch wins" (D66) comes first.

## D96 — Native tick deferred; fallbacks first (2026-09-28)
Answers D94's question (decided at the reference phone measurement), and
amends D82's floor-phone worst case. Partly resolves O14 (the reference
phone is measured; the floor phone is not). Measurement: chunk 1,
`docs/dev/spike-soft-slimes.md`, "Reference phone (Galaxy S20 FE 5G)".
- **What the reference phone showed** (200 slimes, pure GDScript,
  Compatibility):
  - at 12 points per ring the tick alone takes about 17–18 ms cold
    (48–53 fps with nothing else in the frame), and about 27 ms once the
    phone throttles after about 4 minutes of load (33 fps, steady);
  - only 8 points per ring reaches 60 fps cold, leaving about 3 ms for the
    rest of the game;
  - the game's real tick from chunk 5 (terrain contact, friction, touch
    tracking) costs 1.7× the spike's, so about 31 ms cold and 50 ms
    throttled on this phone;
  - the phone runs the GDScript tick 2.0–2.1× slower than the desktop (3.4×
    throttled). The floor phone (A14 class) is estimated at 40–88 ms per
    tick for 200 simulated slimes;
  - drawing is not the problem: the blend costs at most 5 ms of GPU time at
    full-resolution fields and 2.6 ms at half, and the GPU works alongside
    the CPU.
- **The tick stays in GDScript**, on chunk 5's native-ready layout.
- **The cheap fallbacks come first,** built where the plan already places
  them (chunk 15, cheaper states):
  - resting slimes (a pile) stop being simulated, contact solving included,
    until something disturbs them;
  - sleepers don't simulate;
  - fewer points per ring when zoomed out;
  - slimes in a full basket are simplified.
- **The realistic worst case in play is a mostly still pile** (level rule
  16), such as a full basket plus the train, not 200 moving slimes. The
  `stress-moving` fixture stays as a measurement, not a target.
- **Amends D82 (floor phone):** at least 30 fps on the floor phone with the
  level's largest realistic pile on one screen (a full basket plus the
  train, mostly still), instead of "200 slimes on one screen". 60 fps on the
  reference phone in normal play is unchanged. The 200 cap stays (D67).
- **The native GDExtension is the documented, verified contingency:** C++
  with godot-cpp, `-ffp-contract=off`, for the Linux desktop and Android
  arm64. Its toolchain and a trivial extension are checked in under
  `native/`, documented in `docs/dev/native.md`, and kept out of the test
  suite and the exports. The simulation's GDScript interface is ready for it.
- **What would fire it:** chunk 22's measurement of the real game at the
  endgame (the bowl, a full basket, the train), cold and after 5 minutes,
  failing on either phone. Then chunk 5N moves the tick (ring solver,
  contacts, terrain contact, D97) to native code, and chunk 22 is repeated.
- **The renderer stays Compatibility** (D94). On the reference phone both
  renderers hold 60 fps on drawing alone, and Forward Mobile saves under
  1 ms of render CPU time. The Mali-GPU floor phone is still the real test
  of the choice.
- **Still pending:** the floor phone, once bought (O14), and with it the
  floor decision (D71).
- Why: the measurement is of 200 simulated slimes, the case the fallbacks
  are designed to remove, since in play most of a big crowd rests in a pile
  or a basket. The real game at the endgame is what decides, and the
  checked-in, verified contingency keeps the switch cheap if it fails.

## D97 — Slimes against curved terrain: the simulation's own test (2026-09-28)
Resolves O78, with the default it proposed.
- The slime simulation tests ring points against the **baked terrain
  segments itself**, not through Godot's collision shapes. At level load the
  baked terrain polygons (D93) become segment arrays with outward normals
  and a static grid of cells (chunk 5's `TerrainSegments`).
- This code is part of the tick, so it would move to native code with it
  if the contingency fires (D96).
- Why: it keeps the whole simulation in one place with one data layout, so
  it could move to native code in one piece; chunk 5 built it this way and it
  works on the test level.

## D98 — The parent code is never stored in plain text (2026-09-28)
- The parent code is stored only on the phone, and **never in plain text**.
- A security guarantee, already in the build plan (chunk 18) and in the
  declared intent; now also stated in the master spec (§5.8) and the access
  model.
- Why: anyone who can read the app's files (a backup, a debugging tool)
  mustn't learn the code, and with it the parent buttons.

## D99 — Edge buttons are whole-height strips (2026-09-29)
Resolves O89 and O81. The user's report from playing the build (chunk 23).
- An **edge button** is a strip over the screen's whole height, within
  **10% of the screen's width** from the left or right edge. A tap anywhere
  in it is an edge-button press: it moves the camera along the rail (right
  forward, left backward, D90; a step per press, a steady pace while held).
- The strip **takes the whole tap**: no call is issued, and no object under
  it is operated.
- The **parent zone wins where they overlap**: the top band stays the first
  tap zone, so the strips run from below it to the bottom edge.
- A strip tap still gets its ripple. While the edge buttons are hidden
  (bedtime), a tap there is an ordinary tap. In screensaver mode a strip tap
  moves the camera and doesn't start a session.
- How the strips are drawn (the arrows, any marking) stays with `ui_ux/`.
- Consequence: a sleeper or object near an edge has to be brought inward
  with the camera before it can be tapped.
- Why: the placeholder button (96 × 192 px, only the arrow) was too hard to
  hit; the user tapped the screen edge and got a call instead.

## D100 — Stuck slimes: a state with the same effect as lost (2026-09-29)
Resolves O90. The user's report from playing the build (chunk 23). The
cause stays open (O91).
- In the user's words: "it's a new state but has the same effect as lost".
  **Stuck** is its own state, distinct from lost: it isn't "lost" in the
  sense of D10, so it doesn't count against "no slime is ever lost" or "a
  free slime kept on screen is never lost". Its effect is the same as lost:
  the slime goes to the start of the loop and rides the train again. Every
  one is logged with the reason "stuck".
- **Detection:** every 30 ticks (0.5 s), the simulation looks for pairs of
  simulated slimes whose centres are closer than **a quarter of the smaller
  one's radius**. A pair found so on **4 checks in a row** (about 2 s) is
  stuck. A same-species pair that is about to fuse (sizes adding up to 3 or
  less) is never counted.
- **Which one moves:** the smaller one, on a tie the one with the higher id,
  and only a train or free slime. Sleepers, slimes in a basket and
  bedtime-asleep slimes are never moved; if neither slime of the pair can
  be moved, the pair is only logged.
- It is a safety net until the cause is found and prevented (O91).
- Why: slimes of different species sometimes end up inside one another,
  their centres identical. It isn't fusion (only the same species fuse), and
  they stay stuck.

## D101 — A call near the middle of the screen doesn't move the camera (2026-09-29)
Resolves O88. The user's report from playing the build (chunk 23). Refines
D45.
- If the call point is already inside a box **centred on the screen, 20% of
  its width by 20% of its height**, the call happens as usual (the slimes
  answer, the ripple shows) but the camera doesn't move. Outside the box,
  the call drag works as before (D45).
- The box is measured **on the screen**, so it doesn't change with the zoom.
- A new call inside the box during a drag **stops the drag where it is**.
- The camera goes back to the rails when the answering window ends, as
  after any call.
- A tap on a sleeper is a call like any other.
- Why: the camera moving right onto a call point that was already in view
  was troublesome.

## D102 — D95's defaults are approved (2026-09-29)
Resolves O67–O77. Approves D95.
- The user approved every default D95 proposed for the first UX review's
  interaction details, as written: the second finger (O67), reopening the
  app (O68), which taps start a session (O69), the edge-button press (O70),
  the first-play hint (O71), deleting the running level's save (O72), the
  forgotten code (O73), pinning timing (O74), the back gesture without
  pinning (O75) and the wrong-code wait (O76).
- **O77, the language, is confirmed:** the parent-facing text follows the
  phone's language when v1 has it, English otherwise; v1 ships English and
  French. Catching the back gesture (O75's alternative) is not taken.
- The master spec and access model no longer tag these (proposed).

## D103 — The idle camera never zooms in; tilt isn't input for it (2026-09-29)
Resolves O79 and O80. Refines D59, D62 and D80.
- **The idle zoom never zooms in.** Where the camera is already wider than
  the idle and screensaver zoom (inside a wide framing zone, such as the test
  level's tree at 0.7), the idle camera keeps that zoom.
- **Tilt doesn't count as input for the idle clock:** it neither holds off
  the idle camera nor takes control back from it. Only touches count.
- Why: the cue must read as a zoom-out, and zooming in would hide what the
  zone framed; a phone in a hand or on a lap tilts all the time, which would
  stop the idle camera from ever taking over.

## D104 — The session lives in the level's save while v1 has one level (2026-09-29)
Resolves O82. Amends the master spec's 5.10 ("the timers aren't part of a
level's save").
- The session (its phase, elapsed time and clock anchor) is kept in the
  level's save, as built in chunk 17, so a killed app resumes where it was
  (D102, O68) and the state hash covers it.
- **Deleting the level's save keeps the running session** and writes it into
  the fresh save, so deleting can't dodge bedtime (chunk 18).
- With several levels (paid levels, later), the session moves to a store of
  its own, outside any one level's save.

## D105 — Frontier sets: bedtime, a full basket, the gate's lid (2026-09-29)
Resolves O83, O84 and O85.
- **Baskets at bedtime (O83):** a basket's releases pause at bedtime and
  resume at sunrise. The slimes in it sleep in place: they stay in the
  basket, shown asleep, and sunrise doesn't move them out. A reward that is
  due or playing at bedtime waits for sunrise too, so no gate opens and no
  celebration plays during bedtime.
- **No opt-out once the basket is full (O84):** the switch stops answering
  taps from the moment the basket is full, through its reward, as built.
- **A gate's lid (O85):** "the old return route stays in the world" means it
  isn't removed; a gate may shut its entrance with a lid. Level rule 14 then
  needs another way onto that route for any exploration on it.
- Why: bedtime means nothing moves on its own (D28); a full basket is a
  promise that the gate will open.

## D106 — A fifth slime state: in a basket (2026-09-29)
Resolves O86.
- **In a basket** is a slime state of its own, beside sleeper, train slime,
  free slime and bedtime-asleep: caught by a basket's box, it doesn't hop,
  isn't the train and doesn't answer calls, in any basket, filling or full.
  It leaves only when the basket releases it, and rides the train again. At
  bedtime it sleeps in place (D105).
- The hopping tables say "in a basket (any basket, filling or full): no
  hopping", replacing "resting in a full basket".

## D107 — Resting piles keep the fixed anchor for v1 (2026-09-29)
Resolves O87.
- A slime is still when it stays within `REST_DRIFT` (1 px) of an anchor
  fixed where its count started, for `REST_TICKS` (30); a pile rests when
  every member is still at once. Kept for v1, as built.
- Chunk 22 (the performance pass) measures a bedtime pile in the open on
  both phones, and how often an awake slime hopping against a pile wakes
  it, and revisits the rule if needed. The code comment on `REST_DRIFT` is
  brought in line with the rule there.

## D108 — The build's record of chunks 15 and 16, and the build plan, approved (2026-09-29)
- **The test level as built** (`levels/test/README.md`, sections 2 and 3):
  every deviation recorded there is accepted: the cave's route back at about
  46 s, the rim over the plateau reached from its end, the shelves floating
  over the bowl, the bowl's three branches with routes back, sleeper numbers
  running to three digits, basket 3's outlet as a point, the added
  `gate2-open` fixture, and `stress-still`'s bowl pile asleep at bedtime.
- **The chunk 15 and 16 values** in `tuning.md`.
- **Off screen, a free slime with no route back near** heads straight for
  the loop when the loop is near; otherwise it stays where it is until the
  lost timer (D10) moves it (the master spec's 5.3).
- **The build plan** (`versions/v1/build-plan.md`, v9) as a whole; it is no
  longer proposed.

## D109 — Hit areas, and only what answers a tap takes it (2026-09-29)
From the UX review's answers the user approved (ui_ux Q4, Q10).
- **A child's target** (an interactive object): the hit area is the drawn
  object grown by **5 mm** on every side, and never smaller than **20 × 20
  mm**, both measured **on the screen at the current zoom**. Zooming out
  shrinks the drawing, never the hit area's floor. Replaces D91's
  "generous hit areas" with numbers.
- **An adult's target** (the code digits, the parent buttons, settings): at
  least **9 × 9 mm**.
- **Only something that answers a tap takes it.** A tap on an object that
  doesn't answer taps (a basket, a gate, a signpost) or that isn't
  answering right now (a switch while its basket is full, or inert once its
  gate is open) is an ordinary tap on the world: a call. In v1 the only
  object that takes a tap is a switch whose basket is filling.
- Why: 3-year-olds tap about 4.5 mm off a target's centre, and a floor held
  on the screen keeps objects easy to hit exactly where the zoom makes them
  small; a tap that goes nowhere breaks "every touch is answered".

## D110 — A thumb resting on an edge strip stops blocking other touches (2026-09-29)
From ui_ux Q9, approved. Amends D66 and D102 (the second finger). **To check
in a playtest.**
- A touch on an edge strip held longer than **about 5 s** keeps moving the
  camera while it stays down, but stops counting as "the first touch": the
  next touch is handled as if no finger were down, and the first-touch rule
  then applies to it as usual.
- Why: a child holding the phone in both hands may rest a thumb on a strip;
  without this, that thumb would make every other touch get nothing. About
  5 s is the longest slow tap measured at 3.

## D111 — Level rule: interactive objects sit below the parent zone (2026-09-29)
From ui_ux Q8, approved.
- **At the rails' framing, every interactive object sits fully below the
  parent zone** (the top band). The child can't operate an object under the
  band, and can't bring it lower: the call drag is the only vertical
  control. New level rule 21 in `level-design.md`.

## D112 — Without pinning, the edge strips are kept from the back gesture (2026-09-29)
From ui_ux Q5, approved. Amends D102 (O75: "the back gesture leaves the app
as Android normally does").
- The game runs in **sticky immersive mode** (no status or navigation bar),
  which lifts Android's usual 200 dp limit on the areas an app may exclude
  from the back gesture.
- **The whole edge strips are excluded from the back gesture,** so a child's
  tap that slides off a strip doesn't leave the app. Elsewhere the back
  gesture still leaves as Android normally does, and home and recent apps
  still leave. Setup's explanation of declining pinning says so.
- Only matters without pinning: while pinned, Android ignores back anyway.

## D113 — Parent surfaces: buttons, settings, setup, language (2026-09-29)
From ui_ux Q20, Q26, Q31 and Q35, approved.
- **The parent zone** is the canonical name of the band along the top of the
  screen (the spec also called it "the top of the screen", ui_ux "the top
  band").
- **Parent buttons:** they hide after **5 s** with no press; a new tap on
  the parent zone restarts the 5 s. **A tap outside an open parent surface**
  (the buttons or the code prompt) **closes it and does its normal job**: it
  calls, operates an object or moves the camera, and starts a session if it
  reaches the world. Settings and setup fill the screen, so they have no
  outside.
- **Settings close after 30 s with no input,** with a warning over the last
  10 s; any touch resets it. The same 30 s covers the screens opened from
  settings. Settles D83's "a short time, to try".
- **Setup has four steps:** welcome, the code (typed twice), what happens if
  it's forgotten, and screen pinning. **The code is saved only when setup
  finishes;** an interruption before that restarts setup from its first
  step, so no parent skips the pinning explanation. Setup carries no line
  asking the parent to show the child the first tap: that idea is parked
  for v2 with the hint (O93, ux D2, ux D7).
- **French addresses the parent as "vous".**

## D114 — The parent can see the time left (2026-09-29)
From ui_ux Q30, approved. **New v1 scope** (chunk 18).
- The time left in the session, or until sunrise during bedtime, is shown to
  the parent **only behind the code**: in the settings header, and on the
  wake-early prompt. Never on the parent buttons, which the child reveals.
- Why: a parent deciding whether to wake the slimes early, or to hand the
  phone over now, needs the number (P4.G4); the child never meets a
  countdown.

## D115 — The first-play hint's form is a v2 question (2026-09-29)
From ui_ux Q11, which the user deferred to v2.
- v1's hint stays as specified: a wordless pulsing mark near the first
  sleeper (D65).
- Parked for v2: a demonstrating hand instead of a pulse (O92); whether the
  personas and setup may count on the parent showing the first tap (O93);
  making "the first sleeper is close" measurable as a level rule (O94).

## D116 — The test level's start basin and cave framing zone as built (chunk 16) (2026-09-29)
**Approved by the user on 2026-09-29 (D120)**; first recorded as proposed
(the build's choices, recorded as with D95 and D108). Written into
`levels/test/README.md` and `tuning.md`.
- **The start basin (1.1) is rebuilt (chunk 16e):** the loop's start sits at
  0.21 screens at the top of a ramp, with a pocket behind it where the first
  slime starts; the loop's first stretch runs on a raised terrace; the
  slides' shared tail runs under the terrace and up the ramp into the
  pocket. `FirstLedge` is at 0.42 to 0.5 (top y 335), the first sleeper at
  0.46 (0.27 screens from the first slime, "about a quarter of a screen"
  rather than "about a third"). The split zone spans 0.03 to 0.54, past the
  first sleeper's ledge, so only base slimes pass under it.
- **Why:** the old tail ran home along the basin floor against the loop's
  first stretch and shoved the outgoing train back; slimes queued there
  fused past the split zone and a size 3 crawled under the first sleeper's
  ledge. A train slime was lost as stalled (D118) in 5 of 10 fifteen-minute
  sessions with no input, so DoD 1 failed. After the rebuild, 18 sessions
  (seeds 1 to 8 and 16, from `gate1-open` and `gate2-open`) lost none.
- **`s2.frame.cave` (chunk 16d):** a framing zone over the cave branch
  (centre 11.25 screens, y -150, 1.3 screens by 500 px, zoom 0.7, offset
  (0, -140)), so the rails' view shows the loop and the cave pocket's
  sleepers at once (rule 9).
- **`stress-still`** rests about 670 ticks (about 11 s) after loading, not
  about 8 s: 16d's terrain-contact fix changed how the pile settles.

## D117 — Where a return route meets the start: the test level's lesson (2026-09-29)
**Approved by the user on 2026-09-29 (D120)**; first recorded as proposed.
From the start basin jam (chunk 16, D116). A constraint on O22's answer, not its answer: O22 stays open, and
the test level's slides are still a placeholder. If approved, a candidate
for a level rule in `level-design.md`.
- **A return route delivers slimes into the start behind the loop's start,
  travelling the loop's way.** It never runs along the loop's first stretch
  against the flow: slimes coming home join behind the train, they don't
  meet it head on.
- **Nothing a base slime must be called up to overhangs the loop where
  larger slimes pass.** A ledge low enough for a called size-1 slime to hop
  onto is too low for a size 2 or 3 to pass under at its hop's height, and
  one high enough for them is out of the called slime's reach. Such a ledge
  sits where only base slimes pass (inside the split zone's reach, as the
  test level's first sleeper does) or off the loop's path altogether.

## D118 — A train slime that stalls (2026-09-29)
**Approved by the user on 2026-09-29 (D120)**; first recorded as proposed.
Records the build's rule (chunk 6's placeholder, `Train`, unchanged since);
the spec had no rule for it: "lost" (D10) covers free slimes only. Raises
O95. **The "nothing happens to it in play" bullet is superseded by D121:**
a stalled train slime is moved to the start of the loop.
- **Stalled:** a train slime whose progress along the loop hasn't advanced
  24 px in 60 s, on screen or off (parked slimes included), or whose centre
  leaves the level's bounds (the terrain and the loop, plus 64 px, plus
  2000 px above). The build logs it in the train's lost log with the reason
  `stalled` or `out_of_bounds`, once per slime.
- **Nothing happens to it in play:** it stays a train slime where it is
  and the train keeps steering it. Unlike a lost (D10) or stuck (D100)
  slime, it isn't moved to the start of the loop. The log is for the tests
  and the debug view.
- **DoD 1's "no slime ever becomes lost" includes it:** the whole-level
  DoD 1 test fails on any entry in the train's lost log.
- "Stalled" is the spec's term for it (the build says "lost as stalled");
  "lost" keeps D10's meaning.

## D119 — A train slime on a dip floor waits at most 5 s for a partner further back (chunk 16f) (2026-09-29)
**Approved by the user on 2026-09-29 (D120)**, the 5 s wait as built, not
the alternative below; first recorded as proposed (the build's choice,
recorded as with D116). Refines the dip nudge's gathering (D20); written into
`tuning.md`, tagged (proposed).
- **The rule as built:** a train slime on a dip floor waits without limit
  only for a partner directly behind it (no other train slime between
  them). For a partner further back, with a train slime between them, it
  waits at most `DIP_WAIT_SECONDS` = 5 s, then moves on.
- **Why:** since the start basin's rebuild (D116) the train reaches the
  dips as a queue whose species alternate, so a partner usually has a slime
  of another species between them and can't catch up. Waiting for it
  without limit held the whole queue on the floor and stalled train slimes
  (D118): DoD 1 failed (`gate2-open` seed 6 held 17 train slimes in the
  bowl for 6 minutes). With the limit, 8 alternating slimes on the Meadow
  dip all leave the floor in 33 to 58 s, none stalled, and 18 fifteen-minute
  sessions lose none.
- **Why a 5 s wait and not none:** it is what keeps the `bump` fixture's
  3 + 1 bump (the size 1 ahead of the size 3 waits for a size 2 behind it,
  which holds the 3 + 1 pair together long enough to bump).
- **The alternative, for the user:** wait only for the partner directly
  behind, with no limited wait for one further back. The queue passes
  faster (19 to 26 s instead of 33 to 58 s) and the rule is simpler, but
  the `bump` fixture no longer shows the 3 + 1 bump, so its requirement
  (both bumps) would drop to the 2 + 2 only, or the fixture would need a
  new layout.
- **The `bump` fixture as built now:** both bumps within 20 s on seeds 1
  and 3 to 7 (the end-to-end test runs seed 5); seeds 2 and 8 show the
  3 + 1 bump only.

## D120 — Chunk 16's record approved: D116 to D119 (2026-09-29)
The user approved chunk 16's pending items as written.
- **D116,** the test level's start basin and cave framing zone as built,
  and `stress-still` resting after about 11 s.
- **D117,** where a return route meets the start: a constraint on O22's
  answer. O22 itself stays open for the first level's design.
- **D118,** the stalled train slime (the term, the measure, and DoD 1
  counting it as a failure). Its "nothing happens in play" part is replaced
  by D121, which closes O95.
- **D119,** the dip nudge's 5 s wait for a partner further back, as built.
  The alternative (wait only for the partner directly behind) is not taken,
  so the `bump` fixture keeps asserting both bumps.
- The spec no longer tags these (proposed): the master spec (5.2, the
  vocabulary, Definition of done 1, Known gaps 2), `slimes.md`, `concept.md`,
  `tuning.md` and `levels/test/README.md`.

## D121 — A stalled train slime is moved to the start of the loop (2026-09-29)
Resolves O95. Approved by the user (spec-writer's suggested default).
Replaces D118's "nothing happens to it in play".
- **The safety net:** a stalled train slime (D118: no 24 px of progress
  in 60 s, or its centre out of the level's bounds) is moved to the start
  of the loop and rides the train again, as a lost (D10) or stuck (D100)
  slime is. It stays "stalled" in the log, not "lost".
- **Each case is logged,** with the reason `stalled` or `out_of_bounds`, as
  stuck cases are; the 60 s count starts again from the move, so a slime
  that stalls again is moved and logged again.
- **A slime asleep at bedtime is never counted as stalled or moved,** as
  with stuck (D100).
- **DoD 1 keeps its meaning:** the safety net is for play, not a pass. The
  whole-level DoD 1 test still fails on any stalled train slime in a
  15-minute session with no input.
- **Why:** P1.G4 ("never get stuck"): a train slime wedged for good would
  otherwise stay where it is.
- **Carried forward, not open:** whether 24 px in 60 s is still the right
  measure once the real level's return routes exist is a tuning value to
  recheck on the first level (`tuning.md`, master spec Known gaps 7).
- Built as chunk 23's item 23.13, next to 23.3 (the stuck safety net).

## D122 — The coding-rule health review runs last (2026-09-29)
The user's call on `CODING_RULE.md`'s health and clean-up list: it runs as
the build plan's closing step, after chunk 23, not now.

## D123 — Chunk 23 runs next; a level-design toolkit; D117 becomes level rule 22 (2026-09-29)
The user's calls on 2026-09-29.
- **Chunk 23 (small issues, 23.1 to 23.13) runs next, before chunk 18.**
  It used to run after chunk 22, with 23.5 (baskets at bedtime) pulled
  before 22. Why: its items are mechanics fixes and decided behaviour, and
  running it before 22 means chunk 22 measures the finished behaviour
  (baskets at bedtime, the safety nets). The list stays open: new reports
  are still added. Chunk 23 now depends on 17 and 16, and chunk 22 also on
  23. It runs as sub-chunks: 23A safety nets (23.3, 23.13), 23B taps and
  strips (23.2, 23.6b, 23.8), 23C camera (23.1, 23.4, 23.10, 23.12), 23D
  bedtime baskets and the celebration's mark (23.5, 23.11), then 23E
  objects and taps (23.6, 23.7, 23.9).
- **A new chunk, "LD. Level-design toolkit",** asked for by the user. It
  runs in parallel with chunk 23. It is technical (tooling, no Definition
  of done item), so it skips the ATD steps. It brings tools (a level-rules
  checker usable on any level, a new-level scaffolder, and other tools
  that make level design easier), a tutorial for level designers in
  `docs/level-design/`, and project skills in `.claude/skills/`. Its
  content and done-when are in the build plan.
- **Decoration** (non-simulated scenery) had no spec: O96 opens, with a
  proposed default (decoration never collides, never takes a tap, never
  hides an interactive object or a hint). The LD chunk's decoration tools
  build to it until the user decides.
- **D117 becomes level rule 22** in `level-design.md` (approved: "agreed").
  A return route delivers slimes into the start behind the loop's start,
  travelling the loop's way, never along the loop's first stretch against
  the flow; and nothing a base slime must be called up to overhangs the
  loop where larger slimes pass. O22 stays open (what a return route is
  made of); the rule constrains its answer. The master spec's level rules
  (5.11), its Known gaps 2, the test level's rules checklist and O22's note
  now point to it.
- **D121's three details are confirmed by the user,** not only approved as
  a suggested default: each case is logged; the 60 s count starts again
  from the move; a slime asleep at bedtime is never counted as stalled or
  moved. Item 23.13 builds them as written.
- **The coding-rule health review stays the plan's closing step** (D122),
  after chunk 23 and the rest of the plan.

## D124 — What chunk 23A to 23D chose where the spec was silent (2026-09-29)
**Proposed; waits for the user's approval.** The build's own values and
choices from sub-chunks 23A (safety nets), 23B (taps and strips), 23C
(camera) and 23D (bedtime baskets and the celebration's mark). Written into
the master spec (5.1, 5.2, 5.4, 5.5, 5.6), `slimes.md`, `tuning.md` and
`levels/test/README.md`, tagged (proposed).
- **Stuck (23A, D100):** "can't fuse" means couldn't fuse right now:
  another species, sizes over 3, or one of the two not awake, so a
  same-species sleeper inside a train slime counts as stuck (the sleeper
  is never moved). The move comes at the fourth check, 1.5 s after the
  first (checks at 0, 30, 60, 90 ticks), not quite D100's "about 2 s".
- **Landing at the start (23A):** a stuck or stalled slime takes the first
  free spot of 8 at the start of the loop, one slime width apart. The stuck
  and stalled logs keep the last 64 cases each.
- **Millimetres (23B):** the desktop and test mode convert at the reference
  phone's density; a phone reporting a density of 0 or less logs an error
  and uses the reference density.
- **Resting thumb (23B, D110):** "about 5 s" is 300 ticks; only a strip
  touch taken as the first touch can become a resting thumb.
- **Edge-strip arrow (23B):** a placeholder 45% by 80% of the strip's
  width, until `ui_ux/` designs it.
- **Call dead zone (23C, D101):** a point on the box's edge counts as
  inside; a dead-zone call while the camera eases to a stop after an
  edge-button press lets the ease finish.
- **Showing a gate open (23C):** the glide is straight, at an even pace,
  1.5 s, to the rail point nearest the gate's centre; a gate is in view
  only when its whole box is; no show starts while an edge button is
  held; a show replaces a call drag in progress, ends an idle or
  screensaver follow and restarts the idle clock (the idle camera can take
  over again 45 s later).
- **Baskets at bedtime (23D, D105):** a basket reaching its quota during
  bedtime becomes full only at sunrise; a celebration playing when bedtime
  begins pauses and plays the rest at sunrise.
- **The celebration (23D, ux D4):** the lasting mark appears once the 4 s
  burst ends; the double hop is 2 hops at 0.6 of a normal hop's strength
  (about 50 px, about 0.5 s each); the mark is placeholder bunting (sizes in
  `tuning.md`), its look ux-writer's.
- **Not settled by the build, for `ui_ux/`:** slimes asleep in a basket
  have no asleep look yet (only the dusk tint); D105's "shown asleep" waits
  for a design.
- **Save format, pending the user's approval** (`CODING_RULE.md` §4 asks
  for it on any save-format change). Three additive changes; the format
  number stays 1 and older saves still load:
  1. an optional key `transient.frontier.celebration_hops` (absent means
     no double hop playing) (23D);
  2. the camera's transient block gains `show_distance` and `show_tick`,
     also in the state hash, with safe defaults when absent (23C);
  3. an optional key `stuck_slimes` (the stuck log), and the train's log
     key renamed `train.stalled` (an old `train.lost` key is ignored) (23A).

## D125 — Chunk 23A to 23D's record approved: D124 and the save format (2026-09-29)
The user approved D124 as written ("as for the rest i approve").
- **D124's values and choices,** every one: stuck means couldn't fuse right
  now (a same-species sleeper inside a train slime counts); the move at the
  fourth check, 1.5 s after the first; the first free spot of 8 at the
  start of the loop; the stuck and stalled logs of 64 cases; millimetres at
  the reference phone's density on the desktop, in tests, and on a phone
  reporting none; the resting thumb's 300 ticks, first touch only; the
  placeholder strip arrow; the dead zone's edge counting as inside and the
  ease finishing; how a gate is shown opening; a basket full only at
  sunrise and a celebration paused by bedtime; the lasting mark after the
  burst, the double hop and the placeholder bunting.
- **The three save-format changes,** additive, the format number staying
  1: `transient.frontier.celebration_hops`; the camera's `show_distance`
  and `show_tick`; `stuck_slimes`, and the train's log key `train.lost`
  renamed `train.stalled` (an old `train.lost` key is ignored).
- **The numbers stay to try,** as chunks 15 and 16's did (D108): approved
  as starting values, not confirmed in a playtest.
- **Still with `ui_ux/`:** the strip arrow, the bunting, and the asleep
  look of slimes in a basket stay placeholders or undesigned; approving
  D124 doesn't design them.
- The spec no longer tags these (proposed): the master spec (5.1, 5.2,
  5.4, 5.5, 5.6), `slimes.md` and `tuning.md`.

## D126 — What chunks 23E and LD1 chose where the spec was silent; the spec catches up on two approved points (2026-09-29)
**Parts 1 and 2 are proposed and wait for the user's approval.** Part 3
catches the spec up with behaviour the user already approved; part 4 is
the build order. Written into the master spec (5.1, 5.2, 5.4, 5.11),
`concept.md`, `slimes.md`, `interactive-objects.md`, `level-design.md`,
`tuning.md`, `levels/test/README.md` and the build plan, with the proposed
parts tagged (proposed).

**1. Chunk 23E (23.6, 23.7, 23.9), its own readings (proposed).**
- **A sleeper's tap margin:** a tap within 24 screen px of a sleeper's
  drawing is a tap on it (a call centred on it). D109's 20 × 20 mm floor
  isn't used: D109 sizes objects' hit areas, and a sleeper is a slime. A
  20 mm floor would turn any tap within about 1 cm of a sleeper into a
  call centred on the sleeper.
- **Hit areas (D109):** the drawing grown by 5 mm on every side, then, if
  still smaller, grown **about its centre** to 20 × 20 mm, at the current
  zoom. The spec didn't say where the floor sits; 23E centres it on the
  object.
- **Overlapping hit areas:** only an object answering a tap right now can
  take one (D109), so the nearest centre is compared among those only.
  Where a filling basket's switch overlaps a basket, the switch takes the
  tap even when the basket's centre is nearer.
- **Level rule 21, which views count:** the settled views of every
  section's outgoing route's rails, with the gates before it open and the
  framing zones in place, on the reference phone's screen (1440 × 648
  viewport px, where the parent zone is about 67 px). The return routes'
  rails (the slides) aren't checked: seen from them, the camera puts the
  tops of `s1.basket`, `s1.gate`, `s2.gate`, `s2.switch` and `s3.switch`
  in the parent zone or off the top of the screen. The rule's wording ("at
  the rails' framing") doesn't settle whether a return route's views
  count. The consequence to weigh: from a slide's rail the child may see
  switch 2 or 3 under the parent zone, where a tap on it reveals the parent
  buttons; the switch can be tapped from the outgoing route's rail.
- **Level rule 21, what fails and what counts:** an object framed above
  the top of the screen fails, as one whose top is in the parent zone
  does. The objects checked are every switch, basket and gate. Baskets and
  gates don't answer taps (D109), so this is stricter than the rule's
  "so the child can operate it"; signposts and sleepers aren't checked.
- **The edge strips on test mode's window (D99):** on test mode's default
  1152 × 648 window, with the camera aimed at basket 1, switch 1's centre
  is inside the left strip; on the reference phone's 1440 px wide screen it
  is clear. This refines chunk 23B's note in the test level. No change
  proposed.

**2. Chunk LD1, the level-design toolkit's tools (proposed).**
- **A real break of level rule 22 (b) on the test level.** The level-rules
  checker found that `s2.sleeper.15` and `.16` rest on
  `Terrain/Dip2Hollow`, which overhangs the loop from x 9.93 to 10.0
  screens, outside the split zone. Its underside is 110 px over the loop's
  ground, where a size-3 hop reaches about 130 px (the hop is clipped by
  about 20 px but not stopped, and rule 2's laps pass). Its floor is 130 px
  up, and a called base slime reaches about 133 px. The checker reports
  it and fails on the test level until it is fixed.
- **Proposed fix (the orchestrator's default):** move the hollow so it no
  longer overhangs the loop's path, then regenerate the fixtures. Raising
  it isn't the fix: its floor would then be out of a called base slime's
  reach. A small test-level fix, planned before chunk 18.
- **Rule 18's threshold:** the checker takes "close" as within a third of
  a screen, the distance the test level first planned for its first
  sleeper (it was built at 0.27, D116). Making rule 18 measurable is still
  O94 (v2). This is the checker's working threshold until O94 is settled.
- **Rule 22's thresholds:** (b)'s come from the simulation's constants: a
  called base slime reaches about 133 px, and a size-3 train slime's hop
  top is about 130 px. They follow the constants if those change. (a)'s
  numbers (48 px from the loop's first 1.5 screens, an 80 px join) are the
  checker's. All are in `docs/dev/level-tooling.md`.

**3. The spec catches up (approved behaviour, not proposals).**
- **The celebration's double hop** (ux D4, Q15; its values in D124,
  approved in D125): every awake slime on screen does a double hop during
  the burst. Master spec 5.1 didn't say so; it does now.
- **Lost free slimes land like stuck and stalled ones:** the build uses
  the same move (the first free spot of 8 at the start of the loop, one
  slime width apart) for a lost free slime too. Master spec 5.2 gave that
  landing for stuck and stalled slimes only; it now names all three.

**4. The build order.** Chunk 23 (23A to 23E) is done once 23E merges.
Chunk LD1 (the tools) is done; LD2 (the tutorial and the project skills)
is in progress. Next, a small test-level fix for rule 22 (b), then chunk
18.

## D127 — Chunks R22 and LD3 as built; the test level may not be finishable from fresh; rule 20 and numbering; lexicon catch-up (2026-09-29)
**Parts 2 (the fixture sidecar and rule 12's line), 3 and 4 are proposed
and wait for the user's approval** (the user reviews them all on
2026-09-30: simple defaults, no long option lists). Part 1 is D126's
proposed fix, as built; part 5 names terms already in use. Written into
`level-design.md` (rules 12 and 20), the master spec (5.11, rules 12 and
20), `levels/test/README.md`, the build plan and `concept.md`'s
Terminology table, with the proposed parts tagged (proposed).

**1. Chunk R22 as built (D126's proposed fix).** `Terrain/Dip2Hollow`
moved from the second dip's near rim (x 9.93 to 10.09, over the loop) to
over its far slope, reached from the far rim: outline (10.26, -155),
(10.28, -135), (10.42, -135), (10.42, -115), (10.26, -115), a lip at the
back, open toward the far rim. `s2.sleeper.15` moved from (9.97, -174)
to (10.3, -159), `s2.sleeper.16` from (10.05, -174) to (10.38, -159).
Stable IDs unchanged and still numbered left to right. The level-rules
checker passes rule 22 on the test level (22 PASS, 0 FAIL). A called base
slime wakes `.16` from the far rim; `.15` only size-2 and size-3 callers
wake, from about half the spots (see part 3). Fixtures regenerated.

**2. Chunk LD3 as built (the toolkit's gaps).**
- **The scaffolded skeleton is playable:** each section has a dip with a
  hollow on each rim, two sleepers in each, reached from the rim; section
  1 opens with same-species pairs. Its own test plays section 1 to its
  basket full with scripted calls.
- **The progress estimate:** a static check, under level rule 12, of
  whether each section's basket quota is reachable from what a called
  slime can wake by then (reach by size, fusion of same-species slimes up
  to size 3). It gives **warnings**, not FAILs: it can't see climbs or
  lips, so play is the proof. Also in the level report.
- **`tools/level.sh`** wraps the tools (check, report, new, fixture,
  bench); **stale fixtures** are found from the saves themselves; the
  **bench** runs on any level.
- **A fixture sidecar's `camera` may be a stable ID** as well as `[x, y]`
  (the camera starts nearest that thing). Additive: every existing sidecar
  still works. A change to the test fixtures' format only, not to player
  saves (proposed).
- **Rule 12 gains a line (proposed):** each section's basket can be filled
  by play from the slimes that can be woken by then, starting from a fresh
  game. A basket nobody can fill opens nothing, so this reads as part of
  the rule; the checker only warns on it, as above.

**3. Finding: the test level may not be finishable from fresh (proposed
fix).** The progress estimate warns on all three sections of the test
level, and probes back it. In section 1 only `s1.sleeper.01` (B) and
`s1.sleeper.15` (C, from the fusion dip's rim) are within a called base
slime's reach; with A, B and C awake nothing fuses, so 3 base slimes are
available against basket 1's quota of 6. Hill, tree and frontier-ledge
sleepers didn't wake with one to three base slimes called under them.
Sections 2 and 3 warn as a consequence; also, since R22, `s2.sleeper.15`
is 0.2 screens from its rim, beyond a base slime's sideways hop (150 px).
The existing tests didn't see it: they start later sections from
fixtures, and nothing plays basket 1 from fresh.
- **Proposed default:** a small chunk, **TL1**, reworks the test level's
  sleeper placement: ledges lowered or moved within a called slime's
  reach, same-species pairs early in section 1, stable IDs kept. Done
  when the checker gives 0 warnings and a scripted play from `fresh`
  fills basket 1 (and baskets 2 and 3 from `gate1-open` and `gate2-open`).
  Fixtures regenerated. It runs next, before chunk 18.
- **A consequence to weigh:** keeping every stable ID while moving
  sleepers may break the left-to-right numbering the checker asks for
  (rule 20). The test level is never released, so renumbering is allowed
  (part 4), but moves that keep the order are preferred: fixtures and
  tests name sleepers by ID.

**4. Rule 20 against the checker's numbering (proposed).** The checker
asks each section's sleepers to be numbered `.01` to N, left to right,
with no gaps. After release that conflicts with "keep the stable IDs": a
sleeper added between two others can't take a number in order without
renumbering. Default: a released level keeps a list of its released
stable IDs (for example `levels/<id>/released_ids`). Every released ID
must still exist; new sleepers take numbers above the highest released
one in their section; the order and gap checks apply only to unreleased
IDs; removing a released ID is allowed only with a `level_version` bump
and a save migration. A small checker change, due before the first level
is released; not test-level work (the test level is never released).

**5. Lexicon.** `concept.md`'s Terminology table gains the terms used
across the specs and the level-design docs without an entry: base slime,
frontier set, quota, trapdoor, (a basket's) outlet, (a gate's) lid,
loop's start, start basin (its pocket, ramp and terrace), outgoing route
(the scene's outgoing segment), exploration branch, camera rail, stable
ID, fixture, test mode, skeleton. Each matches the existing definitions;
none changes behaviour.

**6. The build order.** Chunk 23 is done (23E merged). Chunk LD is done
(LD1, LD2, LD3). R22 is done. Next, TL1 (proposed), then chunk 18.

## D128 — Chunk 24: the user's second round of playtest issues (2026-09-29)
**Proposed; waits for the user's approval** (the user reviews on
2026-09-30; asked for pragmatic defaults, "it's a kid game"). The user
reported, from their own testing: nothing major gameplay-wise; the frame
rate drops a lot in the last section (hence the debug overlay's fps and
slime counts, built the same day: the user wants hard data); basket 3's
quota needs so many slimes that its display is unreadable ("another
display when more than ten slimes are requested, some pie per 10 slimes
for example"); and a basket, once its gate has opened, doesn't let its
slimes leave and rejoin the loop. The user asked for a new chunk after
all the others, where their next reports will go. Written into the build
plan (chunk 24), the master spec (5.4, proposed lines), `tuning.md`,
`interactive-objects.md`, `concept.md`'s Terminology table and the open
questions (O97, O98, a note on O62).

**1. Chunk 24, an open list, last before the health review.** It runs
after chunk 22 (and 5N if it runs) and before the coding-rule health
review, which stays the very last step (D122). Its items are numbered
24.1, 24.2… like chunk 23's; the user's next play reports are appended
there. *A tension, raised as O97:* chunk 23 was moved before chunk 22 so
the performance pass would measure the finished behaviour (D123); 24.1
(section 3's frame rate) is close to chunk 22's own work, and 24.3 (a
basket that never empties) changes the endgame chunk 22 measures. The
default keeps the user's order; 24.1 closes with a measurement alone if
chunk 22 has already fixed the cause.

**2. 24.1, the frame rate in section 3: measure, then fix.** The debug
overlay (fps; slimes on screen, simulated off screen, parked) and the
level bench on section 3's fixtures, plus a new one with basket 3 at 59
of 60 not at bedtime, before and after, recorded in `docs/dev/`. Leads,
not conclusions: the bench already reads about 15 ms per tick for
`stress-moving` on the desktop; pair checks as section 3 wakes; drawing
at the bowl's zoom 0.5; basket 3's pile not resting or parked; slimes
cycling through basket 3 (item 3 below). No behaviour change; a cost that
is the GDScript tick itself is chunk 5N's ground (D96). **Target
(proposed):** a steady 60 fps on the desktop (test mode's 1152 × 648
window) through section 3 in normal play, and at most 8 ms per tick at
p95 on the section 3 bench cases, `stress-moving` excepted (a
measurement, D96). The phones' targets stay [DoD 30], chunk 22's.

**3. 24.2, a quota above 10 shown as quota pies.** Up to 10, one outline
per unit of weight as now. Above 10, one pie per 10 of weight, the last
holding the rest; one slice per unit, filling in order in the caught
slime's colour, a size-3 slime filling three slices (across two pies if
it has to); a full pie stays full while the basket fills. The reward,
the release and the inert state follow ux D4 Q10 for outlines and pies
alike (pulse; slices empty one by one as the slimes leave; gone once
inert). Readable: the row fits within the basket's width, each pie at
least 6 mm across on the reference phone's screen at the basket's
framing zoom. The look is ux-writer's to draw (flagged for ux D4 Q10);
placeholder art until then. *Why a pie per 10:* the user's own
suggestion, and it keeps a count a child can see fill without reading a
number. *Not taken:* one outline per unit in several rows (60 still
fills the screen), a number (the child sees no text, master spec 5.8).
**The first suggestion's "keep showing complete" after firing** would
contradict ux D4 Q10 (outlines empty with the release, gone once inert),
so ux D4 is kept; the build today keeps every outline filled once fired,
and 24.2 aligns it.
- **Basket 3's quota of 60 stays** on the test level: it is the stress
  case chunk 22 measures (`stress-still`, the largest realistic pile,
  [DoD 30]), and the test level is never released. For real levels, O98
  (proposed default: at most 30 of weight per basket on the first level,
  set in its design session and checked at the children's playtest,
  [DoD 32]).

**4. 24.3, a fired basket lets its slimes go: a bug against the
spec.** The spec already says it (master spec 5.2 and 5.4, D91): after
firing, a basket releases its slimes one every 0.3 s at its outlet, and
they ride the train again with their size and species; the switch and
basket are inert for good, the gate stays open (D86); at bedtime the
releases pause until sunrise (D105). It is built (chunk 14) and tested
only with basket 1's three slimes. So nothing new is decided about
*whether* a basket releases. **Proposed additions:** a fired basket
always empties: no released slime falls back into it, and it is empty
within its quota × 0.3 s plus 10 s of firing, however busy the outlet.
*A lead, unverified:* basket 3's outlet is over switch 3's trapdoor,
which shuts only once no awake slime is near it, so a released slime can
fall back into the basket and be released again, forever. **Kept, not
changed:** the release pace stays 0.3 s (`tuning.md`; a 0.5 s pace was
suggested, but nothing in the report asks for a slower one); released
slimes appear at the outlet, which stays O62 (the basket's own design;
the test level's outlets may move if the fix needs it); bedtime pauses
the release (D105, already built in 23D). Released slimes are train
slimes, available again, never lost or stuck.

**5. Lexicon.** The user's "slime counter" on a basket is its **quota
outlines** (or **quota pies** above 10); the debug overlay's own counts
are the **slime counts**. The user's "last frontier gate" is basket 3,
which has no gate: it fires the celebration (D77). The Terminology table
gains quota outlines, quota pie, release and debug overlay.

## D129 — Chunk TL1 as built: the test level playable from fresh with base slimes alone (2026-09-29)
**Built; the choices below marked proposed wait for the user's approval**
(with D126 to D128). Chunk TL1 (D127) is done: from `fresh`, calls wake
enough base slimes to fill every basket, with no fusion and no tilt; the
checker gives the test level 0 FAIL and 0 warnings (3 warnings before).

**1. How.** A woken slime wakes the sleepers it touches (`Sleepers.wake`;
measured: centres 44 px apart wake, 45 px don't), so TL1 lines sleepers up
**touching** (centres 38 to 40 px apart) within a called base slime's hop
(133 px up, 150 px sideways): one call wakes the whole line (**chain
waking**). Stable IDs are all kept and numbered left to right; each
section's species counts are unchanged (30 / 40 / 130; the level 37 / 36 /
38 / 39 / 50). Base slimes a call can wake by each basket (the estimate,
base slimes alone; with fusion in brackets): basket 1, 10 for a quota of 6
(22); basket 2, 20 for 15 (32); basket 3, 62 for 60 (102). A new played
test, `tests/e2e/test_test_level_playable_e2e.gd`, fills each basket
(seeds 1 to 6 pass; a missed call is retried). `LevelProgress` counts
chain waking (`CHAIN_LINK`, 44 px); its rule 12 warning suggests touching
lines. It is optimistic about the hills (a larger slime called under a
bump hits its underside); no basket depends on them. Suite 922/922.

**2. Deviations from `levels/test/README.md`** (positions: that document,
"Chunk TL1", and `docs/dev/README.md`, "Chunk TL1"): the tree's lower
platform is empty (its six sleepers moved to two hollows on the fusion
dip's rims); the entry ramp's two side ledges and the bowl's first left
tier are one `RampShelf`; the rim is split into `RimLow` (reached from the
plateau, 17 sleepers) and `Rim` (the branch, 13); the descent's top is
steeper, the only change to the loop's path; section 2's parade, second
dip and frontier ledge trade sleepers (new hollow on the second dip's near
rim). **Section 3's IDs were renumbered** left to right across its new
ledges: the same 130 IDs, but most name other spots than before. Against
rule 20 this is fine because the test level is never released (D127's
released-ID list, proposed, is what protects a released level).

**3. Proposed, for the user's review.**
- **Rule 22 (b), house style:** a ledge a called base slime must reach
  keeps its underside at least 130 px (a size 3's hop) over any loop
  ground under it, wherever the slime reaches it from. Stricter than the
  checker, which only measures ledges within a called slime's reach of
  the loop beneath them (a hollow hanging over a dip's slope, reached from
  the rim, isn't measured). The test level meets it.
- **Rule 12's fresh-game line (D127) reads "with fusion":** each basket
  can be filled from fresh by the slimes the train can make, fusion
  included, which is what the checker estimates by default. *Why not
  "base slimes alone":* it would make fusion never needed for progress,
  like tilt (rule 10), a change to what the game is; the user's call.
  The test level meets both.
- **Basket 3's tight margin (62 base slimes for a quota of 60) is
  acceptable** on the test level: it is the stress case, never released,
  and a missed call is simply retried. A real level's quota ceiling is
  O98 (D128).
- **By eye:** with the tree's lower platform empty, check that the tree
  still shows a hint from the loop (rule 9: the platform's edge and the
  bough's three sleepers).

**4. Lexicon.** The Terminology table gains **chain waking** and
**touching line**.

**5. The build order.** TL1 is done. Next, chunk 18.

## D130 — Chunk 18 as built: parent gate and settings, placeholder UI (2026-09-29)
**Built** (54873c1, suite 1041/1041); **the points in 2 and 4 marked
proposed wait for the user's approval** (with D126 to D129). Detail:
`docs/dev/README.md`, "Parent gate and settings (chunk 18)".

**1. As built.**
- **The code** is stored as SHA-256 of a salt then the code, with a fresh
  16-byte salt at every change, in one app-wide file, `user://parent.json`
  (`{"format": 1, "code": {salt, hash} or null, "wrong_tries",
  "wait_until_ms"}`), outside the level saves: deleting a level's save
  touches neither the code nor the tries.
- **Wrong tries and the 30 s wait are on disk**, one count for every
  button. The wait runs on the wall clock and is capped at 30 s left, so a
  clock set back can't lengthen it.
- **The parent layer** is a state machine (hidden, buttons, prompt,
  settings, setup) over the running game; its timers count simulation
  steps; nothing pauses. The code prompt shows dots, never digits.
- **Text** in English and French ("vous") through a small string table
  (`src/parent/parent_text.gd`), not Godot's translation files.
- **Sizes** in millimetres: the parent buttons 14 × 10 mm; every target at
  least 9 × 9 mm and 2 mm apart (D109). Placeholder constants until
  ux-writer's token file exists.
- **Deleting a level's save:** `SaveStore.delete` is the only delete and
  `main.delete_level_save` its only caller (a lint enforces both,
  `rule_saves_never_wiped`); the running session and bedtime carry into the
  fresh save (D104).

**2. Proposed: the build's choices where the spec was silent.**
- The 6th digit submits (no OK key).
- A parent-zone tap while the prompt is open closes the prompt and shows
  the buttons again.
- The wake-early prompt closes if bedtime ends on its own.
- Setup: a matching code moves to the next step by itself; Back works on
  steps 2 to 4; setup has no idle timeout; losing window focus restarts it
  on desktop only (on the phone, going to the background does).
- Deleting a save lifts that level's write block (a fresh level saves again
  even where an unreadable file had blocked saving).
- The phone's tilt neutral carries across a delete, with the session.
- Settings list only the running level's save to delete.
- The parent buttons are 14 × 10 mm so the words fit (above D109's 9 mm).

**3. Spec fix (wording, not behaviour).** DoD 24 said the time left shows
"nowhere the child can reach without the code", but the wake-early prompt,
which anyone can open before typing the code, shows it, as ux Q30, D114 and
`rule_time_left_shown_only_behind_code` intend: it sits behind a parent's
action, never on the parent buttons the child reveals. DoD 24 now says
"never on the parent buttons", as D114 does.

**4. Open risks, carried forward.**
- **An unreadable `parent.json` reads as "no code"**: setup shows again,
  maybe to the child, and a running wait is lost. *Proposed:* chunk 19's
  persistence hardening covers `parent.json` too (atomic write with a
  backup, the backup used when the file can't be read).
- **Setup's text** already describes "Forgot the code?" and pinning, which
  chunk 20 builds; the prompt's "Forgot the code?" is a stub until then.
- **The open button row reaches 11 mm down**, below the 7 mm parent zone,
  and can cover an object while open; a press that misses the buttons
  closes them and is forwarded, so nothing is eaten.
- **The debug speed-up shortens the 30 s wait** (debug builds only).
- **A 6-digit salted hash can be brute-forced offline** by anyone who can
  read the file; the rule asks only that the code is not readable in plain
  text. *Proposed:* accepted for v1.
- **The French labels' fit** hasn't been seen on a real screen: check on
  the reference phone in chunk 20 or 22.

**5. The build order.** Chunk 18 is done. Next, chunk 19.

## D131 — Chunk 19 as built: persistence hardening (2026-09-30)
**Built** (c39ebc0, suite 1097/1097); **the points in 2 marked proposed
wait for the user's approval** (with D126 to D130). Detail:
`docs/dev/README.md`, "Files and autosave" and "Chunk 19: persistence
hardening".

**1. As built.**
- **A level save's write:** the new text goes to `L.json.new` and is read
  back; if the old save reads, it is copied to `L.json.bak` through
  `.bak.new` (checked, then renamed); then `.new` is renamed onto
  `L.json`, which is never missing. A kill at any point leaves a whole save
  and a whole older backup. **Read:** the save, else the backup, else
  fresh (tech-direction, "Saving").
- **Delete (DoD 29)** removes `.json`, `.new`, `.bak` and `.bak.new`.
  Lints: files are removed only inside `SaveStore.delete`, renamed only in
  the two stores.
- **The kill test is simulated**, deterministically: the tests lay out the
  files a kill would leave at each step of the write, then open the game on
  them.

**2. Proposed: the build's choices where the spec was silent.**
- **Unreadable files are set aside** as `L.json.unreadable[.n]` instead of
  blocking the level's writes: nothing is deleted or written over, and only
  a failed rename blocks. Delete leaves the `.unreadable*` and `.v<N>`
  files (they aren't the save).
- **Mid-air on load: grounded** (5.10's "whichever is easier"). A slime
  saved in the air moves straight down onto the first surface below
  (ground or another slime), at rest; with nothing below, it is lost.
  Sleepers, slimes in a basket and parked slimes are left as they are.
- **Migration by level version, keyed by stable IDs.** An older save
  migrates; a newer one (from a newer game) is blocked. Displaced slimes (a
  sleeper moved, removed or of another species; an awake slime inside the
  ground or outside the level) are lost (moved to the loop start, in the
  lost log) but kept in the save, so the 200 stay. Sleepers added to the
  level are added; removed objects' states are dropped; new objects start
  in their initial state. Before the first write, the original is kept as
  `L.json.v<old>` (the write is blocked if that copy fails).
- **`parent.json`** (D130's risk): a mirror, `parent.json.bak`, is written
  after it through side files (salt and hash, tries, the wait's end; never
  the code); load falls back to it. **Both unreadable: LOCKED.** A code is
  said to exist, so setup never shows again (DoD 23), but none matches; the
  tries count in memory only; the files are kept until a new code is set.
  The way out is "Forgot the code?" (chunk 20); until then, clearing the
  app's data.
- **The test level is at `level_version` 2** (no content change), so the
  `old-version` fixture is a real version-1 save. New fixtures: `midair`,
  `old-version`.

**3. Flagged for documentalist** (the chunk 19 preflight, on D118 and
D121): `rule_left_alone_and_lost` covers free slimes only, and chunk 19
adds two more kinds of lost slime, a mid-air slime with nothing below and
one displaced by migration. The lost rule can be widened once the user
approves 2.

**4. Open risks, carried forward.**
- The parent mirror can lag one write behind after a kill: one wrong try
  off after a fallback.
- Migration doesn't cover slimes on a route back that no longer exists, nor
  tap or proxy entries pointing at removed IDs.
- `save_data.gd` is about 505 effective lines and `make_fixture.gd` 599 of
  600: for the health review.
- `tools/bench_level.gd` times from `REST_TICK` 670, but the stress pile
  now rests at about 410: chunk 22 should fix the bench's start.

**5. The build order.** Chunk 19 is done. Next, chunk 20.

## D132 — Chunk 20 as built: Android build and platform integration (2026-09-30)
**Built** (72d3717, suite 1186/1186); DoD 25, 26 and 27 pass on the
emulator (S20FE_API_34). **The points in 2 wait for the user's approval**
(with D126 to D131); the checks in 3 wait for the user's S20 FE. Detail:
`docs/dev/README.md`, "Chunk 20: Android" (its emulator evidence, its
manual checklist and "Choices proposed for spec-writer").

**1. As built.**
- **A small Android plugin** does what Godot can't: pinning, the device
  credential prompt (the screen lock, or a fingerprint or face as Android
  allows; the older system prompt below Android 11), the back-gesture
  exclusion, moving the app to the background, and the screen's real dpi.
- **Two builds:** debug, and release without test mode, the tests, the
  test level or the tools. The release key comes only from the
  environment, never from the repository.
- **No network (DoD 27):** the only permission in either build is the
  fingerprint/face one; no INTERNET permission, so no exception is needed.
- **Pinning (DoD 25):** asked at each launch; "leave" ends it. The
  credential prompt shows while pinned.
- **"Forgot the code?" (DoD 26)** through the device credential. It is
  also the way out of D131's LOCKED state.
- **The back-gesture exclusion covers the strips' whole height**: Android's
  200 dp cap doesn't apply while the bars are hidden. In the ~4 s the bars
  show after a swipe, the exclusion starts below them.
- **Lifecycle:** HOME saves at once; timers stay right across background,
  kill and reboot; the screen is kept on only during a session (and the
  wind-down).
- **Tilt from the accelerometer** (read correctly on the emulator's
  injected dips).
- **Small screens:** the parent controls sit in the safe area; the code
  pads shrink to fit a short screen, never below 9 mm keys and 2 mm gaps.
  Millimetres use the screen's real dpi (the S20 FE reports 480, really
  about 409).

**2. Proposed: the build's choices where the spec was silent.**
- **Landscape fixed,** not flipping with the sensor, so turning the phone
  never reverses the tilt.
- **Back when not pinned** puts the game in the background; it never quits.
- **Screen edges and safe area** (the documentalist's preflight point:
  tech-direction's "controls inside the safe area" against the atom's tap
  zones measured from the screen's edges): **the edge strips' and parent
  zone's tap zones stay on the screen's edges** (a child's finger reaches
  them there, and the exclusion covers them, parent-zone rows included);
  **the parent's controls** (buttons, the code prompt, settings) **go inside
  the safe area.** Both texts are right, each for its own kind of control;
  tech-direction now says so.
- **Real dpi** is trusted only within 0.6 to 1.6 times Android's reported
  one; otherwise the reported one is used.
- **Tilt:** flat within 20° of horizontal; a new reading only from 1° of
  change.
- **"Forgot the code?":** its texts as built; passing the screen lock only
  lets the parent set a new code; Back, or 30 s with no press, leaves the
  new-code screen with nothing changed.
- **No parent-facing text for the LOCKED state** (the prompt's "Forgot the
  code?" is the way out).
- **Release package** `com.slimetrain`, version 0.1 (debug
  `com.slimetrain.dev`).

**3. Waiting for the user's phone** (the manual checklist, S20 FE): tilt
feel (part of the chunk's "done when"), a back swipe off a strip with
pinning declined on One UI, the French labels' fit, the credential prompt
while pinned on One UI, and the punch-hole camera over an edge strip's
arrow.

**4. The release ships no level (O99).** The release build leaves out
`levels/test/` and no real level exists, so a release build opens on an
empty world. No chunk builds the real first level: the plan lists it as
"not in this plan" (a design session after chunk 16). *Proposed:* a chunk
**L01**, the first real level, designed by the user with the level-design
toolkit; see O99.

**5. Open risks, carried forward.**
- `main.gd` is at 394 of 400 effective lines; `parent_gate.gd` links six
  atoms: for the health review.
- Settings' main screen isn't fitted to the height: a second level listed
  could overflow a 57 mm screen.
- The older credential prompt (below Android 11) is untested on a device.
- The emulator needs `-gpu host`.

**6. The build order.** Chunk 20 is done on the emulator; its phone checks
(3) are pending. Next, chunk 21.

## D133 — Chunk 21 as built: end-to-end suite (2026-09-30)
**Built** (ec518a0, editor suite 1198/1198); DoD 31 passes. **The points
in 2 wait for the user's approval** (with D126 to D132). Detail:
`docs/dev/README.md`, "Chunk 21: end-to-end suite" (with its fixture to
test table).

**1. As built.**
- **Every fixture has a scripted scenario and a same-seed hash test.** A
  new file adds the five that lacked one (`stress-moving`, `midair`,
  `old-version`, `s1-optout`, `stress-still`), each booted twice on seed
  21 with equal state hashes.
- **A guard test** fails when a fixture has no end-to-end test loading it.
- **The suite runs on the Linux build (DoD 31):** a new "Linux debug"
  preset; `tools/linux/e2e.sh` exports it and runs `tests/e2e/` inside
  the exported binary (354/354 in 47 scripts, about 13.5 min). It refuses
  to run on a release build.
- **A build-guarantees test** reads the build files: the Android presets
  ask no permission, the plugin asks only the fingerprint/face one, no
  billing library, no network class in `src/` (DoD 27's no network, and
  no in-app purchases).

**2. Proposed: the build's choices where the spec was silent.**
- **Four tool-driven test files stay out of the Linux-build run** (the
  level checker, level selection, the level tools and new-level tests:
  they launch Godot or write into the project, read-only in an export).
  They still run in the editor suite.
- **"Repeatable" is proved per fixture** by the same-seed hash tests, not
  by running the whole suite twice.
- **The Linux build exports scripts as text** (the test runner needs
  them); Android keeps binary tokens.

**3. Open risks, carried forward.**
- The coverage guard matches text, not an actual load.
- Child processes share the saves folder and `parent.json`; nothing
  writes there today (autosave is off in test mode).
- The exported test runner hard-codes the main scene's path.

**4. The build order.** Chunk 21 is done. Next, chunk 22.

## D134 — The version roadmap: v1 is the test level, v2 content and music, v3 graphics (2026-09-30)
Resolves O99. Refines D50 and D54's version split. The user's decision,
verbatim: "v1 currently means only the test level, v2 will help working on
content generation, preparing reusable mechanics and ensure that level
designer have it as easy as possible, but also adding music which is
paramount for this kind of game. Proper gfx won't probably come before v3."

- **v1 is the test level only**, played end to end on the phones, with the
  platform, parent, save and performance work of the v1 build plan. So v1
  plays what the test level has (3 sections, 5 species); the master spec's
  "4 sections, 6 species" describe the real first level and move with it.
  The children's playtest [DoD 32] runs on the test level.
- **O99 is closed:** "the release build ships no level" is not a v1 gap.
  **Chunk L01**, the first real level (`levels/01/`), moves to **v2**. The
  release preset stays as built: test mode and `levels/test/` are left out.
  Whether a v1 release build is ever published to a store is not settled
  (O100); which build v1's Definition of done is checked on is O101.
- **v2 themes:** content generation and its tooling; reusable mechanics
  (interactive objects and components built for reuse across levels);
  making the level designer's work as easy as possible; **music**, which the
  user calls paramount for this kind of game; the first real level(s), L01.
  Music moves from v3 (D50) to v2; whether the rest of sound comes with it
  is O102.
- **v3 theme:** proper graphics. Placeholder art until then.
- Only themes: no v2 or v3 spec is written yet (`versions/v2/README.md`,
  `versions/v3/README.md`).

## D135 — v1 is the full MVP, never in a store (2026-09-30)
Resolves O100. Refines D134. The user's decision, verbatim: "v1 won't ever
be in a store. v1 is probably not the most accurate version number for
this. let's call it a full MVP: all bare mechanics are validated, gameplay
loop is there. It can be tried. We may have somebody work on gfx a bit if
we truly want to put it in kid hands for handson testing. but that's not
our objective right now."

- **v1 is never published to a store.**
- **v1 is called "the full MVP"**: all the bare mechanics are validated, the
  gameplay loop is there, and it can be tried. The text says "v1 (full
  MVP)". The folder `versions/v1/` and the "v1" IDs stay as they are, since
  atoms, code and briefs reference them.
- **The children's playtest [DoD 32] is deferred:** not an objective of the
  full MVP. Putting it in children's hands may first need some graphics
  work ("not our objective right now"). DoD 32 stays in the list, marked
  deferred. D134's "the playtest runs on the test level" is superseded.
- O101 stays open; its proposed default now drops the release build as a
  target (a build that never ships). Which version is the first store
  release, and so carries D31's price, is O103.

## D136 — Sound begins at v2; effects are a v2 candidate (2026-09-30)
Resolves O102. Supersedes, with D134, D50's "sound comes around v3". The
user's decision, verbatim: "I didn't believe we had sound effects planned
for v1. I don't believe we had broached that subject during spec sessions.
Mostly sound begins at v2, especially music. But effects may be added to v2
scope."

- **v1 (full MVP) has no sound**, as D50 says. Nothing changes for v1.
- **Sound begins at v2.** Music is v2 (D134).
- **Sound effects are a v2 candidate**, decided when v2 is scoped. Species
  voices (D40), the 10-voice cap (D68) and bedtime's softer sound (D28)
  count as effects: v2 candidates, no longer pinned to v3.
- Effects were never discussed in spec sessions; nothing more about them is
  specified.

## D137 — The first store release ships a true, fully implemented level: probably v4 (2026-09-30)
Resolves O103. The user's decision, verbatim: "first release mean a true
fully implemented level. Which will probably be the largest step on our
roadmap. so probably v4."

- **The first store release** is the version that ships a true, fully
  implemented level. It is **probably v4**, and probably the largest step
  on the roadmap.
- **D31's price** (about $3–5, no in-app purchases) belongs to that first
  release.
- **How it fits L01 (D134):** v2's level work (chunk L01, the tools, the
  reusable mechanics) builds toward the fully implemented level the first
  store release ships. Whether that level is L01 itself, finished later, is
  O104.

## D138 — Chunk 22 as built: the performance pass (2026-09-30)
**Built** (1e98c7a, suite 1267/1267). **DoD 30 is not met and not
closed.** The points in 2 wait for the user's approval (with D126 to
D133). Detail: `docs/dev/README.md`, "Chunk 22: performance"; the phone
evidence: `docs/perf/2026-09-30-s20fe-session.md` and
`docs/perf/2026-09-30-independent-review.md`.

**1. As built.** Every fix left the behaviour exactly as it was: on all 17
fixtures of the test level, the same seed gives the same state hash before
and after.
- **The fusion nudge** (the dip's nudge toward a partner) computes its
  distances once, stops early when no slime is on a dip's floor, and finds
  partners through maps rather than searches. Most of `stress-moving`'s
  gain.
- **Door passes:** the terrain pass for each shut door skips the slimes
  whose bounding box lies outside the door.
- **The pair loop** stops at the last slime that isn't a wall.
- **Off screen:** detail is set for every slime in one call, the level's
  trapdoors are cached, and each centre is read once.
- **The centre cache:** a slime's centre is computed once per tick, not at
  each of about 1000 calls.
- **Drawing culled to near-view:** only the slimes that can be seen are
  drawn (parked slimes and slimes far off screen are skipped), and the
  same goes for their eyes and the debug labels. The debug overlay counts
  every 250 ms. The switches' and signposts' ways are cached.
- **Desktop, median ms per tick (headless):** `stress-moving` 27.6 →
  10.35 (10.3 to 10.9 across runs, −61 %); `s3-basket-59of60` 9.5 → about
  7.9. Lighter scenes (`fresh`,
  `gate2-open`, `stress-still`) tick in about 0.9 to 1.3 ms. The culling
  cut the rest of the frame by about 1.4 to 2.3 ms on the desktop.
- **Tools:**
  - the **perf log** (`--perf-log[=SECONDS]`, debug builds only): one
    line per window with fps, frame times, ticks per frame, ms per tick,
    the rest of the frame, the slime counts, and the active bodies and
    pairs;
  - **`--max-ticks-per-frame=N`** (debug builds only), to measure with
    another cap;
  - **`tools/android/perf.sh`**, in fixture mode (cold and warm windows)
    or `--free-play` (normal play from the phone's own save). It records
    logcat and the thermal status, and `perf_summary.py` summarises the
    session from the log. It installs with `adb install -r` only, and
    never clears the app's data;
  - **the bench's rest detection** (D131): `stress-still` is timed from the
    tick its pile actually rests (about 407), not from a fixed tick; a pile
    that never rests is not timed;
  - **`tools/level.sh rest`** (D107): the time a bedtime pile in the open
    takes to rest, and how often hoppers wake a resting pile.
  - `REST_DRIFT`'s code comment now says what D107 keeps: the anchor is
    fixed where the count started.

**2. Proposed** (the user reviews):
- **a. The cap on ticks per frame: 2 at 1× speed** (`MAX_TICKS_PER_FRAME`,
  was 8) (proposed). With 8, a tick costing more than a frame made every
  frame run 8 ticks: the game collapsed to a few fps (the catch-up spiral).
  With 2, a 33 ms frame (30 fps) still plays at full speed, and an
  overloaded scene plays in slow motion instead of collapsing (in the
  slowed desktop run, 15.6 fps instead of 5.4). The cap scales with the
  debug speed (2 × the speed, rounded up), so the overlay's and test mode's
  speeds keep their pace. Built so; the hash is unchanged.
- **b. A frame budget on the reference phone** (proposed). The user's goal
  (2026-09-30), verbatim: "we must reach the maximum performance now,
  because this version is the raw one. I fully intent to have other
  objects on screen that will be animated, and music, etc... which will
  require bits of processing power as well." Per 16.7 ms frame:
  - simulation at most 8 ms;
  - drawing at most 4 ms;
  - at least 4.7 ms left for later animation, music and the system.

  **How it relates to DoD 30** (`req_platform_and_performance_targets`):
  DoD 30 stays the target (60 fps on the reference phone in normal play,
  30 fps on the floor phone with the largest realistic pile). The budget
  splits the reference phone's frame so that meeting DoD 30 today leaves
  room for v2's music and animated objects; it doesn't change DoD 30's
  wording. The simulation's share is, on the desktop, a tick of at most
  about 3.8 ms (phone cold, 2.1× the desktop) or 2.4 ms (throttled, 3.4×).
  **A consequence to settle with it:** chunk 24.1's desktop target (at
  most 8 ms per tick at p95, D128) is about 2 to 3 times looser than this
  budget. If the budget is approved, 24.1's target follows it (proposed).
- **c. The fixture `s3-basket-59of60`** (proposed): basket 3 at 59 of 60,
  switch 3 flipped, not at bedtime; 141 train slimes in the bowl; the
  camera on basket 3's framing zone at zoom 0.8. Played on, the basket
  fills, fires in view and the celebration plays. It is the new fixture
  item 24.1 asked for (shared with 24.3). Added to the test level's
  fixture list.
- **d. Phone test sessions capture numbers through logs** (the user's
  rule, 2026-09-30; recorded as proposed until the user confirms this
  wording): the perf log, logcat and `perf.sh` give the numbers;
  screenshots are for visual bugs only.

**3. Verdict: the tick is the bottleneck; chunk 5N is recommended.**
- **DoD 30: not met, not closed.** The reference half fails on the only
  phone evidence there is (the hand-played session of 2026-09-30: 3 to
  20 fps in normal play, 4 fps at the section 3 endgame). That build
  predates the cap, the culling and the centre cache; no perf-log run on
  the phone yet. The floor-phone half stays open (the phone isn't bought,
  O14).
- **The section 3 endgame and `stress-moving` are bound by the physics
  tick.** Estimated phone tick after the fixes: `s3-basket-59of60` 15 to
  17 ms cold, 24 to 27 ms throttled; `stress-moving` about 22 / 36 ms.
  That is more than the whole frame, before any drawing. Lighter scenes
  are bound by drawing and the rest of the frame (2 to 5 ms phone tick),
  which the culling cut.
- **Chunk 5N (the native tick) is recommended**, and chunk 22 repeats
  after it (D96). The cheap fixes are done; what is left is the GDScript
  contacts, rings and terrain on 60 to 90 active slimes. 5N is not
  started.

**4. Findings, for the register and chunk 24.**
- **a. Time to rest (D107; O105).** Open bedtime piles of size-1 slimes
  rest slowly with the fixed anchor: 20 slimes in about 22 s, 40 in about
  165 s, 80 or more never (within 4 to 10 minutes). One awake train slime
  hopping against the resting bowl pile wakes it 10 to 23 times a minute,
  so the pile is awake half to three quarters of the time (6.4 to 7.2 ms
  per tick on the desktop, against 1.0 to 1.5 resting). A resting pile is
  cheap (0.15 to 0.3 ms for 20 to 40 slimes). The rest rule is not changed.
- **b. A fired basket's releases keep its pile awake (O106, with 24.3).**
  A fired basket releases a slime every 18 ticks (0.3 s), and each release
  wakes the whole pile. `REST_TICKS` is 30, so the pile never rests again
  during the drain: bursts of about 89 active slimes, a tick 57 % dearer.
  A design call for chunk 24, together with 24.3.
- **c. Parked asleep slimes stack on one spot (likely bug; O91).**
  Bedtime-asleep slimes that creep past the park margin are parked where
  they are; a parked slime isn't a wall, so the next one slides into the
  same spot: 28 to 31 slimes end up on one centre, and nothing spreads
  them out when they unpark. The stuck safety net skips bedtime-asleep
  slimes, and no test covers it. It also skews 4a's "never" for the
  largest piles, so it is settled before the rest rule.

**5. In progress, no decision:** "crowd detail", the user's idea: fewer
ring points when many slimes are active (for size 1: 12, 10, 8 and 6
points at fewer than 20, 30 and 40 active slimes, and at 40 or more), on
branch `exp/crowd-detail`; if kept, it is its own decision, since it
changes `req_offscreen_simulation`.

**6. The build order.** Chunk 22 is done; DoD 30 open. Next, the user's
call on 5N (recommended); then chunk 22 repeated (D96), then chunk 24
(O97).

## D139 — Chunk 24 gains 24.4 to 24.6, from the phone session (2026-09-30)
Proposed; the user reviews. From the user's hand-played session on the
S20 FE (`docs/perf/2026-09-30-s20fe-session.md`), relayed by the
coordinator. The items and their done-whens are in the build plan, chunk 24.
- **24.4 A migration wakes sleepers.** Proposed: a sleeper displaced by a
  migration stays a sleeper, placed by its stable ID or at a surviving
  sleeper spot; only awake slimes are made lost. This refines D72 (and
  D131's migration), which make every displaced slime lost; the master
  spec follows once approved.
- **24.5 A big awake pile collapses the frame rate** (about 100 awake
  slimes at the loop start, 3 fps). Proposed: it plays in slow motion at
  worst, thanks to D138's tick cap; it follows 24.4 and O105.
- **24.6 The debug labels are too expensive** (36–38 fps to 11–14 on the
  phone). Proposed: cheap labels; debug builds only; measurements always
  with labels off.
- **24.1's target:** D138's proposal stands (it follows the phone budget
  if approved); the user reviews it.
