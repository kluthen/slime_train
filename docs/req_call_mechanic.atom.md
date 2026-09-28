---
id: req_call_mechanic
status: DRAFT
type: REQUIREMENT
human_name: The call and free slimes
tags: [call,free-slime]
parents:
  - [[req_slime_states]]
version: 1.0
layer: BUSINESS
priority: 5
dependents:
  - [[rule_left_alone_and_lost]]
---

# The call and free slimes

## INTENT
Define the call and the three phases a free slime goes through after answering one.

## THE RULE / LOGIC
A tap on open ground is a call. Every awake slime within the call radius (about half the screen width) answers it, train slimes included, and becomes free; this is needed because at the start the only awake slime is on the loop. A free slime goes through three phases: (1) Answering the call - it hops toward the call point until it reaches it, or gives up after about 8 s; a new tap replaces the call point; answering slimes gather in a clump, which is how fusion usually starts. (2) Unsure - for up to about 15 s after its call ends, it stays near the last call point with small lazy hops. (3) Heading back - it hops back toward the loop, mostly downhill but knowing the shortest way by following its area's route back, and rejoins the train when it reaches the loop. Physics applies in every phase; on a steep slope its hops can't hold it and it may roll.

## TECHNICAL INTERFACE
Parented to req_slime_states. Tapping a sleeper is a call centred on it (see req_waking_sleepers).

## EXPECTATION
A tap on open ground makes every awake slime within the call radius turn toward it and hop toward the point; each gives up after about 8 s if it can't reach it; a new tap replaces the point for every answering slime (definition of done item 3). After its call, a free slime lingers up to about 15 s, then heads back by its area's route back and rejoins the train on reaching the loop (definition of done item 4).
