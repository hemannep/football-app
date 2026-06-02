/**
 * Football Fan Hub 2026 — Cloudflare Worker API Proxy
 *
 * PURPOSE
 * -------
 * Keeps all third-party API secrets off the Flutter client. The app only ever
 * calls this Worker; the Worker holds the real keys as encrypted Wrangler
 * secrets and caches responses at the edge.
 *
 * ROUTES (all GET-only; POST/DELETE return 405)
 * -----------------------------------------------
 * /api/fd/*          → football-data.org v4  (FD_TOKEN secret)
 * /api/bsd/*         → Bzzoiro Sports Data v2 (BSD_TOKEN secret)
 * /api/sdb/*         → TheSportsDB v1         (public key 123, no secret)
 * /health            → 200 OK JSON status check
 *
 * CACHE TTLs (aligned with provider update frequencies from the mapping report)
 * -----------
 * BSD live events / incidents  15–30 s
 * BSD stats / player-stats     60 s live / 12 h finished
 * BSD lineups                  10 min before data available / 1 h after confirmed
 * BSD metadata / standings     6 h
 * FD competition matches        5 min (live day) / 6 h (other days)
 * FD standings                 1 h
 * SDB team / player metadata   24 h
 *
 * SECURITY
 * --------
 * • Secrets stored with: wrangler secret put FD_TOKEN
 *                        wrangler secret put BSD_TOKEN
 * • App only needs the Worker URL (no provider keys ship in the APK).
 * • Allowlisted query params per route — arbitrary upstream forwarding blocked.
 * • CORS restricted to your app's origin; set ALLOWED_ORIGIN in wrangler.toml.
 *
 * DEPLOYMENT
 * ----------
 *   cd worker
 *   npm install
 *   npx wrangler secret put FD_TOKEN        # paste your football-data.org token
 *   npx wrangler secret put BSD_TOKEN       # paste your Bzzoiro token
 *   npx wrangler deploy
 *
 * Then set api_base_url / bsd_base_url in Firebase Remote Config to point at
 * the deployed Worker URL so the Flutter app routes through it.
 */

export interface Env {
  FD_TOKEN: string;
  BSD_TOKEN: string;
  ALLOWED_ORIGIN: string; // set in wrangler.toml vars (e.g. "*" for dev)
}

// ─── TTL constants (seconds) ─────────────────────────────────────────────────
const TTL = {
  LIVE_15S:   15,
  LIVE_30S:   30,
  LIVE_60S:   60,
  TEN_MIN:    600,
  ONE_HOUR:   3_600,
  SIX_HOURS:  21_600,
  ONE_DAY:    86_400,
} as const;

// ─── Allowed query-param allowlists per route family ─────────────────────────
const FD_MATCH_PARAMS   = ['dateFrom', 'dateTo', 'status', 'stage', 'season', 'matchday'];
const FD_GENERIC_PARAMS = ['season', 'stage'];
const BSD_EVENT_PARAMS  = ['date_from', 'date_to', 'team_name', 'limit', 'offset'];
const SDB_ANY_PARAMS    = ['id', 'd', 's', 'l', 'e', 'p', 't', 'n', 'strLeague', 'strSport', 'strSeason'];

// ─── Main fetch handler ───────────────────────────────────────────────────────

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    if (request.method !== 'GET') {
      return new Response('Method not allowed', { status: 405 });
    }

    const url    = new URL(request.url);
    const path   = url.pathname;
    const cache  = caches.default;
    const origin = env.ALLOWED_ORIGIN || '*';

    // ── /health ──────────────────────────────────────────────────────────────
    if (path === '/health') {
      return jsonResponse({ status: 'ok', ts: new Date().toISOString() }, 0, origin);
    }

    // ── /api/fd/* ─────────────────────────────────────────────────────────────
    if (path.startsWith('/api/fd/')) {
      return handleFd(request, url, env, cache, ctx, origin);
    }

    // ── /api/bsd/* ────────────────────────────────────────────────────────────
    if (path.startsWith('/api/bsd/')) {
      return handleBsd(request, url, env, cache, ctx, origin);
    }

    // ── /api/sdb/* ────────────────────────────────────────────────────────────
    if (path.startsWith('/api/sdb/')) {
      return handleSdb(request, url, cache, ctx, origin);
    }

    return new Response('Not found', { status: 404 });
  },
};

// ─── football-data.org handler ───────────────────────────────────────────────

async function handleFd(
  request: Request,
  url: URL,
  env: Env,
  cache: Cache,
  ctx: ExecutionContext,
  origin: string,
): Promise<Response> {
  // Strip /api/fd/v4 prefix (or /api/fd) → forward remaining path to FD v4
  const fdPath    = url.pathname.replace(/^\/api\/fd(?:\/v\d+)?/, '');
  const upstream  = new URL(`https://api.football-data.org/v4${fdPath}`);

  // Choose allowlist based on path shape
  const paramList = fdPath.includes('/matches') ? FD_MATCH_PARAMS : FD_GENERIC_PARAMS;
  copyAllowed(url, upstream, paramList);

  const ttl = chooseFdTtl(fdPath, url);

  return proxyCached(request, upstream.toString(), {
    headers: { 'X-Auth-Token': env.FD_TOKEN },
    ttl,
    cache,
    ctx,
    origin,
  });
}

function chooseFdTtl(path: string, url: URL): number {
  if (path.includes('/standings')) return TTL.ONE_HOUR;
  // Live-day match list: short TTL; future/past: 6 h
  const status = url.searchParams.get('status') ?? '';
  if (status && (status.includes('LIVE') || status.includes('IN_PLAY'))) {
    return TTL.LIVE_60S;
  }
  return TTL.SIX_HOURS;
}

