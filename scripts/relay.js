// scripts/relay.js
// ─────────────────────────────────────────────────────────────────────────────
// Football Fan Hub 2026 — Data Relay
//
// Runs on GitHub Actions (cron */5). Fetches from football-data.org for all
// 12 supported competitions and writes to Firestore.
//
// Key design decisions:
//   • SMART DIFF — only Firestore-writes matches whose status or score
//     changed since the last run.  On quiet days (no live matches) this
//     reduces writes from 3,644 → 0, staying well inside the Spark free tier.
//   • 30-second AbortController timeout on every HTTP call — a slow/hung API
//     response can no longer stall the whole relay.
//   • Chunked batch commits — each commit ≤ 450 ops (safely under the 500
//     hard cap), so competitions with 500+ matches (ELC) don't fail.
//   • Rate-limited at 6.5 s between football-data.org calls (≤ 10/min).
//   • Play-Store-safe competition names: no "FIFA" / "World Cup" strings.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');

const fetchFn = global.fetch
  ? global.fetch
  : (...args) => import('node-fetch').then(({ default: f }) => f(...args));

// ─── Config ───────────────────────────────────────────────────────────────────
const FD_BASE          = 'https://api.football-data.org/v4';
const APIFOOTBALL_BASE = 'https://v3.football.api-sports.io';

const COMPETITIONS = ['WC', 'CL', 'EC', 'PL', 'PD', 'BL1', 'SA', 'FL1', 'DED', 'PPL', 'ELC', 'BSA'];

const SAFE_NAMES = {
  WC:  'International Football 2026',
  CL:  'Champions League',
  EC:  'European Championship',
  PL:  'Premier League',
  PD:  'La Liga',
  BL1: 'Bundesliga',
  SA:  'Serie A',
  FL1: 'Ligue 1',
  DED: 'Eredivisie',
  PPL: 'Primeira Liga',
  ELC: 'Championship',
  BSA: 'Série A Brasil',
};

const RATE_LIMIT_MS   = 6500; // 10 calls/min max; 6.5 s gives headroom
const HTTP_TIMEOUT_MS = 30000; // abort any call that hangs > 30 s
const BATCH_LIMIT     = 450;   // safely under Firestore's 500-op hard cap

const PRE_KICKOFF_MS  = 15 * 60 * 1000;
const POST_KICKOFF_MS =  3 * 60 * 60 * 1000;
const RECENTLY_MS     =  4 * 60 * 60 * 1000; // Phase-5 newly-finished window

const LIVE_STATUSES = new Set(['IN_PLAY', 'PAUSED']);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ─── Firebase init ────────────────────────────────────────────────────────────
if (!process.env.FIREBASE_SA) { console.error('FATAL: FIREBASE_SA missing.'); process.exit(1); }
admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SA)) });
const db  = admin.firestore();
const NOW = admin.firestore.FieldValue.serverTimestamp;

// ─── HTTP helpers ─────────────────────────────────────────────────────────────
// AbortController ensures a single hung API call never stalls the whole relay.
async function fdGet(path) {
  const ctrl  = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), HTTP_TIMEOUT_MS);
  try {
    const res = await fetchFn(`${FD_BASE}${path}`, {
      headers: { 'X-Auth-Token': process.env.FD_TOKEN },
      signal: ctrl.signal,
    });
    clearTimeout(timer);
    if (res.status === 429) { console.warn(`Rate limited on ${path}`); return null; }
    if (!res.ok)            { console.warn(`FD ${res.status} on ${path}`); return null; }
    return res.json();
  } catch (err) {
    clearTimeout(timer);
    console.warn(err.name === 'AbortError'
      ? `Timeout (${HTTP_TIMEOUT_MS}ms) on ${path}`
      : `Error on ${path}: ${err.message}`);
    return null;
  }
}

async function apiFootballGet(path) {
  if (!process.env.APIFOOTBALL_KEY) return null;
  const ctrl  = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), HTTP_TIMEOUT_MS);
  try {
    const res = await fetchFn(`${APIFOOTBALL_BASE}${path}`, {
      headers: { 'x-apisports-key': process.env.APIFOOTBALL_KEY },
      signal: ctrl.signal,
    });
    clearTimeout(timer);
    if (!res.ok) { console.warn(`API-Football ${res.status} on ${path}`); return null; }
    return res.json();
  } catch (err) {
    clearTimeout(timer);
    console.warn(`API-Football error on ${path}: ${err.message}`);
    return null;
  }
}

