# Football Fan Hub 2026 — Claude Context

Continue here when context runs out. Last updated: 2026-05-31.

---

## App overview

Flutter app for tracking international football (WC 2026 + 11 other leagues).
Repo: `hemannep/football-app` (GitHub). Local path: `~/Downloads/football_fan_hub_2026`.

**Play Store safety rules (NEVER break):**
- Never use "FIFA", "World Cup", or "Mundial" in any string visible to users.
- Use "International Football 2026", "WC26", or "Football 2026" instead.

---

## Architecture

```
football-data.org API  ──►  relay.js (GitHub Actions, every 5 min)  ──►  Firestore
Bzzoiro API            ──►  bzzoiro_enricher.js (after relay)        ──►  Firestore
RSS feeds              ──►  news_worker.js (every hour)              ──►  Firestore
football-data.org API  ──►  seed_static_data.js (daily)             ──►  Firestore
                                                                          │
                                                                          ▼
                                                                    Flutter app
                                                                  (reads only Firestore)
```

### Firestore collections
| Collection | Key | Written by | Read by |
|---|---|---|---|
| `matches/{fdId}` | football-data.org match ID | relay.js + bzzoiro_enricher.js | LiveDataService |
| `standings/{comp}_{group}` | e.g. `WC_GROUP_A`, `PL_TOTAL` | relay.js | LiveDataService |
| `teams/{teamId}` | football-data.org team ID | seed_static_data.js | LiveDataService |
| `players/{playerId}` | football-data.org player ID | seed_static_data.js | LiveDataService |
| `news/{id}` | auto | news_worker.js | LiveDataService |
| `meta/relay` | fixed | relay.js | LiveDataService |
| `lineups/{matchId}` | football-data.org match ID | relay.js (API-Football) | NOT read by app |

### match doc fields (from Firestore)
Core (relay.js): `id`, `status`, `utcDate`, `homeTeam`, `awayTeam`, `score`, `stage`, `group`, `competition.code`, `competition.name`, `goals`, `bookings`, `substitutions`, `minute`

Bzzoiro enrichment: `bzzLineups`, `bzzPredictedFormation`, `incidents`, `liveStats`, `xg`, `shotmap`, `momentum`, `referee`, `unavailablePlayers`, `penaltyShootout`

API-Football (post-match fallback): `confirmedLineup`

### standings doc fields
`group` (e.g. "GROUP_A"), `competitionCode` (e.g. "WC"), `table: List<TeamStanding>`

---

## Supported competitions

```
['WC', 'CL', 'EC', 'PL', 'PD', 'BL1', 'SA', 'FL1', 'DED', 'PPL', 'ELC', 'BSA']
```
Defined in `lib/shared/models/leagues.dart` as `Leagues.all`.

---

## Frozen files (treat models as effectively frozen)

- `lib/shared/models/match.dart` — Match, TeamRef, Score, MatchGoal — has `minute: int?` field (relay-supplied)
- `lib/shared/models/standing.dart` — GroupTable, TeamStanding

**Match model key fields:**
- `competitionCode` / `competitionName` — from `competition.code` / `competition.name`
- `minute: int?` — live match minute from relay.js (field added)
- `isLive` → `status == 'IN_PLAY' || status == 'PAUSED'`
- `isFinished` → `status == 'FINISHED'`
- `isScheduled` → `status == 'SCHEDULED' || status == 'TIMED'`
- `goals: List<MatchGoal>` — each has `minute`, `scorerName`, `teamId`, `type`

---

## Flutter constraints

- **Riverpod only** — use providers from `live_data_service.dart`; never call `LiveDataService.instance` from widgets directly
- **No new dependencies** except `url_launcher` and `cached_network_image`
- **Null-safe** — use `?.` and `??` everywhere, never `!` on Firestore values
- **Loading/error/empty states** mandatory on every screen with async providers
- **Stat bar standard**: 8px height throughout the app

---

## Firestore read budget (as of 2026-05-31)

**Before:** ~8 000+ reads/session — `collection.snapshots()` on full collections,
plus 4 separate listeners all calling `watchMatches()` independently.

**After:** ≤ 3 reads/warm session (in-memory TTL cache + meta-freshness checks).

