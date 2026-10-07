---
id: rule_dip_may_nudge_fusion
status: REVIEW
tags: [level-rule]
dependents: []
version: 1.2
layer: BUSINESS
priority: 2
human_name: Level rule 5: a dip may nudge fusion
parents:
  - [[req_level_design_rules]]
type: RULE
---

# Level rule 5: a dip may nudge fusion

## INTENT
Allow level design to place a dip in the loop that nudges same-species slimes together into fusing.

## THE RULE / LOGIC
A dip in the loop may nudge same-species slimes into fusing, as one of the ways fusion can happen without a call (see rule_fusion_contact_time).

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 5). Implemented in src/sim/fusion.gd (the gathering on a dip floor): a train slime on a dip floor waits without limit for a partner directly behind it (no other train slime between them), and at most 5 s for a partner further back, counted from the train's stall mark. This is the expected behaviour as built: the train's jam once laid on the dip nudge was found to come from the climb (rule_train_climbs_without_sliding_back, rule_train_relay_on_take_off), and the earlier proposed change to this wait is withdrawn.

## EXPECTATION
At least the option of a dip-induced fusion is available to level design; no level is required to use it, but the mechanic must support it.
