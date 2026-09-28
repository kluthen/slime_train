---
id: rule_split_zone_only_splitter
status: DRAFT
parents:
  - [[req_loop_and_world]]
dependents: []
version: 1.0
type: RULE
human_name: Only split zones split slimes
layer: BUSINESS
priority: 3
tags: [split-zone]
---

# Only split zones split slimes

## INTENT
Define the only mechanism in v1 that splits a fused slime back into base slimes.

## THE RULE / LOGIC
Only split zones split slimes. A split zone splits any slime that enters it back into its base slimes instantly. In v1 the only split zone is at the start of the loop (see level rule rule_start_carries_split_zone).

## TECHNICAL INTERFACE
Parented to req_loop_and_world.

## EXPECTATION
Every slime entering the split zone at the start of the loop leaves it as base slimes (definition of done item 7).
