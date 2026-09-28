---
id: rule_max_size_three
status: DRAFT
layer: BUSINESS
priority: 4
parents:
  - [[req_species_and_colour]]
dependents: []
version: 1.0
type: RULE
human_name: Maximum slime size is 3
tags: [fusion,size]
---

# Maximum slime size is 3

## INTENT
Cap how large a fused slime can become in v1.

## THE RULE / LOGIC
A slime's size is the number of base slimes it is made of, which is also its weight for basket purposes. The maximum size is 3. Two slimes whose sizes would add up to more than 3 just bump into each other instead of fusing. A maximum size above 3 is explicitly deferred to a later version.

## TECHNICAL INTERFACE
Parented to req_species_and_colour. Constrains rule_fusion_contact_time.

## EXPECTATION
Two same-species slimes whose sizes sum above 3 never fuse (definition of done item 6).
