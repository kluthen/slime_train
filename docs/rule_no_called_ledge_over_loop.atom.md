---
id: rule_no_called_ledge_over_loop
status: DRAFT
parents:
  - [[req_level_design_rules]]
human_name: Level rule 22 (second half): no called-up ledge over the loop where larger slimes pass
tags: [level-rule]
type: RULE
priority: 4
version: 1.0
dependents: []
layer: BUSINESS
---

# Level rule 22 (second half): no called-up ledge over the loop where larger slimes pass

## INTENT
Keep the loop passable for larger slimes wherever a level places a ledge for called base slimes.

## THE RULE / LOGIC
Nothing a base slime must be called up to overhangs the loop where larger slimes pass. A ledge a called size-1 slime can reach is too low for a size-2 or size-3 slime to pass under, so such a ledge sits either where only base slimes pass (inside a split zone's reach) or off the loop's path.

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 22, second half; rule_return_route_joins_start_behind_train is the first). Protects rule_all_sizes_travel_loop_v1 (any size travels the loop) where it meets rule_first_sleeper_near_first_awake_slime and other ledges within a called slime's reach.

## EXPECTATION
In every level, no ledge within a called base slime's reach overhangs a stretch of the loop that size-2 or size-3 slimes travel.
