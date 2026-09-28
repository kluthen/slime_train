---
id: req_level_completion_celebration
status: DRAFT
layer: BUSINESS
priority: 3
tags: [celebration,completion,persistence]
type: REQUIREMENT
version: 1.0
human_name: Level completion celebration
parents:
  - [[req_loop_and_world]]
dependents: []
---

# Level completion celebration

## INTENT
Define the one-time celebration that plays when the last basket fires, and how it is persisted so a reload never replays it.

## THE RULE / LOGIC
When the last basket in the level fires, nothing about the loop ends: the loop is complete, the world stays open, and a one-time celebration plays. That the celebration has already played is recorded in the level's save alongside the other object and gate state (see req_persistence_and_saves), so reloading the level afterwards never replays it. Deleting the level's save resets this along with everything else: the celebration is due again the next time the level is completed on that fresh save.

## TECHNICAL INTERFACE
Parented to req_loop_and_world, whose loop-completion rule names the one-time celebration only in passing; this atom is its dedicated record. Depends on req_switch_basket_gate_set for what firing the last basket means, and on req_persistence_and_saves for where the played flag is stored.

## EXPECTATION
When the last basket fires, the celebration plays once, and the world keeps running with the loop complete; reloading doesn't replay it (definition of done item 14).
