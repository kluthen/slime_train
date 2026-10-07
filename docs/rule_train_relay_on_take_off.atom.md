---
id: rule_train_relay_on_take_off
status: DRAFT
type: RULE
layer: BUSINESS
version: 1.0
dependents: []
priority: 3
human_name: The relay: the train slime behind a take-off hops almost at once
tags: [slimes,movement,train,relay]
parents:
  - [[req_hopping_behavior]]
---

# The relay: the train slime behind a take-off hops almost at once

## INTENT
Let a packed queue of train slimes move as a wave instead of each slime waiting out its own hop timer.

## THE RULE / LOGIC
When a train slime takes off, the train slime standing right behind it on the outgoing route, close enough to touch it with a hop, hops almost at once, so the next one behind follows in turn. Only the one right behind is hurried, never across a gap it couldn't hop, and never later than its own timer.

## TECHNICAL INTERFACE
Parented to req_hopping_behavior (a train slime's hop timing). Implemented in Train._relay and Train._behind (src/sim/train.gd), run at the start of Train.steer from the last tick's take-offs (SlimeBodies.train_hopped): the nearest train slime further back along the loop (ties by id), when it is supported, not parked, not on a slide, not itself taking off, and its gap is within its hop reach plus both radii and twice the edge, has its hop timer cut to RELAY_DELAY (0.15 s) if it was longer. The hop timers are already state: nothing new is saved; the same on both simulation ticks.

Pending the user's sign-off (proposed, not settled; built on main in chunk 24g as the fix for the train's jam on climbs, which the user may still drop): this rule as a whole. Until the user rules on it, the hopping behaviour of req_hopping_behavior is what is settled.

## EXPECTATION
When a train slime in a standing queue takes off, the one right behind it has its hop timer at 0.15 s and the one behind that keeps its own; that one hops within 0.15 s and the next one behind is then relayed in turn; a slime further back than its reach is not relayed; a slime whose own hop is already sooner than 0.15 s keeps it.
