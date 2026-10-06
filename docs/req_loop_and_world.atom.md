---
id: req_loop_and_world
status: DRAFT
type: REQUIREMENT
priority: 5
human_name: The loop and the world
tags: [loop,world]
parents: []
version: 1.1
layer: BUSINESS
dependents:
  - [[req_controls_tap_zones]]
  - [[req_interactive_objects_general]]
  - [[req_level_completion_celebration]]
  - [[req_offscreen_simulation]]
  - [[req_persistence_and_saves]]
  - [[req_session_lifecycle]]
  - [[req_slime_states]]
  - [[rule_geyser_spreads_arrivals_at_loop_start]]
  - [[rule_split_zone_only_splitter]]
  - [[rule_stalled_train_slime_moved_to_start]]
---

# The loop and the world

## INTENT
Define the loop as the route the train follows and how it grows as gates open.

## THE RULE / LOGIC
A level is a side-view world; the loop is a drawn route the train follows, with physics only handling the squish and bumps of slimes on it. The loop has forks, and every branch joins the loop again: there are no dead ends, and a slime on any branch of the loop is still part of the train. Exploration areas hang off the loop; slimes reach them only by being called. The loop runs from the start to the frontier gate (the first unopened gate). Unless the child is actively filling the frontier basket, the flow at the frontier is sent back to the start by that section's return route; what the return route is physically made of is decided per level. The return route is itself part of the loop, with its own camera rail, and may carry exploration opportunities. Opening a gate extends the loop into the new section: only the part that led back to the start is replaced; the old return route stays in the world (it isn't removed) but is no longer used. The gate may shut the old route's entrance with a lid; level design then makes sure that exploration opportunities on that route stay reachable another way, so they never become unreachable. Gates stay open for good. When the last basket fires, nothing ends: the loop is complete and the world stays open, with a one-time celebration followed by a small lasting mark at the start of the loop (see req_level_completion_celebration); moving on to another level waits for a later version. The start of the loop carries a split zone.

## TECHNICAL INTERFACE
Parent to level rules rule_no_dead_ends, rule_return_route_per_section, rule_return_route_may_carry_exploration, rule_start_carries_split_zone.

## EXPECTATION
From a fresh save, with no input at all, the train keeps travelling the whole current loop for a full session, no slime ever becomes lost and no train slime stalls; a stalled slime moved by the safety net doesn't count as a pass (definition of done item 1). Opening a gate extends the loop and the old return route is no longer used (definition of done item 9); exploration opportunities on an old return route stay reachable, another way if the gate's lid shuts that route's entrance.
