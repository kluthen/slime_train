---
id: contract_atd
status: DRAFT
layer: BUSINESS
human_name: Contract
tags: [contract,guarantees]
version: 1.1
priority: 5
parents: []
dependents: []
type: CONTRACT
---

# Contract

## INTENT
Record what Slime Train v1 currently guarantees to anything outside it, as a versioned surface. This contract covers v1 only; later versions may revise it, and any such revision needs explicit human confirmation together with the corresponding version bump.

## THE RULE / LOGIC
This contract guarantees, for v1 only: no network connection is ever made by the app (rule_no_network_connection, STABLE); v1 makes no purchases available inside the app (rule_no_in_app_purchases, STABLE); a level's save is never wiped by an app update (rule_saves_never_wiped, STABLE). These three are the contract's first guarantees, confirmed by the user as settled for v1. No other BUSINESS or ARCHITECTURE atom is yet STABLE, so nothing else currently sits on the guaranteed surface per the Contract Surface Grid (only STABLE atoms are eligible). A later version of the app may revise or drop any of these guarantees, but only with explicit human confirmation and a corresponding version bump to this file in the same change.

## TECHNICAL INTERFACE
Read by documentalist before revising, retiring or promoting any atom the Contract Surface Grid (ATD.md 1.4) classifies as surface. Never listed in any atom's parents/dependents.

## EXPECTATION
version stays 1.1 until another STABLE surface atom is confirmed by a human and promoted, or an existing guarantee is revised or dropped for a later version, at which point this file's version takes the corresponding MINOR (additive) or MAJOR (breaking) bump in the same change.
