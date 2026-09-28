---
id: rule_first_section_species_count
status: DRAFT
type: RULE
layer: BUSINESS
priority: 3
human_name: Level rule 11: species count per section
tags: [level-rule]
dependents: []
parents:
  - [[req_level_design_rules]]
version: 1.0
---

# Level rule 11: species count per section

## INTENT
Fix how many species each section of a level introduces.

## THE RULE / LOGIC
The first section has 3 native species; each later section adds one more species. In v1's 4-section level this yields the 6 total species of req_species_and_colour (3 in the first section, plus 1 per each of the 3 later sections).

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 11 of 20). Constrains req_species_and_colour and req_scope_one_level_four_sections.

## EXPECTATION
The first section contains exactly 3 species; each subsequent section introduces exactly 1 new species.