| Scenario | Reads |
|---|---|
| Warm session (cache ≤ 5 min old) | 1 (meta check) |
| Cold session / first open | ~1 091 (meta + matches + standings + news) |
| Live match detail view | 1/relay-push (single-doc snapshot, intentional) |

### Cache strategy
Three layers, cheapest first:
1. **In-memory** (`LiveDataService._mem`) — per-process, zero cost. TTLs: matches 5 min, standings 15 min, news 30 min, teams/players 24 h, lineups 20 min, meta 2 min.
2. **Hive** (`live_cache` box) — persists across restarts. Only served when relay hasn't run since last fill (`_hiveIsFresh(key, meta)`).
3. **Firestore `get()`** — called only when both caches are stale/absent.

`watchMatches()`, `watchStandings()`, `watchStandingsByLeague()`, `watchNews()` are now **`async*` generators** that yield once from cache immediately, then re-check at the TTL interval. No persistent `collection.snapshots()` listeners.

`watchMatch()` and `watchMatchRaw()` retain single-doc `snapshots()` for live match detail — justified at 1 read/relay-push.

### Shared cache across callers
`LiveDataService` is a singleton. All callers that call `getMatches()` or `watchMatches()` hit the same `_mem['matches_all']` entry. The old pattern of each screen opening a separate Firestore listener is eliminated:
- `team_comparison_screen.dart` — uses `getMatches()` directly
- `ai_insights_widget.dart` — uses `getMatches()` directly
- `team_details_screen.dart` — uses `watchMatches()` (shares cache)

---

## Key providers (lib/core/services/live_data_service.dart)

```dart
matchesStreamProvider          // TTL-aware stream (5 min) — all matches
standingsStreamProvider        // TTL-aware stream (15 min) — all standings
standingsByLeagueProvider(code)// TTL-aware stream (15 min) — filtered by code
matchStreamProvider(id)        // Single-doc snapshot — live match updates
watchMatchRaw(id)              // Single-doc snapshot — raw Firestore doc (details screen)
relayMetaProvider              // FutureProvider — 2-min memory TTL
teamProvider(id)               // FutureProvider — 24-hour TTL
playerProvider(id)             // FutureProvider — 24-hour TTL
playersForTeamProvider(id)     // FutureProvider — 24-hour TTL
newsStreamProvider             // TTL-aware stream (30 min)
lineupProvider(id)             // FutureProvider — 20-min TTL, lineups/{matchId} collection
```

`RelayMeta.freshnessLabel` → "Updated X min ago" string for UI.

### LiveScoreNotifier (lib/core/providers/live_score_provider.dart)
Wraps `matchesStreamProvider`, filters by `selectedLeagueProvider.code` client-side.
Used by Home and Fixtures screens via `ref.watch(liveScoreProvider)`.

### selectedLeagueProvider
Persisted to Hive. Default: `'WC'`. Changed by `LeaguePickerChip`.

### myStatsProvider (lib/core/providers/prediction_provider.dart)
Returns record: `(points, submitted, settled, exactScores, correctResults)`.
- `exactScores` = count where settled && pointsEarned == 5
- `correctResults` = count where settled && pointsEarned == 3
- Accuracy displayed in predictor as `(exactScores + correctResults) / settled * 100`%

---

## Match detail screen (part file system)

`lib/features/match details/match_details_screen.dart` is the library root.
Part files (all in same folder):
- `summary_tab.dart` — goalscorers, xG bar, referee, incidents
- `lineups_tab.dart` — pitch view with player chips, sub-tabs (Lineup/Subs/Injuries/Suspensions)
- `stats_tab.dart` — possession bar, stat rows, momentum
- `standings_tab.dart` — mini group table for match's group
- `h2h_tab.dart` — H2H analytics card, W/D/L bar, historical meetings
- `match_details_shared.dart` — shared helpers (_DetailCard, _SectionLabel, etc.)

The `_rawMatchProvider` is a **StreamProvider** using `watchMatchRaw()` — the screen auto-refreshes when Firestore updates.

The match detail hero shows:
- Live: `"LIVE · 2H · 67'"` with pulsing dot (half + minute)
- Paused: `"Half-Time"` chip
- Finished: `"Full Time"` / `"After Extra Time"` / `"After Penalties"` + date
- Scheduled: countdown `"Kicks off in 3d 4h"` or `"Kicks off in 45m"`

