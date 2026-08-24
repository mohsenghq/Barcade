# 03 — Monetization & Ads Research (Flutter, Offline-First)

**Date researched:** 2026-08-11 · **Project:** starcade · **Stack:** Flutter (SDK ^3.12), Riverpod + Flame, drift persistence
**Constraint:** All ads/IAP/analytics behind service interfaces; a `Mock` provider ships for offline/dev; gameplay never depends on monetization.

---

## 0. Executive summary

- **Rewarded ads (2026):** The landscape consolidated hard. The old "Unity Ads vs ironSource vs Vungle vs AppLovin" map is gone. Today the dominant players are **AdMob (Google)** and **AppLovin MAX**, with **Unity LevelPlay** as a shrinking-but-live third mediation platform. **Unity killed its own ironSource ads network** (direct demand shut down **April 30, 2026**) to bet on its new **Unity Vector** AI ad platform; **Liftoff is a separate company** (Liftoff Mobile, formerly the 2021 Liftoff+Vungle merger, Blackstone-backed, **IPO June 4, 2026** on Nasdaq at $3.83B) whose network product is called **Liftoff Monetize**. **Vungle no longer exists as a brand** (folded into Liftoff). **Meta Audience Network** is alive for in-app placements but its iOS inventory collapsed after ATT/IDFA (2021); it is now an Android fill partner in mediation, not a primary monetizer.
- **Recommendation for this project:** **AdMob via `google_mobile_ads` (v9.x, June 2026)** as the default rewarded provider — best-maintained Flutter plugin, free built-in mediation, UMP consent handled in-plugin, server-side verification (SSV) support. **AppLovin MAX (`applovin_max`)** is the credible upgrade path for higher gaming rewarded eCPMs; it has an official Flutter plugin and can be swapped in behind the same interface. Do **not** build on Unity LevelPlay for a new 2026 app: direct ironSource demand is gone and Unity is mid-restructuring (Supersonic sale, Vector migration).
- **IAP:** Use **`purchases_flutter` (RevenueCat)** as the production implementation behind `IPurchaseService` — it absorbs Play Billing v8/v9 changes, StoreKit 1/2, receipt validation, subscription status, restore, and (new) Play "user-choice billing," and it caches entitlements locally (offline-safe). A leaner fallback is the official `in_app_purchase` plugin + your own local grant ledger.
- **Top 3 pitfalls:** (1) trusting the client — validate purchases/ad completions server-side; (2) non-idempotent grants (duplicate callbacks, restore flows) — keep an idempotency ledger; (3) consent/ATT/account-deletion compliance gaps → account suspension / takedown.
- **Architecture:** three narrow interfaces — `IAdvertisementService`, `IPurchaseService`, `IAnalyticsService` — each with a `Mock*` impl that is the default build; production impls are opt-in plugins resolved at the composition root. See §7.

---

## 1. Rewarded-ads provider landscape (as of Aug 2026)

### The 2025-2026 consolidation, verified

| Event | Date | Source |
|---|---|---|
| Liftoff + Vungle merger → "Liftoff Mobile" (ad network = **Liftoff Monetize**, formerly Vungle) | 2021 | unity docs, support.vungle.com |
| AdMob: UMP consent required for EEA/UK; Google-certified CMP (IAB TCF); UMP SDK bundled in GMA SDK (iOS 7.64.0 / Android 19.8.0) | Jan 16, 2024 | TopOn/Google groups, Google docs |
| AdMob: `app-ads.txt` required for new apps | Jan 2025 | AdMob help |
| AdMob: updated Publisher Policies (ad identity/`PrivacySandbox`-adjacent rules) | Feb 2025 | Google blog via Peggy KTC |
| AppLovin: short-seller report alleging ad fraud & tracking children; SEC probe reported (unconfirmed) | Feb 2025 / Oct 2025 | Wikipedia, Bloomberg |
| AppLovin: divests game studio (Lion Studios) business to Tripledot; joins S&P 500 | Jun 30, 2025 / Sep 22, 2025 | Wikipedia, pocketgamer.biz |
| Unity: launches **Vector** AI ad platform; "fully migrated its ads network" to it | May 8, 2025 | pocketgamer.biz |
| Liftoff: General Atlantic minority investment at ~$4.3B valuation | Jul 1, 2025 | Liftoff PR via search |
| Unity: **announces shutdown of ironSource Ads network** + sale of Supersonic | Mar 2026 | gameworldobserver, gamesindustry.biz, Wikipedia |
| **ironSource Ads direct demand sunset** | **Apr 30, 2026** | unity.com/products/ironsource-ads-sunset |
| Liftoff Mobile **IPO** (Nasdaq, $3.83B, raised $437M) | Jun 4, 2026 | pocketgamer.biz |
| Google Play: **Play Billing Library v8 mandatory** — new apps Aug 2025, all existing apps Feb 2026; v9 in prep | Aug 2025–Feb 2026 | RevenueCat, appsops |
| Google Play: expanded "billing choice"/fee restructuring US+UK+EEA | Jun 30, 2026 | android-developers blog |
| `google_mobile_ads` Flutter plugin v9.0.0 (adds **Next-Gen GMA SDK for Android**); v8.0.0 Apr 2026 (SPM, UISceneDelegate) | Jun 9, 2026 | github.com/googleads/googleads-mobile-flutter/releases |
| Android GMA SDK 25.0.0 (major, breaking) | Feb 2026 | ads-developers.googleblog.com |
| GMA **Next-Gen SDK** (Android) — significant rewrite, open beta | 2025-2026 | developers.google.com/admob/android/next-gen/quick-start |

