# Test level

Status: draft v11

A compact level that puts nearly every v1 gameplay item in one place (D76).
It is the testing ground while the game is built, and the level the
automated end-to-end tests drive on the Linux build (see "Testability" in
`../../tech-direction.md`).

- It is **not** the real first level (`../01/`, designed later). Its layout,
  pacing and size teach us nothing about how the real level should feel.
- It never ships in the release build (D91). It uses placeholder art.
- It follows every rule in `../../level-design.md`. The checklist is at the
  end of this document.
- Positions and sizes are rough. Whoever builds the scene may move things,
  as long as the rules and the coverage matrix still hold.

## Conventions

- **Side view, landscape, locked** (D78).
- **Distances are in screens.** 1 screen = the width of the view at normal
  zoom. Screen 0 is the left edge of the level. The level is about 16.5
  screens wide.
- **The loop runs left to right along the surface.** Each section's return
  route to the start is an **underground slide** that runs back beneath the
  surface and comes up into the start basin behind the loop's start (see
  1.1).
  - The slides are a **placeholder for testing only**. They do **not** settle
    how the real level brings slimes back to the start (O22).
- **Camera rails** follow the whole loop: the outgoing surface route and each
  slide, which has its own rail (D79). The right edge button moves forward
  along the loop, round the turn and back along a slide (D90).
- **Species** are labelled A to E, with placeholder colours: A red, B blue,
  C yellow, D green, E purple. Species differ by colour only (D81).
- Every sleeper is size 1. The level holds exactly **200 base slimes** (D67).

## Overview

| Section | Screens | Species | Areas |
|---|---|---|---|
| S1 "Meadow" | 0–8 | A, B, C | start basin, hills, fusion dip, high step, the tree, frontier set 1 |
| S2 "Caves" | 8–13 | adds D | descent, parade, second dip, the cave branch, frontier set 2 |
| S3 "Big bowl" | 13–16.5 | adds E | entry ramp, the bowl, the high rim, frontier set 3 |

## Section 1 — Meadow (screens 0–8)

**1.1 Start basin (0–1).**
- A shallow basin carrying the loop-start **split zone** (rule 4). Every
  return slide comes out here.
- The game wakes the **first slime** (species A) in the basin.
- The **first sleeper** (B) sits about a quarter of a screen to the right
  (built at 0.27), on a small ledge just above the loop (rules 17, 18). On
  the very first play, the wordless hint pulses next to it after about 10 s
  without a call (D65).
- **As built (chunk 16e; D116).** Rebuilt so that DoD 1 holds
  over the whole level (x in screens, y in px, up is negative):
  - **The loop's start** is at 0.21, y 476, at the top of a ramp. From
    there the loop's route rises over the ramp (to 0.25, y 416) and eases
    down onto a **terrace** (top y 460, 0.26 to 0.6), which carries the
    loop's first stretch; the terrace then climbs out of the basin at
    35–38° to the hills. The old lip at 0.64 is gone.
  - **The slides come home under the terrace.** Their shared tail runs
    along the bedrock's floor beneath it (0.78, y 561; 0.64, 576; 0.28,
    586), in a lane about 100 px high (a size 3 is 79 px tall), then up the ramp
    (0.255, 566) into the loop's start (0.21, 476).
  - **The pocket** lies behind the loop's start: the basin floor at y 500
    from 0.05 to 0.21, against the level's left wall (0.03 to 0.04). A
    slime coming home up the ramp pops out there, behind the train, and
    hops on after it, travelling the loop's way. The pocket is wide enough
    for a size 3 coming home (split into three there) and the slimes
    behind it.
  - **The first slime** starts in the pocket at 0.19, y 476.
  - **The first sleeper** (`s1.sleeper.01`) sits at 0.46, y 311 on
    `FirstLedge` (0.42 to 0.5, top y 335, 20 px thick, 105 px over the
    terrace), 0.27 screens right of the first slime. A called base slime
    can hop onto it, and a hopping base slime passes under it.
  - **The split zone** (`start.split-zone`) spans x 0.03 to 0.54, y 370 to
    560: the pocket, the ramp's top and the terrace, reaching past the
    first sleeper's ledge, so only base slimes ever pass under the ledge.
    Nothing fuses in the basin (a split zone has no fusion).
  - **Why.** Before 16e the slides' tail ran home along the basin floor
    over the loop's first stretch, against the train: each slime coming
    home shoved the outgoing train slimes back 100 to 250 px; slimes queued
    there fused past the split zone (which ended at 0.4), and a size 3 then
    crawled under the first sleeper's ledge (80 px over the floor). A train
    slime was lost as stalled (D118) in 5 of 10 fifteen-minute sessions
    with no input, always in the basin. A ledge a called base slime can
    reach is too low for a size 2 or 3 to pass under at its pace (their
    hops top out 108 and 130 px over the ground), and a ledge high enough
    for them would be out of a called slime's reach; hence the split zone
    reaching past the ledge. The lesson for the real level's return routes
    is D117 (O22). The slides' tail is still a placeholder (O22).

