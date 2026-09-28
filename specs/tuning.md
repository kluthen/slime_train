# Tuning values

Status: live

Every number the spec leaves to prototypes and playtests, with the starting
value to try. When a value is tuned, update it here and log the result in
`decisions.md`.

| Value | Start at | Source |
|---|---|---|
| Fusion contact time | 3 s (a hop resets it) | D37 |
| Unsure phase after a call | up to about 15 s | D27 |
| Left alone (off screen) | 10 s | D10 |
| Lost (left alone, not back) | 1 min | D10 |
| Idle camera takes over | 45 s with no input | D32 |
| Idle camera cue | starts 10 s before | D32, D62 |
| Screensaver and idle zoom | 10–20% wider than normal play; one zoom for both, no stacking | D60, D62, D80 |
| Minimum zoom inside framing zones | to find with the prototype | O65 |
| Wrong-code wait | 30 s after 5 wrong tries in a row | D83 |
| Code prompt and settings close by themselves | about 15 s with no input (settings: short, to try) | D83 |
| Delay before leaving a framing zone | a bit longer than a normal move | D61 |
| Camera drag toward a call: speed, and when it goes back | slow and steady; to try | D45 |
| Call radius | about half the screen width (proposed) | D46 |
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
