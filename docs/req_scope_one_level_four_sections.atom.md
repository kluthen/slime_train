---
id: req_scope_one_level_four_sections
status: DRAFT
parents: []
layer: BUSINESS
dependents:
  - [[req_level_design_rules]]
  - [[req_platform_and_performance_targets]]
  - [[req_species_and_colour]]
  - [[req_test_level_and_test_mode]]
  - [[rule_no_in_app_purchases]]
version: 1.0
type: REQUIREMENT
priority: 5
human_name: v1 scope: one level
tags: [scope,level]
---

# v1 scope: one level

## INTENT
Fix v1's shipped content scope to exactly one level of four sections, so no later decision quietly grows it.

## THE RULE / LOGIC
v1 ships one level made of 4 sections, with a basic theme close to Cocoreccho!: black 'stone' and black 'plants' form the ground. The level has 6 species in total, told apart by colour, with the first section native to 3 of them and each later section adding one more (see req_species_and_colour, and level rule rule_first_section_species_count). Moving on to another level waits for paid extra levels, a later version; v1's world stays open and playable once complete rather than advancing anywhere else.

## TECHNICAL INTERFACE
Governs the scope of req_loop_and_world, req_species_and_colour, and the four-section structure referenced by req_level_design_rules.

## EXPECTATION
The shipped v1 build contains exactly one level with exactly 4 sections and 6 species total; no in-app path leads to a second level.
