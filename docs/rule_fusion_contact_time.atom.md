---
id: rule_fusion_contact_time
status: REVIEW
dependents: []
type: RULE
priority: 4
tags: [fusion]
version: 1.0
layer: BUSINESS
human_name: Fusion requires 3 s of contact
parents:
  - [[req_species_and_colour]]
---

# Fusion requires 3 s of contact

## INTENT
Define the exact condition under which two slimes fuse.

## THE RULE / LOGIC
Two slimes of the same species fuse after 3 s of continuous contact. A hop that breaks contact resets the count. The fused slime's size is the sum of the two original sizes (subject to the size-3 cap in rule_max_size_three). Fusion mostly happens through the call, since slimes answering it clump together at the call point, but it can also happen on its own, and a dip in the loop can nudge slimes into fusing (see level rule rule_dip_may_nudge_fusion).

## TECHNICAL INTERFACE
Parented to req_species_and_colour. Constrained by rule_max_size_three.

## EXPECTATION
Two same-species slimes in contact for 3 s fuse into one whose size is the sum; a hop breaking contact resets the count; slimes of different species, or whose sizes sum above 3, never fuse (definition of done item 6).
