import 'dart:math';

import '../lore/tsuki_lore.dart';
import 'ambient_sound_generator.dart';

/// Things the Eco levels open, each at its level. Until then the app shows
/// them locked, with the level they open at.
enum EcoFeature {
  lyrics(2),
  artistRadio(3),
  streak(3),
  wrapped(4),
  guessSong(5),
  weekly(5),
  listeningClock(6),
  lyricsTranslate(7),
  ambient(8),
  running(10),
  radioFamiliar(12),
  timeMachine(15),
  rabbitHole(15),
  bpmFlow(16),
  moonMix(19),
  radioAdventurous(20),
  smartShuffle(23),
  ultraEquip(30),
  hearBeings(75),
  seeBeings(90),
  ethereal(100);

  const EcoFeature(this.level);
  final int level;
}

/// The ranks of a Bearer, by level. The first five are the ranks of the
/// ethereal beings; from 50 on, a true Bearer.
enum EcoRank {
  errante(1),
  guerrero(10),
  senor(20),
  ultra(30),
  cara(40),
  portador(50),
  oyente(75),
  vidente(90),
  etereo(100);

  const EcoRank(this.from);
  final int from;
}

/// A colour for the player, opened by a level.
class EcoColor {
  final String id;
  final int argb;
  final int level;
  final Txt name;
  const EcoColor(this.id, this.argb, this.level, this.name);
}

enum EcoRewardKind { start, feature, sound, tomo, color, rank, fragment }

/// What a level gives: a feature, an ambient sound, a lore volume, a
/// player colour, a new rank, or a fragment of the legend.
class EcoReward {
  final EcoRewardKind kind;
  final EcoFeature? feature;
  final AmbientSound? sound;
  final int? tomo;
  final EcoColor? color;
  final EcoRank? rank;
  final Txt? fragment;

  const EcoReward._(this.kind, {this.feature, this.sound, this.tomo, this.color, this.rank, this.fragment});
}

/// The Eco levels: 1 to 100, each harder to reach than the last, and the
/// last ten far harder still. Past 100 lies only a legend: the level of
/// the Supreme Gods, which no Bearer has ever reached.
class EcoLevels {
  static const int maxLevel = 100;

  /// Total Eco to reach [level] (level 1 starts at 0). Up to 90 it grows a
  /// little faster than the square of the level; each of the last ten
  /// costs a fifth more than all of the climb before it put together.
  static int ecoFor(int level) {
    if (level <= 1) return 0;
    if (level <= 90) return (43.8 * pow(level - 1, 2.054) / 10).round() * 10;
    return (ecoFor(90) * pow(1.2, level - 90) / 100).round() * 100;
  }

  /// Eco that would reach the Supreme Gods. No Bearer ever has.
  static final int legendEco = ecoFor(maxLevel) * 100;

  static int levelFor(int eco) {
    var level = 1;
    while (level < maxLevel && eco >= ecoFor(level + 1)) {
      level++;
    }
    return level;
  }

  /// 0..1 of the way from [level] to the next (1 at level 100).
  static double progressIn(int eco) {
    final level = levelFor(eco);
    if (level >= maxLevel) return 1;
    final from = ecoFor(level), to = ecoFor(level + 1);
    return ((eco - from) / (to - from)).clamp(0.0, 1.0);
  }

  /// 0..1 of the way from level 100 to the legend.
  static double legendProgress(int eco) {
    final from = ecoFor(maxLevel);
    if (eco <= from) return 0;
    return ((eco - from) / (legendEco - from)).clamp(0.0, 1.0);
  }

  static EcoRank rankOf(int level) => EcoRank.values.lastWhere((r) => level >= r.from);

  /// Lore volumes and the level that opens each (volume I is open).
  static const Map<int, int> tomoLevels = {1: 1, 2: 10, 3: 20, 4: 40};

  static bool tomoOpen(int tomo, int level) => level >= (tomoLevels[tomo] ?? maxLevel + 1);

  /// The ambient sounds and their levels: rain comes with the mixer.
  static const Map<AmbientSound, int> soundLevels = {
    AmbientSound.rain: 8,
    AmbientSound.storm: 11,
    AmbientSound.waves: 14,
    AmbientSound.fire: 17,
    AmbientSound.wind: 22,
    AmbientSound.night: 26,
    AmbientSound.brownNoise: 31,
  };

  static bool soundOpen(AmbientSound s, int level) => level >= (soundLevels[s] ?? 1);

