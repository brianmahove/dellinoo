import type { Env } from './types';
import { createDoc } from './firestore';

// Sends push notifications through Firebase Cloud Messaging's HTTP v1 API.
// FCM itself is free on the Spark plan — what Spark lacks is Cloud
// Functions to *trigger* a send, so this Worker sends them instead: from
// the Paynow webhook (payment received) and from /notify/order-status (the
// admin panel calls it after changing an order's status).
//
// Device tokens live at `users/{uid}/fcmTokens/{token}`, written by the
// customer app (lib/core/push.dart). The doc id *is* the token.

const FIRESTORE_BASE = 'https://firestore.googleapis.com/v1';

export interface PushMessage {
  title: string;
  body: string;
  // Delivered to the app as RemoteMessage.data — `route` is the go_router
  // location to open when the notification is tapped.
  data?: Record<string, string>;
  // Android channel, created in MainActivity.kt. Separate channels let a
  // customer mute promos in Android settings without losing order updates.
  channel?: 'order_updates' | 'price_drops' | 'deals';
  // Picks the icon in the app's notification inbox
  // (lib/features/notifications/notifications_screen.dart).
  kind: 'order' | 'payment' | 'reminder' | 'price_drop' | 'quote' | 'invoice' | 'promo';
}

export const PROMOS_TOPIC = 'promos';

function fcmBody(target: { token: string } | { topic: string }, message: PushMessage): string {
  return JSON.stringify({
    message: {
      ...target,
      notification: { title: message.title, body: message.body },
      data: message.data ?? {},
      android: {
        priority: message.channel === 'deals' ? 'normal' : 'high',
        // The icon/colour defaults come from AndroidManifest.xml.
        notification: { channel_id: message.channel ?? 'order_updates' },
      },
    },
  });
}

function fcmUrl(env: Env): string {
  return `https://fcm.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/messages:send`;
}

// Topic pushes have no per-user inbox record (that would be a write per
// customer); the broadcast handler stores one public `promos` doc instead,
// which the app's inbox merges in.
// Sends [message] to every app install subscribed to [topic] (see
// lib/core/push.dart — every install subscribes to `promos` unless the
// customer turned "Deals & offers" off).
export async function sendToTopic(topic: string, message: PushMessage, env: Env, accessToken: string): Promise<void> {
  const res = await fetch(fcmUrl(env), {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: fcmBody({ topic }, message),
  });
  if (!res.ok) throw new Error(`FCM topic send failed: ${res.status} ${await res.text()}`);
}

function tokensPath(env: Env, uid: string): string {
  return `projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/users/${uid}/fcmTokens`;
}

async function listTokens(uid: string, env: Env, accessToken: string): Promise<string[]> {
  const res = await fetch(`${FIRESTORE_BASE}/${tokensPath(env, uid)}?pageSize=50&mask.fieldPaths=updatedAt`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) throw new Error(`Firestore list fcmTokens failed: ${res.status} ${await res.text()}`);
  const json = (await res.json()) as { documents?: Array<{ name: string }> };
  return (json.documents ?? []).map((d) => decodeURIComponent(d.name.split('/').pop()!));
}

async function deleteToken(uid: string, token: string, env: Env, accessToken: string): Promise<void> {
  await fetch(`${FIRESTORE_BASE}/${tokensPath(env, uid)}/${encodeURIComponent(token)}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${accessToken}` },
  });
}

// Sends [message] to every device [uid] is signed in on, and records it in
// their in-app inbox (`users/{uid}/notifications`) first — so it's there
// even if no device got the push (notifications off, phone offline).
// Never throws for a single bad token: tokens FCM reports as gone (app
// uninstalled, data cleared) are deleted so they stop costing a request on
// every send. Returns how many devices accepted it.
export async function sendToUser(uid: string, message: PushMessage, env: Env, accessToken: string): Promise<number> {
  await createDoc(`users/${uid}/notifications`, env, accessToken, {
    title: message.title,
    body: message.body,
    route: message.data?.route ?? '',
    kind: message.kind,
    read: false,
    createdAt: new Date(),
  });
  const tokens = await listTokens(uid, env, accessToken);
  let sent = 0;
  for (const token of tokens) {
    const res = await fetch(fcmUrl(env), {
      method: 'POST',
      headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
      body: fcmBody({ token }, message),
    });
    if (res.ok) {
      sent++;
      continue;
    }
    const text = await res.text();
    // UNREGISTERED (404) = token no longer valid; INVALID_ARGUMENT (400) on
    // a token we stored ourselves means the same in practice.
    if (res.status === 404 || (res.status === 400 && text.includes('INVALID_ARGUMENT'))) {
      console.log(`fcm: dropping dead token for uid=${uid}`);
      await deleteToken(uid, token, env, accessToken);
    } else {
      console.error(`fcm: send failed for uid=${uid}: ${res.status} ${text}`);
    }
  }
  return sent;
}

// What the customer sees for each order status. `null` = no push (the
// customer just did it themselves). Statuses mirror OrderStatus in the app's
// lib/data/models.dart and _statuses in admin/lib/orders_screen.dart.
export function orderStatusMessage(status: string, displayId: string, note?: string): PushMessage | null {
  const copy: Record<string, [string, string] | null> = {
    placed: null,
    paid: ['Payment received', `Thanks! We've got your payment for order ${displayId}.`],
    processing: ['Order being prepared', `We're getting order ${displayId} ready.`],
    boughtInChina: ['Bought in China', `Your items for order ${displayId} have been bought and are getting ready to fly.`],
    inTransit: ['Flying to Zimbabwe', `Order ${displayId} is on its way from China.`],
    arrivedZim: ['Arrived in Harare', `Order ${displayId} has landed in Zimbabwe.`],
    outForDelivery: ['Out for delivery', `Order ${displayId} is on its way to you.`],
    delivered: ['Delivered', `Order ${displayId} has been delivered. Enjoy!`],
  };
  const entry = copy[status];
  if (!entry) return null;
  const [title, body] = entry;
  return {
    title,
    body: note ? `${body} ${note}` : body,
    data: { route: `/orders/${displayId}` },
    kind: status === 'paid' ? 'payment' : 'order',
  };
}

// Sent when the admin rejects a customer's manual payment reference.
export function manualPaymentRejectedMessage(displayId: string, reference: string, note?: string): PushMessage {
  return {
    title: "We couldn't confirm your payment",
    body: `Reference ${reference} for order ${displayId} didn't match our records.${note ? ` ${note}` : ''} Tap to check it and send it again.`,
    data: { route: `/orders/${displayId}` },
    kind: 'payment',
  };
}
