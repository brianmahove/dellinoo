import type { Env } from './types';

// Talks to Firestore over its plain REST API, authenticated as a Google
// service account (not the `firebase-admin` SDK — it needs Node APIs the
// Workers runtime doesn't have). A request signed this way is a privileged,
// server-side identity: it bypasses ../firestore.rules entirely, the same
// trust level the Admin SDK would have — this Worker is the ONLY thing
// (besides the admin panel) allowed to write an order's status.

interface ServiceAccount {
  client_email: string;
  private_key: string;
}

type FirestoreValue =
  | { stringValue: string }
  | { integerValue: string }
  | { doubleValue: number }
  | { booleanValue: boolean }
  | { timestampValue: string }
  | { nullValue: null }
  | { mapValue: { fields?: Record<string, FirestoreValue> } }
  | { arrayValue: { values?: FirestoreValue[] } };

const FIRESTORE_BASE = 'https://firestore.googleapis.com/v1';

function docPath(env: Env, orderId: string): string {
  return `projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/orders/${orderId}`;
}

function base64Url(bytes: ArrayBuffer | string): string {
  const arr = typeof bytes === 'string' ? new TextEncoder().encode(bytes) : new Uint8Array(bytes);
  let binary = '';
  for (const b of arr) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const body = pem.replace(/-----BEGIN PRIVATE KEY-----/, '').replace(/-----END PRIVATE KEY-----/, '').replace(/\s+/g, '');
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

// Reused across requests within the same Worker isolate to cut down on
// token-endpoint round trips; harmless to lose on a cold start.
let cachedToken: { token: string; expiresAt: number } | null = null;

export async function getAccessToken(env: Env): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 30_000) {
    return cachedToken.token;
  }
  const serviceAccount = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON) as ServiceAccount;
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: serviceAccount.client_email,
    // One token covers both Firestore (orders) and FCM (push notifications,
    // see fcm.ts) — the service account already has both roles.
    scope: 'https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const signingInput = `${base64Url(JSON.stringify(header))}.${base64Url(JSON.stringify(claims))}`;

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(signingInput));
  const jwt = `${signingInput}.${base64Url(signature)}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }).toString(),
  });
  if (!res.ok) throw new Error(`Failed to get Google access token: ${res.status} ${await res.text()}`);
  const json = (await res.json()) as { access_token: string; expires_in: number };
  cachedToken = { token: json.access_token, expiresAt: Date.now() + json.expires_in * 1000 };
  return json.access_token;
}

function fromFirestoreValue(value: FirestoreValue | undefined): unknown {
  if (!value) return undefined;
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('nullValue' in value) return null;
  if ('mapValue' in value) {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value.mapValue.fields ?? {})) out[k] = fromFirestoreValue(v);
    return out;
  }
  if ('arrayValue' in value) return (value.arrayValue.values ?? []).map(fromFirestoreValue);
  return undefined;
}

export interface LoadedOrder {
  userId: string;
  displayId: string;
  customerEmail: string;
  payment: string;
  address: { fullName: string; phone: string; street: string; city: string };
  area: { id: string; name: string; fee: number; eta: string };
  items: Array<{ productId: string; price: number; quantity: number }>;
  coupon: { code: string } | null;
  history: Array<{ status: string; at: string; note?: string }>;
}

export async function getOrder(orderId: string, env: Env, token: string): Promise<LoadedOrder | null> {
  const res = await fetch(`${FIRESTORE_BASE}/${docPath(env, orderId)}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`Firestore getOrder failed: ${res.status} ${await res.text()}`);
  const json = (await res.json()) as { fields?: Record<string, FirestoreValue> };
  const fields = json.fields ?? {};
  const get = (name: string) => fromFirestoreValue(fields[name]);
  return {
    userId: (get('userId') as string) ?? '',
    displayId: (get('displayId') as string) ?? '',
    customerEmail: (get('customerEmail') as string) ?? '',
    payment: (get('payment') as string) ?? '',
    address: (get('address') as LoadedOrder['address']) ?? { fullName: '', phone: '', street: '', city: '' },
    area: (get('area') as LoadedOrder['area']) ?? { id: '', name: '', fee: 0, eta: '' },
    items: (get('items') as LoadedOrder['items']) ?? [],
    coupon: (get('coupon') as LoadedOrder['coupon']) ?? null,
    history: (get('history') as LoadedOrder['history']) ?? [],
  };
}

