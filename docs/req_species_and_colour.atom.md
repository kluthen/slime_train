---
id: req_species_and_colour
status: DRAFT
priority: 4
tags: [species,accessibility]
version: 1.0
human_name: Species and colour
parents:
  - [[req_scope_one_level_four_sections]]
dependents:
  - [[rule_fusion_contact_time]]
  - [[rule_max_size_three]]
type: REQUIREMENT
layer: BUSINESS
---

# Species and colour

## INTENT
Define how many species exist in v1 and how the child tells them apart.

## THE RULE / LOGIC
v1 has 6 species: 3 native to the first section, and one more per later section (see level rule rule_first_section_species_count). In v1, species differ by colour only; the 6 colours also differ clearly in lightness, which helps colour-blind players at no extra cost. Only slimes of the same species fuse (see rule_fusion_contact_time). A texture or styling per species, and other colour palettes, may come in later versions.

## TECHNICAL INTERFACE
Parented to req_scope_one_level_four_sections. Governs rule_max_size_three and rule_fusion_contact_time.

## EXPECTATION
Exactly 6 species exist, distinguishable by colour and by lightness alone, with no other visual distinction in v1.
