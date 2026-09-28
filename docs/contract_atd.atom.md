---
id: contract_atd
status: DRAFT
layer: BUSINESS
human_name: Contract
tags: [contract,guarantees]
version: 1.0
priority: 5
parents: []
dependents: []
type: CONTRACT
---

# Contract

## INTENT
Record what Slime Train v1 currently guarantees to anything outside it, as a versioned surface, kept thin until atoms are actually promoted to STABLE.

## THE RULE / LOGIC
No atom in this project is yet STABLE, so no BUSINESS or ARCHITECTURE atom currently sits on the guaranteed surface per the Contract Surface Grid (only STABLE atoms are eligible). This contract therefore currently guarantees nothing formally.

Three candidate non-negotiable invariants were identified during v1 spec ingestion as good fits for this surface once confirmed, because the master spec and access model state them as absolute, day-one constraints rather than features still being designed: no network connection is ever made by the app (rule_no_network_connection); v1 makes no purchases available inside the app (rule_no_in_app_purchases); a level's save is never wiped by an app update (rule_saves_never_wiped). Each is drafted as its own BUSINESS-layer RULE atom, parented to the requirement it constrains, and left at DRAFT status. None is marked STABLE and none is yet part of this contract's guaranteed surface: that promotion needs explicit human confirmation that each is truly settled now, not aspirational, together with the MINOR version bump this file would then take.

## TECHNICAL INTERFACE
Read by documentalist before revising, retiring or promoting any atom the Contract Surface Grid (ATD.md 1.4) classifies as surface. Never listed in any atom's parents/dependents.

## EXPECTATION
version stays 1.0 until a candidate RULE atom above (or any other STABLE surface atom) is confirmed by a human and promoted, at which point this file's version takes the corresponding MINOR (additive) or MAJOR (breaking) bump in the same change.
