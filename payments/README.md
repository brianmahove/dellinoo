# Dellinoo payments Worker

A small Cloudflare Worker that holds Paynow's secret **Integration Key** and
is the only thing (besides the admin panel) allowed to mark a Firestore
order `paid` — see `../firestore.rules`'s `allow update: if isAdmin();`.

It exists as a separate service, not a Firebase Cloud Function, because the
Firebase project is on the free **Spark** plan and Cloud Functions require
Blaze to deploy at all. Cloudflare Workers have a genuine free tier with no
billing account needed. It never touches the Flutter app's `flutter
analyze`/`flutter test` (no `.dart` files, no `pubspec.yaml`), same as how
those already ignore `../admin/`'s separate package.

## How it works

- **`POST /paynow/initiate`** — called by the app (with the customer's
  Firebase ID token) right after an order is created (unpaid, status
  `placed`). Verifies the token, loads the order from Firestore, recomputes
  the amount itself (never trusts the client), and calls Paynow to start a
  transaction — card gets a browser redirect URL, EcoCash/OneMoney/InnBucks
  get Paynow's "Express Checkout" flow.
- **`POST /paynow/webhook`** — Paynow's `resulturl`, called server-to-server
  when the transaction's status changes. Verifies Paynow's hash, and if
  `status === "Paid"`, appends a `paid` entry to the order's `history` in
  Firestore. The Flutter app never polls anything — it just listens to the
  order doc in Firestore and reacts when this shows up.
- **`GET /paynow/return`** — a static "you can switch back to the app" page
  for the card/browser flow's redirect-back target.

## One-time setup

1. **Paynow** — merchant dashboard → Advanced Integration → note the
   **Integration ID** and **Integration Key**, and confirm EcoCash, OneMoney,
   InnBucks and Card are all enabled on that integration.
2. **Firebase service account** — [Firebase Console](https://console.firebase.google.com)
   → Project Settings → Service Accounts (project `mobile-billing-system-d2bfb`)
   → "Generate new private key" → download the JSON. This file never goes
   into git — only pasted into a Cloudflare secret in step 4.
3. **Cloudflare** — create a free account (no card needed), then from this
   folder:
   ```
   npm install
   npx wrangler login
   ```
4. **Secrets** (never committed — see `.dev.vars.example` for the names):
   ```
   npx wrangler secret put PAYNOW_INTEGRATION_KEY
   npx wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON
   ```
   For the second one, paste the *entire contents* of the JSON file from
   step 2 as a single string.
5. Fill in `PAYNOW_INTEGRATION_ID` in `wrangler.toml` (plain, not secret).
6. Deploy:
   ```
   npx wrangler deploy
   ```
   Note the printed `https://dellinoo-payments.<subdomain>.workers.dev` URL.
7. Paste that URL into `../lib/core/payments.dart`'s `kPaymentsWorkerUrl`
   (it doesn't exist until after this first deploy).

## Local development

```
cp .dev.vars.example .dev.vars   # fill in real values, gitignored
npm run dev                       # wrangler dev
npm run tail                      # live logs against the deployed Worker
npm run typecheck
```

## Testing

Paynow's test mode is automatic — no separate sandbox toggle. Every new
Integration ID starts in test mode; fixed test identifiers simulate outcomes:

- Mobile money (EcoCash/OneMoney/InnBucks): `0771111111` success,
  `0772222222` delayed success, `0773333333` user-cancelled, `0774444444`
  insufficient balance.
- Card: test tokens `{11111111-1111-1111-1111-111111111111}` success,
  `{22222222-...}` pending, `{33333333-...}` cancelled, `{44444444-...}`
  insufficient balance.

Once all four payment methods pass a real end-to-end test (order created →
`PaymentWaitDialog` shown → Firestore listener sees `paid`), ask Paynow
support to "Set Live" on the integration.
