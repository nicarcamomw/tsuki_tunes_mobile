import { initializeApp } from 'firebase-admin/app';
import { getAppCheck } from 'firebase-admin/app-check';
import { logger } from 'firebase-functions';
import { defineBoolean, defineSecret } from 'firebase-functions/params';
import { onRequest } from 'firebase-functions/v2/https';

import { TtlCache } from './cache.js';
import { handleProxy } from './proxy.js';
import { RateLimiter } from './rate_limit.js';

initializeApp();

/** Last.fm's key: in Secret Manager, never in the app. */
const lastFmKey = defineSecret('LASTFM_API_KEY');

/**
 * Refuse callers without a valid App Check token. Off until the app is in
 * Google Play (installs from GitHub can't pass Play Integrity); turn it on
 * together with Firestore's enforcement. Its value is in functions/.env (a
 * CI deploy is non-interactive and cannot ask for it).
 */
const enforceAppCheck = defineBoolean('ENFORCE_APP_CHECK', { default: false });

// Per instance; see TtlCache and RateLimiter.
const cache = new TtlCache<{ status: number; body: string }>(2000);
// Last.fm: song radio, tags and "did you mean", a few a minute per user.
const lastFmLimiter = new RateLimiter(30, 60);
// Deezer: searches as you type and pages, many more.
const deezerLimiter = new RateLimiter(120, 300);

/**
 * https://us-central1-<project>.cloudfunctions.net/api/lastfm?method=...
 * https://us-central1-<project>.cloudfunctions.net/api/deezer/<path>?...
 */
export const api = onRequest(
  {
    region: 'us-central1',
    secrets: [lastFmKey],
    // Few instances: caps the cost of a flood and keeps the per-instance
    // cache and rate limits meaningful.
    maxInstances: 5,
    concurrency: 80,
    memory: '256MiB',
    timeoutSeconds: 20,
    invoker: 'public',
  },
  async (req, res) => {
    const query: Record<string, string> = {};
    for (const [key, value] of Object.entries(req.query)) {
      if (typeof value === 'string') query[key] = value;
    }
    try {
      const out = await handleProxy(
        {
          method: req.method,
          path: req.path,
          query,
          headers: {
            'x-firebase-appcheck': req.header('X-Firebase-AppCheck') ?? undefined,
          },
          // Behind Google's front end the client is the first address of
          // X-Forwarded-For, not the connection's.
          ip: req.header('X-Forwarded-For')?.split(',')[0]?.trim() || req.ip || 'unknown',
        },
        {
          fetch: (url) =>
            fetch(url, {
              headers: { 'User-Agent': 'TsukiTunes/1.0 (+https://github.com/nicarcamomw/tsuki_tunes_mobile)' },
              signal: AbortSignal.timeout(10000),
            }),
          lastFmKey: () => lastFmKey.value(),
          verifyAppCheck: async (token) => {
            if (!token) return null;
            try {
              return (await getAppCheck().verifyToken(token)).appId;
            } catch {
              return null;
            }
          },
          enforceAppCheck: () => enforceAppCheck.value(),
          cache,
          lastFmLimiter,
          deezerLimiter,
        },
      );
      res.status(out.status).set(out.headers).send(out.body);
    } catch (e) {
      logger.error('proxy error', e);
      res.status(500).set('Access-Control-Allow-Origin', '*').json({ error: 'internal' });
    }
  },
);
