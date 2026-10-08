---
id: rule_no_network_connection
status: STABLE
tags: [privacy]
version: 1.1
type: RULE
human_name: No network connection
parents:
  - [[req_parent_gate_and_access]]
dependents: []
layer: BUSINESS
priority: 5
---

# No network connection

## INTENT
Guarantee that the app makes no network connection of any kind.

## THE RULE / LOGIC
Slime Train has no accounts, no server and no network: there is no login, no remote access and no multi-device concern. Code recovery uses the phone's own screen lock, so no server, website or account exists. There is no analytics, no ads, and no network permission. No support or remote access exists, so nobody can act on the phone from outside the app.

## TECHNICAL INTERFACE
Parented to req_parent_gate_and_access. On contract_atd's guaranteed surface (STABLE, v1), confirmed by the user as a v1 guarantee (2026-10-07).

## EXPECTATION
The app makes no network connection (definition of done item 27).
