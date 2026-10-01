---
id: domain_drawing
status: DRAFT
human_name: Drawing slimes
type: DOMAIN
layer: BUSINESS
version: 1.0
priority: 2
tags: [architecture,rationale,drawing]
parents:
  - [[domain_architecture_rationale]]
dependents: []
---

# Drawing slimes

## INTENT
Record how slimes are drawn, why drawing is kept cheap by design, and which renderer draws them.

## THE RULE / LOGIC
Each soft slime is drawn with a shader that blends nearby shapes into smooth blobs; no engine provides this out of the box. Drawing is kept cheap by design rather than assumed cheap: only the slimes near the view are drawn, each drawing redraws only when what it shows changes, and repeated shapes (eyes, a basket's slots) are drawn in one instanced draw. Before that work, drawing cost more of the frame than the simulation tick on light scenes. Drawing's share of the reference phone's frame is at most 4 ms (proposed); estimated within it cold and slightly over it once the phone throttles, and the phone measurement decides. The renderer is Godot's Compatibility renderer, which reaches the most Android phones.

## TECHNICAL INTERFACE
Narrative context only; no code tag. Read by whoever designs ARCHITECTURE-layer atoms for drawing and rendering, to understand why the constraint exists before proposing an alternative.

## EXPECTATION
N/A (narrative atom, not independently testable). Its content is corroborated by the ARCHITECTURE-layer atoms that eventually implement this decision, and by the REQUIREMENT/RULE atoms whose behaviour depends on it (e.g. req_platform_and_performance_targets).
