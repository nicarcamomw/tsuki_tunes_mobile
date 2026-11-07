import { describe, expect, it } from 'vitest';

import { TtlCache } from '../src/cache.js';
import { handleProxy, type ProxyDeps, type ProxyRequest } from '../src/proxy.js';
import { RateLimiter } from '../src/rate_limit.js';
import { BadRequest, deezerUpstream, lastFmUpstream } from '../src/upstreams.js';

function deps(overrides: Partial<ProxyDeps> = {}) {
  const calls: string[] = [];
  const base: ProxyDeps = {
    fetch: async (url) => {
      calls.push(url);
      return { status: 200, text: async () => '{"ok":true}' };
    },
    lastFmKey: () => 'SECRET',
    verifyAppCheck: async (t) => (t === 'good' ? 'app-1' : null),
    enforceAppCheck: () => false,
    cache: new TtlCache(100),
    lastFmLimiter: new RateLimiter(100, 100),
    deezerLimiter: new RateLimiter(100, 100),
    ...overrides,
  };
  return { deps: base, calls };
}

function req(path: string, query: Record<string, string> = {}, extra: Partial<ProxyRequest> = {}): ProxyRequest {
  return { method: 'GET', path, query, headers: {}, ip: '1.2.3.4', ...extra };
}

describe('Last.fm', () => {
  it('adds the server key and asks for JSON', () => {
    const up = lastFmUpstream({ method: 'track.getSimilar', artist: 'Deftones', track: 'Change', limit: '60' }, 'K');
    const url = new URL(up.url);
    expect(url.host).toBe('ws.audioscrobbler.com');
    expect(url.searchParams.get('method')).toBe('track.getsimilar');
    expect(url.searchParams.get('api_key')).toBe('K');
    expect(url.searchParams.get('format')).toBe('json');
    expect(url.searchParams.get('artist')).toBe('Deftones');
  });

  it('refuses other methods, unknown parameters and a key from the caller', () => {
    expect(() => lastFmUpstream({ method: 'user.getinfo', user: 'x' }, 'K')).toThrow(BadRequest);
    expect(() => lastFmUpstream({ method: 'artist.getinfo', artist: 'a', user: 'x' }, 'K')).toThrow(BadRequest);
    expect(() => lastFmUpstream({ method: 'artist.search', artist: 'a', api_key: 'mine' }, 'K')).toThrow(BadRequest);
    expect(() => lastFmUpstream({ method: 'artist.search', artist: 'a', limit: 'lots' }, 'K')).toThrow(BadRequest);
    expect(() => lastFmUpstream({ method: 'artist.search', artist: 'x'.repeat(301) }, 'K')).toThrow(BadRequest);
  });
});

describe('Deezer', () => {
  it('passes the paths and parameters the app reads', () => {
    expect(deezerUpstream('search/artist', { q: 'korn', limit: '25' }).url).toBe(
      'https://api.deezer.com/search/artist?q=korn&limit=25',
    );
    expect(deezerUpstream('/artist/27/top/', { limit: '50' }).url).toBe('https://api.deezer.com/artist/27/top?limit=50');
    expect(deezerUpstream('chart/0/tracks', {}).ttlSeconds).toBe(3600);
    expect(deezerUpstream('genre', {}).url).toBe('https://api.deezer.com/genre');
  });

  it('refuses anything else', () => {
    expect(() => deezerUpstream('user/me', {})).toThrow(BadRequest);
    expect(() => deezerUpstream('artist/abc', {})).toThrow(BadRequest);
    expect(() => deezerUpstream('search', { access_token: 'x' })).toThrow(BadRequest);
    expect(() => deezerUpstream('search', { limit: '-1' })).toThrow(BadRequest);
    expect(() => deezerUpstream('../etc', {})).toThrow(BadRequest);
  });
});