**Is "Unity Ads → Liftoff" real?** No. That is a common conflation. Unity's monetization (Unity Ads, LevelPlay mediation, ironSource, Vector) **remains Unity's** ("Unity Grow"). Liftoff is an independent ad-tech company (formed 2021 when Liftoff and Vungle merged) that monetizes as an **ad network** (Liftoff Monetize) inside other mediation platforms (LevelPlay, AdMob). We could not confirm any Unity–Liftoff merger as of Aug 2026.

### Provider comparison for rewarded video

| Provider | Role (2026) | Rewarded-video strength | Flutter plugin | Mediation? | Notes / risk |
|---|---|---|---|---|---|
| **AdMob (Google)** — `google_mobile_ads` | Network + built-in free mediation | Strong fill, Google/YouTube demand, decent gaming eCPMs | **Official, best-maintained (v9.0.0)** | Yes, first-party | UMP consent, SSV, app-ads.txt. Next-Gen GMA SDK (Android rewrite) is rolling out. Lowest-risk default. |
| **AppLovin MAX / AppLovin Ads** — `applovin_max` | Mediation layer + own demand (AppDiscovery/AXON AI) | Historically highest gaming rewarded eCPMs | **Official** | Yes | Dominant in gaming UA/monetization. Carry risk: Feb 2025 ad-fraud short report, reported Oct 2025 SEC probe (unconfirmed); -20% single-day Aug 6, 2026. eCPM upside vs. brand risk — evaluate at scale. |
| **Unity LevelPlay** (Unity Grow) | Mediation layer (Unity Ads demand + unified auction) | Strong in games historically | **Official Flutter SDK** (docs.unity.com LevelPlay Flutter SDK) | Yes | **ironSource direct demand shut Apr 30, 2026**; Exchange continues, but Unity is restructuring (Vector, Supersonic sale). Not recommended for a fresh 2026 integration. |
| **Liftoff Monetize** (formerly **Vungle**) | Network only (bidding/waterfall partner) | Rewarded + rewarded interstitial | Via mediation adapters (AdMob/LevelPlay), no standalone official Flutter plugin | No (network) | Owned by Liftoff Mobile (Blackstone → IPO Jun 2026). Use as a mediation network, not as the primary SDK. |
| **ironSource Ads** | ~dead | — | Was inside LevelPlay | No | Direct demand sunset **Apr 30, 2026**; Exchange lives inside LevelPlay. Avoid as a standalone choice. |
| **Meta Audience Network** | Network only (in-app placements) | Negligible on iOS post-ATT; usable Android fill | Via mediation adapters | No (network) | **Not dead** (web/in-stream closed Apr 11, 2020; in-app still serving 2026 — status pages, format updates Aug 2025/Jan 2026), but iOS eCPMs collapsed after IDFA deprecation. Third-party "definitive shutdown" reports circulate; verify before betting on it. |
| **AdColony / Chartboost / others** | Long tail networks | — | Via mediation | No | Consolidating (AdColony acquired 2021); treat as fill only. |

