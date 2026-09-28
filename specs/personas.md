# Personas

Status: draft v1

Who Slime Train is for, what each person is trying to get done, and the
circumstances they use it in. These are built from the real people the user
has in mind, not invented profiles. This is a standing document that
describes the product, so it is kept up to date across versions and never
archived.

Personas are not roles. What each kind of user *may do* (the child vs the
parent behind the code) belongs to the parent gate rules (D30, D57), not here.

## Primary: the newcomer (3 years old)

**Who:** a 3-year-old girl who has **never played a video game**. She is the
main player.

**Context:** a Samsung Galaxy S20 FE. When and where the phone is handed over,
and whether she holds it or it lies on a table, are still open (O15).

**Goals:**
- See something pleasant happen and keep watching it.
- Touch the screen and see the world answer her straight away.
- Find out on her own what touching does. There is no one to explain it and
  she can't read.

**Abilities and limits (proposed, to check against the real child):**
- Taps well. Holding, dragging and precise aiming are unreliable.
- Doesn't read. Digits are not a given.
- Holding the phone steady, or tilting it on purpose, is uncertain at 3.
- Short bursts of attention. She may put the phone down and come back.

## Secondary: the watching sibling (2 years old)

**Who:** her 2-year-old little brother. He mostly watches over her shoulder.

**Goals:**
- Watch the slimes.
- Probably poke the screen too, sometimes at the same moment as his sister.

**What it means:** the game has to be pleasant to watch without playing, and
must stay safe and unbroken whatever gets poked. How the game treats two
fingers from two children at once is O48.

## Secondary: the early player (4 years old)

**Who:** children of friends, about 4, using a similar phone.

**Goals:**
- Play more on purpose: call slimes, fuse them, fill a basket, open the next
  section.
- Explore off the loop to find more slimes.

**Limits:** may already know digits. The code is 6 digits, and D1 accepts that
risk.

## Supporting: the parent

**Who:** the adult who owns the phone, buys the game and sets it up: the user,
and the friends' parents.

**Goals:**
- Hand over a calm, safe activity for a limited time, and trust it to end on
  its own.
- Trust that the child can't leave the app, change anything or buy anything.
- Set it up once, easily, and never have to think about it again.
- Take the phone back, or give more time, whenever they choose.

## How the settled spec serves these goals

| Goal | Served by |
|---|---|
| Newcomer: something pleasant to watch | interactive screensaver, idle camera, screensaver mode (D2, D4, D53, D59) |
| Newcomer: instant answer to a touch | tap-to-call, with any tap anywhere doing something (D15, D46) |
| Newcomer: nothing to fail | no failure states; a lost slime just comes back (D10, D36) |
| Newcomer: learn with no explanation | **gap:** nothing yet. How a first-time player discovers the call is O49 |
| Sibling: safe to poke | parent gate on every parent button (D57); two touches at once is O48 |
| Early player: goals to reach | sleepers, fusion, the frontier-gate set, exploration (D13, D20, D54, D45) |
| Parent: bounded time | 15 min real-time sessions, bedtime, 10 min cooldown (D29, D44, D56) |
| Parent: the child can't get out | screen pinning plus the parent code (D1, D30) |
| Parent: easy setup | one-time setup at first launch (D55) |
| Parent: in control | wake early, leave and settings behind the code (D57) |