export class AmountError extends Error {
  constructor(
    public code: string,
    message: string,
  ) {
    super(message);
  }
}

export async function getDocFields(path: string, env: Env, token: string): Promise<Record<string, unknown> | null> {
  const res = await fetch(`${FIRESTORE_BASE}/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/${path}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`Firestore get ${path} failed: ${res.status} ${await res.text()}`);
  const json = (await res.json()) as { fields?: Record<string, FirestoreValue> };
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(json.fields ?? {})) out[k] = fromFirestoreValue(v);
  return out;
}

// True if [uid] has a *paid* order other than [exceptOrderId] — used to
// enforce first-order-only coupons.
async function hasOtherPaidOrder(uid: string, exceptOrderId: string, env: Env, token: string): Promise<boolean> {
  const res = await fetch(
    `${FIRESTORE_BASE}/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents:runQuery`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: 'orders' }],
          where: { fieldFilter: { field: { fieldPath: 'userId' }, op: 'EQUAL', value: { stringValue: uid } } },
          limit: 50,
        },
      }),
    },
  );
  if (!res.ok) throw new Error(`Firestore runQuery failed: ${res.status} ${await res.text()}`);
  const rows = (await res.json()) as Array<{ document?: { name: string; fields?: Record<string, FirestoreValue> } }>;
  return rows.some((r) => r.document && !r.document.name.endsWith(`/${exceptOrderId}`) && r.document.fields?.paidAt);
}

// The amount to charge, computed from the catalogue and coupon *documents*,
// never from prices/discounts the customer's app wrote onto the order (the
// client can write anything to its own order doc — see firestore.rules).
export async function computeAmount(orderId: string, order: LoadedOrder, env: Env, token: string): Promise<string> {
  let subtotal = 0;
  for (const item of order.items) {
    const product = await getDocFields(`products/${item.productId}`, env, token);
    if (!product || typeof product.price !== 'number') {
      throw new AmountError('invalid_order', 'An item in this order is no longer available');
    }
    subtotal += product.price * item.quantity;
  }

  let discount = 0;
  if (order.coupon?.code) {
    const coupon = await getDocFields(`coupons/${order.coupon.code}`, env, token);
    const expiresAt = coupon?.expiresAt ? Date.parse(coupon.expiresAt as string) : null;
    const bad = (why: string) => new AmountError('coupon_invalid', `Coupon ${order.coupon!.code} ${why}`);
    if (!coupon || coupon.active !== true) throw bad('is not valid');
    if (expiresAt !== null && expiresAt < Date.now()) throw bad('has expired');
    if (typeof coupon.minSubtotal === 'number' && subtotal < coupon.minSubtotal) throw bad('needs a bigger order');
    if (coupon.firstOrderOnly === true && (await hasOtherPaidOrder(order.userId, orderId, env, token))) {
      throw bad('is for first orders only');
    }
    if (typeof coupon.percentOff === 'number') discount = (subtotal * coupon.percentOff) / 100;
    else if (typeof coupon.amountOff === 'number') discount = coupon.amountOff;
    discount = Math.min(Math.max(discount, 0), subtotal);
  }
  return (subtotal - discount + (order.area.fee ?? 0)).toFixed(2);
}

// Sets a couple of plain fields (e.g. `paynowReference` right after
// initiating) without touching anything else on the doc.
export async function patchFields(orderId: string, env: Env, token: string, fields: Record<string, string>): Promise<void> {
  const mask = Object.keys(fields).map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`).join('&');
  const firestoreFields: Record<string, FirestoreValue> = {};
  for (const [k, v] of Object.entries(fields)) firestoreFields[k] = { stringValue: v };
  const res = await fetch(`${FIRESTORE_BASE}/${docPath(env, orderId)}?${mask}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: firestoreFields }),
  });
  if (!res.ok) throw new Error(`Firestore patch failed: ${res.status} ${await res.text()}`);
}

// The only path by which an order moves to `paid` outside the admin panel.
// Appends a `paid` StatusEvent (an array transform, since a plain PATCH
// can't append) and stamps `paynowReference`/`paidAt` in the same commit.
export async function appendPaidAndPatch(orderId: string, env: Env, token: string, paynowReference: string): Promise<void> {
  const nowIso = new Date().toISOString();
  const name = docPath(env, orderId);
  const body = {
    writes: [
      {
        transform: {
          document: name,
          fieldTransforms: [
            {
              fieldPath: 'history',
              appendMissingElements: {
                values: [{ mapValue: { fields: { status: { stringValue: 'paid' }, at: { timestampValue: nowIso } } } }],
              },
            },
          ],
        },
        currentDocument: { exists: true },
      },
      {
        update: {
          name,
          fields: {
            paynowReference: { stringValue: paynowReference },
            paidAt: { timestampValue: nowIso },
          },
        },
        updateMask: { fieldPaths: ['paynowReference', 'paidAt'] },
      },
    ],
  };
  const res = await fetch(`${FIRESTORE_BASE}/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents:commit`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`Firestore commit failed: ${res.status} ${await res.text()}`);
}

// ---------- Generic helpers (price-drop job, broadcasts) ----------

export interface LoadedDoc {
  // Path relative to the database root, e.g. `users/abc/wishlist/p174`.
  path: string;
  fields: Record<string, unknown>;
}

function documentsRoot(env: Env): string {
  return `projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents`;
}

function toLoadedDoc(env: Env, doc: { name: string; fields?: Record<string, FirestoreValue> }): LoadedDoc {
  const fields: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(doc.fields ?? {})) fields[k] = fromFirestoreValue(v);
  return { path: doc.name.slice(documentsRoot(env).length + 1), fields };
}

// Runs a structured query from the database root (so `allDescendants: true`
// in `from` makes it a collection-group query). Billed one read per doc
// returned, and one read for an empty result.
export async function queryDocs(structuredQuery: unknown, env: Env, token: string): Promise<LoadedDoc[]> {
  const res = await fetch(`${FIRESTORE_BASE}/${documentsRoot(env)}:runQuery`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ structuredQuery }),
  });
  if (!res.ok) throw new Error(`Firestore query failed: ${res.status} ${await res.text()}`);
  const rows = (await res.json()) as Array<{ document?: { name: string; fields?: Record<string, FirestoreValue> } }>;
  return rows.filter((r) => r.document).map((r) => toLoadedDoc(env, r.document!));
}

// Sets one timestamp field, creating the doc if needed.
export async function setTimestamp(path: string, field: string, at: Date, env: Env, token: string): Promise<void> {
  const res = await fetch(
    `${FIRESTORE_BASE}/${documentsRoot(env)}/${path}?updateMask.fieldPaths=${encodeURIComponent(field)}`,
    {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields: { [field]: { timestampValue: at.toISOString() } } }),
    },
  );
  if (!res.ok) throw new Error(`Firestore set ${path}.${field} failed: ${res.status} ${await res.text()}`);
}

// Sets numeric fields on an existing doc, leaving the rest alone.
export async function patchNumbers(path: string, env: Env, token: string, fields: Record<string, number>): Promise<void> {
  const mask = Object.keys(fields).map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`).join('&');
  const firestoreFields: Record<string, FirestoreValue> = {};
  for (const [k, v] of Object.entries(fields)) firestoreFields[k] = { doubleValue: v };
  const res = await fetch(`${FIRESTORE_BASE}/${documentsRoot(env)}/${path}?${mask}&currentDocument.exists=true`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: firestoreFields }),
  });
  if (!res.ok) throw new Error(`Firestore patch ${path} failed: ${res.status} ${await res.text()}`);
}

// Adds a doc with an auto id. Values: strings, plus `sentAt`-style
// timestamps passed as Date.
export async function createDoc(collection: string, env: Env, token: string, fields: Record<string, string | Date>): Promise<void> {
  const firestoreFields: Record<string, FirestoreValue> = {};
  for (const [k, v] of Object.entries(fields)) {
    firestoreFields[k] = v instanceof Date ? { timestampValue: v.toISOString() } : { stringValue: v };
  }
  const res = await fetch(`${FIRESTORE_BASE}/${documentsRoot(env)}/${collection}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: firestoreFields }),
  });
  if (!res.ok) throw new Error(`Firestore create in ${collection} failed: ${res.status} ${await res.text()}`);
}
