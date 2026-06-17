// scripts/news_worker.js
// ─────────────────────────────────────────────────────────────────────────────
// Football Fan Hub 2026 — News Worker
//
// Free, no key, no signup. Pulls football headlines from public RSS feeds
// and writes them to Firestore as one doc per article. The app reads the
// "news" collection ordered by publishedAt desc.
//
// Sources (all free):
//   • BBC Sport — http://feeds.bbci.co.uk/sport/football/rss.xml
//   • Guardian Football — https://www.theguardian.com/football/rss
//
// Add more sources by appending to FEEDS. Each article gets a stable hash id
// derived from its URL so re-runs upsert cleanly instead of duplicating.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const crypto = require('crypto');

const fetchFn = global.fetch
  ? global.fetch
  : (...a) => import('node-fetch').then(({ default: f }) => f(...a));

const FEEDS = [
  { source: 'BBC Sport',         url: 'https://feeds.bbci.co.uk/sport/football/rss.xml' },
  { source: 'Guardian Football', url: 'https://www.theguardian.com/football/rss' },
];

// Delete articles older than this many days. RSS feeds never contain content
// older than a few days, so this naturally caps collection size without the
// expensive offset() scan that charges reads for every doc before the offset.
const PRUNE_AFTER_DAYS = 7;

if (!process.env.FIREBASE_SA) {
  console.error('FATAL: FIREBASE_SA missing.');
  process.exit(1);
}
admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SA)),
});
const db = admin.firestore();
const NOW = admin.firestore.FieldValue.serverTimestamp;

// ─── Tiny RSS parser ─────────────────────────────────────────────────────────
// RSS 2.0 has very stable structure: <item> blocks with title/link/description/
// pubDate children. A regex extractor is more than enough and saves a npm dep.
// CDATA, named entities and stray whitespace are all handled.
function stripTags(s) {
  return (s || '')
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/<[^>]+>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .trim();
}

function extractTag(block, tag) {
  const m = block.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`, 'i'));
  return m ? stripTags(m[1]) : null;
}

function extractImage(block) {
  // Common variants across feeds: <media:thumbnail url="…">, <enclosure url="…" type="image/…">
  const mt = block.match(/<media:(?:thumbnail|content)[^>]*url="([^"]+)"/i);
  if (mt) return mt[1];
  const en = block.match(/<enclosure[^>]*url="([^"]+)"[^>]*type="image\//i);
  if (en) return en[1];
  return null;
}

function parseRss(xml) {
  const items = [];
  const itemRe = /<item[\s>][\s\S]*?<\/item>/gi;
  for (const m of xml.matchAll(itemRe)) {
    const block = m[0];
    const title = extractTag(block, 'title');
    const link = extractTag(block, 'link');
    const description = extractTag(block, 'description');
    const pubDate = extractTag(block, 'pubDate');
    if (!title || !link) continue;
    items.push({
      title,
      link,
      description,
      pubDate,
      imageUrl: extractImage(block),
    });
  }
  return items;
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  const startedAt = new Date();
  console.log(`▶ News worker start ${startedAt.toISOString()}`);

  const all = [];
  for (const feed of FEEDS) {
    try {
      const res = await fetchFn(feed.url, {
        headers: { 'User-Agent': 'FootballFanHub2026/1.0 (+relay)' },
      });
      if (!res.ok) {
        console.warn(`✗ ${feed.source}: HTTP ${res.status}`);
        continue;
      }
      const xml = await res.text();
      const items = parseRss(xml);
      for (const it of items) all.push({ ...it, source: feed.source });
      console.log(`✓ ${feed.source}: ${items.length} items.`);
    } catch (err) {
      console.warn(`✗ ${feed.source}: ${err.message}`);
    }
  }

  if (!all.length) {
    console.warn('No articles fetched from any feed. Exiting.');
    return;
  }

  // Deduplicate by URL hash; freshest pubDate wins on conflict.
  const byHash = new Map();
  for (const a of all) {
    const id = crypto.createHash('sha1').update(a.link).digest('hex').slice(0, 20);
    const existing = byHash.get(id);
    const t = a.pubDate ? new Date(a.pubDate).getTime() : 0;
    const tExisting = existing?.publishedAtMs ?? 0;
    if (!existing || t > tExisting) {
      byHash.set(id, { ...a, id, publishedAtMs: t });
    }
  }

  // Upsert.
  const writes = [...byHash.values()];
  for (let i = 0; i < writes.length; i += 450) {
    const chunk = writes.slice(i, i + 450);
    const batch = db.batch();
    for (const a of chunk) {
      const ref = db.collection('news').doc(a.id);
      batch.set(
        ref,
        {
          id: a.id,
          title: a.title,
          link: a.link,
          description: a.description ?? '',
          imageUrl: a.imageUrl ?? null,
          source: a.source,
          publishedAt: a.pubDate ? new Date(a.pubDate) : null,
          publishedAtMs: a.publishedAtMs,
          fetchedAt: NOW(),
        },
        { merge: true }
      );
    }
    await batch.commit();
  }
  console.log(`✓ Upserted ${writes.length} articles.`);

  // Prune articles older than PRUNE_AFTER_DAYS using a where() filter.
  // This only reads docs that actually qualify for deletion (typically zero,
  // since RSS feeds never carry content older than a few days). The previous
  // offset()-based approach charged for every doc before the offset position,
  // burning thousands of free-tier reads per day.
  const cutoffMs = Date.now() - PRUNE_AFTER_DAYS * 24 * 60 * 60 * 1000;
  const oldSnap = await db
    .collection('news')
    .where('publishedAtMs', '<', cutoffMs)
    .get();
  if (!oldSnap.empty) {
    for (let i = 0; i < oldSnap.docs.length; i += 450) {
      const batch = db.batch();
      for (const d of oldSnap.docs.slice(i, i + 450)) batch.delete(d.ref);
      await batch.commit();
    }
    console.log(`✓ Pruned ${oldSnap.size} article(s) older than ${PRUNE_AFTER_DAYS} days.`);
  }

  await db.collection('meta').doc('news').set(
    {
      lastRun: NOW(),
      lastRunIso: startedAt.toISOString(),
      articlesWritten: writes.length,
    },
    { merge: true }
  );

  console.log('✓ News worker done.');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    if (err.code === 8) {
      // Firestore RESOURCE_EXHAUSTED — daily quota used up. Exit cleanly so
      // the GitHub Actions run stays green; news will refresh on the next run.
      console.warn('⚠ Firestore quota exceeded — skipping this news run.');
      process.exit(0);
    }
    console.error('News worker failed:', err);
    process.exit(1);
  });