describe('the proxy', () => {
  it('answers Last.fm with the server key and caches the answer', async () => {
    const { deps: d, calls } = deps();
    const r = req('/lastfm', { method: 'artist.getinfo', artist: 'Korn' });
    const first = await handleProxy(r, d);
    const second = await handleProxy(r, d);
    expect(first.status).toBe(200);
    expect(first.headers['X-Cache']).toBe('MISS');
    expect(second.headers['X-Cache']).toBe('HIT');
    expect(calls).toHaveLength(1);
    expect(calls[0]).toContain('api_key=SECRET');
    expect(second.body).not.toContain('SECRET');
  });

  it('proxies Deezer with CORS for the web', async () => {
    const { deps: d, calls } = deps();
    const out = await handleProxy(req('/deezer/album/302127'), d);
    expect(out.status).toBe(200);
    expect(out.headers['Access-Control-Allow-Origin']).toBe('*');
    expect(calls).toEqual(['https://api.deezer.com/album/302127']);
  });

  it('answers the browser preflight and refuses other methods and services', async () => {
    const { deps: d } = deps();
    expect((await handleProxy(req('/deezer/genre', {}, { method: 'OPTIONS' }), d)).status).toBe(204);
    expect((await handleProxy(req('/deezer/genre', {}, { method: 'POST' }), d)).status).toBe(405);
    expect((await handleProxy(req('/spotify/me'), d)).status).toBe(404);
    expect((await handleProxy(req('/lastfm', { method: 'user.getinfo' }), d)).status).toBe(400);
  });

  it('never caches errors, even the ones that come with a 200', async () => {
    let n = 0;
    const { deps: d } = deps({
      fetch: async () => {
        n++;
        return { status: 200, text: async () => '{"error":{"code":4}}' };
      },
    });
    await handleProxy(req('/deezer/track/1'), d);
    const again = await handleProxy(req('/deezer/track/1'), d);
    expect(n).toBe(2);
    expect(again.headers['Cache-Control']).toBe('no-store');
  });

  it('reports an unreachable upstream as 502', async () => {
    const { deps: d } = deps({
      fetch: async () => {
        throw new Error('offline');
      },
    });
    expect((await handleProxy(req('/deezer/genre'), d)).status).toBe(502);
  });

  it('rate-limits each caller on its own', async () => {
    const { deps: d } = deps({ deezerLimiter: new RateLimiter(2, 0) });
    expect((await handleProxy(req('/deezer/genre'), d)).status).toBe(200);
    expect((await handleProxy(req('/deezer/genre'), d)).status).toBe(200);
    const third = await handleProxy(req('/deezer/genre'), d);
    expect(third.status).toBe(429);
    expect(third.headers['Retry-After']).toBe('30');
    expect((await handleProxy(req('/deezer/genre', {}, { ip: '5.6.7.8' }), d)).status).toBe(200);
  });

  it('with App Check enforced, refuses callers without a valid token', async () => {
    const { deps: d } = deps({ enforceAppCheck: () => true });
    expect((await handleProxy(req('/deezer/genre'), d)).status).toBe(401);
    const bad = req('/deezer/genre', {}, { headers: { 'x-firebase-appcheck': 'forged' } });
    expect((await handleProxy(bad, d)).status).toBe(401);
    const good = req('/deezer/genre', {}, { headers: { 'x-firebase-appcheck': 'good' } });
    expect((await handleProxy(good, d)).status).toBe(200);
  });
});

describe('cache and limiter', () => {
  it('entries expire and the oldest go first', () => {
    let now = 0;
    const cache = new TtlCache<number>(2, () => now);
    cache.set('a', 1, 10);
    cache.set('b', 2, 10);
    cache.get('a');
    cache.set('c', 3, 10);
    expect(cache.get('b')).toBeUndefined();
    expect(cache.get('a')).toBe(1);
    now = 11000;
    expect(cache.get('a')).toBeUndefined();
  });

  it('the bucket refills over time', () => {
    let now = 0;
    const limiter = new RateLimiter(1, 60, () => now);
    expect(limiter.allow('x')).toBe(true);
    expect(limiter.allow('x')).toBe(false);
    now = 1000;
    expect(limiter.allow('x')).toBe(true);
  });
});
