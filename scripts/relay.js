// scripts/relay.js
// ─────────────────────────────────────────────────────────────────────────────
// Football Fan Hub 2026 — Data Relay
//
// Runs on GitHub Actions (cron */5). Pulls from football-data.org (live scores,
// events, standings) for ALL 12 supported competitions, normalizes everything
// into the schema the Flutter app expects, and writes to Firestore.
//
// The Flutter app NEVER calls these external APIs. It only reads Firestore.
// External API keys live ONLY in GitHub Secrets — never in the APK.
//
// Design rules:
//   • All 12 competitions fetched in one run; rate-limited at 6.5 s/call.
//   • Goals written in the EXACT shape MatchGoal.fromJson() expects.
//   • Standings stored as {competitionCode}_{groupKey} so the app can filter
//     by competition (e.g. watchStandings('PL') → only PL table).
//   • meta/relay holds liveMatchIds + lastRun for 1 cheap app read first.
//   • Play-Store-safe competition names: no "FIFA" / "World Cup" strings.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');

const fetchFn = global.fetch
  ? global.fetch
  : (...args) => import('node-fetch').then(({ default: f }) => f(...args));

// ─── Config ──────────────────────────────────────────────────────────────────
const FD_BASE = 'https://api.football-data.org/v4';
const APIFOOTBALL_BASE = 'https://v3.football.api-sports.io';

// All competitions the app supports. Matches are fetched for every one.
const COMPETITIONS = ['WC', 'CL', 'EC', 'PL', 'PD', 'BL1', 'SA', 'FL1', 'DED', 'PPL', 'ELC', 'BSA'];

// Play-Store safe display names — never use "FIFA" or "World Cup".
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

// football-data.org free tier: 10 calls/min → wait ≥ 6 s between calls.
const RATE_LIMIT_MS = 6500;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Match window: 15 min before kickoff to 3h after.
const PRE_KICKOFF_MS  = 15 * 60 * 1000;
const POST_KICKOFF_MS =  3 * 60 * 60 * 1000;

const LIVE_STATUSES = new Set(['IN_PLAY', 'PAUSED']);

// ─── Init Firebase Admin ───────────────────────────────────────────────────────
if (!process.env.FIREBASE_SA) {
  console.error('FATAL: FIREBASE_SA secret is missing.');
  process.exit(1);
}
admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SA)),
});
const db  = admin.firestore();
const NOW = admin.firestore.FieldValue.serverTimestamp;

// ─── HTTP helpers ────────────────────────────────────────────────────────────
async function fdGet(path) {
  const res = await fetchFn(`${FD_BASE}${path}`, {
    headers: { 'X-Auth-Token': process.env.FD_TOKEN },
  });
  if (res.status === 429) {
    console.warn(`football-data.org rate limited on ${path} — skipping.`);
    return null;
  }
  if (!res.ok) {
    console.warn(`football-data.org ${res.status} on ${path}`);
    return null;
  }
  return res.json();
}

async function apiFootballGet(path) {
  if (!process.env.APIFOOTBALL_KEY) return null;
  const res = await fetchFn(`${APIFOOTBALL_BASE}${path}`, {
    headers: { 'x-apisports-key': process.env.APIFOOTBALL_KEY },
  });
  if (!res.ok) {
    console.warn(`API-Football ${res.status} on ${path}`);
    return null;
  }
  return res.json();
}

// ─── Normalizers ──────────────────────────────────────────────────────────────
function normalizeGoals(rawGoals) {
  if (!Array.isArray(rawGoals)) return [];
  return rawGoals.map((g) => ({
    minute: g.minute ?? 0,
    type:   g.type   ?? 'REGULAR',
    scorer: { name: g.scorer?.name ?? null },
    assist: { name: g.assist?.name  ?? null },
    team:   { id: g.team?.id ?? null, tla: g.team?.tla ?? null },
  }));
}

