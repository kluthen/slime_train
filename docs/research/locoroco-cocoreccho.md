# Research: LocoRoco Cocoreccho! — gameplay, game design, mechanics

- **Date:** 2026-09-27
- **Produced by:** web-researcher (delegated by spec-writer)
- **Status:** raw research, verbatim. Not a decision — nothing here is settled until it lands in `specs/`.

> **Curator notes (spec-writer, not part of the researcher's output):**
> - Sources for this game are thin: period reviews, a few Kouno interviews, one academic paper and one blog dissection. There is no postmortem and no technical source on the blob physics.
> - Findings that bear directly on our design:
>   - The player is a **cursor** (a butterfly) that attracts LocoRoco, which maps to our touch-to-attract.
>   - There is **no whole-world tilt** in Cocoreccho!. Our tilt control comes from the main PSP series.
>   - Cocoreccho! has **no merging**, and a reviewer called that a flaw. Our fusing also comes from the main series.
>   - Gates need a **headcount**, and a short group gets blown back around a looping circuit instead of failing. This is very close to our basket-and-loop idea.
>   - Kouno called it an "interactive screensaver" with no enemies on the main route, which fits "almost idle".
>   - Critics said the controls asked the player to juggle too much at once.
> - The Fandom wiki page and the Eurogamer/IGN reviews could not be read directly, and no YouTube longplay link was verified. Both are worth a manual pass in a browser.

---

# LocoRoco Cocoreccho! (Sony Japan Studio, PS3/PSN, 2007) — Research Report

**Scope note up front:** Cocoreccho! is a small, single-level, ~2007 PSN download (JP title *Oideyo LocoRoco!! Boo Boo Cocoreccho!*). Primary sources are limited to period reviews, a couple of contemporary interviews with director Tsutomu Kouno, the Wikipedia article, the LocoRoco Fandom wiki, one academic paper, and one long-form blog "dissection." There is **no** developer postmortem, GDC talk, or technical paper specifically about Cocoreccho!, and no source documents its internal soft-body/physics code. I flag every claim's confidence level below.

---

## 1. Core loop and controls

**Verified (multiple independent sources: [MTV/Totilo](https://www.mtv.com/news/228mr8/mixed-motions-how-locoroco-on-ps3-takes-unexpected-twists), [Destructoid](https://www.destructoid.com/destructoid-review-loco-roco-cocoreccho/), [VideoGamer](https://www.videogamer.com/reviews/locoroco-cocoreccho-review/), [Wikipedia](https://en.wikipedia.org/wiki/LocoRoco_Cocoreccho!), [Fandom wiki](https://locoroco.fandom.com/wiki/LocoRoco_Cocoreccho!)):**
- Unlike the PSP mainline games (world-tilted with L/R shoulder buttons), Cocoreccho! drops whole-world tilt. Instead you steer a small pink butterfly ("Cocoreccho," sometimes miscalled "Buibui" — see correction below) with the **left analog stick**, moving it like a **mouse cursor in a point-and-click game** (Destructoid and MTV both make this comparison explicitly).
- Pressing a button (Circle, per the Fandom wiki) makes the butterfly emit a **ring of light/signal**; nearby sleeping/awake LocoRoco are attracted toward it and follow it. Straying outside its radius, LocoRoco wander off again (Destructoid: the attraction radius is "about a third of the screen" and was criticized as too small).
- Hovering the butterfly **over a specific character or object** and then **tilting or shaking the SIXAXIS controller** performs a *local*, contextual action on that thing (tip a platform, jolt a branch to drop a sleeping LocoRoco, work a MuiMui-powered device). This is a targeted/contextual use of tilt, not the "tilt the whole world" mechanic of the main series — VideoGamer's review explicitly notes "there's no tilting of the game world" in this game, which is consistent with the other sources once you separate "world tilt" from "targeted object tilt."
- **Goal:** wake/gather scattered LocoRoco and lead a big-enough group through gates to progress. Per Destructoid's review: you gather LocoRoco onto a "counting platform" that opens a gate once the required number is present; if the group is short, per MTV/Totilo's hands-on account, the LocoRoco **catch a gust of wind and are blown back to the start**, looping around the whole level, rather than the level failing.
- **Correction on "Buibui":** BuiBui are NOT the player's cursor character. They are a hostile/corrupted MuiMui creature type appearing only inside one bonus minigame (see §2). The cursor is the **Cocoreccho butterfly**. ([Villains Wiki – BuiBui](https://villains.fandom.com/wiki/BuiBui))
- **Session length:** Multiple critics note the whole game is a single continuous level playable start-to-end in a few hours; several call it too short to be a "full game" at the £1.99–$6.99 PSN price point ([GameSpot](https://www.gamespot.com/reviews/locoroco-cocoreccho-review/1900-6179869/), [Metacritic aggregation](https://www.metacritic.com/game/locoroco-cocoreccho/)). One NeoGAF poster got stuck needing 40 LocoRoco at a gate, suggesting some sections take real repeated effort.

**Kouno's stated intent** (verified, [Engadget/Joystiq TGS 2007 interview](https://www.engadget.com/2007-10-01-tgs07-interview-with-loco-rocos-tsutomu-kouno.html)): Sony's "interactive screensaver" label was his own idea — he wanted a world that's "as fun to watch as to play" and that keeps running/animating when the controller is set down; that's explicitly why there are **no enemies on the main route** (Moja are present but framed as an ambient hazard, not level-blocking foes — see §2).

---

## 2. Mechanics catalogue

**Gathering LocoRoco** (verified, [Fandom wiki](https://locoroco.fandom.com/wiki/LocoRoco_Cocoreccho!)):
- You start with 1 yellow LocoRoco (Kulche). Touching/attracting sleeping LocoRoco with the butterfly's signal wakes them; awake LocoRoco follow the butterfly and can, in turn, help rouse others nearby (consistent with your "awake wakes sleeping" design idea, though no source explicitly frames it as "awake LocoRoco wake other sleeping ones" — treat this as **plausible inference**, not confirmed mechanic text).
- Total collectible target across the level: **200 LocoRoco** (verified, multiple sources incl. NeoGAF screenshot thread and Fandom wiki).

**Threats / fail state** (moderately verified — corroborated across [Fandom wiki via gamepressure.com re-summary](https://www.gamepressure.com/games/locoroco-cocoreccho/zd2236) and a fan compilation site, but I could not load the primary Fandom page directly due to a paywall-style fetch error, so treat as **secondary-sourced**):
- **Moja** creatures eat LocoRoco that stray too close; a LocoRoco steered into a Moja with enough force can destroy it instead (same rule as the mainline games).
- If too many LocoRoco are lost to Moja, boss character **BonMucha/Bonmucho wakes up and the game ends** — i.e., there IS a fail state, unlike a true screensaver, though it's a "lose count" threshold rather than instant death. TV Tropes' framing that the whole game is Bonmucho's dream (ending when he wakes) is a nice narrative wrapper but is sourced to a fan wiki, not to Kouno or Sony directly — **flag as unconfirmed/secondary**.

**Gates and progression** (verified, Destructoid + MTV/Totilo hands-on accounts): each section posts a required LocoRoco headcount sign; gather that many onto a platform/through a gate to advance; falling short causes the group to be blown back around a level-spanning loop rather than a hard failure — effectively a soft-fail/retry loop, matching your "gates redirecting flow into a waiting basket" idea closely.

**Minigames** (verified, [Engadget/Joystiq interview](https://www.engadget.com/2007-10-01-tgs07-interview-with-loco-rocos-tsutomu-kouno.html), [Fandom/Villains wiki cross-check](https://villains.fandom.com/wiki/BuiBui)):
- Three hidden minigame types exist, reachable only via specific triggers (a launch pad, a giant bird/Bochollo, etc.), and only unlocked after finishing the main level once.
- Each has a high-score mechanism converting a currency called **picories** into extra LocoRoco, up to +15 per minigame, at a rate of 100 picories = 1 LocoRoco.
- Named minigame types found: a **Nyokki-launch minigame** where you catapult LocoRoco at BuiBui (hot-air-balloon hostile MuiMui variants, unique to this game) to knock them out and collect picories; a **Garnelo-balancing minigame** after being carried up a tree by Bochollo circles.
- These minigames are confirmed as **the only way to reach the full 200-LocoRoco count** — i.e., 100% completion requires engaging with all three, not just the main flow.

**Contact-triggered objects/creatures:**
- MuiMui-powered contraptions are activated/operated via SIXAXIS tilt/shake once the butterfly targets them (verified, multiple sources).
- Bochollo (bird-like carrier) wakes and flies when LocoRoco are thrown onto it via a MuiMui contraption, continuing until no LocoRoco remain aboard or it hits a height cap (verified, Fandom cross-summary via search).

**Merging/splitting — important negative finding:** Destructoid's review **explicitly states LocoRoco do NOT merge into larger blobs in Cocoreccho!**, and calls this a design weakness ("keeping a group together is tiring" without the option to consolidate them). This is a **deliberate departure from the mainline games**, where merge/split is core (see §7). If your game wants same-type fusing as a core mechanic, note that Cocoreccho! itself doesn't have it — you'd be reintroducing a mainline-series mechanic Cocoreccho! dropped, and a contemporary critic flagged its absence as a flaw. Worth knowing either way.

**Sound/music-making mechanics specific to Cocoreccho!:** No source describes a Cocoreccho!-specific "LocoRoco singing changes with count/colour" system distinct from the mainline series. Treat the "does the soundtrack respond to number/colour of LocoRoco present" question as **confirmed only for the mainline PSP games** (see §4), **not independently verified for Cocoreccho!**.

---

## 3. Level structure

**Verified (Engadget/Joystiq interview, Mandible dissection, NeoGAF):**
- The entire game is **one single, large, continuous scene/structure** — not discrete stages. Kouno confirmed only one level exists, with no DLC levels planned at launch.
- The blogger at Mandible.net describes it as one enormous branching "Thing" containing spinning, sloped, and hole-punctured structures reused from PSP-era set pieces, with large ambient circuits where LocoRoco move on their own (rolling downhill, jumping, blown by wind) even without player input — this is the literal implementation of the "screensaver" idea.
- **Progression gating:** advancing requires hitting per-section LocoRoco headcounts at gates (§2); beating the main route once **unlocks hidden areas containing the three minigames**, which are the only path to full (200/200) completion — i.e., there's a "beat it once, then go for 100%" replay structure.
- **Camera:** per Mandible's critique, the camera is largely static/fixed per screen and does not proactively reframe on its own, which the reviewer felt undercut the "screensaver" ambient-watching premise.
- **Leaderboards** ([gamepressure.com summary](https://www.gamepressure.com/games/locoroco-cocoreccho/zd2236)): online leaderboards for total score and for "time attack" (fastest time to reach the goal) — this is the closest thing to a formal "ending"/replay-value hook; I found no evidence of a scripted cutscene ending beyond the Bonmucho-wakes framing (unconfirmed, §2).
- **Length/pacing criticism:** Multiple reviewers (GameSpot, Destructoid, several Metacritic-aggregated UK reviews) say reaching meaningful content/new areas is slow — the Mandible review specifically estimates 15–30 minutes of work to reach some rewarding moments, calling it impractical for genuinely casual/idle play despite the "screensaver" pitch.

---

## 4. Music and audio design

**Composers (verified, [VGMO](https://vgmonline.net/locoroco/), [Discogs](https://www.discogs.com/master/2967205-SIE-Sound-Team-Locoroco-Original-Soundtrack)):** Nobuyuki Shimizu and Kemmei Adachi composed and performed most of the mainline LocoRoco (2006) and LocoRoco 2 soundtracks; Kouji Niikura contributed a few tracks. Lyrics by Adachi and Kouno. I found **no dedicated soundtrack credit breakdown specific to Cocoreccho!** — treat Cocoreccho!'s score as very likely reusing/extending the same team and invented-language approach, but this is an **inference**, not a confirmed credit.

**Invented "LocoRoco language"** (verified, Kouno interview, Engadget/Joystiq TGS 2007): Kouno deliberately built a fictional pan-linguistic gibberish for lyrics/dialogue by harvesting words across many real languages and reshaping them phonetically — explicitly to avoid localization and let every region "share the same experience."

**Layering by colour/count** — this is confirmed **only for the mainline games**, via the academic paper (Westecott 2009, *Eludamos*, see full text link below): each mainline LocoRoco colour (Kulche/yellow, Priffy/pink, Tupley/blue, Pekerone/red, Budzi/black, Chavez/green, Viole/purple in LR2) has a **distinct singing voice/vocal style**, and colour composition of your group is described as affecting "the audio-visual experience." Music also functions diegetically — signaling threats/opportunities, and characters "sing to unlock secrets" (a call-and-response mechanic where LocoRoco singing reveals hidden content). I could **not confirm** whether Cocoreccho! specifically implements per-colour/count music layering as a live system; no review or wiki source describes this explicitly for this title.

**Design commentary:** Kouno stated (Joystiq/Engadget interview) the score draws on reggae/soul/R&B influences he personally curated for the composer, an explicit reaction against generic game-music conventions. Destructoid's reviewer likened the audio experience to Disneyland's "It's a Small World" — cited as a *positive*, describing it as something he "still loves."

---

## 5. Art direction

**Verified across multiple reviews (GameSpot, Destructoid, Mandible, gamepressure):**
- Flat, simplified, vector-like 2D "cutout" shapes; bright pastel colour scheme; described by GameSpot as "outstanding," by Destructoid as "a visual feast," especially on large widescreen displays.
- Runs at full 1080p (native PS3 hardware capability, unusual for a small PSN title at the time) — verified, multiple sources.
- Kouno confirmed (Gamasutra interview) the flat 2D cartoon style was chosen deliberately over polygons/realistic lighting for budget reasons (no costly textures, arbitrary scalability) as well as for a "cheerful world" tone, after testing claymation and fabric-texture prototypes that were dropped as too costly.
- **Camera:** static/fixed per screen rather than dynamically panning/zooming to track action (contrast with the mainline PSP games, where Westecott's paper explicitly documents a dynamic, zooming/panning camera). This static-camera choice in Cocoreccho! was specifically criticized (Mandible) as undermining the "ambient screensaver" premise.

---

## 6. Design intent & reception

**Developer intent (verified, primary interviews):**
- [Joystiq/Engadget TGS 2007](https://www.engadget.com/2007-10-01-tgs07-interview-with-loco-rocos-tsutomu-kouno.html): "interactive screensaver" was Kouno's own framing; explicit goal of a world that's fun to *watch*, that keeps running when you set the controller down, hence no enemies blocking the main route.
- [Develop UK keynote coverage, Game Developer/Gamasutra, July 2007](https://www.gamedeveloper.com/game-platforms/develop-uk-i-locoroco-i-s-kouno-talks-innovative-design): mainline design mandate was "easy to play, fun, and dramatic visuals even using only 2D graphics," explicitly targeting non-gamers and wanting "a peaceful game" as reaction against overly complex titles.
- [Gamasutra interview, 2009](https://www.gamedeveloper.com/design/the-thoughtful-design-of-locoroco-tsutomu-kouno-speaks): reiterates the non-gamer/international-audience target; states the game is "simple on the surface but with depth" (100% completion requires real thought) — a philosophy directly applicable to a kids' game that also rewards adult replay.

**Reception (verified via Wikipedia's citation table + individual review fetches):**
- Metacritic aggregate: **72/100** ("mixed or average").
- Eurogamer: 9/10 (highest — full text not independently fetchable, paywalled/blocked; score only confirmed via Wikipedia citation).
- VideoGamer.com: 8/10 — praised value at the price point but called it fundamentally more like *Lemmings* than the original LocoRoco, and explicitly noted the loss of whole-world tilt.
- IGN: 6/10 (full review text not retrievable; score only, via Wikipedia).
- GameSpot (Kevin VanOrd): praised art/level design ("outstanding," "clever level layout," compared favourably-but-differently to *flOw*); core criticism was brevity and value-for-money at $6.99, plus frustration when stacking/coordinating LocoRoco who "don't wish to cooperate."
- Destructoid (8BitBrian): 5.5/10 — praised art and audio strongly, but the harshest mechanical critique: the split control scheme (steering the butterfly + managing SIXAXIS tilts) was "too much with all the buttons available," the attraction radius too small, no merging mechanic (a specific regression vs. mainline), and fans of the original found it "wasn't really fun." Suggested motion-only controls (cf. *flOw*) would have worked better.
- GamesRadar+: 3/5 (score only, not fetched in full).
- Common threads across critics: **short length relative to price**, **controls trying to do too much at once** (steering + targeted-tilt + calling), and **a fundamentally different, more indirect/puzzle-like feel than the beloved PSP original** — several reviewers explicitly warn PSP fans not to expect the same game.
- No source discusses accessibility for young children specifically; this game was not marketed or reviewed as a children's product per se (PEGI 3 rating only, per gamepressure.com).

---

## 7. Main LocoRoco series mechanics relevant to your design (context, not Cocoreccho! itself)

**Verified, primarily via [Westecott (2009), "I ♥ LocoRoco," *Eludamos* 3(1)](https://septentrio.uit.no/index.php/eludamos/article/download/vol3no1-9/5881?inline=1) and the Develop UK keynote coverage:**
- Core control: **tilt the world**, not the character, via L/R shoulder buttons; a full press-both-shoulders "bounce" input; and a dedicated **split/recombine command**.
- Splitting lets the group squeeze through tight gaps; a minimum LocoRoco count is required for certain actions (explicit "threshold" mechanic you can cite directly).
- Growth mechanic: eating berries grows the LocoRoco; size affects both movement capability and effective "health" (how much damage from Burrs/Moja it can absorb before losing individuals); losing the last LocoRoco = game over.
- Colour composition of a merged group changes its vocal/singing character but **not gameplay function** — a clean, verified precedent for "cosmetic variety without added rules complexity," useful for a game aimed at very young children.
- Singing is diegetically tied to secret-reveal mechanics — characters "sing to unlock secrets," matching your "zones revealed when slimes approach" idea closely, though in the mainline series it's explicitly *singing*-triggered rather than merely *proximity*-triggered.
- No HUD; progress is legible purely through LocoRoco size — a strong precedent for minimal-UI design appropriate to a 3–5-year-old audience.

**Soft-body implementation — could NOT find primary technical documentation.** No GDC talk, published paper, or official technical postmortem exists in the sources I could reach. What's available:
- Kouno, in a 2006 [Pocket Gamer interview](https://www.pocketgamer.com/locoroco/meet-the-psps-mr-locoroco-tsutomu-kouno/), states character behavior is not keyframed/hand-animated but computed live: "the characters' actions are not determined by certain motion data... I am trying to realize LocoRoco by physical calculations," exploiting PSP's curved-surface rendering and processing speed. This is the closest thing to a technical statement from the developer, but it's a short interview quote, not a technical breakdown.
- Secondary/unofficial analysis: an animation-design blog ([Game Anim, "Basics: Look-At System"](https://www.gameanim.com/2007/09/09/looko-roco/)) and Grokipedia both characterize LocoRoco as an early example of a fully procedural (zero hand-animation), physics-driven squash-and-stretch character system — **Grokipedia is AI-generated and should not be treated as an independent source**; I flag it as unverified color, not evidence.
- Community reverse-engineering discussion (GameDev.net threads, 2006/2009) recommends Thomas Jakobsen's **Verlet-integration / stiff-constraint** approach (his GDC 2001 talk, written for *Hitman*, not LocoRoco) and pressure-based 2D soft-body models (maintaining blob area/volume) as the standard techniques that would produce this kind of behavior — this is **general soft-body technique background, not confirmed as LocoRoco's actual implementation**.
- **Bottom line: there is no verifiable primary source describing LocoRoco's actual soft-body code.** Any claim about "how it was actually implemented" beyond Kouno's one quote above should be treated as informed speculation from the wider game-dev community, not established fact.

---

## 8. Longplay / walkthrough / wiki sources

- [LocoRoco Wiki (Fandom) — Cocoreccho! page](https://locoroco.fandom.com/wiki/LocoRoco_Cocoreccho!) (repeatedly returned HTTP 402 on direct fetch in this session — likely a Fandom-side paywall/bot-block bug, not a dead page; accessible via a normal browser)
- [LocoRoco Wiki — Cocoreccho article, mirror](https://locorocouniverse.fandom.com/wiki/LocoRoco_Cocoreccho!)
- [LocoRoco Wiki — Nyokki NyoNyokki minigame page](https://locoroco.fandom.com/wiki/Nyokki_NyoNyokki)
- [LocoRoco Wiki — Bochollo page](https://locoroco.fandom.com/wiki/Bochollo)
- [Villains Wiki — BuiBui](https://villains.fandom.com/wiki/BuiBui) (accessible, used above)
- [TV Tropes — LocoRoco (Video Game)](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/LocoRoco)
- No dedicated YouTube longplay URL could be verified through text search in this session (search tooling here doesn't reliably surface/validate YouTube links) — I'd recommend searching YouTube directly for "LocoRoco Cocoreccho longplay" or "ロコロコ コチョコチョ 実況" once you have browser access; I cannot vouch for any specific video I didn't independently verify.

---

## Design takeaways for a kids' (3–5) tilt+touch slime game — my interpretation, not sourced claims

- Cocoreccho!'s own critics converged on one lesson worth heeding: **combining a moving cursor + targeted contextual tilt + a separate "call/attract" action was "too much to juggle at once."** For 3–5-year-olds, simplify further than Cocoreccho! did — pick tilt-to-redirect-flow and touch-to-attract as your two verbs and resist adding a third simultaneous input.
- Cocoreccho! dropping merge (from the mainline games) and being criticized for it suggests merge/fuse is a well-loved, expected part of the "blob" fantasy — safe to keep it in your design, and you're not fighting franchise expectations by including it.
- The "gate needs N units, else blown back around a loop" mechanic (confirmed via the Totilo/MTV hands-on) is a strong, kid-friendly precedent for your "gates redirecting flow into a waiting basket" idea: failure is a gentle retry-loop, not a hard game-over — appropriate for very young players.
- No-HUD, size/count-as-feedback design (mainline series, Westecott) is a good precedent for legibility with pre-readers.
- Diegetic, singing/proximity-triggered secret reveals (mainline series) map directly onto your "zones revealed when slimes approach" mechanic — you have a validated precedent to point to.
- Cocoreccho!'s actual fail state (lose-too-many-to-Moja triggers an ending) is worth deliberately *not* copying for a 3–5 audience — no hostile creatures / no failure state at all is more defensible for that age group, and is arguably closer to what Kouno's own "no enemies on the main route" screensaver philosophy already gestures toward.
- Given no source documents Cocoreccho!'s soft-body/blob physics implementation, plan to prototype your own merge/split/soft-body feel from scratch (Verlet/spring-mass techniques referenced in §7) rather than assuming there's a known reference implementation to copy.

---

## Full source list

- [LocoRoco Cocoreccho! — Wikipedia](https://en.wikipedia.org/wiki/LocoRoco_Cocoreccho!)
- [Metacritic — LocoRoco Cocoreccho! critic reviews](https://www.metacritic.com/game/locoroco-cocoreccho/critic-reviews/)
- [GameSpot review (Kevin VanOrd)](https://www.gamespot.com/reviews/locoroco-cocoreccho-review/1900-6179869/)
- [Destructoid review (8BitBrian)](https://www.destructoid.com/destructoid-review-loco-roco-cocoreccho/)
- [VideoGamer.com review (Wesley Yin-Poole)](https://www.videogamer.com/reviews/locoroco-cocoreccho-review/)
- [MTV Multiplayer — "Mixed Motions" hands-on (Stephen Totilo, Aug 31 2007)](https://www.mtv.com/news/228mr8/mixed-motions-how-locoroco-on-ps3-takes-unexpected-twists)
- [Engadget/Joystiq — TGS 2007 Kouno interview](https://www.engadget.com/2007-10-01-tgs07-interview-with-loco-rocos-tsutomu-kouno.html)
- [Game Developer/Gamasutra — Develop UK keynote coverage](https://www.gamedeveloper.com/game-platforms/develop-uk-i-locoroco-i-s-kouno-talks-innovative-design)
- [Game Developer/Gamasutra — "The Thoughtful Design of LocoRoco" (2009 interview)](https://www.gamedeveloper.com/design/the-thoughtful-design-of-locoroco-tsutomu-kouno-speaks)
- [Pocket Gamer — "Meet the PSP's Mr LocoRoco, Tsutomu Kouno"](https://www.pocketgamer.com/locoroco/meet-the-psps-mr-locoroco-tsutomu-kouno/)
- [Westecott, "I HEART LocoRoco," Eludamos 3(1), 2009 — full PDF](https://septentrio.uit.no/index.php/eludamos/article/download/vol3no1-9/5881?inline=1)
- [Mandible.net — "LocoRoco: Cocoreccho dissection" (2008 blog)](https://www.mandible.net/2008/07/27/locoroco-cocoreccho-dissection/)
- [LocoRoco Wiki (Fandom) — Cocoreccho! page](https://locoroco.fandom.com/wiki/LocoRoco_Cocoreccho!)
- [Villains Wiki — BuiBui](https://villains.fandom.com/wiki/BuiBui)
- [gamepressure.com — LocoRoco Cocoreccho! database entry](https://www.gamepressure.com/games/locoroco-cocoreccho/zd2236)
- [NeoGAF — Loco Roco Cocoreccho! Impressions thread](https://www.neogaf.com/threads/loco-roco-cocoreccho-impressions.192279/)
- [VGMO — LocoRoco soundtrack review](https://vgmonline.net/locoroco/)
- [Discogs — SIE Sound Team, LocoRoco Original Soundtrack credits](https://www.discogs.com/master/2967205-SIE-Sound-Team-Locoroco-Original-Soundtrack)
- [TV Tropes — LocoRoco (Video Game)](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/LocoRoco)
- [Game Anim — "Basics: Look-At System" (animation analysis, unofficial)](https://www.gameanim.com/2007/09/09/looko-roco/)

**Unreachable/paywalled during this session (content not independently verified beyond snippet summaries):** Eurogamer's full review text, IGN's full review text, the Fandom Cocoreccho! wiki page's direct HTML (returned HTTP 402 each attempt), web.archive.org (blocked in this environment).
