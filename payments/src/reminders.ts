import type { Env } from './types';
import { queryDocs, setTimestamp } from './firestore';
import { sendToUser } from './fcm';

// "Complete your payment" nudge for orders left unpaid. Runs on the same
// cron trigger as the price-drop job (every 6 hours, see wrangler.toml).
//
// Looks only at orders created 24–48 hours ago (one range query on
// `createdAt`, single-field index Firestore creates automatically), so each
// order is seen by ~4 runs and the cost is ~4 reads per order per day.
// `reminderSentAt` makes sure a customer is nudged at most once per order.

const HOUR = 60 * 60 * 1000;

export async function runPaymentReminders(env: Env, accessToken: string): Promise<number> {
  const now = Date.now();
  const orders = await queryDocs(
    {
      from: [{ collectionId: 'orders' }],
      where: {
        compositeFilter: {
          op: 'AND',
          filters: [
            {
              fieldFilter: {
                field: { fieldPath: 'createdAt' },
                op: 'LESS_THAN_OR_EQUAL',
                value: { timestampValue: new Date(now - 24 * HOUR).toISOString() },
              },
            },
            {
              fieldFilter: {
                field: { fieldPath: 'createdAt' },
                op: 'GREATER_THAN',
                value: { timestampValue: new Date(now - 48 * HOUR).toISOString() },
              },
            },
          ],
        },
      },
    },
    env,
    accessToken,
  );

  let reminded = 0;
  for (const order of orders) {
    const history = (order.fields.history as Array<{ status?: string }> | undefined) ?? [];
    const awaitingPayment = history.at(-1)?.status === 'placed';
    // A manual payment reference is waiting for the admin to check it — the
    // customer has already paid, so don't nudge them to pay again.
    const manualStatus = (order.fields.manualPayment as { status?: string } | undefined)?.status;
    if (!awaitingPayment || order.fields.reminderSentAt || manualStatus === 'submitted') continue;
    const uid = order.fields.userId as string | undefined;
    const displayId = String(order.fields.displayId ?? '');
    if (!uid || !displayId) continue;
    try {
      await sendToUser(
        uid,
        {
          title: 'Your order is waiting for payment',
          body: `Order ${displayId} isn't paid yet. Tap to complete payment and we'll get it moving.`,
          data: { route: `/orders/${displayId}` },
          channel: 'order_updates',
          kind: 'reminder',
        },
        env,
        accessToken,
      );
      await setTimestamp(order.path, 'reminderSentAt', new Date(), env, accessToken);
      reminded++;
    } catch (err) {
      console.error(`reminders: ${order.path} failed`, err);
    }
  }
  console.log(`reminders: ${orders.length} order(s) in window, ${reminded} reminded`);
  return reminded;
}
