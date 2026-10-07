# Slimes

Status: draft v26 (the geyser after v1, D161, the user's; the hold on a climb and the relay stay in v1, chunk 24g, the train's climb, proposed; v25: the geyser a level object, the user's, D160; the train's jam is the climb: the hold on a climb and the relay, proposed; the dip nudge unchanged, D159 (5) withdrawn, V1s the user's call, O121; earlier, v24: the cause of stuck slimes found and fixed, the net kept as a backstop, D159 (1); the geyser at the loop's start and the dip nudge's jam, D159, proposed; earlier, v23: every wake local: a fusion, a split, a slime taken out of the level, a call, a trapdoor, gate or lid opening or shutting, and a tilt change too, D156 (7); earlier, v22: moves to the loop start one at a time, 0.5 to 2 s apart, to a random free spot, and no stall clock while parked, chunk 22h, D150, the user's, details proposed; the local wake, chunk 22l, D156; the fps session after 0196c25 withdrawn, D155: the lean stays as approved in direction, unbuilt; the train leans away from clusters, D143, approved in direction, D144; its numbers proposed, O107)

## States

| State | Meaning |
|---|---|
| sleeper | asleep, not moving. Wakes **only** when a free slime touches it, on screen (D13, D70). Never on the loop. The game wakes the very first slime. |
| train slime | awake and following the loop (D8, D11). Ignores tilt (D19). |
| bedtime-asleep | asleep because the session ended (D28). The game wakes it at sunrise (D44): near the loop it is a train slime again, anywhere else a free slime heading back (the distance is in `tuning.md`). Not a sleeper. |
| free slime | awake and away from the loop after answering a call. Physics always applies and it feels tilt (D8, D19). Can become left alone or lost (D10). Goes through the phases below. |
| in a basket (D106) | caught by a basket's box (built as `in_basket`, chunk 14). Doesn't hop, isn't the train and doesn't answer calls, in any basket, filling or full; it falls and settles in the pile. Leaves only when the basket releases it, and rides the train again. At bedtime it sleeps in place, and sunrise doesn't move it out (D105). |

## Free slime phases (D27)

1. **Answering the call:** hops toward the call point, until it reaches it or
   for about 8 s at most. A new tap replaces the call point (D73). Slimes
   gather in a clump there, which is how fusion usually starts.
2. **Unsure:** after the call ends, for up to about 15 s (to be tuned). It stays
   put or hops around, without straying far from the last call point.
3. **Heading back:** makes for the loop, hopping mostly downhill but knowing
   the shortest way, using the route back that every exploration branch has
   (D41, D51). It rejoins the train when it
   reaches the loop.

Physics applies in every phase. On a steep slope its hopping can't hold it,
and it may roll downhill. Phase names were adopted in D75.

## Off screen (D69, D70)

- Physics runs only for slimes on or near the screen. Off screen, a train slime
  follows the loop at a deterministic pace, and a free slime follows its area's
  route back (if there is none, it is lost). Out of any branch (D108), it heads straight for the loop when the loop is
  near; with neither near, it stays put until the lost timer (D10) moves it
  to the start of the loop.
- Fusion and waking happen only on screen.
- **Resting piles** (D96): a still, touching group of pile slimes (in a
  basket, or asleep at bedtime) rests and costs no physics until
  disturbed. *The local wake (D156, chunk 22l):* every wake is local. A
  release, a touch faster than 30 px/s, a move to the loop start, a
  fusion, a split, a slime taken out of the level, a call, a trapdoor,
  gate or lid opening or shutting, and a tilt change wake only the
  resting slimes they reach (a state change, only the slime itself), not
  the whole pile. It never wakes a sleeper.

## Stuck slimes (D100)

