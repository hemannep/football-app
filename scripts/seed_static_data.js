// scripts/seed_static_data.js
// ─────────────────────────────────────────────────────────────────────────────
// Football Fan Hub 2026 — Static Data Seeder
//
// Populates two Firestore collections that change rarely (compared to live
// scores), so they belong in their OWN workflow with a daily schedule rather
// than the 5-minute live-data relay:
//
//   • teams/{teamId}     — full team profile + squad (48 docs)
//   • players/{playerId} — flat player rows, queryable by teamId
//
// Strategy:
//   1. Bulk fetch /competitions/WC/teams — one call, all 48 teams.
//   2. If a team's squad is empty (free tier sometimes omits it on bulk),
//      do a /teams/{id} per-team fallback, paced under 10 req/min.
//   3. Write teams in one batch; write players in chunked batches (≤450 ops
//      per commit to stay safely under the 500-op limit).
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');

const fetchFn = global.fetch
  ? global.fetch
  : (...a) => import('node-fetch').then(({ default: f }) => f(...a));

const FD_BASE = 'https://api.football-data.org/v4';
const FD_COMPETITION = 'WC';
const BATCH_LIMIT = 450; // safe under Firestore's hard 500 per commit

if (!process.env.FIREBASE_SA) {
  console.error('FATAL: FIREBASE_SA missing.');
  process.exit(1);
}
admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SA)),
});
const db = admin.firestore();
const NOW = admin.firestore.FieldValue.serverTimestamp;

// ─── HTTP ─────────────────────────────────────────────────────────────────────
async function fdGet(path) {
  const res = await fetchFn(`${FD_BASE}${path}`, {
    headers: { 'X-Auth-Token': process.env.FD_TOKEN },
  });
  if (!res.ok) {
    console.warn(`football-data.org ${res.status} on ${path}`);
    return null;
  }
  return res.json();
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ─── Chunked commit helper ────────────────────────────────────────────────────
// Firestore caps each batch at 500 ops. We chunk so big squads can't break it.
async function commitInChunks(ops) {
  let count = 0;
  for (let i = 0; i < ops.length; i += BATCH_LIMIT) {
    const slice = ops.slice(i, i + BATCH_LIMIT);
    const batch = db.batch();
    for (const op of slice) batch.set(op.ref, op.data, { merge: true });
    await batch.commit();
    count += slice.length;
  }
  return count;
}

// ─── Normalizers ──────────────────────────────────────────────────────────────
function teamDoc(t) {
  return {
    id: t.id,
    name: t.name ?? 'Unknown',
    shortName: t.shortName ?? null,
    tla: t.tla ?? '???',
    crest: t.crest ?? null,
    address: t.address ?? null,
    website: t.website ?? null,
    founded: t.founded ?? null,
    clubColors: t.clubColors ?? null,
    venue: t.venue ?? null,
    coach: t.coach ?? null,
    // squad stored on the team doc so a single read gives you everything.
    squad: Array.isArray(t.squad) ? t.squad : [],
    updatedAt: NOW(),
  };
}

function playerDoc(p, team) {
  return {
    id: p.id,
    name: p.name ?? 'Unknown',
    position: p.position ?? null,
    dateOfBirth: p.dateOfBirth ?? null,
    nationality: p.nationality ?? null,
    shirtNumber: p.shirtNumber ?? null,
    // Denormalized team info so player-detail screens need only 1 read.
    teamId: team.id,
    teamName: team.name,
    teamTla: team.tla,
    teamCrest: team.crest ?? null,
    updatedAt: NOW(),
  };
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  const startedAt = new Date();
  console.log(`▶ Seed start ${startedAt.toISOString()}`);

  // 1. Bulk teams.
  const bulk = await fdGet(`/competitions/${FD_COMPETITION}/teams`);
  if (!bulk?.teams?.length) {
    console.error('No teams returned. Aborting.');
    process.exit(1);
  }
  const teams = bulk.teams;
  console.log(`✓ Fetched ${teams.length} teams.`);

  // 2. Fallback per-team for any team missing a squad.
  //    Paced at one request every 7s (≈ 8/min, well under the 10/min cap).
  const missingSquad = teams.filter((t) => !Array.isArray(t.squad) || t.squad.length === 0);
  if (missingSquad.length) {
    console.log(`  ${missingSquad.length} teams missing squad — fetching detail…`);
    for (const t of missingSquad) {
      const detail = await fdGet(`/teams/${t.id}`);
      if (detail?.squad) t.squad = detail.squad;
      await sleep(7000);
    }
  }

  // 3. Write teams.
  const teamOps = teams.map((t) => ({
    ref: db.collection('teams').doc(String(t.id)),
    data: teamDoc(t),
  }));
  const teamsWritten = await commitInChunks(teamOps);
  console.log(`✓ Wrote ${teamsWritten} team docs.`);

  // 4. Write players (denormalized, one row per player).
  const playerOps = [];
  for (const t of teams) {
    for (const p of t.squad ?? []) {
      if (!p?.id) continue;
      playerOps.push({
        ref: db.collection('players').doc(String(p.id)),
        data: playerDoc(p, t),
      });
    }
  }
  const playersWritten = await commitInChunks(playerOps);
  console.log(`✓ Wrote ${playersWritten} player docs.`);

  // 5. Heartbeat — lets the app show "Squads updated X hours ago".
  await db.collection('meta').doc('seed').set(
    {
      lastRun: NOW(),
      lastRunIso: startedAt.toISOString(),
      teamsCount: teamsWritten,
      playersCount: playersWritten,
    },
    { merge: true }
  );

  console.log(`✓ Seed done. teams=${teamsWritten} players=${playersWritten}`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Seed failed:', err);
    process.exit(1);
  });