---
id: domain_parent_lock_offline
status: DRAFT
human_name: A best-effort
type: DOMAIN
layer: BUSINESS
version: 1.0
parents:
  - [[domain_architecture_rationale]]
dependents: []
priority: 2
tags: [architecture,rationale,parent-lock]
---

# A best-effort

## INTENT
Record why the parent lock is best-effort and fully offline.

## THE RULE / LOGIC
The parent lock is best-effort and fully offline: screen pinning, custom code, and stored clocks cover the real risk of a small child wandering out of the app, without requiring the parent to provision the phone as a managed device; code recovery goes through the phone's own screen lock, so no server, website or account exists, and there is no analytics, no ads and no network permission.

## TECHNICAL INTERFACE
Narrative context only; no code tag. Read by whoever designs ARCHITECTURE-layer atoms for the parent lock and parent access, to understand why the constraint exists before proposing an alternative.

## EXPECTATION
N/A (narrative atom, not independently testable). Its content is corroborated by the ARCHITECTURE-layer atoms that eventually implement this decision, and by the REQUIREMENT/RULE atoms whose behaviour depends on it (e.g. req_parent_gate_and_access, req_screen_pinning, rule_no_network_connection).
