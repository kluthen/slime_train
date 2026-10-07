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
  *Refined by D163 (2026-10-07, the user's):* a displaced **sleeper** goes
  back asleep to its stable ID's spot, else to the nearest empty sleeper
  spot (taking its ID); only awake slimes, and a sleeper with no spot
  left, are lost.
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
  *Refined by D153 (2026-10-02):* 200 moving slimes (`stress-moving`) is
  an abuse test with an abuse target, not a 30 fps target: on the
  reference phone it must not crash or freeze and must keep at least
  15 fps. The 30 fps target is the dense moving case's (`stress-dense`).
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
  was 8) (proposed; *settled by D163, the user's*). With 8, a tick costing more than a frame made every
  frame run 8 ticks: the game collapsed to a few fps (the catch-up spiral).
  With 2, a 33 ms frame (30 fps) still plays at full speed, and an
  overloaded scene plays in slow motion instead of collapsing (in the
  slowed desktop run, 15.6 fps instead of 5.4). The cap scales with the
  debug speed (2 × the speed, rounded up), so the overlay's and test mode's
  speeds keep their pace. Built so; the hash is unchanged.
- **b. A frame budget on the reference phone** (proposed; *D163, the
  user's: a headroom target, recorded, not a v1 gate*). The user's goal
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
- **24.4 A migration wakes sleepers.** *(Settled by D163, the user's, as
  built in 61b8d5f.)* Proposed: a sleeper displaced by a
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

## D140 — Crowd detail; the order of the next steps; 5N goes ahead (2026-09-30)
Proposed; the user reviews. Crowd detail is the user's idea (D138, item 5),
merged now from branch `exp/crowd-detail`. The user's words (2026-09-30):
"in case of screen filled with slimes, the chaos prevent accurate action.
So having reduced physics shouldn't be problematic... graduation
12 - 10 - 8 - 6 for <20 <30 <40 >40 simulated, for size 1 slime", and:
"Should it prove unsufficient, we will see how it goes with 5N."
Resolves O97.

**1. Crowd detail.** It changes `req_offscreen_simulation` (and the master
spec's 5.3, once approved): "fewer ring points zoomed out" becomes "fewer
ring points zoomed out, or when many slimes are active".
- **Ring points per size and detail level** (level 0 is full detail):

  | Size | L0 | L1 | L2 | L3 |
  |---|---|---|---|---|
  | 1 | 12 | 10 | 8 | 6 |
  | 2 | 15 | 12 | 10 | 8 |
  | 3 | 18 | 15 | 12 | 9 |

- **The crowd count:** the slimes that cost physics this tick, counted
  after the parking: ACTIVE slimes that are not sleepers. Resting and
  parked slimes cost nothing and don't count. The count comes from the
  simulation's state only, never from the frame rate or a measured time,
  so runs repeat (same seed, same hash).
- **Levels:** up at 20, 30 and 40 active slimes; down only at 15, 25 and
  35, so rings never reshape back and forth.
- **Zoom:** the level used is the higher of the zoom's and the crowd's.
  Zoomed out (below zoom 0.8, back from 0.85) gives at least level 2
  (8, 10 and 12 points, the same as the old zoomed-out detail).
- **Who is reshaped:** only ACTIVE rings are resampled, so a reshape never
  wakes a resting pile. A slime waking or unparking takes the current
  level on the tick it is ACTIVE again.
- **Pile cap:** pile slimes (in a basket, or asleep at bedtime) stop at
  level 2. At 6 points the `stress-still` pile rested at about tick 1300
  instead of about 407.
- **Save format:** each body stores `detail` (absent: 0); the off-screen
  state stores `crowd_level` (absent: 0); an older save's `low: true`
  loads as level 2 (a migration). A reload is exact: the same state and
  the same run after it.
- **Look:** in a crowd, 6-point slimes read fine. A lone slime at normal
  zoom while a crowd sits just off screen (simulated, not parked) looks
  like a hexagon: accepted (proposed).
- **Measured gain,** on a slowed desktop CPU standing in for the phone:
  - `s3-basket-59of60`: 16.4 -> 18.0 fps, tick 21 -> 17.7 ms;
    `stress-moving`: 11.4 -> 12.3 fps, tick 33 -> 30 ms.
  - The contact solver shrinks with the points (`stress-moving` 8.8 ->
    5.7 ms from L0 to L3); about 4 to 5 ms of each tick doesn't depend on
    the points.
  - The rest of the frame, outside the tick, is about 21 ms on the slowed
    CPU either way.
  - **Verdict: helpful, but not enough on its own.**
- The values are rows in `tuning.md` ("Off screen, resting piles and
  detail").

**2. The order of the next steps (proposed; the build plan follows).**
1. **Chunk 22b, the drawing pass:** measure and cut what the frame costs
   outside the tick, about 21 ms on the slowed CPU: the blend's field
   viewports, the eyes, the lines, the frontier view, the debug overlay.
2. **Chunk 5N, the native tick, goes ahead** after 22b. The targets are
   missed (D138) and crowd detail is not enough on its own, which meets the
   condition of the user's go quoted above. `domain_architecture_rationale`
   adopts it (for documentalist). Its results are deterministic within one
   build, not bit-equal to the GDScript tick. Saves load under either tick,
   and the GDScript tick stays as a fallback.
3. **Chunk 22 repeated** on the reference phone, with the perf log tooling
   (`tools/android/perf.sh`).
4. **Chunk 24.**
5. **The coding-rule health review, last** (D122).

O97 closes on this order. It keeps its proposed default (chunk 24 after 5N
and chunk 22's repeat), with 22b placed first. 24.3 and O106 still change
the endgame chunk 22's repeat measures; the repeat records which of them
have landed.

**3. A tension, noted in O105 (no decision).** `domain_architecture_rationale`
and the master spec's section 6 assume "a big crowd is mostly a still
pile". O105 (open piles of 40 or more rest in minutes or never; an awake
slime keeps waking a resting pile) and O106 (a fired basket's releases keep
its pile awake) undercut that assumption. Documentalist found it.

## D141 — Crowd detail only when the device can't keep up (2026-09-30)
Proposed; the user reviews. Amends D140's crowd detail. The user's words
(2026-09-30): "I'd like to add an amend for the next update: currently we
reduce number of physic points a slime has when too many are simulated
(active in/out of screen). We should probably only reduce this number IF
fps goes below 60fps. (meaning, if you've got a good phone/tablet, why
degrade?)". Defaults proposed by the coordinator, refined here where the
spec and the code showed a better fit (each refinement says why).

**1. The signal is load, not the displayed fps** (proposed).
- Under vsync the fps reads 60 until the device is already late, so it
  shows no headroom. Two measures instead, over a window of about 1 s of
  real time:
  - **the busy share:** the real time spent on the frame's work (the ticks
    plus the rest of the game's `_process`, measured as the perf log's
    process time), summed over the window, divided by the window's length;
  - **missed beats:** frames at 1x that ran 2 ticks (the fixed step
    catching up), so the game's 60 Hz pace slipped at that frame. They
    catch what the busy share can't see: drawing, rendering, the system.
- *Refined:* a share of the window rather than ms per frame. It reads the
  same at a 60 Hz or a 120 Hz refresh (the S20 FE's screen may run at
  120 Hz; the PERF_INFO line will tell); at 60 Hz, 85 % is about 14 ms of
  a 16.7 ms frame and 60 % about 10 ms, the coordinator's numbers.
- **Each window gives a verdict:**
  - **pressed:** a busy share above 85 %, or 3 missed beats or more (under
    about 57 fps);
  - **calm:** a busy share below 60 % and at most 1 missed beat (a stray
    hitch is tolerated);
  - otherwise **in the band:** neither.
- A window holding a frame over 250 ms (a pause, a load, the app back from
  the background) is dropped, and so is any window at a debug speed other
  than 1x.
- **Where it lives:** in the scene layer, in every build, release
  included. The perf log is debug-only and the release preset leaves
  `src/debug/` out, so the meter can't be the perf log; the perf log
  reports it. `src/sim/` never reads a clock (CODING_RULE §2).

**2. The detail ceiling** (proposed).
- *Refined:* rather than a separate "under pressure" flag that forces the
  crowd level to 0, the load sets a **ceiling** on the crowd's detail
  level, 0 to 3. The detail an ACTIVE ring takes becomes the higher of the
  zoom's and the lower of the crowd's level and the ceiling:
  max(zoom's, min(crowd level, ceiling)); the pile cap (level 2) applies
  as today. The crowd level itself still follows D140's steps (up at 20,
  30 and 40 active slimes, down at 15, 25 and 35), unchanged.
- **How the ceiling moves:**
  - a pressed window raises it one step (at most 3);
  - 3 calm windows in a row lower it one step, and the count starts again,
    so detail comes back at most one step per about 3 s;
  - a window in the band holds it and restarts the calm count.
- This keeps the coordinator's rules (on at once, off only after about
  3 s of calm, at most one step per window), and it stops at the first
  level where the device sits in the band instead of dropping straight
  back to full detail. *Thrash:* a step changes the tick by about 1 ms on
  the slowed desktop CPU (`stress-moving`'s contact solver 8.8 -> 5.7 ms
  from level 0 to 3, D140), well under the band's 4 ms (60 to 85 %), so
  it shouldn't bounce between steps; chunk 22c checks it.
- A good device never goes pressed, so the ceiling stays 0: full ring
  points, whatever the crowd. A pressed device gets D140's behaviour.
- Zoom's low detail (at least level 2 below zoom 0.8, back from 0.85) is
  unchanged: it is about what can be seen, not about load.

**3. Modes and determinism** (proposed).
- One switch, `--crowd-detail=auto|always|off` (a debug flag, debug
  builds only; a release build is always `auto`):
  - `auto`: the ceiling moved by the load meter. The default in normal
    play;
  - `always`: the ceiling fixed at 3, which is D140's behaviour exactly;
  - `off`: the ceiling fixed at 0 (only the zoom's detail).
- *Refined:* the simulation's own default is `always`; only the game root
  in normal play turns `auto` on. So test mode, the fixtures, test-mode
  scripts, the level bench, `tools/level.sh` and every unit or end-to-end
  test run `always` unless a run asks for `auto`, and every state hash
  stays as today (req_test_level_and_test_mode: same seed, same hash).
  Test mode accepts the flag (the phone's fixture runs need `auto`); the
  test-mode script format doesn't change.
- **The ceiling is an input,** like the tilt (`TiltFeed` hands it to the
  simulation before every tick): the scene layer hands it over at a tick
  boundary, and a change applies from the next tick.
- **Saves: no new key.** `detail` (each body's level) and
  `offscreen.crowd_level` (D140's crowd level) keep their meaning. The
  ceiling isn't saved. *Refined:* in `auto` it starts at 0 after a load or
  a fresh start (a good device never shows reduced rings; a pressed one
  climbs within a few seconds). A reload stays exact in `always` and
  `off`. In `auto` the state loads exactly, but the run after it depends
  on the device's load, as it did before the reload. No hard-contract
  change (CODING_RULE §4).
- It amends D140's "the count comes from the simulation's state only,
  never from the frame rate or a measured time, so runs repeat": that
  still holds for `always` and `off`. In `auto`, normal play's detail also
  depends on the measured load. Documentalist: `req_offscreen_simulation`
  (the detail rule) and `req_test_level_and_test_mode` (runs repeat
  because test mode is `always`).

**4. When: chunk 22c, after 5N and before chunk 22's repeat** (proposed).
- 5N changes how often the device is pressed at all, and the phone run
  should measure `auto`, the shipping behaviour. Not folded into 5N (one
  chunk at a time) nor into 22b (running).
- The perf log gains the ceiling, the crowd level, the detail used, the
  busy share and the missed beats on the PERF line, plus a line at each
  ceiling step with its reason. `tools/android/perf.sh` runs `auto` in
  both of its modes (fixture runs pass `--crowd-detail=auto`), with a way
  to pick another mode for comparison.
- Chunk 22's repeat measures `auto`, and DoD 30 is judged on it.
- The build plan has the chunk and its done-when; the values are rows in
  `tuning.md`.
- O105 is unchanged: this doesn't touch the rest rule or "a big crowd is
  mostly a still pile".

## D142 — Chunk 22b as built: the drawing pass; the slowed-CPU method; 5N confirmed (2026-09-30)
**Approved by the user on 2026-09-30 (D144)**, "agreed"; first recorded
as proposed. Still open inside it: the throttled drawing verdict (3),
which the phone measurement decides, and O108 (6), open with its proposed
default. The labels' 250 ms (7) is approved with it.
**Built** (5d9533a, suite 1318/1318; the 17 fixture hashes, seed 909 over
600 ticks, unchanged). Proposed; the user reviews: the method (2), the
verdict's reading (3), the new open question (6) and the look and label
choices (7). Detail and every table: `docs/dev/README.md`, "Chunk 22b:
drawing". D143 reserved this number for it.

**1. As built.** Nothing changed in the simulation, and on screen only
what 7 accepts. BLEND mode and the Compatibility renderer stay.
- **Redraw only on change:** the frontier view (a key of every value it
  paints, compared each frame; every frame while the celebration's burst
  shows), the tap feedback (ripples, hint, eyes), the edge buttons, test
  mode's overlay and the debug overlay.
- **The slime renderer** rebuilds nothing when the bodies, the topology
  and the screen are unchanged, and builds vertices for the seen slimes
  only. A resize bug is fixed (a painter redraws from its own draw
  signal), with a regression test.
- **Instanced shapes** (`src/draw/shape_instances.gd`): one instanced draw
  reproduces many `draw_circle()` or antialiased `draw_arc()` calls. The
  eyes take one draw per ring radius (3); a basket's quota slots take two;
  at the reward pulse's peak a basket falls back to slot-by-slot drawing
  so the overlap looks the same. The celebration and the lasting mark
  draw from an `Overlay` child, above the slots.
- **The debug slime labels** (item 24.6): text cached and rebuilt at most
  every 250 ms, positions every frame (7).
- **Tools:** the PERF line gains 14 per-part fields (debug builds only:
  `slimes_ms`, `eyes_ms`, `frontier_ms`, `hud_ms`, `debug_ms`, `main_ms`,
  `setup_ms`, `render_cpu_ms`, `render_gpu_ms`, `field_cpu_ms`,
  `field_gpu_ms`, `draw_calls`, `objects`, `primitives`), which
  `perf_summary.py` reports (older logs still read);
  `tools/perf_slow.sh` (a fixture run slowed or at full speed, then its
  summary); `tools/compare_frames.py` (movie frames compared pixel by
  pixel).
- **Before -> after,** on the slowed desktop CPU with chunk 22's method
  (whole process pinned; comparable with D138 and D140, overstated, see
  2):

  | Scene | Rest of the frame, ms | fps | Draw calls |
  |---|---|---|---|
  | `s3-basket-59of60` | 22.2 -> 13.6 | 17.0 -> 19.8 | 482 -> 84 |
  | `stress-moving` | 25.8 -> 14.7 | 10.2 -> 12.9 | 485 -> 89 |
  | `gate2-open` | 30.9 -> 6.4 | 17.9 -> 129.6 | 369 -> 91 |
  | `fresh` | 17.9 -> 3.7 | 41.5 -> 242.1 | 72 -> 71 |

  `s3-basket-59of60` and `stress-moving` stay slow: the tick binds them.

**2. The method: what the slowed runs got wrong** (proposed).
- Chunk 22's slowed runs pinned the whole Godot process to one core. That
  also put Godot's and the GL driver's helper threads on the game's core,
  where a phone runs them on its other cores. On `s3-basket-59of60`, one
  core without busy loops took the rest of the frame from 3.0 to about
  11.6 ms while every drawn part cost the same. With only the main thread
  pinned, the rest before the cuts was 16.7 ms, not 22. So the "about
  21 ms outside the tick" (D140) was mostly the method, plus the frontier
  view and the render recording. The slowed runs' tick is skewed too
  (`gate2-open`: 12 ms or more a tick slowed, 1.3 headless).
- **The slowed-CPU method is now `tools/perf_slow.sh --pin=main`** (only
  the main thread pinned, with the busy loops). `--pin=process`, still
  the script's default, is kept only to compare with chunk 22's and
  D140's numbers.
- **The phone estimate uses full-speed costs,** not slowed runs: each
  part's cost at full speed on the desktop, times 2.1 cold and 3.4
  throttled (the phone factors, D96). Caveat: the factors are the GDScript
  tick's; the engine's C++ render recording and the phone's driver may
  scale otherwise. Only the phone's own perf log settles a number (the
  user's rule, D138 2d).
- Spec text that cited the 21 ms or the old method is updated: the build
  plan's chunks 22, 22b, 22c and 5N, `tech-direction.md` ("Simulation
  performance"), the index.

**3. Verdict against D138's drawing budget (4 ms a frame on the reference
phone): an estimate, not closed.**
- Drawing a 60 fps frame on the desktop now costs 1.2 to 1.6 ms (the
  four scenes above; before: 1.5 to 3.9). On the phone, estimated:
  - **cold: 2.6 to 3.3 ms, all four scenes meet 4 ms** (before, only
    `fresh`; the busy scenes 6.7 to 8.1);
  - **throttled: 4.2 to 5.3 ms, none does** (`fresh` 0.2 over; before,
    5.1 to 13.1).
- **Only chunk 22's repeat on the phone closes it** (the perf log, cold
  and throttled). Proposed: what drawing still costs above 4 ms there is
  recorded, not chased into look changes (22b's done-when); the levers
  that would change the look or the renderer are O108, the user's call.
- **The phone's GPU cost is unknown.** On Android with this renderer
  `render_gpu_ms` reads 0; BLEND's two half-resolution field viewports
  and its full-screen composite are the GPU risk (desktop GPU after the
  cuts: 0.2 to 0.35 ms root, at most 0.14 ms for the fields). It shows
  only through the frame rate in chunk 22's repeat. Noted in O14.

**4. Chunk 5N: the user's explicit go.** The user (2026-09-30, verbatim):
"ok schedule work on 5N after this chunk". This settles adopting the
native tick: D140's conditional go, its condition met, is now explicit.
The native tick is no longer a contingency. How it ships stays as D140
proposed (deterministic within one build, not bit-equal to the GDScript
tick; saves load under either tick; the GDScript tick kept as the
fallback). Chunk 22d still comes first: the user asked for it "prior
working on 5N" (D143). The master spec's section 6 and known gap 5, and
`tech-direction.md`, now say the tick moves to native code. For
documentalist: `domain_architecture_rationale`'s "the simulation tick was
first kept in GDScript ... prepared as a contingency" becomes, once 5N
lands (its post-task sync), "the tick runs as native code, the GDScript
tick kept as a fallback".

**5. A drift, for documentalist: "Drawing costs little".**
`domain_architecture_rationale` (and the master spec's section 6, fixed
here) says drawing costs little. Measured: before 22b, drawing cost more
of the frame than the tick on the light scenes (`gate2-open`: 3.85 ms of
drawing a frame on the desktop against a 1.3 ms headless tick; about
8 ms on the phone, cold). After 22b: 1.2 to 1.6 ms on the desktop. The
wording proposed for the atom, replacing "Drawing costs little (flagged,
unresolved: ...)":

> Drawing is kept cheap by design rather than assumed cheap: only the
> slimes near the view are drawn, each drawing redraws only when what it
> shows changes, and repeated shapes (eyes, a basket's slots) are drawn
> in one instanced draw. Before that work, drawing cost more of the frame
> than the simulation tick on light scenes. Its share of the reference
> phone's frame is at most 4 ms (proposed); estimated within it cold and
> slightly over it once the phone throttles, and the phone measurement
> decides.

The rest of that sentence (the Compatibility renderer, which reaches the
most Android phones) stays.

**6. Left for later.**
- **Needing a spec change, not scheduled: O108** (new). DIRECT mode
  instead of BLEND in play (each slime drawn on its own with a soft edge,
  so same-species slimes no longer merge into one blob: the game's look,
  D94); the Mobile renderer (with O14's floor-phone question); a field
  resolution below half, if it changes the look. Proposed default: none
  before chunk 22's repeat; its phone numbers decide whether any is
  needed.
- **Still costing, no spec change:** the slimes' per-frame skirt loop in
  GDScript (about 0.2 ms a frame on the desktop on crowded scenes); the
  render recording (about 0.5 ms). Recorded, not scheduled.
- **Caveats for later work** (in `docs/dev/README.md`): the instanced
  discs match the old drawing exactly only while the tap feedback and the
  frontier view keep an identity transform; no movie frame covers the
  celebration (proposed: the user looks at it in the next play; a
  difference goes to chunk 24's list).

**7. The look and the labels** (proposed).
- **Accepted look change:** the baskets' outline feathers differ by at
  most 1 of 255 on one colour channel, on 13 to 135 pixels a frame
  (sub-pixel rounding: the instanced ring adds the slot's position on the
  GPU). Invisible. Everything else compared identical (frames 60, 180 and
  300 of four fixtures; `fresh` and the eyes identical).
- **Item 24.6 done in 22b:** the labels' text refreshed at most every
  250 ms, so a label may lag its slime's state by up to 250 ms; debug
  builds only; measured with the labels off, as always. Its phone number
  (the done-when's share of the frame rate) is taken with chunk 22's
  repeat.

**8. The order, unchanged:** 22d, 5N, 22c, chunk 22 repeated on the
S20 FE, chunk 24, then the coding-rule health review. The build plan marks
22b done.

ATD: 66 `@spec-link` and 19 `@test-link` tags to
`req_platform_and_performance_targets`; no atom file touched.

## D143 — Debug counters before 5N; cluster avoidance; two v2 level-design aids (2026-09-30)
**Items 24.7 and 24.8 (2 (a) and (b)) approved in direction by the user on
2026-09-30 (D144)**; their numbers stay proposed until calibrated (O107).
The rest (1, O106's default, section 3 left as is, 3 and 4) stays
proposed.
**Item 24.8 (2 (b)): a replacement was tried and withdrawn (D155).** It
replaced the lean (D145 to D152) on a branch of work that was reverted;
the lean itself stays as written here, approved in direction and
unbuilt. O106's default became the local wake (D156,
chunk 22l).
Proposed; the user reviews. Four requests from the user (2026-09-30),
relayed by the coordinator. D142 is reserved for chunk 22b as built,
recorded once 22b closes. Refinements of the coordinator's defaults say
why.

**1. The debug counters, reworked before chunk 5N (chunk 22d).** The
user: "try to do these debug changes prior working on 5N", and "ensure
these informations are also available regularily in the logs for your
perusal". Today's bar ("12 on screen : 5 simulated : 63 off screen")
misled: slimes in a basket count as on screen, and looked outside the
physics.
- **The bar shows four counts,** in slimes, every state unless said:
  - **Physics:** the slimes that cost physics this tick: calm ACTIVE,
    not sleepers. *Refined:* this is `SlimeBodies.crowd_count()`, the count
    crowd detail steps on (D140). The PERF line's `active` today comes
    from `PerfLog.active_bodies()`, which also leaves out slimes asleep at
    bedtime, though an asleep slime still settling is integrated and costs
    physics. 22d aligns `active` on `crowd_count()`, so the bar, the log
    and crowd detail count the same thing;
  - **On screen:** centre in the visible view, any state;
  - **In range:** not parked, any state (on screen or within Offscreen's
    margins);
  - **Parked.**
  On screen and In range overlap, so the four don't add up to the total.
- **The PERF line** carries the same names, `physics`, `on_screen`,
  `in_range`, `parked`, taken at the line, plus `resting` and
  `largest_cluster`. `simulated` and `off_screen` go: kept under a new
  meaning they would mislead old readings. `active` (the per-frame mean
  over the window) and `bodies` stay. `tools/android/perf_summary.py`
  reports each count (min, mean, max over a run) and the largest cluster's
  maximum.
- **Largest awake cluster:** the biggest group of touching Physics slimes
  (a connected group: A touches B, B touches C), counted in slimes.
  Touching means the contact pass found their rings in contact on the last
  tick; where the solver keeps no such list, centres closer than the sum
  of their radii plus 2 px (the implementer's choice, written down).
  Computed once per perf-log period, not every frame, and read only: it
  never changes the state (same hash). Debug builds only.
- Debug tooling only: no atom pins the overlay, so no ATD steps; the perf
  log's existing tags stay.
- **Where:** chunk 22d, after 22b and before 5N. It was headed for
  chunk 24 (the coordinator's notes); the user moved it ahead.

**2. Cluster avoidance** (proposed). The user (2026-09-30, verbatim):
"beside i've seen another test on the 3rd section with piles of active
slimes. This one is legit slow fps, and if i remember the structure of
the section, it's right next to the basket, hence the problem. maybe we
should add this as a level design rule: preventing large cluster to
happen. It could be handled in multiples ways both in level design but
also in train management currently movement is random, but we could
favor cluster reducing activity. It doesn't change that if the player
activelly build such a cluster the performance issue will appear."
- **Grounding.** A train slime's hops are already aimed along the loop
  (`Train`: at `hop_reach()` ahead of its progress); only their timing is
  random, each slime on its own seeded timer (1.5 to 3 s, longer for
  bigger slimes, `SlimeBodies`). Nothing today spaces train slimes apart.
  Rule 16 already asks that a big pile on one screen stay mostly still;
  an awake cluster is the case it doesn't cover. What a cluster costs:
  its slimes keep waking each other (a pile touching an awake slime never
  rests, O105), and its pairs load the contact pass.
- **(a) A level-design rule, rule 23** (`level-design.md`): no spot where
  many slimes gather awake. Known shapes: a bowl or dip next to a basket,
  an outlet releasing into a crowd, a narrow ledge where the train queues,
  a dead end on the train's path (rule 3 already bans dead ends on the
  loop; this adds places where slimes pile up in practice).
  - **The measure:** the largest awake cluster (§1) over a level's own
    scripted runs: its played test (from fresh, filling every basket) and
    each basket's fire-and-drain. The deliberate stress fixtures
    (`stress-*`) are excepted, as in D96.
  - **The limit** (proposed): the largest awake cluster above 20 slimes
    for more than 5 s in a row fails. 20 is where crowd detail steps to
    level 1 (D140). *Refined:* a limit held for a time, not an instant
    peak: a basket filling, a dip nudging fusion (rule 5) and a release
    make short clusters that rest or split. The number is calibrated from
    22d's logs on the test level before chunk 24 fixes it (O107): a dense
    train queue on the loop may read as one long cluster.
  - **Checked by:** the level bench (its RESULT line gains 22d's names,
    `largest_cluster` and the seconds above the limit) and the level's
    own test on its played run. The level-rules checker can't run the
    simulation, so its rule 23 line points at the bench and the played
    test, as rule 12's played test is its proof.
    `docs/level-design/06-population.md` and `09-check-the-rules.md` and
    the `level-review` skill gain the rule (chunk 24's work, not the
    spec's).
- **(b) The train leans away from clusters** (proposed).
  - When a train slime's hop timer runs out, it counts the Physics slimes
    near its landing point (centres within 2 base-slime diameters, 96 px,
    of the hop's target) that it can't fuse with (another species, or a
    fusion past the maximum size, D49). With 3 or more, it waits 0.5 s
    and looks again, at most 4 times in a row (2 s at most), then hops
    anyway: the train never stalls on it.
  - *Refined:* waiting, not aiming past the crowd: `Train.aim()` already
    handles steps, drops and overhangs, and a longer hop past a crowd
    would bypass that logic. Counting only slimes it can't fuse with
    leaves the dip nudge (rule 5, D119) working: same-species bunching
    fuses, which shrinks a crowd anyway.
  - Deterministic: the count comes from the simulation's state (the pair
    grid, or a read-only count over the same cells; the implementer
    checks where the hop decision sits against the grid's build), and the
    wait is a constant, never a draw, so the seeded streams stay aligned.
    *Refined:* "no hash change in unrelated fixtures" can't be promised: any
    fixture where a train slime lands near a crowd changes (the bowl,
    basket 3, `stress-moving`, likely more). The chunk lists which hashes
    changed and why, and regenerates them.
  - Only train slimes. Calls, answering, unsure and heading-back slimes
    are unchanged: the call stays the player's (c).
  - It changes `req_hopping_behavior` (next to a crowd, a train slime's
    hop may come up to 2 s later than its 1.5 to 3 s timer); flagged for
    documentalist once approved.
- **(c) A player-built cluster stays possible.** Accepted, as the user
  says: a child calling slimes into one spot builds one. Crowd detail
  (D140, D141), the tick cap (D138), chunk 5N and chunk 22c cover it.
- **O106 goes with it.** A fired basket's drain is today's biggest awake
  cluster (about 89 active slimes, D138): each release wakes the whole
  pile, which never rests again. Rule 23 can't pass at any basket with a
  quota above 20 until that changes. O106 stays with item 24.3, which runs
  first; its proposed default: a release wakes only the slimes touching
  the one released (the resting-pile wake rule, `tuning.md`), not the
  whole pile.
- **Section 3 of the test level:** no level edit now (proposed). It is
  the declared stress area (rule 16, D67) and DoD 30's worst case, which
  chunk 22's repeat measures; changing its layout mid-pass would move the
  target. The pile the user saw sits between the bowl's far wall and
  basket 3 (the train climbs out of the bowl, the plateau is short, the
  low rim's 17 sleepers drop there, and the drain releases there). Chunk
  24 measures it once 24.3 (with O106) and (b) have landed; if it still
  breaks the limit in normal play, a small edit (an LD chunk) is the
  user's call (O107).
- **Where:** chunk 24, items 24.7 (the rule and its measure) and 24.8 (the
  train's lean), after 24.3.

**3. v2: an activity-zone tool** (proposed). The user (2026-09-30,
verbatim): "add to the todo list for v2.0 a dev tool that will allow the
level designer to have an idea given a point on the map, of the active
physic computation zone (this would ensure we "space" things out enough
to prevent cluster potential: area were activity and clustering are
expected to be near one another)."
- In the level tools or the editor, pick a point or a framing zone: the
  tool shows the **activity zone** while the camera is there, the view at
  that zoom grown by Offscreen's margins (surely simulated within the near
  margin, 288 px; maybe simulated up to the park margin, 384 px; parked
  beyond).
- It overlays the spots where clusters are expected (baskets and their
  outlets, dips, split zones, narrow ledges on the loop, the landing spots
  of sleeper shelves), so a designer sees when two of them share one
  activity zone.
- It serves rule 23. `versions/v2/README.md`, under "Level design made as
  easy as possible". No v1 work.

**4. v2: a population fork, a cluster-breaking object** (proposed). The
user (2026-09-30, verbatim): "then we can have in v2 cluster breaking
objects: we have already planned for forks and similar objects. One such
could simply switch path by population within a given fork."
- **A fork that sends the next slimes down its emptier branch:** it counts
  the slimes on each branch's first stretch and routes the flow to the
  one with fewer. Activation: presence (it counts slimes, D15); it isn't
  tapped. Deterministic: it counts, and reads no clock; a switch holds for
  at least a set number of ticks, and a tie keeps the current way, so it
  doesn't flicker.
- **It sits beside the signposts; it replaces neither.** Like a filter
  (D47, D88), it is a kind of fork, and like every fork it has a plain
  signpost (rule 6), which here shows the way it currently sends slimes.
  A large signpost (which branch the camera follows) is separate and may
  stand at it too.
- **It is the spring-back pathway's opposite** (D17): the pathway sends a
  dense clump down one branch, the population fork spreads a crowd over
  both. Both branches are loop (rules 1 and 3).
- Open for v2's scoping: whether it counts slimes or weight (clusters cost
  per slime; presence objects count weight, D16), which stretch it
  counts, off screen (D70: it counts the proxies), and which branch the
  camera follows.
- Listed with v2's reusable interactive objects (`versions/v2/README.md`,
  `interactive-objects.md`). It serves rule 23.

**Terminology** (`concept.md`): the debug overlay's slime counts renamed;
**awake cluster**, **activity zone** and **population fork** added.

## D144 — Chunk 22b's record approved; cluster avoidance approved in direction; the architecture atom's split (2026-09-30)
The user was shown three items and replied, verbatim: "agreed"
(2026-09-30).
- **D142, as written:** chunk 22b as built; the slowed-CPU method
  (`tools/perf_slow.sh --pin=main`) and the phone estimate from
  full-speed desktop costs (× 2.1 cold, × 3.4 throttled); the verdict's
  reading (an estimate: met cold, missed throttled); the accepted feather
  difference (at most 1 of 255); the debug labels' text refreshed at most
  every 250 ms (item 24.6). With it, the drawing wording D142 (5) proposed,
  which documentalist wrote into `domain_architecture_rationale`
  (fee5cdb).
  - **Still open inside it:** the throttled drawing verdict: chunk 22's
    repeat on the phone decides it. O108 stays open, with its proposed
    default (none of the levers before 22's repeat). The 4 ms drawing
    budget itself is D138's and stays proposed with D138 (the atom's
    wording already says "(proposed)"); how 5N ships stays D140's
    proposal.
- **D143's items 24.7 and 24.8, in direction:** level rule 23 (no spot
  where many slimes gather awake, measured by the largest awake cluster
  over a level's played test and each basket's drain) and the train's
  lean (a train slime's hop waits, at most 2 s, while slimes it can't
  fuse with crowd its landing point). **Their numbers stay proposed**
  until chunk 24 calibrates them from chunk 22d's logs (O107): rule 23's
  limit (above 20 slimes for more than 5 s in a row), the lean's wait
  (0.5 s, at most 4 times), its count (3 slimes) and its reach (96 px).
  Once built, they change `req_hopping_behavior` and add a rule atom
  under `req_level_design_rules` (documentalist, at chunk 24's sync).
  - **Not covered, still proposed:** the rest of D143: chunk 22d's
    counters, O106's default (settled in 24.3), section 3 left as is
    (O107 (c)), and the two v2 aids (the activity-zone tool, the
    population fork).
- **Splitting `domain_architecture_rationale`,** the user's call: the ATD
  audit flags the atom as BLOATED, and the user agreed to split it into
  smaller atoms, which renames what code tags point at. Documentalist does
  it after chunk 22d is committed. Flagged in the index.
- The spec no longer tags D142's points (proposed): `tech-direction.md`
  (how performance is measured; the feather difference), `tuning.md` (the
  phone estimate; the labels' refresh) and the build plan's 24.6. Rule 23
  (`level-design.md`), the lean (`slimes.md`), their `tuning.md` rows and
  the build plan's 24.7 and 24.8 read "approved in direction", their
  numbers proposed.

## D145 — Withdrawn: the train holds before a crowd (2026-09-30)
**Withdrawn by D155 (2026-10-03).** It was the hold: a train slime whose
hop was due waited while its landing point was crowded or a queue of
waiting train slimes lay ahead, and such a slime could rest; it replaced
D143's lean (item 24.8) and proposed the local wake, which D156 keeps.
Full text on branch `archive/fps-session-2026-10`, commit 59db79b (its
as-built notes, 9965847; final text at the branch's tip, bcaa8b7).

## D146 — Withdrawn: chunk 22e, the cluster fixes before 5N (2026-09-30)
**Withdrawn by D155 (2026-10-03).** It moved the hold and the local wake
into chunk 22e, before 5N, and recorded 22e as built (4750f12). Full text
on branch `archive/fps-session-2026-10`, commit dc3c69d (as-built notes,
9965847).

## D147 — Withdrawn: the hold, second round, chunk 22f (2026-10-01)
**Withdrawn by D155 (2026-10-03).** It reworked the hold (a crowd check
over a box ahead of the hop, a forced hop when the whole train waits,
resting by contact); it opened O109 and O110, both withdrawn with it.
Full text on branch `archive/fps-session-2026-10`, commit 2bb5100
(amended in ace6202).

## D148 — A save wipe flag for development builds, chunk 19w (2026-10-01)
*Re-entered by D155 (2026-10-03), edited:* the first text, on branch
`archive/fps-session-2026-10` (commit ace6202), placed chunk 19w among
withdrawn chunks; the order is now D155's. The rest is as written there.
Proposed where it goes beyond the user's words; the user reviews.

**Approved in direction, amended by D149 (the user, 2026-10-01).** The
user approved the direction: the per-launch flag, for **automated testing
only** ("the flag is only for automated testing. i've the reset button");
by hand, a level is started over with the parent's delete of its save.
O112 is closed (no toggle that stays set) and O111 is answered (the save
format may break before the first store release; see D149). The details
below marked proposed still wait for the user. The user also approved
documentalist's wording for `rule_saves_never_wiped`'s LOGIC ("i agree
with the wording"), verbatim: "No player's build ever wipes a save: no
update, migration or load-failure path deletes an existing level save;
only a parent's explicit delete of one level's save removes it. A
development aid that exists only in debug builds, is ignored by a release
build and never reaches a release install, is outside this rule." It
replaces the bare "Saves are never wiped" this entry's documentalist note
asked about (written into the atom as `rule_saves_never_wiped` 1.1,
729fe87, kept through the revert, D155); how it squares with D149's
pre-store-release rule is checked in D149 (6).

The user's words, verbatim (2026-10-01):
"Currently we aren't in production, so we may relax save file deletion in
testing. Ensure that a flag can be set so that if set, the save file is
automatically deleted at the begining of a test session. Of course, when
testing save/restore state we need to remove this flag."

**Reading.** "A test session" is read as **one launch of the app for
testing**. In our terms a *session* is the 15 min play period; the wipe
acts once per launch, not at each session's start inside a run (a session
started by the first tap after sunrise doesn't wipe). Relaxed is the
deletion of saves on a developer's own build, nothing else: the save
**format** stays a hard contract (format 1, additive keys, older saves
load), and whether format compatibility is also relaxed in development is
open (O111). Nothing here changes what a player's build can do. *(D149:
O111 answered: the format is a hard contract only from the first store
release; before it, a format change may break older saves, and a save a
build can't use is set aside and the level starts fresh.)*

**Grounded in the code (read 2026-10-01; the save and startup code is
unchanged by the revert):** the level saves live in
`user://saves/` (`SaveStore.DEFAULT_DIRECTORY`): per level
`<level id>.json`, its backup `.bak`, a write's side files `.new`, files
set aside as `.unreadable` (`.2`, `.3`...) and version copies `.v<n>`.
`read()` falls back to the backup when the save is missing, so a save
deleted alone would come back from its backup. The parent code is
`user://parent.json` (and its `.bak`). `main.gd` reads the user arguments
(`OS.get_cmdline_user_args()`) in `_ready`, creates the stores, loads the
level, then resumes from the save in `_resume_play()` only when test mode
is off: **a fixture run never reads the player's save**. `--load=PATH`
and the run configuration's `"load"` key are test mode's (start from the
save at PATH). The check for debug-only tools is `TestModeGuard.allows()`
(`OS.is_debug_build()`); the release preset excludes `src/test_mode/*` and
`src/debug/*`. On Android, `tools/android/perf.sh` passes flags through
the launch intent's `slime_args` extra, which the SlimePlatform plugin
reads in a debuggable build only; the debug app is its own package
(`com.slimetrain.dev`), the release one `com.slimetrain`.
`tools/perf_slow.sh` always runs a fixture in test mode and forwards its
extra arguments to the game.

**1. The flag** (name proposed): **`--wipe-save`**, a user argument after
`--` (on Android, in `slime_args`). Never on by default, in any build.
Command line only: not a test-mode run configuration key, not a setting,
and no toggle that stays set across launches (D149, O112 closed: the
flag is for automated testing only; manual play starts a level over with
the parent's delete).

**2. What it wipes** (proposed): **every file in `user://saves/`**, every
level's save with its backup, side files, set-aside files and version
copies. The backup has to go (the read would bring it back); the others
go so that the start is a true fresh install for the level saves. The
directory itself may stay. Every level is then as on a fresh install: the
first-play hint is due, the celebration can play again, and v1's session,
which lives in the level's save (D104), starts afresh. Unlike the
parent's delete (D43, D104), which keeps a running session so deleting
can't dodge bedtime, the wipe doesn't keep one: it acts at launch, on a
developer's build, before any session is read.
- **`user://parent.json` is kept** (proposed), and with it the parent
  code and setup: a wipe doesn't send the next launch through setup. No
  `--wipe-parent` in this chunk (proposed): the user asked for the save
  file only, and a fresh setup is a different test (clearing the app's
  data does it). If wanted later, it is a second flag beside this
  one, never part of `--wipe-save`.

**3. When and where** (proposed):
- **At startup, before anything reads a save:** in the main scene's
  `_ready`, after the stores are made and before the level loads and
  `_resume_play()` reads the save. Once per launch.
- **Only the main scene's default directory** (`user://saves/`). A store
  a test gives (`SaveStore.new(DIR)`, as every save test does) is never
  wiped by the flag. The wipe's function takes its directory as an
  argument so its unit tests run on a scratch directory.
- **Not a `SaveStore` path.** The store keeps its rule: it never deletes
  a save except on the parent's explicit delete
  (`rule_saves_never_wiped`). The wipe lives in a debug-only file, for
  example `src/debug/save_wipe.gd`, named by path only after the guard
  allows it (as test mode is), so the release preset leaves it out with
  `src/debug/*`. `SaveStore`'s header gains a one-line pointer to it.

**4. The guard** (the user's and the coordinator's constraint; the rest
proposed): **debug builds only**, through the same check as test mode
(`TestModeGuard.allows()`). In a release build the flag is **ignored**:
nothing is deleted and one line is logged (`Save wipe: --wipe-save
ignored, not a debug build.`). On Android a release build doesn't receive
`slime_args` at all, and a debug install is a different package, so the
flag can never reach a release install's saves, even on the same phone.

**5. With a save to load: refused** (proposed). When the launch also
names a save to start from (`--load=PATH`, or a test script whose run
configuration has `"load"`), the wipe doesn't run, an error is printed,
and in a debug build the app quits with exit code 1, as a bad test-mode
or perf-log flag does today (in a release build both flags are already
ignored). A save/restore run that carries the flag by mistake fails
loudly instead of silently testing a fresh start, and a `--load` path
inside `user://saves/` can't be deleted before it is read. The other way
(ignore the wipe with a log line, load anyway) is the user's call.
`--fixture` is not a conflict: fixtures are `res://` files. With test
mode and no load, the wipe runs as asked (harmless: a fixture run doesn't
read the player's save; it matters only if the run autosaves).

**6. The log line** (proposed): on every wipe, one line on standard
output (logcat's `godot` tag on Android): `Save wipe (--wipe-save):
deleted N files from user://saves/; parent.json kept.`, N possibly 0. A
file that can't be deleted is named in an error line, and the launch
carries on (a dev aid must not block play).

**7. The tools** (proposed):
- **`tools/android/perf.sh` gains `--wipe-save`, off by default.**
  Accepted with `--fixture=none` and `--free-play` (normal play, which
  reads the device's save); refused with a fixture (exit 2, a bad
  argument: a fixture run never reads the player's save). It adds
  `--wipe-save` to `slime_args`; the session's `perf.log` header already
  records the launch line, so a wiped session shows in its record. Its
  header's "the player's data is never at risk" paragraph is amended:
  with `--wipe-save`, the debug app's level saves are deleted at launch,
  the parent code kept; it still never uninstalls or clears the app's
  data. **Why off by default:** the user's "a flag can be set" reads as
  an opt-in per test session, and `--fixture=none` exists to measure the
  device's own (often late-game) save, which a default wipe would destroy.
- **`tools/perf_slow.sh`: no new option** (proposed, against the
  coordinator's suggestion): it always runs a fixture in test mode, which
  never reads the player's save, so the flag would do nothing there; its
  extra arguments already pass any flag through.
- **`docs/dev/README.md`** (the coding chunk writes it): what the flag
  does and doesn't wipe, that it is for automated test runs only (D149),
  how a test run passes it on the desktop (`godot --path . --
  --wipe-save`) and on the phone (`perf.sh --free-play --wipe-save`),
  that manual play starts a level over with the parent's delete instead,
  and the rule in 8. *(D149: the hand-typed adb launch line first planned
  here is dropped.)*

**8. Save and restore tests never pass it** (the user's: "when testing
save/restore state we need to remove this flag"). The kill-and-reload
tests, the delete-save tests, the persistence fixtures (`midair`,
`old-version`), every fixture and its sidecar, the test scripts and the
end-to-end suite never carry `--wipe-save`. A guard test (proposed)
checks that no file under `tests/`, `levels/*/fixtures/` or the test
scripts names it, the flag's own tests apart. A manual save and restore
check on the phone or the desktop is run without it; `docs/dev/README.md`
says so.

**9. What doesn't change:** the save format (format 1, additive only; a
hard contract *until the first store release, D149*); `rule_saves_never_wiped` and the contract's guarantee ("a
level's save is never wiped by an app update"): a release build can't
wipe, and no update, migration or load-failure path gains a delete; the
parent's delete (D43, D104); the simulation (same hashes).

**10. Chunk 19w** (name proposed: a small add-on to chunk 19's
persistence, S). **Order:** D155's (19w first among the remaining
chunks). It shares `main.gd`'s startup and `docs/dev/README.md` with the
chunks around it, so it doesn't run while another chunk edits them. It
**keeps both ATD steps**: documentalist preflights it against
`rule_saves_never_wiped` (STABLE, on the contract's surface) before any
code, with `req_persistence_and_saves`, `domain_saves_per_level`,
`rule_released_level_stable_with_migration`,
`req_test_level_and_test_mode` and `domain_testability`.
- **Done when:**
  - **unit tests** (on a scratch directory and an explicit guard):
    - *the flag wipes:* with two levels' saves, their backups, a side
      file, a set-aside file and a version copy, the wipe leaves the
      directory empty, leaves a `parent.json` (and its `.bak`) beside it
      untouched, and logs one line with the count;
    - *no flag keeps:* a launch without it leaves every file
      byte-identical;
    - *a release build ignores it:* a guard answering "not a debug
      build" deletes nothing and logs the ignored line;
    - *with a load, refused:* `--wipe-save` with `--load=PATH`, and with
      a test script holding `"load"`, deletes nothing and returns the
      error that makes a debug launch exit 1;
    - *before any read:* a game started with the flag on a directory
      holding a save starts fresh (the first-play hint due);
    - *only the default directory:* a store a test gives is never wiped
      by the flag;
    - the guard test of 8, and the release preset's exclude filter
      covering the wipe's file (as `test_test_mode_guard.gd` checks
      `src/test_mode/`);
  - **perf.sh**, checked by hand on the emulator or the phone:
    `--free-play --wipe-save` starts fresh and its log line is in
    `logcat.txt`; `--fixture=<name> --wipe-save` is refused with exit 2;
    without the flag, the device's save is resumed as before;
  - **same hashes:** every fixture's hash unchanged; the full suite
    green;
  - `docs/dev/README.md` and `SaveStore`'s header carry their notes.

**For documentalist (preflight, before coding).** No conflict found with
the contract or `rule_saves_never_wiped`'s intent and expectation (an app
update never wipes a parent's save): the flag is no update path, exists
only in debug builds, and acts on the debug package's own data. The
rule's LOGIC now carries the user-approved wording (1.1, above).
`req_persistence_and_saves` may gain a technical-interface
line (a third way saves go, debug only), and the wipe's file is tagged to
`req_test_level_and_test_mode` or a new ARCHITECTURE atom, documentalist's
call.

**Open:** O111 (is save-format compatibility also relaxed in
development?), O112 (a per-launch flag, or also a toggle that stays set
across launches?). *Both resolved in D149.*

**Terminology** (`concept.md`): **save wipe** added (proposed), kept apart
from the parent's *delete* of one level's save.

*As built (chunk 19w, on main, fdae364, 2026-10-03):* see the as-built
note under D149, which covers both.

## D149 — The save format before the first store release; the save wipe for automated testing only (2026-10-01)
*Re-entered by D155 (2026-10-03), edited:* the first text, on branch
`archive/fps-session-2026-10` (commit d4fe7a9), also qualified passages
of withdrawn decisions and placed chunk 19w among withdrawn chunks; those
mentions are left out, the order is D155's. The rest is as written there.
The user's answers to D148's open questions, verbatim (2026-10-01): "the
flag is only for automated testing. i've the reset button. save format may
break between version. That's our prerogative to ensure migration (if the
app has been shipped, otherwise, we just wipe). i agree with the wording."
Resolves **O111** and **O112**. Approves D148 in direction (the flag, for
automated testing only) and documentalist's wording for
`rule_saves_never_wiped` (quoted in D148's head). Proposed where it goes
beyond the user's words; the user reviews.

**1. The save wipe is for automated testing only (O112; the user's).**
The per-launch `--wipe-save` is enough: no toggle that stays set across
launches, no marker file, no debug-overlay switch. It is passed by the
test tools (`tools/android/perf.sh --wipe-save`, a scripted desktop
launch), not used in manual play. To start a level over by hand, the user
uses the parent's **delete** of that level's save (D43, D104; the user's
"reset button"). D148's items 1 and 7 are amended: `docs/dev/README.md`
presents the flag as an option of automated test runs and points manual
play to the parent's delete; the hand-typed adb launch line is dropped.
Everything else in D148 stands as written.

**2. The save format may break before the first store release (O111; the
user's).** Keeping a player's save across a save-format change, with a
migration, is owed only once the app has **shipped**: once a build has
gone out in a store, at the first store release (probably v4, D137; v1 is
never in a store, D135). Until then, a save a build can't use because of
a format change is discarded ("we just wipe"), not migrated. So, until
the first store release:
- A save-format change may be additive or breaking. It needs **no
  migration and no special approval**; it is recorded like any other
  choice (the chunk's record, `docs/dev/README.md`'s save section, the
  atoms).
- *(proposed)* A breaking change **bumps the format number** (`format`
  2, 3...), so an old save is refused plainly rather than misread. An
  additive change with safe defaults may keep the number, as chunk 23's
  three did (D125): cheaper, and it keeps the developer's own saves.
- No format migration code is kept before shipping.
- From the first store release on, every save-format change ships with
  its migration, and the format is a hard contract again (what the spec
  said before this entry, now dated).

**3. A save a build can't use, before the first store release**
(proposed). *Today* (`main.gd`'s `_resume_play`, chunks 8 and 19, D131):
a file that isn't JSON is set aside as `.unreadable` and the backup is
tried; a save that parses but `SaveData.problems()` refuses (a format
newer than the build's, a newer level version, another level, a bad
shape) is **left untouched, the level starts fresh, and the store blocks
writes for that level**. That keeps the file, but it isn't "we just wipe":
the level would start fresh at every launch and never save again until
someone removes the file. Proposed instead, before the first store
release:
- The refused save is **set aside** with the store's existing suffix
  (`.unreadable`, then `.2`, `.3`... if taken), its backup with it, and
  the level **starts fresh with autosave on** (no write block). Its
  session starts afresh with it (v1's session lives in the level's save,
  D104), as on a save wipe.
- **One log line** on the error output, for example: `Save: <path> can't
  be used (<reasons>); not shipped yet, so it is set aside as <set-aside
  path> and the level starts fresh.`
- **A format other than the build's own** is refused, older or newer.
  (`problems()` today accepts any format from 1 up to the build's own;
  with only format 1 there is nothing older yet.)
- **Why set aside, not delete:** the same effect in play (the level
  starts fresh, as the user asked); the file stays for a look when a
  refusal is a bug rather than a planned change; `--wipe-save` and the
  parent's delete already clear set-aside files; and the approved wording
  of `rule_saves_never_wiped` holds as written (see 6). A real delete
  instead is the user's call, and needs one more clause in that atom.
- **Unchanged:** a file that isn't JSON is set aside as today; a save of
  an **older level version** is still migrated as it loads, displaced
  slimes lost (D72, D131, the `old-version` fixture, item 24.4). That is
  a level change, not a format change, and it already works; this entry
  doesn't touch it.
- **One switch.** Whether the app has shipped is a single value in the
  code (its name the implementer's, for example `SaveData.SHIPPED`),
  false until the first store release. Turning it on is part of that
  release (noted in `versions/v4/README.md`). From then on, a refused save
  is handled as today (left untouched, the level starts fresh, writes
  blocked), and format changes ship with their migrations.
- **Where it is built** (proposed): in **chunk 19w**, beside the wipe. It
  touches the same code (`main.gd`'s startup and `_resume_play`,
  `SaveStore`, `SaveData`) and has the same preflight atoms. Order:
  D155's. Extra done-when items:
  - before shipping (the switch off), a save with another format number
    (newer, and older with a test-only number), and a format-1 save
    that fails the shape check, are each set aside with their backup; the
    level starts fresh; the next autosave writes a new save; one log line;
  - with the switch on, the same saves are left untouched and writes are
    blocked (today's tests, kept and run with the switch on);
  - a file that isn't JSON behaves as today; an older level version still
    migrates (`old-version`); every fixture's hash unchanged.

**4. Fixtures and test-mode scripts: unchanged.** The user said nothing
about them, so their formats stay hard contracts as they are
(`CODING_RULE.md` §4). One consequence to keep in mind (flagged, not
decided): fixtures *are* saves (build plan, principle 4), so a breaking
save-format change can't land without converting every fixture in the
same change. That conversion falls under the fixture format's own rule.
In practice the relaxed rule frees the players' and developers' saves on
devices, not the fixtures in the repository.

**5. Qualified "until the first store release".** Passages that called
the save format a hard contract or asked a migration for every format
change now hold until the first store release: D148 (the reading and
item 9), `tech-direction.md`'s Saving and Save wipe, the build plan's
chunk 19w, `concept.md`'s Persistence, the master spec's 5.10, and
`README.md`. **Not changed:** "saves are never wiped", which is about a
player's build (see 6); level rule 20 and
`rule_released_level_stable_with_migration`, since a released level is a
shipped one and the rule already starts at release; D124 and D125, a
record of what was done then. **Outside `specs/`, not edited:**
`CODING_RULE.md` §4 says "the save format ... [is a] hard contract" and
names "left untouched, the level starts fresh, writes are blocked" as the
one sanctioned fallback; both need "until the first store release" (and 3's
set-aside) if this is approved. That is the user's file, used by the
health review.

**6. Squared with `rule_saves_never_wiped`'s approved wording.** "No
player's build ever wipes a save: no update, migration or load-failure
path deletes an existing level save; only a parent's explicit delete of
one level's save removes it." Before the first store release there is no
player's build, and 3's set-aside deletes nothing: set-aside files are
already part of this rule (D131). So the load-failure clause holds as
written. Two points flagged, not resolved:
- **(a) If the user wants a real delete before shipping**, the wording
  conflicts: a release-preset build made before shipping would delete on
  a load failure, and the development-aid exception covers only aids that
  exist in debug builds alone. The fix would be one more clause, for
  example: "Before the first store release there is no player's build,
  and a build may discard a save it can't use."
- **(b) The contract** (`contract_atd`) guarantees for v1 that "a level's
  save is never wiped by an app update". Nothing is deleted, but before
  shipping a format change starts the level fresh, which a parent would
  see as a wipe, for example on the family phones where the children play
  development builds. v1 never ships, and the user accepts it ("otherwise,
  we just wipe"). The guarantee's wording may still want "once shipped".
  It is on the contract's surface, so documentalist proposes and the user
  confirms.

**For documentalist** (with chunk 19w's preflight, before its code):
`rule_saves_never_wiped` (the approved LOGIC, now 1.1; 6), `req_persistence_and_saves`
("additions ... keep format 1, so older saves still load" holds until the
first store release; the pre-store-release set-aside and the shipped
switch; the wipe as a third, debug-only way saves go),
`rule_released_level_stable_with_migration` (unchanged in substance;
released means shipped), `domain_saves_per_level` ("level updates migrate
saves rather than breaking them": still true of level versions; format
changes before the first store release don't migrate), `contract_atd`
(6 (b)), and `req_test_level_and_test_mode` or `domain_testability` (the
wipe is for automated test runs only).

**Terminology** (`concept.md`): **shipped** added (proposed): the app
from its first store release on. **Save wipe** amended: for automated
test runs only.

*As built (chunk 19w, on main, fdae364, 2026-10-03; covers D148 too):*
- **The wipe (D148):** `--wipe-save`, debug builds only, per launch, in
  the main scene only, before the level loads and any save is read. It
  is refused, nothing deleted, exit 1, with `--load`, or with a test
  script that names a save to load **or can't be read** (the last is the
  build's own choice, **proposed**: an unreadable script can't prove it
  loads nothing). A release build logs it as ignored. `perf.sh
  --wipe-save` is accepted with `--free-play` or `--fixture=none` only,
  exit 2 with a fixture.
- **Deviation:** the release build's "ignored" branch lives in `main.gd`,
  not in the wipe's own file: `src/debug/save_wipe.gd` is left out of the
  release export, so it can't log there. Behaviour as specified.
- **The set-aside (D149, 3):** one switch, `SaveData.SHIPPED`, false.
  With it off, a save of another format number (older or newer) or one
  failing the shape check is renamed `.unreadable` with its backup, the
  level starts fresh and saves again. With it on: keep-and-block, as
  before.
- **Not verified on a device:** `perf.sh --wipe-save` (the agent's run was
  refused by the permission system; the user runs it,
  `docs/perf/2026-10-03-s20fe-session.md`, item 7).
- **Still flagged (5):** `CODING_RULE.md` §4 still names keep-and-block as
  the only fallback; it needs "until the first store release" (the
  user's file).
- Suite 1365/1365. D148's and D149's proposed details still wait for the
  user's approval.

## D150 — Moves to the loop start one at a time, to a random free spot; no stall clock while parked; chunk 22h (2026-10-02)
*Re-entered by D155 (2026-10-03), edited:* the first text, on branch
`archive/fps-session-2026-10` (commit 25ef5ae), also covered withdrawn
rules (a train slime waiting before a crowd, the safety catch against a
frozen train) and a wording fix in a withdrawn decision; those are left
out, and the order is D155's. The rest is as written there.
The user's decisions (2026-10-02), after chunk 22g's stall diagnostic
(withdrawn code, D155; its report, `docs/perf/2026-10-01-chunk-22g.md`,
section 5, is on branch `archive/fps-session-2026-10`): "2 problems arose:
first is easy: emergency teleport should be randomized in position.
Second is quite easy as well: emergency teleport should have a cooldown.
between 0.5s to 2s." To the coordinator's questions: the cooldown is a
**global queue**, one move to the loop start at a time, the next waiting a
random 0.5 to 2 s after each; and the stall clock is **paused while a
train slime is parked**, resuming when it is simulated again (amends D118).
The user's "emergency teleport" is the **move to the loop start**
(`LoopStart.move`), the one move the three safety nets share: lost free
slimes (D10), stuck slimes (D100) and stalled train slimes (D118, D121;
out of bounds included). All three go through what follows; that lost
free slimes take the same move is checked in the code (`Offscreen.lose`),
so they are included (proposed, as the coordinator suggested). Also the
user's: `stress-moving` is an intentional cluster of disproportionate
dimensions, so its numbers are never targets to tune the rules to (D153
later gave it an abuse target: no crash, no freeze, at least 15 fps; not
a 30 fps target). Proposed where it goes beyond the
user's words. Opens O113.

**What 22g measured** (on the withdrawn build, D155). In
`s3-basket-59of60` over 10,000 ticks (seed 1), the stall net moved 87
train slimes, 64 of them at tick 3600, all parked; then 305 stuck moves on
61 slimes at the loop start (seed 2: 86 and 172). Two causes:
- **Parked slimes stalled.** Parking doesn't freeze a train slime: it
  moves along the loop at the deterministic off-screen pace (about
  67 px/s for a size 1), but single file: it never comes closer than the
  two slimes' widths behind the train slime ahead of it, parked or not,
  and waits there (`Offscreen`, chunk 15, D69). The 87 were such a line
  in the bowl before basket 3, about 50 px apart at nearly the same
  distance along the loop: only its front could move, and the front was
  itself blocked by the slime ahead. A parked line can so wait more than
  60 s, and theirs ran out together (D118: "on screen or off").
- **Landings on one point.** `LoopStart.move` puts a slime on the first
  free spot of 8 along the loop from its start, and on the start itself
  when all 8 are taken. 64 moves in one tick took the 8 spots, then piled
  the rest on one point (x 210, y 409); 2 s later they were stuck (D100),
  moved again onto the same pile, and so on.
- **Likely on main too (to check when 22h is built).** Both causes are in
  code the revert kept (the single-file parked line, chunk 15; the first
  free spot of 8, D124, D126), not in the withdrawn rules, so the bug
  most likely exists on 0196c25's base as well. Chunk 22h first measures
  the same runs on main (its "before") and records whether they show it.

**1. The stall clock pauses while parked (the user's; amends D118).** A
train slime's 60 s without 24 px of progress counts only the ticks it is
simulated. While it is parked the clock doesn't run; once simulated again
it resumes from where it was (not from zero). Progress made while parked
(at the off-screen pace) still counts as progress, as today. Out of
bounds is unchanged (a parked slime outside the level's bounds is still
stalled). *Which parked slimes (O113, proposed: every parked train
slime, the user's wording):* the alternative pauses only a parked slime
waiting in the single-file line. In effect the two hardly differ: a
parked slime that isn't waiting moves at the pace, so it advances 24 px
in well under a second and its clock never comes near 60 s; "every
parked slime" is the simpler rule to build and test. *How, proposed:*
each tick a followed slime is parked, its last stall mark's tick moves on
by one, so the time since its last mark stays what it was; that tick is
already in the saved train record (`marked_at`), so a reload resumes the
same clock, no new save key.
*Why this can't leave a train stuck for good:* a parked train slime is
only ever blocked by the train slime ahead of it; the front of any such
line is simulated (its clock runs and the stall net still acts on it) or
moving. When the front gets going or is moved, the parked line follows. A
parked line waits as long as its front does, out of sight. In
`s3-basket-59of60` that means the bowl's parked line no longer drains by
the stall net at tick 3600: it waits until the crowd ahead moves or the
view comes near (reported, not a target).

**2. The loop-start queue (the user's: one at a time, 0.5 to 2 s apart).**
- A safety net no longer moves a slime itself: it finds the slime **due**
  a move, and the **loop-start queue** moves the slimes due, **one per
  turn**. After each move the next turn comes **30 to 120 ticks** later
  (0.5 to 2 s at 60 Hz, a whole number of ticks, uniform, both ends
  included). With no move in the last 120 ticks, the head moves at once.
- **Order (proposed): first due, first moved** (FIFO), by the tick each
  slime became due, ties by ascending id. A slime **out of the level's
  bounds** goes first (it is outside the level, falling), ascending id
  among several. A slime due for two reasons waits once, at its earliest;
  it is logged under that reason (on a tie: out of bounds, stalled,
  stuck, lost).
- **While it waits (proposed):** a queued slime keeps its state and
  carries on as it would: simulated or parked, resting, hopping. Nothing
  keeps it in place. At its turn its reason is checked again: a stalled
  slime that has since advanced 24 px, a stuck pair that has come apart, a
  lost slime back on screen or no longer free, a slime back in bounds, a
  bedtime-asleep slime: it leaves the queue **without a move**, and the
  turn passes to the next one in line on the same tick (no wait is spent
  on it). Each net's log entry is written at the move, as today (its tick
  is the move's tick).
- **The debug overlay's kill tool** (debug builds only) keeps its
  immediate move (`Offscreen.lose`), outside the queue; it counts as a
  move for the next turn's wait (proposed).
- **Derived, not saved (proposed; no save change).** The queue is never
  stored: at each turn it is rebuilt from the nets' own saved state.
  - *Who is due, and since when:* stalled, from the train record's last
    mark (its tick plus 60 s); lost, from the off-screen count
    (`offscreen.away`: its start plus 10 s plus 1 min); stuck, from the
    pair's saved count, which now **keeps counting while its mover
    waits** (it reached 4 checks that many checks ago; today it stops
    there because the move is immediate); out of bounds, from the centre.
  - *When the next turn is:* the last move's tick is the latest tick in
    the three move logs (`train.stalled`, the stuck log's entries with
    `moved`, `offscreen.lost`), all saved today; the wait after it is the
    first draw of the derived stream `loop_start:gap:<that tick>`. A last
    move later than the current tick (an old fixture) counts as none.
  - So a save and reload mid-queue moves the same slimes on the same
    ticks to the same spots as an unbroken run. If deriving proves
    awkward in the build, the fallback is one additive key (for example
    `loop_start: {"next": tick, "queue": [ids]}`, format 1): no special
    OK before the first store release (D149), but it is recorded.
- **Where it runs:** once per tick, after the three nets have looked
  (the off-screen lost count at the tick's start, then the Train's
  `follow()`, then the stuck check): last in `Simulation.step`, after
  `stuck_slimes.step`.
  Where the code lives is the implementer's (for example `LoopStart`
  gains the queue, or a small `src/sim/loop_start_queue.gd`).

**3. A random free landing spot (the user's: "randomized in
position").** Replaces "the first free spot of 8, one slime width apart"
(D124, D126).
- **Where (proposed):** a point on the loop's **first stretch**, at a
  distance along the loop drawn uniformly between 0 and **240 px** from
  the loop's start, the slime's centre lifted by its size above the loop
  there (as today). On the test level that is the ramp's top and the
  terrace, inside the start's split zone (x 0.03 to 0.54) and short of
  its end, so a fused slime is still split at once.
- **Free:** the spot is taken when it lies outside every split zone, or
  when the slime's ring there would overlap any other slime's (parked
  ones included; today's test, `LoopStart._free_spot`). Up to **8 draws**
  per turn; the first free one is used.
- **All 8 taken:** nobody moves this turn; the head of the queue tries
  again, with fresh draws, on the next tick that is a multiple of 30
  (0.5 s), and so on until a spot is free. Never onto another slime.
  (The other way, landing at the draw with the most room, is not taken:
  it is what keeps re-sticking.)
- **The draws** come from the derived stream `loop_start:spot:<tick of
  the try>` (`Rng.derive`): no draw from any existing stream, so a run
  where no slime is moved to the loop start keeps its hash, and the same
  seed gives the same spots.
- A move is otherwise as today: a parked slime is translated, a
  simulated one gets a new body there, unsupported and woken; state
  train, its hop no longer held back (`set_hop_held(false)`, as today),
  its train record afresh (its stall clock from zero). With the local
  wake (D156) the resting slimes it touched where it was wake too, and no
  others.

**4. Chunk 22h**, in D155's order (after 19w, before 22l, 22m, 5N, 22c,
22 repeated, the rest of 24 and the health review; build plan, "22h"). It
changes three safety nets' rules, so it **keeps both ATD steps**
(preflight: `rule_stalled_train_slime_moved_to_start`, whose "on screen
or off" changes; `rule_stuck_slimes_moved_to_start`;
`rule_left_alone_and_lost`, whose move now waits its turn;
`req_offscreen_simulation`; `req_slime_states`;
`req_persistence_and_saves`, to confirm no key changes). It must not run
while another chunk edits the Train, the stuck check or the off-screen
simulation (5N among them). **Done when:**
- `s3-basket-59of60`, seeds 1 and 2, 10,000 ticks (the run tool of chunk
  22m): **0 stall moves of a slime that was parked** at any tick of its
  last 60 s, **0 stuck moves of a slime within 600 ticks (10 s) of
  landing** from a move to the loop start; every two moves at least 30
  ticks apart; every landing free at its tick (no ring overlapping) and on
  the first 240 px of the loop. The stall and stuck counts before
  (measured on main first; the withdrawn build's were 87 and 305, 86 and
  172) and after are reported, with the bowl's parked line (now waiting,
  not drained: not a failure);
- `stress-moving`, the same checks on the moves; its counts reported,
  never targets (the user's note);
- unit tests: the parked pause and resume (a slime parked 100 s, then
  simulated, is moved only once its simulated time without progress
  reaches 60 s); one move per turn, the 30 to 120-tick wait from its
  derived stream; first due first moved, out of bounds first; a slime
  that recovers while queued leaves without a move and without spending
  a wait; lost and stuck slimes going through the queue; the stuck count
  going on while its mover waits; a spot drawn on the first 240 px, free,
  inside a split zone; all 8 taken, the retry on the next multiple of 30;
  the kill tool still immediate; a save and reload mid-queue giving the
  same hash as an unbroken run;
- every changed hash listed with its reason (expected: the fixtures with
  a move to the loop start or a parked stall; the others unchanged);
  [DoD 1]'s whole-level test unchanged (still failing on any logged
  case); the suite passes. The perf report gains a short 22h section.

**Numbers** (`tuning.md`): the turns' wait 30 to 120 ticks (the user's
0.5 to 2 s); the landing stretch 240 px, 8 draws, the retry every 30
ticks (proposed). **Terminology** (`concept.md`): **move to the loop
start** and **loop-start queue** added; **stalled** amended (the clock
paused while parked); **lost** says "moved", not "teleported".

**Unchanged:** the nets' own rules and numbers (60 s and 24 px, 2 s
stuck, 10 s plus 1 min lost).

*As built (chunk 22h, on main, 2026-10-03; reviewer OKAY):*
- **Step A (fccbb8e), 1:** while a followed train slime is parked, its
  `marked_at` moves on by one per tick (O113's default, every parked
  train slime); no save key. Fixture hashes change only through
  `marked_at`. Suite 1372/1372.
- **Step B (96725f1), 2 and 3:** `LoopStartQueue`
  (`src/sim/loop_start_queue.gd`, last in `Simulation.step`), rebuilt
  each tick from saved state, no new save key (the fallback key not
  needed). The wait 30 to 120 ticks from `loop_start:gap:<tick>`; out of
  bounds first, then first due, ties by id; a recovered slime leaves
  without a move or a wait; a slime due for two reasons waits once, at
  its earliest. `LoopStart.free_spot`: up to 8 draws over 0 to 240 px
  from `loop_start:spot:<tick>`, free = inside a split zone and no ring
  overlapping; all taken, the retry on the next multiple of 30, but an
  out-of-bounds slime with no saved due tick retries every tick.
- **Two exceptions to the text above, as built:**
  - *"Never onto another slime"* (3) covers **queue moves only**. The
    debug kill tool and losses found at load time stay immediate
    (`spot_now`) and may land on another slime.
  - *"A save and reload mid-queue moves the same slimes on the same
    ticks"* (2) has one exception: a save taken while an out-of-bounds
    slime waits; on load, D12's handling moves it at once.
- **Hashes:** in step B only `old-version`'s changed (its displaced
  sleeper lands on a random free spot).
- **Measured** (`tools/thru.gd`, 10,000 ticks): `s3-basket-59of60`
  (seed 1; step B's 11 on seeds 1 and 2): stall moves 87 on main before
  22h (so the bug was on main too) -> 0; stuck moves 234 -> 65 (step A)
  -> 11 (step B). `stress-dense`:
  stall 64 -> 0; its bowl's parked line now waits (`bowl_n` 49 -> 77,
  not a failure). Every landing free, within 240 px, moves at least 30
  ticks apart, 0 re-stuck within 600 ticks.
- **For rule 24 (D157) and O117:** the start basin crowds when slimes
  come home (about 36 near the start at tick 9500; queue waits up to 516
  ticks). This is the test level's first rule 24 evidence, and an input
  for the geyser.
- Suite 1383/1383. D150's proposed details and O113 still wait for the
  user's approval.

## D151 — Withdrawn: a density cap on the loop (2026-10-02)
**Withdrawn by D155 (2026-10-03).** It cut the loop into 300 px stretches
and capped the weight each could take from hops (chunk 22i, behind a
switch); it had no effect on the frame rate and jammed `stress-moving`.
Full text on branch `archive/fps-session-2026-10`, commit d7f7c5a.

## D152 — Withdrawn: waiting train slimes don't stall (2026-10-02)
**Withdrawn by D155 (2026-10-03).** It paused the stall clock while a
train slime waited under D147 or D151, answering O110; without those
rules it has nothing to act on. Full text on branch
`archive/fps-session-2026-10`, commit 7d4c702.

## D153 — A second stress fixture, `stress-dense`, and fps targets for both (2026-10-02)
*Re-entered by D155 (2026-10-03), edited:* the first text, on branch
`archive/fps-session-2026-10` (commit f26fc7d), stated the density
against a withdrawn decision's numbers and placed the fixture in chunk
22j, withdrawn with its build; here the density is in slimes per 100 px
of loop, as D154 amended it, and the fixture is chunk 22m's.
**Amended by D154 (the user's, 2026-10-02):** `stress-dense` is thinner
and laid along the loop line, not stacked (2); O114 answered in part.
*Built on main by chunk 22m (4aac65a); as-built note and readings under
D154.*
The user (2026-10-02), on `stress-moving` (200 train slimes, the level's
maximum, all in section 3's bowl, about 10 to 12 per 100 px of loop):
"we may have to tone down stress moving test (its got hundreds of slimes
in a setup we definitely don't want (see level design notes)). We do have
to do a stress test, agreed, but this one ... may be too much." Then:
"keep stress moving whose goal is not to crash and keep a minimum of
15fps", and a new fixture at "what the rules allow + 50% or something like
that": "stress dense: should have at minimum 30 fps." The coordinator's
first numbers, accepted that day: 6 per 100 px of loop, 50 % above a
reference density of 4 per 100 px proposed the same day (D151, since
withdrawn; D154 replaced the 6 by 3). "200 slimes is the maximum number
of slimes on a level."

1. **`stress-moving` stays unchanged** (its build, its hash): an **abuse
   test**, beyond any setup the level design wants. Its target: no crash,
   no freeze, and at least 15 fps. *Proposed reading of "no freeze":* over
   10,000 ticks the run ends without an error and the train hops in every
   600-tick window.
2. **A new fixture, `stress-dense`:** the dense case the rules allow, plus
   a margin. Its target: at least 30 fps. The user's: 200 size-1 base
   train slimes, centred on section 3's bowl, the camera on the bowl,
   gates 1 and 2 open as in `stress-moving`. Its density and placement
   are D154's (the first, 6 per 100 px stacked in columns from the ground
   up, was dropped there). *Proposed* (the rest):
   - **species:** each slime keeps its sleeper's species (the first slime
     and the 199 sleepers, as `stress-moving`); not at bedtime, no session;
     switch 3 and basket 3 as in `stress-moving` (untouched, basket 3
     empty);
   - **fill:** from the bowl outward, behind first; no slime past switch
     3 (if the span would reach it, the rest go behind); slimes in stable
     ID order (the first slime first) onto spots in fill order; each
     follows the loop from its nearest point. Deterministic, no draw;
   - **in the bowl:** the user: "currently i don't expect there to be 200
     slimes in the bowl"; whether the total should be lower is **O114**.
3. **Whose fps:** both targets are on the **reference phone** (S20 FE),
   the camera on the bowl. Until it is measured there, the phone emulation
   (`tools/perf_slow.sh --pin=main`) stands in, and the record says so.
   *Proposed:* the target is the mean over a 62 s run; the 5th percentile
   is reported beside it, not a gate (**O115**).
4. **Where they land:** the master spec's Definition of done 30 and §7
   gain the two targets; `stress-moving` stops being "a measurement, not a
   target" (D96's wording for it, refined). A reading on the withdrawn
   build (D155; phone emulation, its experimental switch off;
   `docs/perf/2026-10-02-d152.md` on branch `archive/fps-session-2026-10`):
   `stress-moving` 13.5 fps, `s3-basket-59of60` 25.4; to be measured
   again on main. Neither target is expected before 5N; they are checked
   at chunk 22's repeat.
5. **Chunk 22m, the `stress-dense` fixture** (S; it was 22j, D155):
   built with the existing fixture tooling (`tools/make_fixture.gd`, a
   recipe and a build function), no fixture-format change; its hash
   recorded with the others'; a scripted test. Order: D155's.
6. **Rule 23 and the `stress-*` exception:** `stress-dense` falls under
   level rule 23's "`stress-*` excepted" (no change to the rule).

Flagged for documentalist: DoD 30's new clauses (the performance
requirement's atom), at 22m's ATD peek. **Unchanged:** `stress-moving`,
chunk 22h (O113 open).

## D154 — `stress-dense` thinned: 3 per 100 px of loop, the bowl's bottom at 4, along the loop line; amends D153 (2026-10-02)
*Re-entered by D155 (2026-10-03), edited:* the first text, on branch
`archive/fps-session-2026-10` (commit bcaa8b7), stated the density
against a withdrawn decision's numbers; here it is in plain loop
distances, the measured number kept is the one that doesn't depend on
withdrawn code being switched on, and the known issue moved to O116.
The user (2026-10-02), after watching chunk 22j's first `stress-dense`
(ad8cd36: 6 per 100 px stacked in columns, 134 of 200 in the bowl; a
first phone-emulation reading of 13.9 fps): "the dense setting is quite
crowded. 130 slimes. too much, way too much. we were at cap + 50%, let's
downgrade to a shuffle of cap - 25% with one or two segments at 100%
and see where it goes? What i expected was a line of slime at the bottom
and some on the heights. what i saw was a soup of slimes, so i didn't
quite expect good result." (The user's "cap" is the reference density of
4 per 100 px of loop, D153's head: withdrawn as a rule, D155, kept here
as a number only.) Rebuilt then as a redo of 22j; built on main by chunk
22m.

1. **The density (the user's):** 3 slimes of weight per 100 px of loop
   (the reference's 4 minus 25 %). The loop is cut into **300 px
   stretches** of loop distance, counted from the loop's start with gates
   1 and 2 open (a slime's stretch is its distance along the loop divided
   by 300, rounded down): **9 per stretch**, and the **two stretches at
   the bottom of the bowl at 4 per 100 px, 12 each** (the user's "one or
   two segments at 100%"; two taken, proposed). Filled from the bowl
   outward, behind first, nothing past switch 3.
2. **Placement along the loop line, not stacked (the user's "a line of
   slime at the bottom and some on the heights"):** within a stretch the
   slimes are evenly spaced by loop distance and each is set on the loop
   as a train slime is spawned; D153's first columns stacked from the
   ground up are dropped. *Proposed reading of "shuffle":* the mix of the
   two densities, deterministic, no draw. *Noted:* a size-1 slime (42 px
   across) is wider than both spacings (about 33 px at 9 per stretch, 25
   px at 12), so neighbours overlap at load and push apart in the first
   ticks; the line may thicken there. The build reports how it settles.
3. **The total:** 200 size-1 train slimes, the level's maximum, unless the
   loop before switch 3 can't hold them at this density; then fewer, and
   the build reports the count. Built so on the withdrawn branch
   (bcaa8b7): 200, **70 in the bowl** (105 in section 3, 95 back through
   gate 2 in section 2), none past switch 3; chunk 22m records its own
   count. **O114** answered in part: fewer in the bowl; the total stays
   200 (proposed) unless it doesn't fit.
4. **Unchanged:** the target (at least 30 fps on the S20 FE, the phone
   emulation standing in, O115 open), the species, gates, switch 3,
   basket 3, the camera on the bowl, the fixture tooling, `stress-moving`.
5. **Measured on withdrawn code** (bcaa8b7; phone emulation, 62 s, its
   experimental switch off): 21.2 fps, tick 20.1 ms (target 30). That
   build carried rules D155 withdrew, so the number is a hint only;
   `stress-dense` is measured again on main once chunk 22m has rebuilt
   it.
6. **Known issue, found in 22j:** a fixture's train distances wrap on
   load. Now **O116** (it predates the session).

Specs: test level README's `stress-dense` row, the build plan's 22m, the
master spec's DoD 30 and §7 wording, `tuning.md`, O114, README.

*As built (chunk 22m part 1, on main, 4aac65a, 2026-10-03; covers D153
too):* the fixture is the branch's, copied verbatim and rebuilt byte for
byte by `tools/make_fixture.gd` (300 px stretches, 9 each, the bowl's
bottom two at 12, no withdrawn code): 200, 70 in the bowl, 105 in
section 3, 95 in section 2. The 17 other hashes unchanged. Phone
emulation, with the local wake (D156): `stress-dense` 22.9 fps (tick
16.3 ms, Physics 69), **its 30 fps target not met**; `stress-moving`
16.1 fps mean, 5th percentile 13.0, minimum 12.6: **its 15 fps abuse
target met on the mean, not at every moment**, so O115 now decides it.
Both run at the cap of 2 ticks per frame. O116 still open: 17 of
`stress-dense`'s slimes wrap at load, and the scenario test's advance
check passes only thanks to it. Part 2, the 10,000-tick run tool, is
being built. Suite 1342/1342.

## D155 — The fps session reverted to 0196c25: what was kept, what was dropped (2026-10-03)
The user's direction, 2026-10-03 (plan approved: "as you recommend",
after the review of the session, 2026-10-03). The user, verbatim: "prior
going native, we will revert to that commit, reapply the fps fixes worth
keeping, gather back other non fps fixes we should keep as well. update
the specs as appropriate and only then move on native." And: "we should
probably have marked this whole session as a throwaway".

**What is reverted.** The work after 0196c25 up to bcaa8b7: D145 to D154
and chunks 22d to 22j. Its frame-rate part grew a set of train rules (a
train slime waiting before a crowd, then a second round of it, a safety
catch, a front-first order, a cap on how many slimes a stretch of loop
may take) whose measurements didn't pay for them, while a few pieces
inside it did.

**1. The base: 0196c25.** The last commit before the session's first,
59db79b (D145). Its code is chunk 22b's (5d9533a): chunk 22's engineering
passes (the dip nudge rewrite, `stress-moving` 27.6 -> 12.0 ms a tick;
door bounding boxes and the pair loop, 18 to 25 % off; the off-screen
step; the centre cache; drawing culled to the near view; the cap of 2
ticks per frame, never measured on the phone), crowd detail (582c897),
22b's drawing pass (draw calls 482 -> 84, drawing 3.21 -> 1.43 ms) and
its cached labels; its specs are D138 to D144. The history is linear, so
going back to the S20 FE report (ec623c0) and reapplying those passes
gives this same tree.

**2. The method.** The whole session is kept verbatim on branch
`archive/fps-session-2026-10` (at bcaa8b7, pushed). On main, one restore
commit (3b7e7a1) sets the tree back to 0196c25's: no force push, no
history rewritten. Then three cherry-picks: 1a539db (chunk 22d's debug
counters, from 7437fd0), 931c53b (`domain_architecture_rationale` split
into 11 child atoms, D144, from df4c4eb) and 729fe87
(`rule_saves_never_wiped` 1.1, the user's wording, from de8ae14). The
withdrawn decisions keep their numbers as stubs pointing at the branch.

**3. Kept.**
- Base 0196c25's engineering passes (1).
- Chunk 22d's counters (Physics, On screen, In range, Parked; `resting`
  and `largest_cluster` on the PERF line), the atom split, and
  `rule_saves_never_wiped` 1.1 (2).
- D148, D149, D150, D153 and D154, re-entered by hand and edited: the
  save wipe and the save format before the first store release (chunk
  19w, not built), the loop-start queue (chunk 22h, not built), the
  `stress-dense` fixture and the two stress targets.
- **The local wake** (D156), re-implemented without the rest of the code
  it was built with, in chunk 22l, with the `hops` and `short_hops`
  counters (debug builds, the PERF line only).
- **The `stress-dense` fixture**, re-implemented in chunk 22m with a
  300 px constant for its stretches instead of the withdrawn code's, and
  the **10,000-tick run tool** (the branch's `thru.gd`) without the
  fields of withdrawn rules.
- As tools, already in the base or rebuilt with 22l and 22m: the perf
  log, `tools/android/perf.sh`, `perf_summary.py`, `tools/perf_slow.sh`,
  `compare_frames.py`, the bench's rest detection, `s3-basket-59of60`.
- Left for native (5N): crowd detail's `auto` mode stays chunk 22c,
  after 5N (D141); the bounding-box and centre-cache ideas are ported by
  5N.

**4. Dropped, and why** (the review's numbers; every number from the
phone emulation or the desktop):
- the waiting rule's first round (D145, chunk 22e): the tick got 5 %
  dearer;
- its second round (D147, chunk 22f): no fps gain, and resting by contact
  never happened (0 slimes);
- the front-first order (chunk 22g): worse;
- the density cap (D151, chunk 22i): no effect on the frame rate, and it
  jams `stress-moving`;
- D152 (waiting slimes don't stall): it only mattered with the waiting
  rules;
- 22f's fix of the dip-nudge pin at a wait's end: moot without them;
- the `counts_toward_fusion` cache: dropped by the review with the rest
  of that code;
- with them: the save key `train.hold`, the per-slime "may rest" input,
  the celebration waking waiting slimes, and v3's idle animations for
  waiting train slimes (D145 (8)).

**5. The local wake's numbers** (`s3-basket-59of60`, the withdrawn 22e
build, where no slime waited on seed 1, so the gain is the local wake's
alone): Physics 80 -> 51; phone emulation 22.6 -> 27.1 fps; tick 15.27 ->
13.22 ms; whole-pile wakes during basket 3's drain 6 -> 0. Chunk 22l
measures them again on main.

**6. No phone number.** No number since ec623c0 (the S20 FE session of
2026-09-30) comes from the real S20 FE: everything since is the phone
emulation (`tools/perf_slow.sh --pin=main`) or a desktop estimate.
Chunk 22's repeat on the real phone is still owed, and decides DoD 30.

**7. Questions.** O109 (what the waiting rule's time limit was for) and
O110 (whether waiting time counts toward the stall net) are withdrawn
with D147 and D152. O111 and O112 stay closed by D149. O113 (D150), O114
and O115 (D153, D154) stay open. O106 is answered by D156. New: **O116**,
the fixture-load wrap, found in 22j and older than the session.

**8. Terminology.** The session's terms are withdrawn and were never on
main's table: hold, jam, holder, hold guard, hop corridor, stack zone,
loop bucket, bucket cap, overfilled. Re-added: **save wipe**, **shipped**
(D148, D149), **move to the loop start**, **loop-start queue** (D150);
**stalled** amended by D150 only (no clock while parked); **lost** says
"moved". Added: **local wake** (D156).

**9. Order from here:** 19w, 22h, 22l (the local wake), 22m (the
`stress-dense` fixture and the 10,000-tick tool), 5N, 22c, 22 repeated on
the real S20 FE, the rest of chunk 24, the health review. 22l and 22m are
being built now, with the revert itself. Chunks 22e, 22f, 22g, 22i, 22j
and 22k are withdrawn (the branch keeps them); their ids aren't reused.

**10. Lesson.** The session should have been marked a throwaway from its
start. An experiment whose rules aren't settled goes on a branch, and
only what its measurements justify comes to main, through the spec.

**For documentalist:** after 22l, `req_offscreen_simulation` 1.2 gains
a local-wake paragraph (no "may rest"); `req_persistence_and_saves` stays
1.2 and `req_hopping_behavior` 1.1 (the withdrawn rules never reach
them); then `atd lint` and `atd check --full`.

**Where:** this log (stubs D145, D146, D147, D151, D152; D148, D149,
D150, D153, D154 re-entered; D143's 24.8 note), `open-questions.md`,
`concept.md`'s Persistence and Terminology, `slimes.md`,
`tech-direction.md`, `tuning.md`, the master spec (header, 5.2, 5.10, §7,
DoD 30), the build plan (Progress, the overview, 19w, 22h, 22l, 22m, the
withdrawn chunks, 24.3, 24.8, 5N), `levels/test/README.md`,
`versions/v4/README.md` and the index.

## D156 — The local wake: a disturbance wakes only the resting slimes it touches (2026-10-03)
The user's direction, 2026-10-03 (plan approved, D155). From D145 (3)
and chunk 22e's build (4750f12), without the rules D155 withdrew.
Answers **O106** (D138; D143's default, widened). Proposed where the
detail goes beyond what was built and measured.

**1. The rule.** A resting pile no longer wakes whole (D96). Three
disturbances wake **only the resting slimes they touch**; the rest of the
pile stays resting:
- **a release:** a basket letting a slime go (D91, D105) wakes the
  resting slimes the released slime touches, not the basket's whole pile;
- **a fast touch:** a slime touching a resting one faster than
  `WAKE_SPEED` (30 px/s: a hop, a landing, a neighbour moving) wakes the
  ones it touches;
- **a move to the loop start:** the moved slime is woken where it lands,
  as today, and the resting slimes that touched it where it was wake too,
  so none is left leaning on an empty spot.
It **never wakes a sleeper**: sleepers wake as they always have (D13, on
contact with an awake slime), and the local wake is about resting slimes
only. The other wakes stay as `tuning.md` lists them (a call wakes the
resting slimes within its radius, a tilt change wakes them all, bedtime,
sunrise and a basket catching).

**2. What doesn't come with it.** Which slimes may rest is unchanged:
pile slimes only (in a basket, or asleep at bedtime, D96); an awake train
or free slime never rests. No per-slime "may rest" input, no train
waiting rule, no `train.hold` save key. **The save format is unchanged.**

**3. If piles churn** (D96's reason for waking piles whole: half a pile
resting could jolt and wake again): the fallback is to wake the touched
slimes' touching neighbours too, one step, never the whole pile
(proposed). It wasn't needed on the withdrawn build: basket 3's drain
showed 0 whole-pile wakes against 6, at most 9 pile slimes woken in a
tick, Physics during the drain 84 -> 48.

**4. Counters, debug only** (from D145 (7)): the PERF line gains `hops`
(train hops taken in the period) and `short_hops` (train hops whose
landing advanced the slime along the loop by less than half its hop
reach, `Train.hop_reach`); `perf_summary.py` reports them. Read only: no
state change, same hashes.

**5. Hashes.** A fixture whose resting slimes are disturbed within the
hashed ticks may change; the chunk lists every changed hash and why. The
numbers to beat are D155 (5)'s.

**6. Chunk 22l** (build plan, "22l"). It changes how piles wake, so it
**keeps both ATD steps**: preflight from `req_offscreen_simulation` (its
resting text), `req_slime_states`, `req_waking_sleepers` and
`req_switch_basket_gate_set` (the release). **5N ports it:** the native
rest pass wakes locally, the GDScript behaviour its reference.

**7. Every wake is local** (2026-10-03, a follow-up: how chunk 22l builds
(1)). Every way a resting slime wakes goes through one wake, which wakes
that slime alone: never the rest of its pile, never a sleeper. So
(1)'s "the other wakes stay as `tuning.md` lists them" keeps their
triggers, each made local:
- a release, a touch faster than `WAKE_SPEED`, a move to the loop start
  (1), a fusion, a split, and a slime taken out of the level wake the
  resting slimes touching the slime concerned;
- a call wakes the resting slimes within its radius;
- a trapdoor, gate or lid opening or shutting wakes the resting slimes
  within 80 px of it (`DOOR_WAKE_REACH`);
- a state change (bedtime, sunrise, a basket catching or releasing)
  wakes the slime whose state changed;
- a tilt change wakes every resting slime, each by itself (in effect all
  of them, as before).
The rest of a pile wakes only if a woken slime then touches it faster
than `WAKE_SPEED`. No new value, no save change.

**Terminology** (`concept.md`): **local wake** added.

*As built (chunk 22l, on main, 2026-10-03):* 600de6b, the counters
(`hops=` and `short_hops=` on the PERF line, debug only, the same 17
hashes); 5f6a6b0, the wake: `SlimeBodies._wake_at` wakes only that slime,
every wake path goes through it, never a sleeper; no separate wake added
in `LoopStart` (the state change already wakes the moved slime). The
one-step-neighbour fallback (3) was not needed and is not built. Basket
3's drain (`s3-basket-59of60`, seed 1, 2400 ticks, headless): whole-pile
wakes 6 -> 0, woken per tick median 3, max 9; Physics 75.5 -> 51.8;
largest cluster 47.8 -> 26.0. Phone emulation (`tools/perf_slow.sh
--pin=main --seconds=62`, pinned lines): 25.4 -> 35.0 fps, tick 15.0 ->
10.5 ms, Physics 74 -> 43, cluster 47 -> 20. Only `s3-basket-59of60`'s
hash changed. Suite 1339/1339.

## D157 — Level rule 24: where slimes arrive fast, they get away faster than they arrive; the geyser, an idea (2026-10-03)
The user's words (2026-10-03), on the test level: "for the test level
design, the way back is fully automated, which is nice with slimes
gliding back. maybe ensure that they are 'geysered' high with a wide
dispersion, ensuring that they don't get too stalled at start point."
Then: "the geyser option is not urgent, but would probably help
preventing cluster at start. Slimes comes in fast, if they can't get away
from start point quickly enough it will build a self feeding cluster (we
need to add this as a level building rule)". The rule is the user's; its
wording, reading and check are proposed. The geyser is an idea, not
scheduled (O117).

**1. Level rule 24 (the user's; wording proposed).** Where slimes arrive
fast (the end of a return route at the loop's start, a slide's end, a
basket's outlet), the place they land lets them move away faster than
they arrive: enough room and a clear way onward. Otherwise each arrival
lands on the ones before it, and the pile feeds itself.

**2. How it sits with the other rules.**
- **Rule 23** (D143): a special case of it. Rule 23 keeps apart the
  spots the layout makes; rule 24 is a gathering spot the flow itself
  makes, wherever arrivals outpace departures.
- **Rule 22** (D117, D123) says where a return route comes home (behind
  the loop's start, the loop's way); rule 24 says that place must also
  clear fast enough.
- **Rule 4** (proposed reading): where a split zone meets the arrivals,
  count them in base slimes; a size 3 coming home lands as three.
- **D150, the loop-start queue:** moves to the loop start (lost, stuck,
  stalled) come one at a time, 0.5 to 2 s apart, onto a random free spot
  on the loop's first 240 px. That paces the safety nets only. A level's
  own arrivals (a return route, a slide, an outlet) come at the flow's
  pace, and nothing paces them; rule 24 is about those.

**3. A consequence to keep in view (proposed reading; no number).** "A
clear way onward" counts by its pace, not only its room. At the loop's
start slimes leave by joining the train, whose slimes hop every 1.5 to
3 s (`slimes.md`). A return route that brings them faster than the
train carries them off the first stretch fills the start however wide
it is. So a designer reads the rule as a rate (arrivals against
departures), not as a size alone.

**4. How it is checked (proposed).**
- **By eye, in test mode:** watch each arrival spot while slimes come
  home: they spread and leave, and no pile there grows while arrivals
  go on. An item in each level's rules checklist.
- **Largest awake cluster at the arrival:** the largest awake cluster
  with a slime within 240 px of where the slimes land (at the loop's
  start, D150's stretch), held to rule 23's limit (O107) over the
  level's own scripted runs, the `stress-*` fixtures excepted.
- **Stuck moves at the arrival,** over a 10,000-tick `tools/thru.gd`
  run: none stuck again within 600 ticks (10 s) of landing there (chunk
  22h's measure for moves to the loop start). `thru.gd`'s `stuck` count
  is level-wide today; telling the arrival spot apart is a small tool
  addition, not scheduled.
- **The level-rules checker has no automatic check in v1.** The rule
  hangs on arrival and departure rates, which only a run shows; the
  checker reads the scene. The checker and the level review list rule
  24 as a by-eye item.

**5. The geyser: an idea, not urgent, not scheduled (O117, parked; a v2
candidate).** At a return route's end, the arriving slimes are launched
high with a wide dispersion, so they come down spread over the start
area instead of on one point. It would be tried first as a **throwaway
experiment on a branch** (the user's working rule; D155's lesson),
measured with section 4's checks against the same runs without it,
before any spec commitment. No term in `concept.md` until it is
proposed.

**6. The test level.** Whether its loop's start meets rule 24 is
**unknown until chunk 22h's measurements**. After 22h step A (fccbb8e,
the stall clock paused while parked), `s3-basket-59of60`, seed 1,
10,000 ticks: 65 stuck moves (234 before), mostly a re-stuck loop at
the loop's start; step B (the loop-start queue and random free
landings) is being built. Whether the slides' arrivals into the pocket
pile up is not measured apart. The test level's checklist gains the
by-eye item; no level edit proposed before 22h's numbers.

**Documents:** `level-design.md` rule 24; `levels/test/README.md`
checklist (rule 24's row, and rule 23's row, which was missing: it
restates D143 and O107 (c), no new content); `open-questions.md` O117,
O107 (d); `versions/v2/README.md` lists the idea. **Flagged:** for
documentalist, a rule 24 atom beside rule 23's under
`req_level_design_rules`; outside `specs/`, the `level-review` skill and
`docs/level-design/` list rules only up to 22 (23 and 24 missing).

## D158 — Chunk 5N goes ahead now, after 22h, for headroom (2026-10-03)
After the real S20 FE session (`docs/perf/2026-10-03-s20fe-session.md`,
build fdae364): first 60 s `s3-basket-59of60` 55.8 fps, `stress-dense`
41.3 (p5 28.7), `stress-moving` 22.6 (p5 17.3), thermal 0; DoD 30's
targets all pass. But after about 151 s of `s3-basket-59of60` an awake
section 1 cluster of 80 to 100 drops it to 18–23 fps, and a tick costs
about 11 ms even with 20 to 30 physics slimes. Asked "native now or
later" (the user's earlier rule: if the fix works, a clean-up pass and
native set aside for now), the user: **"go native."**

- **When:** chunk 5N runs next, after chunk 22h (being finished). Order
  from here: 22h, 5N, 22c, 22 repeated on the real S20 FE, the rest of
  24, the health review.
- **Why:** headroom, not a missed target: the user's standing wish for
  maximum performance before animations and music; the warm section 1
  crowd window; the ~11 ms per-tick floor; the floor phone still
  unmeasured.
- **Scope unchanged** (5N as written, D140, D142): the solver internals
  move to C++; behaviour code (the train, the loop, hops, phases, calls,
  fusion timing) stays in GDScript. The 11 ms floor may lie partly in
  behaviour code; 5N's preflight notes it, and porting behaviour code
  would need its own decision, outside 5N.

**Documents:** `versions/v1/build-plan.md` (order, 5N's heading and
intro; 19w, 22h step A and 22m part 2 marked done); `README.md`.

## D159 — v1's two blockers: O91 fixed; the geyser kept for v1, level rule 24 strengthened, the dip nudge's jam; chunk 24g (2026-10-06)
Settles O91 and O117 (out of v2, into v1); opens O118 and O119.

The user's words (2026-10-06): two "mandatory fixes prior version lock":
"slimes of different species gobbling each other", and "the end of the
return route's geyser": "we must add the geyser thing when reached to
prevent clustering at start point (it's happening right now)". After the
experiment (§2), on its recommendation: "I'll follow your
recommendation, we must take care of this in the level design rules as
well (preventing scenario were cluster forms at loop start)."
**Decided by the user:** the geyser goes into v1 in its "high and wide"
form (variant C) with its landing limits fixed; the train's jam at the
dips is fixed with it, so the train takes slimes off the start faster;
then measure again; if the start still crowds, pace the return route's
end next; rule 24 covers the case. **Everything else below is proposed.**

**1. O91 resolved, as built (3a27d86, merged 0061ccf; hashes d48c519).**
The cause: where two rings sat deeper than a radius in each other, a
point of ring a past b's centre was pushed straight out from b's centre,
which pulled a further into b until the centres met. Such a point is now
pushed along its offset mirrored back to a's side; nothing changes while
the centres are at least a's radius apart (GDScript and native alike,
bit for bit). The deep overlaps came from parked train slimes unparked
at almost the same progress (the bowl, the slide's end) and from the
slide carrying slimes into its pile. The gobble probe, `s3-basket-59of60`
seed 1, 18,000 ticks: overlaps lasting 2 s or more 139 -> 3, stuck moves
11 -> 0. Tests: `test_slime_deep_overlap`, a deep pair in
`test_native_contacts`; only `stress-moving`'s hashes changed. **D100's
stuck net stays,** as a backstop. Master spec Known gap 6 is closed.
O91's chunk 22 finding (bedtime-asleep slimes parked on one spot, D138)
is carried into O105's note: unchecked since the fix.

**2. The experiment (exp/geyser, throwaway, D155's rule).**
`s3-basket-59of60`, camera held on the start from tick 9000, 14,000
ticks, seeds 1/2, per 600 ticks from 9000:

| | off | C (high and wide) |
|---|---|---|
| arrivals | 16.1 / 14.8 | 17.8 / 16.7 |
| largest awake cluster | 123 / 128 | 107 / 120 |
| slimes within 240 px of the start (mean) | 24.8 / 25.5 | 13.4 / 15.5 |
| departures past 240 px | 5.9 / 6.4 | 11.8 / 8.6 |
| departures past 750 px | 2.0 / 2.4 | 3.2 / 3.0 |
| pocket behind the start (mean) | 30.0 / 29.1 | 11.4 / 13.5 |
| ticks to clear 240 px (median) | 888 / 1341 | 38 / 41 |
| landed off the loop | 18 / 25 | 81 / 68 |

Tick cost unchanged. **Verdict:** the geyser clears the start point, but
the queue only moves onto the terrace: downstream the train takes about
3 slimes per 10 s against about 17 arriving (D157 §3's rate limit). The
`stress-dense` census (cb7e6f5; phone, 0f3d027) shows why the train is
slow: it jams behind slimes held by the dip nudge (§5). C's problems:
landings on top of the stacked queue, some slimes on `FirstLedge` (the
ledge rule 22 (b) guards), base slimes past the start's split zone
(which ends near 410 px).

**3. The geyser, in v1 (the user's; details proposed).**
- **Where:** the loop's start, where a return route brings slimes home.
  In v1 it is part of the loop's start in every level, not an object a
  level places or tunes (proposed; a placeable object stays a later
  option).
- **When:** a train slime coming home by a return route reaches the
  loop's start. A move to the loop start (D150) is never launched: it
  already lands on a free spot (proposed; the experiment counted any
  wrap of the loop, a knocked-off slime put back near the start
  included).
- **What (variant C):** the arriving slime is lifted straight up above
  the slimes piled over it, then launched high, and comes down on the
  emptiest of a few seeded spots along the loop's first stretch. A spot
  whose flight would hit the terrain isn't used; with no usable spot the
  slime isn't launched and carries on as today.
- **Landing limits (proposed, fixing §2's problems):** (a) only on the
  loop's own route, on a free spot (no ring there, slimes in flight
  counted where they come down), so never on top of the waiting queue;
  (b) never onto a ledge rule 22 (b) guards, nor anywhere else off the
  loop (the experiment's `FirstLedge` cases came from the stacked queue
  bridging up to the ledge, not from flights: (a) and §5 should remove
  them, and the build checks it); (c) never at or past a gate; (d) a
  fused slime lands only inside a split zone; a base slime may land
  past the start's split zone, since it has nothing to split (as on the
  branch; every landing inside the zone would halve the spread on the
  test level).
- **Off screen:** a parked arrival isn't flown: it is placed directly on
  a free drawn spot; with none free it stays in the parked single file
  (as on the branch).
- **Deterministic:** its own derived stream, `geyser:<tick>:<id>`; the
  same hash on both ticks; no save change (a slime in flight is ordinary
  physics).
- **Numbers, tuned in the build** (rows in `tuning.md`): lift at most
  240 px, 6 px clear of the pile; apex about 260 px above the higher end,
  ±25 % seeded; 10 draws on 150 to 700 px along the loop (the branch's
  variant C draws 10, not 6).
- **Seen, not changed:** the idle camera may follow a launched slime
  away from the start (the experiment saw it). A by-eye item.

**4. Level rule 24 strengthened (the user's ask; wording and check
proposed).** A level must not let arrivals at the loop's start outpace
what the train takes off it. The geyser gives the arrivals room; only
the train's pace takes them away, so the rule is a rate.
- **Check:** over the level's own scripted runs, from the first arrival
  on: the mean arrivals at the loop's start per 600 ticks stay at or
  below the mean departures past the end of the first stretch (past the
  geyser's farthest landing: 750 px on the test level) per 600 ticks;
  and the largest awake cluster with a slime within 240 px of the start
  stays within rule 23's limit (O107). Measured by the experiment's
  probe, kept as a level run tool in chunk 24g. The window and the
  threshold are O119. The by-eye item stays; still no check in the
  scene-only level-rules checker. The `stress-*` fixtures are excepted.
- **When it fails, the designer:** gives the first stretch more room (a
  longer or wider first stretch), makes the train faster off it (a
  gentler first slope), or, once it exists, paces the return route's end
  (O118).
- **The test level fails it today** (about 15 to 18 arrivals per 600
  ticks after basket 3 fires against 2 to 3 departures past 750 px, with
  the geyser or without). Chunk 24g measures it again after the geyser
  and §5; if it still fails, the next step is O118, the user's call.

**5. The dip nudge must not jam the train (proposed; ships with the
geyser).** The user's report (2026-10-05, the phone, `stress-dense`):
"movement wise, it fails grossly": the front slime is held, the slimes
behind keep hopping into it and stay in place (micro hops; cold minute,
93 % short hops). The census (cb7e6f5 on the desktop; 0f3d027 on the
phone): 19 to 32 train slimes held by the dip nudge's gathering, 56 to
68 of 60 to 68 last hops short, chains advancing 0 to 17 px. The cause,
as the code reads (`src/sim/fusion.gd`, `_gathering`): a slime on a dip
floor waits for a partner within 300 px behind; for one with other
slimes between them, D119's 5 s limit counts from the train's stall
mark, which moves on whenever the slime is pushed forward, so the
slimes hopping into it from behind keep restarting its wait.
- **Rule (proposed; the exact form is the build's, measured on
  `stress-dense` and `s3-basket-59of60`):** a gathering slime's wait
  counts its own time on the dip floor and isn't restarted by a push;
  and it is let go when the slimes pressing it from behind aren't
  partners.
- **Must still hold:** fusion still happens in dips (rule 5); [DoD 1];
  the `bump` fixture's two bumps (D119 kept the 5 s wait for the 3 + 1
  bump, where a size 1 waits with a size 3 behind it: letting go on a
  non-partner's push may lose that bump; if both can't hold, it is the
  user's call, D119's alternative).

**6. Next, only if the start still crowds after 24g: pace the return
route's end (O118, not scheduled).** Like D150: arrivals held at the
return route's end and let onto the loop's start at the pace the train
takes them, the geyser spreading them.

**7. Chunk 24g** (build plan): the geyser, §5, rule 24's run check and
the measures against §2's numbers. It runs before v1 closes; proposed:
next after 5N, before 22c and chunk 22's repeat (which then measures the
game with it).

**Documents:** `level-design.md` rule 24; `concept.md` Terminology
(geyser, proposed); `slimes.md` (stuck, fusion); `tuning.md` (the
geyser's rows, the dip wait's row); `open-questions.md` (O91 and O117
out, O118 and O119 in); `versions/v1/master-spec.md` (header, 5.2,
Known gap 6); `versions/v1/build-plan.md` (chunk 24g, the order);
`versions/v2/README.md` (the geyser moves to v1); `levels/test/README.md`
(rule 24's row); `README.md`. **Flagged:** for documentalist,
`rule_dip_may_nudge_fusion` (§5), `rule_stuck_slimes_moved_to_start`
(the net now a backstop), rule 24's atom under `req_level_design_rules`,
and an atom for the geyser; outside `specs/`, the `level-review` skill
and `docs/level-design/` still list rules only up to 22.

## D160 — The geyser, a level object; the start's crowding to a test-level review, not a v1 blocker; the train's jam is the climb (2026-10-07)
Restates D159 (3), (5), (6) and (7); parks O118; O119 stays open for the review; opens O120 to O124.

The user's words (2026-10-07): "don't stress over the crowding of the
loop's start too much. we need to review the test level design better
to reduce the factors affecting this. Ensure the geyser option stays
(but not specifically as the end of the route feature, but as a
standalone "object/effect" that happen to be located there. (so that
the object can be reused elswhere)." Then: "but that doesn't prevent
validating this version." **Decided by the user:** the geyser stays, as
a standalone level object reusable on any level, which the test level
happens to place at its return routes' end; the crowding of the loop's
start is not a v1 blocker and goes to a review of the test level's
design. **Everything else below is proposed**; V1s (§4) is the user's
call, asked 2026-10-07 (O121).

**1. The geyser, a level object (restates D159 (3)).**
- **A component a level places** (D6: reusable, configured in the
  editor, no per-level script), like a split zone or a framing zone. Each
  placement sets: its **catch** (a box: a train slime travelling the
  loop's way whose centre enters it is launched); its **landing span**
  (from and to, in px along the loop, ahead of the catch); its **apex**
  and jitter, its **draws** per arrival and its **lift** cap (defaults:
  D159's numbers, `tuning.md`); and one switch, **fused slimes land only
  inside a split zone** (on for a placement at the loop's start, so
  fused arrivals still split there; off elsewhere). Details: O120.
- **Always applied, whatever the placement** (D159's limits): a spot on
  the loop's own route, free (never on the waiting queue); never onto or
  under a ledge rule 22 (b) guards; never at or past a gate; the flight
  clears the terrain. No usable spot: the plain arrival (no lift, no
  launch). Off screen, a parked slime reaching the catch is placed on a
  free spot of the span directly, or stays in the parked single file.
- **Never launched:** a slime put inside the catch rather than
  travelling into it (a move to the loop start, D150, already lands on a
  free spot; a load).
- **No tap** (a tap on it is a call, D109); **no state of its own,
  nothing saved** (a slime in flight is ordinary physics); its own
  derived stream `geyser:<tick>:<id>` (a slime is in one catch at a
  time); the same hash on both ticks. Drawn as placeholder art, like a
  split zone; its look is v3's graphics.
- **The test level places one:** its catch over the return routes' end
  (the pocket behind the loop's start, D116), its span 150 to 700 px,
  fused slimes only into the split zone. That placement is D159's
  geyser: "an arrival by a return route" is what this catch sees.
- v1's objects gain the geyser (it is no longer "part of the loop's
  start", nor a v2 option, D159 (3)).

**2. Placing a geyser: level rule 25 (proposed).** A geyser lands slimes
where they can carry on: its span lies on the loop, wholly ahead of its
catch, with no gate in it, and as little of it as possible under a
ledge rule 22 (b) guards; at the loop's start, its catch takes the
arrivals before they reach the pile (rule 24). *Check (proposed,
`tools/check_level.gd`, chunk 24g):* fails a span off the loop, behind or
over its catch, or holding a gate; warns when the fused switch is on
with no split zone over any of the span; and reports the share of the
span under a guarded ledge (below). *By eye:* the flights clear the
terrain.
**Inconsistency, not resolved:** the test level's span (150 to 700 px)
crosses `FirstLedge` (about 245 to 390 px; in the experiment about 460
of each run's ~1,500 refused draws were that ledge), so it would get the
warning, and TL1's guard test wants no checker warning on the test level
(`test_the_rules_checker_gives_the_test_level_no_warning`). Proposed for
24g: the ledge share is a note in the checker's report, not a warning,
until the review settles it; shorten or split the span, or accept it:
O124, for the review (§3).

**3. The start's crowding: not a v1 blocker (the user's); a review of
the test level's design.** Rule 24 stays as written (D159 (4)); the test
level failing its check no longer blocks v1's validation or lock, and
D159 (6)'s "next, pace the return route's end" is withdrawn as v1's next
step. The review weighs the factors that crowd the start: the arrival
rate against the train's take-up (rule 24's check, by 24g's run tool);
the first stretch's room (length, width); its slopes (the start basin's
exit climb, rising 0.72 to 0.75 over x 660 to 1,200, where the queue
goes single file); the terrace and the pocket; the geyser's placement
and span (O124). Its fixes are level edits first. **Where it goes is the
user's (O123);** proposed: chunk **TL2** in v1's remaining list after
24g, not a lock gate (v1 may lock with it undone; it then carries into
v2's level work). **O118 parked** (not needed for v1; pacing stays an
option the review may pick). **O119 stays open**, settled in the review.

**4. The train's jam is the climb, not the dip nudge (corrects D159
(5)).** Measured on exp/dip-jam (1af507a, its `HANDOFF.md`; throwaway,
D155's rule): taking the nudge out of the jam (V1s: let go when the
slime behind is another species) cuts the gathering holds 92 % with the
flow unchanged (micro hops still 93 %; s3's departures past 750 px
unchanged). What jams the train is the climb: on a rise it goes single
file at about 10 px/s, each slime sliding back 5 to 17 px/s between
hops, every hop aimed 150 px on and landing on the slime ahead.
- **The fix (proposed, the measures' recommendation): G and R.** **G,
  the hold on a climb:** a grounded train slime between hops on the
  outgoing route, on a rise over 0.1, keeps its place (no slide back:
  alone on a rise 12.9 -> 1.6 px/s); the return routes' carry is
  untouched. **R, the relay:** when a train slime takes off, the
  standing train slime right behind it (within its reach of touching
  it, on the outgoing route) has its hop timer cut to 0.15 s, so a wave
  runs down the queue. No new state. `s3-basket-59of60` held on the
  start, per 600 ticks from tick 9000, seeds 1 / 2: departures past
  750 px 2.5 / 3.1 -> 7.8 / 7.6; largest cluster within 240 px 118 /
  117 -> 98 / 95 (rule 23's limit 20); with the geyser too, 9.0 / 8.6
  and 90 / 85. `stress-dense` speed 16.3 -> 23.5 px/s. `test_train`,
  `test_fusion` and `test_slime_hops` pass; equal hashes on both ticks.
- **The dip nudge unchanged.** D159 (5)'s two changes are withdrawn: the
  wait counted on its own time (V2) left the flow unchanged and needs a
  saved key; the let-go (V1s) fully unjams `stress-dense` with G and R
  (speed 35 px/s, slow share 0.83 -> 0.02) but changes the A, B, A
  touching fusion test by design: **left out by default, the user's
  call (O121).** Hopping over the queue (H) was nearly inert: dropped.
- **To watch:** fusions per minute on `s3-basket-59of60` fall 17 -> 7.7
  with G and R (5.1 with the geyser), while `stress-dense` keeps 20 to
  32; not explained yet (O122). The relay doubles the landings.

**5. Chunk 24g restated** (build plan): the geyser object (from
exp/geyser, generalised to a placement), G and R (from exp/dip-jam),
rule 25's checks, and rule 24's run check kept as a level run tool for
the review. The start's measures are recorded against D159's baseline,
not a pass or fail on rules 23 and 24. v1's blockers: the gobble
(done, 0061ccf) and the geyser object (24g).

**Documents:** `concept.md` Terminology (geyser restated; hold on a
climb, relay); `interactive-objects.md` (the geyser, v1's objects);
`level-design.md` (rule 24's text, rule 25); `slimes.md` (the geyser,
the climb, the dip nudge); `tuning.md` (the geyser's per-placement
defaults, G and R, the dip wait row); `open-questions.md` (O118 parked,
O119 kept, O120 to O124 in); `versions/v1/master-spec.md` (header, 3,
5.2, 5.4); `versions/v1/build-plan.md` (24g, TL2, the order);
`versions/v1/README.md`; `versions/v2/README.md`; `levels/test/README.md`
(rule 24's row, rule 25's row); `README.md`. **Flagged:** for
documentalist, `rule_geyser_spreads_arrivals_at_loop_start` (DRAFT, not
built) now describes an object a level places, not the loop's start
(its rename is documentalist's); `rule_dip_may_nudge_fusion` 1.1's
pending no-jam change is withdrawn (unchanged unless O121);
`req_hopping_behavior` gains G and R; `rule_arrivals_clear_faster_than_they_arrive`
(the test level's fail no longer a v1 blocker); rule 25 under
`req_level_design_rules`; `req_interactive_objects_general` (v1's
objects gain the geyser). Outside `specs/`: the `level-content` skill (a
new object kind) and the `level-review` skill and `docs/level-design/`
(rules up to 25).

## D161 — The geyser and the test level's start review come after v1; the climb fix stays in v1 (proposed); v1's fps gate leaves the loop start's crowding aside (2026-10-07)
Answers O123; withdraws D159's "the geyser is a v1 blocker" (D159 (3), kept by D160 (5)); carries O118, O119, O120 and O124 after v1; opens O125.

The user's words (2026-10-07), answering O123 and D160's questions:
"nah test level review comes after v1 is finished. same with geyser etc.
right now, fps gating is mostly ok if we ignore loop's start issue. so v1
should be okay"

**1. After v1 (decided by the user).** The test level's start review
(chunk TL2, D160 (3)) and the geyser object (D160 (1) and (2): the
object, level rule 25 and its check) come **after v1 is finished**: the
first thing after v1, with v2's level work (`versions/v2/README.md`
lists them as carried in). No version number beyond the user's "after
v1". D159's "the geyser, mandatory before the version lock" is withdrawn
by the user's "same with geyser"; the other D159 blocker, the gobble fix
(O91, 0061ccf), stays done. The geyser's spec stays as D160 wrote it,
only scheduled after v1; its experiment stays on branch `exp/geyser`
(8b116e4), throwaway as before. v1's objects lose the geyser again
(`interactive-objects.md`, master spec 3 and 5.4): **the test level
places no geyser in v1**. Rule 24 stays a level rule as written (D157,
D159 (4)); the test level failing its check is a known gap of the test
level, settled in TL2 (D160 (3)). **O123 answered:** after v1. **O118,
O119, O120 and O124 go with them** (parked, after v1). *Reading of
"etc." (proposed):* the geyser and everything serving the start's
crowding (rule 25, its check, pacing the return route's end, rule 24's
rate window); the climb fix below is read as outside it (O125).

**2. The climb fix stays in v1 (proposed; the user may drop it, O125).**
The hold on a climb and the relay (G and R, D160 (4)) answer the user's
2026-10-05 `stress-dense` report ("movement wise, it fails grossly"),
which doesn't depend on the loop's start. **Chunk 24g keeps its id**
(the branch `feat/24g` already carries it) and becomes **"the train's
climb"**: G and R, the measures recorded against D159's baseline with
the experiment's probe kept as a level run tool (without the geyser's
fields; TL2 reuses it), and the fusion drop explained (O122, stays with
24g). The geyser's parts (24g's former items 1 and 3, and the geyser's
own checks in its done-when) move to the build plan's "After v1"
section, unchanged. **O121 (V1s)** stays the user's, default out.

**3. The fps gate (the user's reading; wording proposed).** "fps gating
is mostly ok if we ignore loop's start issue": v1's frame-rate targets
(DoD 30, chunk 22's repeat) are judged **with the loop start's crowding
set aside**: the windows where slimes coming home crowd the loop's start
(in `s3-basket-59of60`, its section 1 window once the train comes home;
on 5N's phone session, 2026-10-06, 28.5 fps, warm 24.1) are measured and
recorded, not gated. Every other target and number in DoD 30 is
unchanged; no new number. The start's crowding and its frame rate go to
TL2 with the geyser.

**4. The build order after 5N (proposed):** chunk 24g (the train's
climb), 22c, chunk 22 repeated on the real S20 FE, the rest of chunk 24,
the health review. **After v1:** the geyser object, then TL2 (which
weighs the geyser's placement).

**Documents:** `open-questions.md` (O123 out; O119, O120, O124 parked
beside O118; O125 in); `interactive-objects.md` (v1's objects; the
geyser after v1); `level-design.md` (rule 25 after v1; rule 24's run
tool, its "when it fails"); `concept.md` Terminology (geyser after v1;
hold and relay, chunk 24g); `slimes.md` (the geyser after v1);
`tuning.md` (the geyser's section after v1; G and R rows);
`versions/v1/master-spec.md` (header, 3, 4, 5.2, 5.4, DoD 30, Known gap 9);
`versions/v1/build-plan.md` (24g, TL2, the geyser after v1, the order,
chunk 22's repeat); `versions/v1/README.md`; `versions/v2/README.md`;
`levels/test/README.md` (rules 24 and 25's rows); `README.md`.
**Flagged:** for documentalist, `rule_geyser_spreads_arrivals_at_loop_start`
(DRAFT, not built: after v1, not v1), `req_interactive_objects_general`
(v1's objects lose the geyser again), rule 25 under
`req_level_design_rules` (after v1), `req_platform_and_performance_targets`
(DoD 30's start crowding set aside, proposed). Outside `specs/`: the
`level-content` skill, the `level-review` skill and `docs/level-design/`
need no geyser or rule 25 for v1.

## D162 — Chunk 22c as built: the load meter's hold after a bounce; exact repeat outside `auto`; O122 answered (2026-10-07)
Proposed; the user reviews. Refines D141 (2) and (3); answers O122 (D160
(4)). Sources: `docs/dev/README.md`, "Chunk 22c: crowd detail only under
load" (merge 57d38e7) and "Chunk 24g", "Closure" (branch
`chore/24g-close`, 7595762, not yet on main); `src/platform/load_meter.gd`.

**1. Chunk 22c as built** (57d38e7; suite 1552/1552 native, 126/126 the
GDScript pass; all 36 fixture hashes unchanged). The load meter, the
detail ceiling and the modes as D141 wrote them, plus a hold.
- **The thrash.** On the slowed CPU capped at 60 fps (`tools/perf_slow.sh
  --pin=main --max-fps=60`, `s3-basket-59of60`, `auto`, 2 min) the
  ceiling stepped 32 times: up to 3, down to 0 over about 9 s, up again,
  over and over. The busy share stayed 0.22 to 0.72, never past D141's
  pressed share (85 %), so missed beats alone decided each window, and
  D141's "a step is well under the band" didn't apply.
- **The hold after a bounce** (proposed by the orchestrator, refined in
  the build). A **bounce** is a pressed window within 10 judged windows
  after a step down: the lower ceiling couldn't be kept. The next step
  down then waits for 60 calm windows in a row (about a minute) instead
  of 3. A step down that lasts 10 judged windows without a pressed one
  sets the wait back to 3; so does a load (the meter's reset). It isn't
  saved, like the ceiling.
- **Why not the doubling first proposed** (3, 6, 12, a cap of 24, back
  to 3 after 30 calm windows at a level): on a device calm at a ceiling
  and pressed one step below, each bounce costs two steps, and the
  doubling still gives about 12 steps after the climb in 2 min (10 with
  no cap), not "a few"; with its cap below 30, its reset could fire only
  at ceiling 0. One long hold gives a few with fewer values.
- **Measured** (desktop, 2 min, `s3-basket-59of60`, `auto`): at the
  normal clock, ceiling 0 throughout. Slowed and capped at 60 fps: 5
  steps (was 32). Slowed, uncapped: 3 and 7 steps over two runs (was 16).
  The climb to the crowd's level takes about 3–4 s. After the climb, 0 to
  4 steps per 2 min; "a few" read as 5 or fewer (the build's reading).
  The phone (vsync on) may differ: chunk 22's repeat measures it.
- **The risk:** after a bounce, crowd detail stays coarser for up to about
  a minute after the device has recovered.
- **The build's choices** (proposed):
  - a dropped window changes nothing (no step, no count, not one of the 10
    windows after a step down);
  - a missed beat is a frame that ran 2 ticks or more;
  - `auto` applies to any game outside test mode with no flag, a game
    added by a test in normal play included;
  - the `PERF_CEILING` line (one per step) is printed in `auto` only.
- Values in `tuning.md` (`BOUNCE_WINDOWS` 10, `BACKOFF_WINDOWS` 60).

**2. Exact repeat in test mode (proposed, for the user).**
- Seeded runs repeat exactly (same build, same seed, same hash) in
  `always`, the default of test mode, the fixtures, test-mode scripts,
  the level bench and the tests, and in `off`.
- A run passed `--crowd-detail=auto` (`perf.sh`'s phone runs) follows the
  device's measured load and doesn't repeat. Its hash isn't a fixture
  hash. A save written in `auto` still loads in every mode.
- Stated where the master spec (6, Testability), `tech-direction.md`
  (Testability) and the test level (Repeatability) promised exact repeat.

**3. O122 answered (as measured in 24g's closure).**
- Fusions per minute on `s3-basket-59of60` fell from about 17 to about
  7.5 (seeds 1 / 2: 17.0 / 16.2 -> 8.0 / 6.9). Slimes don't meet less
  (as often or more); their contacts break sooner. A fusion needs 3 s of
  contact: in the bowl the share of meetings that fuse fell from about
  50 % to about 20 %. The hold and the relay each cut about as much alone
  (17 -> 11 and 10.5).
- Rule 5 and DoD 1 hold: the dip nudge is unchanged and still gathers,
  fusions still happen in the bowl (13 to 15 per seed; the rule sets no
  rate), 0 stalled, stuck or lost. On `stress-dense` the rate holds (21
  -> 22 per minute).
- **Proposed:** accepted, watched in chunk 22's repeat and the playtest
  (chunk 24); if fusion feels rare there, it becomes a chunk 24 item.
  Whether a lower fusion rate on that level is acceptable is the user's
  call; O122 leaves the register, and the user may reopen it.

**4. The build plan.** 5N done (0f3d027). 24g part A done (a0ffdde); its
closure measures done (7595762); one fix in progress: the relay must
survive a save and reload, since `SlimeBodies.train_hopped` isn't state
(a `stress-dense` save taken just after a take-off parts from the run
that never stopped one tick after the load). 22c done (57d38e7). Next:
chunk 22 repeated on the S20 FE (in `auto`), the rest of 24, the health
review.

**Documents:** `tuning.md` (the ceiling's rows, the hold's row);
`tech-direction.md` (crowd detail, Testability, the next steps);
`versions/v1/master-spec.md` (header, 6); `levels/test/README.md`
(Repeatability); `versions/v1/build-plan.md` (Progress, the table, 5N,
22c, 24g); `open-questions.md` (O122 out); `README.md`.
**Flagged:** for documentalist, `req_offscreen_simulation` (the hold
after a bounce) and `req_test_level_and_test_mode` (exact repeat
outside `auto`).

## D163 — The user's answers of 2026-10-07: a displaced sleeper stays asleep (D139, 24.4) settled; rule 23 leaves a basket's own fill out; the tick cap settled, the phone frame budget a headroom target (D138); catch-up: 24g closed, chunk 22's repeat on the phone (session 6), the phone hash finding, 24.4 and 24.7 done (2026-10-07)
Answers O107 (a) in part. Settles D139's 24.4 (refines D72 and D131) and
D138 (2a); turns D138 (2b) into a headroom target.

The user's words (2026-10-07, answering the orchestrator's questions):
1. "Approve: D139 settled; rule_saves_never_wiped reworded ('re-placed
   when their spot or a free spot exists, else lost'), contract_atd minor
   bump. The no-wipe guarantee is unchanged."
2. "Exclude basket fill: slimes inside a basket's box don't count toward
   rule 23; the pile outside it still does".
3. "Approve cap, budget as target: the cap is settled; 8/4 ms becomes a
   headroom target, recorded but not a v1 gate, since 59 fps already
   holds."

**1. A migration keeps a displaced sleeper asleep (settled, as built in
61b8d5f).** Refines D72 and D131 (both made every displaced slime lost).
- A sleeper displaced by a level-version migration goes back to **its
  stable ID's spot** when the level still has that sleeper: its spot
  moved, or its species changed (the save's species is kept).
- Otherwise it goes to the **nearest empty sleeper spot** (a level
  sleeper no slime of the save holds, nearest the sleeper's saved
  centre) and **takes that spot's stable ID**; each spot takes one, in
  save order.
- **Only awake displaced slimes, and a sleeper left with no spot** (the
  level has fewer empty spots than such sleepers), **are lost**: to the
  loop start (D10), each once, the population whole.
- **Saves are never wiped:** unchanged. D72's "displaced slimes are
  treated as lost" now reads: an awake displaced slime is lost; a
  displaced sleeper is re-placed when its spot or a free spot exists,
  else lost.
- **As measured:** the phone's version-1 save of 2026-09-30 lost 105
  sleepers before, none after. The `old-version` fixture's moved sleeper
  is now put back asleep at its spot, nothing lost (its hashes
  re-recorded).
- D139's other items aren't in this answer: 24.5 stays proposed; 24.6
  was approved with chunk 22b (D144).

**2. Level rule 23 leaves a basket's own fill out (the user's).**
Answers O107 (a) in part.
- **Slimes inside a basket's box** (where its caught slimes rest) **don't
  count toward rule 23; the pile outside a basket still does.**
- *(Proposed, the measure's reading:)* a slime is inside when its centre
  is inside the box; the largest awake cluster is then taken over the
  other slimes, so two piles outside a basket aren't joined into one
  through the slimes in it.
- **The limit stays proposed:** above 20 slimes for more than 5 s in a
  row fails. `ClusterWatch`'s values (`LIMIT` 20, `HOLD_SECONDS` 5,
  sampled every 6 ticks, 0.1 s) are now rows in `tuning.md`, proposed.
- **Still open in O107:** whether a train queue on the loop counts ((a)'s
  other half; `stress-moving`'s dense train reads as one cluster of
  133), the lean (b, item 24.8), whether section 3 needs an edit (c), and
  rule 24's reuse of the limit (d).
- **On the test level:** item 24.7's numbers were taken with the fill
  counted. Section 3 went above the limit in its play (59 slimes, 21.9 s
  in a row) and its basket's drain (55, 11.3 s) because basket 3's fill
  of 59 to 60 is one cluster by itself. They are taken again once
  `ClusterWatch` leaves the fill out (the next small change), before any
  verdict.

**3. The tick cap settled; the phone frame budget a headroom target
(the user's).**
- **Settled (D138 (2a)):** at most **2 ticks per frame at 1x**
  (`MAX_TICKS_PER_FRAME`, was 8), times the debug speed, rounded up. An
  overloaded scene plays in slow motion instead of collapsing into the
  catch-up spiral.
- **The reference phone's frame budget (D138 (2b))** (simulation at most
  8 ms, drawing at most 4 ms, at least 4.7 ms left, per 16.7 ms frame) is
  a **headroom target**: measured and recorded at each phone session,
  not a v1 gate and not part of the Definition of done. DoD 30, the frame
  rate, is the gate.
- **Item 24.1's target follows:** the frame rate gates (a steady 60 fps
  on the desktop overlay through section 3; DoD 30 on the phones). Its
  tick numbers are recorded against the budget's simulation share (on
  the desktop, a tick of about 2.4 to 3.8 ms), not gated. D128's
  proposed gate of 8 ms per tick at p95 on the section 3 bench cases is
  replaced by this.
- D138 (2c), the `s3-basket-59of60` fixture, and (2d), phone numbers
  through logs, aren't in this answer; they stay as they were.

**4. Catch-up (facts, from the commits and `docs/dev/`).**
- **a. Chunk 24g closed.** The relay's save and reload fix landed
  (5d7409f, merged in 578ccff; ATD 459642e). Tick cost +0.4 to +6 % on
  the native tick, judged within noise by the orchestrator.
  `Train._behind`'s linear scan goes on the health review's list. O125
  stays the user's: 24g is built in v1, and the user may still drop it.
- **b. Chunk 22's repeat on the phone, session 6** (2026-10-07, main
  cfe1dab, crowd detail `auto`, native tick, `perf.sh` runs p8-*):

  | Fixture | Cold p50 / p5 | Warm p50 / p5 | Detail ceiling |
  |---|---|---|---|
  | `s3-basket-59of60` | 59.1 / 58.7 fps | 59.1 / 58.8 fps | stepped to 1 at 47 s |
  | `stress-dense` | 59.1 / 58.9 fps | 59.1 / 58.7 fps | stayed 0 |
  | `stress-moving` | 23.0 / 21.0 fps | 59.0 / 43.9 fps | reached 3 in 5 s, no thrash |

  - The GDScript tick on `s3-basket-59of60`: 21.2 / 16.7 fps cold, 23.4 /
    22.6 warm. The morning's odd pair (GDScript at 58 cold) was a bad run.
  - A tick costs about 10 ms on the phone: off screen 4.0 ms,
    `train_follow` 1.7, fusion 1.0, the frontier 1.0, the native solver
    0.3. The battery stayed at or under 32.1 °C, thermal status 0.
  - **DoD 30 is met on the reference phone for these three fixtures**
    (`stress-moving`'s abuse target of 15 fps on both the median and the
    5th percentile, so O115 doesn't decide it there). The floor phone is
    still unmeasured (O14).
  - **Not yet run** (the user needed the phone): the labels off against
    on (item 24.6's number), normal play, the `loop-start-pile` fixture
    (item 24.5), the second native basket run, and chunk 20's checks by
    hand. All are scripted for the next session (7). **Chunk 22's repeat
    stays open until then.**
- **c. The phone hash finding** (daf1d66). `s3-basket-59of60`'s hash is
  4c5d03d2… on the phone on both ticks, and a0223398… on the desktop.
  Android's C library (bionic) gives an `atan2f` that differs from
  glibc's in the last bit; it enters the state through `Vector2.angle()`
  in `SlimeBodies._resample` when crowd detail resamples a ring. Neither
  the view nor the native tick is the cause. This is the known caveat:
  **hashes compare within one build and one platform**.
  `tools/linux/bionic_libm.sh` (a shim giving a desktop run bionic's
  `atan2`, `atan2f`, `sin` and `cos`) reproduces the phone's hashes on
  the desktop. *Not scheduled, possibly after v1:* our own `atan2`,
  `sin` and `cos` would allow determinism across devices, if replays or
  sharing ever need it (`versions/timeline.md`).
- **d. Item 24.4 done** (61b8d5f), with **item 24.5's fixture**
  `loop-start-pile` (the phone's migrated save of 2026-09-30, a stress
  case kept on purpose: 103 awake, 91 piled at the loop start); its phone
  run is pending (session 7).
- **e. Item 24.7 done** (5509f71): the measure (`ClusterWatch`), the
  bench's fields, the played tests, a synthetic level failing and
  passing, the checker's line, the tutorial pages and the skill. The test
  level as measured: sections 1 and 2 never above the limit; section 3
  above it because of basket 3's fill, which 2 now leaves out.

**5. The next order (the orchestrator's plan):**
1. a small change: `ClusterWatch` leaves a basket's own fill out (2);
2. item 24.3, running;
3. item 24.8;
4. item 24.2, the quota pies (a placeholder look until ux-writer's);
5. item 24.1, recording the numbers (3);
6. the phone's session 7 (the runs in 4b not yet run) and chunk 20's
   checks by hand;
7. the health review.

**Documents:** `level-design.md` (rule 23); `tuning.md` (rule 23's rows,
the cap and the budget, 24.1's row); `tech-direction.md` (the cap, the
budget, Saving, Testability, the next steps); `versions/v1/master-spec.md`
(header, 5.10, 6, 7, Known gap 5); `versions/v1/build-plan.md` (header,
Progress, the table, 22, 24g, 24.1, 24.4, 24.5, 24.7, the closing step);
`versions/v1/README.md`; `versions/timeline.md` (determinism across
devices); `levels/test/README.md` (the fixtures `old-version` and
`loop-start-pile`, Repeatability, rule 23's row); `open-questions.md`
(O14, O107, O108, O115, O125); `README.md`. Notes added under D72, D138
and D139.
**Flagged:** for documentalist, `rule_saves_never_wiped` (the user's
rewording: "re-placed when their spot or a free spot exists, else
lost") and `contract_atd`'s minor bump (the user's), the migration's
pending notes (f09a501), rule 23's DRAFT atom (a basket's own fill left
out), `req_platform_and_performance_targets` (the cap settled, the
budget a headroom target, DoD 30 met on the reference phone for three
fixtures, chunk 22's repeat still open) and `domain_testability` (hashes within
one build and one platform). Outside `specs/`: the `level-review`
skill's rule 23 line and `docs/level-design/` (06-population,
09-check-the-rules) need the basket's fill left out once `ClusterWatch`
does; `CODING_RULE.md`'s health list gains `Train._behind`'s linear scan.

## D164 — Item 24.3 and rule 23's basket exclusion as built: basket 3's outlet over slide 3's drop; the test level passes rule 23 in every section; O107 (c) narrowed (2026-10-07)
Facts as built, with one proposed acceptance (the orchestrator's) and one
new question (O126). Narrows O107 (c); notes on O62 and O119. Sources:
the merge messages of 18d1a86 (item 24.3) and b14f0d5 (rule 23's
exclusion); `docs/dev/README.md`, "A fired basket empties (item 24.3)"
and "Level rule 23 on the test level".

**1. Item 24.3 done** (18d1a86; suite 1582/1582 native, 126/126 the
GDScript pass).
- **The cause was the outlet's clearance, not switch 3's trapdoor.** The
  trapdoor shut at tick 570, before the fire at 675, and no released slime
  fell back in. A release waits until the outlet is clear
  (`OUTLET_CLEARANCE`); a released slime sat at rest on basket 3's outlet
  (on the plateau, over the trapdoor) until its own hop timer ran out (1.5
  to 3 s), and from about 8 s after the fire the bowl's train crossed the
  outlet and kept it busy. Before the fix, 7 of 61 slimes were out 28 s
  after firing.
- **The fix, the test level only (proposed, the orchestrator's
  acceptance of the build's fix):** basket 3's `outlet_point` is
  (535.68, -134), at x 18979.2, y -144: over slide 3's drop, in the middle
  of its shaft (x 18893 to 19066), at the loop's height, past the
  plateau's end. Was: a point on the plateau 200 px before slide 3's
  entrance (chunk 16). A released slime falls clear at once and the
  bowl's train only crosses that point falling, so the 0.3 s pace holds.
  Basket 2, the default outlet and the release code are unchanged.
- **Measured:** basket 3 is empty **18.4 s** after firing (1104 ticks;
  done-when 28 s), 0 caught again; 60 s later all 200 slimes are train
  slimes and none is stalled. Basket 2 is empty **13.1 s** after firing
  (done-when 14.5 s). Bedtime pauses the releases and sunrise resumes
  them. New test `test_basket_drain_e2e`; three tests changed for the new
  outlet; only `s3-basket-59of60`'s hash at 2400 ticks changed.
- **Against rule 24** (an outlet is a place where a flow lands slimes; it
  gives them room and a clear way onward): the new outlet meets it as
  measured. The released slimes fall down the shaft and ride slide 3 home
  (about 4 in the shaft and 11 to 16 along its bottom at once, riding
  on); the drain's largest awake cluster outside the basket's box is 5.
  What the measure doesn't cover: the drain now comes home at the full
  0.3 s pace, and whether that burst may outpace the train at the loop's
  start is rule 24's rate check, after v1 (O119's note).
- **O62 stays open:** where a basket's outlet goes is the basket object's
  own design. The test level's move is one placement, and it adds a
  lesson to O62: an outlet where a released slime rests, or where a flow
  crosses, can't keep the release pace.
- **New, O126:** baskets 1 and 2 still release at about one slime per
  hop interval (a released slime rests on the outlet until it hops).
  Basket 2's fixture (6 slimes) passes. But a basket filled with base
  slimes may not empty within D128's bound (quota × 0.3 s plus 10 s,
  "however busy the outlet"). This is not measured.

**2. Rule 23's basket exclusion built** (b14f0d5; D163 (2), the user's).
`DebugCounts.largest_cluster` takes boxes to leave out, by a slime's
centre, before clustering (so piles can't join through a basket);
`ClusterWatch` passes the level's basket boxes; the debug overlay and the
PERF line still count every slime. D163's proposed reading (inside by the
centre, the cluster taken over the other slimes) is what was built.
- **The test level passes rule 23 in every section** on the merged tree
  (18d1a86): section 3's play peaks at 23 slimes for 0.1 s in a row (was
  59, 21.9 s); section 3's drain at 5 (was 55, 11.3 s). Sections 1 and 2
  stay far under the limit.
- **The bench:** `s3-basket-59of60` (lead-in 60) reads 37 slimes, above
  the limit for 2.6 s in a row (was 59, 5.9 s), under the 5 s hold: the
  pile outside the basket, which still counts. `stress-moving` (excepted)
  still reads one cluster of 133.
- **O107 (c) narrowed (proposed):** section 3 needs no edit for rule 23
  under the proposed limit. It is measured with the local wake, 24.3 and
  the exclusion in. Still open in (c): the numbers again after the lean
  (24.8), and again if (a)'s calibration moves the limit.

**3. The order:** 24.3 done (18d1a86); next 24.8 (running), then 24.2,
24.1's record, the phone's session 7 (with chunk 20's checks by hand),
the health review.

**Documents:** `levels/test/README.md` (section 3, the outlet, rules 23
and 24's rows); `tuning.md` (basket 3's outlet, the emptying bound's
measures, `ClusterWatch`'s row); `level-design.md` (rule 23's note);
`versions/v1/build-plan.md` (header, Progress, 24.3, 24.7);
`versions/v1/master-spec.md` (Known gap 3); `open-questions.md` (O62,
O107, O119, O126); `README.md`.
**Flagged:** for documentalist, rule 23's atom (the exclusion now built)
and 24.3's post-task sync (`req_switch_basket_gate_set`; basket 3's
outlet placement, proposed). Outside `specs/`: in `docs/dev/README.md`,
the "Since item 24.3" paragraph and 24.3's "Level rule 23" paragraph give
section 3's drain with the fill counted (57 slimes, 9.2 s in a row) and
say the basket's pile still goes above the limit. On the merged tree,
with the fill left out, the drain peaks at 5 (18d1a86's message). The
`--lead-in=700` bench row has no number taken after both changes.