**1.2 Hills (1–2.5).**
- Gentle rolling hills. The loop follows their tops.
- 12 sleepers sit on side bumps above and beside the loop. Every bump slopes
  down onto the loop, so a woken slime heads back by gravity alone.
- Exercises: calls, waking, the unsure phase, heading back, rejoining the
  train, and the camera drag toward a call (D45).

**1.3 Fusion dip (2.5–3.5).**
- A U-shaped dip in the loop. Train slimes bunch up at the bottom, which
  nudges same-species slimes into fusing (rule 5, D20, D37).
- Two C sleepers rest in a hollow on the dip's rim, off the loop.
- Exercises: fusion on its own, fusion reset by a hop, and bumping when a
  fusion would go past size 3 (for example 3 + 1) (D49).

**1.4 High step (3.5–4.5).**
- No fork: filters are v2 (D89), and every size travels the loop the same way
  (rule 2).
- Beside the loop, a **ledge** stands on a step that only a called size-3 slime
  can hop up. Its far side slopes back down to the loop at 4.5 (its route
  back, rules 7, 8). Nothing lives up there: it tests jump height by size.
- A framing zone shows the loop and the ledge at once (rule 19).

**1.5 The tree (4.5–5.8).** An exploration branch.
- A **lower platform** high above the loop, holding 6 sleepers (A, B and C, 2
  of each). Their outlines and the platform's edge peek into the top of the
  view from the loop (rule 9).
- A **high bough** above the platform holds 3 A sleepers. Only a size-3 jump
  from the platform reaches it.
  - Smaller slimes called to the bough can't reach it. Their calls end after
    about 8 s (D73), and they pile up under it. That is the fusion-by-call
    case (D20).
- **Getting up:** a slope that a size-1 slime can hop up when called.
  Tilting the phone helps free slimes along, but is never needed (rule 10,
  D64).
- **Route back:** a separate, gentler slope down the far side that lands on
  the loop at about 5.8 (rules 7, 8). A slime falling off the bough lands on
  the platform, then takes the same slope.
- A **framing zone** at the tree's foot zooms out and shifts up, to show the
  loop and the lower platform together (D60, D61).

**1.6 Frontier set 1 (6–8).**
- 5 sleepers on ledges above the switch (B ×2, C ×3).
- The rest of the set is described under "Frontier sets" below. The whole set
  fits on one screen, so this basket fills in view.
- **As built (chunk 14).** Positions moved from the table below while
  building, as allowed above:
  - switch 1's **trapdoor** (6.5 to 7.29) replaces the crust bridge that
    first covered pit 1: it is solid while the switch sends the flow onward,
    open while flipped;
  - **basket 1** is the pit under it: centred at 6.895 screens, 0.81 screens
    wide and 200 px deep, quota 6;
  - a **pillar** (7.66 to 8.5) replaces the chute's far wall; its top
    carries the loop on to **gate 1**, at 8.58. Gate 1's **lid** (7.49 to
    7.67) shuts slide 1's entrance once the gate is open (D105);
  - the temporary section 2 stub that first stood past gate 1 was replaced
    by section 2 itself in chunk 15.

## Section 2 — Caves (screens 8–13)

**2.1 Descent (8–9).**
- Past gate 1, the loop steps down into a cave. 6 D sleepers sit on side
  ledges, all visible from the loop. This is the first sight of the new
  species (rule 11).

**2.2 Parade (9–10).**
- A long, flat stretch with overhang ledges above it (A, B, C and D, 2 of
  each).
