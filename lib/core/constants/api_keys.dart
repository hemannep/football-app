// lib/core/constants/api_keys.dart
//
// Central place for ALL third-party API keys.
//
// ⚠️ For production, move these to --dart-define build flags so they are
//    not shipped in the APK source. Example:
//       flutter build apk --dart-define=NEWSAPI_KEY=xxxx --dart-define=RAPIDAPI_KEY=xxxx
//
class ApiKeys {
  // ─── Bzzoiro Sports Data (BSD) — match details on the free tier ────────
  // Free, no rate limits, no credit card. Provides what football-data.org's
  // free tier locks: lineups, formations, bench, incidents (goals/cards/subs),
  // and match statistics. Used ONLY for the match-details screen. We resolve
  // an fd.org match → BSD event by (date, team names) in BsdService.
  // Register at https://sports.bzzoiro.com/register/ to get your token.
  static const String bsdToken = String.fromEnvironment(
    'BSD_TOKEN',
    defaultValue: 'PASTE_YOUR_BSD_TOKEN_HERE',
  );
  static const String bsdBase = 'https://sports.bzzoiro.com/api/v2';

  // ─── football-data.org (already used by ApiService) ────────────────────
  // Keep this as the authoritative source for fixtures / scores / standings.
  static const String footballData = String.fromEnvironment(
    'FD_TOKEN',
    defaultValue: 'b6fa0db6e10b4f7ea64ca5e52cc806a4',
  );

  // ─── NewsAPI.org (football news) ───────────────────────────────────────
  // Free tier: 100 req/day, developer-only. We always fall back to BBC RSS
  // when this fails / 429s / is blocked from a production device.
  static const String newsApi = String.fromEnvironment(
    'NEWSAPI_KEY',
    defaultValue: 'acfe84cf39964c8abb98f003c609b507',
  );

  // ─── RapidAPI — sportapi7 (SofaScore wrapper) ──────────────────────────
  // Used ONLY for match-detail enrichment: lineups, incidents, statistics.
  // The host echoes SofaScore IDs, so we resolve fd.org match → SofaScore
  // event-id by (date, home, away) inside MatchExtrasService.
  static const String rapidApiKey = String.fromEnvironment(
    'RAPIDAPI_KEY',
    defaultValue: '19c6cc6445msh0b3d88bdd13ce06p143949jsna58f033979cd',
  );
  static const String rapidApiHost = 'sportapi7.p.rapidapi.com';

  // ─── TheSportsDB (team badge, anthem, players, photos) ─────────────────
  // Key "123" is the official public test key — fine for free-tier endpoints.
  static const String sportsDbKey = String.fromEnvironment(
    'SPORTSDB_KEY',
    defaultValue: '123',
  );
  static const String sportsDbBase = 'https://www.thesportsdb.com/api/v1/json';

  // ─── News fallback (always works, no key) ──────────────────────────────
  static const String bbcFootballRss =
      'https://feeds.bbci.co.uk/sport/football/rss.xml';
}
