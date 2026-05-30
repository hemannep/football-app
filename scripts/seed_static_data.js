// scripts/seed_static_data.js
// ─────────────────────────────────────────────────────────────────────────────
// Football Fan Hub 2026 — Static Data Seeder
//
// Populates Firestore collections that change rarely:
//
//   • teams/{teamId}     — full team profile + squad
//   • players/{playerId} — flat player rows queryable by teamId
//
// Fetches teams for ALL 12 supported competitions, deduplicates by team ID
// (same club can appear in PL + CL), and writes in batched Firestore commits.
//
// Strategy:
//   1. Loop through each competition, bulk-fetch /competitions/{code}/teams.
//   2. Deduplicate by teamId — merge squad if a later fetch has more players.
//   3. For any team still missing a squad, do per-team fallback (paced).
//   4. Write teams + players in chunked batches (≤450 ops per commit).
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');

const fetchFn = global.fetch
  ? global.fetch
  : (...a) => import('node-fetch').then(({ default: f }) => f(...a));

const FD_BASE      = 'https://api.football-data.org/v4';
const COMPETITIONS = ['WC', 'CL', 'EC', 'PL', 'PD', 'BL1', 'SA', 'FL1', 'DED', 'PPL', 'ELC', 'BSA'];
const BATCH_LIMIT  = 450; // safely under Firestore's 500-op hard cap

if (!process.env.FIREBASE_SA) {
  console.error('FATAL: FIREBASE_SA missing.');
  process.exit(1);
}
admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SA)),
});
const db  = admin.firestore();
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

// ─── Chunked commit ───────────────────────────────────────────────────────────
// A short pause between chunks prevents Firestore RESOURCE_EXHAUSTED bursts
// when writing thousands of player docs in quick succession.
async function commitInChunks(ops, delayBetweenMs = 1500) {
  let count = 0;
  for (let i = 0; i < ops.length; i += BATCH_LIMIT) {
    const slice = ops.slice(i, i + BATCH_LIMIT);
    const batch = db.batch();
    for (const op of slice) batch.set(op.ref, op.data, { merge: true });
    await batch.commit();
    count += slice.length;
    if (i + BATCH_LIMIT < ops.length) await sleep(delayBetweenMs);
  }
  return count;
}

// ─── Normalizers ──────────────────────────────────────────────────────────────
function teamDoc(t) {
  return {
    id:         t.id,
    name:       t.name        ?? 'Unknown',
    shortName:  t.shortName   ?? null,
    tla:        t.tla         ?? '???',
    crest:      t.crest       ?? null,
    address:    t.address     ?? null,
    website:    t.website     ?? null,
    founded:    t.founded     ?? null,
    clubColors: t.clubColors  ?? null,
    venue:      t.venue       ?? null,
    coach:      t.coach       ?? null,
    squad:      Array.isArray(t.squad) ? t.squad : [],
    updatedAt:  NOW(),
  };
}

function playerDoc(p, team) {
  return {
    id:          p.id,
    name:        p.name        ?? 'Unknown',
    position:    p.position    ?? null,
    dateOfBirth: p.dateOfBirth ?? null,
    nationality: p.nationality ?? null,
    shirtNumber: p.shirtNumber ?? null,
    // Denormalized team info so player-detail screens need only 1 read.
    teamId:      team.id,
    teamName:    team.name,
    teamTla:     team.tla,
    teamCrest:   team.crest    ?? null,
    updatedAt:   NOW(),
  };
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  const startedAt = new Date();
  console.log(`▶ Seed start ${startedAt.toISOString()}`);

  // 1. Collect teams from all competitions, deduplicating by team ID.
  //    If two competitions return the same team ID, keep the one with the
  //    larger squad (or the later one as a tie-break).
  const teamMap = new Map(); // id → team object

  for (const comp of COMPETITIONS) {
    console.log(`  Fetching [${comp}] teams…`);
    const bulk = await fdGet(`/competitions/${comp}/teams`);
    if (!bulk?.teams?.length) {
      console.log(`  [${comp}] No teams returned — skipping.`);
      await sleep(7000);
      continue;
    }

    for (const t of bulk.teams) {
      if (!t?.id) continue;
      const existing = teamMap.get(t.id);
      const newSquadLen      = Array.isArray(t.squad)          ? t.squad.length          : 0;
      const existingSquadLen = existing && Array.isArray(existing.squad) ? existing.squad.length : 0;
      // Prefer whichever version has a larger squad.
      if (!existing || newSquadLen > existingSquadLen) {
        teamMap.set(t.id, t);
      }
    }
    console.log(`  [${comp}] ${bulk.teams.length} teams fetched (total unique: ${teamMap.size})`);
    await sleep(7000); // rate limit: 10 req/min
  }

  if (teamMap.size === 0) {
    console.error('No teams returned from any competition. Aborting.');
    process.exit(1);
  }

  const teams = [...teamMap.values()];
  console.log(`✓ ${teams.length} unique teams collected.`);

  // 2. Per-team fallback for any team still missing a squad.
  //    Paced at 7 s each to stay under the 10 req/min limit.
  const missingSquad = teams.filter((t) => !Array.isArray(t.squad) || t.squad.length === 0);
  if (missingSquad.length) {
    console.log(`  ${missingSquad.length} teams missing squad — fetching individually…`);
    for (const t of missingSquad) {
      const detail = await fdGet(`/teams/${t.id}`);
      if (detail?.squad) t.squad = detail.squad;
      await sleep(7000);
    }
  }

  // 3. Write teams.
  const teamOps = teams.map((t) => ({
    ref:  db.collection('teams').doc(String(t.id)),
    data: teamDoc(t),
  }));
  const teamsWritten = await commitInChunks(teamOps);
  console.log(`✓ Wrote ${teamsWritten} team docs.`);

  // 4. Write players (one flat doc per player, queryable by teamId).
  const playerOps = [];
  for (const t of teams) {
    for (const p of t.squad ?? []) {
      if (!p?.id) continue;
      playerOps.push({
        ref:  db.collection('players').doc(String(p.id)),
        data: playerDoc(p, t),
      });
    }
  }
  const playersWritten = await commitInChunks(playerOps);
  console.log(`✓ Wrote ${playersWritten} player docs.`);

  // 5. Heartbeat.
  await db.collection('meta').doc('seed').set(
    {
      lastRun:      NOW(),
      lastRunIso:   startedAt.toISOString(),
      teamsCount:   teamsWritten,
      playersCount: playersWritten,
      competitions: COMPETITIONS,
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
