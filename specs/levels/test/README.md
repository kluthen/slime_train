# Test level

Status: draft v2

A compact level that puts nearly every v1 gameplay item in one place (D76).
It is the testing ground while the game is built, and the level the
automated end-to-end tests drive on the Linux build (see "Testability" in
`../../tech-direction.md`).

- It is **not** the real first level (`../01/`, designed later). Its layout,
  pacing and size teach us nothing about how the real level should feel.
- (proposed) It never ships in the release build. It uses placeholder art.
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
  surface and comes out in the start basin.
  - The slides are a **placeholder for testing only**. They do **not** settle
    how the real level brings slimes back to the start (O22).
- **Camera rails** follow the whole loop: the outgoing surface route and each
  slide, which has its own rail (D79). Which way the edge buttons move on a
  slide is O66.
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
- The **first sleeper** (B) sits about a third of a screen to the right, on
  a small ledge just above the loop (rules 17, 18). On the very first play,
  the wordless hint pulses next to it after about 10 s without a call (D65).

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
  path and comes out on the loop at about 11.8. (proposed) It takes a size-1
  slime about 30–40 s, which is longer than "left alone" (10 s) but well
  under "lost" (1 min).
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
- A framing zone shows the whole bowl, about 2 screens at normal zoom.
  (proposed) That means zooming out to about half.

**3.3 High rim (15–15.5).**
- A rim above the far wall holds 30 sleepers (A, B, C and D, 5 each, plus 10
  E). Only a size-3 jump from the far wall reaches it. Anything that falls off
  lands back in the bowl.

**3.4 Frontier set 3 (15.5–16.5).**
- The basket is a wide, flat-bottomed pit. Slimes resting in it don't hop, so
  a big pile sits still (rule 16).
- A framing zone shows the switch and the whole pit on one screen.
- Its target is the **level-complete celebration** instead of a gate. This
  is D77. (proposed) After the
  celebration, the basket releases its slimes into the section 3 slide, and
  the loop stays complete.

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

**When the basket fills:**
1. The reward animation plays. It waits until the basket is in view
   (proposed, D70).
2. The basket fires. The gate opens, and the loop grows into the next section
   (D9).
3. As part of the reward, the old slide entrance closes. Only the route back
   to the start is replaced: the next section's slide takes over.
4. The basket releases its slimes.
5. The switch and basket become inert for good (D86).

**Opting out (D70):** flipping the switch back before the basket is full stops
the filling. (proposed) The slimes inside go back to the loop.

