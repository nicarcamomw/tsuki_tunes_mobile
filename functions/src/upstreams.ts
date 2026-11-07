/**
 * What the proxy may ask Last.fm and Deezer for. Anything else is refused,
 * so the proxy can't be used as a free general-purpose Last.fm key or an
 * open relay.
 */

export class BadRequest extends Error {}

/** How long an answer stays good, in seconds. */
export interface Upstream {
  url: string;
  ttlSeconds: number;
}

const HOUR = 3600;
const DAY = 24 * HOUR;

/** Last.fm methods the app uses, with the parameters each may carry. */
const LASTFM_METHODS: Record<string, { params: string[]; ttlSeconds: number }> = {
  // Song radio: songs Last.fm listeners play alongside one.
  'track.getsimilar': { params: ['artist', 'track', 'autocorrect', 'limit'], ttlSeconds: DAY },
  // An artist's style tags.
  'artist.getinfo': { params: ['artist', 'lang', 'autocorrect'], ttlSeconds: DAY },
  // "Did you mean": its search forgives typos.
  'artist.search': { params: ['artist', 'limit'], ttlSeconds: 6 * HOUR },
};

const MAX_VALUE_LENGTH = 300;

function cleanValue(key: string, value: string): string {
  const v = value.trim();
  if (!v) throw new BadRequest(`empty ${key}`);
  if (v.length > MAX_VALUE_LENGTH) throw new BadRequest(`${key} too long`);
  if (key === 'limit' && !/^\d{1,3}$/.test(v)) throw new BadRequest('bad limit');
  if (key === 'autocorrect' && v !== '0' && v !== '1') throw new BadRequest('bad autocorrect');
  return v;
}

/**
 * The Last.fm request for the app's [query] (method plus its parameters),
 * with the server's [apiKey]. Throws [BadRequest] for any method or
 * parameter the app doesn't use.
 */
export function lastFmUpstream(query: Record<string, string>, apiKey: string): Upstream {
  const method = (query.method ?? '').toLowerCase();
  const spec = LASTFM_METHODS[method];
  if (!spec) throw new BadRequest('method not allowed');

  const url = new URL('https://ws.audioscrobbler.com/2.0/');
  url.searchParams.set('method', method);
  for (const [key, value] of Object.entries(query)) {
    if (key === 'method' || key === 'format') continue;
    if (key === 'api_key') throw new BadRequest('the key is the server\'s');
    if (!spec.params.includes(key)) throw new BadRequest(`parameter not allowed: ${key}`);
    url.searchParams.set(key, cleanValue(key, value));
  }
  url.searchParams.set('api_key', apiKey);
  url.searchParams.set('format', 'json');
  return { url: url.toString(), ttlSeconds: spec.ttlSeconds };
}

/** Deezer paths the app reads, each with how long its answer is kept. */
const DEEZER_PATHS: Array<{ pattern: RegExp; ttlSeconds: number }> = [
  { pattern: /^search(\/(artist|album|track))?$/, ttlSeconds: 2 * HOUR },
  { pattern: /^artist\/\d+$/, ttlSeconds: DAY },
  { pattern: /^artist\/\d+\/(top|albums|related|radio)$/, ttlSeconds: 6 * HOUR },
  { pattern: /^album\/\d+$/, ttlSeconds: DAY },
  { pattern: /^track\/\d+$/, ttlSeconds: DAY },
  { pattern: /^chart\/\d+\/(tracks|artists|albums)$/, ttlSeconds: HOUR },
  { pattern: /^genre$/, ttlSeconds: DAY },
  { pattern: /^genre\/\d+\/artists$/, ttlSeconds: 6 * HOUR },
];

const DEEZER_QUERY_KEYS = ['q', 'limit', 'index', 'type', 'strict', 'order'];

/**
 * The Deezer request for [path] (as in api.deezer.com/{path}) and its
 * [query]. Throws [BadRequest] for anything the app doesn't read.
 */
export function deezerUpstream(path: string, query: Record<string, string>): Upstream {
  const clean = path.replace(/^\/+|\/+$/g, '');
  const match = DEEZER_PATHS.find((p) => p.pattern.test(clean));
  if (!match) throw new BadRequest('path not allowed');

  const url = new URL(`https://api.deezer.com/${clean}`);
  for (const [key, value] of Object.entries(query)) {
    if (!DEEZER_QUERY_KEYS.includes(key)) throw new BadRequest(`parameter not allowed: ${key}`);
    if (key === 'limit' || key === 'index') {
      if (!/^\d{1,4}$/.test(value)) throw new BadRequest(`bad ${key}`);
    } else if (value.length > MAX_VALUE_LENGTH) {
      throw new BadRequest(`${key} too long`);
    }
    url.searchParams.set(key, value);
  }
  return { url: url.toString(), ttlSeconds: match.ttlSeconds };
}
