// Firestore security rules tests. Run from this folder:
//   npm install
//   npx firebase emulators:exec --only firestore --project demo-tsuki "node rules.test.mjs"
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc,
  setDoc,
  updateDoc,
  deleteDoc,
  getDoc,
  writeBatch,
  serverTimestamp,
  increment,
  Timestamp,
} from 'firebase/firestore';

const env = await initializeTestEnvironment({
  projectId: 'demo-tsuki',
  firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
});

const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();

// Seeds documents with rules off, e.g. a stamp from long ago.
async function seed(path, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}

const oldStamp = () => ({ lastSubWrite: Timestamp.fromMillis(Date.now() - 60_000) });
const track = (id) => ({
  trackId: id,
  title: 'Song',
  artistName: 'Artist',
  albumTitle: 'Album',
  albumId: '1',
  coverUrl: 'https://e/c.jpg',
  previewUrl: 'https://e/p.mp3',
  duration: 200,
  listenedAt: serverTimestamp(),
});

// What the app does: subcollection write + stamp, in one batch.
function stampedBatch(db, uid, write) {
  const b = writeBatch(db);
  write(b);
  b.set(doc(db, `users/${uid}`), { lastSubWrite: serverTimestamp() }, { merge: true });
  return b.commit();
}

const tests = [];
const test = (name, fn) => tests.push([name, fn]);

