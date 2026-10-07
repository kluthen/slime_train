---
id: req_level_design_rules
status: DRAFT
type: REQUIREMENT
layer: BUSINESS
priority: 5
parents:
  - [[req_scope_one_level_four_sections]]
dependents:
  - [[rule_all_sizes_travel_loop_v1]]
  - [[rule_arrivals_clear_faster_than_they_arrive]]
  - [[rule_dip_may_nudge_fusion]]
  - [[rule_exploration_branch_has_route_back]]
  - [[rule_first_section_species_count]]
  - [[rule_first_sleeper_near_first_awake_slime]]
  - [[rule_framing_zone_wherever_wider_view_needed]]
  - [[rule_frontier_set_inert_after_gate_open]]
  - [[rule_gate_opens_via_switch_basket_set]]
  - [[rule_gravity_leads_back_to_loop]]
  - [[rule_hints_visible_from_loop]]
  - [[rule_loop_travelable_with_no_input]]
  - [[rule_max_200_slimes_per_level]]
  - [[rule_no_called_ledge_over_loop]]
  - [[rule_no_dead_ends]]
  - [[rule_objects_below_parent_zone]]
  - [[rule_released_level_stable_with_migration]]
  - [[rule_return_route_joins_start_behind_train]]
  - [[rule_return_route_may_carry_exploration]]
  - [[rule_return_route_per_section]]
  - [[rule_signpost_at_every_fork]]
  - [[rule_sleepers_never_on_loop]]
  - [[rule_start_carries_split_zone]]
  - [[rule_tilt_never_required]]
human_name: Level design rules
tags: [level-rules]
version: 1.3
---

# Level design rules

## INTENT
Require that every level, the test level included, satisfies a fixed set of structural and pacing rules.

## THE RULE / LOGIC
Every level built for Slime Train, the test level included, must follow the full set of level design rules recorded as this atom's children (rule_loop_travelable_with_no_input through rule_objects_below_parent_zone, plus the two halves of the rule about where return routes meet the start: rule_return_route_joins_start_behind_train and rule_no_called_ledge_over_loop). These rules exist so that any level, current or future, keeps the same guarantees: it can always be watched with no input, it never traps a slime or the child, and it stays consistent with the game's design stance. A level that violates any child rule fails the level-rules check that v1's definition of done requires for the real first level.

## TECHNICAL INTERFACE
Parented to req_scope_one_level_four_sections. Each child RULE atom states one of the 22 level rules; level rule 22 joins two constraints and so has two child atoms.

Pending the user's sign-off (proposed, not settled; the 22 rules above are what is settled until then): the level rules now number 25. Rule 23, no spot where many slimes gather awake (approved by the user in direction, its measure and limit proposed), has no child atom yet: it gets one once its limit is calibrated. Rule 24, where slimes arrive fast they get away faster than they arrive (the user's rule, its wording and checks proposed), has a DRAFT child, rule_arrivals_clear_faster_than_they_arrive; its run tool, tools/dipjam_probe.gd, is built in v1 (without a geyser's counts), while its rate window and threshold are settled after v1. Rule 25, a geyser lands slimes where they can carry on (where a level may place a geyser: its landing span on the loop, wholly ahead of its catch, with no gate in it, as little of it as possible under a guarded ledge, and a split zone over part of it when fused arrivals land only in one; the object is the user's, this rule and its check proposed), applies after v1, once the geyser is built (rule_geyser_spreads_arrivals_at_loop_start): no v1 level places one, and it has no child atom yet. None of rules 23 to 25 has an automatic level-rules checker check in v1.

## EXPECTATION
v1 is done only when the real first level (designed later) passes the level-rules check against every child rule of this atom.