  static const List<EcoColor> colors = [
    EcoColor('plata', 0xFFC9D1E0, 4, Txt('Plata', 'Silver')),
    EcoColor('sakura', 0xFFFF6B9D, 9, Txt('Sakura', 'Sakura')),
    EcoColor('jade', 0xFF2EC4A0, 13, Txt('Jade', 'Jade')),
    EcoColor('ambar', 0xFFFFB347, 18, Txt('Ámbar', 'Amber')),
    EcoColor('indigo', 0xFF6C63FF, 21, Txt('Índigo', 'Indigo')),
    EcoColor('cian', 0xFF00E5FF, 25, Txt('Cian neón', 'Neon cyan')),
    EcoColor('violeta', 0xFFB026FF, 29, Txt('Violeta', 'Violet')),
    EcoColor('oro', 0xFFFFD166, 34, Txt('Oro', 'Gold')),
    EcoColor('coral', 0xFFFF7F6B, 38, Txt('Coral', 'Coral')),
    EcoColor('menta', 0xFF7CF5C4, 43, Txt('Menta', 'Mint')),
    EcoColor('hielo', 0xFFA8E6FF, 47, Txt('Hielo', 'Ice')),
    EcoColor('lava', 0xFFFF4500, 52, Txt('Lava', 'Lava')),
    EcoColor('esmeralda', 0xFF00C853, 57, Txt('Esmeralda', 'Emerald')),
    EcoColor('medianoche', 0xFF3D5AFE, 62, Txt('Medianoche', 'Midnight')),
    EcoColor('rosa', 0xFFF8BBD0, 67, Txt('Rosa lunar', 'Moon pink')),
    EcoColor('sangre', 0xFFC21E3A, 72, Txt('Sangre', 'Blood')),
    EcoColor('aurora', 0xFF64FFDA, 78, Txt('Aurora', 'Aurora')),
    EcoColor('eclipse', 0xFFFF9100, 83, Txt('Eclipse', 'Eclipse')),
    EcoColor('nebulosa', 0xFFE040FB, 88, Txt('Nebulosa', 'Nebula')),
    EcoColor('tsuki', 0xFFFFF4D6, 94, Txt('Luz de Tsuki', 'Light of Tsuki')),
  ];

