# Tuning values

Status: live

Every number the spec leaves to prototypes and playtests, with the starting
value to try. When a value is tuned, update it here and log the result in
`decisions.md`.

| Value | Start at | Source |
|---|---|---|
| Fusion contact time | 3 s (a hop resets it); built as 180 ticks at 60 Hz | D37 |
| Unsure phase after a call | up to about 15 s | D27 |
| Left alone (off screen) | 10 s | D10 |
| Lost (left alone, not back) | 1 min | D10 |
| Idle camera takes over | 45 s with no input | D32 |
| Idle camera cue | starts 10 s before (a smoothstep zoom-out) | D32, D62 |
| Screensaver and idle zoom | 10–20% wider than normal play; one zoom for both, no stacking; built as zoom 1/1.15 (proposed; to try) | D60, D62, D80 |
| Minimum zoom inside framing zones | to find with the prototype; measured slime sizes in O65 | O65 |
| Wrong-code wait | 30 s after 5 wrong tries in a row | D83 |
| Code prompt closes by itself | about 15 s with no input | D83 |
| Settings close by themselves | 30 s with no input, a warning over the last 10 s; any touch resets it; the screens opened from settings too | D113 |
| Parent buttons hide | after 5 s with no press; a new tap on the parent zone restarts it | D113 |
| Hit area of an interactive object | the drawing plus 5 mm on every side, at least 20 × 20 mm, on the screen at the current zoom; a smaller one grows about the object's centre (proposed) | D109, D126 |
| A tap on a sleeper | within 24 screen px of its drawing (proposed; to try) | D126 |
| Parent-facing targets | at least 9 × 9 mm on the screen, at least 2 mm apart | D109, ux D3 |
| The parent zone | a band 7 mm high on the screen, full width, unmarked | D113, ux D4 |
| A thumb resting on an edge strip | after about 5 s held, it stops blocking other touches (to check in a playtest) | D110 |
| Delay before leaving a framing zone | a bit longer than a normal move; built as holding an edge button 1.0 s (to try) | D61, D102 |
| Edge-button press | one fixed step, then a steady pace while held; values below (to try) | D102 |
| Camera drag toward a call: speed, and when it goes back | slow and steady; built as 230.4 px/s, back to the rails when the 8 s answering window ends (proposed; to try) | D45 |
| Call radius | about half the screen width | D46 |
| Call cap (a slime that can't reach the point gives up) | about 8 s | D73 |
| Train slime hop interval | ~1.5–3 s, random per slime | D74 |
| Hop rate when answering a call | a bit faster than on the train | D74 |
| Size effect on hops | bigger: a little less often, further and higher | D24, D74 |
| Wind-down hop slowdown | slower in the last minute | D28, D74 |
| Tilt | ±45° cap, about 10° dead zone | D19 |
| Session length | 15 min (fixed in v1) | D29 |
| Cooldown after bedtime | 10 min | D29, D44 |
| Bedtime wind-down | the last minute | D28 |
| Autosave interval | 15 s | D12 |
| First-play hint appears after | about 10 s without a call | D65 |
| Calls at the same time | 1: the first touch wins; try 2 later | D66 |

## Values the build chose

The build picked these while making the chunks named. They are starting
values, **to try**. The user approved the values of chunks 15 and 16 (D108,
and the rows added later with D116, D118 and D119 in D120)
and chunk 23 (D99–D101, and those its build chose in 23A–23D, D124,
approved in D125); the values of chunks 10, 12, 13, 14 and 17 are still
**(proposed; to try)**: the user hasn't confirmed them one by one. Pixels are
world pixels at zoom 1 on a 1152 px wide view unless noted. The code names in
capitals are the build's own, for finding them in `docs/dev/README.md`.

### Camera: rails, edge buttons, call drag (chunk 12)

| Value | Start at | Source |
|---|---|---|
| Edge-button step (`STEP`) | 384 px per press, a third of a screen | D102 |
| Pace while an edge button is held (`PACE`) | 864 px/s | D102 |
| Ease to a stop after release (`EASE`, `SETTLE`) | closes 5× the distance left per second, never slower than 30 px/s | D102 |
| Call drag and return to the rails (`DRAG_PACE`) | 230.4 px/s, shared by both | D45 |
| Return to the rails | once the 8 s answering window ends, glides to the nearest rail point at the drag pace | D45, D73 |
| Catching up with the rail (`CATCH_UP`) | 1152 px/s | D33 |
| Camera offset from the loop (`RAIL_OFFSET`) | (0, -120) px: the view shows more above the loop | D33 |

### Camera: framing zones and the idle camera (chunk 13)

| Value | Start at | Source |
|---|---|---|
| Holding an edge button to leave a framing zone (`EXIT_HOLD`) | 1.0 s; a zone's own `exit_hold` overrides it | D61, D102 |
| Easing into a framing zone (`FRAME_EASE`) | 1.5× the difference left per second, never slower than 30 px/s for the shift (`SETTLE`) or 0.02/s for the zoom (`ZOOM_SETTLE`) | D60 |
| Idle camera takes over (`IDLE_SECONDS`) | 45 s | D32 |
| Idle cue (`CUE_SECONDS`) | the last 10 s, a smoothstep zoom-out | D59, D62 |
| Idle and screensaver zoom (`IDLE_ZOOM`) | 1/1.15 (about 0.87); never zooms in: inside a zone already wider, it keeps the zone's zoom (D103) | D60, D62, D80 |
| What counts as input for the idle clock | any touch; tilt doesn't count | D59, D103 |
| Idle camera following a slime (`FOLLOW_EASE`, `FOLLOW_PACE`) | eases at 2.0× the distance left per second, at most 576 px/s | D59 |
| Test level, `s1.frame.high-step` | zoom 0.85, offset (0, -120) px | test level |
| Test level, `s1.frame.tree` | zoom 0.7, offset (0, -250) px | test level |

### Fusion and bumping (chunk 10)

| Value | Start at | Source |
|---|---|---|
| Contact before fusion (`CONTACT_TICKS`) | 180 ticks (3 s at 60 Hz) | D37 |
| Bump push | 240 px/s, shared between the two slimes by size, plus a 200 px/s lift | D49 |
| On screen for fusion (`VIEW_MARGIN`) | a slime's centre at least 24 px inside the view's edge (a base slime's radius, so its whole body shows) | D70 |
| Dip floor (where the loop nudges slimes together) | a rise of at least 100 px on both sides, and the floor within 30 px of the bottom | D20 |
| Gathering window on a dip floor | 300 px behind | D20 |
| Waiting for a partner on a dip floor (`Fusion.DIP_WAIT_SECONDS`; chunk 16f) | a train slime on a dip floor waits without limit only for a partner directly behind it (no other train slime between them); for a partner further back, at most 5 s | D20, D119 |
| Hop timer while gathering or holding | held at 0.25 s | D74 |

### Frontier sets, gates and completion (chunk 14)

| Value | Start at | Source |
|---|---|---|
| A full basket's reward before it fires (`REWARD_SECONDS`) | 2.0 s, counted once the basket is in view (settled by ux D4) | D70, D91, ux D4 |
| Release pace (`RELEASE_SECONDS`) | one released slime every 0.3 s, lowest id first, and only when the outlet is clear | D91, O62 |
| Outlet clear (`OUTLET_CLEARANCE`) | no slime closer than the two radii plus 8 px | O62 |
| Door clearance (`DOOR_CLEARANCE`) | 3 px (`SlimeBodies.EDGE`): a trapdoor, gate box or lid shuts only once no slime is in its way | D14 |
| Celebration (`CELEBRATION_SECONDS`) | 4.0 s (settled by ux D4) | D77, ux D4 |
| Default outlet (`outlet_before`, a basket property) | on the onward route, 200 px along the loop before the start of the return route its gate retires (Known gap 3); a basket may name an `outlet_point` instead | O62 |
| Test level, basket 1 quota | 6 (weight) | test level |
| Quota pies (proposed) | above a quota of 10: one pie per 10 of weight, the last holding the rest; the row within the basket's width, each pie at least 6 mm across on the reference phone's screen at the basket's framing zoom | D128, item 24.2 |
| A fired basket empties within (proposed) | its quota × 0.3 s plus 10 s of firing, none of its slimes falling back in | D128, item 24.3 |
| Section 3 frame budget on the desktop (proposed) | a steady 60 fps at test mode's 1152 × 648 window; at most 8 ms per tick at p95 on the section 3 bench cases, `stress-moving` excepted | D128, item 24.1 |

### Off screen, resting piles and detail (chunk 15; crowd detail, D140, D141; clusters, D143, D145)

| Value | Start at | Source |
|---|---|---|
| Parked (not simulated) beyond (`PARK_MARGIN`) | a slime whose centre is more than 384 px (a third of a screen) outside the view | D69 |
| Simulated again within (`NEAR_MARGIN`) | 288 px (a quarter of a screen) outside the view; between the two margins a slime keeps what it was | D69 |
| Off-screen pace | a hop's reach per mean hop interval: about 67 px/s for a size-1 slime (about 64 px/s on screen); an ideal pace, with no stalls | D69 |
| A free slime's route back is near (`ROUTE_NEAR`) | within 288 px; off screen it joins its branch's route back single file, a slime's width behind the one before it; out of any branch, it heads straight for the nearest loop point within that distance; with neither near, it stays put until the lost timer moves it (see §5.3 of the master spec) | D70 |
| Left alone (`LEFT_ALONE_TICKS`) | 600 ticks (10 s) outside the view, the screen with no margin; the count stops on screen | D10 |
| Lost (`LOST_TICKS`) | 3600 ticks (1 min) after left alone, so 70 s off screen in all | D10 |
| A train slime stalls (`Train.LOST_STALL_SECONDS`, `LOST_STALL_ADVANCE`, `BOUNDS_MARGIN`, `BOUNDS_TOP_MARGIN`; chunk 6's placeholder) | its progress along the loop hasn't advanced 24 px in 60 s, on screen or off; or its centre is out of the level's bounds (the terrain and the loop, plus 64 px, plus 2000 px above); it is then moved to the loop start (D121). To recheck on the first level, once real return routes exist. *From chunk 22h (D150, the user's):* the 60 s count only the ticks it is simulated; while parked its clock is paused, and resumes where it was (O113: every parked train slime, proposed) | D118, D121, D150 |
| Dropping into a basket off screen (`ENTRY_REACH`, `SLOT_GAP`) | a parked train slime whose centre is within 64 px above an open trapdoor drops in, into the first clear slot of a grid its own width plus 4 px apart, bottom row first | D70 |
| A slime is still (`REST_DRIFT`, `REST_TICKS`) | supported and within 1 px of its anchor for 30 ticks; the anchor is where the count started; kept for v1; measured in chunk 22 (open piles of 40 or more rest in minutes or never), revisiting it is O105 | D96, D107, D138 |
| A pile rests | when every slime of a touching group of pile slimes (in a basket, or asleep at bedtime) is still at once; awake slimes out of a basket hop and never rest, except *(proposed, D145)* a holding train slime | D96, D145 |
| A resting pile wakes (`WAKE_SPEED`) | a touching slime faster than 30 px/s (a hop, a landing, a neighbour moving), a state change (bedtime, sunrise, a basket catching or releasing), a slime removed, fused or split next to it; a call wakes the resting slimes within its radius, a tilt change wakes them all *Proposed (D143, D145, chunk 22e, D146, O106):* a release, the end of a hold and a touch faster than 30 px/s wake only the slimes they touch, not the whole pile; fallback if it churns: those slimes' touching neighbours too. *Built in chunk 22e (4750f12):* the local wake as written, a LoopStart move waking locally too; the fallback not built (basket 3's drain: 0 whole-pile wakes, at most 9 woken in a tick) | D96, D143, D145, D146 |
| A door wakes nearby piles (`DOOR_WAKE_REACH`) | a trapdoor, gate or lid opening or shutting wakes the piles within 80 px of it | D96 |
| Ring points per detail level (`POINTS_BY_DETAIL`) (proposed) | levels 0 (full) to 3: size 1 12, 10, 8, 6; size 2 15, 12, 10, 8; size 3 18, 15, 12, 9 | D94, D140 |
| Zoomed-out detail (`LOW_ZOOM`, `FULL_ZOOM`, `LOW_DETAIL`) | below zoom 0.8, at least level 2 (8, 10 and 12 points for sizes 1, 2 and 3); back from 0.85 | D94, D96, D140 |
| Crowd detail (`CROWD_STEPS`, `CROWD_EASE`) (proposed) | the crowd is the ACTIVE non-sleeper slimes after the parking; level 1 from 20, 2 from 30, 3 from 40; down only 5 below each step (15, 25, 35); the level used is the higher of the zoom's and the lower of the crowd's and the detail ceiling (D141); only ACTIVE rings are reshaped | D140, D141 |
| Crowd detail mode (`--crowd-detail`) (proposed) | `auto` (the load meter moves the ceiling) in normal play, and always in a release build; `always` (ceiling 3, D140's behaviour) is the simulation's default: test mode, fixtures, scripts, the bench, the tests; `off` (ceiling 0) | D141 |
| Load meter window (proposed) | about 1 s of real time; dropped if it holds a frame over 250 ms, or at a debug speed other than 1x | D141 |
| Load meter: pressed (proposed) | busy share (the ticks plus the rest of `_process`, over the window's real time) above 85 %, or 3 or more frames at 1x that ran 2 ticks | D141 |
| Load meter: calm (proposed) | busy share below 60 % and at most 1 frame that ran 2 ticks | D141 |
| Detail ceiling steps (proposed) | starts at 0; up one step per pressed window (at most 3); down one step after 3 calm windows in a row (the count starts again after each step); held, and the calm count restarted, by a window in the band | D141 |
| Pile detail cap (`PILE_MAX_DETAIL`) (proposed) | pile slimes (in a basket, asleep at bedtime) stop at level 2 (at 6 points the `stress-still` pile rested at about tick 1300 instead of 407) | D140 |
| Largest awake cluster, level rule 23 (the rule approved in direction, D144; the limit proposed, calibrated in chunk 24 from 22d's and 22e's logs, D146, O107) | above 20 slimes for more than 5 s in a row fails, over a level's played test and each basket's fire-and-drain (`stress-*` excepted); touching: in contact on the last tick, or centres within the sum of their radii plus 2 px | D143, item 24.7 |
| The hold: the crowd check (replaces D143's lean, approved in direction, D144; D145, proposed; built and first calibrated in chunk 22e, D146, O107) | when its hop is due, a train slime holds while more than 30 slimes that cost physics, out of a basket (calm ACTIVE, not sleepers, not itself; any species), have their centres within 240 px of its hop's target and ahead of it (on the target's side of its own centre). *Built in chunk 22e (4750f12); its first calibration kept 30 and 240 px (a sweep of 15, 20, 30 and 160, 240 px). Replaced by D147's hop corridor in chunk 22f* | D143, D145, D146, chunk 22e |
| The hold: the jam check (D145, proposed, O107) | it also holds while its hop's target, measured along the loop, would come within the two slimes' radii plus 24 px of the rearmost holding train slime ahead of it (a jam: one holding slime is enough); it holds where it stands, no shorter hop. *Built in chunk 22e (4750f12); the first calibration kept 24 px (48 changed almost nothing). Replaced by D147's holder rule in chunk 22f (proposed)* | D145, D146, chunk 22e |
| The hold: re-check and cap (D145, proposed, O107) | checks again every 0.5 s (30 ticks) from the hold's start, no random draw; hops anyway after 5 s (300 ticks) of holding; may hold again at its next hop. *Built in chunk 22e (4750f12): 86 % of hold ends came at the cap. Replaced by D147 in chunk 22f, the next row* | D145, D146, chunk 22e |
| The hold, second round: the hop corridor (D147, the user's shape; numbers proposed, O107) | replaces the crowd check's 240 px disc and its 30: a box from the slime's centre to its landing point plus 100 px, 75 px either side, the slime left out; every slime whose centre is in it counts (resting and holding too; not parked, in a basket or sleepers); an occupancy (summed π · radius² over the box's area) above 0.5 fails it. Alternative: a size-scaled count (about 6 base slimes). The user's fallback: HOLD_CROWD 15 on the disc | D147, chunk 22f |
| The hold, second round: the holder rule (D147, the user's; replacing the jam check, proposed) | a holder anywhere in the hop corridor (the 100 px past the landing point included) makes the slime hold, whatever the occupancy; a train slime resting by contact counts as a holder | D147, chunk 22f |
| The hold, second round: the stack zone (D147, the user's "guard zone"; shape proposed, O107) | a holder directly or almost directly above or below the hopper doesn't trigger the holder rule: its centre projects onto the hop line, from the hopper's centre, less than the two radii (`radius_of`) apart. Alternative: within ±30° of the vertical through the hopper. It still counts toward the occupancy. A slime touching a holder in its stack zone may rest by contact | D147, chunk 22f |
| The hold, second round: periods and re-checks (D147; the extra and the phase proposed, O107, O109) | a period of 5 s (300 ticks) plus 0 to 60 extra ticks; at its end the checks run again and, still blocked, a new period begins: no hop through a crowd (nor, proposed, for a holder-only hold). Re-checks every 30 ticks, the first after 30 plus a 0 to 29 tick phase drawn per hold. Draws from streams derived from the seed, the slime's id and the period's start tick | D147, chunk 22f |
| The hold guard (D147, proposed) | when no simulated train slime has hopped for 4 s (240 ticks) while one holds (read as: every one holding, resting or `held`, and the latest hold 4 s old), the front-most holder (the longest gap along the loop to the next train slime ahead; tie to the lower id) hops | D147, chunk 22f |
| A holding train slime rests (D145, proposed) | under the pile rule (`REST_DRIFT`, `REST_TICKS`), alone or with the holding slimes it touches; not while a contact of it counts toward fusion; wakes when its hold ends or when disturbed. *D147 (proposed, chunk 22f):* only on the ground (touching terrain facing up, or standing on a resting slime); a train slime touching a holder ahead of it along the loop may rest too (D143's touching), and wakes when that contact moves off fast or it touches no holder ahead; a slime waking wakes those resting on it | D145, D146, D147, chunk 22e, chunk 22f |
| Test level, basket 2 quota | 15 (weight) | test level |

### Performance (chunks 22, 22b)

| Value | Start at | Source |
|---|---|---|
| Ticks per frame at most (`MAX_TICKS_PER_FRAME`) (proposed) | 2 at 1x speed (was 8); times the debug speed, rounded up; beyond it the game plays in slow motion | D138 |
| Frame budget on the reference phone (proposed) | per 16.7 ms frame: simulation at most 8 ms, drawing at most 4 ms, at least 4.7 ms left for later animation, music and the system | D138 |
| Phone estimate from the desktop | a part's full-speed desktop cost × 2.1 cold, × 3.4 throttled (the GDScript tick's factors); a slowed desktop run pins the main thread only (`tools/perf_slow.sh --pin=main`); the phone's perf log settles every number | D96, D142, D144 |
| Debug slime labels' text refresh (`TEXT_REFRESH_MS`) | at most every 250 ms; positions every frame (debug builds only) | D142, D144, item 24.6 |

### Test level sections 2 and 3 (chunks 15, 16)

| Value | Start at | Source |
|---|---|---|
| `s2.frame.parade` | zoom 0.85, offset (0, -100) px | test level |
| `s2.frame.cave` (added in chunk 16d) | centred at 11.25 screens, y -150; 1.3 screens by 500 px; zoom 0.7, offset (0, -140) px: on the rails from 10.6 to 11.9 the view spans y -767 to 159 | test level, D116 |
| `s2.frame.gate` | zoom 0.9, offset (0, -40) px | test level |
| `s3.frame.bowl` | zoom 0.5, offset (0, -200) px | test level |
| `s3.frame.basket` | zoom 0.8, offset (0, 40) px | test level |
| Basket 3 quota | 60 (weight) | test level |
| Basket 3 outlet | a point 200 px before slide 3's entrance (no gate, so no default outlet) | O62 |

### Small issues from play (chunk 23)

The user's reports of 2026-09-29, all decided (D99, D100, D101).

| Value | Start at | Source |
|---|---|---|
| Call camera dead zone | a box centred on the screen, 20% of its width by 20% of its height, measured on the screen; a call point inside it doesn't move the camera, and stops a drag where it is | D101 |
| Edge-button strips | 10% of the screen's width from the left and right edges, the whole height below the parent zone's top band | D99 |
| Stuck-slime check | every 30 ticks (0.5 s) | D100 |
| Stuck: overlapping | centres closer than a quarter of the smaller slime's radius | D100 |
| Stuck: how long | 4 checks in a row (about 2 s); built as a move at the fourth check, 1.5 s after the first (checks at 0, 30, 60, 90 ticks) (to try) | D100, D124 |

### Chunk 23 as built (23A–23D)

All **to try**: recorded in D124, approved in D125.

| Value | Start at | Source |
|---|---|---|
| Landing at the start of the loop (lost, stuck or stalled move) | the first free spot of 8, one slime width apart. *Replaced in chunk 22h (D150):* see the loop-start queue below | D124, D126, D150 |
| Stuck and stalled logs | keep the last 64 cases each | D124 |
| Millimetres on the desktop and in tests | converted at the reference phone's density; a phone reporting a density of 0 or less logs an error and uses the reference density too | D124 |
| A resting thumb (about 5 s) | 300 ticks | D110, D124 |
| Showing a gate open: the glide | a straight line at an even pace, 1.5 s, to the rail point nearest the gate's centre | D124 |
| Celebration double hop (`CelebrationHops`: `HOPS`, `HOP_STRENGTH`) | 2 hops at 0.6 of a normal hop's strength (about 50 px high, about 0.5 s each) | ux D4, D124 |

### The loop-start queue (D150, chunk 22h)

The user's: one move to the loop start at a time, 0.5 to 2 s apart, to a
random spot. The rest **proposed**.

| Value | Start at | Source |
|---|---|---|
| Wait after a move to the loop start | 30 to 120 ticks (0.5 to 2 s, the user's), uniform, both ends included; the first draw of the derived stream `loop_start:gap:<move tick>` | D150 |
| Queue order | out of bounds first; then first due, first moved; ties by ascending id (proposed) | D150 |
| Landing stretch | a distance along the loop drawn uniformly in 0 to 240 px from its start, the centre lifted by the slime's size; inside a split zone (proposed) | D150 |
| Landing draws per turn | 8, from `loop_start:spot:<tick>`; the first free one (no ring overlapping, parked ones included) is used (proposed) | D150 |
| No free spot | nobody moves; the head tries again on the next tick that is a multiple of 30 (0.5 s) (proposed) | D150 |

### Session, wind-down, bedtime and sunrise (chunk 17)

| Value | Start at | Source |
|---|---|---|
| Session (`BEDTIME_MS`) | 900 s (15 min) from the session start | D29 |
| Wind-down (`WIND_DOWN_MS`) | the last 60 s: from 840 s to 900 s | D28 |
| Cooldown, then sunrise (`SUNRISE_MS`) | 600 s (10 min): sunrise at 1 500 s from the session start | D29, D44 |
| Wind-down hop slowdown (`WIND_DOWN_HOP_RATE`) | hop timers slow linearly from 1× to 0.5× over the wind-down | D28, D74 |
| Dusk tint | ramps 0 to 1 over the wind-down, holds through bedtime, fades back to 0 at sunrise | D28 |
| Sunrise fade (`SUNRISE_SECONDS`) | 3 s (settled by ux D5) | D44, ux D5 |
| Late sunrise shows no cue (`SUNRISE_CUE_LATE_MS`) | a sunrise more than 1 s late (the cooldown ran out while the app was closed) plays no cue | D102 |
| Waking at sunrise (`FreeSlimes.REJOIN_DISTANCE`) | a bedtime-asleep slime within 40 px of the loop (plus its extra radius) becomes a train slime; any other becomes free and heads back | D44 |

**The clock rule (chunk 17).** Within one run of the app, the time elapsed is
the larger of the monotonic clock's and the wall clock's progress since the
anchor (where counting last started over). After a restart (the app killed or
the phone restarted), only the wall clock's gap counts, and never a negative
one. Elapsed time never decreases. Moving the wall clock forward while the
app is closed shortens the cooldown; there is no way around it, since the
monotonic clock doesn't survive a restart (accepted in master spec §5.7).

### Placeholders (ui_ux decides)

These stand in until `ui_ux/` designs them.

- **Edge buttons:** built (chunk 23B) as strips 10% of the screen's width
  from each edge, over the whole height below a 7 mm parent zone (D99).
  How they are drawn stays with `ui_ux/`: the placeholder is an arrow 45%
  by 80% of the strip's width (D124).
- **The parent zone:** built (chunk 23B) as a band 7 mm high on the screen
  (ux D4, D113).
- **An object's hit box:** built (chunk 23E) as the drawing plus 5 mm,
  at least 20 × 20 mm on the screen, the floor grown about the centre
  (D109; the centring proposed, D126). A sleeper keeps a 24 screen-px
  margin (proposed, D126).
- **Dusk colour** (`DUSK_COLOUR`): the tint at full dusk, RGB (0.55, 0.52,
  0.78), over the world only (the parent band and buttons aren't tinted).
- **Frontier art:** the shut trapdoors, closed gate boxes and shut lids as
  plain blocks; arrows on the switch and signpost; the basket's quota as
  slime outlines, pulsing during the reward; rings for the celebration.
- **The celebration's lasting mark** (chunk 23D): bunting at the start of
  the loop, 90 px half-width, 150 px high, a 20 px sag, 6 pennants
  26 px deep (`MARK_HALF_WIDTH`, `MARK_HEIGHT`, `MARK_SAG`,
  `MARK_PENNANTS`, `MARK_PENNANT_DROP`). Its real look is ux-writer's
  (ux D4, D124).
- **Slimes asleep in a basket** (chunk 23D): no asleep look exists yet; at
  bedtime they show only the dusk tint, like the rest of the world. "Shown
  asleep" (D105) waits for `ui_ux/`.
