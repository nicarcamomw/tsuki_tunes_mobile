import '../../core/localization/app_language.dart';
import '../logic/music_styles.dart';

/// Rarity tiers, gacha style: R (rare), SR (super rare), SSR (super super
/// rare) and UL (ultra). Whether a mask is hidden is [OniMask.secret].
enum MaskRarity { r, sr, ssr, ul }

enum MaskArt {
  tengu,
  kabuki,
  hannya,
  cyberOni,
  // Redrawn in other techniques (tool/mask_styles.py).
  kintsugi,
  hologram,
  sumie,
  glitch,
  pixel,
  neon,
  duo,
  gold,
  ice,
  sakura,
  // Oni types: new elements and materials.
  akaoni,
  raijin,
  namahage,
  kijo,
  kurohannya,
  kibori,
  ishi,
  seidou,
  yurei,
  chinoame,
}

/// A collectible mask, unlocked by an achievement or a week's challenges:
/// one of the original illustrations ([art], maybe dyed), or its own
/// [image] from a tier folder (assets/images/masks/r|sr|ssr|ul/).
class OniMask {
  final String id;
  final String kanji;
  final MaskArt? art;

  /// Its own illustration (510×637, transparent), instead of an [art].
  final String? image;
  final MaskRarity rarity;
  /// Hidden until unlocked: no name, no hint.
  final bool secret;
  /// 4x5 color matrix applied to the art, or null for the original colors.
  final List<double>? dye;
  /// For counted goals (e.g. 100 plays), the target shown as progress.
  final int? goal;

  /// What [goal] counts, for the masks unlocked by a counter
  /// (MaskProvider.counterValue): 'style:metal', 'streak', 'amb:fire'...
  final String? counter;
  /// Won by completing a week's three challenges, not by an achievement.
  final bool weekly;
  final Map<AppLanguage, String> names;
  final Map<AppLanguage, String> descriptions;
  /// For secret masks: a riddle shown, still locked, once the user has
  /// collected a few masks (MaskProvider.secretHintsShown).
  final Map<AppLanguage, String>? hints;

  const OniMask({
    required this.id,
    required this.kanji,
    this.art,
    this.image,
    required this.rarity,
    required this.names,
    required this.descriptions,
    this.secret = false,
    this.dye,
    this.goal,
    this.counter,
    this.weekly = false,
    this.hints,
  }) : assert((art == null) != (image == null), 'a mask has an art or its own image');

  String asset() => image ?? switch (art!) {
        MaskArt.tengu => 'assets/images/tengu.png',
        MaskArt.kabuki => 'assets/images/oni.png',
        MaskArt.hannya => 'assets/images/hannya.png',
        MaskArt.cyberOni => 'assets/images/cyber_oni_mask.png',
        final other => 'assets/images/masks/${other.name}.webp',
      };

  String name(AppLanguage l) => names[l] ?? names[AppLanguage.es]!;
  String description(AppLanguage l) => descriptions[l] ?? descriptions[AppLanguage.es]!;
  String? hint(AppLanguage l) => hints == null ? null : (hints![l] ?? hints![AppLanguage.es]);

}

/// Luminance-preserving tint: keeps the illustration's shading and detail,
/// recolors it toward [argb] (a 0xAARRGGBB color).
List<double> maskDye(int argb, {double strength = 0.85, double gain = 1.25}) {
  final r = ((argb >> 16) & 0xFF) / 255, g = ((argb >> 8) & 0xFF) / 255, b = (argb & 0xFF) / 255;
  final keep = 1 - strength;
  List<double> row(double c, int channel) {
    final k = strength * c * gain;
    return [
      (channel == 0 ? keep : 0) + k * 0.2126,
      (channel == 1 ? keep : 0) + k * 0.7152,
      (channel == 2 ? keep : 0) + k * 0.0722,
      0,
      0,
    ];
  }

  return [...row(r, 0), ...row(g, 1), ...row(b, 2), 0, 0, 0, 1, 0];
}

/// Photographic negative with a cold tint: eerie on purpose.
const List<double> _negative = [
  -0.85, 0, 0, 0, 200,
  0, -0.95, 0, 0, 235,
  0, 0, -1.0, 0, 255,
  0, 0, 0, 1, 0,
];

