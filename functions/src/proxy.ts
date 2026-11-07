import { TtlCache } from './cache.js';
import { RateLimiter } from './rate_limit.js';
import { BadRequest, deezerUpstream, lastFmUpstream, type Upstream } from './upstreams.js';

/** A request as the proxy sees it, whatever the HTTP framework. */
export interface ProxyRequest {
  method: string;
  /** The path after the function's name: /lastfm or /deezer/artist/27. */
  path: string;
  query: Record<string, string>;
  headers: Record<string, string | undefined>;
  ip: string;
}

export interface ProxyResponse {
  status: number;
  headers: Record<string, string>;
  body: string;
}

export interface ProxyDeps {
  fetch: (url: string) => Promise<{ status: number; text: () => Promise<string> }>;
  lastFmKey: () => string;
  /** The app's App Check token, verified; null when missing or invalid. */
  verifyAppCheck: (token: string | undefined) => Promise<string | null>;
  /** Refuse requests without a valid App Check token. */
  enforceAppCheck: () => boolean;
  cache: TtlCache<{ status: number; body: string }>;
  lastFmLimiter: RateLimiter;
  deezerLimiter: RateLimiter;
}

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'X-Firebase-AppCheck, Content-Type',
  'Access-Control-Max-Age': '3600',
};

function json(status: number, body: unknown, extra: Record<string, string> = {}): ProxyResponse {
  return {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8', ...extra },
    body: JSON.stringify(body),
  };
}

/**
 * The proxy: checks the caller (App Check), its rate, and that the request
 * is one the app makes; answers from the cache or asks Last.fm (with the
 * server's key) or Deezer. Upstream failures are passed on, never cached.
 */
export async function handleProxy(req: ProxyRequest, deps: ProxyDeps): Promise<ProxyResponse> {
  if (req.method === 'OPTIONS') return { status: 204, headers: CORS, body: '' };
  if (req.method !== 'GET') return json(405, { error: 'method not allowed' });

  const segments = req.path.replace(/^\/+/, '').split('/');
  const service = segments.shift();
  if (service !== 'lastfm' && service !== 'deezer') return json(404, { error: 'not found' });

  const appId = await deps.verifyAppCheck(req.headers['x-firebase-appcheck']);
  if (!appId && deps.enforceAppCheck()) return json(401, { error: 'app check required' });

  // A verified app is limited per installation-agnostic app id plus IP;
  // anyone else per IP.
  const caller = `${appId ?? 'anon'}:${req.ip}`;
  const limiter = service === 'lastfm' ? deps.lastFmLimiter : deps.deezerLimiter;
  if (!limiter.allow(caller)) {
    return json(429, { error: 'too many requests' }, { 'Retry-After': '30' });
  }

  let upstream: Upstream;
  try {
    upstream =
      service === 'lastfm'
        ? lastFmUpstream(req.query, deps.lastFmKey())
        : deezerUpstream(segments.join('/'), req.query);
  } catch (e) {
    if (e instanceof BadRequest) return json(400, { error: e.message });
    throw e;
  }

  // The cache key never includes the key itself.
  const cacheKey = upstream.url.replace(/([?&])api_key=[^&]*/, '$1');
  const cached = deps.cache.get(cacheKey);
  const cacheHeaders = { 'Cache-Control': `public, max-age=${upstream.ttlSeconds}` };
  if (cached) {
    return {
      status: cached.status,
      headers: { ...CORS, ...cacheHeaders, 'Content-Type': 'application/json; charset=utf-8', 'X-Cache': 'HIT' },
      body: cached.body,
    };
  }

  let status: number;
  let body: string;
  try {
    const res = await deps.fetch(upstream.url);
    status = res.status;
    body = await res.text();
  } catch {
    return json(502, { error: 'upstream unreachable' });
  }

  // Only good answers are kept: both services report some errors with a
  // 200 and an "error" field.
  const isError = status !== 200 || /^\s*\{\s*"error"/.test(body);
  if (!isError) deps.cache.set(cacheKey, { status, body }, upstream.ttlSeconds);
  return {
    status,
    headers: {
      ...CORS,
      ...(isError ? { 'Cache-Control': 'no-store' } : cacheHeaders),
      'Content-Type': 'application/json; charset=utf-8',
      'X-Cache': 'MISS',
    },
    body,
  };
}