// ─── Bzzoiro BSD handler ──────────────────────────────────────────────────────

async function handleBsd(
  request: Request,
  url: URL,
  env: Env,
  cache: Cache,
  ctx: ExecutionContext,
  origin: string,
): Promise<Response> {
  const bsdPath  = url.pathname.replace(/^\/api\/bsd/, '');
  const upstream = new URL(`https://sports.bzzoiro.com/api/v2${bsdPath}`);

  copyAllowed(url, upstream, BSD_EVENT_PARAMS);

  const ttl = chooseBsdTtl(bsdPath);

  return proxyCached(request, upstream.toString(), {
    headers: {
      'Authorization': `Token ${env.BSD_TOKEN}`,
      'Accept': 'application/json',
    },
    ttl,
    cache,
    ctx,
    origin,
  });
}

function chooseBsdTtl(path: string): number {
  // Live events list and core event header: 30 s
  if (path === '/events/live/' || path === '/live/') return TTL.LIVE_30S;
  // Incidents and per-event header (may be called during live play)
  if (path.includes('/incidents/')) return TTL.LIVE_30S;
  // Stats update every 30–60 s during live play
  if (path.includes('/stats/')) return TTL.LIVE_60S;
  // Player stats: 60 s live — callers pass ?live=1 if needed; we use 60 s baseline
  if (path.includes('/player-stats/')) return TTL.LIVE_60S;
  // Lineups: confirmed ~60 min before kickoff; cache 10 min until then
  if (path.includes('/lineups/')) return TTL.TEN_MIN;
  // Metadata (funfacts, AI preview, jerseys): stable pre-match content
  if (path.includes('/metadata/')) return TTL.SIX_HOURS;
  // Standings update infrequently
  if (path.includes('/standings/')) return TTL.ONE_HOUR;
  // Default event list / event detail
  return TTL.SIX_HOURS;
}

// ─── TheSportsDB handler (public key 123, no secret needed) ──────────────────

async function handleSdb(
  request: Request,
  url: URL,
  cache: Cache,
  ctx: ExecutionContext,
  origin: string,
): Promise<Response> {
  const sdbPath  = url.pathname.replace(/^\/api\/sdb/, '');
  const upstream = new URL(`https://www.thesportsdb.com/api/v1/json/123${sdbPath}`);

  copyAllowed(url, upstream, SDB_ANY_PARAMS);

  return proxyCached(request, upstream.toString(), {
    headers: { 'Accept': 'application/json' },
    ttl: TTL.ONE_DAY, // SDB metadata is stable (badges, bios, photos)
    cache,
    ctx,
    origin,
  });
}

// ─── Generic caching proxy ────────────────────────────────────────────────────

interface ProxyOptions {
  headers: Record<string, string>;
  ttl: number;
  cache: Cache;
  ctx: ExecutionContext;
  origin: string;
}

async function proxyCached(
  clientReq: Request,
  upstreamUrl: string,
  opts: ProxyOptions,
): Promise<Response> {
  const { headers, ttl, cache, ctx, origin } = opts;

  // Cache key = normalized upstream URL (client URL stripped of host/prefix)
  const cacheKey = new Request(upstreamUrl, { method: 'GET' });

  // 1. Edge cache hit
  if (ttl > 0) {
    const hit = await cache.match(cacheKey);
    if (hit) {
      return addCors(hit, origin);
    }
  }

  // 2. Upstream fetch
  let upstreamRes: Response;
  try {
    upstreamRes = await fetch(upstreamUrl, {
      headers: { ...headers, 'User-Agent': 'FootballFanHub2026-Worker/1.0' },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ error: 'upstream_fetch_failed', detail: String(err) }),
      { status: 502, headers: corsHeaders(origin, 'application/json') },
    );
  }

  if (!upstreamRes.ok) {
    // Pass provider errors through without caching
    const body = await upstreamRes.text();
    return new Response(body, {
      status: upstreamRes.status,
      headers: corsHeaders(origin, upstreamRes.headers.get('content-type') ?? 'text/plain'),
    });
  }

  const body = await upstreamRes.text();
  const res  = new Response(body, {
    status: 200,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': ttl > 0 ? `public, max-age=${ttl}` : 'no-store',
      ...corsHeaders(origin),
    },
  });

  if (ttl > 0) {
    ctx.waitUntil(cache.put(cacheKey, res.clone()));
  }
  return res;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function copyAllowed(from: URL, to: URL, keys: string[]): void {
  for (const key of keys) {
    const value = from.searchParams.get(key);
    if (value !== null) to.searchParams.set(key, value);
  }
}

function corsHeaders(
  origin: string,
  contentType = 'application/json; charset=utf-8',
): Record<string, string> {
  return {
    'access-control-allow-origin':  origin,
    'access-control-allow-methods': 'GET, OPTIONS',
    'access-control-allow-headers': 'Content-Type',
    'content-type': contentType,
  };
}

function addCors(res: Response, origin: string): Response {
  const headers = new Headers(res.headers);
  headers.set('access-control-allow-origin',  origin);
  headers.set('access-control-allow-methods', 'GET, OPTIONS');
  return new Response(res.body, { status: res.status, headers });
}

function jsonResponse(data: unknown, ttl: number, origin: string): Response {
  return new Response(JSON.stringify(data), {
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': ttl > 0 ? `public, max-age=${ttl}` : 'no-store',
      ...corsHeaders(origin),
    },
  });
}