---

## AppTheme

```dart
AppTheme.of(context)  // returns Palette
AppTheme.brand        // static Color (yellow-green)
AppTheme.live         // static Color (red)
AppTheme.warn         // static Color (amber)
AppTheme.good         // static Color (green)
AppTheme.bad          // static Color (red-dark)
AppTheme.liveGradient // LinearGradient (red)
AppTheme.brandGradient// LinearGradient
const double r = 16   // AppTheme.r — standard border radius
```

`Palette` (instance): `p.bg`, `p.surface`, `p.surfaceHi`, `p.stroke`, `p.textHi`, `p.textMid`, `p.textLow`, `p.heroGradient`

---

## Widgets

- `FlagWidget(tla: 'BRA', size: 32)` — country flag from flagcdn.com
- `nationalityToTla(String? nationality)` — in flag_widget.dart, converts "France" → "FRA"
- `TeamCrestWidget(crestUrl, tla, name, size)` — team badge
- `MatchCard(match, onTap, showDate)` — compact match row with GOAL! badge on live cards
- `PitchBackground` — CustomPainter (lib/shared/widgets/pitch_painter.dart)
- `formationPositions({formation, isHome, playerCount})` — returns `List<Offset>` for pitch layout
- `AdBannerWidget` — banner ad at bottom of screens
- `SectionLabel` (exported from predictor_screen.dart) — used by team_details_screen for section headers

---

## GitHub Actions workflows

Location: `.github/workflows/` (PLURAL — GitHub requires this)
Old broken location `.github/workflow/` (singular) also exists but is ignored by GitHub.

| File | Schedule | Does |
|---|---|---|
| `fetch_match_data.yml` | Every 5 min | relay.js + bzzoiro_enricher.js |
| `seed_static_data.yml` | Daily 04:00 UTC | seed_static_data.js |
| `news_worker.yml` | Every hour :15 | news_worker.js |

All use `node-version: '24'` and `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true` (opt into Node 24 for action runners).
Relay timeout: 10 min. Seed timeout: 30 min.

**Required GitHub Secrets:** `FD_TOKEN`, `FIREBASE_SA`, `BZZOIRO_TOKEN`, `APIFOOTBALL_KEY`

---

## relay.js key design decisions

**Smart diff:** Only writes a match doc when `status` or `score` changed since last run.
- Cuts Firestore writes from 3,644/run to ~0 on quiet days.
- Firestore Spark free tier: 20,000 writes/day — must stay under this.
- State tracked in `meta/relay.matchStates: {matchId: {s, h, a}}`.

**Standings optimization (2026-05-31):** Phase 3 only writes standings for competitions
that have live matches (`liveCompCodes` set). Full 12-comp refresh only at top of hour
(`now.getUTCMinutes() < 5`). Saves up to 11× write quota during match windows.

**Graceful quota exit:** `RESOURCE_EXHAUSTED` (gRPC code 8) → logs warning + `process.exit(0)`.
GitHub Actions stays green; data catches up on the next 5-min run.

**AbortController:** 30s timeout on every HTTP call. Prevents one slow API from stalling the relay.

**Rate limiting:** 6.5s sleep between football-data.org calls (limit: 10/min).

**Phase 5 guard:** `detectNewlyFinished` only processes matches that kicked off within 4 hours.

---

## news_worker.js key design decisions

