// scripts/bzzoiro_enricher.js
// ─────────────────────────────────────────────────────────────────────────────
// Football Fan Hub 2026 — Bzzoiro Enricher
//
// Runs in the same workflow as relay.js, AFTER it. The main relay populates
// matches/{fdId} from football-data.org. This script then:
//
//   1. Reads matches in the "enrichment window" (live + next 24h) from Firestore
//   2. Pulls Bzzoiro events for the same date range (+ live)
//   3. Matches them by (kickoff date, normalized team names) — sources use
//      different IDs, so name+time matching is the bridge
//   4. Writes Bzzoiro's lineups, incidents, live_stats, xG and shotmap into
//      the SAME matches/{fdId} doc under namespaced fields
//   5. Logs unmatched events to meta/bzzoiro for debugging
//
// Result: the Flutter app reads ONE doc per match and gets everything —
// football-data score + Bzzoiro lineups, incidents, xG, momentum.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');

const fetchFn = global.fetch
  ? global.fetch
  : (...a) => import('node-fetch').then(({ default: f }) => f(...a));

const BSD = 'https://sports.bzzoiro.com/api';
const ENRICH_PAST_MS = 3 * 60 * 60 * 1000; // 3h after kickoff
const ENRICH_FUTURE_MS = 24 * 60 * 60 * 1000; // 24h before kickoff

if (!process.env.FIREBASE_SA) {
  console.error('FATAL: FIREBASE_SA missing.');
  process.exit(1);
}
if (!process.env.BZZOIRO_TOKEN) {
  console.error('FATAL: BZZOIRO_TOKEN missing.');
  process.exit(1);
}
admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SA)),
});
const db = admin.firestore();
const NOW = admin.firestore.FieldValue.serverTimestamp;

// ─── HTTP ─────────────────────────────────────────────────────────────────────
async function bzzGet(path) {
  const res = await fetchFn(`${BSD}${path}`, {
    headers: { Authorization: `Token ${process.env.BZZOIRO_TOKEN}` },
  });
  if (!res.ok) {
    console.warn(`Bzzoiro ${res.status} on ${path}`);
    return null;
  }
  return res.json();
}

// ─── Name normalization for cross-source matching ────────────────────────────
// football-data and Bzzoiro disagree on a few country names. We:
//   1. Lowercase + strip accents + strip non-letters
//   2. Map known TLAs → list of acceptable Bzzoiro forms
// If you spot another mismatch in the unmatched log, just extend this map.
const ALIASES = {
  USA: ['usa', 'unitedstates', 'unitedstatesofamerica'],
  KOR: ['southkorea', 'koreasouth', 'koreathrepublicof', 'republicofkorea', 'korearepublic'],
  PRK: ['northkorea', 'koreanorth', 'democraticpeoplesrepublicofkorea'],
  IRN: ['iran', 'islamicrepublicofiran'],
  CIV: ['cotedivoire', 'ivorycoast'],
  CZE: ['czechia', 'czechrepublic'],
  RSA: ['southafrica'],
  CPV: ['caboverde', 'capeverde'],
  BIH: ['bosniaandherzegovina', 'bosniaherzegovina'],
  TUR: ['turkey', 'turkiye'],
  CGO: ['drcongo', 'democraticrepublicofthecongo'],
  CRC: ['costarica'],
  TRI: ['trinidadandtobago'],
  NZL: ['newzealand'],
  SAU: ['saudiarabia'],
};

function norm(s) {
  return (s || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z]/g, '');
}

function teamsMatch(bzzName, fdName, fdTla) {
  if (!bzzName || !fdName) return false;
  const a = norm(bzzName);
  const b = norm(fdName);
  if (a === b) return true;
  if (a.length >= 4 && (a.includes(b) || b.includes(a))) return true;
  const aliases = ALIASES[(fdTla || '').toUpperCase()];
  if (aliases?.some((x) => norm(x) === a)) return true;
  return false;
}

// ─── Step 1: read candidate matches from Firestore ────────────────────────────
async function getCandidates() {
  const now = Date.now();
  const snap = await db.collection('matches').get();
  return snap.docs
    .map((d) => ({ fdId: d.id, m: d.data() }))
    .filter(({ m }) => {
      if (!m.utcDate) return false;
      if (m.status === 'IN_PLAY' || m.status === 'PAUSED') return true;
      const ko = new Date(m.utcDate).getTime();
      return ko >= now - ENRICH_PAST_MS && ko <= now + ENRICH_FUTURE_MS;
    });
}

// ─── Step 2: fetch Bzzoiro events (paginated) ────────────────────────────────
async function fetchBzzEvents(dateFrom, dateTo) {
  const out = [];
  let offset = 0;
  for (let page = 0; page < 5; page++) {
    const url = `/events/?date_from=${dateFrom}&date_to=${dateTo}&full=true&limit=200&offset=${offset}`;
    const data = await bzzGet(url);
    const results = data?.results ?? [];
    out.push(...results);
    if (results.length < 200) break;
    offset += 200;
  }
  return out;
}

