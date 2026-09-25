# Dellinoo

Flutter e-commerce app for a client who **buys goods in China and sells them to customers in Zimbabwe**. Think "a simpler SHEIN": clothes (men, women, kids), shoes, handbags, phones, watches, laptops, games, electronics.

- **Platform:** Android first (package `com.dellinoo.app`). iOS later.
- **Status:** customer UI complete on **mock data**. Backend, real auth, payments and admin panel are not built yet (see Roadmap).
- **Timeline agreed with client (Sep 2026):** UI shown Sat 27 Sep → backend the following week.

## Ownership & licence

- **Designed & developed by Vizion.** Proprietary: © 2026 Vizion, all rights reserved (see `LICENSE`).
- App credits live in `lib/core/app_info.dart` (`AppInfo.developer`, `copyright`, `version`) and appear on the splash ("by Vizion"), Profile footer and About page (`/about`).
- Third-party licences show in-app via Flutter's licence page; the vendored Iconly licence is registered in `main()`. Keep `LICENSE`'s third-party list in sync when adding assets.

## Business rules

- Every product is either **In stock** (already in Zimbabwe, 1–3 days) or **From China** (pre-order, ~2–3 weeks). The UI always shows a concrete date ("Get it by 28 Sep" / "Arrives 16 Oct"), from `StockStatus.etaDays` (3 / 21) via `arrivalShort` / `arrivalLong` in `lib/core/format.dart`.
- Prices in **USD**. Payments via local gateways (**Paynow**: EcoCash, OneMoney, InnBucks, Visa/Mastercard/ZimSwitch).
- **Delivery areas and fees are managed by the admin** (mock list in `mock_data.dart`), including a free pickup point.
- Orders with China items go through extra steps: **Bought in China → Flying to Zimbabwe → Arrived in Harare** (`OrderStatus.chinaLeg`, `Order.journey`).
- The admin adds products and updates order status.

## Commands

```bash
flutter pub get
flutter analyze          # must be clean
flutter test
flutter run              # Android emulator/device
```

- Flutter SDK is at `C:\develop\flutter\bin` (not on PATH in the agent shell: `export PATH="/c/develop/flutter/bin:$PATH"`).
- Format with `dart format -l 120 lib test`.
- **Don't build/preview the web version** — the user tests on an Android emulator.
- Route or Android-manifest changes need a **full restart / `flutter run`**, not hot reload.

## Architecture

```
lib/
  main.dart                 loads SharedPreferences, ProviderScope, theme/dark-mode switching
  core/
    theme.dart              AppColors (light/dark), buildTheme()
    router.dart             go_router routes; tabs = StatefulShellRoute
    format.dart             money, dates, arrival promises
    iconly.dart             Iconly icon font classes (vendored, see below)
    contact.dart            WhatsApp number + openWhatsApp()
  data/
    models.dart             Product, CartItem, Order, OrderStatus, StockStatus, ...
    catalog_repository.dart CatalogRepository interface + MockCatalogRepository
    mock_data.dart          categories, delivery areas, demo orders
    mock_products.dart      GENERATED demo catalogue (dummyjson.com images)
  state/providers.dart      all Riverpod providers (cart, wishlist, orders, recents, settings)
  widgets/
    common.dart             shared UI: ProductCard, grids, pills, stepper, empty states, heroes
    glass.dart              GlassBox, glass dialogs/sheets/toasts
    brand.dart              placeholder logo
  features/<area>/          one folder per screen area
```

- **State:** Riverpod 3 (`Notifier` / `NotifierProvider`, no legacy `StateProvider`).
- **Backend swap point:** screens only use `CatalogRepository` via `catalogRepositoryProvider`. Replace `MockCatalogRepository` with the real API; screens shouldn't change. Cart/orders/wishlist notifiers will need API calls too.
- **Persistence:** `prefsProvider` (SharedPreferences, overridden in `main()`; `null` in tests, so persisted notifiers must tolerate null). Persisted: theme mode, data saver, recently viewed, recent searches, welcome-seen flag.
- **Navigation:** go_router. Tabs (Home, Shop `/categories`, Cart, Profile) are a `StatefulShellRoute` with `FadeThroughTabs` (keeps tab state). Other pages are top-level routes. `/product/:id` takes a Hero tag via `extra`.

## Design system

Design comes from reference mockups the user supplied: **yellow `#FFC107`, black `#020910`, grey, white on beige**, pill buttons, tinted product cards, floating nav bar. Font is **Urbanist** (free stand-in for the paid Gilroy; swap in `buildTheme`).

### Colours and dark mode
- All colours live in `AppColors` (`lib/core/theme.dart`). Most are **getters that flip with `AppColors.dark`** — so they are **not `const`**; don't put them in `const` widgets.
- Anything drawn **on yellow** must use `AppColors.black` (always black), never `AppColors.ink` (which turns light in dark mode).
- Surfaces use `AppColors.surface`, not `Colors.white`. Text on an `ink`-filled surface uses `AppColors.onInk`.
- Theme switching remounts `MaterialApp` (keyed by brightness); navigation and Riverpod state survive.

