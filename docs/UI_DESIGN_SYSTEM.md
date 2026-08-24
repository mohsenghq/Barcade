# UI Design System — "Cosmic Toybox"

The visual language for Starcade. One set of tokens (`lib/ui/theme/cosmic_toybox.dart`),
one widget kit (`lib/ui/theme/widgets.dart`), and every screen in the app derives from
both. Games reach in for the raw tokens because Flame paints its own canvas.

Companion to `TECHNICAL_DECISIONS.md` (decision **D7**). Status: **current**.

---

## 1. Principles

1. **Deep space, warm accents.** Indigo gradient ground; coral, cyan, gold, mint
   do the talking. Nothing is flat white-on-black.
2. **Motion is physics, not decoration.** Springy overshoot on entrances, squash
   on press, fast fade-out on exits. Nothing eases the same way twice by accident.
3. **Everything is a card.** Surfaces are translucent glass (white at 8–18%
   alpha) over the gradient, softly rounded.
4. **Rewards glow.** Gold is reserved for currency/rewards/stars; mint for
   success/level-ups; ember for danger/misses. Color carries meaning.

---

## 2. Tokens (`Ct`, `cosmic_toybox.dart`)

### Palette

| Token | Hex | Role |
|---|---|---|
| `Ct.indigo` | `#1B1533` | primary surface |
| `Ct.indigoDeep` | `#130E24` | screen background |
| `Ct.indigoLight` | `#241A45` | lifted surface |
| `Ct.coral` / `coralHot` | `#FF5A5F` / `#FF7A72` | primary action |
| `Ct.cyan` | `#29E0E0` | secondary action, "energy" |
| `Ct.gold` | `#FFC53D` | rewards, stars, achievements |
| `Ct.mint` | `#3DDC97` | success, level-up |
| `Ct.ember` | `#FF4D6D` | danger, misses |
| `Ct.white` | `#F6F3FF` | text on dark |
| `Ct.ink` | `#0B0817` | text on light (rare) |

### Glass surfaces

| Token | Value | Use |
|---|---|---|
| `Ct.surface` | `0x14FFFFFF` (8%) | cards, panels |
| `Ct.surfaceStrong` | `0x24FFFFFF` (14%) | chips, active tiles |
| `Ct.surfaceStroke` | `0x2EFFFFFF` (18%) | borders |

### Shape

| Token | Value | Use |
|---|---|---|
| `Ct.radius` | 20 | cards, buttons, modals |
| `Ct.radiusSmall` | 12 | chips, stat pills |

### Motion (all durations from Ct — never hard-code elsewhere)

| Token | Value | Use |
|---|---|---|
| `Ct.popIn` | 520ms | big entrances (result overlay, cards) |
| `Ct.enter` | 260ms | small entrances (rows, chips) |
| `Ct.press` | 120ms | button squash |
| `Ct.easeOutBack` | `Curves.easeOutBack` | the springy overshoot |

> ⚠ `easeOutBack` overshoots past 1.0. When its output feeds `Opacity` (e.g. the
> star pop in `StarsRow`), clamp to `[0, 1]` — see `widgets.dart`.

### Gradients & glow

- `Ct.background` — radial aurora bloom behind the hub content.
- `Ct.shimmer` — three-stop indigo sweep (shimmering lock overlay).
- `Ct.glowShadow` — coral glow used by the primary button.

---

## 3. Typography

- **Display/headings/buttons:** Nunito w800, `tabularFigures` for counters so
  digits don't jitter while animating.
- **Body:** Inter, w400–500.
- Scale (`cosmicTheme().textTheme`): `displayLarge` 44, `displayMedium` 32,
  `headlineMedium` 26, `titleLarge` 20, `titleMedium` 16, `titleSmall` 14,
  `bodyLarge/Medium/Small` 16/14/12, `labelLarge` 16 (buttons).
- Game HUDs use the same Nunito w800 via `TextPaint` (`cosmic_toybox.dart`'s
  `_display` style is the source of truth; game HUDs hard-pin their own sizes
  because Flame text layout differs from Flutter).

---

## 4. Component kit (`widgets.dart`)

| Component | Purpose | Motion |
|---|---|---|
| `CosmicBackground` | gradient + drifting `_MoteField` (24 motes) | perpetual drift |
| `PopIn` | scale+fade entrance (overshoot) | `popIn` + `easeOutBack` |
| `FadeSlideIn` | slide-up fade for lists/rows | `enter` |
| `GlowButton` | primary CTA (glow on filled, outline on ghost) | `press` squash |
| `PillButton` | small secondary action | `press` squash |
| `AnimatedCounter` | tick-up integer (currencies, scores, XP) | ~300ms |
| `XpBar` | XP progress with eased width | ~500ms |
| `StarsRow` | 0–3 star result, pop-in per star | `popIn` + overshoot (clamped) |
| `ConfettiBurst` | one-shot victory burst (deterministic) | 1600ms rise+fall+fade |

### Button pattern

`GlowButton` squashes on press (`Ct.press`), glows when filled. Icon buttons
(the hub top bar, game chrome) are `CircleBorder` ink wells on `surfaceStrong`.
Never mix two filled CTAs in one overlay — one filled, one ghost.

---

## 5. Screens

| Screen | Composition |
|---|---|
| **Hub** | header (greeting + level), currency pills, daily-reward bar, sliver grid of game cards |
| **Game card** | accent glow edge, shimmer lock overlay when locked, `NEW` tag |
| **Game chrome** | top bar (back / title / pause), shared `FlameGameHost` tap-to-start gate, pause overlay |
| **Result overlay** | headline, `StarsRow`, `_RewardCard` (score + coins/XP/gems chips, level-up line), achievement chips, confetti on win |
| **Achievement feedback** | gold-bordered chip: icon + title + `+N 💎` per newly-unlocked achievement |

---

## 6. Rules for contributors

1. Pull from `Ct` and `widgets.dart` — no new hex colors, no hard-coded
   `Duration`s, no hand-rolled entrance animation when `PopIn`/`FadeSlideIn`
   fit.
2. New screens: start from `CosmicBackground` + `SafeArea` + the correct text
   style; don't invent layout primitives.
3. Flame games: use tokens for palette + `TextPaint` HUD with Nunito w800.
4. `Opacity` fed from `easeOutBack` must clamp. `IconData` for achievements is
   mapped once in `game_screen.dart` (`_achievementIcon`) — add new icons there,
   not inline.
5. Adding a shared widget? It belongs in `widgets.dart`, documented here.
