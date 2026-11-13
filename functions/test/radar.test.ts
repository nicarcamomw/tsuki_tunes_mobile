import { describe, expect, it } from 'vitest';

import {
  buildMessage,
  isDeezerQuota,
  newReleases,
  notificationText,
  parseAlbums,
  runRadar,
  STALE_DEVICE_MS,
  STALE_STATE_MS,
  type ArtistState,
  type DeezerAlbum,
  type FollowedArtist,
  type PushMessage,
  type RadarDeps,
  type RadarDevice,
  type Release,
  type SendOutcome,
} from '../src/radar.js';

const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.parse('2026-11-13T14:00:00Z');

function day(offsetDays: number): string {
  return new Date(NOW + offsetDays * DAY).toISOString().slice(0, 10);
}

function album(id: string, released: string, recordType = 'album'): DeezerAlbum {
  return { id, title: `Album ${id}`, coverUrl: `https://cdn/${id}.jpg`, releaseDate: released, recordType };
}

function device(uid: string, extra: Partial<RadarDevice> = {}): RadarDevice {
  return { uid, deviceId: `${uid}-phone`, fid: `fid-${uid}`, platform: 'android', lang: 'es', notify: true, updatedAt: NOW - DAY, ...extra };
}

interface World {
  devices: RadarDevice[];
  follows: Record<string, FollowedArtist[]>;
  albums: Record<string, DeezerAlbum[] | null>;
  states: Map<string, ArtistState>;
  outcomes?: (m: PushMessage) => SendOutcome;
}

function fake(world: World) {
  const sent: PushMessage[] = [];
  const removed: string[] = [];
  const fetched: string[] = [];
  let clock = NOW;
  const deps: RadarDeps = {
    devices: async () => world.devices,
    followedArtists: async (uid) => world.follows[uid] ?? [],
    fetchAlbums: async (id) => {
      fetched.push(id);
      return world.albums[id] ?? null;
    },
    loadStates: async (ids) => new Map([...world.states].filter(([id]) => ids.includes(id))),
    saveStates: async (states) => {
      for (const [id, s] of states) world.states.set(id, s);
    },
    send: async (messages) => {
      sent.push(...messages);
      return messages.map((m) => world.outcomes?.(m) ?? 'ok');
    },
    removeDevices: async (list) => {
      removed.push(...list.map((d) => d.deviceId));
    },
    now: () => clock,
    sleep: async (ms) => {
      clock += ms;
    },
  };
  return { deps, sent, removed, fetched, advance: (ms: number) => (clock += ms) };
}

const options = { budgetMs: 60_000, workers: 2, gapMs: 10 };

describe('what counts as new', () => {
  const known: ArtistState = { ids: ['old'], checkedAt: NOW - DAY };

  it('an album not seen before, out in the last 30 days', () => {
    expect(newReleases([album('old', day(-100)), album('new', day(-2))], known, NOW).map((a) => a.id)).toEqual(['new']);
  });

  it('back-catalogue uploads, compilations and undated albums are not news', () => {
    const albums = [album('ancient', day(-40)), album('mix', day(-1), 'compile'), album('nodate', '')];
    expect(newReleases(albums, known, NOW)).toEqual([]);
  });

  it('an artist never seen before is only noted', () => {
    expect(newReleases([album('new', day(-1))], undefined, NOW)).toEqual([]);
  });

  it('a release dated ahead counts, like in the app', () => {
    expect(newReleases([album('soon', day(3))], known, NOW).map((a) => a.id)).toEqual(['soon']);
  });
});