// ─── Normalizers ──────────────────────────────────────────────────────────────
function normalizeGoals(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.map((g) => ({
    minute: g.minute ?? 0,
    type:   g.type   ?? 'REGULAR',
    scorer: { name: g.scorer?.name ?? null },
    assist: { name: g.assist?.name  ?? null },
    team:   { id: g.team?.id ?? null, tla: g.team?.tla ?? null },
  }));
}
function normalizeBookings(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.map((b) => ({ minute: b.minute ?? 0, player: b.player?.name ?? null, team: b.team?.tla ?? b.team?.name ?? null, card: b.card ?? 'YELLOW' }));
}
function normalizeSubs(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.map((s) => ({ minute: s.minute ?? 0, playerIn: s.playerIn?.name ?? null, playerOut: s.playerOut?.name ?? null, team: s.team?.tla ?? s.team?.name ?? null }));
}

// ─── Chunked Firestore commit ─────────────────────────────────────────────────
async function commitBatches(ops) {
  for (let i = 0; i < ops.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    for (const op of ops.slice(i, i + BATCH_LIMIT)) {
      batch.set(op.ref, op.data, { merge: true });
    }
    await batch.commit();
  }
}

// ─── Phase 1: matches for one competition (smart diff) ────────────────────────
// Returns the raw match array, list of live IDs, and new match-state snapshot.
async function fetchAndStoreMatchesForComp(comp, prevStates) {
  const data = await fdGet(`/competitions/${comp}/matches`);
  if (!data || !Array.isArray(data.matches)) return { matches: [], liveIds: [], states: {} };

  const compName = SAFE_NAMES[comp] ?? comp;
  const liveIds  = [];
  const toWrite  = [];
  const states   = {};

  for (const m of data.matches) {
    const h = m.score?.fullTime?.home ?? null;
    const a = m.score?.fullTime?.away ?? null;
    states[m.id] = { s: m.status, h, a };

    // Only queue a Firestore write if something actually changed.
    const prev    = prevStates[m.id];
    const changed = !prev || prev.s !== m.status || prev.h !== h || prev.a !== a;
    if (changed) toWrite.push(m);
    if (LIVE_STATUSES.has(m.status)) liveIds.push(m.id);
  }

  if (toWrite.length > 0) {
    const ops = toWrite.map((m) => ({
      ref:  db.collection('matches').doc(String(m.id)),
      data: {
        id: m.id, status: m.status, utcDate: m.utcDate,
        homeTeam: m.homeTeam ?? {}, awayTeam: m.awayTeam ?? {},
        score: m.score ?? {}, stage: m.stage ?? 'GROUP_STAGE',
        group: m.group ?? null,
        competition: { name: compName, code: comp },
        updatedAt: NOW(),
      },
    }));
    await commitBatches(ops);
  }

  console.log(`  [${comp}] ${data.matches.length} fetched, ${toWrite.length} written`);
  return { matches: data.matches, liveIds, states };
}

// ─── Phase 2: standings for one competition ───────────────────────────────────
async function fetchAndStoreStandingsForComp(comp) {
  const data = await fdGet(`/competitions/${comp}/standings`);
  if (!data) return;

  const standings = Array.isArray(data.standings)
    ? data.standings
    : data.standings ? [data.standings] : [];
  if (!standings.length) { console.log(`  [${comp}] no standings returned`); return; }

  const ops = standings.map((s) => {
    const groupKey = s.group ?? s.stage ?? 'TOTAL';
    return {
      ref:  db.collection('standings').doc(`${comp}_${groupKey}`),
      data: { group: groupKey, competitionCode: comp, table: s.table ?? [], updatedAt: NOW() },
    };
  });
  await commitBatches(ops);
  console.log(`  [${comp}] ${standings.length} standing group(s) written`);
}

// ─── Phase 3: per-match detail (goals, cards, subs) ──────────────────────────
async function fetchMatchDetail(matchId) {
  const m = await fdGet(`/matches/${matchId}`);
  if (!m) return;
  await db.collection('matches').doc(String(matchId)).set({
    goals: normalizeGoals(m.goals), bookings: normalizeBookings(m.bookings),
    substitutions: normalizeSubs(m.substitutions), score: m.score ?? {},
    status: m.status, detailUpdatedAt: NOW(),
  }, { merge: true });
}

