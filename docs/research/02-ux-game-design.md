# 02 — UX & Game Design Research

> **Method note:** Live web search was **unavailable from this environment** (Google-fronted
> hosts and search endpoints are geo-blocked, as documented in `00-environment.md`). This
> document therefore synthesizes **publicly documented, widely-reported design patterns**
> from the named games — their design talks, developer blogs, press analysis, and standard
> game-design literature — rather than freshly-fetched sources. Patterns below are
> **analyzed and re-derived, never copied**; nothing recommends reproducing copyrighted
> assets, characters, or layouts. The output of this document is an **original** design
> language and economy inspired by these patterns.

---

# Part 1 — Design patterns from successful games

## 1.1 Clash Royale / Brawl Stars (Supercell) — the short-session vertical loop

Supercell's games are the reference for **sessions measured in minutes** and a **hub → battle → reward** rhythm.

- **Navigation:** a single vertical "battle" path dominates. The main screen IS the hub — your profile, chests, shop, and a big **primary play button** — so there is exactly one decision per session: *play now, or manage*. No nested menus between launch and action.
- **Session loop:** Play (2–3 min) → **reward screen** (crate/chest opening with anticipation build-up) → slot fills on a timer → next battle. Each session ends on a **positive peak** (a revealed reward), which is the emotional hook for the next launch.
- **Reward slots (crates/star drops):** limited openable slots fill over time. The *full slot* is a persistent "you have a reward waiting" state — an anticipation engine that works **without notifications** (it's visible on-screen). This is the single most transplantable pattern for an offline-first game.
- **Currencies:** **soft** (coins — spend freely, abundant) + **hard** (gems — scarce, convertible, never required to play). Hard currency can *speed up* timers but never gates core gameplay. Clean separation of "abundant fun" and "premium value."
- **Shop:** a rotating daily shop with a few items + a weekly refresh cadence. Scarcity is **time-based, not money-based**, so a free player always has something to check daily.
- **Progression:** card/troop levels create a long, shallow treadmill; **trophy/league ladder** resets periodically to create seasons. Ladders give short-term and long-term goals simultaneously.
- **Feedback density:** every tap produces sound + haptic + scale animation. Damage numbers, hit-stop, screen shake. *Every action answers with a physical response.*
- **Onboarding:** first battle is effectively a scripted tutorial disguised as a win; new systems unlock gradually over the first week, never dumped at once.

**Lesson for us:** one-dominant-action hub, sessions that always end on a revealed reward, soft/hard currency split, time-scaled daily shop, and heavy per-tap feedback.

## 1.2 Candy Crush Saga (King) — the map, the lives, and the "one more try"

The most instructive game for **level gating, failure psychology, and casual onboarding**.

- **Map-based level select:** a long horizontal path with nodes; themes repeat every N levels with color/decoration swaps. The map *is* progression — you literally see distance traveled. Branching side-routes hold bonus/challenge nodes.
- **Lives system (soft gate):** 5 lives, one lost per failure, ~30 min regen. This is the canonical **soft gate**: it creates scarcity and return value *without* a hard paywall, and it invented the social "send/receive lives" loop. For a purely offline single-player app we soften this further (see §2.3).
- **"One more move" post-fail upsell:** after a failed level, the player is shown how close they were — a tiny nudge that turns failure into motivation. Combines a *loss-aversion* push with an optional continue (boosters).
- **Pre-level shop & booster inventory:** you see what you could bring *into* the level — purchase happens in the decision context, not in a separate store.
- **Booster logic:** special items that *cheat* a hard rule (a move extra, a color clear). Boosters are a coin sink and a skill-leveller simultaneously.
- **Combo juice:** matching 4/5 same-color produces a bigger piece with splash effects and screen clears — the **juice scales with the size of the achievement**. Bigger combo = bigger particles, sound, screen impact.
- **Daily rewards & timed events:** a daily reward wheel/calendar plus rotating events keep the map fresh without content updates.
- **Celebration sequences:** level-win = confetti, animated stars, layered "You did it" → rating → next. The reward screen is *staged in phases*, never a single flat dialog.

**Lesson for us:** map-as-progression, soft lives, failure→motivation framing, booster-as-coin-sink, juice that scales with achievement size, phased celebration screens.

## 1.3 Monument Valley (ustwo) — diegetic UI and beauty-as-retention

A premium, near-economy-free counterweight proving that **minimal UI can be its own reward**.

- **The world is the menu:** no HUD bar, no tutorial popups — guidance comes from architecture (light, paths, the puzzle itself). Silent onboarding by *curiosity*, not instruction.
- **Chapter-select islands:** levels are sparse, art-directed chapters; choosing a level is a *walk*, not a list.
- **Restraint as polish:** motion is slow, deliberate, ambient. Sound is a sparse score with diegetic events. The lack of 12 popup types is itself a premium-feel signal.
- **Failure is frictionless:** an undone move just reverses; no "Game Over" — the state machine forgives constantly, keeping flow.

**Lesson for us:** for flagship/special games, allow **diegetic UI** (hints in-world, no overlay), make failure cheap, and treat *emptiness* (whitespace, silence) as a design tool rather than something to fill.

## 1.4 Alto's Odyssey — flow-state design and anti-anxiety pacing

- **One-touch mastery:** the whole game is two inputs. Complexity comes from *environment*, not controls.
- **Combo via trick-strings:** chaining tricks across jumps builds a combo meter that increases score multiplier *and* refills the (soft) dash. Combo is functional, not just cosmetic.
- **Zen mode:** an explicitly no-fail variant for pure flow. Proves that a game can offer *relaxation* as a first-class mode, widening audience beyond hardcore players.
- **Per-run goals, not endless score only:** each run has 3 explicit camera targets (e.g., "reach the ruins"), so there's always a *named* short-term objective alongside the score.
- **Progressive difficulty through biome/condition variety** (night, storms, temperature) rather than raw speed only — difficulty *flavors* the world instead of just punishing.
- **Currencies:** coins collected in-run fund character/item upgrades — earning and spending happen in the *same loop* (no menu-driven farming).
- **Unlockable characters** as long-term goals, each with a different ability — same underlying game, different "skin + mechanic" each run.

**Lesson for us:** one-input games are accessible; tie combo to a *function* (meter/multiplier); offer a no-fail mode; give each run named goals; vary difficulty through world-state, not just speed; let cosmetics change the feel, not just the look.

## 1.5 Duolingo — the streak, the quest, and notification engineering

The single strongest **habit-building** machine in consumer software.

- **The Streak:** one daily action keeps it alive. Lost-streak anxiety (plus Streak Freeze purchasable items) is the most copied retention mechanic in the industry. Its power: it converts *engagement* into *identity* ("I have a 97-day streak").
- **Daily Quests:** exactly **3 small goals** per day (earn X XP, complete Y lessons). Bounded, achievable, replaceable — a daily to-do that feels light.
- **Leagues/leaderboards:** weekly groups with promotion/relegation — *asynchronous* competition that works even when you and your peers never meet live.
- **The Path:** the 2023+ redesign replaced the skill tree with a single linear path with side branches — fewer decisions, more momentum. Later, branching optional content was reintroduced for choice. Lesson: *linear momentum wins for habit; branch sparingly.*
- **XP and levels (non-expiring):** XP is forgiving (no decay) so players never feel punished for missing a day — the streak is the only fragile thing.
- **Hearts/Lives:** a limited-error budget per lesson; running out triggers either a practice-to-refill loop or a wait — converts failure into *another session*.
- **Mascot with emotional states:** Duo reacts (sad on missed day, delighted on correct) — cheap, effective emotional feedback that costs no animation budget beyond a few sprites.
- **Feedback density on correctness:** green flash, chime, confetti burst on correct; red buzz on wrong. Instant binary feedback with *sound* doing half the work.

**Lesson for us:** streak + 3 daily quests + non-decaying XP + small error budget + mascot reactions + sound-led correctness feedback. All of this is **100% offline-implementable** — perfect for our constraint.

## 1.6 Casual/arcade mini-game collections (Poptropica, Miniclip hubs, "100 games" apps)

Direct structural ancestors of our HUB.

- **Grid/list game selection** with a **featured carousel** on top; category tabs (Arcade / Puzzle / Sports / Strategy) for 100+ games.
- **Instant launch:** from icon to gameplay in ≤2 taps; no interstitial between hub and game. The hub exists to be *exited*.
- **Recently played / Continue** section — returning players skip the browse step.
- **Per-game score lists** ("Best", friends, global) visible *in the hub*, so the hub itself is a scoreboard.
- **Shared meta-currency** across games (one coin purse) — each game feeds the same economy, so variety drives the meta.
- **Achievements unlocked per-game but displayed globally.**
- Typical weakness of these apps (we avoid it): **uncohesive art direction** — every game looks like a different product. Our differentiator is a **single coherent design system** around varied game genres (see Part 2).

**Lesson for us:** ≤2 taps to play, featured + recently-played rows, hub-side score lists, one shared economy, and a *unified art language* around the games.

---

## 1.7 Cross-game pattern synthesis

| Pattern | Source games | Why it matters for us | Offline-friendly? |
|---|---|---|---|
| Short-session vertical loop | Supercell | Every session ends on a reward peak | ✅ |
| Reward slots with visible "full" state | Clash Royale/Brawl | Anticipation without notifications | ✅ |
| Soft currency (abundant) + hard currency (scarce) split | Supercell | Clean value ladder | ✅ |
| Map/linear-path progression | Candy Crush, Duolingo | Distance felt = momentum | ✅ |
| Soft-gate lives (never hard-lock) | Candy Crush, Duolingo | Return value + pressure, no paywall | ✅ |
| Failure→motivation ("so close!") | Candy Crush | Turns churn moments into replays | ✅ |
| 3 daily quests + streak | Duolingo | Habit engine, fully offline | ✅ |
| Combo functional (meter/multiplier), not cosmetic | Alto, Candy Crush | Skill depth cheap to add | ✅ |
| Juice scales with achievement size | Candy Crush | Bigger moment = bigger celebration | ✅ |
| Phased reward screens | Supercell, King | Dwell-time on the positive peak | ✅ |
| No-fail / zen mode | Alto's Odyssey | Audience breadth, relaxation | ✅ |
| Diegetic UI for flagship games | Monument Valley | Premium feel, contrast | ✅ |
| Mascot emotional feedback | Duolingo | Cheap personality | ✅ |
| ≤2 taps to play, hub = scoreboard | Miniclip-style hubs | Hub must be exited fast | ✅ |

---

# Part 2 — Design System Outline

## 2.1 Visual identity direction — "Cosmic Toybox"

A **single art language** that must host very different genres (physics, runner, puzzle, strategy, rhythm) without fragmenting. The trick: a *constant frame* (chrome, typography, motion, sound) around *variable game worlds*.

**Color palette concept — "Neon Night + Candy"**
- **Base:** deep indigo-violet (≈ `#1B1533` → `#241A45` gradient). Rationale: a dark stage makes glowing game content pop, hides seams between genres, is OLED-friendly (offline mobile battery), and makes gold rewards read as *radiant*.
- **Primary action:** hot coral `#FF5A5F` — every "play / buy / go" button. One unambiguous action color.
- **Secondary/energize:** electric cyan `#29E0E0` — interactables, info, game accents.
- **Reward:** warm gold `#FFC53D` — coins, XP, level-ups, only ever positive.
- **Success / danger:** mint `#3DDC97` and ember red `#FF4D6D` — correctness/failure feedback.
- **Gradient candy accents per game:** each mini-game gets its own 2-stop accent pair (e.g., Gravity Bloom = leaf-green→lime, Circuit Surge = cyan→blue, Combo Kitchen = orange→pink) applied to *in-game* elements only — the chrome stays constant so the hub always reads as one product.

**Typography concept — "Chunky friendly, precise numbers"**
- **Display/titles & all numbers:** a rounded geometric black/extra-bold face (Nunito/“Baloo”-class). Heavy weights carry the emotion; **tabular figures** for all counters so coin/XP animations don't jitter.
- **Body/labels:** a humanist sans (Inter-class) for readability at small sizes.
- Rule: *feel* comes from the display face; *clarity* comes from the body face; **counters are always the display face at extra-bold with tabular numerals.**

**Shape / radius language — "Super-round, chunky"**
- Pill buttons, cards at 24–32 px radius, chips at full-round. Large radius = friendliness (casual games skew round; sharp edges read "utility").
- One intentional break: **in-game UI** (timers, HUD) uses slightly smaller radius and higher contrast so gameplay readability is never sacrificed to style.

**Motion language — "Springy, staged, never sluggish"**
- UI entrances: **overshoot spring** (scale 0.8 → 1.05 → 1.0, easeOutBack, 200–300 ms) with **staggered cascades** for lists/cards (60–80 ms per element).
- Press: **squash-and-stretch** on tap-down (0.92 scale, 60 ms) — every button physically answers the finger.
- Reward moments: **staged celebration** — (1) freeze/beat-pause, (2) particles + light burst, (3) counter ticks up with eased number animation, (4) reveal card scales in. 500–700 ms total, ends on the new positive state.
- Screen transitions: 200 ms fade+scale of the *incoming* screen, never the outgoing (out is instant, in is eased) — removes perceived latency.
- 60 fps everywhere; **honor system Reduce Motion** (fall back to fades, no springs). No motion on currency *spending* (only earning) — spending is instant, earning is celebrated.

**Sound & haptics concept — "Every tap answers"**
- SFX: short, pitched, layered (tap = soft pop; confirm = 2-note; big win = ascending arpeggio; error = low buzz). One consistent *instrument family* across games (soft synth/plucks) so the audio brand unifies varied genres.
- Haptics mapped to reward size: light tap = light impact, mid = tick-tack, jackpot = heavy double-pulse. Haptics optional/off by default on desktop; toggle in settings.

## 2.2 Economy & progression model

**Currencies**
| Currency | Type | Earned by | Spent on | Notes |
|---|---|---|---|---|
| **Coins** | Soft, abundant | Every win, scaled by stars/score; first-win-of-day ×2 | Boosters, cosmetics, characters, game-skip shortcuts | Never gates core play |
| **Gems** | Hard, scarce | Achievements (+10), level-ups (+5 every 5), day-7 calendar (+15), rare in-run drops (0–3) | Exclusive skins, premium boosters, time-save | Convertible to coins; never required |

**XP & level curve**
- `xpToNext(L) = round(100 · L^1.4 / 10) · 10`
- Typical session grants 15–60 XP → ~600 plays to reach level 30 (a multi-month casual arc).
- Levels 1–30; every level awards coins; every 5th level also awards gems + a cosmetic.

| Level | XP to next | Level | XP to next |
|---|---|---|---|
| 1→2 | 100 | 10→11 | 500 |
| 2→3 | 140 | 15→16 | 810 |
| 3→4 | 180 | 20→21 | 1150 |
| 5→6 | 270 | 25→26 | 1530 |
| 8→9 | 400 | 30→31 | 1960 |

**Unlock tree for the 6 core games** (unlock = 1 short animated moment, not a shop purchase)
| Game | Unlock at | Also requires |
|---|---|---|
| **Gravity Bloom** | Level 1 (immediate) | — |
| **Combo Kitchen** | Player level 3 | 15 total stars |
| **Circuit Surge** | Player level 5 | 30 total stars |
| **Colony Hex** | Player level 8 | 50 total stars |
| **Neon Gauntlet** | Player level 12 | 75 total stars |
| **Echo Beat** | Player level 16 | 100 total stars |

- **Daily Challenge** rotates a *locked* game free for one round → players taste before they unlock (proven retention + free marketing for the locked content).
- Locked games are **visible** (silhouette + "Reach level X") — the tree is aspirational, not hidden.

**Daily reward calendar (7-day, streak-based)**
| Day | Reward |
|---|---|
| 1 | 150 coins |
| 2 | Coin Doubler (6 h) |
| 3 | 250 coins |
| 4 | 5 gems |
| 5 | XP Booster (1 h) |
| 6 | 350 coins |
| 7 | **15 gems + streak badge** |
- Streak ≥7 days: day-7 becomes **25 gems**; every consecutive week adds a +10% coin bag. Missing a day resets to day 1 unless a **Streak Freeze** booster is active.
- Rationale: day 7 is the *peak of the curve*, always within reach of a short daily play (offline-friendly, no server needed).

**Achievements (~16)** — global, displayed per-game where relevant, each +gems:
1. Green Thumb — win your first round (any game)
2. Perfectionist — earn 3 stars on a round
3. Tower Master — reach height 50 in Gravity Bloom
4. Speed Demon — travel 2,000 m in Circuit Surge
5. Master Chef — hit a 15-chain combo in Combo Kitchen
6. Untouchable — survive 60 s in Neon Gauntlet without taking a hit
7. Field General — capture 3 territories in one Colony Hex round
8. In the Zone — land 100 beats in Echo Beat
9. Tour the Hub — play all 6 games
10. Rising Star — reach player level 10
11. Legendary — reach player level 25
12. On a Roll — keep a 7-day streak
13. Unstoppable — keep a 30-day streak
14. Deep Pockets — earn 10,000 coins total
15. Gem Hoarder — hold 100 gems at once
16. Locked & Loaded — unlock all games

**Reward multipliers**
- First win of the day: **×2 coins** (daily quest engine, per Duolingo/Supercell lesson).
- 3-star round: **×1.5 coins**.
- Streak day ≥2: +10% coins per consecutive day (capped +50%).
- In-game combo chains apply their own score multipliers (functional, Alto-style).

**Boosters** (coin sink, some gem-only):
- **Coin Doubler** (timed) · **XP Booster** (timed) · **Extra Heart** (survive one more failure) · **Streak Freeze** · **Slow-Mo / Undo / Shuffle** (per-game skill aids) · **Gem Boost** (rare).
- Boosters are *optional amplifiers*, never required — protects the "no paywall" promise.

## 2.3 UX guardrails derived from the research
- **Lives but no hard lock:** hearts regenerate; on empty, the player can still play in a "practice/no-reward" mode rather than being blocked. Soft gate keeps return value, removes the churn moment.
- **Every session ends on a reward peak** (chest/card reveal) — never on a "nice job, bye" flat screen.
- **Celebrations are staged in phases**, never single dialogs.
- **Hub is exited in ≤2 taps**; featured + recently-played rows; per-game best scores visible on the hub.
- **Onboarding = guided win**, systems unlock progressively over the first week, nothing dumped at once.
- **Reduce Motion + toggle haptics/sound** honored.

---

# Part 3 — Mini-Game Concepts (6 core)

Design brief per game: **title, 1-line pitch, core mechanic, game loop, scoring, difficulty ramp, success/failure, architecture requirement demonstrated, why distinct.**

## G1. Gravity Bloom
- **Pitch:** Grow a wobbly flower-tower by dropping petals onto a stalk without letting it topple.
- **Core mechanic:** Physics tower-building — each dropped piece adds mass and torque; the stalk sways, deforms, and tips.
- **Game loop:** Watch the sway → pick drop point → release → bloom reacts → tower grows → height score.
- **Scoring:** Height × stability bonus × streak of "clean" (no-wobble) drops.
- **Difficulty ramp:** Pieces get heavier/less predictable; wind gusts; narrower planting zones.
- **Success/failure:** Tower reaches target height = win; topple or top-out = fail (with "so close!" framing).
- **Requirement demonstrated:** **Physics** simulation (rigid bodies, joints, sway).
- **Why distinct:** the only non-time-pressured, meditative game; feel = Alto-style flow.

## G2. Circuit Surge
- **Pitch:** A one-touch neon runner through procedurally-built sky-canals that never repeat.
- **Core mechanic:** Endless runner; swipe/tap to hop/slide; world segments are **procedurally generated** (gaps, platforms, loop-de-loops) with seeded difficulty.
- **Game loop:** Run → react → chain near-misses → build meter → unlock overdrive.
- **Scoring:** Distance + near-miss combo multiplier; named per-run goals ("reach the storm wall").
- **Difficulty ramp:** Speed ramps; biome variety (night, storm, zero-G) *flavors* difficulty instead of only punishing.
- **Success/failure:** Beat per-run goal = win; one hit = run ends (zen mode: no-fail option).
- **Requirement demonstrated:** **Procedural generation** + **progressive difficulty**.
- **Why distinct:** pure kinetic flow; the "always fresh" game proving generation value.

## G3. Combo Kitchen
- **Pitch:** A timed plate-rush: chain matching ingredients into dishes before the timer burns.
- **Core mechanic:** Grid swap/merge with a **combo chain**: matching same-color ingredients inside a shrinking timer window links a multiplier; dishes complete = board pressure.
- **Game loop:** 30–60 s round → match quickly → chain combos → build dish → order complete → next order, faster.
- **Scoring:** Dish value × combo multiplier; perfect-completion bonus; 3-star target scores.
- **Difficulty ramp:** More ingredient types, shorter windows, multi-step dishes.
- **Success/failure:** Fill all orders = win; timer out mid-dish = fail (close-to-done framing).
- **Requirement demonstrated:** **Score/combo** system (functional multiplier, Candy-Crunch/Aalto-style).
- **Why distinct:** the "fast hands + quick eye" game; most social/score-bragging friendly.

## G4. Colony Hex
- **Pitch:** A compact strategy duel: capture the hex-board with limited moves and clever rng boons.
- **Core mechanic:** Turn-based territory capture on a hex grid; each move spends a limited "action" budget; territory adjacency + boon cards (build, rally, sabotage).
- **Game loop:** Plan → spend moves → capture → draw boon → repeat until map resolves.
- **Scoring:** Territory count × efficiency (moves remaining) × colony bonuses.
- **Difficulty ramp:** Larger maps, hostile neutral tiles, rarer boons; puzzle-style "perfect" objectives.
- **Success/failure:** Majority capture within move budget = win; budget exhausted without majority = fail.
- **Requirement demonstrated:** **Strategic decision-making** (turn-economy, no reflexes).
- **Why distinct:** the only turn-based, plan-ahead game; proves the platform isn't reflex-only.

## G5. Neon Gauntlet
- **Pitch:** A dodge-arena pattern gauntlet: survive waves that stack until you can't.
- **Core mechanic:** Single-screen dodging; incoming pattern walls ramp in density and speed.
- **Game loop:** Survive wave → collect shards (risk reward) → new pattern type introduced → repeat.
- **Scoring:** Wave count × shard multiplier; combo for consecutive no-hit waves.
- **Difficulty ramp:** *Explicitly* the progressive-difficulty showcase: spawn rate, speed, and pattern complexity each ramp on independent axes.
- **Success/failure:** Beat the final named wave = win; one hit = fail (with wave-reached recap).
- **Requirement demonstrated:** **Progressive difficulty** (dedicated, quantifiable).
- **Why distinct:** the "tension" game — pure reflexes, escalating pressure, high replay via wave bests.

## G6. Echo Beat
- **Pitch:** A rhythm-timing game where your taps physically build a neon melody.
- **Core mechanic:** Tap/beat-matching; timing quality (perfect/good/miss) drives a combo meter; your hit-streak *composes* the soundtrack live.
- **Game loop:** Pick a track → hit beats → keep streak → unlock next track/chart at higher BPM.
- **Scoring:** Timing-accuracy × streak multiplier; perfect-song bonus.
- **Difficulty ramp:** BPM and note-density ramp per chart; charts unlock in sequence.
- **Success/failure:** Complete a chart = win; streak break hurts score but never kills the run (forgiving).
- **Requirement demonstrated:** **Timing + combo**; demonstrates audio-driven gameplay (SFX/music as core mechanic).
- **Why distinct:** the only game where *sound is the mechanic*, and the composer angle makes combo matter emotionally.

---

## Part 4 — Requirement coverage map

| Requirement | Covered by |
|---|---|
| Physics | Gravity Bloom (rigid bodies, sway/joints) |
| Procedural generation | Circuit Surge (seeded endless segments) |
| Score/combo | Combo Kitchen (functional multiplier) + Echo Beat (timing combo) |
| Progressive difficulty | Neon Gauntlet (dedicated) + Circuit Surge (speed/biome ramp) |
| Strategic decision-making | Colony Hex (turn/action economy) |
| Flow/relaxation variety | Gravity Bloom (+ zen mode in Circuit Surge) |

Each of the 6 ships with: **tutorial (guided win), pause, restart, result screen, reward grant, animations, SFX, haptics** — the shared game-template contract the platform enforces.

---

## References (publicly documented patterns; not live-fetched in this env)
- Supercell — game design philosophy / short-session loop; Brawl Stars & Clash Royale economy & shop systems (press, developer talks, design blog).
- King / Candy Crush Saga — map level design, lives system, booster economy (press, GDC talks on match-3 design).
- ustwo — Monument Valley design process (ustwo design/engineering blog, GDC).
- Snowman — Alto's Odyssey design (developer interviews, press).
- Duolingo — streak, quests, path redesign, notifications (Duolingo engineering/UX blog, press).
- Miniclip / Poptropica / "100 games" collections — hub architecture (product/press observations).

> **Caveat:** patterns are re-derived from well-known public reporting; treat specific version details (e.g., exact reward schedules, 2025+ changes) as approximate and re-verify against live sources before ship.
