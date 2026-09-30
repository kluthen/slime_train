# Slimes

Status: draft v22 (the train holds before a crowd or a jam, holding slimes may rest, D145, proposed, replacing D143's lean, approved in direction, D144; its numbers proposed, O107)

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

## Stuck slimes (D100)

- Slimes of different species have been seen stuck inside one another
  (the user's report, 2026-09-29). It isn't fusion: only the same species
  fuse.
- Until the cause is fixed (O91), a safety net: the simulation checks every 0.5 s for two
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
| train slime holding (proposed, D145) | no hopping until its hold ends (at most 5 s) |

- Bigger slimes hop a little less often, but further and higher.
- During bedtime's wind-down, every slime hops more slowly.
- **The hold** *(proposed, D145, item 24.8, amending D143's lean, which
  was approved in direction, D144; its numbers proposed, O107)*: when its
  hop is due, a train slime **holds** (stays where it is) while either
  - more than 30 awake slimes out of a basket (not resting, not parked,
    any species) are near its landing point, ahead of it, or
  - its landing point would come right up against a **jam**: train slimes
    ahead of it on the loop that are holding.

  It looks again every 0.5 s and holds at most 5 s, then hops anyway. The
  front of a queue, whose way is clear, goes first; the slimes behind
  wait, and new ones stop short of the queue instead of landing on it, so
  a crowd drains from the front. Calls, free slimes and celebration hops
  are unchanged.
- **A holding slime may rest** *(proposed, D145)*: once still on the
  ground, it stops being simulated, like a resting pile, and wakes when its
  hold ends or something disturbs it. It doesn't rest while it is fusing
  with a neighbour. A wake is local (item 24.3, with O106): only the slimes
  touched wake, not the whole pile.
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
  can nudge slimes toward fusing.
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
