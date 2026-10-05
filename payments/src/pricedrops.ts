import type { Env } from './types';
import { getDocFields, patchNumbers, queryDocs, setTimestamp, type LoadedDoc } from './firestore';
import { sendToUser, type PushMessage } from './fcm';

// Wishlist price-drop alerts. Runs on the Worker's cron trigger (see
// wrangler.toml), and on demand from the admin panel's Notifications screen
// via POST /notify/price-drops. Spark has no scheduled Cloud Functions;
// Cloudflare cron triggers are free.
//
// Each customer's wishlist lives at `users/{uid}/wishlist/{productId}` with
// `savedPrice` (written by the app, lib/state/providers.dart's
// WishlistNotifier). This job adds `notifiedPrice` after alerting, and only
// alerts again if the price falls *below that*, so a customer hears about
// each new low once, not every six hours.
//
// Cost on the Spark quota (50k reads/day): the admin panel stamps
// `priceChangedAt` on a product only when its price is *cut*
// (admin/lib/products_screen.dart), and this job only looks at products
// stamped since its last run (`meta/priceDropJob.lastRunAt`). A run where
// nothing got cheaper — most runs — costs ~2 reads (that doc + an empty
// query). Otherwise it reads the cut products plus only the wishlist entries
// for those products (by their `productId` field, collection-group index in
// firestore.indexes.json), never every wishlist.

// Re-check a little before the last run, in case a cut landed while it was
// running or clocks differ; `notifiedPrice` stops a double alert.
const OVERLAP_MS = 10 * 60 * 1000;
const META_PATH = 'meta/priceDropJob';

export interface PriceDropSummary {
  productsCut: number;
  wishlistItems: number;
  drops: number;
  customersNotified: number;
  devicesReached: number;
}

const money = (n: number) => `$${n.toFixed(2)}`;

export async function runPriceDrops(env: Env, accessToken: string): Promise<PriceDropSummary> {
  const runStartedAt = new Date();
  const meta = await getDocFields(META_PATH, env, accessToken);
  const lastRun = typeof meta?.lastRunAt === 'string' ? Date.parse(meta.lastRunAt) : 0;
  const since = new Date(Math.max(0, lastRun - OVERLAP_MS));

  const products = await queryDocs(
    {
      from: [{ collectionId: 'products' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'priceChangedAt' },
          op: 'GREATER_THAN',
          value: { timestampValue: since.toISOString() },
        },
      },
    },
    env,
    accessToken,
  );
  const catalogue = new Map<string, { name: string; price: number }>();
  for (const p of products) {
    const id = p.path.split('/').pop()!;
    if (typeof p.fields.price === 'number') catalogue.set(id, { name: String(p.fields.name ?? 'An item'), price: p.fields.price });
  }

  const empty: PriceDropSummary = { productsCut: 0, wishlistItems: 0, drops: 0, customersNotified: 0, devicesReached: 0 };
  if (catalogue.size === 0) {
    // Nothing got cheaper: no wishlist reads, and no write to lastRunAt
    // either (the window just stays open until something changes).
    console.log('pricedrops: no price cuts since last run');
    return empty;
  }

  // Firestore caps `IN` at 30 values per query.
  const ids = [...catalogue.keys()];
  const wishlistItems: LoadedDoc[] = [];
  for (let i = 0; i < ids.length; i += 30) {
    const chunk = ids.slice(i, i + 30);
    wishlistItems.push(
      ...(await queryDocs(
        {
          from: [{ collectionId: 'wishlist', allDescendants: true }],
          where: {
            fieldFilter: {
              field: { fieldPath: 'productId' },
              op: 'IN',
              value: { arrayValue: { values: chunk.map((id) => ({ stringValue: id })) } },
            },
          },
        },
        env,
        accessToken,
      )),
    );
  }

  // uid -> drops for that customer
  const byUser = new Map<string, Array<{ path: string; productId: string; name: string; was: number; now: number }>>();
  for (const item of wishlistItems) {
    // users/{uid}/wishlist/{productId}
    const [, uid, , productId] = item.path.split('/');
    const product = catalogue.get(productId);
    const saved = item.fields.savedPrice;
    if (!product || typeof saved !== 'number') continue;
    const notified = typeof item.fields.notifiedPrice === 'number' ? item.fields.notifiedPrice : Infinity;
    if (product.price > Math.min(saved, notified) - 0.01) continue;
    const list = byUser.get(uid) ?? [];
    list.push({ path: item.path, productId, name: product.name, was: saved, now: product.price });
    byUser.set(uid, list);
  }

  const summary: PriceDropSummary = { ...empty, productsCut: catalogue.size, wishlistItems: wishlistItems.length };
  for (const [uid, drops] of byUser) {
    summary.drops += drops.length;
    try {
      // Opt-out from the app's Settings ("Price drop alerts"); default on.
      const profile = await getDocFields(`users/${uid}`, env, accessToken);
      if (profile?.priceDropAlerts !== false) {
        const sent = await sendToUser(uid, priceDropMessage(drops), env, accessToken);
        summary.devicesReached += sent;
        if (sent > 0) summary.customersNotified++;
      }
      // Marked even when opted out or no device got it, so the alert isn't
      // retried every run; a further drop still triggers a new one.
      for (const d of drops) await patchNumbers(d.path, env, accessToken, { notifiedPrice: d.now });
    } catch (err) {
      console.error(`pricedrops: uid=${uid} failed`, err);
    }
  }
  // Only after the whole run: if it died part-way, the next run re-checks
  // the same window (notifiedPrice prevents repeat alerts).
  await setTimestamp(META_PATH, 'lastRunAt', runStartedAt, env, accessToken);
  console.log(`pricedrops: ${JSON.stringify(summary)}`);
  return summary;
}

function priceDropMessage(drops: Array<{ productId: string; name: string; was: number; now: number }>): PushMessage {
  if (drops.length === 1) {
    const [d] = drops;
    return {
      title: 'Price drop on your wishlist',
      body: `${d.name} is now ${money(d.now)} (was ${money(d.was)}).`,
      data: { route: `/product/${d.productId}` },
      channel: 'price_drops',
    };
  }
  const names = drops.slice(0, 2).map((d) => d.name).join(', ');
  return {
    title: `${drops.length} wishlist items got cheaper`,
    body: drops.length > 2 ? `${names} and more are on sale.` : `${names} are on sale.`,
    data: { route: '/wishlist' },
    channel: 'price_drops',
  };
}
