import type { Env } from './types';
import { deleteDocs, queryDocs } from './firestore';

// Weekly tidy-up of things that only ever grow (wrangler.toml's weekly cron).
// Photo orphans are handled next door in images.ts.

const DAY = 24 * 60 * 60 * 1000;

// Inbox items (users/{uid}/notifications) and promo copies older than this
// are deleted. The app only ever shows the newest 50 / 10 anyway.
const KEEP_DAYS = 90;

// Cap per run so one run never does an unbounded amount of work; anything
// left over goes next week.
const MAX_DELETES = 2000;

export async function pruneOldNotifications(env: Env, token: string): Promise<{ inbox: number; promos: number }> {
  const cutoff = new Date(Date.now() - KEEP_DAYS * DAY).toISOString();
  const olderThan = (field: string) => ({
    fieldFilter: { field: { fieldPath: field }, op: 'LESS_THAN', value: { timestampValue: cutoff } },
  });

  // Collection group across every customer — needs the createdAt field
  // override in firestore.indexes.json.
  const inbox = await queryDocs(
    { from: [{ collectionId: 'notifications', allDescendants: true }], where: olderThan('createdAt'), limit: MAX_DELETES },
    env,
    token,
  );
  const promos = await queryDocs(
    { from: [{ collectionId: 'promos' }], where: olderThan('sentAt'), limit: MAX_DELETES },
    env,
    token,
  );
  await deleteDocs([...inbox, ...promos].map((d) => d.path), env, token);
  console.log(`housekeeping: pruned ${inbox.length} inbox item(s), ${promos.length} promo(s) older than ${KEEP_DAYS} days`);
  return { inbox: inbox.length, promos: promos.length };
}
