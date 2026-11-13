// Subsets the artist fonts (assets/fonts) to Latin: each one only draws an
// artist's name (DistortedArtistName), so the rest of their glyphs only
// weighed on the APK. Run from tool/font_subset:
//   npm install && node subset.mjs ../../assets/fonts <font files...>
//
// It calls HarfBuzz's subsetter directly (not subset-font) to keep the
// names looking exactly the same:
//  - no table is dropped: several fonts kern with the legacy `kern` table,
//    which HarfBuzz drops by default;
//  - glyph ids are kept (RETAIN_GIDS), so tables copied as they are still
//    point at the right glyphs;
//  - every layout feature (kerning, ligatures, accents built from marks)
//    is kept for the glyphs that stay.
// Running it again on an already subset font changes nothing.
import { readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { instance } = await WebAssembly.instantiate(
  readFileSync(require.resolve('harfbuzzjs/hb-subset.wasm')));
const hb = instance.exports;

// Basic Latin, Latin-1 and the combining accents some fonts build é or ñ
// from: whatever an artist's name from Deezer can plausibly have.
const ranges = [[0x20, 0x7e], [0xa0, 0xff], [0x300, 0x36f]];

const HB_MEMORY_MODE_WRITABLE = 2;
const HB_SUBSET_SETS_DROP_TABLE_TAG = 3;
const HB_SUBSET_SETS_LAYOUT_FEATURE_TAG = 6;
const HB_SUBSET_SETS_LAYOUT_SCRIPT_TAG = 7;
const HB_SUBSET_FLAGS_RETAIN_GIDS = 0x2;

function subset(font) {
  const heap = () => new Uint8Array(hb.memory.buffer);
  const input = hb.hb_subset_input_create_or_fail();
  if (!input) throw new Error('hb_subset_input_create_or_fail failed');
  const ptr = hb.malloc(font.byteLength);
  heap().set(font, ptr);
  const blob = hb.hb_blob_create(ptr, font.byteLength, HB_MEMORY_MODE_WRITABLE, 0, 0);
  const face = hb.hb_face_create(blob, 0);
  hb.hb_blob_destroy(blob);
  try {
    // Keep every table, every layout feature and script.
    hb.hb_set_clear(hb.hb_subset_input_set(input, HB_SUBSET_SETS_DROP_TABLE_TAG));
    for (const set of [HB_SUBSET_SETS_LAYOUT_FEATURE_TAG, HB_SUBSET_SETS_LAYOUT_SCRIPT_TAG]) {
      const s = hb.hb_subset_input_set(input, set);
      hb.hb_set_clear(s);
      hb.hb_set_invert(s);
    }
    hb.hb_subset_input_set_flags(input, hb.hb_subset_input_get_flags(input) | HB_SUBSET_FLAGS_RETAIN_GIDS);
    const unicodes = hb.hb_subset_input_unicode_set(input);
    for (const [from, to] of ranges) {
      for (let c = from; c <= to; c++) hb.hb_set_add(unicodes, c);
    }

    const out = hb.hb_subset_or_fail(face, input);
    if (!out) throw new Error('hb_subset_or_fail failed');
    const result = hb.hb_face_reference_blob(out);
    const offset = hb.hb_blob_get_data(result, 0);
    const length = hb.hb_blob_get_length(result);
    const bytes = Buffer.from(heap().subarray(offset, offset + length));
    hb.hb_blob_destroy(result);
    hb.hb_face_destroy(out);
    if (!length) throw new Error('empty subset');
    return bytes;
  } finally {
    hb.hb_subset_input_destroy(input);
    hb.hb_face_destroy(face);
    hb.free(ptr);
  }
}

// The font's table tags, from its sfnt header.
function tables(font) {
  const view = new DataView(font.buffer, font.byteOffset, font.byteLength);
  const count = view.getUint16(4);
  const tags = new Set();
  for (let i = 0; i < count; i++) {
    tags.add(String.fromCharCode(...font.subarray(12 + i * 16, 16 + i * 16)));
  }
  return tags;
}

// What HarfBuzz's subsetter can't carry over, so the font is left as it is:
// kerning only in the legacy `kern` table (always dropped by the subsetter;
// with GPOS present, shaping uses GPOS and ignores `kern`), and embedded
// bitmaps, which it drops too.
function whyKeep(font) {
  const t = tables(font);
  if (t.has('kern') && !t.has('GPOS')) return 'kerns with the legacy kern table';
  for (const bitmap of ['EBDT', 'EBLC', 'CBDT', 'CBLC']) {
    if (t.has(bitmap)) return 'has embedded bitmaps';
  }
  return null;
}

const [dir, ...files] = process.argv.slice(2);
for (const f of files) {
  const path = `${dir}/${f}`;
  const before = readFileSync(path);
  const reason = whyKeep(before);
  if (reason) {
    console.log(`${f}: kept, ${reason}`);
    continue;
  }
  const after = subset(before);
  if (after.length >= before.length) {
    console.log(`${f}: kept (${(before.length / 1024).toFixed(0)} KB)`);
    continue;
  }
  writeFileSync(path, after);
  console.log(`${f}: ${(before.length / 1024).toFixed(0)} KB -> ${(after.length / 1024).toFixed(0)} KB`);
}
