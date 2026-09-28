---
id: rule_tilt_never_required
status: DRAFT
type: RULE
layer: BUSINESS
priority: 4
parents:
  - [[req_level_design_rules]]
human_name: Level rule 10: tilt is never needed to make progress
tags: [level-rule]
dependents: []
version: 1.0
---

# Level rule 10: tilt is never needed to make progress

## INTENT
Require that tilt stays optional in every level, used only for exploration or fun.

## THE RULE / LOGIC
Tilt is only for exploration or fun, never needed to make progress. No level may require tilting the phone to open a gate, complete a section, or reach any exploration branch.

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 10 of 20). Consistent with req_controls_tap_zones's tilt description.

## EXPECTATION
Opening all gates of the level never requires tilt (definition of done item 12).
