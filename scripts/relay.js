// scripts/relay.js
// ─────────────────────────────────────────────────────────────────────────────
// Football Fan Hub 2026 — Data Relay
//
// Runs on GitHub Actions (cron */5). Pulls from football-data.org (live scores,
// events, standings) and API-Football (lineups, once per match), normalizes
// everything into the schema the Flutter app expects, and writes to Firestore.
//
// The Flutter app NEVER calls these external APIs. It only reads Firestore.
// External API keys live ONLY in GitHub Secrets — never in the APK.
//
// Design rules:
//   • Every external call is wrapped — one failing source never aborts the run.
//   • Writes are batched (1 commit for all matches) to stay cheap on quota.
//   • Goals are written in the EXACT shape Match.fromJson()/MatchGoal expects:
//       { minute, scorer:{name}, team:{id,tla}, type, assist:{name} }
//   • meta/relay holds liveMatchIds + lastRun so the app reads 1 cheap doc first.
//   • API-Football lineup calls are gated to newly-finished matches only,
//     keeping total usage at ~104 calls for the whole tournament (limit 100/day).
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');

// node-fetch v3 is ESM-only; use global fetch (Node 18+) if present, else import.
const fetchFn = global.fetch
  ? global.fetch
  : (...args) => import('node-fetch').then(({ default: f }) => f(...args));

// ─── Config ──────────────────────────────────────────────────────────────────
const FD_BASE = 'https://api.football-data.org/v4';
const FD_COMPETITION = 'WC';
const APIFOOTBALL_BASE = 'https://v3.football.api-sports.io';

// A match is considered "in its window" from 15 min before kickoff to 3h after.
const PRE_KICKOFF_MS = 15 * 60 * 1000;
const POST_KICKOFF_MS = 3 * 60 * 60 * 1000;

const LIVE_STATUSES = new Set(['IN_PLAY', 'PAUSED']);

// ─── Init Firebase Admin ───────────────────────────────────────────────────────
if (!process.env.FIREBASE_SA) {
  console.error('FATAL: FIREBASE_SA secret is missing.');
  process.exit(1);
}
admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SA)),
});
const db = admin.firestore();
const NOW = admin.firestore.FieldValue.serverTimestamp;

