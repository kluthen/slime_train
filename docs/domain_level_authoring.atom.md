---
id: domain_level_authoring
status: DRAFT
tags: [architecture,rationale,levels]
parents:
  - [[domain_architecture_rationale]]
dependents: []
type: DOMAIN
layer: BUSINESS
version: 1.0
priority: 2
human_name: Levels are content
---

# Levels are content

## INTENT
Record why levels are built in Godot's own editor from reusable components, with no custom level editor and no per-level code.

## THE RULE / LOGIC
There is no custom level editor: levels are Godot scenes built in Godot's own editor, with curved terrain from paths and collision polygons, and every interactive element is a reusable, property-configured component with no per-level scripts, so that extra levels (possibly paid) stay content rather than code.

## TECHNICAL INTERFACE
Narrative context only; no code tag. Read by whoever designs ARCHITECTURE-layer atoms for levels, terrain and interactive components, to understand why the constraint exists before proposing an alternative.

## EXPECTATION
N/A (narrative atom, not independently testable). Its content is corroborated by the ARCHITECTURE-layer atoms that eventually implement this decision, and by the REQUIREMENT/RULE atoms whose behaviour depends on it (e.g. req_level_design_rules, req_interactive_objects_general).
