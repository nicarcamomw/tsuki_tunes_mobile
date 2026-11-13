/**
 * The release radar on the server: once a day, every artist someone follows
 * is checked on Deezer, and each phone whose account follows an artist with
 * a new release gets a push.
 *
 * Same rules as the app's own check (lib/data/datasources/release_radar_service.dart),
 * which stays as the fallback (guests, phones without Google Play, a day
 * the server misses):
 * - A release is new when the artist was already being watched, its album
 *   wasn't among the ones seen before, and it came out in the last 30 days
 *   (older albums appearing are back-catalogue uploads). Compilations never count.
 * - An artist seen for the first time, or not checked for a few days (nobody
 *   followed them for a while), is only noted: what they already have is not news.
 *
 * Android gets data only, and the app shows the notification itself: in the
 * person's language, with the cover, and skipping releases its own check
 * already told about. iOS can't run the app for that reliably, so it gets
 * the notification ready-made (in the language the phone registered with).
 *
 * Everything outside (Firestore, Deezer, FCM, the clock) comes in through
 * RadarDeps, so the tests run it with fakes.
 */

export interface DeezerAlbum {
  id: string;
  title: string;
  coverUrl: string;
  releaseDate: string;
  recordType: string;
}

export interface Release extends DeezerAlbum {
  artistId: string;
  artistName: string;
}

export interface RadarDevice {
  uid: string;
  deviceId: string;
  /** The phone's Firebase Installation ID: where FCM sends. */
  fid: string;
  platform: string;
  lang: string;
  notify: boolean;
  /** Last time the app confirmed this device, ms since epoch. */
  updatedAt: number;
}

export interface FollowedArtist {
  id: string;
  name: string;
}

export interface ArtistState {
  ids: string[];
  checkedAt: number;
}

export interface PushMessage {
  fid: string;
  data: Record<string, string>;
  android?: { priority: 'high'; ttl: number; collapseKey: string };
  apns?: {
    headers: Record<string, string>;
    payload: { aps: { alert: { title: string; body: string }; sound: string; threadId: string } };
  };
}

/** 'ok', 'gone' (the installation is no longer registered: forget the device) or 'failed'. */
export type SendOutcome = 'ok' | 'gone' | 'failed';

export interface RadarDeps {
  devices(): Promise<RadarDevice[]>;
  followedArtists(uid: string): Promise<FollowedArtist[]>;
  /** null: Deezer didn't answer properly; the artist keeps their old state. */
  fetchAlbums(artistId: string): Promise<DeezerAlbum[] | null>;
  loadStates(artistIds: string[]): Promise<Map<string, ArtistState>>;
  saveStates(states: Map<string, ArtistState>): Promise<void>;
  send(messages: PushMessage[]): Promise<SendOutcome[]>;
  removeDevices(devices: { uid: string; deviceId: string }[]): Promise<void>;
  now(): number;
  sleep(ms: number): Promise<void>;
}

export interface RadarOptions {
  /** Stop starting new Deezer requests after this many ms. */
  budgetMs: number;
  /** Deezer requests in flight at once. */
  workers: number;
  /** Pause after each request, per worker (Deezer allows ~50 per 5 s per address). */
  gapMs: number;
}

export interface RadarSummary {
  devices: number;
  artists: number;
  checked: number;
  releases: number;
  pushed: number;
  removedDevices: number;
}

const DAY = 24 * 60 * 60 * 1000;
export const NEW_WINDOW_MS = 30 * DAY;
/** A state older than this is stale: the artist is noted again, not compared. */
export const STALE_STATE_MS = 3 * DAY;
/** Devices the app hasn't confirmed in this long are dropped (FCM's advice). */
export const STALE_DEVICE_MS = 60 * DAY;
const MAX_IDS_PER_ARTIST = 150;
/** Releases described in one push; more only add to the count. */
const MAX_RELEASES_IN_PUSH = 6;
const FCM_BATCH = 500;

export const defaultOptions: RadarOptions = { budgetMs: 7 * 60 * 1000, workers: 3, gapMs: 350 };

/**
 * The albums of [albums] that are new for an artist last seen as [known]
 * (undefined: never seen, or stale).
 */
export function newReleases(albums: DeezerAlbum[], known: ArtistState | undefined, now: number): DeezerAlbum[] {
  if (!known) return [];
  const seen = new Set(known.ids);
  return albums.filter((a) => {
    if (!a.id || seen.has(a.id) || a.recordType === 'compile') return false;
    const released = Date.parse(a.releaseDate);
    if (Number.isNaN(released)) return false;
    // A date ahead (a pre-release listed early) counts as new, like in the app.
    return now - released <= NEW_WINDOW_MS;
  });
}