- A mild zoom-out framing zone covers it.
- Exercises: the idle camera takeover and its cue, the screensaver zoom,
  entering a framing zone, and the longer delay to leave it (D59–D62).

**2.3 Second dip (10–10.5).**
- A smaller dip where size-2 slimes meet: 2 + 2 just bump (D49).
- 2 D sleepers rest beside it, off the loop.

**2.4 The cave branch (10.5–11.8).** An exploration branch.
- A stepped climb from the loop leads up to a cave pocket holding 14
  sleepers (A ×3, B ×3, C ×3, D ×5).
- **Route back:** a long, winding tunnel. It descends for about 3 screens of
  path and comes out on the loop at about 11.8. It takes a size-1
  slime longer than "left alone" (10 s) but well under "lost" (1 min after
  that). First proposed at 30–40 s; as built (chunk 15) it is about
  3100 px, some 46 s from the pocket (about 33 s from shelf A, where the
  `s2-cave-return` fixture starts). That still leaves about 24 s before
  "lost" (70 s off screen in all), so it is kept (D108).
- Exercises (D69, D70):
  - a free slime going off screen follows the route back by projection;
  - moving the camera to the tunnel's mouth makes it reappear and physics
    take over again;
  - a slime becomes left alone, then rejoins the train before it is lost.

**2.5 Frontier set 2 (11–13).**
- 10 sleepers on ledges around the switch (A ×2, B ×2, C ×2, D ×4).
- The basket sits **1.5 screens away from the switch**, out of view while the
  camera is at the switch.
- Exercises: the basket filling off screen, and its reward and firing waiting
  until it is in view (D70). The rest of the set is under "Frontier sets".

**As built (chunk 15; approved, D108).** Section 2 follows the plan above, with these
positions (x in screens, y in px, up is negative):
- **Descent:** the ground steps down from the pillar's top (y -100 at 8.6)
  to the cave floor (y -20 at 9.0). The 6 D sleepers sit on two side
  ledges (8.55 to 8.72 and 8.78 to 8.95).
- **Parade:** two overhang ledges (9.15 to 9.36 and 9.6 to 9.81, y -240),
  4 sleepers on each.
- **Second dip:** 10.0 to 10.5, 120 px deep; its 2 D sleepers sit in a
  hollow on its left rim (9.93 to 10.09).
- **The cave:** a climb of 4 steps (10.5 to 10.95) up to the pocket (10.95
  to 11.65, floor at y -700) with its 14 sleepers. The branch is
  `s2.branch.cave`. Its route back, `s2.route-back.cave`, runs along the
  pocket, back along two tunnel shelves (shelf A, then shelf B, each turning
  at a lip) and drops onto the loop at 11.92.
- **Frontier set 2:** signpost at 10.9, switch at 10.97. Switch 2's
  trapdoor covers basket 2's pit: 12.2 to 12.55 (0.35 screens wide), 170 px
  deep, quota 15, about 1.4 screens from the switch. Slide 2's entrance is
  at 12.66, gate 2 at 12.8, and gate 2's lid (12.59 to 12.73) shuts slide
  2's chute once the gate is open (D105). The 10 set sleepers sit on two
  ledges, one by the switch (10.76 to 10.93) and one before the pit (12.0
  to 12.27).
- **Slide 2** drops down the chute at 12.66 and runs back along the tunnel,
  joining slide 1's tail to the start basin.
- **Framing zones:** `s2.frame.parade` (centred at 9.5, 1 screen wide) and
  `s2.frame.gate` (centred at 12.6, 0.8 screens wide). Chunk 16d added
  `s2.frame.cave` (centred at 11.25 screens, y -150, 1.3 screens by 500 px:
  10.6 to 11.9; D116): on the rails there, the view shows the loop
  and the cave pocket's 14 sleepers at once (rule 9). It stays clear of
  `s2.frame.gate`. Their zooms are in `../../tuning.md`.
- Sleepers are numbered left to right: `s2.sleeper.01` to `.40`.

## Section 3 — Big bowl (screens 13–16.5)

This is the stress area (rule 16, D67, O14).

**3.1 Entry ramp (13–13.5).**
- Past gate 2, a ramp leads down to the bowl. 10 E sleepers sit on side
  ledges above it.

**3.2 The bowl (13.5–15.5).**
- A wide, shallow saucer that is part of the loop. The train rolls down into
  it and hops up the far side. The walls are gentle enough for a size-1 hop
  (rule 2).
