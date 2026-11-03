import '../../core/localization/app_language.dart';

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
      rarity: MaskRarity.ssr,
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
      rarity: MaskRarity.ssr,
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
      rarity: MaskRarity.ssr,
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
      rarity: MaskRarity.ssr,
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
      rarity: MaskRarity.ul,
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
        AppLanguage.es: 'Luna de Sangre',
        AppLanguage.en: 'Blood Moon',
        AppLanguage.ja: '血の月',
      },
      descriptions: _weeklyDescription,
    ),
    // New illustrations (tool/add_mask.py), weekly rewards: R and SR.
    const OniMask(
      id: 'tetsu',
      kanji: '鉄',
      image: 'assets/images/masks/r/tetsu.webp',
      rarity: MaskRarity.r,
      weekly: true,
      names: {
        AppLanguage.es: 'Oni de Acero',
        AppLanguage.en: 'Steel Oni',
        AppLanguage.ja: '鉄の鬼',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'kin_oni',
      kanji: '金',
      image: 'assets/images/masks/sr/kin_oni.webp',
      rarity: MaskRarity.sr,
      weekly: true,
      names: {
        AppLanguage.es: 'Oni Dorado',
        AppLanguage.en: 'Golden Oni',
        AppLanguage.ja: '金鬼',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'shiro',
      kanji: '白',
      image: 'assets/images/masks/r/shiro.webp',
      rarity: MaskRarity.r,
      weekly: true,
      names: {
        AppLanguage.es: 'Oni Blanco',
        AppLanguage.en: 'White Oni',
        AppLanguage.ja: '白鬼',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'inazuma',
      kanji: '電',
      image: 'assets/images/masks/sr/inazuma.webp',
      rarity: MaskRarity.sr,
      weekly: true,
      names: {
        AppLanguage.es: 'Rayo',
        AppLanguage.en: 'Lightning',
        AppLanguage.ja: '稲妻',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'yami',
      kanji: '闇',
      image: 'assets/images/masks/r/yami.webp',
      rarity: MaskRarity.r,
      weekly: true,
      names: {
        AppLanguage.es: 'Oni de Sombra',
        AppLanguage.en: 'Shadow Oni',
        AppLanguage.ja: '闇鬼',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'urushi',
      kanji: '漆',
      image: 'assets/images/masks/sr/urushi.webp',
      rarity: MaskRarity.sr,
      weekly: true,
      names: {
        AppLanguage.es: 'Laca',
        AppLanguage.en: 'Lacquer',
        AppLanguage.ja: '漆',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'sabi',
      kanji: '錆',
      image: 'assets/images/masks/r/sabi.webp',
      rarity: MaskRarity.r,
      weekly: true,
      names: {
        AppLanguage.es: 'Óxido',
        AppLanguage.en: 'Rust',
        AppLanguage.ja: '錆鬼',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'rakugaki',
      kanji: '彩',
      image: 'assets/images/masks/sr/rakugaki.webp',
      rarity: MaskRarity.sr,
      weekly: true,
      names: {
        AppLanguage.es: 'Grafiti Neón',
        AppLanguage.en: 'Neon Graffiti',
        AppLanguage.ja: '落書き',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'meisai',
      kanji: '迷',
      image: 'assets/images/masks/r/meisai.webp',
      rarity: MaskRarity.r,
      weekly: true,
      names: {
        AppLanguage.es: 'Camuflaje',
        AppLanguage.en: 'Camouflage',
        AppLanguage.ja: '迷彩鬼',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'eizou',
      kanji: '映',
      image: 'assets/images/masks/sr/eizou.webp',
      rarity: MaskRarity.sr,
      weekly: true,
      names: {
        AppLanguage.es: 'Proyección',
        AppLanguage.en: 'Projection',
        AppLanguage.ja: '映像',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'kikai',
      kanji: '機',
      image: 'assets/images/masks/r/kikai.webp',
      rarity: MaskRarity.r,
      weekly: true,
      names: {
        AppLanguage.es: 'Mecha',
        AppLanguage.en: 'Mecha',
        AppLanguage.ja: '機械鬼',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'tsurara',
      kanji: '凍',
      image: 'assets/images/masks/sr/tsurara.webp',
      rarity: MaskRarity.sr,
      weekly: true,
      names: {
        AppLanguage.es: 'Escarcha',
        AppLanguage.en: 'Frost',
        AppLanguage.ja: '凍鬼',
      },
      descriptions: _weeklyDescription,
    ),
    const OniMask(
      id: 'murasaki',
      kanji: '紫',
      image: 'assets/images/masks/r/murasaki.webp',
      rarity: MaskRarity.r,
      weekly: true,
      names: {
        AppLanguage.es: 'Grafiti Violeta',
        AppLanguage.en: 'Violet Graffiti',
        AppLanguage.ja: '紫の落書き',
      },
      descriptions: _weeklyDescription,
    ),
  ];

  static const _weeklyDescription = {
    AppLanguage.es: 'Completa los 3 desafíos de una semana.',
    AppLanguage.en: "Complete a week's 3 challenges.",
    AppLanguage.ja: '1週間の3つのチャレンジを達成する。',
  };

  /// The masks won with weekly challenges, in rotation order.
  static final List<OniMask> weekly = [for (final m in all) if (m.weekly) m];

  static OniMask? byId(String? id) {
    if (id == null) return null;
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }
}
