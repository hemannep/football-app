// scripts/bzzoiro_enricher.js
// ─────────────────────────────────────────────────────────────────────────────
// Football Fan Hub 2026 — Bzzoiro Enricher  (BSD v2)
//
// Runs in the same GitHub Actions workflow as relay.js, AFTER it.
// Reads matches in the enrichment window, hits BSD v2 sub-endpoints per match,
// and writes bzzLineups, incidents, liveStats, xG, coach names into the
// matches/{fdId} Firestore document so the Flutter app reads ONE doc per match.
//
// BSD v2 endpoints used:
//   GET /events/?date_from=…&date_to=…&limit=100   → event list + basic data
//   GET /live/?                                     → live events
//   GET /events/{id}/lineups/                       → confirmed/predicted lineup
//   GET /events/{id}/incidents/                     → goals, cards, subs
//   GET /events/{id}/stats/                         → possession, shots, …
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');

const fetchFn = global.fetch
  ? global.fetch
  : (...a) => import('node-fetch').then(({ default: f }) => f(...a));

// ─── Config ───────────────────────────────────────────────────────────────────
const BSD_BASE         = 'https://sports.bzzoiro.com/api/v2';
const ENRICH_PAST_MS   = 3  * 60 * 60 * 1000;  // 3 h after kickoff
const ENRICH_FUTURE_MS = 24 * 60 * 60 * 1000;  // 24 h before kickoff
const HTTP_TIMEOUT_MS  = 30000;

if (!process.env.FIREBASE_SA) { console.error('FATAL: FIREBASE_SA missing.'); process.exit(1); }
if (!process.env.BZZOIRO_TOKEN) { console.error('FATAL: BZZOIRO_TOKEN missing.'); process.exit(1); }

admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SA)) });
const db  = admin.firestore();
const NOW = admin.firestore.FieldValue.serverTimestamp;

// ─── HTTP helper ─────────────────────────────────────────────────────────────
async function bzzGet(path) {
  const ctrl  = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), HTTP_TIMEOUT_MS);
  try {
    const res = await fetchFn(`${BSD_BASE}${path}`, {
      headers: {
        Authorization: `Token ${process.env.BZZOIRO_TOKEN}`,
        Accept: 'application/json',
      },
      signal: ctrl.signal,
    });
    clearTimeout(timer);
    if (!res.ok) {
      console.warn(`Bzzoiro ${res.status} on ${path}`);
      return null;
    }
    return res.json();
  } catch (err) {
    clearTimeout(timer);
    console.warn(err.name === 'AbortError'
      ? `Bzzoiro timeout on ${path}`
      : `Bzzoiro error on ${path}: ${err.message}`);
    return null;
  }
}

// ─── Name normalization ───────────────────────────────────────────────────────
const ALIASES = {
  USA: ['usa', 'unitedstates', 'unitedstatesofamerica'],
  KOR: ['southkorea', 'koreasouth', 'korearepublic', 'republicofkorea'],
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
  CMR: ['cameroon'],
  GHA: ['ghana'],
  SEN: ['senegal'],
  MAR: ['morocco'],
  EGY: ['egypt'],
  NGA: ['nigeria'],
  ECU: ['ecuador'],
  URU: ['uruguay'],
  PAR: ['paraguay'],
  PER: ['peru'],
};

