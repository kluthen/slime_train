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
