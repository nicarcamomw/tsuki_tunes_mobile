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
  deleteField,
  collection,
  query,
  where,
  orderBy,
  getDocs,
  arrayUnion,
  arrayRemove,
} from 'firebase/firestore';

const env = await initializeTestEnvironment({
  projectId: 'demo-tsuki',
  firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
});

const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();
const carol = () => env.authenticatedContext('carol').firestore();

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

test('mask progress backup: counters and up to 50 artists', async () => {
  await seed('users/alice', { ...oldStamp(), masks: { unlocked: { hajime: 1 } } });
  const db = alice();
  const artists = (n) => Object.fromEntries(Array.from({ length: n }, (_, i) => [`artist ${i}`, i]));
  await assertSucceeds(setDoc(doc(db, 'users/alice'),
    { masks: { progress: { plays: 300, night: 12, rain: 3600, artists: artists(30) } } },
    { mergeFields: ['masks.progress'] }));
  await assertFails(setDoc(doc(db, 'users/alice'),
    { masks: { progress: { plays: 1, artists: artists(51) } } },
    { mergeFields: ['masks.progress'] }));
  await assertFails(setDoc(doc(db, 'users/alice'),
    { masks: { progress: { artists: 'many' } } },
    { mergeFields: ['masks.progress'] }));
  // Styles and the newer masks' counters.
  await assertSucceeds(setDoc(doc(db, 'users/alice'),
    { masks: { progress: { plays: 300, styles: { metal: 40, rock: 12 }, c: { streak: 9, 'amb:fire': 3600 } } } },
    { mergeFields: ['masks.progress'] }));
  const many = (n) => Object.fromEntries(Array.from({ length: n }, (_, i) => [`k${i}`, i]));
  await assertFails(setDoc(doc(db, 'users/alice'),
    { masks: { progress: { styles: many(25) } } },
    { mergeFields: ['masks.progress'] }));
  await assertFails(setDoc(doc(db, 'users/alice'),
    { masks: { progress: { c: many(41) } } },
    { mergeFields: ['masks.progress'] }));
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

// --- Schema per collection

const artist = (id) => ({
  id, name: 'Artist', pictureUrl: 'https://e/a.jpg', pictureSmall: null,
  pictureMedium: 'https://e/m.jpg', pictureBig: null, pictureXl: null, fansCount: 10, albumsCount: 2,
});

test('what the app writes passes the schema of every collection', async () => {
  const db = alice();
  await seed('users/alice', oldStamp());
  await assertSucceeds(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/followedArtists/a1'), artist('a1'))));
  await seed('users/alice', oldStamp());
  await assertSucceeds(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/playlists/p1'),
    { name: 'Mix', tracks: [{ id: '1' }], createdAt: Timestamp.now(), updatedAt: serverTimestamp() })));
  await seed('users/alice', oldStamp());
  await assertSucceeds(stampedBatch(db, 'alice', (b) => b.update(doc(db, 'users/alice/playlists/p1'),
    { name: 'Renamed', updatedAt: serverTimestamp() })));
});

test('a field outside the schema is rejected, in every collection', async () => {
  const db = alice();
  const junk = { isAdmin: true };
  await seed('users/alice', oldStamp());
  await assertFails(setDoc(doc(db, 'users/alice'), junk, { merge: true }));
  await assertFails(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/listenedTracks/t1'), { ...track('t1'), ...junk })));
  await assertFails(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/followedArtists/a1'), { ...artist('a1'), ...junk })));
  await assertFails(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/playlists/p1'), { name: 'P', tracks: [], ...junk })));
  await assertFails(setDoc(doc(db, 'users/alice/playDays/2026-10-30'), { date: '2026-10-30', ...junk }, { merge: true }));
});

test('wrong types and ids that do not match the document are rejected', async () => {
  const db = alice();
  await seed('users/alice', oldStamp());
  await assertFails(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/listenedTracks/t1'), { ...track('t1'), duration: '200' })));
  await assertFails(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/listenedTracks/t1'), track('other'))));
  await assertFails(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/listenedTracks/t1'), { ...track('t1'), listenedAt: 'yesterday' })));
  await assertFails(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/followedArtists/a1'), artist('a2'))));
  await assertFails(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/followedArtists/a1'), { ...artist('a1'), fansCount: -1 })));
  await assertFails(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/playlists/p1'), { name: '', tracks: [] })));
  await assertFails(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/playlists/p1'), { tracks: [] })));
  await assertFails(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/playlists/p1'),
    { name: 'P', tracks: [], updatedAt: Timestamp.fromMillis(0) })));
  await assertFails(setDoc(doc(db, 'users/alice/playDays/2026-10-30'), { date: '2026-10-31' }, { merge: true }));
  await assertFails(setDoc(doc(db, 'users/alice'), { stats: { totalTracks: -5 } }, { merge: true }));
  await assertFails(setDoc(doc(db, 'users/alice'), { masks: { equipped: 'x'.repeat(41) } }, { merge: true }));
});

test('an older document with fields from earlier versions can still be updated', async () => {
  const db = alice();
  await seed('users/alice', { ...oldStamp(), webTheme: 'dark', stats: { totalTracks: 3, webOnly: 1 } });
  await seed('users/alice/listenedTracks/t1', { ...track('t1'), listenedAt: Timestamp.now(), legacyRating: 5 });
  await assertSucceeds(setDoc(doc(db, 'users/alice'), { stats: { totalTracks: 4 } }, { merge: true }));
  await assertSucceeds(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/listenedTracks/t1'),
    { ...track('t1'), artists: ['A'] }, { merge: true })));
  // Replacing it whole drops the old field: that is fine too.
  await seed('users/alice', { ...oldStamp(), webTheme: 'dark' });
  await assertSucceeds(stampedBatch(db, 'alice', (b) => b.set(doc(db, 'users/alice/listenedTracks/t1'), track('t1'))));
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

// Deleting the account from the app (AccountDeletionService): every
// subcollection in stamped batches, the play log and profile outright, and
// the user document stripped of everything but the stamp.
test('the app can delete all of an account\'s data', async () => {
  await seed('users/alice', {
    displayName: 'Alice',
    email: 'alice@example.com',
    photoURL: 'https://e/a.jpg',
    createdAt: Timestamp.now(),
    lastLoginAt: Timestamp.now(),
    stats: { totalTracks: 2 },
    masks: { equipped: 'oni' },
    ...oldStamp(),
  });
  await seed('users/alice/listenedTracks/t1', { trackId: 't1' });
  await seed('users/alice/playlists/p1', { name: 'Mix', tracks: [] });
  await seed('users/alice/followedArtists/a1', { id: 'a1', name: 'A' });
  await seed('users/alice/listenedDeletions/t2', { deletedAt: Timestamp.now() });
  await seed('users/alice/playDays/2026-11-02', { date: '2026-11-02' });
  await seed('profiles/alice', { ...profile(), updatedAt: Timestamp.now() });

  const db = alice();
  const paths = [
    'users/alice/listenedTracks/t1',
    'users/alice/playlists/p1',
    'users/alice/followedArtists/a1',
    'users/alice/listenedDeletions/t2',
  ];
  for (const [i, path] of paths.entries()) {
    if (i > 0) await new Promise((r) => setTimeout(r, 1100));
    await assertSucceeds(stampedBatch(db, 'alice', (b) => b.delete(doc(db, path))));
  }
  await assertSucceeds(deleteDoc(doc(db, 'users/alice/playDays/2026-11-02')));
  await assertSucceeds(deleteDoc(doc(db, 'profiles/alice')));
  await assertSucceeds(updateDoc(doc(db, 'users/alice'), {
    displayName: deleteField(),
    email: deleteField(),
    photoURL: deleteField(),
    createdAt: deleteField(),
    lastLoginAt: deleteField(),
    stats: deleteField(),
    masks: deleteField(),
  }));
  const left = (await getDoc(doc(db, 'users/alice'))).data();
  assert.deepEqual(Object.keys(left), ['lastSubWrite']);
});

test('nobody else can delete an account\'s data', async () => {
  await seed('users/alice', { email: 'alice@example.com', ...oldStamp() });
  await seed('users/alice/playDays/2026-11-02', { date: '2026-11-02' });
  const db = bob();
  await assertFails(updateDoc(doc(db, 'users/alice'), { email: deleteField() }));
  await assertFails(deleteDoc(doc(db, 'users/alice/playDays/2026-11-02')));
});

test('the level 100 choice is made once', async () => {
  await seed('users/alice', { ...oldStamp(), masks: { unlocked: { hajime: 1 } } });
  const db = alice();
  await assertFails(setDoc(doc(db, 'users/alice'), { masks: { choice: 'maybe' } }, { merge: true }));
  await assertSucceeds(setDoc(doc(db, 'users/alice'), { masks: { choice: 'no' } }, { merge: true }));
  await assertFails(setDoc(doc(db, 'users/alice'), { masks: { choice: 'ser' } }, { merge: true }));
  // Deleting the account's data still works.
  await assertSucceeds(updateDoc(doc(db, 'users/alice'), { masks: deleteField() }));
});

test('a Bearer at level 100 tells the keeper; no one reads it', async () => {
  const db = alice();
  const report = { name: 'Alice', level: 100, eco: 2800000, at: serverTimestamp() };
  await assertSucceeds(setDoc(doc(db, 'ascensions/alice'), report));
  await assertSucceeds(setDoc(doc(db, 'ascensions/alice'),
    { maskName: 'Luz de Alice', choice: 'ser', level: 100, eco: 2800500, at: serverTimestamp() }, { merge: true }));
  // The choice stays; others can't write here; nobody reads.
  await assertFails(setDoc(doc(db, 'ascensions/alice'),
    { choice: 'no', level: 100, eco: 2800600, at: serverTimestamp() }, { merge: true }));
  await assertFails(setDoc(doc(bob(), 'ascensions/alice'), report));
  await assertFails(getDoc(doc(db, 'ascensions/alice')));
  // Only the report's fields; the keeper's marks are not the client's.
  await assertFails(setDoc(doc(db, 'ascensions/alice'),
    { notifiedReach: true, level: 100, eco: 2800600, at: serverTimestamp() }, { merge: true }));
  await assertFails(setDoc(doc(alice(), 'ascensions/alice2'), report));
  await assertFails(setDoc(doc(bob(), 'ascensions/bob'), { ...report, level: 99 }));
  // Deleting the account takes it; only its owner can.
  await assertFails(deleteDoc(doc(bob(), 'ascensions/alice')));
  await assertSucceeds(deleteDoc(doc(db, 'ascensions/alice')));
});

// --- Bonds (Lazos)

const card = (name, overrides = {}) => ({ name, photoUrl: null, maskId: 'hannya', at: serverTimestamp(), ...overrides });

// Alice asks Bob, as the app does: his inbox, her outbox and her stamp.
function sendRequest(db = alice()) {
  const b = writeBatch(db);
  b.set(doc(db, 'users/bob/friendRequests/alice'), card('Alice'));
  b.set(doc(db, 'users/alice/sentRequests/bob'), card('Bob'));
  b.set(doc(db, 'users/alice'), { lastSubWrite: serverTimestamp() }, { merge: true });
  return b.commit();
}

// Bob accepts: both Bonds, the request and Alice's outbox entry gone.
function accept(db = bob()) {
  const b = writeBatch(db);
  b.set(doc(db, 'users/bob/friends/alice'), card('Alice'));
  b.set(doc(db, 'users/alice/friends/bob'), card('Bob'));
  b.delete(doc(db, 'users/bob/friendRequests/alice'));
  b.delete(doc(db, 'users/alice/sentRequests/bob'));
  return b.commit();
}

test('a request goes out stamped, and only as yourself', async () => {
  await seed('users/alice', oldStamp());
  await assertSucceeds(sendRequest());
  // Without the stamp, or in someone else's name.
  await seed('users/carol', oldStamp());
  await assertFails(setDoc(doc(carol(), 'users/bob/friendRequests/carol'), card('Carol')));
  await assertFails(setDoc(doc(carol(), 'users/bob/friendRequests/alice'), card('Alice')));
  // Not to yourself, nothing else in the card.
  const db = alice();
  await assertFails(setDoc(doc(db, 'users/alice/friendRequests/alice'), card('Alice')));
  await assertFails(setDoc(doc(db, 'users/bob/friendRequests/alice'), card('Alice', { email: 'a@x.com' })));
});

test('a request can be read by the one who got it, not by others', async () => {
  await seed('users/bob/friendRequests/alice', { ...card('Alice'), at: Timestamp.now() });
  await assertSucceeds(getDoc(doc(bob(), 'users/bob/friendRequests/alice')));
  await assertFails(getDoc(doc(carol(), 'users/bob/friendRequests/alice')));
});

test('accepting makes the Bond on both sides; without a request, no Bond', async () => {
  // No request: nobody can make themselves someone's Bond.
  await assertFails(setDoc(doc(alice(), 'users/alice/friends/bob'), card('Bob')));
  await assertFails(setDoc(doc(alice(), 'users/bob/friends/alice'), card('Alice')));
  await seed('users/bob/friendRequests/alice', { ...card('Alice'), at: Timestamp.now() });
  await seed('users/alice/sentRequests/bob', { ...card('Bob'), at: Timestamp.now() });
  // The sender can't accept their own request.
  await assertFails(setDoc(doc(alice(), 'users/alice/friends/bob'), card('Bob')));
  await assertSucceeds(accept());
});

test('a request to someone already bonded is refused', async () => {
  await seed('users/alice', oldStamp());
  await seed('users/bob/friends/alice', { ...card('Alice'), at: Timestamp.now() });
  await assertFails(sendRequest());
});

test('either side can decline, cancel or undo the Bond; outsiders cannot', async () => {
  await seed('users/bob/friendRequests/alice', { ...card('Alice'), at: Timestamp.now() });
  await assertFails(deleteDoc(doc(carol(), 'users/bob/friendRequests/alice')));
  await assertSucceeds(deleteDoc(doc(alice(), 'users/bob/friendRequests/alice')));
  await seed('users/alice/friends/bob', { ...card('Bob'), at: Timestamp.now() });
  await seed('users/bob/friends/alice', { ...card('Alice'), at: Timestamp.now() });
  await assertFails(deleteDoc(doc(carol(), 'users/alice/friends/bob')));
  await assertSucceeds(deleteDoc(doc(bob(), 'users/alice/friends/bob')));
  await assertSucceeds(deleteDoc(doc(bob(), 'users/bob/friends/alice')));
});

test('a private profile is readable by its Bonds only', async () => {
  await seed('profiles/alice', { ...profile({ public: false }), updatedAt: Timestamp.now() });
  await assertFails(getDoc(doc(bob(), 'profiles/alice')));
  await seed('users/alice/friends/bob', { ...card('Bob'), at: Timestamp.now() });
  await assertSucceeds(getDoc(doc(bob(), 'profiles/alice')));
  await assertFails(getDoc(doc(carol(), 'profiles/alice')));
});

test('a profile carries its search key, tops and milestones, within limits', async () => {
  const db = alice();
  await assertSucceeds(setDoc(doc(db, 'profiles/alice'), profile({
    nameLower: 'alice',
    tops: ['SOAD', 'Deftones'],
    milestones: [{ k: 'album', a: 'Toxicity', b: 'SOAD', t: 1 }],
  })));
  await env.clearFirestore();
  await assertFails(setDoc(doc(db, 'profiles/alice'), profile({ tops: Array.from({ length: 31 }, (_, i) => `A${i}`) })));
  await assertFails(setDoc(doc(db, 'profiles/alice'),
    profile({ milestones: Array.from({ length: 11 }, () => ({ k: 'mask', a: 'oni', t: 1 })) })));
  await assertFails(setDoc(doc(db, 'profiles/alice'), profile({ nameLower: 'x'.repeat(61) })));
});

test('searching by name finds public profiles only', async () => {
  await seed('profiles/alice', { ...profile({ nameLower: 'alice' }), updatedAt: Timestamp.now() });
  await seed('profiles/alma', { ...profile({ displayName: 'Alma', nameLower: 'alma', public: false }), updatedAt: Timestamp.now() });
  const db = bob();
  const found = await assertSucceeds(getDocs(query(collection(db, 'profiles'),
    where('public', '==', true), where('nameLower', '>=', 'al'), where('nameLower', '<', 'al\uf8ff'), orderBy('nameLower'))));
  assert.deepEqual(found.docs.map((d) => d.id), ['alice']);
  // Without the public filter the query could return private ones: refused.
  await assertFails(getDocs(query(collection(db, 'profiles'), where('nameLower', '>=', 'al'))));
});

// --- Collaborative playlists

const shared = (overrides = {}) => ({
  name: 'Noche', owner: 'alice', members: ['alice'], invited: [], names: { alice: 'Alice' },
  tracks: [], updatedAt: serverTimestamp(), updatedBy: 'alice', ...overrides,
});
const seedShared = (overrides = {}) =>
  seed('sharedPlaylists/s1', { ...shared(overrides), updatedAt: Timestamp.now() });
const stamp = (uid) => ({ updatedAt: serverTimestamp(), updatedBy: uid });

test('a collaborative playlist is born with its owner as the only member', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'sharedPlaylists/s1'), shared()));
  await assertFails(setDoc(doc(alice(), 'sharedPlaylists/s2'), shared({ members: ['alice', 'bob'] })));
  await assertFails(setDoc(doc(alice(), 'sharedPlaylists/s3'), shared({ invited: ['bob'] })));
  await assertFails(setDoc(doc(bob(), 'sharedPlaylists/s4'), shared()));
});

test('the owner invites Bonds only, one at a time', async () => {
  await seedShared();
  await assertFails(updateDoc(doc(alice(), 'sharedPlaylists/s1'), { invited: arrayUnion('bob'), lastInvited: 'bob', ...stamp('alice') }));
  await seed('users/alice/friends/bob', { name: 'Bob', at: Timestamp.now() });
  await assertSucceeds(updateDoc(doc(alice(), 'sharedPlaylists/s1'), { invited: arrayUnion('bob'), lastInvited: 'bob', ...stamp('alice') }));
  // Nobody is made a member without joining.
  await assertFails(updateDoc(doc(alice(), 'sharedPlaylists/s1'), { members: arrayUnion('carol'), ...stamp('alice') }));
});

test('an invited Bond reads it and joins, with their own name only; outsiders see nothing', async () => {
  await seedShared({ invited: ['bob'] });
  await assertSucceeds(getDoc(doc(bob(), 'sharedPlaylists/s1')));
  await assertFails(getDoc(doc(carol(), 'sharedPlaylists/s1')));
  await assertFails(updateDoc(doc(carol(), 'sharedPlaylists/s1'), { members: arrayUnion('carol'), ...stamp('carol') }));
  await assertFails(updateDoc(doc(bob(), 'sharedPlaylists/s1'),
    { invited: arrayRemove('bob'), members: arrayUnion('bob'), 'names.alice': 'Hacked', ...stamp('bob') }));
  await assertSucceeds(updateDoc(doc(bob(), 'sharedPlaylists/s1'),
    { invited: arrayRemove('bob'), members: arrayUnion('bob'), 'names.bob': 'Bob', ...stamp('bob') }));
});

test('members edit the songs but not the name or the people; a member leaves; only the owner deletes', async () => {
  await seedShared({ members: ['alice', 'bob'], names: { alice: 'Alice', bob: 'Bob' } });
  await assertSucceeds(updateDoc(doc(bob(), 'sharedPlaylists/s1'), { tracks: [{ id: 't1', addedBy: 'bob' }], ...stamp('bob') }));
  await assertFails(updateDoc(doc(bob(), 'sharedPlaylists/s1'), { name: 'Mía', ...stamp('bob') }));
  await assertFails(updateDoc(doc(bob(), 'sharedPlaylists/s1'), { members: ['bob'], ...stamp('bob') }));
  await assertFails(updateDoc(doc(bob(), 'sharedPlaylists/s1'), { tracks: [], updatedAt: serverTimestamp(), updatedBy: 'alice' }));
  await assertFails(deleteDoc(doc(bob(), 'sharedPlaylists/s1')));
  await assertSucceeds(updateDoc(doc(bob(), 'sharedPlaylists/s1'), { members: arrayRemove('bob'), ...stamp('bob') }));
  await assertSucceeds(deleteDoc(doc(alice(), 'sharedPlaylists/s1')));
});

test('my collaborative playlists and invitations can be listed, not anyone else\'s', async () => {
  await seedShared({ invited: ['bob'] });
  const db = bob();
  await assertSucceeds(getDocs(query(collection(db, 'sharedPlaylists'), where('invited', 'array-contains', 'bob'))));
  await assertSucceeds(getDocs(query(collection(db, 'sharedPlaylists'), where('members', 'array-contains', 'bob'))));
  await assertFails(getDocs(query(collection(db, 'sharedPlaylists'), where('members', 'array-contains', 'alice'))));
});

// --- Listening parties

const party = (overrides = {}) => ({
  host: 'alice', name: 'Alice', members: [], invited: [], names: {},
  track: { id: 't1', title: 'Song' }, positionMs: 0, playing: true,
  at: serverTimestamp(), updatedAt: serverTimestamp(), ...overrides,
});
const seedParty = (overrides = {}) =>
  seed('parties/alice', { ...party(overrides), at: Timestamp.now(), updatedAt: Timestamp.now() });

test('a host opens their own party only, empty, and moves the music on', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'parties/alice'), party()));
  await assertFails(setDoc(doc(bob(), 'parties/alice'), party()));
  await assertFails(setDoc(doc(bob(), 'parties/bob'), party({ host: 'bob', members: ['alice'] })));
  await assertSucceeds(updateDoc(doc(alice(), 'parties/alice'),
    { positionMs: 42000, playing: false, at: serverTimestamp(), updatedAt: serverTimestamp() }));
  // A made-up clock is refused.
  await assertFails(updateDoc(doc(alice(), 'parties/alice'),
    { positionMs: 1, at: Timestamp.fromMillis(0), updatedAt: serverTimestamp() }));
});

test('only Bonds are invited; they join with their name; members cannot steer the music', async () => {
  await seedParty();
  await assertFails(updateDoc(doc(alice(), 'parties/alice'), { invited: arrayUnion('bob'), lastInvited: 'bob', updatedAt: serverTimestamp() }));
  await seed('users/alice/friends/bob', { name: 'Bob', at: Timestamp.now() });
  await assertSucceeds(updateDoc(doc(alice(), 'parties/alice'), { invited: arrayUnion('bob'), lastInvited: 'bob', updatedAt: serverTimestamp() }));
  await assertSucceeds(getDoc(doc(bob(), 'parties/alice')));
  await assertFails(getDoc(doc(carol(), 'parties/alice')));
  await assertSucceeds(updateDoc(doc(bob(), 'parties/alice'),
    { invited: arrayRemove('bob'), members: arrayUnion('bob'), 'names.bob': 'Bob', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(bob(), 'parties/alice'), { positionMs: 0, updatedAt: serverTimestamp() }));
  await assertFails(deleteDoc(doc(bob(), 'parties/alice')));
  await assertSucceeds(updateDoc(doc(bob(), 'parties/alice'), { members: arrayRemove('bob'), updatedAt: serverTimestamp() }));
  await assertSucceeds(deleteDoc(doc(alice(), 'parties/alice')));
});

test('push devices: the owner registers, updates and removes their phone', async () => {
  const device = (extra = {}) => ({ fid: 'cKx1-fid', platform: 'android', lang: 'es', notify: true, updatedAt: serverTimestamp(), ...extra });
  const db = alice();
  const ref = doc(db, 'users/alice/devices/abcdef0123456789');
  await assertSucceeds(setDoc(ref, device()));
  await assertSucceeds(setDoc(ref, device({ fid: 'new-fid', notify: false })));
  await assertSucceeds(getDoc(ref));
  // Not someone else's, and nothing outside the shape.
  await assertFails(getDoc(doc(bob(), 'users/alice/devices/abcdef0123456789')));
  await assertFails(setDoc(doc(bob(), 'users/alice/devices/bobsphone0001'), device()));
  await assertFails(setDoc(ref, device({ extra: 1 })));
  await assertFails(setDoc(ref, device({ platform: 'web' })));
  await assertFails(setDoc(ref, device({ fid: '' })));
  await assertFails(setDoc(ref, device({ updatedAt: Timestamp.fromMillis(0) })));
  await assertFails(setDoc(doc(db, 'users/alice/devices/x'), device()));
  await assertSucceeds(deleteDoc(ref));
});

test('the radar state is the server\'s alone', async () => {
  await assertFails(getDoc(doc(alice(), 'radarArtists/27')));
  await assertFails(setDoc(doc(alice(), 'radarArtists/27'), { ids: [], checkedAt: serverTimestamp() }));
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
