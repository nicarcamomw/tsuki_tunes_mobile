import 'dart:ui';

import '../core/localization/app_language.dart';

enum MaskRarity { common, rare, epic, secret, legendary }

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

/// A collectible mask: one of the four illustrations, dyed with a color
/// matrix, unlocked by an achievement.
class OniMask {
  final String id;
  final String kanji;
  final MaskArt art;
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

  const OniMask({
    required this.id,
    required this.kanji,
    required this.art,
    required this.rarity,
    required this.names,
    required this.descriptions,
    this.secret = false,
    this.dye,
    this.goal,
    this.weekly = false,
  });

  String asset() => switch (art) {
        MaskArt.tengu => 'assets/images/tengu.png',
        MaskArt.kabuki => 'assets/images/oni.png',
        MaskArt.hannya => 'assets/images/hannya.png',
        MaskArt.cyberOni => 'assets/images/cyber_oni_mask.png',
        _ => 'assets/images/masks/${art.name}.webp',
      };

  String name(AppLanguage l) => names[l] ?? names[AppLanguage.es]!;
  String description(AppLanguage l) => descriptions[l] ?? descriptions[AppLanguage.es]!;

  Color get rarityColor => switch (rarity) {
        MaskRarity.common => const Color(0xFFB8C0D0),
        MaskRarity.rare => const Color(0xFF00E5FF),
        MaskRarity.epic => const Color(0xFFB026FF),
        MaskRarity.secret => const Color(0xFFFF2A4A),
        MaskRarity.legendary => const Color(0xFFFFC94A),
      };
}

/// Luminance-preserving tint: keeps the illustration's shading and detail,
/// recolors it toward [color].
List<double> maskDye(Color color, {double strength = 0.85, double gain = 1.25}) {
  final r = color.r, g = color.g, b = color.b;
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
      rarity: MaskRarity.common,
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
      rarity: MaskRarity.common,
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
      rarity: MaskRarity.epic,
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
      rarity: MaskRarity.rare,
      goal: 100,
      dye: maskDye(const Color(0xFFFF6B9D)),
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
      rarity: MaskRarity.rare,
      goal: 20,
      dye: maskDye(const Color(0xFF2EE6A6)),
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
      rarity: MaskRarity.rare,
      dye: maskDye(const Color(0xFFE6ECF5), strength: 0.9, gain: 1.45),
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
      rarity: MaskRarity.rare,
      goal: 10,
      dye: maskDye(const Color(0xFF4FA8FF)),
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
      rarity: MaskRarity.rare,
      dye: maskDye(const Color(0xFFD6E0F5), strength: 0.7, gain: 1.35),
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
      rarity: MaskRarity.rare,
      goal: 50,
      dye: maskDye(const Color(0xFF7A5CFF)),
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
      rarity: MaskRarity.epic,
      dye: maskDye(const Color(0xFFFFC94A), gain: 1.35),
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
      rarity: MaskRarity.epic,
      goal: 14,
      dye: maskDye(const Color(0xFFB026FF)),
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
      rarity: MaskRarity.secret,
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
    ),
    OniMask(
      id: 'chizuki',
      kanji: '血',
      art: MaskArt.tengu,
      rarity: MaskRarity.secret,
      secret: true,
      dye: maskDye(const Color(0xFFB0101E), strength: 0.75, gain: 1.4),
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
    ),
    OniMask(
      id: 'shuchaku',
      kanji: '執',
      art: MaskArt.hannya,
      rarity: MaskRarity.secret,
      secret: true,
      dye: maskDye(const Color(0xFF9CFF3A)),
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
    ),
    const OniMask(
      id: 'hannya',
      kanji: '般',
      art: MaskArt.cyberOni,
      rarity: MaskRarity.secret,
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
    ),
    OniMask(
      id: 'oni',
      kanji: '鬼',
      art: MaskArt.cyberOni,
      rarity: MaskRarity.legendary,
      secret: true,
      dye: maskDye(const Color(0xFFFFB02E), strength: 0.55, gain: 1.3),
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
    ),
    // Weekly challenge rewards, in the order they're handed out.
    const OniMask(
      id: 'sumi',
      kanji: '墨',
      art: MaskArt.sumie,
      rarity: MaskRarity.rare,
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
      rarity: MaskRarity.rare,
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
      rarity: MaskRarity.rare,
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
      rarity: MaskRarity.rare,
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
      rarity: MaskRarity.rare,
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
      rarity: MaskRarity.epic,
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
      rarity: MaskRarity.epic,
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
      rarity: MaskRarity.epic,
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
      rarity: MaskRarity.epic,
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
      rarity: MaskRarity.epic,
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
      rarity: MaskRarity.rare,
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
      rarity: MaskRarity.rare,
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
      rarity: MaskRarity.rare,
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
      rarity: MaskRarity.rare,
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
      rarity: MaskRarity.rare,
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
      rarity: MaskRarity.epic,
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
      rarity: MaskRarity.epic,
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
      rarity: MaskRarity.epic,
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
      rarity: MaskRarity.epic,
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
      rarity: MaskRarity.epic,
      weekly: true,
      names: {
        AppLanguage.es: 'Luna de Sangre',
        AppLanguage.en: 'Blood Moon',
        AppLanguage.ja: '血の月',
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