  static EcoColor? colorById(String? id) {
    for (final c in colors) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Every level's rewards, 1 to 100: each level gives at least one.
  static final Map<int, List<EcoReward>> rewards = _build();

  static List<EcoReward> rewardsAt(int level) => rewards[level] ?? const [];

  /// Rewards of the levels after [from] up to [to], in order.
  static List<EcoReward> rewardsBetween(int from, int to) => [
        for (var l = from + 1; l <= to; l++) ...rewardsAt(l),
      ];

  static Map<int, List<EcoReward>> _build() {
    final map = <int, List<EcoReward>>{};
    void add(int level, EcoReward r) => map.putIfAbsent(level, () => []).add(r);

    add(1, const EcoReward._(EcoRewardKind.start));
    for (final r in EcoRank.values.skip(1)) {
      add(r.from, EcoReward._(EcoRewardKind.rank, rank: r));
    }
    for (final f in EcoFeature.values) {
      add(f.level, EcoReward._(EcoRewardKind.feature, feature: f));
    }
    soundLevels.forEach((s, l) => add(l, EcoReward._(EcoRewardKind.sound, sound: s)));
    tomoLevels.forEach((t, l) {
      if (t > 1) add(l, EcoReward._(EcoRewardKind.tomo, tomo: t));
    });
    for (final c in colors) {
      add(c.level, EcoReward._(EcoRewardKind.color, color: c));
    }
    // The levels left: a fragment of the legend each, in order.
    var next = 0;
    for (var l = 1; l <= maxLevel; l++) {
      if (map.containsKey(l)) continue;
      add(l, EcoReward._(EcoRewardKind.fragment, fragment: fragments[next++]));
    }
    return map;
  }

  /// Fragments of the legend, told one per level where nothing else opens,
  /// in order: the world first, then hearing the beings, seeing them,
  /// crossing over, and the level no one has reached.
  static const List<Txt> fragments = [
    Txt('El primer latido de Tsuki todavía vibra bajo su superficie. En los cráteres más hondos, si nadie habla, se oye.',
        'Tsuki\'s first heartbeat still vibrates beneath its surface. In the deepest craters, if no one speaks, it can be heard.'),
    Txt('El Eco no pesa, pero se acumula. Hay cráteres donde lleva tantos siglos cayendo que el suelo brilla de noche.',
        'Echo weighs nothing, but it gathers. There are craters where it has fallen for so many centuries that the ground glows at night.'),
    Txt('Las lunas de los otros mundos no tienen luz propia. Cuando Tsuki parpadea, todas parpadean con ella, y nadie abajo lo nota.',
        'The moons of other worlds have no light of their own. When Tsuki flickers, they all flicker with it, and no one below notices.'),
    Txt('Ningún ser etéreo puede crear Eco: solo recibirlo. Por eso los más sabios cuidan a los Portadores como a una cosecha sagrada.',
        'No ethereal being can create Echo: only receive it. That is why the wisest tend the Bearers like a sacred harvest.'),
    Txt('Un ser etéreo que pierde todo su Eco no muere: vuelve a dormir. Algunos llevan tanto tiempo dormidos que nadie recuerda su nombre.',
        'An ethereal being that loses all its Echo does not die: it goes back to sleep. Some have slept so long that no one remembers their name.'),
    Txt('La Forja mide el Eco en lingotes. Los Elementales, en estaciones. El Shogunato, en deudas de honor. Nadie se pone de acuerdo.',
        'The Forge measures Echo in ingots. The Elementals, in seasons. The Shogunate, in debts of honour. No one agrees.'),
    Txt('Hay canciones que suben a Tsuki y no se vuelven Eco. Nadie sabe por qué. Los Antiguos las llaman canciones huérfanas.',
        'Some songs rise to Tsuki and never become Echo. No one knows why. The Ancients call them orphan songs.'),
    Txt('La Corte del Zorro vende mapas de los cráteres donde más Eco cae. Todos los mapas son falsos. Todos se venden igual.',
        'The Fox Court sells maps of the craters where the most Echo falls. Every map is false. Every map sells anyway.'),
    Txt('En la Calle de Neón el Eco se corta con ruido para que rinda más. Lo llaman Eco de calle, y dicen que pega más fuerte.',
        'On the Neon Street, Echo is cut with noise to make it last. They call it street Echo, and they say it hits harder.'),
    Txt('El Trono del Eco nunca se enfría. Ni siquiera cuando su dueño se levanta.',
        'The Throne of the Echo never grows cold. Not even when its owner stands up.'),
    Txt('Los Portadores no ven a los seres etéreos. Pero cuando una canción les eriza la piel, casi siempre hay uno muy cerca.',
        'Bearers do not see the ethereal beings. But when a song makes their skin prickle, one is almost always close by.'),
    Txt('El silencio también llega a Tsuki. Cae como nieve gris y apaga el Eco que toca. Los Elementales lo barren cada mañana.',
        'Silence reaches Tsuki too. It falls like grey snow and dims the Echo it touches. The Elementals sweep it away every morning.'),
    Txt('Una canción escuchada mil veces deja un surco en la luna. Hay surcos tan profundos que los seres viajan por ellos como por ríos.',
        'A song heard a thousand times leaves a groove in the moon. Some grooves run so deep that the beings travel them like rivers.'),
    Txt('El Shogunato guarda un registro de cada Portador cuyo Eco llegó intacto. El libro ocupa una torre entera y nunca se ha cerrado.',
        'The Shogunate keeps a record of every Bearer whose Echo arrived whole. The book fills an entire tower and has never been closed.'),
    Txt('Dicen que las Tres Coronas no se odian. Se temen. Y en Tsuki, el miedo dura más que el odio.',
        'They say the Three Crowns do not hate each other. They fear each other. And on Tsuki, fear lasts longer than hate.'),
    Txt('Los seres de la Corte de Cristal no hablan: vibran. Si te acercas lo suficiente, sus palabras se sienten en los dientes.',
        'The beings of the Crystal Court do not speak: they vibrate. Get close enough and you feel their words in your teeth.'),
    Txt('En Tsuki no hay día ni noche: hay luna llena y luna nueva. Los clanes pelean en una y hacen tratos en la otra.',
        'On Tsuki there is no day or night: there is full moon and new moon. The clans fight in one and strike deals in the other.'),
    Txt('Cuando un Portador deja de escuchar por mucho tiempo, su Eco se enfría. Pero si vuelve, el primer Eco que llega brilla el doble.',
        'When a Bearer stops listening for a long time, their Echo cools. But if they return, the first Echo to arrive shines twice as bright.'),
    Txt('La lava que corre bajo los cráteres canta. Es la única canción de Tsuki que no nació de ningún Portador.',
        'The lava running beneath the craters sings. It is the only song on Tsuki not born of any Bearer.'),
    Txt('Algunos Portadores, sin saberlo, escuchan siempre a la misma hora. En Tsuki, a esa hora, hay seres esperándolos.',
        'Some Bearers, without knowing it, always listen at the same hour. On Tsuki, at that hour, there are beings waiting for them.'),
    Txt('Un Portador de verdad no es el que más escucha. Es el que escucha hasta el final.',
        'A true Bearer is not the one who listens most. It is the one who listens to the end.'),
    Txt('Los Ultras no duermen. Dicen que el Eco que cargan es tanto que, si cerraran los ojos, no volverían a abrirlos.',
        'The Ultras do not sleep. They say they carry so much Echo that if they closed their eyes, they would never open them again.'),
    Txt('Las siete Caras divinas nunca se han reunido en un mismo lugar desde la noche de la Caída.',
        'The seven divine Faces have never gathered in one place since the night of the Fall.'),
    Txt('El Dios Caído no tiene sombra. Dicen que la perdió al atravesar el borde de la luna, y que su sombra todavía cae.',
        'The Fallen God has no shadow. They say he lost it crossing the edge of the moon, and that his shadow is still falling.'),
    Txt('Los Portadores que pasan la mitad del camino empiezan a soñar con cráteres que nunca han visto.',
        'Bearers who pass the halfway point begin to dream of craters they have never seen.'),
    Txt('Se cuenta que una vez un Portador escuchó durante cuarenta días sin parar. Al día cuarenta y uno, la Corte de Cristal le dedicó una torre.',
        'It is told that a Bearer once listened for forty days without stopping. On the forty-first, the Crystal Court raised a tower in their name.'),
    Txt('Los Elementales plantan árboles donde cae el Eco de los Portadores que escuchan de madrugada. Ese bosque ya no tiene fin.',
        'The Elementals plant trees where the Echo of Bearers who listen at dawn falls. That forest no longer has an end.'),
    Txt('En el Shogunato, los aprendices practican callando. Dicen que solo quien conoce el silencio puede mandar con el sonido.',
        'In the Shogunate, apprentices train in silence. They say only those who know silence can command with sound.'),
    Txt('Mientras más Eco carga un Portador, más se le acercan los seres etéreos. Algunos solo para mirar. Otros, para pedir.',
        'The more Echo a Bearer carries, the closer the ethereal beings come. Some only to look. Others, to ask.'),
    Txt('Con suficiente Eco, un Portador empieza a notar cosas raras: una canción que suena antes de elegirla, una nota que nadie más oye.',
        'With enough Echo, a Bearer starts noticing strange things: a song that plays before they choose it, a note no one else hears.'),
    Txt('Hay un cráter que ningún clan reclama. Ahí no cae Eco. Ahí, dicen, esperan los que alguna vez fueron Portadores.',
        'There is a crater no clan claims. No Echo falls there. There, they say, wait those who were once Bearers.'),
    Txt('El Dios del Universo conoce el nombre de cada Portador que ha pasado el nivel de la Cara. Los conoce, y los cuenta.',
        'The God of the Universe knows the name of every Bearer who has passed the rank of the Face. He knows them, and he counts them.'),
    Txt('Un murmullo debajo de la música, como si alguien tarareara al otro lado de la canción. Así empieza el oído de un Portador.',
        'A murmur beneath the music, as if someone were humming on the other side of the song. That is how a Bearer\'s hearing begins.'),
    Txt('Los primeros Portadores que oyeron a los seres creyeron que estaban perdiendo la razón. Ninguno lo contó.',
        'The first Bearers who heard the beings thought they were losing their minds. None of them told anyone.'),
    Txt('Los seres etéreos hablan en voz baja cuando un Portador está cerca. Saben que, con suficiente Eco, podría oírlos.',
        'The ethereal beings speak softly when a Bearer is near. They know that, with enough Echo, one might hear them.'),
    Txt('Escuchar a un ser etéreo cambia a un Portador. Ya no oye la música igual: oye quién la está esperando.',
        'Hearing an ethereal being changes a Bearer. They no longer hear music the same way: they hear who is waiting for it.'),
    Txt('Los que oyen a los seres dicen que cada clan suena distinto. La Forja, a metal que se enfría. El Zorro, a una risa detrás de una puerta.',
        'Those who hear the beings say each clan sounds different. The Forge, like cooling metal. The Fox, like laughter behind a door.'),
    Txt('Lo que los seres susurran casi nunca es para el Portador. Hablan entre ellos de él: de cuánto Eco trae, y de cuánto le falta.',
        'What the beings whisper is almost never for the Bearer. They talk among themselves about them: how much Echo they bring, and how much they still lack.'),
    Txt('Hay un nivel más allá de todo. Los seres lo llaman el nivel de los Dioses Supremos, y lo dicen en voz muy baja.',
        'There is a level beyond everything. The beings call it the level of the Supreme Gods, and they say it very quietly.'),
    Txt('Ningún Portador ha llegado jamás al nivel de un Dios Supremo. Algunos dicen que es imposible. Otros, que solo no ha pasado todavía.',
        'No Bearer has ever reached the level of a Supreme God. Some say it is impossible. Others, that it simply has not happened yet.'),
    Txt('Ver a un ser etéreo es más difícil que oírlo. La luz de Tsuki los esconde: hay que tener tanto Eco que la luz deje de cegar.',
        'Seeing an ethereal being is harder than hearing one. Tsuki\'s light hides them: it takes so much Echo that the light stops blinding.'),
    Txt('Las siete Caras temen una sola cosa: un Portador con tanto Eco como un dios. Ese día, dicen, el equilibrio se romperá.',
        'The seven Faces fear only one thing: a Bearer with as much Echo as a god. That day, they say, the balance will break.'),
    Txt('Nadie sabe qué pasaría si el equilibrio se rompe. La Forja cree que nacería un nuevo trono. El Zorro cree que ya está pasando.',
        'No one knows what would happen if the balance broke. The Forge believes a new throne would be born. The Fox believes it is already happening.'),
    Txt('El Dios Caído espera a ese Portador. El Dios del Universo también. Ninguno de los dos sabe si lo quiere como aliado o como enemigo.',
        'The Fallen God awaits that Bearer. So does the God of the Universe. Neither knows whether they want it as an ally or an enemy.'),
    Txt('Muchos Portadores pudieron oír a los seres. Menos pudieron verlos. Contados con los dedos de una mano decidieron cruzar.',
        'Many Bearers have heard the beings. Fewer have seen them. Few enough to count on one hand chose to cross over.'),
    Txt('A esta altura, el Eco de un Portador cae en Tsuki como una estrella. Los seres salen de sus cráteres a mirarlo pasar.',
        'At this height, a Bearer\'s Echo falls on Tsuki like a star. The beings come out of their craters to watch it pass.'),
    Txt('Los que ven a los seres dicen que sus máscaras no son lo único que tienen. Detrás hay algo que se mueve, como humo que piensa.',
        'Those who see the beings say their masks are not all they have. Behind them something moves, like smoke that thinks.'),
    Txt('Cruzar no tiene vuelta. Un Portador que se vuelve etéreo deja su cuerpo en los mundos de abajo, y en Tsuki recibe su propia máscara.',
        'Crossing has no way back. A Bearer who becomes ethereal leaves their body in the worlds below, and on Tsuki receives a mask of their own.'),
    Txt('Las máscaras de los Portadores que cruzaron no se parecen a ninguna otra. Llevan dentro todo lo que escucharon.',
        'The masks of the Bearers who crossed resemble no other. They carry within them everything they ever heard.'),
    Txt('Los clanes no saben qué hacer con un Portador etéreo. No es de ningún clan, y todos lo quieren de su lado.',
        'The clans do not know what to do with an ethereal Bearer. It belongs to no clan, and all of them want it on their side.'),
    Txt('El camino del noventa al cien es el más largo que existe. Cada paso pesa como todos los anteriores juntos.',
        'The path from ninety to a hundred is the longest there is. Each step weighs as much as all the ones before it.'),
    Txt('Los Portadores que llegaron hasta aquí dicen que la música suena distinta: como si la luna entera la escuchara con ellos.',
        'Bearers who made it this far say music sounds different: as if the whole moon were listening with them.'),
    Txt('Más allá del cien no hay más niveles. Solo una leyenda, y un trono que nunca está ocupado del todo.',
        'Past a hundred there are no more levels. Only a legend, and a throne that is never quite occupied.'),
    Txt('Tsuki no juzga a nadie. Solo escucha. Y recuerda todo lo que alguna vez sonó.',
        'Tsuki judges no one. It only listens. And it remembers everything that ever sounded.'),
  ];
}
