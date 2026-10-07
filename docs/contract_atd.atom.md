---
id: contract_atd
status: DRAFT
layer: BUSINESS
human_name: Contract
tags: [contract,guarantees]
version: 1.3
priority: 5
parents: []
dependents: []
type: CONTRACT
---

# Contract

## INTENT
Record what Slime Train v1 currently guarantees to anything outside it, as a versioned surface. This contract covers v1 only; later versions may revise it, and any such revision needs explicit human confirmation together with the corresponding version bump.

## THE RULE / LOGIC
This contract guarantees, for v1 only: no network connection is ever made by the app (rule_no_network_connection, STABLE); v1 makes no purchases available inside the app (rule_no_in_app_purchases, STABLE); a level's save is never wiped by an app update (rule_saves_never_wiped, STABLE). These three are the contract's first guarantees, confirmed by the user as settled for v1. Version 1.2 (the user's, 2026-10-07) records rule_saves_never_wiped's reworded handling of slimes a migration displaces: they are re-placed when their spot or a free spot exists, else lost; the no-wipe guarantee itself is unchanged. Version 1.3 (the user's, 2026-10-07) adds the train's two climb rules, confirmed by the user as built: a train slime standing between hops on a rise of the outgoing route doesn't slide back down it (rule_train_climbs_without_sliding_back, STABLE), and when a train slime takes off, the train slime right behind it within a hop's reach hops almost at once (rule_train_relay_on_take_off, STABLE). No other BUSINESS or ARCHITECTURE atom is yet confirmed onto the guaranteed surface per the Contract Surface Grid (only STABLE atoms are eligible). A later version of the app may revise or drop any of these guarantees, but only with explicit human confirmation and a corresponding version bump to this file in the same change.

## TECHNICAL INTERFACE
Read by documentalist before revising, retiring or promoting any atom the Contract Surface Grid (ATD.md 1.4) classifies as surface. Never listed in any atom's parents/dependents.

## EXPECTATION
version stays 1.3 until another STABLE surface atom is confirmed by a human and promoted, or an existing guarantee is revised or dropped, at which point this file's version takes the corresponding MINOR (additive or a refined wording) or MAJOR (breaking) bump in the same change.