- Tiered shelves line both inner walls and hold 90 sleepers: A, B, C and D,
  15 each, plus 30 E.
  - The shelves tilt inward. A woken slime falls into the bowl, which is the
    loop, so falling in is its route back (rules 7, 8).
  - As built, the shelves float over the bowl in three tiers a side, and
    each side is a branch with an authored route back (see "As built
    (chunk 16)" below).
- A framing zone shows the whole bowl, about 2 screens at normal zoom.
  That means zooming out to about half (built at 0.5).

**3.3 High rim (15–15.5).**
- A rim above the far wall holds 30 sleepers (A, B, C and D, 5 each, plus 10
  E). Only a size-3 jump from the far wall reaches it. Anything that falls off
  lands back in the bowl.
- As built, the rim runs on over the plateau, a size-3 jump from the
  plateau's end reaches it, and it has its own route back (see "As built
  (chunk 16)" below).

**3.4 Frontier set 3 (15.5–16.5).**
- The basket is a wide, flat-bottomed pit. Slimes resting in it don't hop, so
  a big pile sits still (rule 16).
- A framing zone shows the switch and the whole pit on one screen.
- Its target is the **level-complete celebration** instead of a gate. This
  is D77. After the
  celebration, the basket releases its slimes onto the loop just before the
  section 3 slide, and the loop stays complete.
- The celebration plays once **every basket of the level has fired**
  (chunk 14). Basket 3 can only fill once gates 1 and 2 are open, so it is
  always the last to fire. Before section 3 was built, basket 2 was the last,
  and the celebration waited only for it.

**As built (chunk 16; approved, D108).** Positions moved from the plan above, as allowed:
- **The loop:** from gate 2 (the ground starts at 12.72) down the entry
  ramp (13.0 to 13.6), across the bowl's floor (13.6 to 15.05, ground at
  y 100), up the far wall (15.05 to 15.62) to a plateau (ground at y -120),
  over switch 3's trapdoor, to slide 3's entrance at 16.4.
- **Slide 3,** the level's last return route (it has no gate), drops down
  a chute at 16.4 and runs back under sections 2 and 1, joining slide 2's
  and then slide 1's tail.
- **Entry ramp:** two flat side ledges (12.96 to 13.18 at y -210, and 13.22
  to 13.42 at y -160), 5 E sleepers on each. The higher one is reached only
  by a called size-2 or size-3 slime.
- **The shelves float over the bowl** instead of lining its walls: three
  tiers on each side (left 13.42 to 14.18, right 14.28 to 15.02), about
  160 px apart (tops near y -100, -255 and -420), each tilted down toward
  the bowl's middle, and each tier's inner end past the one above it. 15
  sleepers on each shelf. A woken slime rolls off into the bowl, which is
  the loop. The upper tiers are reached only by a called size-2 or size-3
  slime.
- **The rim** lies over the far wall's top and the plateau (15.05 to 16.19,
  top about y -300), not over the far wall alone. It is reached only by a
  size-3 jump from the plateau's right end (16.3 to 16.4, just past the
  rim's end and just before slide 3), not from the far wall. A slime falling
  off its left part lands in the bowl; off its right part it lands on the
  plateau, which is the loop (or into basket 3 while switch 3 is flipped).
  Both meet rule 7. 30 sleepers, 0.038 screens apart.
- **Three exploration branches, each with its route back** (rules 3, 8):
  `s3.branch.left-shelves`, `s3.branch.right-shelves` and `s3.branch.rim`,
  with `s3.route-back.*`. The shelves' routes run down the tiers' inner ends
  to the bowl's floor; the rim's runs along the rim to its left end and
  down into the bowl. The plan above relied on falling alone; authored
  routes back are what every other branch has (D51), and they give the
  off-screen simulation a route to follow.
- **Species on the shelves and the rim** follow the cycle A, E, B, E, C, D,
  which gives the counts in "Population".
- **Frontier set 3:** signpost at 15.62, switch at 15.67. Switch 3's
  trapdoor covers basket 3's pit: 15.72 to 16.3, centred at 16.01, 0.58
  screens wide and 220 px deep, quota 60. No gate. Its outlet is a fixed
  point on the loop 200 px before slide 3's entrance (over the trapdoor,
  which is shut once the basket has fired); with no gate, there is no
  retired return route for the default outlet to find.
