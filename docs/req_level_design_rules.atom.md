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
  - [[rule_no_dead_ends]]
  - [[rule_released_level_stable_with_migration]]
  - [[rule_return_route_may_carry_exploration]]
  - [[rule_return_route_per_section]]
  - [[rule_signpost_at_every_fork]]
  - [[rule_sleepers_never_on_loop]]
  - [[rule_start_carries_split_zone]]
  - [[rule_tilt_never_required]]
human_name: Level design rules
tags: [level-rules]
version: 1.0
---

# Level design rules

## INTENT
Require that every level, the test level included, satisfies a fixed set of structural and pacing rules.

## THE RULE / LOGIC
Every level built for Slime Train, the test level included, must follow the full set of level design rules recorded as this atom's children (rule_loop_travelable_with_no_input through rule_released_level_stable_with_migration). These rules exist so that any level, current or future, keeps the same guarantees: it can always be watched with no input, it never traps a slime or the child, and it stays consistent with the game's design stance. A level that violates any child rule fails the level-rules check that v1's definition of done requires for the real first level.

## TECHNICAL INTERFACE
Parented to req_scope_one_level_four_sections. Each child RULE atom states one of the 20 rules from the master spec's Level rules section.

## EXPECTATION
v1 is done only when the real first level (designed later) passes the level-rules check against every child rule of this atom.