function norm(s) {
  return (s || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
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

// ─── Lineup converter: BSD v2 {home:{starters,bench},away:{…}} → flat list ──
// The Flutter lineups_tab expects bzzLineups as a flat list of player objects
// with is_home / is_starter fields, NOT a {home/away} map.
function buildFlatLineups(lineupsData) {
  if (!lineupsData || typeof lineupsData !== 'object') return null;
  const out = [];

  function addSide(side, isHome) {
    if (!side || typeof side !== 'object') return;
    const starters = side.starters || side.startXI || side.lineup || [];
    const bench    = side.bench    || side.substitutes || [];
    for (const p of starters) {
      if (!p || typeof p !== 'object') continue;
      out.push({
        player_name:   p.name         || p.player_name || '',
        name:          p.name         || p.player_name || '',
        jersey_number: p.shirt_number ?? p.number      ?? null,
        position:      p.position     || p.pos         || null,
        is_home:       isHome,
        is_starter:    true,
        rating:        p.rating       ?? null,
        photo_url:     p.photo_url    || p.photo        || null,
      });
    }
    for (const p of bench) {
      if (!p || typeof p !== 'object') continue;
      out.push({
        player_name:   p.name         || p.player_name || '',
        name:          p.name         || p.player_name || '',
        jersey_number: p.shirt_number ?? p.number      ?? null,
        position:      p.position     || p.pos         || null,
        is_home:       isHome,
        is_starter:    false,
        rating:        p.rating       ?? null,
        photo_url:     p.photo_url    || p.photo        || null,
      });
    }
  }

  addSide(lineupsData.home || lineupsData.home_lineup, true);
  addSide(lineupsData.away || lineupsData.away_lineup, false);
  return out.length > 0 ? out : null;
}

// ─── Step 1: read candidate matches from Firestore ────────────────────────────
async function getCandidates() {
  const now  = Date.now();
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

// ─── Step 2: fetch BSD v2 events for a date range ────────────────────────────
async function fetchBzzEvents(dateFrom, dateTo) {
  const out = [];
  let offset = 0;
  for (let page = 0; page < 5; page++) {
    const data = await bzzGet(
      `/events/?date_from=${dateFrom}&date_to=${dateTo}&limit=100&offset=${offset}`
    );
    const results = data?.results ?? [];
    out.push(...results);
    if (results.length < 100) break;
    offset += 100;
  }
  return out;
}

async function fetchBzzLive() {
  const data = await bzzGet('/live/');
  return data?.results ?? [];
}

// ─── Step 3: fetch sub-resources for a specific BSD event id ─────────────────
async function fetchLineups(bsdId)   { return bzzGet(`/events/${bsdId}/lineups/`); }
async function fetchIncidents(bsdId) { return bzzGet(`/events/${bsdId}/incidents/`); }
async function fetchStats(bsdId)     { return bzzGet(`/events/${bsdId}/stats/`); }

// ─── Step 4: match Bzzoiro event → Firestore candidate ───────────────────────
function findCandidate(bzzEv, candidates) {
  // v2 field: event_date (ISO datetime)
  const koB = new Date(bzzEv.event_date || bzzEv.date || '').getTime();
  if (Number.isNaN(koB)) return null;

  for (const c of candidates) {
    const koF = new Date(c.m.utcDate).getTime();
    if (Math.abs(koB - koF) > 2 * 60 * 60 * 1000) continue;

    // v2 field names: home_team / away_team (same as v1)
    const home = teamsMatch(bzzEv.home_team, c.m.homeTeam?.name, c.m.homeTeam?.tla);
    const away = teamsMatch(bzzEv.away_team, c.m.awayTeam?.name, c.m.awayTeam?.tla);
    if (home && away) return c;
  }
  return null;
}

// ─── Step 5: enrich one match ─────────────────────────────────────────────────
async function enrichOne(candidate, bzzEv) {
  const bsdId    = bzzEv.id;
  const isLive   = bzzEv.status === 'live' || bzzEv.live === true;
  const isFinished = bzzEv.status === 'finished' || bzzEv.result != null;

  // Fetch sub-resources in parallel (rate-limit: relay already serialises calls
  // at the match level, so parallel sub-calls for ONE match is fine).
  const [lineupsRaw, incidentsRaw, statsRaw] = await Promise.all([
    fetchLineups(bsdId),
    fetchIncidents(bsdId),
    fetchStats(bsdId),
  ]);

  // ── Build flat bzzLineups list ──────────────────────────────────────────────
  const flatLineups = buildFlatLineups(lineupsRaw);

  // ── Extract coach names (v2: home/away object has coach field) ──────────────
  const homeCoach = lineupsRaw?.home?.coach?.name
    || lineupsRaw?.home?.coach
    || bzzEv.home_coach?.name
    || null;
  const awayCoach = lineupsRaw?.away?.coach?.name
    || lineupsRaw?.away?.coach
    || bzzEv.away_coach?.name
    || null;

  // ── Formations ─────────────────────────────────────────────────────────────
  const homeFormation = lineupsRaw?.home?.formation
    || bzzEv.home_coach?.preferred_formation
    || null;
  const awayFormation = lineupsRaw?.away?.formation
    || bzzEv.away_coach?.preferred_formation
    || null;

  // ── Incidents (v2: list with type, minute, player, team_id, etc.) ──────────
  const incidentsList = Array.isArray(incidentsRaw)
    ? incidentsRaw
    : (incidentsRaw?.incidents ?? incidentsRaw?.results ?? []);

  // ── Live stats (v2: {home:{…}, away:{…}}) ──────────────────────────────────
  const statsMap = (statsRaw && typeof statsRaw === 'object')
    ? statsRaw
    : null;

  // ── xG: prefer stats endpoint, fall back to top-level event fields ──────────
  const xgHomeLive   = statsRaw?.home?.xg         ?? bzzEv.home_xg_live    ?? null;
  const xgAwayLive   = statsRaw?.away?.xg         ?? bzzEv.away_xg_live    ?? null;
  const xgHomeActual = statsRaw?.home?.actual_xg  ?? bzzEv.actual_home_xg  ?? null;
  const xgAwayActual = statsRaw?.away?.actual_xg  ?? bzzEv.actual_away_xg  ?? null;

  const update = {
    bzzoiroId: bsdId,

    // Lineups as flat list (Flutter lineups_tab reads is_home/is_starter)
    bzzLineups:            flatLineups,
    bzzCoach:              { home: homeCoach, away: awayCoach },
    bzzPredictedFormation: { home: homeFormation, away: awayFormation },

    // Incidents (goals, cards, subs)
    incidents: incidentsList,

    // Live stats — possesion, shots, corners, etc.
    liveStats: statsMap,

    // Expected goals
    xg: {
      homeLive:   xgHomeLive,
      awayLive:   xgAwayLive,
      homeActual: xgHomeActual,
      awayActual: xgAwayActual,
    },

    // Spatial / experimental (keep for future screens)
    shotmap:          bzzEv.shotmap          ?? null,
    momentum:         bzzEv.momentum         ?? null,
    xgPerMinute:      bzzEv.xg_per_minute    ?? null,
    averagePositions: bzzEv.average_positions ?? null,

    // Officials
    referee:             bzzEv.referee              ?? null,
    unavailablePlayers:  bzzEv.unavailable_players   ?? null,

    // Knockout extras
    penaltyShootout: bzzEv.penalty_shootout ?? null,

    bzzUpdatedAt: NOW(),
  };

  // Also mirror flat lineups into lineups/{fdId} so the Flutter
  // lineupProvider can find them without reading the full match doc.
  if (flatLineups && flatLineups.length > 0) {
    await db.collection('lineups').doc(candidate.fdId).set({
      home: lineupsRaw?.home ?? null,
      away: lineupsRaw?.away ?? null,
      flatLineups,
      fetchedAt: NOW(),
    }, { merge: true });
  }

  await db.collection('matches').doc(candidate.fdId).set(update, { merge: true });

  console.log(`  ✓ Enriched match ${candidate.fdId} (bsdId=${bsdId})`
    + ` lineups=${flatLineups?.length ?? 0}`
    + ` incidents=${incidentsList.length}`
    + ` stats=${statsMap ? 'yes' : 'no'}`);
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  const startedAt = new Date();
  console.log(`▶ Enricher start ${startedAt.toISOString()} (BSD v2)`);

  const candidates = await getCandidates();
  if (!candidates.length) {
    console.log('No matches in enrichment window — skipping.');
    await db.collection('meta').doc('bzzoiro').set(
      { lastRun: NOW(), lastRunIso: startedAt.toISOString(), matched: 0, unmatched: 0, candidates: 0 },
      { merge: true }
    );
    return;
  }

  // Date range covering all candidates.
  const koTimes  = candidates.map((c) => new Date(c.m.utcDate).getTime());
  const dateFrom = new Date(Math.min(...koTimes)).toISOString().slice(0, 10);
  const dateTo   = new Date(Math.max(...koTimes)).toISOString().slice(0, 10);

  const [scheduled, live] = await Promise.all([
    fetchBzzEvents(dateFrom, dateTo),
    fetchBzzLive(),
  ]);

  // Live events take priority (fresher data).
  const byId = new Map();
  for (const e of scheduled) byId.set(e.id, e);
  for (const e of live)      byId.set(e.id, e);
  const events = [...byId.values()];

  let matched = 0;
  const unmatchedSamples = [];

  for (const ev of events) {
    const cand = findCandidate(ev, candidates);
    if (cand) {
      try {
        await enrichOne(cand, ev);
        matched++;
      } catch (err) {
        console.warn(`  ✗ enrichOne failed for ${cand.fdId}: ${err.message}`);
      }
    } else if (unmatchedSamples.length < 5) {
      unmatchedSamples.push(`${ev.home_team} vs ${ev.away_team} @ ${ev.event_date}`);
    }
  }

  const unmatched = events.length - matched;
  await db.collection('meta').doc('bzzoiro').set(
    {
      lastRun:        NOW(),
      lastRunIso:     startedAt.toISOString(),
      matched,
      unmatched,
      candidates:     candidates.length,
      totalBzzEvents: events.length,
      unmatchedSamples,
    },
    { merge: true }
  );

  console.log(`✓ Enricher done. matched=${matched} unmatched=${unmatched} candidates=${candidates.length}`);
  if (unmatchedSamples.length) {
    console.log(`  Unmatched: ${unmatchedSamples.join(' | ')}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => { console.error('Enricher failed:', err); process.exit(1); });
