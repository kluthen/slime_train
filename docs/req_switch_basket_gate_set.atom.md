---
id: req_switch_basket_gate_set
status: DRAFT
parents:
  - [[req_interactive_objects_general]]
version: 1.1
type: REQUIREMENT
layer: BUSINESS
priority: 5
human_name: The frontier switch
dependents: []
tags: [objects,frontier-gate]
---

# The frontier switch

## INTENT
Define the only mechanism v1 provides for opening a gate: the switch-plus-basket-plus-gate set.

## THE RULE / LOGIC
The switch stands at the fork just before the frontier gate. By default it sends the flow back to the start by the return route; tapping it flips it so the flow goes into the basket instead, and it stays flipped until tapped again. The basket shows the weight it still needs as empty slime outlines, which fill by weight (a size-3 slime fills three outlines); it can fill off screen. When full, it plays a reward animation, fires its target (the gate), then releases its slimes; the reward and the firing wait until the basket is in view. Flipping the switch back before the basket is full opts out: filling stops, the slimes inside go back to the loop, and the basket empties. Once the basket is full, the switch no longer answers taps (a tap on it is a call), through the reward and after: there is no opting out of a full basket. At bedtime a basket's releases pause and resume at sunrise; the slimes in it sleep in place, staying in the basket shown asleep, and sunrise doesn't move them out; a reward that is due or playing waits for sunrise too, so no gate opens and no celebration plays during bedtime. Where a basket releases its slimes, after firing and after an opt-out, belongs to the basket's own design, which is still to be planned. The gate opens when its basket fires, extends the loop, and stays open; from then on its switch and basket are inert for good (a tap on the switch is a call) and may be removed or turned into a landscape feature. The switch plus basket is the only way to open a gate in v1: there are no filters, so the only fork in the loop is the frontier switch and every size travels the loop the same way; size matters only through basket weight and, off the loop, through bigger free slimes jumping higher. The components share one rule format ('when this basket is full, open that gate'), whose design is left to implementation.

## TECHNICAL INTERFACE
Parented to req_interactive_objects_general. Constrained by level rules rule_gate_opens_via_switch_basket_set and rule_frontier_set_inert_after_gate_open.

## EXPECTATION
Flipping the frontier switch sends the flow into the basket; its outlines fill by weight; when full it plays the reward animation, opens the gate and releases its slimes; the loop then extends into the new section and the old return route is no longer used (definition of done item 9). Flipping the switch back before the basket is full stops the filling, releases the slimes inside back to the loop, and empties the basket; once the basket is full, a tap on the switch doesn't flip it, it calls (definition of done item 11). Once a gate is open, tapping its switch doesn't operate it (the tap is a call), and its basket takes no more slimes (definition of done item 13). During bedtime no basket releases a slime or plays its reward, and the slimes in a basket stay in it through sunrise; releases and rewards resume at sunrise (definition of done item 21).
