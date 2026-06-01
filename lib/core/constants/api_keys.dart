// lib/core/constants/api_keys.dart
//
// Central place for ALL third-party API routing config.
//
// PRODUCTION ARCHITECTURE
// ────────────────────────
// All provider secrets live in the Cloudflare Worker
// (https://football-fan-hub-proxy.footballapp.workers.dev).
// The Flutter app never holds real tokens — it just calls the Worker.
// Remote Config can override any base URL at runtime without a rebuild.
//
// LOCAL / CI DEVELOPMENT
// ───────────────────────
// Pass --dart-define=API_PROXY_BASE_URL=direct to bypass the Worker and hit
// providers directly (requires real tokens via --dart-define=FD_TOKEN=xxx etc).
//
class ApiKeys {
  // ─── Bzzoiro Sports Data (BSD) ─────────────────────────────────────────
  // Worker base — no token needed from Flutter; Worker injects BSD_TOKEN.
  // Falls back to direct BSD if Remote Config returns an empty URL.
  static const String bsdToken = String.fromEnvironment(
    'BSD_TOKEN',
    defaultValue: '', // empty in production; Worker holds the real token
  );
  static const String bsdBase = String.fromEnvironment(
    'BSD_BASE_URL',
    defaultValue:
        'https://football-fan-hub-proxy.footballapp.workers.dev/api/bsd',
  );

  // ─── football-data.org ─────────────────────────────────────────────────
  // Token only used when hitting FD directly (local dev with API_PROXY_BASE_URL=direct).
  static const String footballData = String.fromEnvironment(
    'FD_TOKEN',
    defaultValue: '',
  );

  // ─── NewsAPI.org (football news) ───────────────────────────────────────
  // Free tier: 100 req/day. App always falls back to BBC RSS on failure.
  static const String newsApi = String.fromEnvironment(
    'NEWSAPI_KEY',
    defaultValue: '',
  );

  // ─── TheSportsDB ───────────────────────────────────────────────────────
  // Public test key "123" is fine for free-tier endpoints.
  // In production the Worker proxies SDB at /api/sdb/* — no key exposed.
  static const String sportsDbKey = String.fromEnvironment(
    'SPORTSDB_KEY',
    defaultValue: '123',
  );
  static const String sportsDbBase = 'https://www.thesportsdb.com/api/v1/json';

  // ─── News fallback (always works, no key) ──────────────────────────────
  static const String bbcFootballRss =
      'https://feeds.bbci.co.uk/sport/football/rss.xml';
}
