# Dellinoo

Flutter e-commerce app for a client who **buys goods in China and sells them to customers in Zimbabwe**. Think "a simpler SHEIN": clothes (men, women, kids), shoes, handbags, phones, watches, laptops, games, electronics.

- **Platform:** Android first (package `com.dellinoo.app`). iOS later.
- **Status:** customer UI complete; Firebase backend is real and live — auth (email/password, Google, Facebook), catalogue and orders all run on Firestore, not mocks. Payments (Paynow) aren't built yet; the admin panel has a working v1 (see Roadmap).
- **Timeline agreed with client (Sep 2026):** UI shown Sat 27 Sep → backend the following week.
- **Backend:** Firebase, project `mobile-billing-system-d2bfb` (existing project, reused).
- **Admin panel:** separate Flutter web app, `admin/` (own `pubspec.yaml`, not part of the `dellinoo` package) — live at **https://dellinoo-admin.web.app**. See Roadmap item 4.
- **Firebase Hosting** has two sites: the default site (target `marketing`, public dir `hosting/`, plain static HTML) live at `https://mobile-billing-system-d2bfb.web.app` — `privacy.html`/`data-deletion.html` for Google/Facebook App Review — and `dellinoo-admin` (target `admin`, public dir `admin/build/web`) for the admin panel above. Redeploy both with `firebase deploy --only hosting` from the repo root (needs `firebase login` or a CI token once); rebuild the admin app first (`cd admin && flutter build web --release`) since Hosting serves its static build output, not live code.

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
    brand.dart              BrandMark/BrandLogo/BrandHero — the client's real bag-and-smile logo (assets/images/logo_*.png)
  features/<area>/          one folder per screen area (auth/ includes welcome, login, signup, splash, otp)
```

- **State:** Riverpod 3 (`Notifier` / `NotifierProvider`, no legacy `StateProvider`).
- **Backend swap point:** screens only use `CatalogRepository` via `catalogRepositoryProvider`. Replace `MockCatalogRepository` with the real API; screens shouldn't change. Cart/orders/wishlist notifiers will need API calls too.
- **Persistence:** `prefsProvider` (SharedPreferences, overridden in `main()`; `null` in tests, so persisted notifiers must tolerate null). Persisted: theme mode, data saver, recently viewed, recent searches, welcome-seen flag.
- **Navigation:** go_router. Tabs (Home, Shop `/categories`, Cart, Profile) are a `StatefulShellRoute` with `FadeThroughTabs` (keeps tab state). Other pages are top-level routes. `/product/:id` takes a Hero tag via `extra`.

## Design system

Rebranded (Sep 2026) from the original yellow/black reference mockups to the client's real logo: **deep violet `#5B21D6`** (primary) with an **orange `#FF8A00`** accent, violet/orange gradients for brand moments and buttons, warm gold `#FFC107` kept only for ratings/stars. Black `#020910` stays for always-dark surfaces. Pill buttons, tinted product cards, floating nav bar. Font is **Urbanist** (free stand-in for the paid Gilroy; swap in `buildTheme`).

### Colours and dark mode
- All colours live in `AppColors` (`lib/core/theme.dart`). Most are **getters that flip with `AppColors.dark`** — so they are **not `const`**; don't put them in `const` widgets. `primary`/`primaryLight`/`accentOrange`/`gold`/`black`/`onPrimary` are fixed `const`s (same in both modes).
- Anything drawn **on `primary` or `accentOrange`** must use `AppColors.onPrimary` (always white), never `AppColors.ink` (which turns light in dark mode).
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
- **Privacy Policy / Data Deletion pages** (`hosting/privacy.html`, `hosting/data-deletion.html`, deployed to Firebase Hosting for Facebook/Google App Review — see live URLs below): drafted by Claude, not reviewed by the client or a lawyer. Update once "delete my account" is a real feature.

Resolved: the logo is now the client's real bag-and-smile mark (`assets/images/logo_*.png`, `lib/widgets/brand.dart`), and the launcher icon / native launch screen (`assets/icon/`, `res/drawable*/launch_background.xml`, `values-v31`) were updated to match in the violet/orange rebrand. Regenerate the launcher icon with `dart run flutter_launcher_icons` if `assets/icon/` changes again.

## Roadmap