**Time-based prune (2026-05-31):** Old `offset(150)` query was charging Firestore reads for
every doc before the offset position — burning 7,200+ reads/day on a 300-article collection.
Replaced with `where('publishedAtMs', '<', cutoffMs)` (7 days), which only reads genuinely
old articles (typically zero per run since RSS feeds don't carry 7-day-old content).

**Graceful quota exit:** Same as relay.js — RESOURCE_EXHAUSTED → exit 0.

---

## SportsDbPlayer (lib/core/services/sportsdb_service.dart)

Fields: `playerId`, `name`, `position`, `nationality`, `team`, `photoUrl`, `thumbUrl`,
`description`, `birthYear`, `birthDate` (full ISO string from `dateBorn`), `height`, `weight`, `wage`.

`birthDate` added 2026-05-31 — stores full `dateBorn` string so player screen can show
"15 Jun 1993 · 32 yrs" instead of just "32 yrs".

---

## Player details screen (lib/features/player screen/player_details_screen.dart)

PROFILE section row order: Nationality → Position → Club → Born → Height → Weight → Shirt → Market Value.

- `Born` shows full date when available: `"15 Jun 1993 · 32 yrs"` (Firestore) or `"32 yrs (1993)"` (SportsDB year-only)
- `Market Value` = `sdbPlayer.wage` if non-empty
- Nationality is a plain text row (no separate FlagWidget row) — `_NationalityInfoRow` removed

---

## Predictor screen (lib/features/predictor/predictor_screen.dart)

- `_StatsCard` accepts `correctResults` param; shows `"XX% accuracy"` in brand green below pts (hidden if no settled predictions)
- Community bar height: 8px (standardised, was 10px)

---

## Team details screen (lib/features/team details/team_details_screen.dart)

Body section order: LIVE NOW → NEXT MATCH spotlight → FORM → STATS → STANDING → UPCOMING → SQUAD → CLUB INFO.

`_MiniStandingsCard` (lines 897–1034): shows 5-row mini league table centred on team's position.
Uses `teamGroup` + `tla` + `p` (Palette). Shows GD in green/red, pts bold, team row highlighted.

`_teamMatchesProvider` is a **StreamProvider** for live updates.

Stats: hidden when `playedCount == 0`. Home/Away win-rate bars. 8px stat bars throughout.

---

## Bracket screen (lib/features/bracket/bracket_screen.dart)

`_autoFill()` now filters matches by `selectedLeagueProvider.code` so auto-fill only uses
teams from the currently-selected competition. Shows snackbar if no teams found.
Resets downstream rounds (R16/QF/SF/F/champion) when teams change.

---

## Known issues / limitations

- **API-Football lineup IDs**: `relay.js` queries `/fixtures?id={fdId}` using football-data.org IDs.
  API-Football uses its own ID system → calls usually return nothing. `lineupProvider` reads the
  `lineups/{matchId}` collection as a fallback but it's also sparse. Primary source is Bzzoiro `bzzLineups`.
- **Lineups priority**: bzzLineups → confirmedLineup (match doc) → lineups collection → bzzPredictedLineup → empty pitch.
  Empty pitch shows actual kickoff countdown ("Lineup arrives ~1h before kick-off (in Xh)").
- **Historic match details** (goals/cards for past matches): Not fetched. Only live and recently finished
  matches get per-match detail. Past season matches show scores only, no event timeline.
- **Bzzoiro enrichment window**: Only enriches matches within 24h of kickoff + live.
- **Firestore Spark free tier**: 50k reads/day, 20k writes/day. With TTL caching, warm sessions cost
  ~3 reads. relay.js and news_worker.js exit cleanly (code 0) on RESOURCE_EXHAUSTED so CI stays green.

---

## Recent changes (2026-05-31 session)

**Scripts:**
- `relay.js`: standings only write for comps with live matches during windows (not all 12); graceful RESOURCE_EXHAUSTED exit
- `news_worker.js`: offset() → where('publishedAtMs', '<', cutoff) prune; graceful RESOURCE_EXHAUSTED exit
- All 3 workflow files: `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true` added

**Flutter:**
- `sportsdb_service.dart`: `SportsDbPlayer.birthDate: String?` field added
- `player_details_screen.dart`: nationality/wage/DOB improvements; `_NationalityInfoRow` removed
- `prediction_provider.dart`: `correctResults` in myStatsProvider record
- `predictor_screen.dart`: accuracy % display, community bar 8px
- `bracket_screen.dart`: `_autoFill` filters by selected league + snackbar + resets downstream rounds
- `_MiniStandingsCard` widget confirmed complete (was suspected incomplete — it was fine)
- `flutter analyze lib/` → No issues found

## What still needs to be done (if user asks)

- Push changes to GitHub so the fixed workflows run
- Verify relay runs successfully end-to-end after the fixes
- Manually trigger "Seed Static Data" workflow after relay succeeds (seeds teams + players)
- Test app: switch leagues in LeaguePickerChip, verify PL/BL1/etc. match data appears
- Player details screen: consider adding player stats section (appearances, goals, assists) once seed_static_data.js stores them
- Home extras `WelcomeBackRecap`: currently shows TLA text for finished matches — could add crests for richer look
