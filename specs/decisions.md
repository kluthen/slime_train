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
