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
| Code prompt and settings close by themselves | about 15 s with no input (settings: short, to try) | D83 |
| Delay before leaving a framing zone | a bit longer than a normal move; built as holding an edge button 1.0 s (proposed; to try) | D61, O70 |
| Edge-button press | one fixed step, then a steady pace while held; values below (proposed; to try) | O70 |
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

The build picked these while making the chunks named. All are
**(proposed; to try)**: the user has not confirmed them yet. Pixels are
world pixels at zoom 1 on a 1152 px wide view unless noted. The code names in
capitals are the build's own, for finding them in `docs/dev/README.md`.

### Camera: rails, edge buttons, call drag (chunk 12)

| Value | Start at | Source |
|---|---|---|
| Edge-button step (`STEP`) | 384 px per press, a third of a screen | O70 |
| Pace while an edge button is held (`PACE`) | 864 px/s | O70 |
| Ease to a stop after release (`EASE`, `SETTLE`) | closes 5× the distance left per second, never slower than 30 px/s | O70 |
| Call drag and return to the rails (`DRAG_PACE`) | 230.4 px/s, shared by both | D45 |
| Return to the rails | once the 8 s answering window ends, glides to the nearest rail point at the drag pace | D45, D73 |
| Catching up with the rail (`CATCH_UP`) | 1152 px/s | D33 |
| Camera offset from the loop (`RAIL_OFFSET`) | (0, -120) px: the view shows more above the loop | D33 |

### Camera: framing zones and the idle camera (chunk 13)

| Value | Start at | Source |
|---|---|---|
| Holding an edge button to leave a framing zone (`EXIT_HOLD`) | 1.0 s; a zone's own `exit_hold` overrides it | D61, O70 |
| Easing into a framing zone (`FRAME_EASE`) | 1.5× the difference left per second, never slower than 30 px/s for the shift (`SETTLE`) or 0.02/s for the zoom (`ZOOM_SETTLE`) | D60 |
| Idle camera takes over (`IDLE_SECONDS`) | 45 s | D32 |
| Idle cue (`CUE_SECONDS`) | the last 10 s, a smoothstep zoom-out | D59, D62 |
| Idle and screensaver zoom (`IDLE_ZOOM`) | 1/1.15 (about 0.87); inside a zone already wider, see O79 | D60, D62, D80 |
| What counts as input for the idle clock | any touch; tilt doesn't count (O80) | D59 |
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
| Hop timer while gathering or holding | held at 0.25 s | D74 |

### Placeholders (ui_ux decides)

These stand in until `ui_ux/` designs them.

- **Edge buttons:** 96 × 192 screen px rectangles at mid-height on each side
  (whether they should be full-height edge strips is O81).
- **Top band** (the parent zone): 64 screen px.
- **An object's hit box:** its drawn box grown by 24 px.