**eCPM expectations (directional, no hard numbers — test on your own traffic):** rewarded video in casual games is generally the highest-eCPM format; Android rewarded eCPMs are materially lower than iOS; US/UK/CA/JP monetize far above most of the rest of the world; seasonality (e.g., Q4) swings 30-50%. Mediation with bidding (AdMob mediation, MAX, LevelPlay) recovers fill + price at the margin. For an offline-first casual platform, plan for **AdMob mediation as the baseline** and don't count on ad revenue as the primary model — IAP on a small paying slice typically dwarfs it.

### Flutter plugin quality (the decision that matters)

- `google_mobile_ads` **v9.0.0** (2026-06-09): banner, interstitial, **rewarded**, rewarded interstitial, native, app-open; mediation adapters documented (ironSource, PubMatic, BidMachine, LINE, Liftoff Monetize…); **UMP consent in-plugin**; `RewardedAd.load` / `.show(onUserEarnedReward:)`; **server-side verification (SSV)** optional callback. v9 adds the **Next-Gen GMA SDK for Android** (Google's rewritten GMA SDK, still rolling out). Deprecation/sunset schedule is published and predictable. **This is the safest plugin in the ecosystem** — first-party, active, matches every format we need.
- `applovin_max` — official AppLovin package; supports banner, interstitial, **rewarded**, MREC. Real, maintained, but you manage consent and network adapters yourself.
- LevelPlay Flutter SDK — official Unity docs, but the platform is mid-restructuring; skip for a new app.
- `flutter_play_integrity` (community) / Firebase App Check (Play Integrity provider) — for anti-fraud, not ads.

---

## 2. Offline-first ad design (never let ads touch gameplay)

Ads are the *poster child* for "degrade gracefully": rewarded ads are pure bonus content, so they are the easiest thing to make fully offline-safe.

1. **Availability is a query, not a crash.** `IAdvertisementService.isRewardedAvailable` returns `false` when: offline, SDK not initialized, no consent, load failed, or provider is `Mock`. The reward button in-game simply hides/disables (with a "no ads — come back online" tooltip) when false. **Gameplay and progression never call into the ad SDK.**
2. **Preload, don't block.** Preload one rewarded ad after app start *when online and consent granted*. Never await ad init/load/consent on any game path. On load failure, retry with exponential backoff + jitter, cap it (e.g., 5 tries), then report unavailable.
3. **Grant only after verified completion.** For AdMob: grant in `onUserEarnedReward` **only** (not on `show()`). For high-value rewards use **server-side verification (SSV)** callback as the authoritative grant. Never grant a reward the ad didn't fully play.
4. **Idempotent claims.** Duplicate `onUserEarnedReward` callbacks or an app-kill between "reward earned" and "grant persisted" must not double-grant. Pattern: before showing, write a **claim record** `{claimId(nonce), placement, state: pending}` to the save store; grant once and flip to `claimed`. On startup, reconcile (re-grant or drop `pending` records within a grace window — pick one policy and keep it). Currency math already has grant-idempotency in the core design (see 04-architecture §T1) — ads reuse it.
5. **Consent must not block the game.** Run UMP consent update at startup; whatever the outcome (consented / not / consent failed), the game runs. Not-consented → no personalized ads → either no rewarded ads or consent-walled mode. This is both UX and policy (§6).
6. **No forced ads, no interference.** No rewarded ad as a hard requirement for progress, no auto-play interstitials during gameplay, no ads on result screens within X seconds of an ad (AdMob/Play discourage stacking). Interstitial frequency caps are a separate topic — rewarded is the only format this design needs at v1.
7. **The `Mock` provider is the default.** Offline/dev builds ship `MockAdvertisementService` (deterministic "ad complete" → reward grant for tests/QA, e.g., after a configurable delay) so the whole reward pipeline is testable with zero network.

---

## 3. IAP architecture

### Provider choice

| Approach | Plugin | Pros | Cons |
|---|---|---|---|
| **RevenueCat** (recommended default) | `purchases_flutter` (v-current, 2026) | Receipt validation server-side, subscriptions & status, restore, Play "user-choice billing" support, webhooks, dashboards; **entitlements cached locally → offline-safe reads**; absorbs Play Billing v8/v9 + StoreKit 1/2 churn | Third-party dependency (SaaS backend); not usable fully offline for *buying* (store sheets need network anyway) |
| Official plugin | `in_app_purchase` (+ endorsed `in_app_purchase_storekit`) | No backend, fully under your control | You own receipt validation, subscription state, restore, and all Billing Library/StoreKit migration pain; no offline entitlement cache |

`purchases_flutter` API surface (2026): `PurchasesConfiguration(apiKey)` replaces deprecated `Purchases.setup`; `Purchases.getOfferings()`, `purchasePackage`/`purchaseProduct`, `Purchases.restorePurchases()`, `CustomerInfo` entitlements; `usesStoreKit2IfAvailable` for iOS (RevenueCat defaults to StoreKit 1 unless told otherwise). Works with **Amazon Appstore** too (`Store.amazon`).

**Recommendation:** production impl = RevenueCat; keep `IPurchaseService` thin so the official-plugin impl can replace it later.

### Product model for starcade

| Type | Store kind | Example | Grant rule |
|---|---|---|---|
| **Consumable** | Play: one-time product, consumed; App Store: consumable | **Gems** (e.g., 500 / 1200 / 5000) | Consume token; add to gem balance once (idempotent by `orderId`) |
| **Non-consumable** | Play: one-time; App Store: non-consumable | **Remove ads**, cosmetic bundles | Set permanent flag in save data; restore on reinstall |
| **Subscription** (later) | auto-renewable | "VIP / Arcade Club" | `CustomerInfo` entitlement; grant per-period perks |

### Anti-fraud & correctness (in priority order)

1. **Never trust the client.** All purchase grants must be validated against the store — Google **Play Developer API** purchase token check, Apple **App Store Server API**, or RevenueCat's server-side validation — before crediting. Client-only grants are trivially spoofed with a patched APK.
2. **Idempotency ledger.** Key every grant on the store-provided `orderId`/purchase token; a `claimed_purchases` table (drift) dedupes restore + duplicate webhooks + crash-after-charge. This is the same idempotency pattern as ads (§2.4) — build one generic "grant ledger" service and reuse.
3. **Platform attestation.** Use **Play Integrity API** (via `flutter_play_integrity` or **Firebase App Check**'s Play Integrity provider) to attest the device/app before serving the gem store or granting large amounts. Check verdicts (device integrity, app integrity, licensing) server-side. On iOS, store-level attestation + App Attest for high-value flows (lighter for an indie).
4. **Code obfuscation (don't over-invest).** Flutter: build with `--obfuscate --split-debug-info`; Android: minify/R8 + ProGuard rules; iOS: strip debug symbols. Keep store secrets (if any) server-side — client only holds public app IDs. Remember: obfuscation raises the bar, it does not stop a determined attacker; **real protection is server-side validation** (points 1-3). For an offline-only game, locally granted "free" currencies are inherently forgeable — accept that ceiling (ponytail: local currency is not server-authoritative; only money-purchased gems need hard protection), and never let local currency affect what's purchasable.
5. **Handle store edge cases.** Google `PendingPurchases`, interrupted purchases, duplicate `purchaseUpdated` events, failed consumption → reconcile on next online session; never double-grant; `restorePurchases()` path must be idempotent.

---

## 4. Analytics

- **Production:** **Firebase Analytics (GA4)** via `firebase_analytics` — free, works by **queueing/batching events locally and flushing when online**, so it fits an offline-first app (events logged offline flush later). GA4 also gives the free **Attribution/Firebase Attribution** basics (install source, first-open, campaign links).
- **Platform gap:** official `firebase_analytics` supports **Android, iOS, macOS, web** — **not Windows/Linux desktop**. For this project's desktop targets, use the community `ambilytics` bridge (GA4 Measurement Protocol over HTTP) or keep `MockAnalyticsService` (log-to-console / local SQLite buffer) on desktop. Recommend: **`IAnalyticsService` → Firebase on mobile, Mock on desktop** — zero gameplay coupling either way.
- **Attribution basics (don't over-build):** for organic + AdMob/AppLovin install measurement, GA4/Attribution + each ad SDK's conversion tracking is enough for v1. Full MMPs (AppsFlyer/Adjust) only matter once you run significant paid UA — add later behind the same interface.
- **Consent plumbing:** Firebase Analytics should be gated on the same UMP/consent outcome as ads (no tracking before consent); on iOS, request **ATT** (via `app_tracking_transparency` + UMP) before any ad-tracking identifiers.
- **Event taxonomy (recommend v1):** `game_start`, `game_end{game, score, result}`, `level_up{level}`, `reward_claimed{placement, source:ad|daily|achieve}`, `ad_reward_earned{placement, provider}`, `ad_offered{placement}`, `purchase_started{product}`, `purchase_completed{product}`, `session_start/end`, `save_failed`. Keep it small; every event is a decision.

---

## 5. Platform policies that shape the architecture

### Google Play (2024-2026)
- **Account deletion / data deletion:** any app that lets users *create an account* must let them delete it **in-app AND via a web link** (deadline May 31, 2024; "Account deletion available" badge live). Data-safety form must be accurate. **Architecture impact:** if a future cloud-save/account layer is added, it must include a deletion endpoint from day one. Our offline-first design with **no accounts** sidesteps this entirely — keep it that way until the online layer exists.
- **Play Billing:** digital goods must use Play Billing; **Play Billing Library v8 mandatory** for new apps (Aug 2025) and existing apps (Feb 2026); v9 coming. Google expanded **user-choice billing** (EU DMA) with fee restructuring effective **June 30, 2026** (US/UK/EEA). RevenueCat already handles alternative billing (Play Billing Choice) — another reason to use it.
- **Ads:** AdMob `app-ads.txt` for new apps (Jan 2025); updated Publisher Policies on ad identity (Feb 2025); **UMP**: EEA/UK users must get a Google-certified CMP consent (IAB TCF) — Google blocks personalized ads for non-compliant apps. No deceptive ads; no ads masquerading as UI; child-directed apps: no personalized ads (use `tagForChildDirectedTreatment`/TFUA).
- **Data retention:** AdMob report data retention changed from **Sept 2025**.

### App Store (iOS)
- **Guideline 5.1.1(v) — account deletion:** in-app account deletion required since **June 30, 2022** (must also revoke Sign in with Apple tokens). Same no-accounts-by-default strategy applies.
- **IAP rule (3.1.1):** digital goods consumed in-app must use **StoreKit**. External-purchase-link arrangements exist only under the EU DMA regime — don't architect for them.
- **ATT:** any tracking across apps/websites requires `ATT` permission prompt; ad SDKs must be configured to wait for consent (AdMob UMP handles this).
- **Ads:** allowed, but must not interfere with functionality, and ad disclosure/privacy labels ("Advertising data") must be accurate in the privacy "nutrition label".

### Privacy (both)
- Publish a **privacy policy**; keep data minimization as a selling point: an offline-first game collecting nothing by default is the smallest compliance surface possible. All telemetry should be opt-in and consent-gated.

---

## 6. Top 3 pitfalls for this project (condensed)

1. **Client-side-only trust.** Patching a Flutter APK is easy; granting gems from a client callback without Play Integrity + server-side receipt/token validation means free purchases and infinite rewards.
2. **Non-idempotent grants.** Duplicate `onUserEarnedReward`, restored purchases, retried webhooks, or a crash between charge and grant → double-spend. Fix once with a **generic idempotency ledger** (`claim_id` / `order_id` → state) reused by ads, purchases, daily rewards, and achievements.
3. **Consent/compliance gaps.** Serving personalized ads without a valid UMP consent/CMP, missing ATT on iOS, or (when accounts exist) missing in-app+web account deletion and accurate data-safety/privacy labels → AdMob/Play/App Store enforcement, suspension, or takedown. Also: shipping on Play after Feb 2026 without Billing Library v8 gets rejected.

---

## 7. Recommended service interfaces

Naming follows the architecture doc's composition root (`04-architecture.md`); these are the three the platform touches. Gameplay code depends only on the abstract classes; the `Mock*` implementations are the default build, production impls are wired in at the composition root and can ship later without touching games.

```dart
// core/services/advertisement_service.dart
/// Abstract rewarded-ads gateway. Always available; never throws for gameplay.
abstract interface class IAdvertisementService {
  /// True only when online + initialized + consent granted + ad preloaded.
  Future<bool> isRewardedAvailable({String placement = 'default'});

  /// Preload a rewarded ad for [placement] (best-effort; never awaited by gameplay).
  Future<void> preloadRewarded({String placement = 'default'});

  /// Show a rewarded ad. [onRewarded] fires ONLY after verified ad completion
  /// (onUserEarnedReward / SSV). Must be idempotent: pass an [idempotencyKey]
  /// and the service guarantees at-most-one grant per key.
  Future<AdShowResult> showRewarded({
    required String placement,
    required String idempotencyKey,   // claim nonce
    required void Function(RewardGrant grant) onRewarded,
  });

  /// True when the provider is the offline/dev mock (for debug UI).
  bool get isMock;
}

// core/services/purchase_service.dart
abstract interface class IPurchaseService {
  Future<PurchaseAvailability> get availability; // online? store reachable?

  /// Offerings/products; empty & non-throwing when offline or store unavailable.
  Future<List<ProductOffering>> getOfferings();

  Future<PurchaseResult> buyConsumable(String productId);      // gems
  Future<PurchaseResult> buyNonConsumable(String productId);   // remove-ads, cosmetics
  Future<bool> hasEntitlement(String entitlementId);           // cached, offline-safe
  Future<void> restorePurchases();

  Stream<PurchaseUpdate> get purchaseUpdates; // reconcile interrupted/pending
}

// core/services/analytics_service.dart
abstract interface class IAnalyticsService {
  void logEvent(String name, {Map<String, Object?> params = const {}});
  void setUserId(String? id);            // only when accounts exist
  void setProperty(String name, String value);
  Future<void> flush();                  // no-op on Mock
}
```

Implementations shipped:
- `MockAdvertisementService` — deterministic success/failure, `isMock=true`; used in offline builds, widget tests, desktop.
- `AdMobAdvertisementService` — wraps `google_mobile_ads` RewardedAd + UMP + idempotency ledger; `AppLovinMaxAdvertisementService` is a drop-in via the same interface when/if eCPM upside justifies it.
- `RevenueCatPurchaseService` — wraps `purchases_flutter`; `MockPurchaseService` grants with a test-only dev key.
- `FirebaseAnalyticsService` / `MockAnalyticsService` (log-to-console + local buffer).

All three are injected via the existing `MiniGameServices` composition root (constructor injection, no service locator) — adding a new game never requires touching monetization, and gameplay tests run against mocks.

---

## 8. Sources (accessed 2026-08-11)

- Google AdMob Flutter docs (via Context7): rewarded ads API, UMP consent flow — developers.google.com/admob/flutter/rewarded, /privacy
- google_mobile_ads releases & changelog — github.com/googleads/googleads-mobile-flutter/releases; pub.dev/packages/google_mobile_ads
- GMA Next-Gen SDK (Android) — developers.google.com/admob/android/next-gen/quick-start; LinkedIn "Google AdMob Next-Gen SDK open beta"
- Android GMA SDK 25.0.0 — ads-developers.googleblog.com/2026/02
- AdMob help: app-ads.txt (Jan 2025), data retention (Sep 2025), publisher policies (Feb 2025)
- Unity: ironSource Ads sunset FAQ — unity.com/products/ironsource-ads-sunset; docs.unity.com Grow/LevelPlay; news via pocketgamer.biz (Vector launch May 2025), gameworldobserver & gamesindustry.biz (Mar 2026 ironSource shutdown), Wikipedia/Unity
- Liftoff: pocketgamer.biz — IPO Jun 2026 ($3.83B), General Atlantic Jul 2025; unity docs "Liftoff Monetize (formerly Vungle)"
- AppLovin: Wikipedia (business status, S&P 500, Tripledot divestment, Feb 2025 short report, Oct 2025 SEC probe); AppLovin-MAX-Flutter (official plugin)
- Meta Audience Network: Meta for Developers status/docs (in-app placements live 2026); gamebizconsulting (iOS post-ATT negligible)
- RevenueCat: purchases_flutter docs (via Context7), Play Billing 8 migration blog, Play Billing Choice blog
- Flutter official IAP: pub.dev/packages/in_app_purchase, in_app_purchase_storekit
- Google Play policy: support.google.com — account/data deletion (answer 13327111), Play Billing / billingchoice, user choice billing; android-developers.googleblog.com/2026/06 (expanded billing choice)
- Apple: developer.apple.com/support/offering-account-deletion-in-your-app; App Store guideline 5.1.1(v) coverage
- Play Integrity: Firebase App Check docs (Play Integrity provider); play_integrity_flutter (pub.dev)
- Firebase Analytics: firebase.google.com/docs/analytics; pub.dev/packages/firebase_analytics; ambilytics (Windows/Linux GA4 bridge)