/** The ids to remember for an artist: the latest list first, then older ones. */
export function nextState(albums: DeezerAlbum[], known: ArtistState | undefined, now: number): ArtistState {
  const ids = [...new Set([...albums.map((a) => a.id).filter(Boolean), ...(known?.ids ?? [])])];
  return { ids: ids.slice(0, MAX_IDS_PER_ARTIST), checkedAt: now };
}

// ── Notification text (iOS only; Android writes its own from the data) ──

type Lang = 'es' | 'en' | 'ja';

function lang(code: string): Lang {
  const base = code.toLowerCase().split(/[-_]/)[0];
  return base === 'en' || base === 'ja' ? base : 'es';
}

const kindWord: Record<Lang, Record<'single' | 'ep' | 'album', string>> = {
  es: { single: 'un single nuevo', ep: 'un EP nuevo', album: 'un álbum nuevo' },
  en: { single: 'a new single', ep: 'a new EP', album: 'a new album' },
  ja: { single: '新しいシングル', ep: '新しいEP', album: '新しいアルバム' },
};

function kind(recordType: string): 'single' | 'ep' | 'album' {
  return recordType === 'single' || recordType === 'ep' ? recordType : 'album';
}

/** Mirrors radarNotifSingle / radarNotifMany / radarNotifManyBody in the app's l10n. */
export function notificationText(releases: Release[], code: string): { title: string; body: string } {
  const l = lang(code);
  if (releases.length === 1) {
    const r = releases[0];
    const what = kindWord[l][kind(r.recordType)];
    const title =
      l === 'es' ? `${r.artistName} sacó ${what}` : l === 'en' ? `${r.artistName} dropped ${what}` : `${r.artistName}が${what}をリリース`;
    return { title, body: r.title };
  }
  const n = releases.length;
  const title = l === 'es' ? `${n} lanzamientos nuevos` : l === 'en' ? `${n} new releases` : `新着リリース ${n} 件`;
  const artists = [...new Set(releases.map((r) => r.artistName))];
  const shown = artists.slice(0, 2);
  const rest = artists.length - shown.length;
  let body: string;
  if (rest > 0) {
    const names = shown.join(', ');
    body = l === 'es' ? `${names} y ${rest} más` : l === 'en' ? `${names} and ${rest} more` : `${names} 他${rest}組`;
  } else if (shown.length < 2) {
    body = shown.join(', ');
  } else {
    body = l === 'es' ? `${shown[0]} y ${shown[1]}` : l === 'en' ? `${shown[0]} and ${shown[1]}` : `${shown[0]}、${shown[1]}`;
  }
  return { title, body };
}

/** One device's push for [releases] (newest first). */
export function buildMessage(device: RadarDevice, releases: Release[]): PushMessage {
  const described = releases.slice(0, MAX_RELEASES_IN_PUSH).map((r) => ({
    albumId: r.id,
    title: r.title.slice(0, 150),
    artistId: r.artistId,
    artistName: r.artistName.slice(0, 100),
    coverUrl: r.coverUrl.slice(0, 400),
    releaseDate: r.releaseDate,
    recordType: r.recordType,
  }));
  const data = { type: 'release_radar', count: String(releases.length), releases: JSON.stringify(described) };
  if (device.platform === 'ios') {
    return {
      fid: device.fid,
      data,
      apns: {
        headers: { 'apns-priority': '10', 'apns-collapse-id': 'release_radar' },
        payload: { aps: { alert: notificationText(releases, device.lang), sound: 'default', threadId: 'release_radar' } },
      },
    };
  }
  // Data only, high priority, so the app's handler runs and writes it.
  return { fid: device.fid, data, android: { priority: 'high', ttl: DAY, collapseKey: 'release_radar' } };
}

/** Runs [task] over [items] with [workers] in parallel, stopping new ones at [deadline]. */
async function pool<T>(items: T[], workers: number, deadline: number, deps: RadarDeps, task: (item: T) => Promise<void>) {
  let next = 0;
  const worker = async () => {
    while (next < items.length && deps.now() < deadline) {
      const item = items[next++];
      await task(item);
    }
  };
  await Promise.all(Array.from({ length: Math.max(1, workers) }, worker));
}