// ─── Phase 4: post-match lineup (API-Football, best-effort) ──────────────────
async function fetchAndStoreLineup(matchId) {
  const data    = await apiFootballGet(`/fixtures?id=${matchId}`);
  const fixture = data?.response?.[0];
  if (!fixture) return;

  await db.collection('lineups').doc(String(matchId)).set(
    { home: fixture.lineups?.[0] ?? null, away: fixture.lineups?.[1] ?? null, events: fixture.events ?? [], fetchedAt: NOW() }
  );
  if (fixture.lineups?.length) {
    await db.collection('matches').doc(String(matchId)).set(
      { confirmedLineup: { home: fixture.lineups[0] ?? null, away: fixture.lineups[1] ?? null }, confirmedLineupAt: NOW() },
      { merge: true }
    );
  }
  console.log(`  Lineup stored for match ${matchId}`);
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  const now     = new Date();
  const metaRef = db.collection('meta').doc('relay');
  console.log(`▶ Relay start ${now.toISOString()}`);

  // Read previous match states in one cheap doc read.
  const prevMeta        = (await metaRef.get()).data() ?? {};
  const prevMatchStates = prevMeta.matchStates ?? {};

  // ── Phase 1: fetch + smart-diff write for all competitions ─────────────────
  console.log('Phase 1: fetching matches…');
  const allMatches    = [];
  const allLiveIds    = [];
  const allNewStates  = {};

  for (const comp of COMPETITIONS) {
    const { matches, liveIds, states } = await fetchAndStoreMatchesForComp(comp, prevMatchStates);
    allMatches.push(...matches);
    allLiveIds.push(...liveIds);
    Object.assign(allNewStates, states);
    await sleep(RATE_LIMIT_MS);
  }
  console.log(`  Total: ${allMatches.length} fetched, ${allLiveIds.length} live`);

  // ── Phase 2: window detection ──────────────────────────────────────────────
  const t = now.getTime();
  const windowOpen = allLiveIds.length > 0 || allMatches.some((m) => {
    const ko = new Date(m.utcDate).getTime();
    return t >= ko - PRE_KICKOFF_MS && t <= ko + POST_KICKOFF_MS;
  });

  // ── Phase 3: standings (in window or top of hour) ──────────────────────────
  if (windowOpen || now.getUTCMinutes() < 5) {
    console.log('Phase 3: fetching standings…');
    for (const comp of COMPETITIONS) {
      await fetchAndStoreStandingsForComp(comp);
      await sleep(RATE_LIMIT_MS);
    }
  }

  // ── Phase 4: per-match detail for live matches ─────────────────────────────
  if (allLiveIds.length) {
    console.log(`Phase 4: detail for ${allLiveIds.length} live match(es)…`);
    for (const id of allLiveIds) {
      await fetchMatchDetail(id);
      await sleep(RATE_LIMIT_MS);
    }
  }

  // ── Phase 5: newly finished (max 4-hour window guards against first-run flood)
  const newlyFinished = allMatches.filter((m) => {
    if (m.status !== 'FINISHED') return false;
    if (prevMatchStates[m.id]?.s === 'FINISHED') return false;
    const ko = new Date(m.utcDate).getTime();
    return t - ko <= RECENTLY_MS;
  });

  if (newlyFinished.length) {
    console.log(`Phase 5: ${newlyFinished.length} newly finished match(es)…`);
    for (const m of newlyFinished) {
      await fetchMatchDetail(m.id);
      await fetchAndStoreLineup(m.id);
      await sleep(RATE_LIMIT_MS);
    }
  }

  // ── Phase 6: write meta (app reads this first — 1 cheap doc) ──────────────
  await metaRef.set({
    lastRun:      NOW(),
    lastRunIso:   now.toISOString(),
    liveMatchIds: allLiveIds,
    windowOpen,
    matchStates:  allNewStates, // drives smart diff on next run
    competitions: COMPETITIONS,
  }, { merge: true });

  console.log(`✓ Done. live=${allLiveIds.length} newlyFinished=${newlyFinished.length} window=${windowOpen}`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => { console.error('Relay failed:', err); process.exit(1); });