- **Framing zones:** `s3.frame.bowl` (centred at 14.375, 1.85 screens wide:
  13.45 to 15.3, zoom 0.5) and `s3.frame.basket` (centred at 15.875, 1.15
  screens wide: 15.3 to 16.45, zoom 0.8). Details in `../../tuning.md`.
- Sleepers are numbered left to right (top to bottom where two share a
  place): `s3.sleeper.01` to `.130`.

## Frontier sets

Each set is a switch, a basket and a gate (D14, D35, rule 12). The switch
sits on the loop:

- In its **default** direction (onward), the flow carries on toward the gate.
  While the gate is closed, a slide entrance just before it takes the flow.
  That entrance is the end of the loop.
- **Flipped**, the switch sends the flow into the basket.

| Set | Switch | Basket | Quota (weight) | Gate | Slide | Target |
|---|---|---|---|---|---|---|
| 1 | 6.5 | 7.0, just below the onward path, in view from the switch | 6 | 7.8 | entrance at 7.6 | gate 1 |
| 2 | 11.0 | 12.5, in a pit under the gate, **off screen from the switch** | 15 | 12.8 | entrance at 12.6 | gate 2 |
| 3 | 15.6 | 16.0, a pit | 60 | — | entrance at 16.4 | celebration (D77) |

This table is the plan. As built: set 1 in 1.6 (switch 6.5, basket centred
at 6.895, gate 8.58), set 2 in 2.5 (switch 10.97, basket 12.2 to 12.55,
gate 12.8, slide 12.66), set 3 in 3.4 (switch 15.67, basket centred at
16.01, slide 16.4). The quotas are as planned.

**When the basket fills:**
1. The reward animation plays. It waits until the basket is in view
   (D70, D91).
2. The basket fires. The gate opens, and the loop grows into the next section
   (D9).
3. As part of the reward, the old slide entrance closes (built as the gate's
   lid, which the master spec allows, D105). Only the route back
   to the start is replaced: the next section's slide takes over.
4. The basket releases its slimes.
5. The switch and basket become inert for good (D86).

**Opting out (D70):** flipping the switch back before the basket is full stops
the filling. The slimes inside go back to the loop (D91).