// ─── HTTP helpers ───────────────────────────────────────────────────────────────
async function fdGet(path) {
  const res = await fetchFn(`${FD_BASE}${path}`, {
    headers: { 'X-Auth-Token': process.env.FD_TOKEN },
  });
  if (res.status === 429) {
    console.warn(`football-data.org rate limited on ${path} — backing off.`);
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

// ─── Normalizers ────────────────────────────────────────────────────────────────
// football-data.org returns goals at /matches/{id}.goals. We reshape each one
// to the EXACT structure MatchGoal.fromJson() reads in the Flutter app.
function normalizeGoals(rawGoals) {
  if (!Array.isArray(rawGoals)) return [];
  return rawGoals.map((g) => ({
    minute: g.minute ?? 0,
    type: g.type ?? 'REGULAR', // REGULAR | OWN | PENALTY
    scorer: { name: g.scorer?.name ?? null },
    assist: { name: g.assist?.name ?? null },
    team: { id: g.team?.id ?? null, tla: g.team?.tla ?? null },
  }));
}

function normalizeBookings(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.map((b) => ({
    minute: b.minute ?? 0,
    player: b.player?.name ?? null,
    team: b.team?.tla ?? b.team?.name ?? null,
    card: b.card ?? 'YELLOW', // YELLOW | RED | YELLOW_RED
  }));
}

function normalizeSubs(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.map((s) => ({
    minute: s.minute ?? 0,
    playerIn: s.playerIn?.name ?? null,
    playerOut: s.playerOut?.name ?? null,
    team: s.team?.tla ?? s.team?.name ?? null,
  }));
}

// ─── Step 1: bulk matches (live scores, statuses) ───────────────────────────────
// Cheap: one external call, one batched Firestore commit for all 104 matches.
async function fetchAndStoreMatches() {
  const data = await fdGet(`/competitions/${FD_COMPETITION}/matches`);
  if (!data || !Array.isArray(data.matches)) return [];

  const compName = data.competition?.name ?? 'World Cup';
  const batch = db.batch();
  const liveIds = [];

  for (const m of data.matches) {
    const ref = db.collection('matches').doc(String(m.id));
    batch.set(
      ref,
      {
        id: m.id,
        status: m.status,
        utcDate: m.utcDate,
        homeTeam: m.homeTeam ?? {},
        awayTeam: m.awayTeam ?? {},
        score: m.score ?? {},
        stage: m.stage ?? 'GROUP_STAGE',
        group: m.group ?? null,
        competition: { name: compName, code: FD_COMPETITION },
        updatedAt: NOW(),
      },
      { merge: true }
    );
    if (LIVE_STATUSES.has(m.status)) liveIds.push(m.id);
  }

  await batch.commit();
  console.log(`✓ Stored ${data.matches.length} matches (${liveIds.length} live).`);
  return data.matches;
}

// ─── Step 2: standings (hourly / during windows) ────────────────────────────────
async function fetchAndStoreStandings() {
  const data = await fdGet(`/competitions/${FD_COMPETITION}/standings`);
  if (!data || !Array.isArray(data.standings)) return;

  const batch = db.batch();
  for (const s of data.standings) {
    const groupKey = s.group ?? s.stage ?? 'TOTAL';
    const ref = db.collection('standings').doc(groupKey);
    batch.set(
      ref,
      { group: groupKey, table: s.table ?? [], updatedAt: NOW() },
      { merge: true }
    );
  }
  await batch.commit();
  console.log(`✓ Stored ${data.standings.length} standings groups.`);
}

// ─── Step 3: per-match detail (goals, cards, subs) for live + just-finished ─────
async function fetchMatchDetail(matchId) {
  const m = await fdGet(`/matches/${matchId}`);
  if (!m) return;

  await db.collection('matches').doc(String(matchId)).set(
    {
      goals: normalizeGoals(m.goals),
      bookings: normalizeBookings(m.bookings),
      substitutions: normalizeSubs(m.substitutions),
      score: m.score ?? {},
      status: m.status,
      detailUpdatedAt: NOW(),
    },
    { merge: true }
  );
}

// ─── Step 4: lineups via API-Football (once per match, newly finished) ──────────
// NOTE: API-Football uses its own fixture ID system — different from football-
// data.org. The `/fixtures?id=X` call here will only work if you've stored an
// fd→apifootball ID mapping in schedule.json (not required for launch; Bzzoiro
// covers lineups for the live enrichment window). Until that map exists this
// step is a no-op but still safe to run.
async function fetchAndStoreLineup(matchId) {
  const data = await apiFootballGet(`/fixtures?id=${matchId}`);
  const fixture = data?.response?.[0];
  if (!fixture) return;

  // Write to the dedicated lineups/ collection.
  await db.collection('lineups').doc(String(matchId)).set({
    home: fixture.lineups?.[0] ?? null,
    away: fixture.lineups?.[1] ?? null,
    events: fixture.events ?? [],
    fetchedAt: NOW(),
  });

  // Also merge into the matches/ doc under confirmedLineup so the Flutter app
  // can read it via getMatchRaw() without a second collection fetch.
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

  console.log(`✓ Stored lineup for match ${matchId}.`);
}

// ─── Match-window detection ──────────────────────────────────────────────────────
// Returns { live:[ids], windowOpen:bool } based on the live statuses we already
// pulled, plus a time-window check so we still poll detail just before kickoff.
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

// Compares the previous run's status (stored in meta/relay.statuses) with the
// current pull to detect matches that transitioned INTO "FINISHED" this run.
async function detectNewlyFinished(matches) {
  const metaRef = db.collection('meta').doc('relay');
  const prev = (await metaRef.get()).data() ?? {};
  const prevStatuses = prev.statuses ?? {};

  const newlyFinished = [];
  const statuses = {};
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

  // 1. Bulk matches (always).
  const matches = await fetchAndStoreMatches();

  // 2. Classify what's live / in-window.
  const { live, windowOpen } = classifyMatches(matches, now);

  // 3. Standings: during a window, or at the top of the hour.
  if (windowOpen || now.getUTCMinutes() < 5) {
    await fetchAndStoreStandings();
  }

  // 4. Per-match detail for every live match (goals/cards/subs).
  for (const id of live) {
    await fetchMatchDetail(id);
  }

  // 5. Newly finished: one final detail pull + one lineup pull each.
  const { newlyFinished, statuses } = await detectNewlyFinished(matches);
  for (const id of newlyFinished) {
    await fetchMatchDetail(id);
    await fetchAndStoreLineup(id);
  }

  // 6. Write meta doc LAST — app reads this first (1 cheap doc).
  await db.collection('meta').doc('relay').set(
    {
      lastRun: NOW(),
      lastRunIso: now.toISOString(),
      liveMatchIds: live,
      windowOpen,
      statuses, // used next run to detect transitions
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