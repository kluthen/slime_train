# Slimes

Status: draft v11

## States

| State | Meaning |
|---|---|
| sleeper | asleep, not moving. Wakes **only** when a free slime touches it, on screen (D13, D70). Never on the loop. The game wakes the very first slime. |
| train slime | awake and following the loop (D8, D11). Ignores tilt (D19). |
| bedtime-asleep | asleep because the session ended (D28). The game wakes it at the next session. Not a sleeper. |
| free slime | awake and away from the loop after answering a call. Physics always applies and it feels tilt (D8, D19). Can become left alone or lost (D10). Goes through the phases below. |

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
and it may roll downhill. Phase names are proposed (O32).

## Off screen (D69, D70)

- Physics runs only for slimes on or near the screen. Off screen, a train slime
  follows the loop at a deterministic pace, and a free slime follows its area's
  route back (if there is none, it is lost).
- Fusion and waking happen only on screen.

## Movement (D21, D74)

Slimes move only by hopping.

| State | Hopping |
|---|---|
| train slime | forward along the loop every ~1.5–3 s, with a little random timing per slime so the train bounces unevenly |
| answering a call | toward the call point, a bit more often; jumps upward when the point is higher, and bigger slimes jump higher |
| unsure | small, lazy hops in random directions near the call point |
| heading back | along its area's route back |
| sleeper, bedtime-asleep, covered by other slimes, resting in a full basket | no hopping |

- Bigger slimes hop a little less often, but further and higher.
- During bedtime's wind-down, every slime hops more slowly.
- The numbers are in `tuning.md`.

## Size and weight (D24, D16)

- **Size** = the number of base slimes a slime is made of. That number is also
  its **weight**, which is what presence objects respond to.
- Bigger slimes are heavier and a little more powerful: they jump higher.
- Level rule (D26): a slime of any size can travel the loop, but different
  sizes may take different forks.
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
- (proposed) Pick v1's 6 colours so they also differ clearly in lightness,
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
