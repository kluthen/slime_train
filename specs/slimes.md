# Slimes

Status: draft v3

## States

| State | Meaning |
|---|---|
| sleeper | asleep, not moving. Wakes **only** when an awake slime touches it (D13). The game wakes the very first slime. |
| train slime | awake and following the loop (D8, D11). Ignores tilt (D19). |
| bedtime-asleep | asleep because the session ended (D28). The game wakes it at the next session. Not a sleeper. |
| free slime | awake and away from the loop after answering a call. Physics always applies and it feels tilt (D8, D19). Can become left alone or lost (D10). Goes through the phases below. |

## Free slime phases (D27)

1. **Answering the call:** hops toward the call point.
2. **Unsure:** after the call ends, for up to about 15 s (to be tuned). It stays
   put or hops around, without straying far from the last call point.
3. **Heading back:** makes for the loop (how exactly is O33), and rejoins the
   train when it reaches it.

Physics applies in every phase. On a steep slope its hopping can't hold it,
and it may roll downhill. Phase names are proposed (O32).

## Movement (D21)

Every few seconds a slime makes a small hop in a direction of its choosing.
A train slime hops along the loop. How far and how often a hop goes depends
on the slime's size (see below).

## Size and weight (D24, D16)

- **Size** = the number of base slimes a slime is made of. That number is also
  its **weight**, which is what presence objects respond to.
- Bigger slimes are heavier and a little more powerful: they jump higher.
- Level rule (D26): a slime of any size can travel the loop, but different
  sizes may take different forks.
- The maximum size is O30.

## Species (D22)

- Only slimes of the same species fuse together.
- The first section has 3 native species, and each new section adds one.
- Whether species differ in any other way in the first release (look, voice,
  sound) is O31.

## Fusion (D20)

- Two slimes of the same species fuse when they stay in contact for about
  3–5 s (to be tuned).
- It happens mostly through the call: slimes held in place, or piled up at a
  spot they can't reach. It can also happen on its own, and a dip in the loop
  can nudge slimes toward fusing.
- The fused slime's size is the sum of the two.

## Splitting

- Defusing spots (from the precursor) split a slime back into base slimes
  instantly. Not specified yet.
- Slimes reaching the start of the loop split back into base slimes (D23). The
  in-world reason is O29.

## Fusing different species (D25, later)

A slime-activated device fuses slimes of the right species inside its area
into a new species with special effects (fire burns grass, ice freezes water…).
Not in the first iterations.
