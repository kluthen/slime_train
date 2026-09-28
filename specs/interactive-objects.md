# Interactive objects

Status: draft v4

**Versions (D50):** interactive objects come in v2, except the frontier gate,
which is in v1 (what it includes is O46).

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
(proposed: hit areas are generous, bigger than the drawn object, to suit
small fingers)

## Catalogue

### Switch (D14)
Redirects the flow at a fork in the loop. Activation: tap. Properties: the
default direction, and the direction when flipped. (proposed: it stays
flipped until tapped again)

### Basket (D14)
Collects slimes and shows the ones it still needs as empty slime outlines.
Activation: presence (weight). When full, it fires its target (usually a gate)
and then releases its slimes. Properties: the weight it needs, and its target.
Its outlines fill by weight, so a fused slime fills several at once.

### Gate (D9, D14)
The barrier at the end of the loop. Opening it extends the loop into the new
area. It stays open for good.

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

### Defusing spot (precursor, D38)
A split object or zone. It instantly splits slimes back into base slimes.
(proposed) The start of the loop carries one (D23). Not specified in detail yet.

### Signpost (D47)
Stands at every fork in the loop and shows which way the loop goes. Not
interactive. (proposed: in v1)

### Large signpost (D47)
A larger signpost. Tapping it chooses which branch the camera follows. (proposed:
v2, since it is tapped)

### Filter (D47)
A kind of fork that sends slimes down a branch by species ("all blue slimes go
this way"). It usually has a signpost next to it.

### Species-fusion device (D25, later)
Presence-activated. Fuses slimes of the right species inside its area into a
new species. Not in the first iterations.

## Open points

- Branch rules are settled (D18). Frontier gates open only through the
  switch-plus-basket pattern in the first release (D35).
- The shared rule schema ("when X, fire Y") is yet to be designed (tech-direction).
