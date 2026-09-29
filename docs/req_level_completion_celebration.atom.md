---
id: req_level_completion_celebration
status: DRAFT
layer: BUSINESS
priority: 3
tags: [celebration,completion,persistence]
type: REQUIREMENT
version: 1.1
human_name: Level completion celebration
parents:
  - [[req_loop_and_world]]
dependents: []
---

# Level completion celebration

## INTENT
Define the one-time celebration that plays when the last basket fires, the lasting mark that follows it, and how both are persisted so a reload never replays the celebration.

## THE RULE / LOGIC
When the last basket in the level fires, nothing about the loop ends: the loop is complete, the world stays open, and a one-time celebration plays. During the celebration input stays live and the camera stays where it is. After it, a small lasting mark at the start of the loop shows the level is complete. That the celebration has played is recorded in the level's save alongside the other object and gate state (see req_persistence_and_saves), so reloading the level afterwards never replays it and still shows the mark. A celebration that comes due at bedtime waits for sunrise (see req_switch_basket_gate_set). Deleting the level's save resets this along with everything else: the mark is gone and the celebration is due again the next time the level is completed on that fresh save.

## TECHNICAL INTERFACE
Parented to req_loop_and_world, whose loop-completion rule names the one-time celebration only in passing; this atom is its dedicated record. Depends on req_switch_basket_gate_set for what firing the last basket means, and on req_persistence_and_saves for where the played flag is stored.

## EXPECTATION
When the last basket fires, the celebration plays once, and the world keeps running with the loop complete; reloading doesn't replay it (definition of done item 14). A tap during the celebration does its normal job and the camera doesn't move on its own; afterwards the lasting mark stands at the start of the loop, is still there after a reload, and is absent on a level whose celebration hasn't played.
