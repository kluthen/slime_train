---
id: rule_train_relay_on_take_off
status: REVIEW
type: RULE
layer: BUSINESS
version: 1.2
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
Parented to req_hopping_behavior (a train slime's hop timing). Implemented in Train._relay and Train._behind (src/sim/train.gd), run at the end of Train.follow, in the take-off's own tick, from that tick's take-offs (SlimeBodies.train_hopped, which is not state and is not read past that tick): the nearest train slime further back along the loop (ties by id), when it is supported, not parked, not on a slide, not itself taking off, and its gap is within its hop reach plus both radii and twice the edge, has its hop timer cut to RELAY_DELAY (0.15 s) if it was longer. Only the cut hop timer crosses into the next tick, and the hop timers are already state: nothing new is saved, and a run reloaded from a save taken just after a take-off carries on as the run that never stopped; the same on both simulation ticks.

Decided by the user (2026-10-07): this rule is kept in v1 as built in chunk 24g, the fix for the train's jam on climbs, with the built values.

## EXPECTATION
When a train slime in a standing queue takes off, the one right behind it has its hop timer at 0.15 s and the one behind that keeps its own; that one hops within 0.15 s and the next one behind is then relayed in turn; a slime further back than its reach is not relayed; a slime whose own hop is already sooner than 0.15 s keeps it.