export async function runRadar(deps: RadarDeps, options: RadarOptions = defaultOptions): Promise<RadarSummary> {
  const start = deps.now();
  const deadline = start + options.budgetMs;
  const summary: RadarSummary = { devices: 0, artists: 0, checked: 0, releases: 0, pushed: 0, removedDevices: 0 };

  // Devices: drop the ones the app stopped confirming long ago.
  const all = await deps.devices();
  const stale = all.filter((d) => start - d.updatedAt > STALE_DEVICE_MS || !d.fid);
  const active = all.filter((d) => !stale.includes(d) && d.notify);
  summary.devices = active.length;

  // Who follows whom, for the accounts with a device to tell.
  const followsByUser = new Map<string, FollowedArtist[]>();
  for (const uid of new Set(active.map((d) => d.uid))) {
    const follows = await deps.followedArtists(uid);
    if (follows.length > 0) followsByUser.set(uid, follows);
  }
  const names = new Map<string, string>();
  for (const follows of followsByUser.values()) {
    for (const a of follows) if (a.id && !names.has(a.id)) names.set(a.id, a.name);
  }
  const artistIds = [...names.keys()];
  summary.artists = artistIds.length;

  // Least recently checked first: a run that runs out of time still rotates
  // through everyone over the next days.
  const states = await deps.loadStates(artistIds);
  artistIds.sort((a, b) => (states.get(a)?.checkedAt ?? 0) - (states.get(b)?.checkedAt ?? 0));

  const fresh = new Map<string, Release[]>();
  const updated = new Map<string, ArtistState>();
  await pool(artistIds, options.workers, deadline, deps, async (artistId) => {
    const albums = await deps.fetchAlbums(artistId);
    await deps.sleep(options.gapMs);
    if (!albums) return;
    const now = deps.now();
    const saved = states.get(artistId);
    const known = saved && now - saved.checkedAt <= STALE_STATE_MS ? saved : undefined;
    const found = newReleases(albums, known, now);
    if (found.length > 0) {
      fresh.set(
        artistId,
        found.map((a) => ({ ...a, artistId, artistName: names.get(artistId) ?? '' })),
      );
    }
    updated.set(artistId, nextState(albums, known ?? saved, now));
    summary.checked++;
  });

  // Saved before sending: a run that dies while sending never tells twice.
  if (updated.size > 0) await deps.saveStates(updated);

  const messages: PushMessage[] = [];
  const targets: RadarDevice[] = [];
  for (const device of active) {
    const follows = followsByUser.get(device.uid);
    if (!follows) continue;
    const releases = follows
      .flatMap((a) => fresh.get(a.id) ?? [])
      .sort((a, b) => b.releaseDate.localeCompare(a.releaseDate));
    if (releases.length === 0) continue;
    messages.push(buildMessage(device, releases));
    targets.push(device);
  }
  summary.releases = [...fresh.values()].reduce((n, r) => n + r.length, 0);

  const gone: RadarDevice[] = [...stale];
  for (let i = 0; i < messages.length; i += FCM_BATCH) {
    const outcomes = await deps.send(messages.slice(i, i + FCM_BATCH));
    outcomes.forEach((outcome, j) => {
      if (outcome === 'ok') summary.pushed++;
      if (outcome === 'gone') gone.push(targets[i + j]);
    });
  }
  if (gone.length > 0) {
    await deps.removeDevices(gone.map((d) => ({ uid: d.uid, deviceId: d.deviceId })));
    summary.removedDevices = gone.length;
  }
  return summary;
}

/** Deezer's /artist/{id}/albums answer, or null when it isn't one. */
export function parseAlbums(body: unknown): DeezerAlbum[] | null {
  if (!body || typeof body !== 'object') return null;
  const data = (body as { data?: unknown }).data;
  if (!Array.isArray(data)) return null;
  return data
    .filter((a): a is Record<string, unknown> => !!a && typeof a === 'object')
    .map((a) => ({
      id: a.id == null ? '' : String(a.id),
      title: typeof a.title === 'string' ? a.title : '',
      coverUrl: String(a.cover_medium ?? a.cover_big ?? a.cover ?? ''),
      releaseDate: typeof a.release_date === 'string' ? a.release_date : '',
      recordType: typeof a.record_type === 'string' ? a.record_type : 'album',
    }));
}

/** Deezer reports its quota with HTTP 200 and error code 4 (or 800). */
export function isDeezerQuota(body: unknown): boolean {
  const error = body && typeof body === 'object' ? (body as { error?: { code?: unknown } }).error : undefined;
  return !!error && (error.code === 4 || error.code === 800);
}