async function fetchBzzLive() {
  const data = await bzzGet('/live/?full=true');
  return data?.results ?? [];
}

// ─── Step 3: match Bzzoiro event → fdId ──────────────────────────────────────
function findCandidate(bzzEv, candidates) {
  const koB = new Date(bzzEv.event_date).getTime();
  if (Number.isNaN(koB)) return null;

  for (const c of candidates) {
    const koF = new Date(c.m.utcDate).getTime();
    // Same kickoff within ±2 hours (covers TZ confusion and re-scheduling).
    if (Math.abs(koB - koF) > 2 * 60 * 60 * 1000) continue;

    const home = teamsMatch(bzzEv.home_team, c.m.homeTeam?.name, c.m.homeTeam?.tla);
    const away = teamsMatch(bzzEv.away_team, c.m.awayTeam?.name, c.m.awayTeam?.tla);
    if (home && away) return c;
  }
  return null;
}

// ─── Step 4: write enrichment back ───────────────────────────────────────────
async function enrich(candidate, bzzEv) {
  await db.collection('matches').doc(candidate.fdId).set(
    {
      bzzoiroId: bzzEv.id,
      // Lineups (separate field name so we don't clobber any existing lineups doc)
      bzzLineups: bzzEv.lineups ?? null,
      bzzPredictedFormation: {
        home: bzzEv.home_coach?.preferred_formation ?? null,
        away: bzzEv.away_coach?.preferred_formation ?? null,
      },
      // Incidents (goals, cards, substitutions) — the app already shows these
      incidents: Array.isArray(bzzEv.incidents) ? bzzEv.incidents : [],
      // Live in-match stats — possession, shots, corners, etc.
      liveStats: bzzEv.live_stats ?? null,
      // xG
      xg: {
        homeLive: bzzEv.home_xg_live ?? null,
        awayLive: bzzEv.away_xg_live ?? null,
        homeActual: bzzEv.actual_home_xg ?? null,
        awayActual: bzzEv.actual_away_xg ?? null,
      },
      // Spatial — only useful on match-detail screens that want it
      shotmap: bzzEv.shotmap ?? null,
      momentum: bzzEv.momentum ?? null,
      xgPerMinute: bzzEv.xg_per_minute ?? null,
      averagePositions: bzzEv.average_positions ?? null,
      // Officials + form
      referee: bzzEv.referee ?? null,
      unavailablePlayers: bzzEv.unavailable_players ?? null,
      // Penalty shootout (knockouts)
      penaltyShootout: bzzEv.penalty_shootout ?? null,
      bzzUpdatedAt: NOW(),
    },
    { merge: true }
  );
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  const startedAt = new Date();
  console.log(`▶ Enricher start ${startedAt.toISOString()}`);

  const candidates = await getCandidates();
  if (!candidates.length) {
    console.log('No matches in the enrichment window — skipping.');
    await db.collection('meta').doc('bzzoiro').set(
      { lastRun: NOW(), lastRunIso: startedAt.toISOString(), matched: 0, unmatched: 0, candidates: 0 },
      { merge: true }
    );
    return;
  }

  // Date range covering all candidates (ISO YYYY-MM-DD).
  const koTimes = candidates.map((c) => new Date(c.m.utcDate).getTime());
  const dateFrom = new Date(Math.min(...koTimes)).toISOString().slice(0, 10);
  const dateTo = new Date(Math.max(...koTimes)).toISOString().slice(0, 10);

  const [scheduled, live] = await Promise.all([
    fetchBzzEvents(dateFrom, dateTo),
    fetchBzzLive(),
  ]);

  // Live events get priority — they have fresher live_stats + incidents.
  const byId = new Map();
  for (const e of scheduled) byId.set(e.id, e);
  for (const e of live) byId.set(e.id, e);
  const events = [...byId.values()];

  let matched = 0;
  const unmatchedSamples = [];
  for (const ev of events) {
    const cand = findCandidate(ev, candidates);
    if (cand) {
      await enrich(cand, ev);
      matched++;
    } else if (unmatchedSamples.length < 5) {
      unmatchedSamples.push(`${ev.home_team} vs ${ev.away_team} @ ${ev.event_date}`);
    }
  }
  const unmatched = events.length - matched;

  await db.collection('meta').doc('bzzoiro').set(
    {
      lastRun: NOW(),
      lastRunIso: startedAt.toISOString(),
      matched,
      unmatched,
      candidates: candidates.length,
      totalBzzEvents: events.length,
      unmatchedSamples, // first 5 — useful for adding to the ALIASES map
    },
    { merge: true }
  );

  console.log(`✓ Enricher done. matched=${matched} unmatched=${unmatched} candidates=${candidates.length}`);
  if (unmatchedSamples.length) {
    console.log(`  Unmatched samples: ${unmatchedSamples.join(' | ')}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Enricher failed:', err);
    process.exit(1);
  });