**Needed to launch**
1. Firebase backend: Firestore (products, categories, stock, orders, users) behind `CatalogRepository`; Storage for product photos. Cart/wishlist/orders notifiers in `state/providers.dart` need to call it too, not just the repository. *(Firebase project wired in Sep 2026: `mobile-billing-system-d2bfb`, Android app `com.dellinoo.app`, `firebase_core`/`cloud_firestore`/`firebase_auth`/`firebase_storage` added, `Firebase.initializeApp()` in `main.dart`.)*
   - **Done:** `FirestoreCatalogRepository` (`lib/data/firestore_catalog_repository.dart`) is the default (`catalogRepositoryProvider`) — reads `products` and `delivery_areas` collections; categories stay the fixed `mockCategories` list (Firestore can't hold a Flutter `IconData`, and categories aren't in the admin panel's scope). `firestore.rules`/`firestore.indexes.json` are deployed (public read, `allow write: if false` — nothing writes from the client; the admin panel/Cloud Functions write instead, roadmap item 4). The 60 mock products + 6 delivery areas were seeded into Firestore once via an IAM-authenticated script (not the app), so the live data is currently just the demo catalogue under real infrastructure — the admin will replace it with real products. Unit tests override `catalogRepositoryProvider` back to `MockCatalogRepository` (see `test/widget_test.dart`) so they don't depend on live Firestore/network.
   - **Done:** orders are Firestore-backed too. `OrderRepository`/`FirestoreOrderRepository` (`lib/data/order_repository.dart`, `firestore_order_repository.dart`) — an `orders` collection scoped by `userId`, plus a `meta/orderCounter` doc (transactional +1) that generates the `DL#####` display ids, starting at `DL10300`. `OrdersNotifier` watches `authProvider` and reloads on sign-in/out; `place()` writes through the repository then updates local state optimistically. **Checkout now requires sign-in** — `/checkout`'s router redirect sends signed-out users to `/login` first (decided Sep 2026: real accounts needed since orders are uid-scoped; no guest/anonymous checkout). Login/signup pop back to wherever they were pushed from (e.g. checkout) instead of always going to `/home`. `firestore.rules`: a user may only read/create their own orders (`request.auth.uid == ... userId`); status updates are admin-only (`if false`) until the admin panel exists. Composite index (`userId` + `createdAt`) deployed for the order-history query. Unit tests override both `authProvider` (a Firebase-free fake) and `orderRepositoryProvider` (`MockOrderRepository`) — see `test/widget_test.dart`.
     - **Not yet verified against the real client path**: everything above was tested by writing directly via an IAM-authenticated script, which bypasses Firestore security rules entirely. The rules themselves (`orders`/`meta/orderCounter`) haven't been exercised by an actual signed-in app user yet — do a real checkout on the emulator to confirm the rules are correct in practice, not just on paper.
   - Still open from this item: Storage for product photos, and cart/wishlist still run locally, not through Firestore (kept local deliberately for now — cart is pre-purchase/ephemeral).
2. ~~Firebase Auth phone OTP login~~ **Done differently:** login/signup run on Firebase **Email/Password**, **Google Sign-In** and **Facebook Login** (`AuthNotifier` in `state/providers.dart`, wired into `login_screen.dart`/`signup_screen.dart`), matching the email/password UI from the violet/orange rebrand. Facebook app ID/client token live in `android/app/src/main/res/values/strings.xml` and `AndroidManifest.xml` (app "dellinoo", App ID `1347562878439050` — App Secret is Firebase-console-only, never in the repo). The Facebook app is still in **development mode** (missing real icon/category/privacy links for public App Review — see Placeholders). Apple Sign-In stays "coming soon" (no Apple Developer account yet; app is Android-only). The phone-OTP screen (`otp_screen.dart`) still exists but isn't linked into navigation — `AuthNotifier.signIn(phone)` stays a mock for it. Revisit if the client wants phone-only login later.
3. Paynow payments + payment confirmation (replace the simulated `_PaymentDialog`), likely via Cloud Functions.
4. Admin panel: separate Flutter web app in this repo (Firebase Hosting), covering products/photos, stock type, order status updates, delivery areas & fees.
   - **v1 done (Sep 2026):** `admin/` is its own Flutter project (own `pubspec.yaml`, not part of the `dellinoo` package — `flutter analyze`/`test`/`build` in the repo root never touch it) with `firebase_core`/`cloud_firestore`/`firebase_auth`, deployed at **https://dellinoo-admin.web.app** (a second Firebase Hosting site, target `admin` — the marketing/privacy pages stay on the default site, target `marketing`; both deploy via `firebase deploy --only hosting` from the repo root, or `--only hosting:admin` / `hosting:marketing` for just one). `cd admin && flutter build web --release` before deploying — Hosting serves the built `admin/build/web`, not live-reloaded.
   - **Auth/authorization:** email/password or "Sign in with Google" (`signInWithPopup` — simpler on web than mobile, no `google_sign_in` package needed). Who's an admin is an **email allowlist**, the `admins/{email}` Firestore collection (doc existing = admin), checked both client-side (`admin/lib/shell.dart`, UX only) and in `firestore.rules`' `isAdmin()` (the actual enforcement — products/delivery_areas writes and order status updates all gate on it). Seeded once via IAM script: only `mahovebrian@gmail.com` is an admin right now; add more later with a Firestore write to `admins/<their-email>` (any value, doc just needs to exist).
   - **Screens:** Products (list/add/edit/delete — photo is a pasted URL for now, no upload until Storage/Blaze), Orders (list all, expand for items/history, append a new status event), Delivery areas (list/add/edit/delete).
   - **Not shared with the customer app:** admin duplicates the product/order field names and the fixed category-id list by hand (see comments in `admin/lib/products_screen.dart`/`orders_screen.dart`) rather than through a shared package — a real code-sharing extraction (e.g. `packages/dellinoo_core/`) is a reasonable future cleanup, not done here to avoid a risky refactor of the already-shipped customer app's imports.
   - **Design (Sep 2026):** restyled to match the customer app's violet/orange brand rather than default Material — `admin/lib/theme.dart` is a hand-ported, light-mode-only copy of the customer app's `AppColors`/`buildTheme()` (same colours, Urbanist font, stadium buttons, 22px card radius), plus the real logo (`admin/assets/images/logo_icon.png`, `logo_full.png`, copied from the customer app's assets). Responsive for both desktop and mobile web: `shell.dart` switches at 720px between a `NavigationRail` sidebar (desktop) and a bottom `NavigationBar` (mobile) via `LayoutBuilder`; Products is a responsive `GridView` (auto-fits columns by width); Orders/Delivery areas are centred, width-capped (900px) lists so they don't stretch full-bleed on wide monitors. Same "not shared, kept in sync by hand" caveat as the field names above — if the customer app's palette changes, `admin/lib/theme.dart` needs the same edit made twice.
   - **Resolved (Sep 2026):** `dellinoo-admin.web.app` was missing from Firebase Auth's authorized-domains list, so Google sign-in failed with "This domain is not authorized for OAuth operations." Added via Authentication → Settings → Authorized domains; sign-in confirmed working. If it's ever removed/reset, that's the fix.
5. Push notifications via Firebase Cloud Messaging (order status, price drops). Blocked like Storage/Paynow — needs a Cloud Function (Firestore `onUpdate` trigger on `orders`) to actually fire when the admin changes status, which needs Blaze.

**Business extras**
6. "Request an item" (paste SHEIN/Temu/Alibaba link or photo → quote).
7. Deposit now, balance on arrival (China orders).
8. Coupons / first-order discount.
9. Reviews with photos.
10. Flash sales with countdown.
11. Refer-a-friend.
12. ~~Share product to WhatsApp.~~ **Done (Sep 2026):** `shareToWhatsApp()` in `core/contact.dart` opens WhatsApp's own contact/group picker (no recipient) with the product name/price — a share icon on the product page (`product_detail_screen.dart`), distinct from `openWhatsApp()` which always messages Dellinoo's own number.

**Experience / tech**
13. Offline mode + banner. 14. Pull-to-refresh everywhere, infinite scroll. 15. Visual search (camera icon already in search bar). 16. ~~Multiple saved addresses.~~ **Done (Sep 2026):** `AddressBookNotifier`/`addressBookProvider` (Firestore `users/{uid}/addresses`, owner-only rules), a full `AddressesScreen` (list/add/edit/delete/set-default, reachable from Profile's "Delivery addresses"), and checkout now picks from saved addresses (`_AddressPicker`) instead of a hardcoded demo address — checkout requires sign-in already, so this is a natural fit. 17. ~~Order again.~~ **Done (Sep 2026):** a button on the order detail screen re-adds that order's items to the cart at *today's* prices (not the historical snapshot), skipping and reporting any since-removed products. 18. ZiG/USD toggle. 19. ~~Crash reporting + analytics.~~ **Done (Sep 2026):** Firebase Crashlytics (`FlutterError.onError` + `runZonedGuarded`, disabled in debug builds via `kDebugMode`) and Firebase Analytics (automatic screen tracking via `FirebaseAnalyticsObserver` on the router, plus `logSignUp`/`logLogin`/`logAddToCart`/`logPurchase` at the relevant call sites in `state/providers.dart`) — both free on Spark. All analytics calls go through a `_logSafely()` wrapper so a logging hiccup (or Firebase not being initialized, e.g. in unit tests) can never break real functionality like adding to cart. 20. Real app icon/splash + Play Store listing.