class MaskCatalog {
  static final List<OniMask> all = [
    const OniMask(
      id: 'hajime',
      kanji: '初',
      art: MaskArt.tengu,
      rarity: MaskRarity.r,
      names: {
        AppLanguage.es: 'Primer Eco',
        AppLanguage.en: 'First Echo',
        AppLanguage.ja: '初の響き',
      },
      descriptions: {
        AppLanguage.es: 'Escucha tu primera canción completa.',
        AppLanguage.en: 'Listen to your first full song.',
        AppLanguage.ja: '初めて曲を最後まで聴く。',
      },
    ),
    const OniMask(
      id: 'hyaku',
      kanji: '百',
      art: MaskArt.kabuki,
      rarity: MaskRarity.r,
      goal: 250,
      names: {
        AppLanguage.es: 'Cien Voces',
        AppLanguage.en: 'Hundred Voices',
        AppLanguage.ja: '百の声',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 250 canciones.',
        AppLanguage.en: 'Listen to 250 songs.',
        AppLanguage.ja: '250曲を聴く。',
      },
    ),
    const OniMask(
      id: 'sen',
      kanji: '千',
      art: MaskArt.hannya,
      rarity: MaskRarity.sr,
      goal: 2500,
      names: {
        AppLanguage.es: 'Mil Ecos',
        AppLanguage.en: 'Thousand Echoes',
        AppLanguage.ja: '千の響き',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 2500 canciones.',
        AppLanguage.en: 'Listen to 2500 songs.',
        AppLanguage.ja: '2500曲を聴く。',
      },
    ),
    OniMask(
      id: 'oshi',
      kanji: '推',
      art: MaskArt.kabuki,
      rarity: MaskRarity.r,
      goal: 100,
      dye: maskDye(0xFFFF6B9D),
      names: const {
        AppLanguage.es: 'Devoción',
        AppLanguage.en: 'Devotion',
        AppLanguage.ja: '推し',
      },
      descriptions: const {
        AppLanguage.es: 'Escucha 100 canciones de un mismo artista.',
        AppLanguage.en: 'Listen to 100 songs by the same artist.',
        AppLanguage.ja: '同じアーティストの曲を100回聴く。',
      },
    ),
    OniMask(
      id: 'tabibito',
      kanji: '旅',
      art: MaskArt.tengu,
      rarity: MaskRarity.r,
      goal: 20,
      dye: maskDye(0xFF2EE6A6),
      names: const {
        AppLanguage.es: 'Viajero',
        AppLanguage.en: 'Wanderer',
        AppLanguage.ja: '旅人',
      },
      descriptions: const {
        AppLanguage.es: 'Descubre 20 artistas nuevos en una semana.',
        AppLanguage.en: 'Discover 20 new artists in one week.',
        AppLanguage.ja: '1週間で新しいアーティストを20組発見する。',
      },
    ),
    OniMask(
      id: 'kanpeki',
      kanji: '完',
      art: MaskArt.hannya,
      rarity: MaskRarity.r,
      dye: maskDye(0xFFE6ECF5, strength: 0.9, gain: 1.45),
      names: const {
        AppLanguage.es: 'Álbum Perfecto',
        AppLanguage.en: 'Perfect Album',
        AppLanguage.ja: '完璧',
      },
      descriptions: const {
        AppLanguage.es: 'Escucha un álbum entero sin saltar ninguna canción.',
        AppLanguage.en: 'Listen to a whole album without skipping a song.',
        AppLanguage.ja: 'アルバムを1曲も飛ばさずに最後まで聴く。',
      },
    ),
    OniMask(
      id: 'ame',
      kanji: '雨',
      art: MaskArt.kabuki,
      rarity: MaskRarity.r,
      goal: 10,
      dye: maskDye(0xFF4FA8FF),
      names: const {
        AppLanguage.es: 'Espíritu de la Lluvia',
        AppLanguage.en: 'Rain Spirit',
        AppLanguage.ja: '雨の精',
      },
      descriptions: const {
        AppLanguage.es: 'Escucha 10 horas de lluvia o tormenta en el ambiente.',
        AppLanguage.en: 'Listen to 10 hours of rain or storm ambience.',
        AppLanguage.ja: '雨や嵐の環境音を10時間聴く。',
      },
    ),
    OniMask(
      id: 'mangetsu',
      kanji: '月',
      art: MaskArt.kabuki,
      rarity: MaskRarity.r,
      dye: maskDye(0xFFD6E0F5, strength: 0.7, gain: 1.35),
      names: const {
        AppLanguage.es: 'Luna Llena',
        AppLanguage.en: 'Full Moon',
        AppLanguage.ja: '満月',
      },
      descriptions: const {
        AppLanguage.es: 'Escucha música en una noche de luna llena.',
        AppLanguage.en: 'Listen to music on a full moon night.',
        AppLanguage.ja: '満月の夜に音楽を聴く。',
      },
    ),
    OniMask(
      id: 'yoru',
      kanji: '夜',
      art: MaskArt.hannya,
      rarity: MaskRarity.r,
      goal: 50,
      dye: maskDye(0xFF7A5CFF),
      names: const {
        AppLanguage.es: 'Criatura Nocturna',
        AppLanguage.en: 'Night Creature',
        AppLanguage.ja: '夜の者',
      },
      descriptions: const {
        AppLanguage.es: 'Escucha 50 canciones entre la medianoche y las 5 AM.',
        AppLanguage.en: 'Listen to 50 songs between midnight and 5 AM.',
        AppLanguage.ja: '深夜0時から朝5時の間に50曲聴く。',
      },
    ),
    OniMask(
      id: 'mimi',
      kanji: '耳',
      art: MaskArt.tengu,
      rarity: MaskRarity.sr,
      dye: maskDye(0xFFFFC94A, gain: 1.35),
      names: const {
        AppLanguage.es: 'Oído Absoluto',
        AppLanguage.en: 'Perfect Pitch',
        AppLanguage.ja: '絶対音感',
      },
      descriptions: const {
        AppLanguage.es: 'Adivina el reto diario con solo 1 segundo.',
        AppLanguage.en: 'Guess the daily challenge from 1 second.',
        AppLanguage.ja: 'デイリーチャレンジを1秒で当てる。',
      },
    ),
    OniMask(
      id: 'ren',
      kanji: '連',
      art: MaskArt.tengu,
      rarity: MaskRarity.sr,
      goal: 14,
      dye: maskDye(0xFFB026FF),
      names: const {
        AppLanguage.es: 'Racha Imparable',
        AppLanguage.en: 'Unstoppable Streak',
        AppLanguage.ja: '連勝街道',
      },
      descriptions: const {
        AppLanguage.es: 'Gana el reto diario 14 días seguidos.',
        AppLanguage.en: 'Win the daily challenge 14 days in a row.',
        AppLanguage.ja: 'デイリーチャレンジに14日連続で勝つ。',
      },
    ),
    const OniMask(
      id: 'sanji',
      kanji: '三',
      art: MaskArt.kabuki,
      rarity: MaskRarity.sr,
      secret: true,
      dye: _negative,
      names: {
        AppLanguage.es: '3:33',
        AppLanguage.en: '3:33',
        AppLanguage.ja: '三時三十三分',
      },
      descriptions: {
        AppLanguage.es: 'Escuchaste música a las 3:33 de la madrugada.',
        AppLanguage.en: 'You were listening to music at 3:33 AM.',
        AppLanguage.ja: '午前3時33分に音楽を聴いていた。',
      },
      hints: {
        AppLanguage.es: 'Cuando el reloj repite tres veces el mismo número, algo despierta.',
        AppLanguage.en: 'When the clock shows the same number three times, something wakes up.',
        AppLanguage.ja: '時計が同じ数字を三つ並べるとき、何かが目を覚ます。',
      },
    ),
    OniMask(
      id: 'chizuki',
      kanji: '血',
      art: MaskArt.tengu,
      rarity: MaskRarity.sr,
      secret: true,
      dye: maskDye(0xFFB0101E, strength: 0.75, gain: 1.4),
      names: const {
        AppLanguage.es: 'Luna de Sangre',
        AppLanguage.en: 'Blood Moon',
        AppLanguage.ja: '血月',
      },
      descriptions: const {
        AppLanguage.es: 'Viste un eclipse lunar dentro de Tsuki.',
        AppLanguage.en: 'You saw a lunar eclipse inside Tsuki.',
        AppLanguage.ja: 'Tsukiの中で月食を見た。',
      },
      hints: const {
        AppLanguage.es: 'A veces la luna se tiñe de rojo. Mírala desde aquí.',
        AppLanguage.en: 'Sometimes the moon turns red. Watch it from here.',
        AppLanguage.ja: '月が赤く染まる夜がある。ここから見届けよ。',
      },
    ),
    OniMask(
      id: 'shuchaku',
      kanji: '執',
      art: MaskArt.hannya,
      rarity: MaskRarity.sr,
      secret: true,
      dye: maskDye(0xFF9CFF3A),
      names: const {
        AppLanguage.es: 'Obsesión',
        AppLanguage.en: 'Obsession',
        AppLanguage.ja: '執着',
      },
      descriptions: const {
        AppLanguage.es: 'Escuchaste la misma canción 15 veces en un día.',
        AppLanguage.en: 'You played the same song 15 times in one day.',
        AppLanguage.ja: '1日に同じ曲を15回聴いた。',
      },
      hints: const {
        AppLanguage.es: 'Hay canciones que no puedes soltar. ¿Cuántas veces en un solo día?',
        AppLanguage.en: "Some songs you just can't let go of. How many times in one day?",
        AppLanguage.ja: '手放せない曲がある。一日に何度聴ける？',
      },
    ),
    const OniMask(
      id: 'hannya',
      kanji: '般',
      art: MaskArt.cyberOni,
      rarity: MaskRarity.sr,
      secret: true,
      names: {
        AppLanguage.es: 'Noche de Hannya',
        AppLanguage.en: 'Hannya Night',
        AppLanguage.ja: '般若の夜',
      },
      descriptions: {
        AppLanguage.es: 'Escuchaste música la noche de Halloween.',
        AppLanguage.en: 'You listened to music on Halloween night.',
        AppLanguage.ja: 'ハロウィンの夜に音楽を聴いた。',
      },
      hints: {
        AppLanguage.es: 'Una noche al año, las máscaras salen a la calle.',
        AppLanguage.en: 'One night a year, the masks walk the streets.',
        AppLanguage.ja: '一年に一夜、面たちが街を歩く。',
      },
    ),
    OniMask(
      id: 'oni',
      kanji: '鬼',
      art: MaskArt.cyberOni,
      rarity: MaskRarity.ssr,
      secret: true,
      dye: maskDye(0xFFFFB02E, strength: 0.55, gain: 1.3),
      names: const {
        AppLanguage.es: 'El Oni',
        AppLanguage.en: 'The Oni',
        AppLanguage.ja: '鬼',
      },
      descriptions: const {
        AppLanguage.es: 'Reuniste todas las máscaras de logros.',
        AppLanguage.en: 'You collected every achievement mask.',
        AppLanguage.ja: '実績の面をすべて集めた。',
      },
      hints: const {
        AppLanguage.es: 'Reúne a todos los demás y él vendrá.',
        AppLanguage.en: 'Gather all the others and it will come.',
        AppLanguage.ja: '他のすべてを集めれば、それは来る。',
      },
    ),
    // Weekly challenge rewards, in the order they're handed out.
    const OniMask(
      id: 'sumi',
      kanji: '墨',
      art: MaskArt.sumie,
      rarity: MaskRarity.r,
      weekly: true,
      names: {
        AppLanguage.es: 'Tinta',
        AppLanguage.en: 'Ink',
        AppLanguage.ja: '墨',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'hachi',
      kanji: '点',
      art: MaskArt.pixel,
      rarity: MaskRarity.r,
      weekly: true,
      names: {
        AppLanguage.es: '8 Bits',
        AppLanguage.en: '8-Bit',
        AppLanguage.ja: '八ビット',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'ranpa',
      kanji: '乱',
      art: MaskArt.glitch,
      rarity: MaskRarity.r,
      weekly: true,
      names: {
        AppLanguage.es: 'Señal Rota',
        AppLanguage.en: 'Broken Signal',
        AppLanguage.ja: '乱波',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'kori',
      kanji: '氷',
      art: MaskArt.ice,
      rarity: MaskRarity.r,
      weekly: true,
      names: {
        AppLanguage.es: 'Hielo Eterno',
        AppLanguage.en: 'Eternal Ice',
        AppLanguage.ja: '永久氷',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'hanami',
      kanji: '桜',
      art: MaskArt.sakura,
      rarity: MaskRarity.r,
      weekly: true,
      names: {
        AppLanguage.es: 'Hanami',
        AppLanguage.en: 'Hanami',
        AppLanguage.ja: '花見',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'maboroshi',
      kanji: '幻',
      art: MaskArt.hologram,
      rarity: MaskRarity.sr,
      weekly: true,
      names: {
        AppLanguage.es: 'Fantasma Digital',
        AppLanguage.en: 'Digital Ghost',
        AppLanguage.ja: '幻影',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'hikari',
      kanji: '光',
      art: MaskArt.neon,
      rarity: MaskRarity.sr,
      weekly: true,
      names: {
        AppLanguage.es: 'Neón Nocturno',
        AppLanguage.en: 'Night Neon',
        AppLanguage.ja: '夜の光',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'futaomote',
      kanji: '双',
      art: MaskArt.duo,
      rarity: MaskRarity.sr,
      weekly: true,
      names: {
        AppLanguage.es: 'Dos Caras',
        AppLanguage.en: 'Two Faces',
        AppLanguage.ja: '二つの顔',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'kintsugi',
      kanji: '継',
      art: MaskArt.kintsugi,
      rarity: MaskRarity.sr,
      weekly: true,
      names: {
        AppLanguage.es: 'Kintsugi',
        AppLanguage.en: 'Kintsugi',
        AppLanguage.ja: '金継ぎ',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'ougon',
      kanji: '輝',
      art: MaskArt.gold,
      rarity: MaskRarity.sr,
      weekly: true,
      names: {
        AppLanguage.es: 'Oro Puro',
        AppLanguage.en: 'Pure Gold',
        AppLanguage.ja: '黄金',
      },
      descriptions: _weeklyDescription,
    ),
    // Oni types.
    const OniMask(
      id: 'akaoni',
      kanji: '赤',
      art: MaskArt.akaoni,
      rarity: MaskRarity.r,
      weekly: true,
      names: {
        AppLanguage.es: 'Aka Oni',
        AppLanguage.en: 'Red Oni',
        AppLanguage.ja: '赤鬼',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'kijo',
      kanji: '女',
      art: MaskArt.kijo,
      rarity: MaskRarity.r,
      weekly: true,
      names: {
        AppLanguage.es: 'Kijo',
        AppLanguage.en: 'Demon Woman',
        AppLanguage.ja: '鬼女',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'kibori',
      kanji: '木',
      art: MaskArt.kibori,
      rarity: MaskRarity.r,
      weekly: true,
      names: {
        AppLanguage.es: 'Talla de Madera',
        AppLanguage.en: 'Woodcarving',
        AppLanguage.ja: '木彫り',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'ishi',
      kanji: '石',
      art: MaskArt.ishi,
      rarity: MaskRarity.r,
      weekly: true,
      names: {
        AppLanguage.es: 'Yasha de Piedra',
        AppLanguage.en: 'Stone Yasha',
        AppLanguage.ja: '石の夜叉',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'seidou',
      kanji: '銅',
      art: MaskArt.seidou,
      rarity: MaskRarity.r,
      weekly: true,
      names: {
        AppLanguage.es: 'Bronce Antiguo',
        AppLanguage.en: 'Old Bronze',
        AppLanguage.ja: '青銅',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'raijin',
      kanji: '雷',
      art: MaskArt.raijin,
      rarity: MaskRarity.sr,
      weekly: true,
      names: {
        AppLanguage.es: 'Raijin',
        AppLanguage.en: 'Raijin',
        AppLanguage.ja: '雷神',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'namahage',
      kanji: '剥',
      art: MaskArt.namahage,
      rarity: MaskRarity.sr,
      weekly: true,
      names: {
        AppLanguage.es: 'Namahage',
        AppLanguage.en: 'Namahage',
        AppLanguage.ja: 'なまはげ',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'kurohannya',
      kanji: '黒',
      art: MaskArt.kurohannya,
      rarity: MaskRarity.sr,
      weekly: true,
      names: {
        AppLanguage.es: 'Hannya Negra',
        AppLanguage.en: 'Black Hannya',
        AppLanguage.ja: '黒般若',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'yurei',
      kanji: '霊',
      art: MaskArt.yurei,
      rarity: MaskRarity.sr,
      weekly: true,
      names: {
        AppLanguage.es: 'Yūrei',
        AppLanguage.en: 'Yūrei',
        AppLanguage.ja: '幽霊',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'chinoame',
      kanji: '血',
      art: MaskArt.chinoame,
      rarity: MaskRarity.sr,
      weekly: true,
      names: {
        AppLanguage.es: 'Lluvia de Sangre',
        AppLanguage.en: 'Blood Rain',
        AppLanguage.ja: '血の雨',
      },
      descriptions: _weeklyDescription,
    ),
    // Illustrations made for Tsuki (tool/add_mask.py), each with its own
    // achievement, matched to its design: styles, habits, the app's sounds.
    const OniMask(
      id: 'tetsu',
      kanji: '鉄',
      image: 'assets/images/masks/r/tetsu.webp',
      rarity: MaskRarity.r,
      counter: 'style:metal',
      goal: 30,
      names: {
        AppLanguage.es: 'Oni de Acero',
        AppLanguage.en: 'Steel Oni',
        AppLanguage.ja: '鉄の鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 30 canciones de metal.',
        AppLanguage.en: 'Listen to 30 metal songs.',
        AppLanguage.ja: 'メタルを30曲聴く。',
      },
    ),
    const OniMask(
      id: 'sabi',
      kanji: '錆',
      image: 'assets/images/masks/r/sabi.webp',
      rarity: MaskRarity.r,
      counter: 'style:rock',
      goal: 30,
      names: {
        AppLanguage.es: 'Óxido',
        AppLanguage.en: 'Rust',
        AppLanguage.ja: '錆鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 30 canciones de rock.',
        AppLanguage.en: 'Listen to 30 rock songs.',
        AppLanguage.ja: 'ロックを30曲聴く。',
      },
    ),
    const OniMask(
      id: 'kuchi',
      kanji: '朽',
      image: 'assets/images/masks/r/kuchi.webp',
      rarity: MaskRarity.r,
      counter: 'style:punk',
      goal: 20,
      names: {
        AppLanguage.es: 'Chatarra',
        AppLanguage.en: 'Scrap',
        AppLanguage.ja: '朽ちた面',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 20 canciones de punk.',
        AppLanguage.en: 'Listen to 20 punk songs.',
        AppLanguage.ja: 'パンクを20曲聴く。',
      },
    ),
    const OniMask(
      id: 'kikai',
      kanji: '機',
      image: 'assets/images/masks/r/kikai.webp',
      rarity: MaskRarity.r,
      counter: 'style:electronic',
      goal: 30,
      names: {
        AppLanguage.es: 'Mecha',
        AppLanguage.en: 'Mecha',
        AppLanguage.ja: '機械鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 30 canciones de música electrónica.',
        AppLanguage.en: 'Listen to 30 electronic songs.',
        AppLanguage.ja: 'エレクトロニックを30曲聴く。',
      },
    ),
    const OniMask(
      id: 'murasaki',
      kanji: '紫',
      image: 'assets/images/masks/r/murasaki.webp',
      rarity: MaskRarity.r,
      counter: 'style:hiphop',
      goal: 30,
      names: {
        AppLanguage.es: 'Grafiti Violeta',
        AppLanguage.en: 'Violet Graffiti',
        AppLanguage.ja: '紫の落書き',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 30 canciones de hip-hop o rap.',
        AppLanguage.en: 'Listen to 30 hip-hop or rap songs.',
        AppLanguage.ja: 'ヒップホップ・ラップを30曲聴く。',
      },
    ),
    const OniMask(
      id: 'shiro',
      kanji: '白',
      image: 'assets/images/masks/r/shiro.webp',
      rarity: MaskRarity.r,
      counter: 'style:pop',
      goal: 30,
      names: {
        AppLanguage.es: 'Oni Blanco',
        AppLanguage.en: 'White Oni',
        AppLanguage.ja: '白鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 30 canciones de pop.',
        AppLanguage.en: 'Listen to 30 pop songs.',
        AppLanguage.ja: 'ポップを30曲聴く。',
      },
    ),
    const OniMask(
      id: 'jouki',
      kanji: '蒸',
      image: 'assets/images/masks/r/jouki.webp',
      rarity: MaskRarity.r,
      counter: 'style:jazz',
      goal: 20,
      names: {
        AppLanguage.es: 'Vapor',
        AppLanguage.en: 'Steam',
        AppLanguage.ja: '蒸気',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 20 canciones de jazz, soul o blues.',
        AppLanguage.en: 'Listen to 20 jazz, soul or blues songs.',
        AppLanguage.ja: 'ジャズ・ソウル・ブルースを20曲聴く。',
      },
    ),
    const OniMask(
      id: 'hone',
      kanji: '骨',
      image: 'assets/images/masks/r/hone.webp',
      rarity: MaskRarity.r,
      counter: 'style:folk',
      goal: 20,
      names: {
        AppLanguage.es: 'Hueso',
        AppLanguage.en: 'Bone',
        AppLanguage.ja: '骨鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 20 canciones de folk o acústicas.',
        AppLanguage.en: 'Listen to 20 folk or acoustic songs.',
        AppLanguage.ja: 'フォーク・アコースティックを20曲聴く。',
      },
    ),
    const OniMask(
      id: 'akari',
      kanji: '灯',
      image: 'assets/images/masks/r/akari.webp',
      rarity: MaskRarity.r,
      counter: 'style:synthwave',
      goal: 20,
      names: {
        AppLanguage.es: 'Luz de Neón',
        AppLanguage.en: 'Neon Light',
        AppLanguage.ja: 'ネオンの灯',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 20 canciones de synthwave o de los 80.',
        AppLanguage.en: 'Listen to 20 synthwave or 80s songs.',
        AppLanguage.ja: 'シンセウェイヴ・80年代を20曲聴く。',
      },
    ),
    const OniMask(
      id: 'homura',
      kanji: '焔',
      image: 'assets/images/masks/sr/homura.webp',
      rarity: MaskRarity.sr,
      counter: 'fast',
      goal: 100,
      names: {
        AppLanguage.es: 'Llama de Cobre',
        AppLanguage.en: 'Copper Flame',
        AppLanguage.ja: '焔',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 100 canciones rápidas (150 BPM o más).',
        AppLanguage.en: 'Listen to 100 fast songs (150 BPM or more).',
        AppLanguage.ja: '速い曲（150BPM以上）を100曲聴く。',
      },
    ),
    const OniMask(
      id: 'doku',
      kanji: '毒',
      image: 'assets/images/masks/r/doku.webp',
      rarity: MaskRarity.r,
      counter: 'explicit',
      goal: 30,
      names: {
        AppLanguage.es: 'Tóxico',
        AppLanguage.en: 'Toxic',
        AppLanguage.ja: '毒鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 30 canciones con contenido explícito.',
        AppLanguage.en: 'Listen to 30 explicit songs.',
        AppLanguage.ja: '過激な表現のある曲を30曲聴く。',
      },
    ),
    const OniMask(
      id: 'meisai',
      kanji: '迷',
      image: 'assets/images/masks/r/meisai.webp',
      rarity: MaskRarity.r,
      counter: 'hidden',
      goal: 20,
      names: {
        AppLanguage.es: 'Camuflaje',
        AppLanguage.en: 'Camouflage',
        AppLanguage.ja: '迷彩鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 20 joyas ocultas: canciones que casi nadie conoce.',
        AppLanguage.en: 'Listen to 20 hidden gems: songs hardly anyone knows.',
        AppLanguage.ja: '隠れた名曲を20曲聴く。',
      },
    ),
    const OniMask(
      id: 'yami',
      kanji: '闇',
      image: 'assets/images/masks/r/yami.webp',
      rarity: MaskRarity.r,
      counter: 'sleep',
      goal: 5,
      names: {
        AppLanguage.es: 'Oni de Sombra',
        AppLanguage.en: 'Shadow Oni',
        AppLanguage.ja: '闇鬼',
      },
      descriptions: {
        AppLanguage.es: 'Duérmete con el temporizador de sueño 5 noches.',
        AppLanguage.en: 'Fall asleep with the sleep timer on 5 nights.',
        AppLanguage.ja: 'スリープタイマーで5晩眠る。',
      },
    ),
    const OniMask(
      id: 'kin_oni',
      kanji: '金',
      image: 'assets/images/masks/sr/kin_oni.webp',
      rarity: MaskRarity.sr,
      counter: 'hits',
      goal: 100,
      names: {
        AppLanguage.es: 'Oni Dorado',
        AppLanguage.en: 'Golden Oni',
        AppLanguage.ja: '金鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 100 grandes éxitos.',
        AppLanguage.en: 'Listen to 100 big hits.',
        AppLanguage.ja: '大ヒット曲を100曲聴く。',
      },
    ),
    const OniMask(
      id: 'urushi',
      kanji: '漆',
      image: 'assets/images/masks/r/urushi.webp',
      rarity: MaskRarity.r,
      counter: 'style:jpop',
      goal: 30,
      names: {
        AppLanguage.es: 'Laca',
        AppLanguage.en: 'Lacquer',
        AppLanguage.ja: '漆',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 30 canciones de J-pop, J-rock o anime.',
        AppLanguage.en: 'Listen to 30 J-pop, J-rock or anime songs.',
        AppLanguage.ja: 'J-POP・J-ROCK・アニメを30曲聴く。',
      },
    ),
    const OniMask(
      id: 'rakugaki',
      kanji: '彩',
      image: 'assets/images/masks/sr/rakugaki.webp',
      rarity: MaskRarity.sr,
      counter: 'style:latin',
      goal: 100,
      names: {
        AppLanguage.es: 'Grafiti Neón',
        AppLanguage.en: 'Neon Graffiti',
        AppLanguage.ja: '落書き',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 100 canciones de música urbana latina.',
        AppLanguage.en: 'Listen to 100 Latin urban songs.',
        AppLanguage.ja: 'ラテン・アーバンを100曲聴く。',
      },
    ),
    const OniMask(
      id: 'eizou',
      kanji: '映',
      image: 'assets/images/masks/r/eizou.webp',
      rarity: MaskRarity.r,
      counter: 'style:vocaloid',
      goal: 15,
      names: {
        AppLanguage.es: 'Proyección',
        AppLanguage.en: 'Projection',
        AppLanguage.ja: '映像',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 15 canciones de Vocaloid o hyperpop.',
        AppLanguage.en: 'Listen to 15 Vocaloid or hyperpop songs.',
        AppLanguage.ja: 'ボカロ・ハイパーポップを15曲聴く。',
      },
    ),
    const OniMask(
      id: 'mori',
      kanji: '森',
      image: 'assets/images/masks/r/mori.webp',
      rarity: MaskRarity.r,
      counter: 'style:lofi',
      goal: 30,
      names: {
        AppLanguage.es: 'Espíritu del Bosque',
        AppLanguage.en: 'Forest Spirit',
        AppLanguage.ja: '森の鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 30 canciones de lo-fi o chill.',
        AppLanguage.en: 'Listen to 30 lo-fi or chill songs.',
        AppLanguage.ja: 'ローファイ・チルを30曲聴く。',
      },
    ),
    const OniMask(
      id: 'kumo',
      kanji: '雲',
      image: 'assets/images/masks/sr/kumo.webp',
      rarity: MaskRarity.sr,
      counter: 'style:indie',
      goal: 100,
      names: {
        AppLanguage.es: 'Nube Violeta',
        AppLanguage.en: 'Violet Cloud',
        AppLanguage.ja: '紫雲',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 100 canciones de indie o alternativo.',
        AppLanguage.en: 'Listen to 100 indie or alternative songs.',
        AppLanguage.ja: 'インディー・オルタナを100曲聴く。',
      },
    ),
    const OniMask(
      id: 'suishou',
      kanji: '晶',
      image: 'assets/images/masks/sr/suishou.webp',
      rarity: MaskRarity.sr,
      counter: 'style:classical',
      goal: 60,
      names: {
        AppLanguage.es: 'Cristal',
        AppLanguage.en: 'Crystal',
        AppLanguage.ja: '水晶',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 60 canciones de música clásica, instrumental o bandas sonoras.',
        AppLanguage.en: 'Listen to 60 classical, instrumental or soundtrack pieces.',
        AppLanguage.ja: 'クラシック・インスト・サントラを60曲聴く。',
      },
    ),
    const OniMask(
      id: 'hisui',
      kanji: '翠',
      image: 'assets/images/masks/r/hisui.webp',
      rarity: MaskRarity.r,
      counter: 'countries',
      goal: 5,
      names: {
        AppLanguage.es: 'Jade',
        AppLanguage.en: 'Jade',
        AppLanguage.ja: '翡翠',
      },
      descriptions: {
        AppLanguage.es: 'Escucha música de 5 países distintos.',
        AppLanguage.en: 'Listen to music from 5 different countries.',
        AppLanguage.ja: '5か国の音楽を聴く。',
      },
    ),
    const OniMask(
      id: 'inazuma',
      kanji: '電',
      image: 'assets/images/masks/sr/inazuma.webp',
      rarity: MaskRarity.sr,
      counter: 'amb:storm',
      goal: 5,
      names: {
        AppLanguage.es: 'Rayo',
        AppLanguage.en: 'Lightning',
        AppLanguage.ja: '稲妻',
      },
      descriptions: {
        AppLanguage.es: 'Escucha música durante una tormenta de verdad (con el clima activado), o 5 horas con el sonido de tormenta.',
        AppLanguage.en: 'Listen to music during a real storm (with weather on), or 5 hours with the storm sound.',
        AppLanguage.ja: '本物の嵐の中で聴く（天気オン）、または嵐の音と5時間聴く。',
      },
    ),
    const OniMask(
      id: 'tsurara',
      kanji: '凍',
      image: 'assets/images/masks/r/tsurara.webp',
      rarity: MaskRarity.r,
      counter: 'cold',
      names: {
        AppLanguage.es: 'Escarcha',
        AppLanguage.en: 'Frost',
        AppLanguage.ja: '凍鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha música con 5 °C o menos (necesita el clima activado).',
        AppLanguage.en: 'Listen to music at 5 °C or colder (needs weather on).',
        AppLanguage.ja: '5°C以下で音楽を聴く（天気オンが必要）。',
      },
    ),
    const OniMask(
      id: 'fubuki',
      kanji: '雪',
      image: 'assets/images/masks/sr/fubuki.webp',
      rarity: MaskRarity.sr,
      counter: 'amb:wind',
      goal: 8,
      names: {
        AppLanguage.es: 'Ventisca',
        AppLanguage.en: 'Blizzard',
        AppLanguage.ja: '吹雪',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 8 horas con el sonido de viento.',
        AppLanguage.en: 'Listen for 8 hours with the wind sound.',
        AppLanguage.ja: '風の音と8時間聴く。',
      },
    ),
    const OniMask(
      id: 'hinome',
      kanji: '火',
      image: 'assets/images/masks/sr/hinome.webp',
      rarity: MaskRarity.sr,
      counter: 'marathon',
      goal: 180,
      names: {
        AppLanguage.es: 'Ojo de Fuego',
        AppLanguage.en: 'Fire Eye',
        AppLanguage.ja: '火の目',
      },
      descriptions: {
        AppLanguage.es: 'Maratón: 3 horas de música seguidas.',
        AppLanguage.en: 'Marathon: 3 hours of music in a row.',
        AppLanguage.ja: 'マラソン：3時間連続で音楽を聴く。',
      },
    ),
    const OniMask(
      id: 'yougan',
      kanji: '溶',
      image: 'assets/images/masks/sr/yougan.webp',
      rarity: MaskRarity.sr,
      counter: 'amb:fire',
      goal: 8,
      names: {
        AppLanguage.es: 'Lava',
        AppLanguage.en: 'Lava',
        AppLanguage.ja: '溶岩鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 8 horas con el sonido de fogata.',
        AppLanguage.en: 'Listen for 8 hours with the campfire sound.',
        AppLanguage.ja: '焚き火の音と8時間聴く。',
      },
    ),
    const OniMask(
      id: 'umi',
      kanji: '海',
      image: 'assets/images/masks/ssr/umi.webp',
      rarity: MaskRarity.ssr,
      counter: 'amb:waves',
      goal: 15,
      names: {
        AppLanguage.es: 'Oni del Mar',
        AppLanguage.en: 'Sea Oni',
        AppLanguage.ja: '海鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 15 horas con el sonido de olas.',
        AppLanguage.en: 'Listen for 15 hours with the waves sound.',
        AppLanguage.ja: '波の音と15時間聴く。',
      },
    ),
    const OniMask(
      id: 'jiki',
      kanji: '磁',
      image: 'assets/images/masks/sr/jiki.webp',
      rarity: MaskRarity.sr,
      counter: 'away',
      names: {
        AppLanguage.es: 'Porcelana',
        AppLanguage.en: 'Porcelain',
        AppLanguage.ja: '磁器',
      },
      descriptions: {
        AppLanguage.es: 'Vuelve: escucha música después de 14 días o más sin hacerlo. Lo roto se repara con oro.',
        AppLanguage.en: 'Come back: listen again after 14 days or more away. What breaks is mended with gold.',
        AppLanguage.ja: '14日以上空けて戻ってくる。壊れたものは金で継がれる。',
      },
    ),
    const OniMask(
      id: 'kanmuri',
      kanji: '冠',
      image: 'assets/images/masks/ssr/kanmuri.webp',
      rarity: MaskRarity.ssr,
      counter: 'albums',
      goal: 10,
      names: {
        AppLanguage.es: 'Rey de Hierro',
        AppLanguage.en: 'Iron King',
        AppLanguage.ja: '鉄の王',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 10 álbumes completos, en orden y sin saltar canciones.',
        AppLanguage.en: 'Play 10 whole albums in order, without skipping.',
        AppLanguage.ja: 'アルバムを10枚、順番に飛ばさず聴く。',
      },
    ),
    const OniMask(
      id: 'bushi',
      kanji: '武',
      image: 'assets/images/masks/ssr/bushi.webp',
      rarity: MaskRarity.ssr,
      counter: 'streak',
      goal: 30,
      names: {
        AppLanguage.es: 'Bushi',
        AppLanguage.en: 'Bushi',
        AppLanguage.ja: '武士',
      },
      descriptions: {
        AppLanguage.es: 'Racha de 30 días seguidos con música.',
        AppLanguage.en: 'A 30-day streak of music.',
        AppLanguage.ja: '30日連続で音楽を聴く。',
      },
    ),
    const OniMask(
      id: 'kabuto',
      kanji: '兜',
      image: 'assets/images/masks/ssr/kabuto.webp',
      rarity: MaskRarity.ssr,
      counter: 'runs',
      goal: 15,
      names: {
        AppLanguage.es: 'Kabuto',
        AppLanguage.en: 'Kabuto',
        AppLanguage.ja: '兜',
      },
      descriptions: {
        AppLanguage.es: 'Completa 15 sesiones del modo running (5 minutos o más).',
        AppLanguage.en: 'Finish 15 running sessions (5 minutes or more).',
        AppLanguage.ja: 'ランニングモードを15回（5分以上）。',
      },
    ),
    const OniMask(
      id: 'geisha',
      kanji: '芸',
      image: 'assets/images/masks/ssr/geisha.webp',
      rarity: MaskRarity.ssr,
      counter: 'lyrics',
      goal: 50,
      names: {
        AppLanguage.es: 'Geisha',
        AppLanguage.en: 'Geisha',
        AppLanguage.ja: '芸者',
      },
      descriptions: {
        AppLanguage.es: 'Abre las letras sincronizadas de 50 canciones distintas.',
        AppLanguage.en: 'Open the synced lyrics of 50 different songs.',
        AppLanguage.ja: '50曲の同期歌詞を開く。',
      },
    ),
    const OniMask(
      id: 'akagane',
      kanji: '紅',
      image: 'assets/images/masks/ssr/akagane.webp',
      rarity: MaskRarity.ssr,
      counter: 'artistMax',
      goal: 500,
      names: {
        AppLanguage.es: 'Akagane',
        AppLanguage.en: 'Akagane',
        AppLanguage.ja: '赤金',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 500 canciones de un mismo artista.',
        AppLanguage.en: 'Listen to 500 songs by one artist.',
        AppLanguage.ja: '同じアーティストを500曲聴く。',
      },
    ),
    const OniMask(
      id: 'kitsune',
      kanji: '狐',
      image: 'assets/images/masks/ul/kitsune.webp',
      rarity: MaskRarity.ul,
      counter: 'moons',
      goal: 9,
      names: {
        AppLanguage.es: 'Kitsune',
        AppLanguage.en: 'Kitsune',
        AppLanguage.ja: '狐',
      },
      descriptions: {
        AppLanguage.es: 'Escucha música en 9 lunas llenas. Una cola por cada luna.',
        AppLanguage.en: 'Listen to music on 9 full moons. One tail for each moon.',
        AppLanguage.ja: '9回の満月に音楽を聴く。月ごとに尾が一本。',
      },
    ),
    const OniMask(
      id: 'ou',
      kanji: '王',
      image: 'assets/images/masks/ul/ou.webp',
      rarity: MaskRarity.ul,
      counter: 'masks',
      goal: 50,
      names: {
        AppLanguage.es: 'Rey Oni',
        AppLanguage.en: 'Oni King',
        AppLanguage.ja: '鬼王',
      },
      descriptions: {
        AppLanguage.es: 'Reúne 50 máscaras.',
        AppLanguage.en: 'Collect 50 masks.',
        AppLanguage.ja: '面を50枚集める。',
      },
    ),
    const OniMask(
      id: 'niji',
      kanji: '虹',
      image: 'assets/images/masks/ul/niji.webp',
      rarity: MaskRarity.ul,
      counter: 'styles12',
      goal: 12,
      names: {
        AppLanguage.es: 'Cromo Arcoíris',
        AppLanguage.en: 'Rainbow Chrome',
        AppLanguage.ja: '虹鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha los 12 estilos: 10 canciones de cada uno.',
        AppLanguage.en: 'Listen to all 12 styles: 10 songs of each.',
        AppLanguage.ja: '12のスタイルを各10曲ずつ聴く。',
      },
    ),
    const OniMask(
      id: 'ryuuou',
      kanji: '龍',
      image: 'assets/images/masks/ul/ryuuou.webp',
      rarity: MaskRarity.ul,
      counter: 'streak',
      goal: 100,
      names: {
        AppLanguage.es: 'Rey Dragón',
        AppLanguage.en: 'Dragon King',
        AppLanguage.ja: '龍王',
      },
      descriptions: {
        AppLanguage.es: 'Racha de 100 días seguidos con música.',
        AppLanguage.en: 'A 100-day streak of music.',
        AppLanguage.ja: '100日連続で音楽を聴く。',
      },
    ),
    // Batch 3: second versions of the themes above (the same achievement,
    // harder) and the kitsune series.
    const OniMask(
      id: 'yougan_ni',
      kanji: '熔',
      image: 'assets/images/masks/ul/yougan_ni.webp',
      rarity: MaskRarity.ul,
      counter: 'amb:fire',
      goal: 40,
      names: {
        AppLanguage.es: 'Lava Viva',
        AppLanguage.en: 'Living Lava',
        AppLanguage.ja: '熔岩',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 40 horas con el sonido de fogata.',
        AppLanguage.en: 'Listen for 40 hours with the campfire sound.',
        AppLanguage.ja: '焚き火の音と40時間聴く。',
      },
    ),
    const OniMask(
      id: 'doku_ni',
      kanji: '疫',
      image: 'assets/images/masks/sr/doku_ni.webp',
      rarity: MaskRarity.sr,
      counter: 'explicit',
      goal: 100,
      names: {
        AppLanguage.es: 'Plaga',
        AppLanguage.en: 'Plague',
        AppLanguage.ja: '疫鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 100 canciones con contenido explícito.',
        AppLanguage.en: 'Listen to 100 explicit songs.',
        AppLanguage.ja: '過激な表現のある曲を100曲聴く。',
      },
    ),
    const OniMask(
      id: 'shimo',
      kanji: '霜',
      image: 'assets/images/masks/ssr/shimo.webp',
      rarity: MaskRarity.ssr,
      counter: 'amb:wind',
      goal: 25,
      names: {
        AppLanguage.es: 'Oni de las Nieves',
        AppLanguage.en: 'Snow Oni',
        AppLanguage.ja: '霜鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 25 horas con el sonido de viento.',
        AppLanguage.en: 'Listen for 25 hours with the wind sound.',
        AppLanguage.ja: '風の音と25時間聴く。',
      },
    ),
    const OniMask(
      id: 'amikanmuri',
      kanji: '編',
      image: 'assets/images/masks/ssr/amikanmuri.webp',
      rarity: MaskRarity.ssr,
      counter: 'albums',
      goal: 20,
      names: {
        AppLanguage.es: 'Corona Trenzada',
        AppLanguage.en: 'Braided Crown',
        AppLanguage.ja: '編み冠',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 20 álbumes completos, en orden y sin saltar canciones.',
        AppLanguage.en: 'Play 20 whole albums in order, without skipping.',
        AppLanguage.ja: 'アルバムを20枚、順番に飛ばさず聴く。',
      },
    ),
    const OniMask(
      id: 'mori_ni',
      kanji: '樹',
      image: 'assets/images/masks/sr/mori_ni.webp',
      rarity: MaskRarity.sr,
      counter: 'style:lofi',
      goal: 100,
      names: {
        AppLanguage.es: 'Guardián del Bosque',
        AppLanguage.en: 'Forest Guardian',
        AppLanguage.ja: '森の主',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 100 canciones de lo-fi o chill.',
        AppLanguage.en: 'Listen to 100 lo-fi or chill songs.',
        AppLanguage.ja: 'ローファイ・チルを100曲聴く。',
      },
    ),
    const OniMask(
      id: 'kuzu',
      kanji: '屑',
      image: 'assets/images/masks/sr/kuzu.webp',
      rarity: MaskRarity.sr,
      counter: 'style:punk',
      goal: 60,
      names: {
        AppLanguage.es: 'Desguace',
        AppLanguage.en: 'Junkyard',
        AppLanguage.ja: '屑鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 60 canciones de punk.',
        AppLanguage.en: 'Listen to 60 punk songs.',
        AppLanguage.ja: 'パンクを60曲聴く。',
      },
    ),
    const OniMask(
      id: 'hisui_oni',
      kanji: '玉',
      image: 'assets/images/masks/ssr/hisui_oni.webp',
      rarity: MaskRarity.ssr,
      counter: 'countries',
      goal: 20,
      names: {
        AppLanguage.es: 'Oni de Jade',
        AppLanguage.en: 'Jade Oni',
        AppLanguage.ja: '翡翠鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha música de 20 países distintos.',
        AppLanguage.en: 'Listen to music from 20 different countries.',
        AppLanguage.ja: '20か国の音楽を聴く。',
      },
    ),
    const OniMask(
      id: 'haguruma',
      kanji: '歯',
      image: 'assets/images/masks/sr/haguruma.webp',
      rarity: MaskRarity.sr,
      counter: 'style:jazz',
      goal: 60,
      names: {
        AppLanguage.es: 'Engranaje',
        AppLanguage.en: 'Gear',
        AppLanguage.ja: '歯車',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 60 canciones de jazz, soul o blues.',
        AppLanguage.en: 'Listen to 60 jazz, soul or blues songs.',
        AppLanguage.ja: 'ジャズ・ソウル・ブルースを60曲聴く。',
      },
    ),
    const OniMask(
      id: 'kitsune_jouki',
      kanji: '汽',
      image: 'assets/images/masks/sr/kitsune_jouki.webp',
      rarity: MaskRarity.sr,
      counter: 'marathon',
      goal: 240,
      names: {
        AppLanguage.es: 'Kitsune de Vapor',
        AppLanguage.en: 'Steam Kitsune',
        AppLanguage.ja: '蒸気狐',
      },
      descriptions: {
        AppLanguage.es: 'Maratón: 4 horas de música seguidas.',
        AppLanguage.en: 'Marathon: 4 hours of music in a row.',
        AppLanguage.ja: 'マラソン：4時間連続で音楽を聴く。',
      },
    ),
    const OniMask(
      id: 'kitsune_neon',
      kanji: '妖',
      image: 'assets/images/masks/sr/kitsune_neon.webp',
      rarity: MaskRarity.sr,
      counter: 'style:kpop',
      goal: 60,
      names: {
        AppLanguage.es: 'Kitsune Neón',
        AppLanguage.en: 'Neon Kitsune',
        AppLanguage.ja: 'ネオン狐',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 60 canciones de K-pop.',
        AppLanguage.en: 'Listen to 60 K-pop songs.',
        AppLanguage.ja: 'K-POPを60曲聴く。',
      },
    ),
    const OniMask(
      id: 'kitsune_jiki',
      kanji: '陶',
      image: 'assets/images/masks/ssr/kitsune_jiki.webp',
      rarity: MaskRarity.ssr,
      counter: 'comebacks',
      goal: 3,
      names: {
        AppLanguage.es: 'Kitsune de Porcelana',
        AppLanguage.en: 'Porcelain Kitsune',
        AppLanguage.ja: '磁器狐',
      },
      descriptions: {
        AppLanguage.es: 'Vuelve 3 veces después de 14 días o más sin escuchar música.',
        AppLanguage.en: 'Come back 3 times after 14 days or more away.',
        AppLanguage.ja: '14日以上空けて3回戻ってくる。',
      },
    ),
    const OniMask(
      id: 'kitsune_akagane',
      kanji: '牙',
      image: 'assets/images/masks/r/kitsune_akagane.webp',
      rarity: MaskRarity.r,
      counter: 'fast',
      goal: 40,
      names: {
        AppLanguage.es: 'Kitsune de Cobre',
        AppLanguage.en: 'Copper Kitsune',
        AppLanguage.ja: '銅狐',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 40 canciones rápidas (150 BPM o más).',
        AppLanguage.en: 'Listen to 40 fast songs (150 BPM or more).',
        AppLanguage.ja: '速い曲（150BPM以上）を40曲聴く。',
      },
    ),
    const OniMask(
      id: 'kitsunebi',
      kanji: '宵',
      image: 'assets/images/masks/ul/kitsunebi.webp',
      rarity: MaskRarity.ul,
      counter: 'moonNight',
      goal: 50,
      names: {
        AppLanguage.es: 'Kitsunebi',
        AppLanguage.en: 'Foxfire',
        AppLanguage.ja: '狐火',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 50 canciones de madrugada (entre la medianoche y las 5 AM) en noches de luna llena, cuando arde el fuego del zorro.',
        AppLanguage.en: 'Listen to 50 songs between midnight and 5 AM on full-moon nights, when the foxfire burns.',
        AppLanguage.ja: '満月の夜、深夜0時から5時の間に50曲聴く。狐火が灯る頃。',
      },
    ),
    const OniMask(
      id: 'kitsune_ou',
      kanji: '皇',
      image: 'assets/images/masks/ul/kitsune_ou.webp',
      rarity: MaskRarity.ul,
      counter: 'masks',
      goal: 75,
      names: {
        AppLanguage.es: 'Rey Kitsune',
        AppLanguage.en: 'Kitsune King',
        AppLanguage.ja: '狐王',
      },
      descriptions: {
        AppLanguage.es: 'Reúne 75 máscaras.',
        AppLanguage.en: 'Collect 75 masks.',
        AppLanguage.ja: '面を75枚集める。',
      },
    ),
    const OniMask(
      id: 'kitsune_suishou',
      kanji: '璃',
      image: 'assets/images/masks/sr/kitsune_suishou.webp',
      rarity: MaskRarity.sr,
      counter: 'style:vocaloid',
      goal: 50,
      names: {
        AppLanguage.es: 'Kitsune de Cristal',
        AppLanguage.en: 'Crystal Kitsune',
        AppLanguage.ja: '水晶狐',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 50 canciones de Vocaloid o hyperpop.',
        AppLanguage.en: 'Listen to 50 Vocaloid or hyperpop songs.',
        AppLanguage.ja: 'ボカロ・ハイパーポップを50曲聴く。',
      },
    ),
    const OniMask(
      id: 'kitsune_kuchi',
      kanji: '廃',
      image: 'assets/images/masks/r/kitsune_kuchi.webp',
      rarity: MaskRarity.r,
      counter: 'hidden',
      goal: 40,
      names: {
        AppLanguage.es: 'Kitsune de Chatarra',
        AppLanguage.en: 'Scrap Kitsune',
        AppLanguage.ja: '錆狐',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 40 joyas ocultas: canciones que casi nadie conoce.',
        AppLanguage.en: 'Listen to 40 hidden gems: songs hardly anyone knows.',
        AppLanguage.ja: '隠れた名曲を40曲聴く。',
      },
    ),
    const OniMask(
      id: 'kitsune_hisui',
      kanji: '碧',
      image: 'assets/images/masks/r/kitsune_hisui.webp',
      rarity: MaskRarity.r,
      counter: 'moons',
      goal: 2,
      names: {
        AppLanguage.es: 'Kitsune de Jade',
        AppLanguage.en: 'Jade Kitsune',
        AppLanguage.ja: '翡翠狐',
      },
      descriptions: {
        AppLanguage.es: 'Escucha música en 2 lunas llenas, como la luna que lleva en la frente.',
        AppLanguage.en: 'Listen to music on 2 full moons, like the moon on its brow.',
        AppLanguage.ja: '2回の満月に音楽を聴く。額の月のように。',
      },
    ),
    const OniMask(
      id: 'kemuri_kanmuri',
      kanji: '煙',
      image: 'assets/images/masks/ssr/kemuri_kanmuri.webp',
      rarity: MaskRarity.ssr,
      counter: 'albums',
      goal: 30,
      names: {
        AppLanguage.es: 'Corona de Humo',
        AppLanguage.en: 'Smoke Crown',
        AppLanguage.ja: '煙の冠',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 30 álbumes completos, en orden y sin saltar canciones.',
        AppLanguage.en: 'Play 30 whole albums in order, without skipping.',
        AppLanguage.ja: 'アルバムを30枚、順番に飛ばさず聴く。',
      },
    ),
    // Batch 4: mecha heads and faces of other materials.
    const OniMask(
      id: 'gin',
      kanji: '銀',
      image: 'assets/images/masks/r/gin.webp',
      rarity: MaskRarity.r,
      counter: 'runs',
      goal: 3,
      names: {
        AppLanguage.es: 'Guardián Plateado',
        AppLanguage.en: 'Silver Guardian',
        AppLanguage.ja: '銀の守護者',
      },
      descriptions: {
        AppLanguage.es: 'Completa 3 sesiones del modo running (5 minutos o más).',
        AppLanguage.en: 'Finish 3 running sessions (5 minutes or more).',
        AppLanguage.ja: 'ランニングモードを3回（5分以上）。',
      },
    ),
    const OniMask(
      id: 'shouhei',
      kanji: '哨',
      image: 'assets/images/masks/r/shouhei.webp',
      rarity: MaskRarity.r,
      counter: 'style:electronic',
      goal: 50,
      names: {
        AppLanguage.es: 'Centinela Azul',
        AppLanguage.en: 'Blue Sentinel',
        AppLanguage.ja: '青の哨兵',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 50 canciones de música electrónica.',
        AppLanguage.en: 'Listen to 50 electronic songs.',
        AppLanguage.ja: 'エレクトロニックを50曲聴く。',
      },
    ),
    const OniMask(
      id: 'hououki',
      kanji: '鳳',
      image: 'assets/images/masks/r/hououki.webp',
      rarity: MaskRarity.r,
      counter: 'fast',
      goal: 70,
      names: {
        AppLanguage.es: 'Fénix Mecánico',
        AppLanguage.en: 'Mechanical Phoenix',
        AppLanguage.ja: '機鳳',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 70 canciones rápidas (150 BPM o más).',
        AppLanguage.en: 'Listen to 70 fast songs (150 BPM or more).',
        AppLanguage.ja: '速い曲（150BPM以上）を70曲聴く。',
      },
    ),
    const OniMask(
      id: 'myaku',
      kanji: '脈',
      image: 'assets/images/masks/r/myaku.webp',
      rarity: MaskRarity.r,
      counter: 'style:electronic',
      goal: 80,
      names: {
        AppLanguage.es: 'Pulso Cian',
        AppLanguage.en: 'Cyan Pulse',
        AppLanguage.ja: '青の脈動',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 80 canciones de música electrónica.',
        AppLanguage.en: 'Listen to 80 electronic songs.',
        AppLanguage.ja: 'エレクトロニックを80曲聴く。',
      },
    ),
    const OniMask(
      id: 'meiki',
      kanji: '冥',
      image: 'assets/images/masks/r/meiki.webp',
      rarity: MaskRarity.r,
      counter: 'night',
      goal: 30,
      names: {
        AppLanguage.es: 'Mecha Violeta',
        AppLanguage.en: 'Violet Mecha',
        AppLanguage.ja: '冥機',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 30 canciones entre la medianoche y las 5 AM.',
        AppLanguage.en: 'Listen to 30 songs between midnight and 5 AM.',
        AppLanguage.ja: '深夜0時から5時の間に30曲聴く。',
      },
    ),
    const OniMask(
      id: 'denpa',
      kanji: '波',
      image: 'assets/images/masks/r/denpa.webp',
      rarity: MaskRarity.r,
      counter: 'streak',
      goal: 7,
      names: {
        AppLanguage.es: 'Antena',
        AppLanguage.en: 'Antenna',
        AppLanguage.ja: '電波',
      },
      descriptions: {
        AppLanguage.es: 'Racha de 7 días seguidos con música.',
        AppLanguage.en: 'A 7-day streak of music.',
        AppLanguage.ja: '7日連続で音楽を聴く。',
      },
    ),
    const OniMask(
      id: 'midori',
      kanji: '緑',
      image: 'assets/images/masks/r/midori.webp',
      rarity: MaskRarity.r,
      counter: 'hits',
      goal: 40,
      names: {
        AppLanguage.es: 'Esmeralda',
        AppLanguage.en: 'Emerald',
        AppLanguage.ja: '緑の機兵',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 40 grandes éxitos.',
        AppLanguage.en: 'Listen to 40 big hits.',
        AppLanguage.ja: '大ヒット曲を40曲聴く。',
      },
    ),
    const OniMask(
      id: 'yaiba',
      kanji: '刃',
      image: 'assets/images/masks/r/yaiba.webp',
      rarity: MaskRarity.r,
      counter: 'style:metal',
      goal: 60,
      names: {
        AppLanguage.es: 'Filo de Acero',
        AppLanguage.en: 'Steel Edge',
        AppLanguage.ja: '鋼の刃',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 60 canciones de metal.',
        AppLanguage.en: 'Listen to 60 metal songs.',
        AppLanguage.ja: 'メタルを60曲聴く。',
      },
    ),
    const OniMask(
      id: 'origami',
      kanji: '折',
      image: 'assets/images/masks/ssr/origami.webp',
      rarity: MaskRarity.ssr,
      counter: 'streak',
      goal: 45,
      names: {
        AppLanguage.es: 'Origami',
        AppLanguage.en: 'Origami',
        AppLanguage.ja: '折り紙',
      },
      descriptions: {
        AppLanguage.es: 'Racha de 45 días seguidos con música. Doblez a doblez, día a día.',
        AppLanguage.en: 'A 45-day streak of music. Fold by fold, day by day.',
        AppLanguage.ja: '45日連続で音楽を聴く。一折り一日。',
      },
    ),
    const OniMask(
      id: 'tsugihagi',
      kanji: '綴',
      image: 'assets/images/masks/r/tsugihagi.webp',
      rarity: MaskRarity.r,
      counter: 'countries',
      goal: 8,
      names: {
        AppLanguage.es: 'Retazos',
        AppLanguage.en: 'Patchwork',
        AppLanguage.ja: '継ぎ接ぎ',
      },
      descriptions: {
        AppLanguage.es: 'Escucha música de 8 países distintos.',
        AppLanguage.en: 'Listen to music from 8 different countries.',
        AppLanguage.ja: '8か国の音楽を聴く。',
      },
    ),
    const OniMask(
      id: 'hari',
      kanji: '玻',
      image: 'assets/images/masks/ul/hari.webp',
      rarity: MaskRarity.ul,
      counter: 'countries',
      goal: 40,
      names: {
        AppLanguage.es: 'Vitral',
        AppLanguage.en: 'Stained Glass',
        AppLanguage.ja: '玻璃',
      },
      descriptions: {
        AppLanguage.es: 'Escucha música de 40 países distintos: cada vidrio, una luz.',
        AppLanguage.en: 'Listen to music from 40 different countries: every pane, a light.',
        AppLanguage.ja: '40か国の音楽を聴く。一枚一枚が光。',
      },
    ),
    const OniMask(
      id: 'aki',
      kanji: '秋',
      image: 'assets/images/masks/sr/aki.webp',
      rarity: MaskRarity.sr,
      counter: 'style:folk',
      goal: 100,
      names: {
        AppLanguage.es: 'Espíritu de Otoño',
        AppLanguage.en: 'Autumn Spirit',
        AppLanguage.ja: '秋の精',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 100 canciones de folk o acústicas.',
        AppLanguage.en: 'Listen to 100 folk or acoustic songs.',
        AppLanguage.ja: 'フォーク・アコースティックを100曲聴く。',
      },
    ),
    const OniMask(
      id: 'kisaki',
      kanji: '妃',
      image: 'assets/images/masks/ssr/kisaki.webp',
      rarity: MaskRarity.ssr,
      counter: 'style:kpop',
      goal: 150,
      names: {
        AppLanguage.es: 'Emperatriz Violeta',
        AppLanguage.en: 'Violet Empress',
        AppLanguage.ja: '紫の妃',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 150 canciones de K-pop.',
        AppLanguage.en: 'Listen to 150 K-pop songs.',
        AppLanguage.ja: 'K-POPを150曲聴く。',
      },
    ),
    const OniMask(
      id: 'senkou',
      kanji: '閃',
      image: 'assets/images/masks/r/senkou.webp',
      rarity: MaskRarity.r,
      counter: 'amb:storm',
      goal: 4,
      names: {
        AppLanguage.es: 'Alta Tensión',
        AppLanguage.en: 'High Voltage',
        AppLanguage.ja: '閃光',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 4 horas con el sonido de tormenta.',
        AppLanguage.en: 'Listen for 4 hours with the storm sound.',
        AppLanguage.ja: '嵐の音と4時間聴く。',
      },
    ),
    const OniMask(
      id: 'miko',
      kanji: '巫',
      image: 'assets/images/masks/ssr/miko.webp',
      rarity: MaskRarity.ssr,
      counter: 'moons',
      goal: 6,
      names: {
        AppLanguage.es: 'Oráculo',
        AppLanguage.en: 'Oracle',
        AppLanguage.ja: '巫女',
      },
      descriptions: {
        AppLanguage.es: 'Escucha música en 6 lunas llenas.',
        AppLanguage.en: 'Listen to music on 6 full moons.',
        AppLanguage.ja: '6回の満月に音楽を聴く。',
      },
    ),
    const OniMask(
      id: 'sango',
      kanji: '珊',
      image: 'assets/images/masks/ssr/sango.webp',
      rarity: MaskRarity.ssr,
      counter: 'amb:waves',
      goal: 30,
      names: {
        AppLanguage.es: 'Sirena de Coral',
        AppLanguage.en: 'Coral Siren',
        AppLanguage.ja: '珊瑚の人魚',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 30 horas con el sonido de olas.',
        AppLanguage.en: 'Listen for 30 hours with the waves sound.',
        AppLanguage.ja: '波の音と30時間聴く。',
      },
    ),
    // Batch 5: skulls, stone and an imperial oni.
    const OniMask(
      id: 'runa',
      kanji: '符',
      image: 'assets/images/masks/ssr/runa.webp',
      rarity: MaskRarity.ssr,
      counter: 'style:metal',
      goal: 200,
      names: {
        AppLanguage.es: 'Caballero Rúnico',
        AppLanguage.en: 'Rune Knight',
        AppLanguage.ja: '符の騎士',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 200 canciones de metal.',
        AppLanguage.en: 'Listen to 200 metal songs.',
        AppLanguage.ja: 'メタルを200曲聴く。',
      },
    ),
    const OniMask(
      id: 'iwa',
      kanji: '岩',
      image: 'assets/images/masks/r/iwa.webp',
      rarity: MaskRarity.r,
      counter: 'amb:fire',
      goal: 5,
      names: {
        AppLanguage.es: 'Golem de Magma',
        AppLanguage.en: 'Magma Golem',
        AppLanguage.ja: '溶岩の巨人',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 5 horas con el sonido de fogata.',
        AppLanguage.en: 'Listen for 5 hours with the campfire sound.',
        AppLanguage.ja: '焚き火の音と5時間聴く。',
      },
    ),
    const OniMask(
      id: 'dokuro',
      kanji: '髑',
      image: 'assets/images/masks/sr/dokuro.webp',
      rarity: MaskRarity.sr,
      counter: 'night',
      goal: 120,
      names: {
        AppLanguage.es: 'Calavera Cibernética',
        AppLanguage.en: 'Cyber Skull',
        AppLanguage.ja: '機械髑髏',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 120 canciones entre la medianoche y las 5 AM.',
        AppLanguage.en: 'Listen to 120 songs between midnight and 5 AM.',
        AppLanguage.ja: '深夜0時から5時の間に120曲聴く。',
      },
    ),
    const OniMask(
      id: 'ishiryuu',
      kanji: '竜',
      image: 'assets/images/masks/ssr/ishiryuu.webp',
      rarity: MaskRarity.ssr,
      counter: 'streak',
      goal: 60,
      names: {
        AppLanguage.es: 'Dragón de Piedra',
        AppLanguage.en: 'Stone Dragon',
        AppLanguage.ja: '石竜',
      },
      descriptions: {
        AppLanguage.es: 'Racha de 60 días seguidos con música.',
        AppLanguage.en: 'A 60-day streak of music.',
        AppLanguage.ja: '60日連続で音楽を聴く。',
      },
    ),
    const OniMask(
      id: 'mikado',
      kanji: '帝',
      image: 'assets/images/masks/ssr/mikado.webp',
      rarity: MaskRarity.ssr,
      counter: 'hits',
      goal: 250,
      names: {
        AppLanguage.es: 'Oni Imperial',
        AppLanguage.en: 'Imperial Oni',
        AppLanguage.ja: '帝鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 250 grandes éxitos.',
        AppLanguage.en: 'Listen to 250 big hits.',
        AppLanguage.ja: '大ヒット曲を250曲聴く。',
      },
    ),
    const OniMask(
      id: 'hyou',
      kanji: '豹',
      image: 'assets/images/masks/r/hyou.webp',
      rarity: MaskRarity.r,
      counter: 'style:hiphop',
      goal: 50,
      names: {
        AppLanguage.es: 'Pantera Neón',
        AppLanguage.en: 'Neon Panther',
        AppLanguage.ja: 'ネオン豹',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 50 canciones de hip-hop o rap.',
        AppLanguage.en: 'Listen to 50 hip-hop or rap songs.',
        AppLanguage.ja: 'ヒップホップ・ラップを50曲聴く。',
      },
    ),
    const OniMask(
      id: 'samurai_jouki',
      kanji: '侍',
      image: 'assets/images/masks/ssr/samurai_jouki.webp',
      rarity: MaskRarity.ssr,
      counter: 'style:jazz',
      goal: 300,
      names: {
        AppLanguage.es: 'Samurái de Vapor',
        AppLanguage.en: 'Steam Samurai',
        AppLanguage.ja: '蒸気侍',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 300 canciones de jazz, soul o blues.',
        AppLanguage.en: 'Listen to 300 jazz, soul or blues songs.',
        AppLanguage.ja: 'ジャズ・ソウル・ブルースを300曲聴く。',
      },
    ),
    // Batch 6: cosmic and ritual faces.
    const OniMask(
      id: 'hibiboshi',
      kanji: '裂',
      image: 'assets/images/masks/r/hibiboshi.webp',
      rarity: MaskRarity.r,
      counter: 'night',
      goal: 50,
      names: {
        AppLanguage.es: 'Grieta Estelar',
        AppLanguage.en: 'Star Crack',
        AppLanguage.ja: '星の罅',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 50 canciones entre la medianoche y las 5 AM.',
        AppLanguage.en: 'Listen to 50 songs between midnight and 5 AM.',
        AppLanguage.ja: '深夜0時から5時の間に50曲聴く。',
      },
    ),
    const OniMask(
      id: 'uchuu',
      kanji: '宙',
      image: 'assets/images/masks/sr/uchuu.webp',
      rarity: MaskRarity.sr,
      counter: 'moons',
      goal: 4,
      names: {
        AppLanguage.es: 'Oni Cósmico',
        AppLanguage.en: 'Cosmic Oni',
        AppLanguage.ja: '宇宙鬼',
      },
      descriptions: {
        AppLanguage.es: 'Escucha música en 4 lunas llenas.',
        AppLanguage.en: 'Listen to music on 4 full moons.',
        AppLanguage.ja: '4回の満月に音楽を聴く。',
      },
    ),
    const OniMask(
      id: 'tenshi',
      kanji: '涙',
      image: 'assets/images/masks/ssr/tenshi.webp',
      rarity: MaskRarity.ssr,
      counter: 'sleep',
      goal: 25,
      names: {
        AppLanguage.es: 'Ángel de Lágrimas Doradas',
        AppLanguage.en: 'Angel of Golden Tears',
        AppLanguage.ja: '金涙の天使',
      },
      descriptions: {
        AppLanguage.es: 'Duérmete con el temporizador de sueño 25 noches.',
        AppLanguage.en: 'Fall asleep with the sleep timer on 25 nights.',
        AppLanguage.ja: 'スリープタイマーで25晩眠る。',
      },
    ),
    const OniMask(
      id: 'nichigetsu',
      kanji: '陰',
      image: 'assets/images/masks/r/nichigetsu.webp',
      rarity: MaskRarity.r,
      counter: 'streak',
      goal: 10,
      names: {
        AppLanguage.es: 'Sol y Luna',
        AppLanguage.en: 'Sun and Moon',
        AppLanguage.ja: '日月',
      },
      descriptions: {
        AppLanguage.es: 'Racha de 10 días seguidos con música, de día y de noche.',
        AppLanguage.en: 'A 10-day streak of music, day and night.',
        AppLanguage.ja: '10日連続で音楽を聴く。昼も夜も。',
      },
    ),
    const OniMask(
      id: 'seiza',
      kanji: '星',
      image: 'assets/images/masks/sr/seiza.webp',
      rarity: MaskRarity.sr,
      counter: 'hidden',
      goal: 100,
      names: {
        AppLanguage.es: 'Constelación',
        AppLanguage.en: 'Constellation',
        AppLanguage.ja: '星座',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 100 joyas ocultas: estrellas que casi nadie ha visto.',
        AppLanguage.en: 'Listen to 100 hidden gems: stars hardly anyone has seen.',
        AppLanguage.ja: '隠れた名曲を100曲聴く。誰も見ていない星。',
      },
    ),
    const OniMask(
      id: 'enbu',
      kanji: '舞',
      image: 'assets/images/masks/r/enbu.webp',
      rarity: MaskRarity.r,
      counter: 'style:rock',
      goal: 60,
      names: {
        AppLanguage.es: 'Kabuki Ardiente',
        AppLanguage.en: 'Burning Kabuki',
        AppLanguage.ja: '炎舞',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 60 canciones de rock.',
        AppLanguage.en: 'Listen to 60 rock songs.',
        AppLanguage.ja: 'ロックを60曲聴く。',
      },
    ),
    const OniMask(
      id: 'chirune',
      kanji: '呪',
      image: 'assets/images/masks/r/chirune.webp',
      rarity: MaskRarity.r,
      counter: 'explicit',
      goal: 60,
      names: {
        AppLanguage.es: 'Runa de Sangre',
        AppLanguage.en: 'Blood Rune',
        AppLanguage.ja: '血の呪符',
      },
      descriptions: {
        AppLanguage.es: 'Escucha 60 canciones con contenido explícito.',
        AppLanguage.en: 'Listen to 60 explicit songs.',
        AppLanguage.ja: '過激な表現のある曲を60曲聴く。',
      },
    ),
  ];

  static const _weeklyDescription = {
    AppLanguage.es: 'Completa los 3 desafíos de una semana.',
    AppLanguage.en: "Complete a week's 3 challenges.",
    AppLanguage.ja: '1週間の3つのチャレンジを達成する。',
  };

  /// The masks won with weekly challenges, in rotation order.
  static final List<OniMask> weekly = [for (final m in all) if (m.weekly) m];

  /// The music style each weekly mask's week is about: one of the week's
  /// challenges asks for songs of it.
  static const weeklyThemes = <String, MusicStyle>{
    'sumi': MusicStyle.lofi,
    'hachi': MusicStyle.electronic,
    'ranpa': MusicStyle.indie,
    'kori': MusicStyle.classical,
    'hanami': MusicStyle.jpop,
    'maboroshi': MusicStyle.synthwave,
    'hikari': MusicStyle.pop,
    'futaomote': MusicStyle.latin,
    'kintsugi': MusicStyle.jazz,
    'ougon': MusicStyle.pop,
    'akaoni': MusicStyle.rock,
    'kijo': MusicStyle.punk,
    'kibori': MusicStyle.folk,
    'ishi': MusicStyle.metal,
    'seidou': MusicStyle.rock,
    'raijin': MusicStyle.metal,
    'namahage': MusicStyle.punk,
    'kurohannya': MusicStyle.metal,
    'yurei': MusicStyle.lofi,
    'chinoame': MusicStyle.hiphop,
  };

  /// The masks El Oni asks for: the original achievements (not
  /// the weekly ones, nor the illustrations with achievements of their own).
  static final List<OniMask> oniSet = [
    for (final m in all)
      if (m.id != 'oni' && !m.weekly && m.image == null) m,
  ];

  static OniMask? byId(String? id) {
    if (id == null) return null;
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }
}