function normalizeBookings(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.map((b) => ({
    minute: b.minute ?? 0,
    player: b.player?.name ?? null,
    team:   b.team?.tla ?? b.team?.name ?? null,
    card:   b.card ?? 'YELLOW',
  }));
}

function normalizeSubs(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.map((s) => ({
    minute:    s.minute ?? 0,
    playerIn:  s.playerIn?.name  ?? null,
    playerOut: s.playerOut?.name ?? null,
    team:      s.team?.tla ?? s.team?.name ?? null,
  }));
}

// ─── Step 1: matches for ONE competition ──────────────────────────────────────
async function fetchAndStoreMatchesForComp(comp) {
  const data = await fdGet(`/competitions/${comp}/matches`);
  if (!data || !Array.isArray(data.matches)) return [];

  const compName = SAFE_NAMES[comp] ?? comp;
  const batch    = db.batch();
  const liveIds  = [];

  for (const m of data.matches) {
    const ref = db.collection('matches').doc(String(m.id));
    batch.set(
      ref,
      {
        id:          m.id,
        status:      m.status,
        utcDate:     m.utcDate,
        homeTeam:    m.homeTeam ?? {},
        awayTeam:    m.awayTeam ?? {},
        score:       m.score    ?? {},
        stage:       m.stage    ?? 'GROUP_STAGE',
        group:       m.group    ?? null,
        competition: { name: compName, code: comp },
        updatedAt:   NOW(),
      },
      { merge: true }
    );
    if (LIVE_STATUSES.has(m.status)) liveIds.push(m.id);
  }

  await batch.commit();
  console.log(`  [${comp}] ${data.matches.length} matches stored (${liveIds.length} live)`);
  return data.matches;
}

// ─── Step 2: standings for ONE competition ────────────────────────────────────
// Docs are keyed as "{comp}_{groupKey}" so the Flutter app can query by
// competitionCode without mixing groups from different leagues.
async function fetchAndStoreStandingsForComp(comp) {
  const data = await fdGet(`/competitions/${comp}/standings`);
  if (!data) return;

  const standings = Array.isArray(data.standings)
    ? data.standings
    : data.standings
    ? [data.standings]
    : [];

  if (!standings.length) {
    console.log(`  [${comp}] No standings returned.`);
    return;
  }

  const batch = db.batch();
  for (const s of standings) {
    const groupKey = s.group ?? s.stage ?? 'TOTAL';
    const docKey   = `${comp}_${groupKey}`;
    const ref      = db.collection('standings').doc(docKey);
    batch.set(
      ref,
      {
        group:           groupKey,
        competitionCode: comp,
        table:           s.table ?? [],
        updatedAt:       NOW(),
      },
      { merge: true }
    );
  }
  await batch.commit();
  console.log(`  [${comp}] ${standings.length} standing group(s) stored`);
}

// ─── Step 3: per-match detail (goals, cards, subs) ───────────────────────────
async function fetchMatchDetail(matchId) {
  const m = await fdGet(`/matches/${matchId}`);
  if (!m) return;

  await db.collection('matches').doc(String(matchId)).set(
    {
      goals:         normalizeGoals(m.goals),
      bookings:      normalizeBookings(m.bookings),
      substitutions: normalizeSubs(m.substitutions),
      score:         m.score  ?? {},
      status:        m.status,
      detailUpdatedAt: NOW(),
    },
    { merge: true }
  );
}

// ─── Step 4: post-match lineup via API-Football ───────────────────────────────
// NOTE: API-Football uses its own fixture IDs — different from football-data.org.
// The /fixtures?id=X call only works if the fd→apifootball ID happens to match.
// Bzzoiro covers lineups for the live window; this is a supplemental fallback.
async function fetchAndStoreLineup(matchId) {
  const data    = await apiFootballGet(`/fixtures?id=${matchId}`);
  const fixture = data?.response?.[0];
  if (!fixture) return;

  await db.collection('lineups').doc(String(matchId)).set({
    home:      fixture.lineups?.[0] ?? null,
    away:      fixture.lineups?.[1] ?? null,
    events:    fixture.events ?? [],
    fetchedAt: NOW(),
  });

  // Also merge into the matches/ doc so the app can read it via getMatchRaw().
  if (fixture.lineups?.length) {
    await db.collection('matches').doc(String(matchId)).set(
      {
        confirmedLineup: {
          home: fixture.lineups[0] ?? null,
          away: fixture.lineups[1] ?? null,
        },
        confirmedLineupAt: NOW(),
      },
      { merge: true }
    );
  }

  console.log(`  Lineup stored for match ${matchId}`);
}