### Glass (iPhone-style frosted material)
- `GlassBox` = saturated blur + tint + top sheen + bright rim (+ optional outside-only shadow). Use it **only where content is behind it** (over photos, above scrolling content).
- Glass fills: `AppColors.glass(alpha)` (dark-mode aware). Put **black/ink text on light glass**.
- `GlassGroup` (= `BackdropGroup`) shares one blur pass. **Only wrap a single card**, never a whole scrolling screen — a shared snapshot goes stale and smears.
- Never give translucent glass a normal `BoxShadow` (it shows through as a smudge); use `GlassBox(shadow: true)`.
- Popups: use `showGlassDialog`, `showGlassBottomSheet` (always full width), `showGlassToast` — not the plain Flutter versions.
- `GlassBox.enabled = false` turns blur off for cards/nav/toasts if low-end phones struggle.

### Icons
- **Iconly** (Light/Bold) via `lib/core/iconly.dart` + fonts in `assets/fonts/`. The `iconly` pub package is **broken on current Flutter** (subclasses final `IconData`) — don't re-add it.
- Material icons remain only where Iconly has no equivalent (truck, +/−, radio, close, check, some category fallbacks).
- WhatsApp logo: `font_awesome_flutter` (`FaIcon(FontAwesomeIcons.whatsapp)`).

### Motion
- Card → product page: **only the photo** flies (`ProductPhotoHero`, straight-line `RectTween`); the page fades (`CustomTransitionPage`, 750ms / 600ms back).
- **Hero tags must be unique per screen:** `'product-$heroScope-$id'` (scopes: `grid`, `deals`, `similar`, `wishlist`, `recent`). Product cards are **keyed by product** so Flutter never reuses a card (and its Hero) for another product — removing these keys brings back the `manifest.tag == newManifest.tag` crash.
- Don't mutate Home's data while a Hero is in flight (e.g. "recently viewed" is recorded ~900ms after opening a product).
- Grids replay a staggered `FadeInUp` when `ProductSliverGrid.animateKey` changes (first 6 cards only).
- Pushed pages use the Cupertino slide; tabs use fade-through; haptics on add-to-cart, variant pick, errors.
- Reusable motion pieces live in `lib/widgets/motion.dart`: `PressScale`, `AnimatedMoney`, `ShimmerSweep`, `showHeartBurst`, `DrawnCheck`, `ConfettiBurst`, `logoRefreshIndicator`, `ThemeReveal`. Decorative effects respect the OS "reduce motion" setting (`reduceMotion`).
- `ThemeReveal` wraps `MaterialApp`, so it has **no MediaQuery** — use `View.of(context)` there. Trigger with `themeRevealKey.currentState?.reveal(origin, switchTheme)`.
- Home and Shop use `BouncingScrollPhysics` + `CupertinoSliverRefreshControl` (logo pull-to-refresh).

### Layout conventions
- Page side padding 20; cards radius 22; pills are stadium shapes.
- Tab screens must leave `kNavBarSpace` at the bottom so content scrolls clear of the floating nav bar.

## Placeholders — confirm with the client before release

- **WhatsApp number**: `kWhatsAppNumber` in `lib/core/contact.dart` (currently fake).
- **Warranty / returns claims** on product pages (`_TrustBadges`: "6-month warranty", "7-day easy returns").
- **Size charts** (`lib/features/product/size_guide.dart`), **delivery fees/areas/times**, `etaDays` (3 / 21).
- Demo catalogue has no real kids' clothing or video games (Kids = girls' dresses, Games = sports balls).
- Logo is a placeholder "D" mark (`lib/widgets/brand.dart`); final colours may change with the real logo.

## Roadmap

**Needed to launch**
1. Backend + database (products, categories, stock, orders, users) behind `CatalogRepository`.
2. Real phone OTP login (Zimbabwe numbers).
3. Paynow payments + payment confirmation (replace the simulated `_PaymentDialog`).
4. Admin panel: products/photos, stock type, order status updates, delivery areas & fees.
5. Push notifications (order status, price drops).

**Business extras**
6. "Request an item" (paste SHEIN/Temu/Alibaba link or photo → quote).
7. Deposit now, balance on arrival (China orders).
8. Coupons / first-order discount.
9. Reviews with photos.
10. Flash sales with countdown.
11. Refer-a-friend.
12. Share product to WhatsApp.

**Experience / tech**
13. Offline mode + banner. 14. Pull-to-refresh everywhere, infinite scroll. 15. Visual search (camera icon already in search bar). 16. Multiple saved addresses. 17. Order again. 18. ZiG/USD toggle. 19. Crash reporting + analytics. 20. Real app icon/splash + Play Store listing.
