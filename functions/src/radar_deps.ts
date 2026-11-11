import { Timestamp, type Firestore } from 'firebase-admin/firestore';
import type { Messaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';

import {
  isDeezerQuota,
  parseAlbums,
  type ArtistState,
  type DeezerAlbum,
  type RadarDeps,
  type RadarDevice,
  type SendOutcome,
} from './radar.js';

/** The radar's state per artist; only the server reads or writes it (rules deny the app). */
const STATES = 'radarArtists';
const READ_CHUNK = 300;
const WRITE_CHUNK = 400;

/** FCM's answers that mean the installation is gone for good. */
const GONE_CODES = new Set([
  'messaging/installation-id-not-registered',
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

function millis(v: unknown): number {
  return v instanceof Timestamp ? v.toMillis() : typeof v === 'number' ? v : 0;
}

/** RadarDeps over the real Firestore, Deezer and FCM. */
export function firestoreRadarDeps(db: Firestore, messaging: Messaging, userAgent: string): RadarDeps {
  const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

  return {
    now: () => Date.now(),
    sleep,

    // users/{uid}/devices/{deviceId}, written by the app (PushRegistration).
    async devices() {
      const snap = await db.collectionGroup('devices').get();
      const out: RadarDevice[] = [];
      for (const doc of snap.docs) {
        const user = doc.ref.parent.parent;
        if (!user || user.parent.id !== 'users') continue;
        const d = doc.data();
        out.push({
          uid: user.id,
          deviceId: doc.id,
          fid: typeof d.fid === 'string' ? d.fid : '',
          platform: typeof d.platform === 'string' ? d.platform : 'android',
          lang: typeof d.lang === 'string' ? d.lang : 'es',
          notify: d.notify !== false,
          updatedAt: millis(d.updatedAt),
        });
      }
      return out;
    },

    async followedArtists(uid) {
      const snap = await db.collection('users').doc(uid).collection('followedArtists').get();
      return snap.docs.map((doc) => ({
        id: doc.id,
        name: typeof doc.get('name') === 'string' ? (doc.get('name') as string) : '',
      }));
    },

    async fetchAlbums(artistId) {
      const url = `https://api.deezer.com/artist/${encodeURIComponent(artistId)}/albums?limit=50`;
      for (let attempt = 0; attempt < 3; attempt++) {
        try {
          const res = await fetch(url, { headers: { 'User-Agent': userAgent }, signal: AbortSignal.timeout(10000) });
          if (res.status === 429) {
            await sleep(2000);
            continue;
          }
          if (res.status !== 200) return null;
          const body: unknown = await res.json();
          if (isDeezerQuota(body)) {
            await sleep(2000);
            continue;
          }
          return parseAlbums(body) satisfies DeezerAlbum[] | null;
        } catch {
          return null;
        }
      }
      return null;
    },

    async loadStates(artistIds) {
      const states = new Map<string, ArtistState>();
      for (let i = 0; i < artistIds.length; i += READ_CHUNK) {
        const refs = artistIds.slice(i, i + READ_CHUNK).map((id) => db.collection(STATES).doc(id));
        if (refs.length === 0) continue;
        const docs = await db.getAll(...refs, { fieldMask: ['ids', 'checkedAt'] });
        for (const doc of docs) {
          if (!doc.exists) continue;
          const ids = doc.get('ids');
          states.set(doc.id, {
            ids: Array.isArray(ids) ? ids.map(String) : [],
            checkedAt: millis(doc.get('checkedAt')),
          });
        }
      }
      return states;
    },

    async saveStates(states) {
      const entries = [...states.entries()];
      for (let i = 0; i < entries.length; i += WRITE_CHUNK) {
        const batch = db.batch();
        for (const [id, state] of entries.slice(i, i + WRITE_CHUNK)) {
          batch.set(db.collection(STATES).doc(id), {
            ids: state.ids,
            checkedAt: Timestamp.fromMillis(state.checkedAt),
          });
        }
        await batch.commit();
      }
    },

    async send(messages) {
      const res = await messaging.sendEach(messages);
      return res.responses.map((r): SendOutcome => {
        if (r.success) return 'ok';
        const code = r.error?.code ?? '';
        if (!GONE_CODES.has(code)) logger.warn('push failed', { code, message: r.error?.message });
        return GONE_CODES.has(code) ? 'gone' : 'failed';
      });
    },

    async removeDevices(devices) {
      for (let i = 0; i < devices.length; i += WRITE_CHUNK) {
        const batch = db.batch();
        for (const d of devices.slice(i, i + WRITE_CHUNK)) {
          batch.delete(db.collection('users').doc(d.uid).collection('devices').doc(d.deviceId));
        }
        await batch.commit();
      }
    },
  };
}