test('stamped write is accepted', async () => {
  await seed('users/alice', oldStamp());
  const db = alice();
  await assertSucceeds(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/listenedTracks/t1'), track('t1'))));
});

test('first write ever (no user doc yet) is accepted', async () => {
  const db = alice();
  await assertSucceeds(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/listenedTracks/t1'), track('t1'))));
});

test('write without the stamp is rejected (the old bypass)', async () => {
  await seed('users/alice', oldStamp());
  await assertFails(setDoc(doc(alice(), 'users/alice/listenedTracks/t1'), track('t1')));
});

test('second stamped write within a second is rejected', async () => {
  await seed('users/alice', oldStamp());
  const db = alice();
  await assertSucceeds(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/followedArtists/a1'), { id: 'a1', name: 'A' })));
  await assertFails(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/followedArtists/a2'), { id: 'a2', name: 'B' })));
});

test('a batch of 450 tracks plus stamp is accepted', async () => {
  await seed('users/alice', oldStamp());
  const db = alice();
  await assertSucceeds(stampedBatch(db, 'alice', (b) => {
    for (let i = 0; i < 450; i++) b.set(doc(db, `users/alice/listenedTracks/t${i}`), track(`t${i}`));
  }));
});

test('stamp can not be set to the past', async () => {
  await seed('users/alice', oldStamp());
  await assertFails(updateDoc(doc(alice(), 'users/alice'), { lastSubWrite: Timestamp.fromMillis(0) }));
});

test('user doc can not be deleted (would reset the stamp)', async () => {
  await seed('users/alice', oldStamp());
  await assertFails(deleteDoc(doc(alice(), 'users/alice')));
});

test('profile create and login update are accepted', async () => {
  const db = alice();
  await assertSucceeds(setDoc(doc(db, 'users/alice'), {
    displayName: 'Alice', email: 'a@e.com', photoURL: 'https://e/a.jpg',
    createdAt: serverTimestamp(), lastLoginAt: serverTimestamp(), stats: { totalTracks: 0 },
  }));
  await assertSucceeds(updateDoc(doc(db, 'users/alice'), { lastLoginAt: serverTimestamp() }));
});

test('stats increment with stamp and masks merge are accepted', async () => {
  await seed('users/alice', { ...oldStamp(), stats: { totalTracks: 3 } });
  const db = alice();
  await assertSucceeds(stampedBatch(db, 'alice', (b) => {
    b.set(doc(db, 'users/alice/listenedTracks/t9'), track('t9'));
    b.set(doc(db, 'users/alice'), { stats: { totalTracks: increment(1) } }, { merge: true });
  }));
  await assertSucceeds(setDoc(doc(db, 'users/alice'), { masks: { unlocked: { hajime: 1 }, equipped: 'hajime' } }, { merge: true }));
});

test('oversized fields are rejected', async () => {
  await seed('users/alice', oldStamp());
  const db = alice();
  await assertFails(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/listenedTracks/big'), { ...track('big'), title: 'x'.repeat(501) })));
  await assertFails(setDoc(doc(db, 'users/alice'), { displayName: 'x'.repeat(501) }, { merge: true }));
  const many = {};
  for (let i = 0; i < 41; i++) many[`f${i}`] = i;
  await assertFails(setDoc(doc(db, 'users/alice'), many, { merge: true }));
  await assertFails(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/listenedDeletions/t1'), { deletedAt: serverTimestamp(), junk: 'x' })));
});

test('playlist with too many tracks is rejected', async () => {
  await seed('users/alice', oldStamp());
  const db = alice();
  const tracks = Array.from({ length: 1001 }, (_, i) => ({ id: `${i}` }));
  await assertFails(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/playlists/p1'), { name: 'P', tracks })));
});

test('deletion log entry with stamp is accepted', async () => {
  await seed('users/alice', oldStamp());
  const db = alice();
  await assertSucceeds(stampedBatch(db, 'alice', (b) => {
    b.delete(doc(db, 'users/alice/listenedTracks/t1'));
    b.set(doc(db, 'users/alice/listenedDeletions/t1'), { deletedAt: serverTimestamp() });
  }));
});

test('other users can not read or write', async () => {
  await seed('users/alice', oldStamp());
  await seed('users/alice/listenedTracks/t1', { title: 'Song' });
  const db = bob();
  await assertFails(getDoc(doc(db, 'users/alice')));
  await assertFails(getDoc(doc(db, 'users/alice/listenedTracks/t1')));
  await assertFails(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/listenedTracks/t2'), track('t2'))));
});

test('play log accepts back-to-back writes and rejects bad day ids', async () => {
  const db = alice();
  const day = { date: '2026-10-30', plays: { t1: increment(1) }, hours: { 3: increment(1) }, seconds: increment(200), tracks: {}, updatedAt: serverTimestamp() };
  await assertSucceeds(setDoc(doc(db, 'users/alice/playDays/2026-10-30'), day, { merge: true }));
  await assertSucceeds(setDoc(doc(db, 'users/alice/playDays/2026-10-30'), day, { merge: true }));
  await assertFails(setDoc(doc(db, 'users/alice/playDays/hello'), day));
});

test('a listened song may carry its artist list, of a sane size', async () => {
  await seed('users/alice', oldStamp());
  const db = alice();
  await assertSucceeds(stampedBatch(db, 'alice', (b) =>
    b.set(doc(db, 'users/alice/listenedTracks/t1'), { ...track('t1'), artists: ['Bad Bunny', 'J Balvin'] })));
  await seed('users/alice', oldStamp());
  const many = Array.from({ length: 21 }, (_, i) => `A${i}`);
  await assertFails(stampedBatch(db, 'alice', (b) =>
    b.set(doc(db, 'users/alice/listenedTracks/t2'), { ...track('t2'), artists: many })));
});

// --- Public profiles

const profile = (overrides = {}) => ({
  displayName: 'Alice',
  photoUrl: 'https://x/a.jpg',
  maskId: 'hannya',
  public: true,
  stats: { tracks: 120, albums: 4, artists: 30 },
  topArtists: [{ name: 'SOAD', count: 40, pictureUrl: 'https://x/s.jpg' }],
  updatedAt: serverTimestamp(),
  ...overrides,
});

test('the owner publishes a valid profile', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'profiles/alice'), profile()));
});

test('a profile with anything else in it is rejected (nothing private leaks)', async () => {
  const db = alice();
  await assertFails(setDoc(doc(db, 'profiles/alice'), profile({ email: 'a@x.com' })));
  await assertFails(setDoc(doc(db, 'profiles/alice'), profile({ stats: { tracks: 1, albums: 1, artists: 1, secret: 1 } })));
  await assertFails(setDoc(doc(db, 'profiles/alice'), profile({ topArtists: [{ name: 'A', count: 1, uid: 'bob' }] })));
});

test('bad numbers, too many artists or a made-up time are rejected', async () => {
  const db = alice();
  await assertFails(setDoc(doc(db, 'profiles/alice'), profile({ stats: { tracks: -1, albums: 0, artists: 0 } })));
  await assertFails(setDoc(doc(db, 'profiles/alice'), profile({ stats: { tracks: 1.5, albums: 0, artists: 0 } })));
  const six = Array.from({ length: 6 }, (_, i) => ({ name: `A${i}`, count: 1 }));
  await assertFails(setDoc(doc(db, 'profiles/alice'), profile({ topArtists: six })));
  await assertFails(setDoc(doc(db, 'profiles/alice'), profile({ updatedAt: Timestamp.fromMillis(0) })));
  await assertFails(setDoc(doc(db, 'profiles/alice'), profile({ displayName: 'x'.repeat(61) })));
});

test('a public profile is readable by others, a private one only by its owner', async () => {
  await seed('profiles/alice', { ...profile(), updatedAt: Timestamp.now() });
  await assertSucceeds(getDoc(doc(bob(), 'profiles/alice')));

  await seed('profiles/alice', { ...profile({ public: false }), updatedAt: Timestamp.now() });
  await assertFails(getDoc(doc(bob(), 'profiles/alice')));
  await assertSucceeds(getDoc(doc(alice(), 'profiles/alice')));
  await assertFails(getDoc(doc(bob(), 'profiles/nobody')));
});

test('nobody writes someone else\'s profile', async () => {
  await assertFails(setDoc(doc(bob(), 'profiles/alice'), profile()));
  await seed('profiles/alice', { ...profile(), updatedAt: Timestamp.now() });
  await assertFails(deleteDoc(doc(bob(), 'profiles/alice')));
});

test('profile updates are at least 10 seconds apart', async () => {
  await seed('profiles/alice', { ...profile(), updatedAt: Timestamp.now() });
  await assertFails(setDoc(doc(alice(), 'profiles/alice'), profile({ public: false })));

  await seed('profiles/alice', { ...profile(), updatedAt: Timestamp.fromMillis(Date.now() - 11_000) });
  await assertSucceeds(setDoc(doc(alice(), 'profiles/alice'), profile({ public: false })));
});

let failed = 0;
for (const [name, fn] of tests) {
  await env.clearFirestore();
  try {
    await fn();
    console.log(`ok - ${name}`);
  } catch (e) {
    failed++;
    console.log(`FAIL - ${name}\n  ${e.message}`);
  }
}
await env.cleanup();
assert.equal(failed, 0, `${failed} rules test(s) failed`);
console.log(`\nAll ${tests.length} rules tests passed`);