**Outlet (proposed; the basket's own design, O62):** each basket has one outlet that drops slimes onto the
onward path just before the slide entrance. While the gate is closed, the
path leads into the slide. Once the gate is open, it leads through the gate.
Releasing after firing and emptying after an opt-out both use the same
outlet. Built (chunk 14) as a basket property, 200 px along the loop before
the slide entrance (`tuning.md`), one slime at a time when the outlet is
clear. Basket 3 has no gate, so it names its outlet as a point instead: 200
px before slide 3's entrance (chunk 16).

**Weight:** the outlines fill by weight. A size-3 slime fills 3 at once.

## Framing zones

| ID | Screens | Shows | Tests |
|---|---|---|---|
| `s1.frame.high-step` | 3.5–4.5 | the loop and the ledge | framing beside the loop |
| `s1.frame.tree` | 4.5–5.5 | the loop and the tree's lower platform | zoom out and shift up; the exit delay |
| `s2.frame.parade` | 9–10 | the parade, slightly wider | being ignored while the idle camera or screensaver mode follows a slime, then resuming (D80) |
| `s2.frame.cave` | 10.6–11.9 (added in chunk 16d; D116) | the loop and the cave pocket's sleepers, zoomed out and shifted up | a branch's hint kept in view (rule 9) |
| `s2.frame.gate` | 12.2–13 | gate 2, the slide entrance and the basket pit | reward waiting for view |
| `s3.frame.bowl` | 13.5–15.5 | the whole bowl | a strong zoom-out; stress |
| `s3.frame.basket` | 15.3–16.5 | switch 3 and the basket pit | a big still pile |

As built, the zones are close to these spans: `s2.frame.parade` 9–10,
`s2.frame.cave` 10.6–11.9, `s2.frame.gate` 12.2–13, `s3.frame.bowl` 13.45–15.3 and `s3.frame.basket`
15.3–16.45. Their zooms and offsets are in `../../tuning.md`.

## Population

At the start, 1 slime is awake: the first slime, A, in the start basin. Every
other slime is a size-1 sleeper.

| Area | A | B | C | D | E | Total |
|---|---|---|---|---|---|---|
| 1.1 start basin (awake, then first sleeper) | 1 | 1 | | | | 2 |
| 1.2 hills | 4 | 4 | 4 | | | 12 |
| 1.3 fusion dip | | | 2 | | | 2 |
| 1.5 tree: lower platform | 2 | 2 | 2 | | | 6 |
| 1.5 tree: high bough | 3 | | | | | 3 |
| 1.6 frontier set 1 | | 2 | 3 | | | 5 |
| **S1** | **10** | **9** | **11** | | | **30** |
| 2.1 descent | | | | 6 | | 6 |
| 2.2 parade | 2 | 2 | 2 | 2 | | 8 |
| 2.3 second dip | | | | 2 | | 2 |
| 2.4 cave branch | 3 | 3 | 3 | 5 | | 14 |
| 2.5 frontier set 2 | 2 | 2 | 2 | 4 | | 10 |
| **S2** | **7** | **7** | **7** | **19** | | **40** |
| 3.1 entry ramp | | | | | 10 | 10 |
| 3.2 bowl shelves | 15 | 15 | 15 | 15 | 30 | 90 |
| 3.3 high rim | 5 | 5 | 5 | 5 | 10 | 30 |
| **S3** | **20** | **20** | **20** | **20** | **50** | **130** |
| **Level** | **37** | **36** | **38** | **39** | **50** | **200** |

The quotas leave plenty of room:

| Basket | Quota | Slimes available by then |
|---|---|---|
| 1 | 6 | 30 |
| 2 | 15 | 70 |
| 3 | 60 | 200 |

## Stable IDs (D72)

- **Pattern:** `<place>.<kind>.<name>`, lowercase, with no spaces.
  - `<place>` is `start`, `s1`, `s2` or `s3`.
  - Numbered items use at least two digits and count left to right.
    Past 99 they run to three digits without padding (section
    3's sleepers go from `s3.sleeper.01` to `s3.sleeper.130`, as built in
    chunk 16). Order them by their number, not as text: as text,
    `.100` sorts before `.11`.
- **Examples:**
  - `start.split-zone`, `start.first-slime`
  - `s1.sleeper.01` … `s1.sleeper.29`
  - `s1.switch`, `s1.basket`, `s1.gate`, `s1.slide`
  - `s1.branch.tree`, `s1.route-back.tree`, `s1.frame.tree`
- **Framing zones as built:** `s1.frame.high-step`, `s1.frame.tree`,
  `s2.frame.parade`, `s2.frame.cave` (chunk 16d), `s2.frame.gate`,
  `s3.frame.bowl`, `s3.frame.basket`.
- IDs belong to placed things. How a fused slime keeps an identity in the
  save is up to the save format (tech-direction).

## Coverage matrix

| v1 item | Where |
|---|---|
| The game wakes the first slime; the first sleeper nearby | 1.1 |
| First-play hint | 1.1 |
| Tap-to-call, ripple, slimes turning toward the tap | everywhere; first at 1.1–1.2 |
| Waking: only a free slime, only on screen | 1.2, and every sleeper area |
| Free-slime phases: answering, unsure, heading back | 1.2 (short), 1.5 (up a slope), 2.4 (long) |
| Call cap (~8 s) when the point can't be reached | 1.5 bough, 3.3 rim |
| Call replaced by a new tap | anywhere |
| Camera drag toward a call | 1.5, 2.4 (calls well off the rails) |
| Hopping rules per state; bigger slimes hop higher | everywhere; 1.4, 1.5 bough, 3.3 rim |
| Fusion: on its own, by call, reset by a hop | 1.3, 1.5 bough, 3.2 |
| Maximum size 3 and bumping (3 + 1, 2 + 2) | 1.3, 2.3 |
| Size = weight, filling baskets by weight | each basket |
| Split zone at the loop start | 1.1, whenever a slide returns fused slimes |
| Return routes coming home behind the loop's start (rule 22) | 1.1, every slide's tail |
| Train with no slots; a lone slime keeps going | the whole loop |
| Signpost at every fork; the rails follow the main stream | each frontier switch |
| Frontier set: switch, basket, gate, the loop growing, the slide replaced | 1.6, 2.5 |
| Basket filling off screen; reward waiting for view | 2.5 |
| Opting out by flipping the switch back | 1.6, 2.5 |
| Off screen: projected train, projected route back, respawn on approach | the slides, 2.4, 2.5 |
| Left alone (10 s) and rejoining | 2.4 |
| Lost (1 min), teleported to the start | fixture only (see below) |
| Framing zones and their exit delay | 1.4, 1.5, 2.2, 2.4, 2.5, 3.2, 3.4 |
| Idle camera and its cue; following a slime through a slide on its rail | 2.2; any slide |
| Screensaver mode zoom | 2.2, or anywhere |
| Tilt as a bonus only | 1.5 (helps; never needed) |
| First touch wins | anywhere, with scripted double touches |
| 200 base slimes; many on one screen, mostly still | 3.2, 3.4 |
| Save, reload, mid-air placement, the level version and migration | fixtures |
| Level completion | 3.4 (D77) |

**Session items don't depend on the level:** the timer, bedtime and the
wind-down, sunrise, screensaver mode, the cooldown, the parent gate, setup and
real-time counting. They are tested anywhere in the level through fixtures and
test mode.

## Test fixtures

Named save states that tests load through test mode (tech-direction).

| Fixture | State | For |
|---|---|---|
| `fresh` | no save; first launch | the first slime, the hint, and the start of setup |
| `s1-basket-5of6` | switch 1 flipped, basket 1 at weight 5 of 6, the next slime about to drop in, the camera on the basket (built, chunk 14) | the reward, firing, gate 1 opening, and slide 1 closing |
| `s1-optout` | switch 1 flipped, basket 1 at weight 3, the camera on the basket (built, chunk 14) | flipping back and emptying through the outlet |
| `gate1-open` | S2 reachable, 20 slimes awake, slide 1 closed. Built (chunk 16): gate 1 open as after basket 1 fired; the first slime and `s1.sleeper.01` to `.19` as size-1 train slimes spread along the outgoing loop; the camera at section 2's start | starting from S2 |
| `gate2-open` | gates 1 and 2 open as after baskets 1 and 2 fired (slides 1 and 2 shut), the same 20 train slimes spread along the whole outgoing loop, the camera at section 3's start. Added in chunk 16 | starting from S3; the whole loop with no input (DoD 1) |
| `s2-basket-offscreen` | camera at switch 2, basket 2 at 14, slimes heading into it (built, chunk 15: gate 1 open, the first slime about to reach switch 2) | filling off screen, then the reward on approach; gate 2 opens, and the celebration still waits for basket 3 |
| `s2-cave-return` | 3 free slimes starting down the cave's route back, camera away (built, chunk 15: on shelf A, the camera on the start basin) | projection, respawn, left alone and rejoining |
| `bump` | two size-2, one size-3 and one size-1 slime of species C on the fusion dip's floor (1.3), so both bumps can happen. Built (chunk 16): sizes 2, 2, 3 and 1 left to right, made of the eight C sleepers nearest the dip; nothing fuses. Since chunk 16f (D119) both bumps happen within 20 s on seeds 1 and 3 to 7; seeds 2 and 8 show the 3 + 1 bump only | 2 + 2 and 3 + 1 bumping; the end-to-end test runs seed 5 and asserts both bumps |
| `stress-still` | 200 woken base slimes (none left a sleeper), 60 in basket 3 and the rest piled in the bowl. Built (chunk 16): gates 1 and 2 open; the 60 in basket 3 are full and waiting to be in view; the 140 in the bowl are **asleep at bedtime** (a session at bedtime), because outside a basket only a bedtime pile rests (see below); the pile was settled until it rests, and rests about 670 ticks (about 11 s) after loading (since chunk 16d, which changed the terrain contact; about 8 s before) | the worst still case on one screen (O14, O57) |
| `stress-moving` | 200 train slimes spread through the bowl (built, chunk 16: size 1, lowest spots first, inside the bowl's view) | the worst moving case; beyond what normal play produces, so a measurement, not a target (D96) |
| `lost` | a free slime placed off screen, outside any area's route back (built, chunk 15: a D on the parade's first ledge beyond closed gate 1, the camera on the basin) | left alone at 10 s, then lost 1 min later (70 s off screen) and teleported to the start |
| `midair` | a save taken with slimes in mid-air | placement on reload (D12) |
| `old-version` | a save from an earlier test-level version with a moved sleeper | migration: the displaced slime counts as lost (D72) |
| `wind-down` | session clock at 890 000 ms (14:50) (built, chunk 17) | dusk and the slower hops, then bedtime |
| `bedtime` | session clock at 900 000 ms: bedtime just reached (built, chunk 17) | the cooldown and the parent code ending it (the code: chunk 18) |
| `sunrise` | session clock at 1 495 000 ms: 9:55 into the cooldown (built, chunk 17) | sunrise, then screensaver mode, then the first tap |

The three session fixtures start from the fresh level with a session
started and its clock jumped forward. They need sessions switched on in test
mode (the run's `"sessions": true`); otherwise the game plays untimed.

**`stress-still` and awake slimes.** Awake slimes out of a basket hop, so
they never rest; only a pile in a basket or a pile asleep at bedtime stops
simulating (the resting-pile fallback, D96). A still pile of 140 in the open
is therefore a bedtime pile. A big pile of size-1 slimes (which don't stack)
takes a while to rest after it forms; the fixture is saved already settled,
so it measures the pile at rest, not the minute before (the rest rule is
kept for v1 and revisited in chunk 22, D107).

**Lost** has its own fixture because the level itself can't produce it: every
spot a free slime can reach leads back to the loop (rule 7).

**Repeatability:** all gameplay randomness comes from the seeded generator
(tech-direction), and each test sets its seed.

## Rules checklist (`../../level-design.md`)

| Rule | How this level meets it |
|---|---|
| 1 Travelled with no input | the loop and slides need no input; the frontier switches default to onward |
| 2 Any size | no filters in v1: every size takes the same loop; the bowl walls are hoppable at size 1 |
| 3 No dead ends | the tree, cave, shelves and rim branches rejoin through their routes back; every slide returns to the start |
| 4 Split zone at the start | 1.1: the pocket, the ramp's top and the terrace, past the first sleeper's ledge |
| 5 Fusion dips | 1.3, 2.3 |
| 6 Signpost at every fork | each frontier switch (the only forks in v1) |
| 7 Gravity leads back | bumps and shelves slope toward the loop; the bough drops onto its platform; the rim drops into the bowl or onto the plateau, which is the loop |
| 8 Route back per branch | the tree: far slope; the cave: tunnel; the bowl's shelves (a branch per side) and the rim: authored routes down into the bowl (chunk 16), matching the fall |
| 9 Hints visible | sleepers peek into the view at every branch; framing zones at the tree and the cave |
| 10 Tilt is a bonus | tilt only helps at 1.5; nothing needs it |
| 11 Species per section | S1: A, B, C; S2 adds D; S3 adds E |
| 12 Switch-plus-basket | all 3 frontier sets |
| 13 Return route to the start per section | slides 1, 2 and 3, each with its own rail, coming home behind the loop's start (a placeholder; O22, D117) |
| 14 Return-route exploration stays reachable | none placed on the slides yet |
| 15 Frontier sets inert once open | all 3 sets (D86) |
| 16 At most 200; piles mostly still | exactly 200; the big piles sit in basket pits |
| 17 No sleepers on the loop | every sleeper sits on a ledge, bump, shelf or platform |
| 18 First sleeper close | 1.1, about a quarter of a screen away (0.27) |
| 19 Framing zones | see "Framing zones" |
| 20 No changes after release | not applicable: never released. The `old-version` fixture exercises migrations. |
| 21 Objects below the parent zone | the three switches sit on the loop, well below the parent zone at the rails' framing (D111); a level-rule test checks it (chunk 23) |
| 22 Where slimes come home; no low overhang on the loop | 1.1 as built (D116): the slides' tail runs under the terrace and up the ramp into the pocket behind the loop's start, so slimes coming home join behind the train; the first sleeper's ledge overhangs the terrace only inside the split zone's reach, where only base slimes pass (D117) |

## What this level does not settle

- **O22:** how the real level brings slimes back to the start. The slides are
  a stand-in. What the test level taught about it (where a return route
  meets the loop's start) is now level rule 22 (D117, D123).
- **The real first level:** its size (4 sections, 6 species), pacing, theme
  and tuning. The test level is deliberately compact, and has 3 sections and 5
  species.
- **O62:** the basket outlet is assumed, pending the basket's own design.
