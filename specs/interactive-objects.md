# Interactive objects

Status: draft v13 (population fork, v2, proposed, D143)

**Versions (D50, D54):** v1 has only the frontier-gate set (switch, basket,
gate) and the split zone at the start of the loop. Every other object comes in
v2.

Every interactive object is a reusable, programmed component configured
through its properties in the Godot editor (D6). Its state is part of the
saved state (D7).

## How objects are activated (D15)

| Mode | Meaning |
|---|---|
| tap | the child taps the object; most objects work this way |
| tilt | the phone's tilt drives it, always, even when that affects the train a little (D19) |
| presence | the **weight** of slimes on or in it drives it, possibly only a specific species (D16) |

**Weight** = the number of base slimes a slime is made of. A fused slime
weighs more (D16). Each object's thresholds are set when that object is
designed.

Tapping an interactive object operates it. A tap anywhere else is a call.
**Only something that answers a tap takes it** (D109): a tap on an object
that doesn't answer taps (a basket, a gate, a signpost), or that isn't
answering right now (a switch whose basket is full, or inert), is a call.
Hit areas are the drawn object grown by 5 mm on every side, never smaller
than 20 × 20 mm, both measured on the screen at the current zoom (D91,
D109). A hit area still smaller than the floor grows about the object's
centre (D126, proposed). Where hit areas overlap, the nearest centre is
compared only among objects answering a tap right now: a filling basket's
switch takes the tap even where a basket's centre is nearer (D126,
proposed). Sleepers are slimes, not objects: their tap margin is in
`concept.md`. Every new object must say when it answers taps.

## Catalogue

### Switch (D14)
Redirects the flow at a fork in the loop. Activation: tap. Properties: the
default direction, and the direction when flipped. (D91: it stays
flipped until tapped again)

### Basket (D14)
Collects slimes and shows the ones it still needs as empty slime outlines.
Activation: presence (weight). When full, it fires its target (usually a gate)
and then releases its slimes. Properties: the weight it needs, and its target.
Its outlines fill by weight, so a fused slime fills several at once.
*(Proposed, D128:)* above a quota of 10 it shows **quota pies** instead:
one pie per 10 of weight, the last holding the rest, a slice per unit of
weight; readable at the basket's framing zoom (`tuning.md`). A fired
basket always empties: no released slime falls back into it.
- **Off screen (D70):** it can still reach its quota. Filling it earns a
  **reward animation**, then it fires. (D91: the reward and the firing
  wait until the basket is in view)
- **Opting out (D70):** flipping the switch back before the basket is full
  stops the filling. (D91: the slimes inside go back to the loop, and the
  basket empties) Once the basket is full, the switch no longer answers
  taps, through the reward and after: no opting out of a full basket (D105).
- **At bedtime (D105):** its releases pause and resume at sunrise; the
  slimes in it sleep in place and stay in it at sunrise; a reward due or
  playing waits for sunrise, so no gate opens and no celebration plays
  during bedtime. Slimes in a basket have a state of their own (D106).

- **Outlet:** where it releases its slimes, after firing or after an opt-out,
  belongs to the basket's own design, still to be planned (O62).
- **After its gate opens (D86):** the switch and basket are inert for good.
  They may be removed or turned into a landscape feature (art and level
  design).

### Gate (D9, D14)
The barrier at the end of the loop. Opening it extends the loop into the new
area. It stays open for good. It may shut the old return route's entrance
with a lid; the route itself stays in the world (D105).

### Bending pathway
A walkway that bends under load. Activation: presence.
- Below the threshold (for example, a lone slime), it holds its shape.
- At or above the threshold, it bends, which changes where slimes can go.
- Property `recovery`: either **permanent** (stays bent for good) or
  **springs back** after a set delay.
- Properties: the weight threshold and the recovery delay.
- **Role (D17):** a spring-back pathway is a small fork in the loop driven by
  weight. A dense clump of the train bends it and takes one branch; a sparse
  trickle takes the other. The call can **hold** slimes on it (piling up
  weight) or **hurry** them across (so it stays straight).

### Split zone (D38, D75)
A place that instantly splits slimes back into base slimes.
The start of the loop carries one (D23, D54). Not specified in detail yet.

### Signpost (D47)
Stands at every fork in the loop and shows which way the loop goes. Not
interactive. In v1 (D91).

### Large signpost (D47)
A larger signpost. Tapping it chooses which branch the camera follows. v2, since it is tapped.

### Filter (D47, D88)
A kind of fork that sends slimes down a branch by **species** ("all blue
slimes go this way") or by **size** ("size 3 goes up here"). It usually has a
signpost next to it. It isn't tapped. Both filters are v2 (D89).

### Population fork (v2, proposed, D143)
A kind of fork that breaks up crowds: it sends the next slimes down
whichever of its branches holds fewer slimes on its first stretch.
Activation: presence (it counts slimes); it isn't tapped. It reads no
clock: a tie keeps the current way, and it holds a way for a set number
of ticks, so it doesn't flicker. Like every fork it has a plain signpost
showing where it sends slimes now; a large signpost may stand at it too.
The opposite of the spring-back pathway (D17). It serves level rule 23.
Open for v2's scoping: slimes or weight, the stretch counted, off screen,
the camera's branch.

### Species-fusion device (D25, later)
Presence-activated. Fuses slimes of the right species inside its area into a
new species. Not in the first iterations.

## Off-screen behaviour (D70)

Physics stops off screen (D69), so every object must say how it behaves
there. For example, a bending pathway counts the weight crossing it.

## Open points

- Branch rules are settled (D18). Frontier gates open only through the
  switch-plus-basket pattern in the first release (D35).
- The shared rule schema ("when X, fire Y") is yet to be designed (tech-direction).
