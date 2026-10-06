---
id: rule_dip_may_nudge_fusion
status: REVIEW
tags: [level-rule]
dependents: []
version: 1.1
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
Parented to req_level_design_rules (level rule 5 of 20). Implemented in src/sim/fusion.gd (the gathering on a dip floor): a train slime on a dip floor waits without limit for a partner directly behind it (no other train slime between them), and at most 5 s for a partner further back.

Pending the user's sign-off (proposed, not settled, and not built on main; the rule and expectation above are what is settled until then): the dip nudge never jams the train. A slime waiting on a dip floor for a partner further back counts its own time on the floor, so a push from behind doesn't restart its wait (on main the 5 s count from the train's stall mark, which moves on whenever the slime is pushed forward, so the slimes hopping into it from behind keep restarting it), and it is let go when the slimes pressing it from behind aren't partners. The exact form is the build's, measured on the stress-dense and s3-basket-59of60 fixtures; it ships with the geyser (rule_geyser_spreads_arrivals_at_loop_start). It must still keep fusion happening in dips (this rule), the no-input loop (rule_loop_travelable_with_no_input), and the bump fixture's two bumps (a size 1 that waits with a size 3 behind it); if letting go on a non-partner's push loses that bump and both can't hold, the choice is the user's.

## EXPECTATION
At least the option of a dip-induced fusion is available to level design; no level is required to use it, but the mechanic must support it.
