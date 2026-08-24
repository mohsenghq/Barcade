# 05 — Synthesis & Adversarial Critique

**Date:** 2026-08-11
**Author:** Adversarial technical reviewer (subagent)
**Inputs:** 01-engine-comparison.md, 02-ux-game-design.md, 03-monetization.md, 04-architecture.md
**Method:** Cross-examined the four reports against each other and against the product constraints; verified load-bearing claims live where possible (see §5).

---

## 1. Verdict up front

The proposed stack and plan are **sound and internally coherent at the macro level**: Flutter + Flame 1.38 is consistent across all four documents, the offline-first service-interface architecture is genuinely respected by the monetization design, and the save/economy/reward core is unusually well-specified. The confirmed problems are **spec-level defects, not stack-level mistakes** — the engine choice survives scrutiny, but the plan has several seams where the reports were never checked against each other, and three of the six designed games sit on engine capabilities the architecture report never plans for.

Top 5 implementation risks are listed in §6.

---

## 2. (a) Engine choice vs architecture report — consistent, with one unverified supporting claim

No conflict between the engine recommendation (01) and the architecture (04):
- Both pin **Flutter 3.44.x + Flame 1.38.0**; versions cross-check. Flame 1.38.0 and its "breaking changes" note are confirmed on GitHub (latest, Jul 2026). Godot 4.7.1 / 4.7 / 4.6 / 4.5 dates in 01 match GitHub exactly.
- Geo-blocking story is consistent: 01's China-mirror guidance matches 04's `tool/env.sh` note, and both agree CI runners are not geo-blocked.
- Engine's "18-mini-game hub precedent" claim is **confirmed**: `github.com/akillisletme/flame-games` is a real Flutter/Flame arcade hub with 18 mini-games (note: it uses Hive CE + flutter_bloc + GetIt — not the stack 04 chose, so it is a precedent for *game-count in one app*, not for the state-management approach).

**Unverified/out-of-date claim (does not flip the decision, but must be corrected):**
- 01 says "desktop became a stable target in Flutter 3.42 (Feb 2026) on Impeller 2.0, which also killed the old shader-compilation jank." The official Flutter 3.44 release notes and the 3.44 announcement blog contain **no mention of "Impeller 2.0"**, no desktop-default-Impeller announcement, and no shader-jank fix. Desktop (Windows/macOS/Linux) has been a **stable target since Flutter 3.0 (May 2022)**. What is real: Impeller is progressively displacing Skia on desktop, and "Impeller 2.0" may be marketing shorthand the researcher picked up from a non-authoritative source. The 4/5 desktop score stands; the *rationale* should be rewritten. Risk: nobody re-verifies this and a later reviewer trusts "shader jank is solved" for a decision it doesn't actually back.
- 01's "Flutter 3.44 stable (Dart 3.12); 3.47 due Aug 2026" is **confirmed** by the Flutter release archive (3.44 May 2026, 3.47 target Aug 2026, branch cutoff 2026-07-07). Note 3.47 is due *this month* — pin 3.44.x now or plan the jump deliberately (see §6 risk 5).

---

## 3. (b) UI/game-design proposals vs architecture capabilities — directionally consistent, three real gaps

The UX document (02) and architecture (04) agree on the cross-cutting rails: reduced-motion via `MediaQuery.disableAnimationsOf`, haptics toggle gated on platform support, 60fps target, token-based design system, ≤2-tap hub, landscape adaptation with rotate-gate, text scaling 1.0–2.0. Those maps cleanly onto 04 §6/§7. No contradiction.

Gaps where 02 designs *capabilities that 04 never plans for at the engine level*:

1. **Physics engine is missing from the architecture.** 02's flagship game G1 *Gravity Bloom* is a rigid-body + joint + torque sim, and 01 names `flame_forge2d` as the bridge — but 04's entire doc (including §5 performance) never mentions Forge2D, physics, or the physics game. The two example game folders in 04 (`memory`, `grid_move`) are also *different games* from the six 02 actually designed (Gravity Bloom, Combo Kitchen, Circuit Surge, Colony Hex, Neon Gauntlet, Echo Beat) — cosmetic, but it proves 02 and 04 were never cross-checked. **Action: add a Forge2D decision (version pinned against Flame 1.38's breaking changes, stepped-physics integration with Flame's game loop, early device profiling) to the architecture before the vertical slice.**
2. **Rhythm-game audio latency is unplanned.** 02's G6 *Echo Beat* makes *timing accuracy* the core mechanic; `flame_audio`/`audioplayers` (04's `AudioService` implementation) has well-documented platform-variable playback latency. There is no audio-position-based timing path, no latency calibration, no plan to compensate. A rhythm game on a 200–300ms-latent audio path is unfinishable as designed. **Action: either pick a low-latency audio strategy (or define the timing source as audio position, not wall clock) or swap G6 to a game whose core mechanic is not timing-dependent.**
3. **Procedural generation is only half-planned.** 02's G2 *Circuit Surge* is seeded procedural generation; 04 T1 mentions "seeded RNG" only in the *testing* table. Seeding, difficulty curves, and level-balance tables for the generator have no home in the architecture. Minor, but worth a stub in the game template contract.