describe('the daily run', () => {
  function world(): World {
    return {
      devices: [device('ana'), device('ben', { platform: 'ios', lang: 'en' })],
      follows: {
        ana: [{ id: '1', name: 'Deftones' }, { id: '2', name: 'Mitski' }],
        ben: [{ id: '2', name: 'Mitski' }],
      },
      albums: {
        '1': [album('a1', day(-200)), album('a2', day(-1), 'single')],
        '2': [album('b1', day(-300))],
      },
      states: new Map([
        ['1', { ids: ['a1'], checkedAt: NOW - DAY }],
        ['2', { ids: ['b1'], checkedAt: NOW - DAY }],
      ]),
    };
  }

  it("tells only the people following the artist with something new, once per artist check", async () => {
    const w = world();
    const { deps, sent, fetched } = fake(w);

    const summary = await runRadar(deps, options);

    expect(fetched.sort()).toEqual(['1', '2']);
    expect(sent).toHaveLength(1);
    expect(sent[0].fid).toBe('fid-ana');
    const releases = JSON.parse(sent[0].data.releases);
    expect(releases).toEqual([
      expect.objectContaining({ albumId: 'a2', artistId: '1', artistName: 'Deftones', recordType: 'single' }),
    ]);
    expect(summary).toMatchObject({ devices: 2, artists: 2, checked: 2, releases: 1, pushed: 1 });
    expect(w.states.get('1')?.ids).toEqual(['a1', 'a2']);
  });

  it('a second run the same day tells nobody again', async () => {
    const w = world();
    await runRadar(fake(w).deps, options);
    const again = fake(w);
    again.advance(60 * 60 * 1000);

    await runRadar(again.deps, options);

    expect(again.sent).toEqual([]);
  });

  it("an artist no one watched for days is noted again instead of flooding with what came out meanwhile", async () => {
    const w = world();
    w.states.set('1', { ids: ['a1'], checkedAt: NOW - STALE_STATE_MS - DAY });
    const { deps, sent } = fake(w);

    await runRadar(deps, options);

    expect(sent).toEqual([]);
    expect(w.states.get('1')?.ids).toContain('a2');
    expect(w.states.get('1')?.checkedAt).toBeGreaterThanOrEqual(NOW);
  });

  it('an artist Deezer failed on keeps their state for tomorrow', async () => {
    const w = world();
    w.albums['1'] = null;
    const { deps, sent } = fake(w);

    await runRadar(deps, options);

    expect(sent).toEqual([]);
    expect(w.states.get('1')).toEqual({ ids: ['a1'], checkedAt: NOW - DAY });
  });

  it('respects the switch in the app and skips people who follow no one', async () => {
    const w = world();
    w.devices = [device('ana', { notify: false }), device('cam')];
    const { deps, sent, fetched } = fake(w);

    await runRadar(deps, options);

    expect(sent).toEqual([]);
    expect(fetched).toEqual([]);
  });

  it('forgets uninstalled phones and phones that stopped checking in', async () => {
    const w = world();
    w.devices = [device('ana'), device('old', { updatedAt: NOW - STALE_DEVICE_MS - DAY })];
    w.outcomes = () => 'gone';
    const { deps, removed } = fake(w);

    const summary = await runRadar(deps, options);

    expect(removed.sort()).toEqual(['ana-phone', 'old-phone']);
    expect(summary.pushed).toBe(0);
  });

  it('stops starting requests when out of time; the least recently checked go first', async () => {
    const w = world();
    w.states.set('1', { ids: ['a1'], checkedAt: NOW - 2 * 60 * 1000 });
    w.states.set('2', { ids: ['b1'], checkedAt: NOW - DAY });
    const { deps, fetched } = fake(w);

    await runRadar(deps, { budgetMs: 5, workers: 1, gapMs: 10 });

    expect(fetched).toEqual(['2']);
  });
});

describe('the push', () => {
  const release = (id: string, artistName: string, releaseDate = day(-1), recordType = 'album'): Release => ({
    ...album(id, releaseDate, recordType),
    artistId: artistName,
    artistName,
  });

  it('Android gets data only, high priority, so the app writes the notification', () => {
    const m = buildMessage(device('ana'), [release('x', 'Deftones')]);
    expect(m.android).toEqual(expect.objectContaining({ priority: 'high' }));
    expect(m.apns).toBeUndefined();
    expect(m.data.type).toBe('release_radar');
    expect(m.data.count).toBe('1');
  });

  it('iOS gets the notification ready, in the language the phone registered', () => {
    const m = buildMessage(device('ben', { platform: 'ios', lang: 'en' }), [release('x', 'Deftones', day(-1), 'ep')]);
    expect(m.apns?.payload.aps.alert).toEqual({ title: 'Deftones dropped a new EP', body: 'Album x' });
  });

  it('describes at most 6 releases but counts them all, and stays small', () => {
    const many = Array.from({ length: 10 }, (_, i) => release(`r${i}`, `Artist ${i}`));
    const m = buildMessage(device('ana'), many);
    expect(JSON.parse(m.data.releases)).toHaveLength(6);
    expect(m.data.count).toBe('10');
    expect(JSON.stringify(m.data).length).toBeLessThan(4000);
  });

  it('texts match the app', () => {
    expect(notificationText([release('x', 'Mitski', day(-1), 'single')], 'es')).toEqual({
      title: 'Mitski sacó un single nuevo',
      body: 'Album x',
    });
    expect(notificationText([release('x', 'A'), release('y', 'B')], 'es')).toEqual({ title: '2 lanzamientos nuevos', body: 'A y B' });
    expect(notificationText([release('x', 'A'), release('y', 'B'), release('z', 'C')], 'en-US').body).toBe('A, B and 1 more');
    expect(notificationText([release('x', 'A'), release('y', 'B')], 'ja').title).toBe('新着リリース 2 件');
  });
});

describe('Deezer answers', () => {
  it('reads the albums list', () => {
    expect(
      parseAlbums({ data: [{ id: 7, title: 'T', cover_medium: 'c', release_date: '2026-11-01', record_type: 'ep' }] }),
    ).toEqual([{ id: '7', title: 'T', coverUrl: 'c', releaseDate: '2026-11-01', recordType: 'ep' }]);
    expect(parseAlbums({ error: { code: 800 } })).toBeNull();
  });

  it('spots the quota answer', () => {
    expect(isDeezerQuota({ error: { code: 4 } })).toBe(true);
    expect(isDeezerQuota({ data: [] })).toBe(false);
  });
});