// ─── Match-window detection ───────────────────────────────────────────────────
function classifyMatches(matches, now) {
  const live = [];
  let windowOpen = false;
  const t = now.getTime();

  for (const m of matches) {
    if (LIVE_STATUSES.has(m.status)) {
      live.push(m.id);
      windowOpen = true;
      continue;
    }
    const ko = new Date(m.utcDate).getTime();
    if (t >= ko - PRE_KICKOFF_MS && t <= ko + POST_KICKOFF_MS) {
      windowOpen = true;
    }
  }
  return { live, windowOpen };
}

async function detectNewlyFinished(matches) {
  const metaRef      = db.collection('meta').doc('relay');
  const prev         = (await metaRef.get()).data() ?? {};
  const prevStatuses = prev.statuses ?? {};

  const newlyFinished = [];
  const statuses      = {};
  for (const m of matches) {
    statuses[m.id] = m.status;
    if (m.status === 'FINISHED' && prevStatuses[String(m.id)] !== 'FINISHED') {
      newlyFinished.push(m.id);
    }
  }
  return { newlyFinished, statuses };
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  const now = new Date();
  console.log(`▶ Relay start ${now.toISOString()}`);

  // Phase 1 — Fetch matches for all competitions (rate-limited).
  console.log('Phase 1: fetching matches…');
  const allMatches = [];
  for (const comp of COMPETITIONS) {
    const matches = await fetchAndStoreMatchesForComp(comp);
    allMatches.push(...matches);
    await sleep(RATE_LIMIT_MS);
  }
  console.log(`  Total: ${allMatches.length} matches across ${COMPETITIONS.length} competitions`);

  // Phase 2 — Classify.
  const { live, windowOpen } = classifyMatches(allMatches, now);

  // Phase 3 — Standings: in window OR top of hour.
  if (windowOpen || now.getUTCMinutes() < 5) {
    console.log('Phase 3: fetching standings…');
    for (const comp of COMPETITIONS) {
      await fetchAndStoreStandingsForComp(comp);
      await sleep(RATE_LIMIT_MS);
    }
  }

  // Phase 4 — Per-match detail for every live match.
  if (live.length) {
    console.log(`Phase 4: fetching detail for ${live.length} live match(es)…`);
    for (const id of live) {
      await fetchMatchDetail(id);
      await sleep(RATE_LIMIT_MS);
    }
  }

  // Phase 5 — Newly finished: final detail + lineup.
  const { newlyFinished, statuses } = await detectNewlyFinished(allMatches);
  if (newlyFinished.length) {
    console.log(`Phase 5: ${newlyFinished.length} newly finished match(es)…`);
    for (const id of newlyFinished) {
      await fetchMatchDetail(id);
      await fetchAndStoreLineup(id);
      await sleep(RATE_LIMIT_MS);
    }
  }

  // Phase 6 — Write meta LAST (app reads this doc first).
  await db.collection('meta').doc('relay').set(
    {
      lastRun:        NOW(),
      lastRunIso:     now.toISOString(),
      liveMatchIds:   live,
      windowOpen,
      statuses,
      competitions:   COMPETITIONS,
    },
    { merge: true }
  );

  console.log(
    `✓ Relay done. live=${live.length} newlyFinished=${newlyFinished.length} window=${windowOpen}`
  );
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Relay failed:', err);
    process.exit(1);
  });