---

## 4. (c) Monetization vs offline-first — respected, with two internal contradictions

Report 03 is the most offline-disciplined document of the four: availability-as-a-query, preload-don't-block, grant-only-after-completion, idempotency ledger, consent-never-blocks-the-game, `Mock` provider as default. That is exactly right and consistent with 04's "analytics no-op impl in offline build" and the product's 100% offline-first requirement.

Two genuine contradictions:

1. **The composition root is missing two of the three services 03 claims it contains.** 03 §7: "All three are injected via the existing `MiniGameServices` composition root." But 04's `MiniGameServices` constructor injects only one of the three: `AnalyticsService` (and 04 even calls it a concrete `AnalyticsService`, while 03 names the interface `IAnalyticsService` — a naming mismatch). `IAdvertisementService` and `IPurchaseService` are **not in the composition root at all**. Easy fix (add two fields), but as written, games cannot reach ads/purchases and 03's drop-in-swap claim does not hold yet.
2. **Server-side verification and Play Integrity imply a backend the architecture explicitly doesn't have.** 03 recommends AdMob SSV as the "authoritative grant" for high-value rewards and Play Integrity/Firebase App Check attestation before serving the gem store. SSV is a *postback to your server*; Play Integrity requires Google Play services + network. The product is offline-first, no accounts, no server. 03 half-acknowledges this ("locally granted free currencies are inherently forgeable — accept that ceiling") but still publishes SSV/attestation as if available. **Action: state the v1 ceiling explicitly — client `onUserEarnedReward` + idempotency ledger for ads, RevenueCat's hosted validation for purchases (RevenueCat's backend absorbs the validation role, which is legitimate), no SSV/Play Integrity until a backend exists.** This also resolves the "never trust the client" tension: RevenueCat gives you server-side validation without owning a server; AdMob SSV does not.

Everything else in 03 is consistent with offline-first: buying gems inherently requires network (store sheets), entitlements are cached for offline *reads*, `isRewardedAvailable` returns false offline, and analytics batches locally and flushes later. The `Mock`-first wiring matches 04's composition root philosophy.

---

## 5. (d) Other contradictions, out-of-date claims, and omissions

**Confirmed by arithmetic — XP curve formula does not match the published table.**
02 §2.2 defines `xpToNext(L) = round(100·L^1.4/10)·10` but the table shows 2→3 = 140, 3→4 = 180, 5→6 = 270, 10→11 = 500, 30→31 = 1960. Computing the formula: L=2 → **260**, L=3 → **470**, L=5 → **950**, L=10 → **2510**, L=30 → **11690**. The formula and table diverge by ~5–6× at mid/high levels. One of them is wrong, and the pacing claim ("~600 plays to level 30") is consistent with the *table*, not the *formula*. **Action: pick the table as the single source of truth, delete the formula, and derive all level-based rewards/achievement unlocks from the table. Leave this unresolved and the save schema, pacing, and every "reach level X" unlock drifts.**

**Future-dated ad-industry claims could not be verified.**
Web search is geo-blocked from this environment (as 02 and 00-environment.md document) and targeted fetches returned 403/404. I could not independently confirm: Unity ironSource direct-demand sunset **Apr 30 2026** (03 §1), the **Liftoff IPO Jun 4 2026 at $3.83B** (03 §1), or the **AppLovin −20% single-day move Aug 6 2026** (03 §1). These are consistent with the known trajectory (Unity's pivot to Vector, the Liftoff–Vungle 2021 merger, AppLovin's 2025 short-seller/regulatory noise) and the *recommendation* derived from them — AdMob default, LevelPlay not recommended — is low-risk either way. But they are stated as verified facts; mark them "directionally correct, dates/figures unconfirmed" and re-check at integration time (these dates are within the current quarter).

**Out-of-date/imprecise claims collected (none flip a decision):**
- 01: "desktop became a stable target in Flutter 3.42 on Impeller 2.0" — see §2. Desktop stable since 3.0; "Impeller 2.0" not found in official 3.44 notes.
- 01: "Flutter 3.47 due Aug 2026" — confirmed, and it is due *now*; version policy needed.
- 03: "Meta Audience Network is dead (definitive shutdown reports circulate)" — 03 itself hedges correctly; keep the hedge, don't let a doc reader treat it as dead for planning.
- 03: `firebase_analytics` covers Android/iOS/macOS/web but not Windows/Linux desktop — confirmed against current docs; 04's `Mock` on desktop covers it. Note also the *region* issue (below).

**Omission — analytics may be a permanent no-op in the target region.**
03 recommends Firebase Analytics but the environment blocks Google hosts (documented in 00-environment.md). At runtime in that region, GA4's queued events may *never* flush — this is not just an offline case, it is the deployed reality. 03 covers the desktop gap (ambilytics/Mock) but not the regional gap. **Action: state that analytics is best-effort and non-blocking by policy, or pick a region-reachable analytics endpoint; do not let a "0 events sent" week be misread as a bug.**

**Minor mismatches worth one line each:**
- 04 §4 example game folders (`memory`, `grid_move`) are not the six games in 02 — rename placeholders to match before scaffolding.
- 02's 16 achievements and 03's gem economy reference the same pool; 02 awards gems via achievements (+10 each) while 03 treats gems as the IAP currency. Verify the two gem sources (earned vs purchased) share one balance without enabling inflation — 04's single `currencies` table handles it, but the ratio should be deliberate, not incidental.
- 02's day-7 calendar and streak logic depend on the device clock; 04 correctly stores `last-run` in shared_preferences (user-deletable). Accept the forgeability ceiling explicitly for daily/streak rewards, consistent with the currency ceiling already accepted in 03.

---

## 6. Final verdict and top 5 implementation risks

**Verdict:** The stack (Flutter 3.44 + Flame 1.38, Riverpod for the hub, drift for persistence, ads/IAP/analytics behind mock-default service interfaces) is sound, well-evidenced, and mutually consistent in its fundamentals. The engineering core (save atomicity, reward idempotency, migration ladder, two-layer state split) is production-grade and correctly identified as the correctness center of gravity. The plan should proceed — with the corrections above — but the following risks are the ones most likely to blow up mid-implementation.

### Top 5 risks to watch

1. **The physics game has no engine-level plan.** Gravity Bloom (rigid bodies + joints + torque) is the flagship requirement, but 04 never plans Forge2D, its version pin against Flame 1.38's breaking changes, or its stepped-simulation integration — and 01 itself flags Flame has "no physics-fast path." Unplanned physics is the highest-probability vertical-slice killer. Mitigate: pin `flame_forge2d` now, prototype the topple simulation first, profile on a low-end Android device before building the hub around it.

2. **Rhythm-game timing vs audio latency.** Echo Beat's core mechanic is timing accuracy, but the specified audio stack (`flame_audio`/`audioplayers`) has platform-variable latency and no audio-position-synced timing source. A 200ms latency error makes the game unplayable-by-design. Mitigate: verify latency on target devices in week one, or change G6's mechanic.

3. **Economy/XP spec is internally inconsistent.** The `round(100·L^1.4/10)·10` formula disagrees with the published XP table by ~5–6× at mid levels, and every level unlock, gem grant, and achievement is derived from this curve. Mitigate: freeze the table as the single source of truth and generate all tuning from it before any save schema is written.

4. **Monetization wiring is incompletely specified against the architecture.** `IAdvertisementService`/`IPurchaseService` are not in `MiniGameServices` (03 says they are), and SSV/Play Integrity guidance implies a backend the offline-first design doesn't have. Mitigate: add the two services to the composition root, write the idempotency ledger generically (reused by ads, purchases, daily rewards, achievements), and document the "client `onUserEarnedReward` + ledger" v1 ceiling — SSV and Play Integrity only when a backend exists.

5. **Version churn is an active threat, not a future one.** Flame 1.38 (confirmed breaking changes), Flutter 3.47 due this month, and the unverified "Impeller 2.0" claim all mean the golden/renderer baseline can shift under the test suite. Mitigate: pin Flutter 3.44.x and Flame 1.38.0 in CI with a documented upgrade cadence, generate goldens on a pinned Linux rasterizer, and make the renderer/engine versions explicit in the repo — treat "Impeller 2.0" as unverified until confirmed against the pinned SDK.

---

## 7. Verification evidence

Verified live (WebFetch):
- `github.com/akillisletme/flame-games` — real repo, 18 mini-games, Flutter/Flame arcade hub. Confirms 01 §2.
- `docs.flutter.dev/release/archive` — Flutter 3.44 stable (May 2026), 3.47 target Aug 2026. Confirms 01 versions; contradicts nothing.
- `github.com/flame-engine/flame/releases` — Flame 1.38.0 latest, breaking changes noted. Confirms 01/04.
- `github.com/godotengine/godot/releases` — 4.7.1 (2026-07-14), 4.7 (Jun), 4.6 (Jan), 4.5 (Sep 2025). Confirms 01 exactly.
- `github.com/googleads/googleads-mobile-flutter/releases` — `google_mobile_ads` v9.0.0 (Jun 2026) with Next-Gen GMA SDK for Android. Confirms 03 §1.
- Flutter 3.44 release notes + announcement blog — **no "Impeller 2.0," no desktop-stable announcement, no shader-jank fix.** Falsifies/qualifies 01's framing.
- en.wikipedia.org Unity — runtime-fee cancellation (Sep 2024) confirmed; no ironSource detail. Partially confirms 01.

Could **not** verify (geo-blocked search, 403/404 fetches): ironSource sunset date (Apr 30 2026), Liftoff IPO (Jun 4 2026), AppLovin −20% (Aug 6 2026). Treat as directionally-correct, numerically-unconfirmed.

Arithmetic-verified (no web needed): 02's XP formula vs table mismatch (§5).