**Outlet (proposed; the basket's own design, O62):** each basket has one outlet that drops slimes onto the
onward path just before the slide entrance. While the gate is closed, the
path leads into the slide. Once the gate is open, it leads through the gate.
Releasing after firing and emptying after an opt-out both use the same
outlet.

**Weight:** the outlines fill by weight. A size-3 slime fills 3 at once.

## Framing zones

| ID | Screens | Shows | Tests |
|---|---|---|---|
| `s1.frame.high-step` | 3.5–4.5 | the loop and the ledge | framing beside the loop |
| `s1.frame.tree` | 4.5–5.5 | the loop and the tree's lower platform | zoom out and shift up; the exit delay |
| `s2.frame.parade` | 9–10 | the parade, slightly wider | combining with the idle and screensaver zoom-out |
| `s2.frame.gate` | 12.2–13 | gate 2, the slide entrance and the basket pit | reward waiting for view |
| `s3.frame.bowl` | 13.5–15.5 | the whole bowl | a strong zoom-out; stress |
| `s3.frame.basket` | 15.3–16.5 | switch 3 and the basket pit | a big still pile |

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
| **S3** | **20** | **20** | **20** | **20** | **40** | **130** |
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
  - Numbered items use two digits and count left to right.
- **Examples:**
  - `start.split-zone`, `start.first-slime`
  - `s1.sleeper.01` … `s1.sleeper.29`
  - `s1.switch`, `s1.basket`, `s1.gate`, `s1.slide`
  - `s1.branch.tree`, `s1.route-back.tree`, `s1.frame.tree`
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
| Train with no slots; a lone slime keeps going | the whole loop |
| Signpost at every fork; the rails follow the main stream | each frontier switch |
| Frontier set: switch, basket, gate, the loop growing, the slide replaced | 1.6, 2.5 |
| Basket filling off screen; reward waiting for view | 2.5 |
| Opting out by flipping the switch back | 1.6, 2.5 |
| Off screen: projected train, projected route back, respawn on approach | the slides, 2.4, 2.5 |
| Left alone (10 s) and rejoining | 2.4 |
| Lost (1 min), teleported to the start | fixture only (see below) |
| Framing zones and their exit delay | 1.4, 1.5, 2.2, 2.5, 3.2, 3.4 |
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

## Test fixtures (proposed)

Named save states that tests load through test mode (tech-direction).

| Fixture | State | For |
|---|---|---|
| `fresh` | no save; first launch | the first slime, the hint, and the start of setup |
| `s1-basket-5of6` | switch 1 flipped, basket 1 at weight 5, a slime on its way | the reward, firing, gate 1 opening, and slide 1 closing |
| `s1-optout` | basket 1 at weight 3 | flipping back and emptying through the outlet |
| `gate1-open` | S2 reachable, 20 slimes awake, slide 1 closed | starting from S2 |
| `s2-basket-offscreen` | camera at switch 2, basket 2 at 14, slimes heading into it | filling off screen, then the reward on approach |
| `s2-cave-return` | 3 free slimes starting down the cave's route back, camera away | projection, respawn, left alone and rejoining |
| `bump` | size-2 and size-3 slimes of one species meeting in a dip | 2 + 2 and 3 + 1 bumping |
| `stress-still` | 200 awake base slimes, 60 in basket 3 and the rest piled in the bowl | the worst still case on one screen (O14, O57) |
| `stress-moving` | 200 train slimes spread through the bowl | the worst moving case; beyond what normal play produces |
| `lost` | a free slime placed off screen, outside any area's route back | left alone at 10 s, then lost at 1 min and teleported to the start |
| `midair` | a save taken with slimes in mid-air | placement on reload (D12) |
| `old-version` | a save from an earlier test-level version with a moved sleeper | migration: the displaced slime counts as lost (D72) |
| `wind-down` | session at 14:50 | dusk and the slower hops, then bedtime |
| `bedtime` | bedtime just reached | the cooldown and the parent code ending it |
| `sunrise` | cooldown at 9:55 | sunrise, then screensaver mode, then the first tap |

**Lost** has its own fixture because the level itself can't produce it: every
spot a free slime can reach leads back to the loop (rule 7).

**Repeatability:** all gameplay randomness comes from the seeded generator
(tech-direction), and each test sets its seed.

## Rules checklist (`../../level-design.md`)

| Rule | How this level meets it |
|---|---|
| 1 Travelled with no input | the loop and slides need no input; the frontier switches default to onward |
| 2 Any size | no filters in v1: every size takes the same loop; the bowl walls are hoppable at size 1 |
| 3 No dead ends | the tree and cave branches rejoin through their routes back; every slide returns to the start |
| 4 Split zone at the start | 1.1 |
| 5 Fusion dips | 1.3, 2.3 |
| 6 Signpost at every fork | each frontier switch (the only forks in v1) |
| 7 Gravity leads back | bumps and shelves slope toward the loop; the bough and the rim drop onto a platform or into the bowl |
| 8 Route back per branch | the tree: far slope; the cave: tunnel; the bowl shelves and rim: falling into the bowl |
| 9 Hints visible | sleepers peek into the view at every branch; framing zones at the tree |
| 10 Tilt is a bonus | tilt only helps at 1.5; nothing needs it |
| 11 Species per section | S1: A, B, C; S2 adds D; S3 adds E |
| 12 Switch-plus-basket | all 3 frontier sets |
| 13 Return route to the start per section | slides 1, 2 and 3, each with its own rail (a placeholder; O22) |
| 14 Return-route exploration stays reachable | none placed on the slides yet |
| 15 Frontier sets inert once open | all 3 sets (D86) |
| 16 At most 200; piles mostly still | exactly 200; the big piles sit in basket pits |
| 17 No sleepers on the loop | every sleeper sits on a ledge, bump, shelf or platform |
| 18 First sleeper close | 1.1, a third of a screen away |
| 19 Framing zones | see "Framing zones" |
| 20 No changes after release | not applicable: never released. The `old-version` fixture exercises migrations. |

## What this level does not settle

- **O22:** how the real level brings slimes back to the start. The slides are
  a stand-in.
- **The real first level:** its size (4 sections, 6 species), pacing, theme
  and tuning. The test level is deliberately compact, and has 3 sections and 5
  species.
- **O66:** which way the edge buttons move the camera on a slide.
- **O62:** the basket outlet is assumed, pending the basket's own design.