- Slimes of different species have been seen stuck inside one another
  (the user's report, 2026-09-29). It isn't fusion: only the same species
  fuse.
- *The cause, fixed (D159 (1), O91 closed):* two rings deeper than a radius
  in each other were drawn together by the contacts until their centres
  met; a contact point past the other's centre is now pushed back to its
  own side.
- Kept as a backstop since that fix, a safety net: the simulation checks every 0.5 s for two
  simulated slimes that can't fuse whose centres are closer than a quarter
  of the smaller one's radius. Found so 4 times in a row (about 2 s), the
  smaller one is moved to the start of the loop and rides the train again
  (on a tie, the one with the higher id). Only a train or free slime is
  moved, never a sleeper, a slime in a basket or a bedtime-asleep one.
- **Stuck** is its own state, distinct from lost (D10): it doesn't count as
  a lost slime, but it has the same effect, and every case is logged with
  the reason "stuck".
- **As built (chunk 23A, D124):** a pair that can't fuse is one
  that couldn't fuse right now: another species, sizes adding up to more
  than 3, or one of the two not awake. A same-species sleeper caught inside
  a train slime therefore counts as stuck (the sleeper is never the one
  moved). The move comes at the fourth check, 1.5 s after the first. The
  moved slime lands on the first free spot of 8 at the start of the loop,
  one slime width apart (shared with the stalled move), and the log keeps
  the last 64 cases.

## Stalled train slimes (D118, D121)

- A train slime whose progress along the loop hasn't advanced 24 px in
  60 s, on screen or off, or whose centre leaves the level's bounds, is
  **stalled**. Each case is logged (reasons `stalled`, `out_of_bounds`;
  D121).
- It is moved to the start of the loop and rides the train again, as a lost
  (D10) or stuck (D100) slime is (D121). It is not "lost": each case is
  logged as stalled, and the 60 s count starts again from the move. A slime
  asleep at bedtime is never counted as stalled or moved. As built (chunk
  23A, D124): it lands as a stuck slime does, and the log keeps
  the last 64 cases. A lost free slime (D10) lands the same way too: the
  build uses one move to the start of the loop for all three (D126).
- **From chunk 22h (D150, the user's; details proposed):** the 60 s
  count only the ticks a train slime is simulated: while it is parked
  (moving single file at the off-screen pace) its clock is paused, and
  it resumes where it was (O113). And every move to the loop start, lost,
  stuck or stalled, goes through the **loop-start queue**: one at a time,
  the next 0.5 to 2 s (random) after the last, first due first moved, out
  of bounds first; a waiting slime carries on as it was, and one that
  recovers before its turn leaves without a move. It lands at a random
  free spot on the loop's first 240 px, inside the start's split zone,
  never onto another slime (replacing the first free spot of 8); with
  none free, nobody moves and the queue tries again 0.5 s later.
- **The geyser** *(D159, D160: a level object, the user's; details
  proposed; **after v1**, D161, not in v1; `interactive-objects.md`)*: a train slime entering
  a geyser's catch is lifted above any slimes piled over it and launched
  high, to come down on the emptiest of a few seeded free spots along the
  geyser's landing span, only on the loop's own route, never on the
  waiting queue, never onto a ledge rule 22 (b) guards, never at or past
  a gate. Off screen it is placed on a free spot directly. A move to the
  loop start is never launched. The test level's geyser, once built, sits where its
  return routes end (span 150 to 700 px; a fused slime lands only inside
  the split zone).
- DoD 1's "no slime ever becomes lost" includes stalled train slimes: the
  safety net is for play, and a stall in the DoD 1 test is still a failure.

## Movement (D21, D74)

Slimes move only by hopping.

| State | Hopping |
|---|---|
| train slime | forward along the loop every ~1.5–3 s, with a little random timing per slime so the train bounces unevenly |
| answering a call | toward the call point, a bit more often; jumps upward when the point is higher, and bigger slimes jump higher |
| unsure | small, lazy hops in random directions near the call point |
| heading back | along its area's route back |
| sleeper, bedtime-asleep, covered by other slimes, in a basket (any basket, filling or full; D106) | no hopping |

- Bigger slimes hop a little less often, but further and higher.
- During bedtime's wind-down, every slime hops more slowly.
- *(D143, approved in direction, D144, item 24.8; its numbers proposed, O107):* a train slime whose landing spot is
  crowded by slimes it can't fuse with waits a little before hopping (at
  most 2 s), so crowds thin out instead of growing. Same-species crowds
  don't delay it: they fuse. *(D155: a replacement for this rule was
  tried and withdrawn; this one stays as written, unbuilt.)*
- *(D160, proposed; in v1, chunk 24g, the train's climb, D161; O125)* **The hold on a climb:** a train slime
  standing between hops on a rise of the outgoing route keeps its place
  instead of sliding back down (the return routes' carry is unchanged).
  **The relay:** when a train slime takes off, the train slime standing
  right behind it hops almost at once, so a queue moves as a wave
  instead of each slime waiting out its own timer. Why: on a climb the
  train went single file at about 10 px/s, sliding back between hops;
  that, not the dip nudge, was the train's jam.
- The numbers are in `tuning.md`.

## Size and weight (D24, D16)

- **Size** = the number of base slimes a slime is made of. That number is also
  its **weight**, which is what presence objects respond to.
- Bigger slimes are heavier and a little more powerful: they jump higher.
- Level rule (D26): a slime of any size can travel the loop. From v2, size
  filters may send sizes down different forks (D89).
- The maximum size is **3** for now, maybe 5 later (D39). What happens when a
  fusion would go over it: they just bump (D49).

## Species (D22)

- Only slimes of the same species fuse together.
- The first section has 3 native species, and each new section adds one. For a
  first release of 4 sections that makes 6 species (D48).
- Species differ by **colour** and **voice**, which for now is closer to a kind
  of instrument (D40). v1 has no sound, so there it's colour only (D50, D81). Later versions may
  add a texture or styling per species, other colour palettes (for
  colour-blind players), and behaviour quirks.
- Pick v1's 6 colours so they also differ clearly in lightness,
  which helps colour-blind players at no cost.

## Fusion (D20)

- Two slimes of the same species fuse after **3 s** of continuous contact (D37;
  to be tuned). A hop that breaks contact resets the count.
- It happens mostly through the call: slimes held in place, or piled up at a
  spot they can't reach. It can also happen on its own, and a dip in the loop
  can nudge slimes toward fusing. *(D160: D159 (5)'s change is
  withdrawn; the nudge wasn't what jammed the train, the climb was.)* The
  dip nudge stays as built; letting a gathering slime go when the one
  behind is another species is the user's call (O121).
- The fused slime's size is the sum of the two.

## Splitting

- Only **split zones** split slimes. A split zone splits a slime back into base
  slimes instantly (D38, D75).
- Slimes reaching the start of the loop split back into base slimes (D23).
  This is because the start of the loop carries a split zone (D54).

## Fusing different species (D25, later)

A slime-activated device fuses slimes of the right species inside its area
into a new species with special effects (fire burns grass, ice freezes water…).
Not in the first iterations.
