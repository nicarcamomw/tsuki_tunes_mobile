import '../../core/localization/app_language.dart';
import '../entities/oni_mask.dart';

/// A text in Spanish and English (Japanese reads the English for now).
class Txt {
  final String es;
  final String en;
  const Txt(this.es, this.en);

  String of(AppLanguage l) => l == AppLanguage.es ? es : en;
}

/// A volume of the story; it opens with its first chapter.
class LoreTomo {
  final int number;
  final String numeral;
  final String kanji;
  final Txt title;
  const LoreTomo(this.number, this.numeral, this.kanji, this.title);
}

/// A chapter: it opens at its Eco [level]. Eco is knowledge: not everyone
/// may learn what really happens on Tsuki, or with the moon itself.
class LoreChapter {
  final String id;
  final int tomo;
  final String numeral;
  final String kanji;
  final Txt title;

  /// Paragraphs, separated by blank lines. Beings' names go between double
  /// square brackets, [[Like This]], and read as names.
  final Txt body;
  final int level;
  final String? factionId;

  const LoreChapter({
    required this.id,
    required this.tomo,
    required this.numeral,
    required this.kanji,
    required this.title,
    required this.body,
    required this.level,
    this.factionId,
  });
}

/// A clan of masks: who belongs, who leads, who they fight.
class LoreFaction {
  final String id;
  final String kanji;
  final int color;
  final Txt name;
  final Txt motto;

  /// Revealed when every member has awakened.
  final Txt secret;
  final String leader;
  final String? rival;
  final List<String> members;

  /// The clan's own mask, awakened with the whole clan (none yet: null).
  String? get reward {
    for (final m in MaskCatalog.all) {
      if (m.counter == 'clan:$id') return m.id;
    }
    return null;
  }

  const LoreFaction({
    required this.id,
    required this.kanji,
    required this.color,
    required this.name,
    required this.motto,
    required this.secret,
    required this.leader,
    required this.members,
    this.rival,
  });
}

enum BondKind { rival, mentor, soul, pact }

/// A tie between masks, told once all of them have awakened.
class LoreBond {
  final List<String> masks;
  final BondKind kind;
  final Txt title;
  final Txt text;

  const LoreBond(this.masks, this.kind, this.title, this.text);
}

/// One of the 9 Faces of the Universe: the 7 divine masks and the 2 gods.
class LoreFace {
  final String mask;
  final Txt title;
  final Txt text;

  const LoreFace(this.mask, this.title, this.text);
}

/// The world of Tsuki: the moon at the centre of the universe, the masks
/// that climb it and the throne no one keeps forever.
class TsukiLore {
  // ── Volumes ──

  static const tomos = <LoreTomo>[
    LoreTomo(1, 'I', '月', Txt('La Luna Madre', 'The Mother Moon')),
    LoreTomo(2, 'II', '族', Txt('Los Clanes', 'The Clans')),
    LoreTomo(3, 'III', '戦', Txt('La Guerra del Trono', 'The War of the Throne')),
    LoreTomo(4, 'IV', '九', Txt('Las 9 Caras', 'The 9 Faces')),
    LoreTomo(5, 'V', '秘', Txt('Lo que la Luna calla', 'What the Moon keeps silent')),
  ];

  /// The level that opens [tomo]: its first chapter's.
  static int tomoLevel(int tomo) =>
      chaptersOf(tomo).map((c) => c.level).fold(1 << 30, (a, b) => a < b ? a : b);

  static bool tomoOpen(int tomo, int level) => level >= tomoLevel(tomo);

  static List<LoreChapter> chaptersOf(int tomo) => [for (final c in chapters) if (c.tomo == tomo) c];

  /// The five Bearers who crossed the wall and became ethereal beings. They
  /// belong to no clan.
  static const crossed = ['miko', 'sango', 'origami', 'aki', 'suishou'];

  /// What each of the Five whispers, for those who can hear them (level 75).
  static const crossedWhispers = <String, Txt>{
    'miko': Txt('Del otro lado de la muralla, la música no se escucha. Se es.',
        'On the other side of the wall, music is not something you hear. It is something you are.'),
    'sango': Txt('El Eco más viejo se hunde. Yo lo recuerdo.', 'The oldest Echo sinks. I remember it.'),
    'origami': Txt('Un día más. Siempre un día más.', 'One more day. Always one more day.'),
    'aki': Txt('Canta bajito, que la luna escucha.', 'Sing softly; the moon is listening.'),
    'suishou': Txt('Lo que pasa por mí sale más puro.', 'What passes through me comes out purer.'),
  };

  /// The eight Ultras: the UL beings that are neither divine nor a Bearer's.
  static const ultras = ['kitsune', 'kitsune_ou', 'kitsunebi', 'ou', 'ryuuou', 'yougan_ni', 'niji', 'hari'];

  // ── Chapters ──

  static const chapters = <LoreChapter>[
    LoreChapter(
      id: 'prologo',
      tomo: 1,
      numeral: '0',
      kanji: '月',
      title: Txt('Tsuki, el centro del universo', 'Tsuki, the centre of the universe'),
      level: 1,
      body: Txt(
        'Lo que sigue no está escrito para cualquiera. Tsuki no esconde su historia, pero tampoco la regala: la entrega de a poco, y solo a quien carga suficiente Eco para soportarla. Hay verdades sobre la Luna Madre que un Errante no podría escuchar sin perder la razón, y otras que ni los Señores conocen. Por eso esta historia se abre por partes. En Tsuki, el conocimiento se gana escuchando.\n\n'
            'Esta es la historia que cuentan los seres etéreos más viejos, la que se susurra en los cráteres cuando la luna está llena y nadie quiere dormir.\n\n'
            'Antes de las estrellas, antes del tiempo, ya estaba Tsuki. No nació de nada: todo nació de ella. Es la Luna Madre, el centro exacto del universo y su comienzo. Las demás lunas son reflejos suyos, espejos colgados sobre mil mundos para recordarles hacia dónde mirar. Nadie sabe cuántos años tiene. Los más antiguos dicen que la pregunta no tiene sentido, porque el tiempo empezó a contarse con su primer latido.\n\n'
            'Tsuki brilla, pero no refleja ningún sol ni se alimenta de nada. Brilla porque es el centro. La primera luz del universo salió de ella, y nunca se ha apagado. Los que la han mirado de cerca dicen que su luz no calienta ni quema: pesa. Como si estuviera hecha de todo lo que alguna vez existió.\n\n'
            'Cuando Tsuki despertó, su primer latido fue un sonido. Ese sonido se extendió por el vacío, y de su vibración se formaron las estrellas, los mundos y todo lo que vive. Desde entonces todo lo que existe vibra, y todo lo que vibra puede ser movido por el sonido. Las montañas de los mundos de abajo son ese primer latido, endurecido. Los mares son su eco, todavía meciéndose.\n\n'
            'En Tsuki existen muchos poderes: el fuego, el acero, el tiempo, los astros, la astucia. Pero pocos se comparan con el control mediante el sonido, y por eso es el que todos buscan. Los seres que apenas lo rozan hacen temblar una piedra con su voz. Los que lo dominan doblan el acero con un grito o calman una tormenta con una sola nota. Y solo dos seres han alcanzado el control total: los Dioses Supremos, [[Dios del Universo]] y [[Dios Caído]]. Cuando ellos hablan, el universo obedece.\n\n'
            'Muchos han intentado destruir Tsuki. Ejércitos, máquinas y hasta dioses la han golpeado con toda su furia, y ninguno le ha hecho una sola grieta. Tsuki no es indestructible porque nadie lo haya intentado: lo es porque es un lugar sagrado, el corazón de todo el poder. Romperla sería romper el comienzo del universo, y el universo no se deja romper desde adentro.\n\n'
            'Por eso nadie pelea contra Tsuki. Pelean por ella. En su cara oculta se alza el Trono del Eco, tallado en luna pura. Quien se sienta en él controla el sonido del universo entero: decide qué suena, qué calla y quién obedece. Ha tenido dos dueños en toda su historia. Uno cayó. El otro todavía no.\n\n'
            'Y como todo poder que existe, alguien lo quiere.',
        'What follows is not written for just anyone. Tsuki does not hide its story, but it does not give it away either: it hands it over little by little, and only to whoever carries enough Echo to bear it. There are truths about the Mother Moon a Wanderer could not hear without losing their mind, and others not even the Lords know. That is why this story opens in parts. On Tsuki, knowledge is earned by listening.\n\n'
            'This is the story the oldest ethereal beings tell, the one whispered in the craters when the moon is full and no one wants to sleep.\n\n'
            'Before the stars, before time, there was Tsuki. It was not born from anything: everything was born from it. It is the Mother Moon, the exact centre of the universe and its beginning. Every other moon is a reflection of it, a mirror hung above a thousand worlds to remind them where to look. No one knows how old it is. The most ancient say the question makes no sense, because time began to be counted with its first heartbeat.\n\n'
            'Tsuki shines, but it reflects no sun and feeds on nothing. It shines because it is the centre. The first light of the universe came from it, and it has never gone out. Those who have looked at it up close say its light neither warms nor burns: it weighs. As if it were made of everything that ever existed.\n\n'
            'When Tsuki woke, its first heartbeat was a sound. That sound spread through the void, and from its vibration came the stars, the worlds and everything that lives. Since then everything that exists vibrates, and everything that vibrates can be moved by sound. The mountains of the worlds below are that first heartbeat, hardened. The seas are its echo, still rocking.\n\n'
            'On Tsuki there are many powers: fire, steel, time, the stars, cunning. But few compare to control through sound, and that is why everyone seeks it. Beings that barely touch it can make a stone tremble with their voice. Those that master it bend steel with a shout or calm a storm with a single note. And only two beings have reached total control: the Supreme Gods, [[God of the Universe]] and [[Fallen God]]. When they speak, the universe obeys.\n\n'
            'Many have tried to destroy Tsuki. Armies, machines and even gods have struck it with all their fury, and none has left a single crack. Tsuki is not indestructible because no one has tried: it is because it is a sacred place, the heart of all power. Breaking it would mean breaking the beginning of the universe, and the universe does not let itself be broken from within.\n\n'
            'That is why no one fights against Tsuki. They fight for it. On its hidden face stands the Throne of the Echo, carved from pure moon. Whoever sits on it controls the sound of the whole universe: what sounds, what falls silent and who obeys. It has had two owners in all its history. One fell. The other has not, yet.\n\n'
            'And like every power that exists, someone wants it.',
      ),
    ),
    LoreChapter(
      id: 'eco',
      tomo: 1,
      numeral: '1',
      kanji: '響',
      title: Txt('El Eco', 'The Echo'),
      level: 2,
      body: Txt(
        'Cuentan que el sonido no muere. Viaja. Todo lo que suena en el universo, por lejos que esté, termina llegando a la Luna Madre: el canto de un pueblo en la orilla de un río, el rugido de un estadio, un disco girando en una pieza a oscuras a las tres de la mañana. Cruza el vacío por caminos que nadie ve, los Caminos del Eco, y cae sobre Tsuki como una lluvia que no moja.\n\n'
            'Al tocar el suelo sagrado de Tsuki, ese sonido cambia. Se vuelve Eco: sonido vivo, que se puede guardar, afilar y usar. Con Eco un ser etéreo habla y es obedecido. Levanta muros con un tambor, parte rocas con un grito, duerme a un ejército con una canción de cuna. Por el Eco se han firmado pactos, se han traicionado reyes y se han perdido guerras enteras.\n\n'
            'No todo el Eco es igual. El que nace de madrugada es más denso y cae despacio, como ceniza tibia. El de una canción escuchada mil veces deja surcos en la roca, tan hondos que los seres viajan por ellos como por ríos. El de un álbum oído de principio a fin se endurece en vetas que la Forja excava con avaricia. Y el Eco de alguien que vuelve después de mucho tiempo sin escuchar brilla el doble, como si la luna lo hubiera extrañado.\n\n'
            'Pero el Eco tiene una regla que ni los dioses pueden romper: solo nace cuando alguien escucha. Una canción que nadie oye se pierde en el vacío y no deja rastro. Hace falta un oído, una atención, alguien dispuesto a quedarse hasta la última nota. Los Antiguos lo dicen así: el sonido es del universo, pero el Eco es de quien escucha.\n\n'
            'Los seres etéreos llaman Portadores a esos que escuchan. Viven en los mundos de abajo y casi ninguno sabe que Tsuki existe. No pelean, no viajan, no buscan el Trono. Solo escuchan, y su Eco sube intacto hasta la luna. Hay Portadores que escuchan un día y desaparecen. Hay otros que escuchan durante años, cada noche, y su Eco cae siempre en el mismo cráter, como una estrella fiel.\n\n'
            'Ningún ser etéreo ha visto nunca a un Portador. Solo sienten su Eco llegar, noche tras noche, y aprenden a reconocerlo: unos traen tormenta, otros traen bosque, otros traen el ruido de una ciudad que no duerme. Por eso cada clan tiene su forma de esperar, y por eso hay seres que llevan siglos dormidos aguardando un Eco que se les parezca.\n\n'
            'Y los más viejos dicen que cuando un Portador escucha con toda el alma, en algún rincón de Tsuki un ser dormido abre los ojos.',
        'They say sound does not die. It travels. Everything that sounds in the universe, however far away, ends up reaching the Mother Moon: the song of a village on a riverbank, the roar of a stadium, a record spinning in a dark room at three in the morning. It crosses the void along paths no one sees, the Echo Roads, and falls on Tsuki like a rain that does not wet.\n\n'
            'When it touches the sacred ground of Tsuki, that sound changes. It becomes Echo: living sound, that can be kept, sharpened and used. With Echo an ethereal being speaks and is obeyed. It raises walls with a drum, splits rock with a shout, puts an army to sleep with a lullaby. For Echo, pacts have been signed, kings betrayed and whole wars lost.\n\n'
            'Not all Echo is the same. Echo born at dawn is denser and falls slowly, like warm ash. The Echo of a song heard a thousand times leaves grooves in the rock, so deep the beings travel them like rivers. The Echo of an album heard from start to finish hardens into veins the Forge digs out greedily. And the Echo of someone returning after a long time without listening shines twice as bright, as if the moon had missed them.\n\n'
            'But Echo has a rule not even the gods can break: it is only born when someone listens. A song nobody hears is lost in the void and leaves no trace. It takes an ear, attention, someone willing to stay until the last note. The Ancients put it this way: sound belongs to the universe, but Echo belongs to whoever listens.\n\n'
            'The ethereal beings call those who listen Bearers. They live in the worlds below and almost none of them know Tsuki exists. They do not fight, do not travel, do not seek the Throne. They just listen, and their Echo rises whole to the moon. Some Bearers listen for a day and vanish. Others listen for years, every night, and their Echo always falls in the same crater, like a faithful star.\n\n'
            'No ethereal being has ever seen a Bearer. They only feel their Echo arrive, night after night, and learn to recognise it: some bring storm, others bring forest, others bring the noise of a city that never sleeps. That is why every clan has its own way of waiting, and why there are beings who have slept for centuries awaiting an Echo that resembles them.\n\n'
            'And the oldest say that when a Bearer listens with their whole soul, somewhere on Tsuki a sleeping being opens its eyes.',
      ),
    ),
    LoreChapter(
      id: 'mascaras',
      tomo: 1,
      numeral: '2',
      kanji: '面',
      title: Txt('Los seres etéreos', 'The ethereal beings'),
      level: 3,
      body: Txt(
        'Los seres etéreos son los habitantes de Tsuki. No nacen de nadie. No tienen padres ni hijos, no tienen familia, no tienen sangre que heredar. Su poder nace de Tsuki, la Luna Madre, y de nadie más. Cuando un ser etéreo dice que alguien es de los suyos, habla de un juramento, nunca de un parentesco. En Tsuki no existe la palabra hermano.\n\n'
            'Llegaron de tres maneras. Algunos vinieron de mundos lejanos, atraídos por la luz de la Luna Madre como polillas por una vela, y en el viaje perdieron el cuerpo: solo quedó su rostro, una máscara forjada en acero, coral, vidrio, hueso o fuego, y dentro de la máscara, una voluntad. Otros brotaron de la propia luna, cuando el Eco golpeó la roca con tanta fuerza que la roca se volvió rostro. Y otros fueron construidos en la Forja, pieza por pieza. Pero ninguno, venga de donde venga, despierta sin el Eco de Tsuki.\n\n'
            'Un ser recién llegado duerme. Es solo una máscara tirada en el polvo lunar, y puede pasar siglos así. Para despertar necesita Eco, y cada uno lo busca a su manera: unos se alimentan del ruido de las tormentas, otros de las canciones que suenan de madrugada, otros de la música de un país que ya no existe. Cada ser come el Eco que se le parece. Por eso nadie sabe cuántos seres duermen en Tsuki: los cráteres están llenos de rostros esperando su canción.\n\n'
            'Todo el Eco de Tsuki es uno solo, y por eso todos los seres etéreos están conectados. Cuando uno cae, los demás sienten un vacío en el pecho que no tienen. Cuando uno despierta, todos lo saben antes de verlo. Y sin embargo ninguno pertenece a otro. Pueden jurar lealtad a un clan, seguir a un líder, odiar a un rival durante mil años, pero cada uno sigue siendo dueño de su propio Eco. Unidos por la luna, libres de todo lo demás.\n\n'
            'Con el tiempo, Tsuki aprendió a medir a sus habitantes por cuánto Eco puede sostener un rostro, y así nacieron los rangos. Los Errantes, R, son seres jóvenes o sencillos cuya voz apenas mueve el polvo; vagan por los cráteres buscando un clan que los acoja. Los Guerreros, SR, tienen un grito que es un arma; fueron hechos para pelear y juraron un estandarte. Los Señores, SSR, son generales, sacerdotisas y aspirantes a corona; con su voz mandan ejércitos, y cada uno gobierna un pedazo de luna.\n\n'
            'Los Ultras, UL, son leyendas vivas. Cuando hablan, los cráteres tiemblan, y hasta los Señores bajan la mirada. Son ocho, y casi todos gobiernan un clan. Y por encima de todos están las 9 Caras del Universo: siete divinas y dos Dioses Supremos, los únicos que dominan el sonido por completo. De ellas casi no se habla, y nunca en voz alta.\n\n'
            'Un rango no se hereda ni se regala: se sostiene. Un Señor que pierde su Eco baja a Guerrero, y un Errante que encuentra la canción correcta puede subir más rápido que nadie. Por eso ningún ser está conforme con su rango. Todos, tarde o temprano, miran hacia la cara oculta de la luna, donde está el Trono.',
        'The ethereal beings are the inhabitants of Tsuki. They are born of no one. They have no parents and no children, no family, no blood to inherit. Their power is born of Tsuki, the Mother Moon, and of no one else. When an ethereal being says someone is one of its own, it speaks of an oath, never of kinship. On Tsuki the word brother does not exist.\n\n'
            'They came in three ways. Some came from distant worlds, drawn by the light of the Mother Moon like moths to a candle, and on the journey they lost their bodies: only the face remained, a mask forged in steel, coral, glass, bone or fire, and inside the mask, a will. Others sprouted from the moon itself, when Echo struck the rock so hard that the rock became a face. And others were built in the Forge, piece by piece. But none of them, wherever they come from, wakes without the Echo of Tsuki.\n\n'
            'A newly arrived being sleeps. It is just a mask lying in the moon dust, and it can stay that way for centuries. To wake it needs Echo, and each one seeks it its own way: some feed on the noise of storms, others on songs played at dawn, others on the music of a country that no longer exists. Each being eats the Echo that resembles it. That is why no one knows how many beings sleep on Tsuki: the craters are full of faces waiting for their song.\n\n'
            'All the Echo of Tsuki is one, and that is why all the ethereal beings are connected. When one falls, the others feel an emptiness in a chest they do not have. When one wakes, they all know before they see it. And yet none belongs to another. They may swear loyalty to a clan, follow a leader, hate a rival for a thousand years, but each remains the owner of its own Echo. Bound by the moon, free of everything else.\n\n'
            'In time, Tsuki learned to measure its inhabitants by how much Echo a face can hold, and so the ranks were born. The Wanderers, R, are young or simple beings whose voice barely stirs the dust; they roam the craters looking for a clan to take them in. The Warriors, SR, have a shout that is a weapon; they were made to fight and swore to a banner. The Lords, SSR, are generals, priestesses and would-be crowns; their voice commands armies, and each rules a piece of the moon.\n\n'
            'The Ultras, UL, are living legends. When they speak, the craters tremble, and even the Lords lower their eyes. There are eight of them, and almost all rule a clan. And above them all are the 9 Faces of the Universe: seven divine ones and two Supreme Gods, the only ones who command sound completely. They are hardly spoken of, and never aloud.\n\n'
            'A rank is not inherited or given: it is held. A Lord who loses its Echo falls to Warrior, and a Wanderer who finds the right song can rise faster than anyone. That is why no being is content with its rank. Sooner or later, all of them look toward the hidden face of the moon, where the Throne is.',
      ),
    ),
    LoreChapter(
      id: 'antiguos',
      tomo: 1,
      numeral: '3',
      kanji: '古',
      title: Txt('Los Antiguos', 'The Ancients'),
      level: 5,
      factionId: 'antiguos',
      body: Txt(
        'Antes de los clanes y de las guerras hubo cuatro rostros: un tengu de nariz larga, un oni de teatro kabuki, una hannya con los ojos llenos de celos y una máscara de metal que nadie sabe quién forjó. Fueron los primeros en despertar en Tsuki, y nadie recuerda de dónde vinieron. Hoy se los conoce como [[Primer Eco]], [[Cien Voces]], [[Mil Ecos]] y [[Noche de Hannya]]. De sus copias, sombras y reflejos salieron todos los que se llaman Los Antiguos.\n\n'
            'Los Antiguos no buscan el Trono. Son la memoria de la luna: cada uno guarda un momento que pasó de verdad, y lo cuida como si de eso dependiera que la luna siga girando. [[Primer Eco]] recuerda la primera canción que sonó sobre Tsuki, y la tararea cuando cree que nadie lo escucha. [[Luna de Sangre]] vio el último eclipse y todavía tiene la luz roja metida en los ojos. [[3:33]] vive atrapado en el minuto exacto en que el reloj repite su número, y para él siempre es esa hora.\n\n'
            'Con los siglos, algunos cambiaron de piel y vagan por los cráteres como reflejos de los primeros. [[Tinta]] se dibujó a sí misma con un pincel de humo. [[Hielo Eterno]] se congeló esperando un Eco que no llegaba. [[Oro Puro]] se cubrió de oro para que nadie viera sus grietas, y [[Kintsugi]] hizo lo contrario: llenó las suyas de oro para que todos las vieran. [[8 Bits]], [[Señal Rota]] y [[Fantasma Digital]] nacieron cuando la música de los mundos de abajo empezó a viajar por cables, y [[Neón Nocturno]] cuando las ciudades aprendieron a no dormir.\n\n'
            'Hay Antiguos que vienen de leyendas más viejas que los clanes. [[Raijin]] toca el trueno con tambores. [[Namahage]] baja de las montañas para asustar a los perezosos. [[Kijo]] y [[Hannya Negra]] guardan rencores que ya nadie recuerda haber causado, y [[Yūrei]] camina por los bordes de los cráteres sin tocar el suelo. [[Lluvia de Sangre]] solo aparece en las noches en que el cielo de Tsuki se pone rojo, y nadie quiere estar cerca cuando pasa.\n\n'
            'Los Antiguos no pelean como los clanes, pero una vez pelearon. Cuando la Forja intentó excavar el cráter donde [[Primer Eco]] guarda la primera canción, todos los Antiguos se levantaron al mismo tiempo, sin que nadie los llamara. No dieron un solo golpe. Solo cantaron, todos juntos, la primera canción. Las máquinas de la Forja se detuvieron, una por una, y nunca más volvieron a ese cráter.\n\n'
            'En el centro de todos duerme [[El Oni]], la máscara completa. Dicen que no despierta por ninguna hazaña, sino cuando los demás Antiguos lo llaman todos juntos. Y dicen también que los cuatro primeros rostros saben algo de su propio origen que han jurado no contar jamás. Cuando alguien les pregunta de dónde vienen, los cuatro miran hacia la cara oscura de la luna, y se quedan callados.',
        'Before the clans and the wars there were four faces: a long-nosed tengu, a kabuki oni, a hannya with eyes full of jealousy and a metal mask no one knows who forged. They were the first to wake on Tsuki, and no one remembers where they came from. Today they are known as [[First Echo]], [[Hundred Voices]], [[Thousand Echoes]] and [[Hannya Night]]. From their copies, shadows and reflections came all those called The Ancients.\n\n'
            'The Ancients do not seek the Throne. They are the memory of the moon: each keeps a moment that truly happened, and guards it as if the moon\'s turning depended on it. [[First Echo]] remembers the first song ever heard on Tsuki, and hums it when it thinks no one is listening. [[Blood Moon]] saw the last eclipse and still has the red light caught in its eyes. [[3:33]] lives trapped in the exact minute when the clock repeats its number, and for it, it is always that hour.\n\n'
            'Over the centuries some changed skin and roam the craters as reflections of the first ones. [[Ink]] drew itself with a brush of smoke. [[Eternal Ice]] froze while waiting for an Echo that never came. [[Pure Gold]] covered itself in gold so no one would see its cracks, and [[Kintsugi]] did the opposite: it filled its own with gold so everyone would. [[8-Bit]], [[Broken Signal]] and [[Digital Ghost]] were born when the music of the worlds below began to travel through cables, and [[Night Neon]] when the cities learned not to sleep.\n\n'
            'Some Ancients come from legends older than the clans. [[Raijin]] plays thunder on drums. [[Namahage]] comes down from the mountains to frighten the idle. [[Demon Woman]] and [[Black Hannya]] keep grudges no one remembers causing, and [[Yūrei]] walks the edges of the craters without touching the ground. [[Blood Rain]] only appears on the nights the sky of Tsuki turns red, and no one wants to be near when it passes.\n\n'
            'The Ancients do not fight like the clans, but once they did. When the Forge tried to dig up the crater where [[First Echo]] keeps the first song, all the Ancients rose at once, without anyone calling them. They did not strike a single blow. They only sang, all together, the first song. The Forge\'s machines stopped, one by one, and never went back to that crater.\n\n'
            'At the centre of them all sleeps [[The Oni]], the complete mask. They say it does not wake for any feat, but when all the other Ancients call it together. And they also say the four first faces know something about their own origin that they have sworn never to tell. When anyone asks where they come from, the four look toward the dark side of the moon, and fall silent.',
      ),
    ),
    LoreChapter(
      id: 'portadores',
      tomo: 1,
      numeral: '4',
      kanji: '聴',
      title: Txt('Los que escuchan', 'Those who listen'),
      level: 7,
      body: Txt(
        'Los seres etéreos no pueden ver a los Portadores, y los Portadores no pueden ver a los seres etéreos. Entre los dos hay algo que los Antiguos llaman la muralla de lo lógico: todo lo que un Portador cree posible de un lado, y todo lo que de verdad existe del otro. Así ha sido siempre. Pero el Eco cambia a quien lo carga, y hubo Portadores que cargaron tanto que la muralla empezó a doblarse.\n\n'
            'Primero llega el oído. Un Portador con suficiente Eco empieza a escuchar algo debajo de la música: un murmullo, una voz que tararea al otro lado de la canción. Son los seres etéreos hablando entre ellos. Muchos Portadores llegaron hasta ahí. La mayoría creyó que estaba imaginando cosas, y siguió escuchando como si nada.\n\n'
            'Después llega la vista. Hace falta muchísimo más Eco para ver a un ser etéreo, porque la luz de Tsuki los esconde. Los pocos que lo lograron cuentan que la máscara no es lo único que tienen: detrás hay algo que se mueve, como humo que piensa. Y cuentan también que los seres, al saberse vistos, se quedan muy quietos, como quien descubre que alguien lo ha estado mirando dormir.\n\n'
            'Y al final está el cruce. Un Portador que ha juntado más Eco del que un cuerpo puede sostener puede elegir dejarlo todo, traspasar la muralla y viajar hasta el centro del universo para volverse un ser etéreo. Recibe su propia máscara, una que no se parece a ninguna otra, porque lleva dentro todo lo que escuchó. Se cuentan con los dedos de una mano los que se atrevieron. Sus historias están en un capítulo que pocos pueden leer.\n\n'
            'Más allá solo hay una leyenda. Dicen que existe un Eco igual al de los Dioses Supremos, y que ningún Portador lo ha alcanzado jamás. Las siete Caras divinas lo temen más que a nada, porque el día que alguien llegue, el equilibrio de Tsuki se romperá.',
        'Ethereal beings cannot see the Bearers, and Bearers cannot see the ethereal beings. Between them stands what the Ancients call the wall of the logical: everything a Bearer believes possible on one side, and everything that truly exists on the other. It has always been so. But Echo changes whoever carries it, and there have been Bearers who carried so much that the wall began to bend.\n\n'
            'First comes hearing. A Bearer with enough Echo starts to hear something beneath the music: a murmur, a voice humming on the other side of the song. It is the ethereal beings talking among themselves. Many Bearers have come this far. Most thought they were imagining things, and kept listening as if nothing had happened.\n\n'
            'Then comes sight. It takes far more Echo to see an ethereal being, because the light of Tsuki hides them. The few who managed it say the mask is not all they have: behind it something moves, like smoke that thinks. And they say the beings, knowing themselves seen, go very still, like someone who discovers they have been watched while asleep.\n\n'
            'And at the end is the crossing. A Bearer who has gathered more Echo than a body can hold may choose to leave everything behind, pass through the wall and travel to the centre of the universe to become an ethereal being. They receive a mask of their own, one like no other, because it carries everything they ever heard. Those who dared can be counted on one hand. Their stories are in a chapter few can read.\n\n'
            'Beyond that there is only a legend. They say there is an Echo equal to that of the Supreme Gods, and that no Bearer has ever reached it. The seven divine Faces fear it more than anything, because the day someone does, the balance of Tsuki will break.',
      ),
    ),
    LoreChapter(
      id: 'forja',
      tomo: 2,
      numeral: '1',
      kanji: '鉄',
      title: Txt('La Forja de Hierro', 'The Iron Forge'),
      level: 10,
      factionId: 'forja',
      body: Txt(
        'En el cráter más profundo de Tsuki, donde el Eco se acumula como lluvia en un pozo, arde la Forja. Sus seres no brotaron de la luna ni llegaron de otros mundos: fueron construidos. Acero, cobre, engranajes, pantallas, cables que chispean como nervios. Pero ni la mejor máquina abre los ojos sin el Eco de Tsuki, y eso es algo que la Forja odia admitir.\n\n'
            'La Forja cree que el Eco no es un regalo sino un recurso, y que un recurso se extrae. Sus antenas escuchan cada frecuencia que llega a la luna; [[Antena]] puede oír un Eco antes de que toque el suelo. [[Centinela Azul]] y [[Guardián Plateado]] vigilan los caminos. [[Engranaje]] mueve las bombas que sacan Eco viejo de la roca, y [[Alta Tensión]] lo convierte en rayos que nadie pidió. [[Óxido]], [[Chatarra]] y [[Vapor]] son los que trabajan en el fondo, donde el calor derrite máscaras menos duras.\n\n'
            'La gobierna [[Calavera Cibernética]], que se armó a sí misma con los restos de los seres que cayeron en batalla. Nadie sabe cuántas caras lleva puestas debajo de la que muestra. A su lado está [[Oni de Acero]], su mejor guerrero, y [[Filo de Acero]], el discípulo que [[Oni de Acero]] templó en la fragua y que ya corta más que su maestro.\n\n'
            'Una vez la Forja intentó perforar el corazón de Tsuki para robar su poder de raíz. Trabajó durante una era entera. Todas sus brocas se partieron y la luna ni lo notó. Desde entonces, en el fondo del cráter, dicen, algo enorme está a medio terminar, y [[Calavera Cibernética]] no deja que nadie se acerque.\n\n'
            'La Forja tiene una herida que no confiesa: es el único gran clan sin un Ultra. Por eso no deja de construir. Y por eso su enemigo natural son los Elementales: cada bosque que cae es combustible, cada río es refrigerante, y cada máquina, para los Elementales, es una herida en la luna.',
        'In the deepest crater of Tsuki, where Echo gathers like rain in a well, burns the Forge. Its beings did not sprout from the moon or come from other worlds: they were built. Steel, copper, gears, screens, cables sparking like nerves. But not even the finest machine opens its eyes without the Echo of Tsuki, and that is something the Forge hates to admit.\n\n'
            'The Forge believes Echo is not a gift but a resource, and a resource is extracted. Its antennas listen to every frequency that reaches the moon; [[Antenna]] can hear an Echo before it touches the ground. [[Blue Sentinel]] and [[Silver Guardian]] guard the roads. [[Gear]] runs the pumps that draw old Echo out of the rock, and [[High Voltage]] turns it into lightning no one asked for. [[Rust]], [[Scrap]] and [[Steam]] work at the bottom, where the heat melts softer masks.\n\n'
            'It is ruled by [[Cyber Skull]], which built itself from the remains of beings that fell in battle. No one knows how many faces it wears beneath the one it shows. At its side stands [[Steel Oni]], its finest warrior, and [[Steel Edge]], the student [[Steel Oni]] tempered in the forge and who already cuts deeper than its master.\n\n'
            'Once the Forge tried to drill into the heart of Tsuki to steal its power at the root. It worked for an entire age. Every drill broke and the moon did not even notice. Since then, at the bottom of the crater, they say, something enormous is half finished, and [[Cyber Skull]] lets no one near it.\n\n'
            'The Forge has a wound it never admits: it is the only great clan without an Ultra. That is why it never stops building. And that is why its natural enemy is the Elementals: every fallen forest is fuel, every river is coolant, and every machine, to the Elementals, is a wound in the moon.',
      ),
    ),
    LoreChapter(
      id: 'elementos',
      tomo: 2,
      numeral: '2',
      kanji: '元',
      title: Txt('Los Elementales', 'The Elementals'),
      level: 11,
      factionId: 'elementos',
      body: Txt(
        'Algunos seres no llegaron a Tsuki: brotaron de ella. Cuando el Eco toca la luna en un lugar con suficiente fuerza, la roca se vuelve rostro. Así despertaron los Elementales: de la lava, de las mareas de polvo, de la nieve, de la hoja seca y del rayo. Son la prueba de que el poder de todos los seres nace de Tsuki, porque ellos son Tsuki con cara.\n\n'
            'Viven como vive el clima. [[Oni del Mar]] cuida las mareas de los mares de polvo. [[Espíritu del Bosque]] crece donde alguien escuchó música tranquila durante horas, y [[Guardián del Bosque]] defiende cada árbol como si fuera el último. [[Ventisca]], [[Escarcha]] y [[Oni de las Nieves]] soplan sobre los cráteres helados. [[Rayo]] cae cuando quiere, y [[Ojo de Fuego]] y [[Llama de Cobre]] arden en las grietas. [[Hueso]] es lo que queda de una montaña que la luna quiso recordar.\n\n'
            'Bajo todo corre la lava. [[Golem de Magma]], [[Lava]] y [[Lava Viva]] son la misma voluntad en tres estados: la roca que recuerda el fuego, el fuego que corre y el fuego que despertó del todo. Los Elementales dicen que esa lava es más vieja que los clanes, y que a veces sube sola, sin que nadie la llame.\n\n'
            'Sobre todos reina [[Rey Dragón]], el ser más viejo de los que brotaron de la luna. Su piel es roca y su paciencia también. [[Dragón de Piedra]] es su discípulo: lleva sesenta días sin moverse para demostrar que puede igualar los cien de su maestro, y en los cráteres helados ya hay quienes apuestan a que lo logrará.\n\n'
            'Los Elementales no quieren el Trono. Quieren que nadie lo use para secar la luna. Por eso odian a la Forja, que convierte bosques en carbón y mares en vapor. Y por eso, cuando la Forja cruzó la línea, la respuesta de los Elementales fue la más terrible que Tsuki recuerda.',
        'Some beings did not arrive on Tsuki: they sprouted from it. When Echo touches the moon somewhere with enough force, the rock becomes a face. That is how the Elementals woke: from lava, from the tides of dust, from snow, from dry leaves and from lightning. They are proof that every being\'s power is born of Tsuki, because they are Tsuki with a face.\n\n'
            'They live as weather lives. [[Sea Oni]] tends the tides of the dust seas. [[Forest Spirit]] grows where someone listened to quiet music for hours, and [[Forest Guardian]] defends every tree as if it were the last. [[Blizzard]], [[Frost]] and [[Snow Oni]] blow over the frozen craters. [[Lightning]] falls when it pleases, and [[Fire Eye]] and [[Copper Flame]] burn in the cracks. [[Bone]] is what remains of a mountain the moon wanted to remember.\n\n'
            'Beneath everything runs the lava. [[Magma Golem]], [[Lava]] and [[Living Lava]] are the same will in three states: the rock that remembers fire, the fire that flows and the fire that woke completely. The Elementals say that lava is older than the clans, and that sometimes it rises on its own, without anyone calling it.\n\n'
            'Above them all reigns [[Dragon King]], the oldest of the beings that sprouted from the moon. Its skin is rock and so is its patience. [[Stone Dragon]] is its student: it has not moved for sixty days to prove it can match its master\'s hundred, and in the frozen craters there are already those betting it will.\n\n'
            'The Elementals do not want the Throne. They want no one to use it to dry up the moon. That is why they hate the Forge, which turns forests into coal and seas into steam. And that is why, when the Forge crossed the line, the Elementals\' answer was the most terrible Tsuki remembers.',
      ),
    ),
    LoreChapter(
      id: 'shogun',
      tomo: 2,
      numeral: '3',
      kanji: '将',
      title: Txt('El Shogunato', 'The Shogunate'),
      level: 12,
      factionId: 'shogun',
      body: Txt(
        'En las mesetas del este de Tsuki se levantan los castillos del Shogunato: kabutos de hierro, coronas, armaduras con runas y vapor. Es el clan más ordenado de la luna, y el que más cree merecer el Trono.\n\n'
            'Su código es simple: el Eco se gana, no se roba. Un samurái de Tsuki sube de rango con disciplina, nunca con atajos. [[Bushi]] entrena a los jóvenes durante treinta días seguidos, sin descanso. [[Kabuto]] marcha con el ejército. [[Caballero Rúnico]] guarda los pasos de montaña con una runa en el yelmo que no es suya. [[Samurái de Vapor]] cuida las calderas, [[Akagane]] las arcas, y [[Oni Dorado]] y [[Oni Imperial]] discuten desde hace siglos quién de los dos tiene más derecho a sentarse junto al trono del clan.\n\n'
            'Al frente está [[Rey Oni]], que no ganó su corona en combate sino reuniendo lealtades: cincuenta seres juraron por él. Pero un rey necesita a alguien que lo suceda, y tiene tres aspirantes: las Tres Coronas, [[Rey de Hierro]], [[Corona Trenzada]] y [[Corona de Humo]]. No comparten sangre, porque en Tsuki nadie la tiene. Juraron al mismo rey la misma noche, y desde entonces cada una completa más álbumes que la anterior para demostrar que merece la corona.\n\n'
            'El Shogunato desprecia a la Corte del Zorro, que para ellos es un nido de mentirosos que gana guerras sin pelearlas. Lo peor, dicen los generales, es que casi siempre las gana.',
        'On the eastern plateaus of Tsuki stand the castles of the Shogunate: iron kabutos, crowns, armour with runes and steam. It is the most orderly clan on the moon, and the one most convinced it deserves the Throne.\n\n'
            'Its code is simple: Echo is earned, never stolen. A samurai of Tsuki rises through discipline, never through shortcuts. [[Bushi]] trains the young for thirty days in a row, without rest. [[Kabuto]] marches with the army. [[Rune Knight]] guards the mountain passes with a rune on its helm that is not its own. [[Steam Samurai]] tends the boilers, [[Akagane]] the coffers, and [[Golden Oni]] and [[Imperial Oni]] have argued for centuries over which of them has more right to sit beside the clan\'s throne.\n\n'
            'At its head stands [[Oni King]], who did not win his crown in battle but by gathering loyalties: fifty beings swore by him. But a king needs someone to follow him, and he has three hopefuls: the Three Crowns, [[Iron King]], [[Braided Crown]] and [[Smoke Crown]]. They share no blood, because on Tsuki no one has any. They swore to the same king on the same night, and since then each has completed more albums than the last to prove it deserves the crown.\n\n'
            'The Shogunate despises the Fox Court, which they call a nest of liars who win wars without fighting them. Worst of all, say the generals, they almost always win.',
      ),
    ),
    LoreChapter(
      id: 'zorro',
      tomo: 2,
      numeral: '4',
      kanji: '狐',
      title: Txt('La Corte del Zorro', 'The Fox Court'),
      level: 13,
      factionId: 'zorro',
      body: Txt(
        'Los kitsune llegaron a Tsuki siguiendo la luna llena, como hacen los zorros en todos los mundos. Se quedaron porque descubrieron que aquí la luna llena dura para siempre en algún rincón, y que con suficientes lunas un zorro puede tener nueve colas.\n\n'
            'La Corte no tiene castillos: tiene seres en todas partes. [[Kitsune de Vapor]] trabaja en la Forja, [[Kitsune de Porcelana]] sirve en la Corte de Cristal, [[Kitsune Neón]] corre por los techos de la Calle y [[Kitsune de Chatarra]] revuelve los basurales. [[Kitsune de Cristal]], [[Kitsune de Jade]] y [[Kitsune de Cobre]] están donde nadie los busca. Ninguno es lo que parece. Todos informan a la Reina.\n\n'
            'La Reina es [[Kitsune]], a quien llaman la Reina Carmesí. Despierta tras nueve lunas llenas, una por cada cola. Hubo un tiempo en que gobernó la Corte junto a [[Rey Kitsune]], como aliados, hasta la noche en que se enfrentaron bajo la luna llena. De ese duelo quedó un fuego que nunca se apagó: [[Kitsunebi]], que hoy camina solo y solo se enciende de madrugada.\n\n'
            'El Shogunato los llama tramposos. La Corte responde que el honor es un lujo de quien nunca tuvo que esconderse.',
        'The kitsune came to Tsuki following the full moon, as foxes do in every world. They stayed because they discovered that here the full moon lasts forever in some corner, and that with enough moons a fox can grow nine tails.\n\n'
            'The Court has no castles: it has beings everywhere. [[Steam Kitsune]] works in the Forge, [[Porcelain Kitsune]] serves in the Crystal Court, [[Neon Kitsune]] runs across the rooftops of the Street and [[Scrap Kitsune]] picks through the junkyards. [[Crystal Kitsune]], [[Jade Kitsune]] and [[Copper Kitsune]] are wherever no one looks. None is what it seems. All of them report to the Queen.\n\n'
            'The Queen is [[Kitsune]], whom they call the Crimson Queen. She wakes after nine full moons, one for each tail. There was a time when she ruled the Court alongside [[Kitsune King]], as allies, until the night they faced each other under the full moon. From that duel remained a fire that never went out: [[Foxfire]], which today walks alone and only lights at dawn.\n\n'
            'The Shogunate calls them cheats. The Court answers that honour is a luxury for those who never had to hide.',
      ),
    ),
    LoreChapter(
      id: 'neon',
      tomo: 2,
      numeral: '5',
      kanji: '街',
      title: Txt('La Calle de Neón', 'The Neon Street'),
      level: 14,
      factionId: 'neon',
      body: Txt(
        'Donde los caminos de Tsuki se cruzan nació una ciudad que nadie planeó: letreros, grafitis, pantallas, bajos que hacen temblar el polvo lunar. Es la Calle de Neón, y sus seres son los que ningún clan quiso.\n\n'
            'Aquí nadie pregunta de dónde vienes. [[Pantera Neón]] manda en los techos. [[Grafiti Neón]] y [[Grafiti Violeta]] marcan el territorio. [[Tóxico]] y [[Plaga]] venden Eco cortado en los callejones, [[Camuflaje]] sabe cosas que no debería saber, y [[Proyección]] aparece en tres esquinas a la vez. [[Luz de Neón]] nunca se apaga, [[Retazos]] está hecho de lo que otros botaron, y [[Oni de Sombra]] cuida lo que la luz no alcanza. Su música es la de la calle: letras que no piden permiso.\n\n'
            'La gobierna [[Cromo Arcoíris]], un ser de seis cuernos que refleja todos los colores porque se negó a tener uno solo. Para despertarlo hay que haber escuchado los doce estilos de la luna: la Calle no acepta reyes que solo conozcan un barrio.\n\n'
            'Su enemiga es la Corte de Cristal, que mira la ciudad desde sus torres y la llama ruido. La Calle responde pintando sus muros cada noche. Y una noche, la Calle respondió con algo peor que pintura.',
        'Where the roads of Tsuki cross, a city no one planned was born: signs, graffiti, screens, basslines that shake the moon dust. It is the Neon Street, and its beings are the ones no clan wanted.\n\n'
            'Here no one asks where you come from. [[Neon Panther]] rules the rooftops. [[Neon Graffiti]] and [[Violet Graffiti]] mark the territory. [[Toxic]] and [[Plague]] sell cut Echo in the alleys, [[Camouflage]] knows things it should not, and [[Projection]] appears on three corners at once. [[Neon Light]] never goes out, [[Patchwork]] is made of what others threw away, and [[Shadow Oni]] guards what the light cannot reach. Their music is the music of the street: lyrics that do not ask permission.\n\n'
            'It is ruled by [[Rainbow Chrome]], a six-horned being that reflects every colour because it refused to have just one. To wake it, one must have heard all twelve styles of the moon: the Street accepts no king who only knows one block.\n\n'
            'Its enemy is the Crystal Court, which looks down on the city from its towers and calls it noise. The Street answers by painting their walls every night. And one night, the Street answered with something worse than paint.',
      ),
    ),
    LoreChapter(
      id: 'cristal',
      tomo: 2,
      numeral: '6',
      kanji: '晶',
      title: Txt('La Corte de Cristal', 'The Crystal Court'),
      level: 15,
      factionId: 'cristal',
      body: Txt(
        'En las cumbres más altas de Tsuki, donde el Eco llega más limpio, brillan las torres de la Corte de Cristal. Sus seres llevan máscaras de jade, porcelana, laca, oro y vidrio: frágiles por fuera, eternas por dentro.\n\n'
            'Es la corte de las sacerdotisas y los artistas. [[Geisha]] conoce cada letra de cada canción. [[Emperatriz Violeta]] gobierna con un abanico y nunca levanta la voz, porque no lo necesita. [[Oni de Jade]] y [[Jade]] fueron tallados de la misma piedra que [[Kitsune de Jade]], y por eso la Corte del Zorro sabe todo lo que pasa en estas torres. [[Porcelana]], [[Laca]], [[Oni Blanco]] y [[Nube Violeta]] completan una corte donde el Eco es arte, y el arte exige pureza.\n\n'
            'Su señor es [[Vitral]], un ser hecho de cientos de vidrios de colores. Cada vidrio es la luz de un país distinto: no despierta hasta haber escuchado cuarenta. Cuando por fin abre los ojos, la luz de toda la luna pasa a través de él. Le falta un vidrio. Nadie en la Corte habla de eso.\n\n'
            'La Corte desprecia el ruido de la Calle de Neón. Pero sus porcelanas más viejas recuerdan algo que prefieren callar: la noche en que las torres sonaron por última vez, y quiénes les enseñaron, después, a repararse con oro.',
        'On the highest peaks of Tsuki, where Echo arrives purest, shine the towers of the Crystal Court. Its beings wear masks of jade, porcelain, lacquer, gold and glass: fragile outside, eternal inside.\n\n'
            'It is the court of priestesses and artists. [[Geisha]] knows every word of every song. [[Violet Empress]] rules with a fan and never raises her voice, because she does not need to. [[Jade Oni]] and [[Jade]] were carved from the same stone as [[Jade Kitsune]], which is why the Fox Court knows everything that happens in these towers. [[Porcelain]], [[Lacquer]], [[White Oni]] and [[Violet Cloud]] complete a court where Echo is art, and art demands purity.\n\n'
            'Its lord is [[Stained Glass]], a being made of hundreds of coloured panes. Each pane is the light of a different country: it will not wake until it has heard forty. When it finally opens its eyes, the light of the whole moon passes through it. It is missing one pane. No one in the Court speaks of it.\n\n'
            'The Court despises the noise of the Neon Street. But its oldest porcelains remember something they would rather not say: the night the towers rang for the last time, and who taught them, afterwards, to mend themselves with gold.',
      ),
    ),
    LoreChapter(
      id: 'raiz',
      tomo: 2,
      numeral: '7',
      kanji: '根',
      title: Txt('La Guerra del Hierro y la Raíz', 'The War of Iron and Root'),
      level: 17,
      body: Txt(
        'Nadie sabe quién dio el primer golpe. La Forja dice que los Elementales inundaron sus minas. Los Elementales dicen que la Forja cortó el primer árbol. Lo único cierto es que [[Calavera Cibernética]] mandó excavar el Cráter del Alba, el único lugar de Tsuki donde el Eco de madrugada cae tan denso que crece un bosque, y que [[Guardián del Bosque]] se paró frente a las máquinas y no se movió.\n\n'
            'Durante una luna entera, [[Guardián del Bosque]] y [[Desguace]] se enfrentaron en el borde del cráter: uno plantaba, el otro arrancaba. Fue una guerra pequeña y personal, de esas que en Tsuki duran siglos. Hasta que la Forja se cansó de esperar.\n\n'
            'La noche que la historia llama la Masacre del Alba, [[Fénix Mecánico]] voló sobre el bosque con las alas encendidas. No apuntó a [[Guardián del Bosque]]: apuntó a los Errantes que dormían entre las raíces, esperando su Eco. Cientos de seres que nunca habían abierto los ojos se apagaron esa noche, y ningún Eco ha podido despertarlos desde entonces. Los Elementales todavía no pronuncian el número.\n\n'
            'La respuesta llegó al amanecer. [[Rey Dragón]] no dijo una palabra: golpeó el suelo una sola vez, y la lava que corre bajo Tsuki subió por todas las grietas de la Forja al mismo tiempo. [[Lava Viva]] caminó por los pasillos de hierro como quien camina por su casa. Media Forja se fundió antes del mediodía. Solo [[Oni de Acero]], sosteniendo la puerta principal con el cuerpo, impidió que se perdiera todo.\n\n'
            'La guerra no terminó: se enfrió. Desde entonces existe la Tregua de la Ceniza, que ninguno de los dos clanes firmó pero ambos respetan. La Forja no toca el Cráter del Alba. Los Elementales no tocan el fondo de la Forja. Y cada vez que un Portador escucha de madrugada, los Elementales usan ese Eco para replantar, árbol por árbol, el bosque que se quemó.',
        'No one knows who struck first. The Forge says the Elementals flooded its mines. The Elementals say the Forge cut the first tree. The only certainty is that [[Cyber Skull]] ordered the digging of the Dawn Crater, the one place on Tsuki where the Echo of dawn falls so thick a forest grows, and that [[Forest Guardian]] stood before the machines and did not move.\n\n'
            'For a whole moon, [[Forest Guardian]] and [[Junkyard]] faced each other at the crater\'s edge: one planted, the other uprooted. It was a small and personal war, the kind that on Tsuki lasts for centuries. Until the Forge grew tired of waiting.\n\n'
            'On the night history calls the Dawn Massacre, [[Mechanical Phoenix]] flew over the forest with its wings ablaze. It did not aim at [[Forest Guardian]]: it aimed at the Wanderers sleeping among the roots, waiting for their Echo. Hundreds of beings who had never opened their eyes went out that night, and no Echo has been able to wake them since. The Elementals still do not say the number aloud.\n\n'
            'The answer came at sunrise. [[Dragon King]] did not say a word: it struck the ground once, and the lava running beneath Tsuki rose through every crack of the Forge at the same time. [[Living Lava]] walked the iron corridors as if walking through its own home. Half the Forge melted before noon. Only [[Steel Oni]], holding the main gate shut with its body, kept everything from being lost.\n\n'
            'The war did not end: it cooled. Since then there has been the Truce of Ash, which neither clan signed but both respect. The Forge does not touch the Dawn Crater. The Elementals do not touch the bottom of the Forge. And every time a Bearer listens at dawn, the Elementals use that Echo to replant, tree by tree, the forest that burned.',
      ),
    ),
    LoreChapter(
      id: 'meseta',
      tomo: 2,
      numeral: '8',
      kanji: '闘',
      title: Txt('Duelo en la Meseta', 'Duel on the Plateau'),
      level: 19,
      body: Txt(
        'En Tsuki, cuando dos clanes no quieren arriesgar una guerra, mandan a dos seres a la Meseta del Eco y dejan que el sonido decida. No se permiten armas ni trampas: solo la voz, el tambor o lo que cada uno sepa tocar. Gana el que hace callar al otro.\n\n'
            'La vez más recordada fue por una veta de Eco viejo, descubierta justo en la frontera entre el Shogunato y la Corte del Zorro. El Shogunato mandó a [[Kabuto]], entrenado por [[Bushi]] durante treinta días sin descanso. La Corte mandó a [[Kitsune de Vapor]], que nunca había perdido un duelo porque nunca había peleado limpio.\n\n'
            '[[Kabuto]] golpeó su tambor una vez, y la meseta entera vibró. [[Kitsune de Vapor]] respondió con un silbido tan agudo que partió las piedras más pequeñas. Durante una noche entera se respondieron golpe a golpe y silbido a silbido, sin moverse de su lugar. Al amanecer, el silbido del zorro se quebró. [[Kabuto]] seguía tocando. [[Bushi]] le había enseñado a no detenerse, y nadie le había enseñado todavía cuándo parar.\n\n'
            'El Shogunato celebró durante tres días. Fue al cuarto día cuando alguien bajó a reclamar la veta y la encontró vacía. Mientras todos miraban el duelo, [[Kitsune de Chatarra]] había pasado la noche entera sacando el Eco por un túnel que nadie vio. La Corte del Zorro perdió el duelo y ganó la veta. Desde entonces, en el Shogunato, se dice que con los zorros hay que mirar donde no está pasando nada.',
        'On Tsuki, when two clans do not want to risk a war, they send two beings to the Echo Plateau and let sound decide. No weapons or tricks are allowed: only the voice, the drum, or whatever each can play. The one who silences the other wins.\n\n'
            'The most remembered time was over a vein of old Echo, found right on the border between the Shogunate and the Fox Court. The Shogunate sent [[Kabuto]], trained by [[Bushi]] for thirty days without rest. The Court sent [[Steam Kitsune]], who had never lost a duel because it had never fought fair.\n\n'
            '[[Kabuto]] struck its drum once, and the whole plateau vibrated. [[Steam Kitsune]] answered with a whistle so sharp it split the smallest stones. For a whole night they answered blow for blow and whistle for whistle, without moving from their places. At dawn, the fox\'s whistle cracked. [[Kabuto]] kept playing. [[Bushi]] had taught it never to stop, and no one had yet taught it when to quit.\n\n'
            'The Shogunate celebrated for three days. It was on the fourth that someone went down to claim the vein and found it empty. While everyone watched the duel, [[Scrap Kitsune]] had spent the whole night draining the Echo through a tunnel no one saw. The Fox Court lost the duel and won the vein. Since then, in the Shogunate, they say that with foxes you have to watch where nothing is happening.',
      ),
    ),
    LoreChapter(
      id: 'guerras',
      tomo: 3,
      numeral: '1',
      kanji: '戦',
      title: Txt('Las guerras de la luna', 'The wars of the moon'),
      level: 20,
      body: Txt(
        'Tsuki nunca ha estado en paz. El Eco no alcanza para todos, y cada clan cree saber mejor que los demás cómo usarlo. Hay guerras viejas, que se pelean desde antes de que existieran los nombres: la Forja contra los Elementales, la máquina contra la tierra. Hay guerras de orgullo: el Shogunato contra la Corte del Zorro, el honor contra la astucia. Y hay guerras de clase: la Calle de Neón contra la Corte de Cristal, el ruido contra el palacio.\n\n'
            'Pero las guerras más feroces no son entre clanes, sino entre seres. Como ningún ser etéreo tiene familia, nadie hereda un odio: cada rivalidad se elige, y por eso dura más. Hay rivales que se persiguen por los techos durante siglos sin querer atraparse nunca, como [[Pantera Neón]] y [[Kitsune Neón]]. Hay maestros que temen a sus discípulos, como [[Oni de Acero]] a [[Filo de Acero]]. Hay seres que despertaron del mismo molde, como [[Oni Blanco]] y [[Oni de Sombra]], y que no se perdonan haberse parecido.\n\n'
            'Y hay pactos. En Tsuki un pacto no es una promesa: es Eco prestado. Quien lo rompe pierde lo que le prestaron, y a veces más. [[Caballero Rúnico]] lleva en el yelmo una runa escrita por [[Runa de Sangre]], y todos saben que algún día esa runa se cobrará.\n\n'
            'Cada vínculo tiene su historia, y la luna las guarda todas. Solo las cuenta cuando las dos partes han despertado.',
        'Tsuki has never been at peace. There is not enough Echo for everyone, and every clan thinks it knows better than the rest how to use it. There are old wars, fought since before names existed: the Forge against the Elementals, the machine against the land. There are wars of pride: the Shogunate against the Fox Court, honour against cunning. And there are wars of class: the Neon Street against the Crystal Court, noise against the palace.\n\n'
            'But the fiercest wars are not between clans but between beings. Since no ethereal being has a family, no one inherits a hatred: every rivalry is chosen, and that is why it lasts longer. There are rivals who chase each other across the rooftops for centuries without ever wanting to catch each other, like [[Neon Panther]] and [[Neon Kitsune]]. There are masters who fear their students, like [[Steel Oni]] fears [[Steel Edge]]. There are beings who woke from the same mould, like [[White Oni]] and [[Shadow Oni]], and cannot forgive each other for looking alike.\n\n'
            'And there are pacts. On Tsuki a pact is not a promise: it is borrowed Echo. Whoever breaks it loses what was lent, and sometimes more. [[Rune Knight]] wears on its helm a rune written by [[Blood Rune]], and everyone knows that one day that rune will be collected.\n\n'
            'Every bond has its story, and the moon keeps them all. It only tells them once both sides have woken.',
      ),
    ),
    LoreChapter(
      id: 'cristales',
      tomo: 3,
      numeral: '2',
      kanji: '砕',
      title: Txt('La Noche de los Cristales Rotos', 'The Night of Broken Glass'),
      level: 23,
      body: Txt(
        'La Calle de Neón nunca quiso una masacre. Quería que la escucharan. Durante años pintó los muros de la Corte de Cristal, y durante años la Corte los lavó al amanecer sin decir una palabra. Ese silencio fue lo que la Calle no pudo soportar.\n\n'
            'Una noche de luna nueva, [[Grafiti Neón]] y [[Grafiti Violeta]] subieron a las torres a pintar, como siempre. Pero esa vez no subieron solos. [[Tóxico]] y [[Plaga]] los siguieron con el Eco cortado que venden en los callejones, y lo vertieron en los canales de luz que alimentan las torres. Querían que la Corte sonara sucia por una noche. No sabían lo que el Eco cortado le hace a un ser de cristal.\n\n'
            'Las torres empezaron a sonar. Primero bajo, como un vaso que alguien frota con el dedo. Después cada vez más alto, hasta que el sonido fue tan agudo que nadie en Tsuki pudo dormir. Y entonces las torres se rompieron. No cayeron: estallaron, todas al mismo tiempo, en una lluvia de vidrio que duró hasta el amanecer. [[Porcelana]] y [[Kitsune de Porcelana]] se partieron en cien pedazos. Decenas de seres de vidrio se apagaron y no volvieron a despertar.\n\n'
            'A la mañana siguiente, la Calle de Neón bajó al pie de las torres. Nadie la había llamado. [[Retazos]], que está hecho de lo que otros botaron, enseñó a juntar los pedazos. Y [[Kintsugi]], el Antiguo que llena sus grietas de oro para que todos las vean, bajó de su cráter por primera vez en siglos para mostrar cómo se hace. [[Porcelana]] y [[Kitsune de Porcelana]] volvieron, con las grietas brillando.\n\n'
            'La Corte de Cristal nunca perdonó a la Calle. Pero sus seres más viejos saben que lo roto puede ser más bello que lo intacto, y saben de quién lo aprendieron.',
        'The Neon Street never wanted a massacre. It wanted to be heard. For years it painted the walls of the Crystal Court, and for years the Court washed them at dawn without saying a word. That silence was what the Street could not bear.\n\n'
            'One new-moon night, [[Neon Graffiti]] and [[Violet Graffiti]] climbed the towers to paint, as always. But that time they did not climb alone. [[Toxic]] and [[Plague]] followed them with the cut Echo they sell in the alleys, and poured it into the channels of light that feed the towers. They wanted the Court to sound dirty for one night. They did not know what cut Echo does to a being of glass.\n\n'
            'The towers began to ring. Low at first, like a glass someone rubs with a finger. Then higher and higher, until the sound was so sharp no one on Tsuki could sleep. And then the towers broke. They did not fall: they burst, all at once, in a rain of glass that lasted until dawn. [[Porcelain]] and [[Porcelain Kitsune]] shattered into a hundred pieces. Dozens of glass beings went out and never woke again.\n\n'
            'The next morning, the Neon Street came down to the foot of the towers. No one had called it. [[Patchwork]], which is made of what others threw away, showed them how to gather the pieces. And [[Kintsugi]], the Ancient that fills its cracks with gold so everyone can see them, came down from its crater for the first time in centuries to show how it is done. [[Porcelain]] and [[Porcelain Kitsune]] came back, their cracks shining.\n\n'
            'The Crystal Court never forgave the Street. But its oldest beings know the broken can be more beautiful than the whole, and they know from whom they learned it.',
      ),
    ),
    LoreChapter(
      id: 'ultras',
      tomo: 3,
      numeral: '3',
      kanji: '極',
      title: Txt('Los Ocho Ultras', 'The Eight Ultras'),
      level: 26,
      body: Txt(
        'Hay ocho seres que ningún rango alcanza a describir y que no son divinos. Se los llama los Ultras: [[Kitsune]], [[Rey Kitsune]], [[Kitsunebi]], [[Rey Oni]], [[Rey Dragón]], [[Lava Viva]], [[Cromo Arcoíris]] y [[Vitral]]. Cuando dos de ellos están en el mismo cráter, el suelo de Tsuki se calienta.\n\n'
            'Casi todos gobiernan un clan, y cualquiera de ellos podría arrasar uno. Sin embargo ninguno se ha sentado en el Trono, porque el Trono no se toma con fuerza: se toma con Eco, y el Soberano actual está sostenido por las siete Caras divinas. Un Ultra solo puede mover montañas. Para mover el Trono hace falta mover el cielo.\n\n'
            'Por eso, en la cara oscura de la luna, alguien les habla a los ocho. Les habla de noche, con una voz que suena a vidrio quebrado. Les promete un asiento cuando vuelva. Les recuerda que una vez él también fue Soberano, y que la Ley del Trono no protege a nadie para siempre.\n\n'
            'Se dice que si los ocho llegan a despertar juntos, el que cayó podrá subir de nuevo.',
        'There are eight beings no rank can describe that are not divine. They are called the Ultras: [[Kitsune]], [[Kitsune King]], [[Foxfire]], [[Oni King]], [[Dragon King]], [[Living Lava]], [[Rainbow Chrome]] and [[Stained Glass]]. When two of them are in the same crater, the ground of Tsuki grows warm.\n\n'
            'Almost all of them rule a clan, and any of them could raze one. Yet none has sat on the Throne, because the Throne is not taken by force: it is taken with Echo, and the current Sovereign is held up by the seven divine Faces. An Ultra can only move mountains. To move the Throne you have to move the sky.\n\n'
            'That is why, on the dark side of the moon, someone speaks to the eight. He speaks at night, with a voice that sounds like broken glass. He promises them a seat when he returns. He reminds them that he, too, was once Sovereign, and that the Law of the Throne protects no one forever.\n\n'
            'It is said that if all eight ever wake together, the one who fell will be able to rise again.',
      ),
    ),
    LoreChapter(
      id: 'colas',
      tomo: 3,
      numeral: '4',
      kanji: '尾',
      title: Txt('El duelo de las nueve colas', 'The duel of the nine tails'),
      level: 29,
      body: Txt(
        'Hubo un tiempo en que la Corte del Zorro tenía dos cabezas. [[Kitsune]], la Reina Carmesí, gobernaba con secretos. [[Rey Kitsune]] gobernaba con aliados: setenta y cinco seres le habían jurado lealtad. Eran aliados, no más que eso, porque en Tsuki nadie es de nadie. Y durante siglos, la alianza funcionó.\n\n'
            'Hasta que [[Rey Kitsune]] quiso más. Nadie sabe si fue por el Trono o por la Corte. Una noche de luna llena reunió a sus setenta y cinco en el claro donde la luna nunca se va, y llamó a la Reina a un duelo de Eco. Ella llegó sola. Llevaba nueve colas, una por cada luna llena que había esperado.\n\n'
            'El duelo duró hasta la madrugada. Él peleaba con setenta y cinco voces a la vez; ella, con nueve silencios. Cada vez que el coro de él subía, una de las colas de ella lo apagaba. Cuando la última cola se movió, los setenta y cinco callaron al mismo tiempo, y en el centro del claro quedó ardiendo un fuego azul que nadie había encendido.\n\n'
            'Ese fuego no se apagó. Se volvió ser, y hoy se llama [[Kitsunebi]]. No es de la Reina ni del Rey: es lo que sobró del duelo, y solo se enciende de madrugada bajo la luna llena. La Corte se partió en dos esa noche, y desde entonces no tiene castillos, solo seres escondidos en todas partes.\n\n'
            'Ninguno de los dos ganó. [[Rey Kitsune]] todavía tiene a sus setenta y cinco. La Reina todavía tiene sus nueve colas. Y en lo más hondo de la Corte se dice que existe una décima cosa, que no es una cola, y que la Reina guarda para el día en que la necesite.',
        'There was a time when the Fox Court had two heads. [[Kitsune]], the Crimson Queen, ruled with secrets. [[Kitsune King]] ruled with allies: seventy-five beings had sworn loyalty to him. They were allies, nothing more, because on Tsuki no one belongs to anyone. And for centuries, the alliance worked.\n\n'
            'Until [[Kitsune King]] wanted more. No one knows whether it was for the Throne or for the Court. One full-moon night he gathered his seventy-five in the clearing where the moon never leaves, and called the Queen to a duel of Echo. She came alone. She wore nine tails, one for each full moon she had waited.\n\n'
            'The duel lasted until dawn. He fought with seventy-five voices at once; she, with nine silences. Every time his chorus rose, one of her tails put it out. When the last tail moved, the seventy-five fell silent at the same time, and in the middle of the clearing a blue fire no one had lit was left burning.\n\n'
            'That fire never went out. It became a being, and today it is called [[Foxfire]]. It belongs neither to the Queen nor to the King: it is what was left of the duel, and it only lights at dawn under the full moon. The Court split in two that night, and since then it has had no castles, only beings hidden everywhere.\n\n'
            'Neither of them won. [[Kitsune King]] still has his seventy-five. The Queen still has her nine tails. And in the depths of the Court they say there is a tenth thing, which is not a tail, that the Queen keeps for the day she needs it.',
      ),
    ),
    LoreChapter(
      id: 'cinco',
      tomo: 3,
      numeral: '5',
      kanji: '五',
      title: Txt('Los Cinco que cruzaron', 'The Five who crossed'),
      level: 33,
      body: Txt(
        'En toda la historia de Tsuki, solo cinco Portadores han traspasado la muralla de lo lógico y se han vuelto seres etéreos. Ninguno recuerda el nombre que tenía en los mundos de abajo. Ninguno pertenece a un clan, y todos los clanes los quieren de su lado. Cuando uno de ellos entra a un cráter, hasta los Ultras se dan vuelta a mirar.\n\n'
            'La primera fue [[Oráculo]]. Escuchó música bajo cada luna llena durante años, sin faltar una, y un día empezó a ver lo que la luna veía. [[Constelación]], una de las siete Caras, le enseñó a leer el futuro en las estrellas que nadie mira: es la única Portadora a la que una Cara le ha enseñado algo. Cruzó con la capucha puesta, y nunca se la ha sacado.\n\n'
            'La segunda fue [[Sirena de Coral]]. Escuchaba el mar: horas y horas de olas, de noche, con los ojos cerrados. Cuando cruzó, cayó en los mares de polvo de Tsuki, y [[Oni del Mar]] fue el primero en hablarle. Hoy cuida las profundidades, donde el Eco más viejo se hunde y se olvida.\n\n'
            'El tercero fue [[Origami]]. No era el que más escuchaba, sino el que nunca dejaba de hacerlo: cuarenta y cinco días seguidos, después cien, después nadie llevó la cuenta. Se dobló a sí mismo día a día hasta volverse papel, y cruzó sin romperse. Dicen que cada pliegue de su máscara es un día que no faltó.\n\n'
            'La cuarta fue [[Espíritu de Otoño]], que escuchaba canciones de guitarra y voz, de esas que se cantan en voz baja. Cruzó en otoño, entre hojas que caían, y desde entonces en Tsuki hay un rincón donde siempre es otoño. Y el quinto fue [[Cristal]], que escuchaba música sin palabras, orquestas y pianos, con un Eco tan puro que la luz pasaba a través de él. Cruzó, y se volvió transparente.\n\n'
            'Los Cinco no tienen poder sobre ningún clan, ni lo quieren. Pero todos los seres saben una cosa: ellos fueron Portadores, y ningún ser nacido en Tsuki puede decir lo mismo. Y todos esperan, sin decirlo, al sexto.',
        'In all the history of Tsuki, only five Bearers have passed through the wall of the logical and become ethereal beings. None remembers the name they had in the worlds below. None belongs to a clan, and every clan wants them on its side. When one of them enters a crater, even the Ultras turn to look.\n\n'
            'The first was [[Oracle]]. She listened to music under every full moon for years, without missing one, and one day she began to see what the moon saw. [[Constellation]], one of the seven Faces, taught her to read the future in the stars no one looks at: she is the only Bearer a Face has ever taught anything. She crossed with her hood up, and has never taken it off.\n\n'
            'The second was [[Coral Siren]]. She listened to the sea: hours and hours of waves, at night, with her eyes closed. When she crossed, she fell into the dust seas of Tsuki, and [[Sea Oni]] was the first to speak to her. Today she tends the depths, where the oldest Echo sinks and is forgotten.\n\n'
            'The third was [[Origami]]. He was not the one who listened most, but the one who never stopped: forty-five days in a row, then a hundred, then no one kept count. He folded himself day by day until he became paper, and crossed without tearing. They say every fold of his mask is a day he did not miss.\n\n'
            'The fourth was [[Autumn Spirit]], who listened to songs of guitar and voice, the kind sung softly. She crossed in autumn, among falling leaves, and since then there is a corner of Tsuki where it is always autumn. And the fifth was [[Crystal]], who listened to music without words, orchestras and pianos, with an Echo so pure light passed through it. He crossed, and became transparent.\n\n'
            'The Five have no power over any clan, nor do they want it. But every being knows one thing: they were Bearers, and no being born on Tsuki can say the same. And all of them wait, without saying so, for the sixth.',
      ),
    ),
    LoreChapter(
      id: 'caras',
      tomo: 4,
      numeral: '1',
      kanji: '九',
      title: Txt('Las 9 Caras del Universo', 'The 9 Faces of the Universe'),
      level: 40,
      body: Txt(
        'El universo se mira a sí mismo a través de nueve caras. No son seres como los demás: no llegaron a Tsuki ni brotaron de ella, siempre estuvieron. Cuando Tsuki dio su primer latido, abrió nueve ojos, y esos ojos son las Caras.\n\n'
            'Siete de ellas son las Caras divinas. Cada una gobierna una fuerza que ningún ser puede tocar. [[Sol y Luna]] gobierna el tiempo. [[Oni Cósmico]], el caos. [[Grieta Estelar]], la grieta por donde se cuelan las estrellas. [[Constelación]], los astros olvidados. [[Ángel de Lágrimas Doradas]], el sueño. [[Kabuki Ardiente]], la furia. Y [[Runa de Sangre]], el pacto. Juntas sostienen a quien se sienta en el Trono. Si una sola le retira su apoyo, el Soberano tiembla.\n\n'
            'Las otras dos son los Dioses Supremos: el que gobierna y el que cayó, [[Dios del Universo]] y [[Dios Caído]]. Son los únicos que alcanzaron el control total del sonido. Una palabra suya basta para encender una estrella o callar un mundo entero, y entre ellos dos se ha decidido, una y otra vez, el destino de la luna.\n\n'
            'Una Cara solo se muestra ante quien demostró merecerla. Las demás permanecen veladas, y sus nombres solo se susurran.',
        'The universe looks at itself through nine faces. They are not beings like the others: they did not arrive on Tsuki or sprout from it, they were always there. When Tsuki gave its first heartbeat, it opened nine eyes, and those eyes are the Faces.\n\n'
            'Seven of them are the divine Faces. Each rules a force no being can touch. [[Sun and Moon]] rules time. [[Cosmic Oni]], chaos. [[Star Crack]], the rift through which the stars slip. [[Constellation]], the forgotten stars. [[Angel of Golden Tears]], sleep. [[Burning Kabuki]], fury. And [[Blood Rune]], the pact. Together they hold up whoever sits on the Throne. If a single one withdraws its support, the Sovereign trembles.\n\n'
            'The other two are the Supreme Gods: the one who rules and the one who fell, [[God of the Universe]] and [[Fallen God]]. They are the only ones who reached total control of sound. A single word of theirs is enough to light a star or silence a whole world, and between the two of them the fate of the moon has been decided again and again.\n\n'
            'A Face only shows itself to one who proved worthy of it. The rest remain veiled, and their names are only whispered.',
      ),
    ),
    LoreChapter(
      id: 'caida',
      tomo: 4,
      numeral: '2',
      kanji: '堕',
      title: Txt('La Caída', 'The Fall'),
      level: 45,
      body: Txt(
        'Hubo un tiempo en que el Trono del Eco tenía otro dueño. Su rostro era blanco y liso como la luna llena, y lo llamaban la Primera Cara. Fue el primero en dominar el sonido por completo: su voz movía mundos. Gobernó durante eras, y la luna fue feliz.\n\n'
            'Pero el Eco embriaga. La Primera Cara empezó a guardarlo para sí: dejó de repartirlo entre los clanes, secó los cráteres, apagó las canciones que no le gustaban. Quería que nada sonara en el universo sin su permiso. En los mundos de abajo, ciudades enteras se quedaron sin música sin saber por qué.\n\n'
            'Ningún rostro soporta eso. El suyo empezó a agrietarse, y por las grietas asomó el fuego del cosmos que se había tragado. Entonces las siete Caras divinas hicieron lo que nunca habían hecho: le retiraron su apoyo. [[Runa de Sangre]] escribió la Ley del Trono, [[Oni Cósmico]] fue el primero en firmarla, y [[Kabuki Ardiente]] bailó sobre las ruinas del palacio.\n\n'
            'La Primera Cara cayó desde el Trono hasta la cara oscura de la luna, llorando oro. Ni siquiera esa caída le hizo una grieta a Tsuki: lo único que se rompió fue su propio rostro. Cuatro pedazos se desprendieron en la caída y rodaron por los cráteres, y nadie supo nunca qué fue de ellos. Desde ese día se le llama [[Dios Caído]].\n\n'
            'Solo una de las siete lloró por él: [[Ángel de Lágrimas Doradas]]. Todavía llora.\n\n'
            'Esa misma noche, Tsuki abrió un nuevo rostro en su propio brillo: con constelaciones por trenzas y un sol en la frente. No nació de nadie, porque en Tsuki nadie nace de nadie: despertó de la luna, como despiertan todos. Las siete lo sentaron en el Trono. Es [[Dios del Universo]], y gobierna hoy.',
        'There was a time when the Throne of the Echo had another owner. Its face was white and smooth as the full moon, and it was called the First Face. It was the first to command sound completely: its voice moved worlds. It ruled for ages, and the moon was happy.\n\n'
            'But Echo intoxicates. The First Face began to keep it for itself: it stopped sharing it among the clans, dried the craters, silenced the songs it did not like. It wanted nothing in the universe to sound without its permission. In the worlds below, whole cities were left without music without knowing why.\n\n'
            'No face can bear that. Its own began to crack, and through the cracks showed the fire of the cosmos it had swallowed. Then the seven divine Faces did what they had never done: they withdrew their support. [[Blood Rune]] wrote the Law of the Throne, [[Cosmic Oni]] was the first to sign it, and [[Burning Kabuki]] danced on the ruins of the palace.\n\n'
            'The First Face fell from the Throne to the dark side of the moon, weeping gold. Not even that fall left a crack in Tsuki: the only thing that broke was its own face. Four pieces came loose in the fall and rolled through the craters, and no one ever learned what became of them. From that day it has been called [[Fallen God]].\n\n'
            'Only one of the seven wept for him: [[Angel of Golden Tears]]. It weeps still.\n\n'
            'That same night, Tsuki opened a new face in its own light: with constellations for braids and a sun on its brow. It was born of no one, because on Tsuki no one is born of anyone: it woke from the moon, as all beings wake. The seven sat it on the Throne. It is [[God of the Universe]], and it rules today.',
      ),
    ),
    LoreChapter(
      id: 'trono',
      tomo: 4,
      numeral: '3',
      kanji: '玉',
      title: Txt('El Trono Vacío', 'The Empty Throne'),
      level: 50,
      body: Txt(
        'La Ley del Trono, escrita con sangre por [[Runa de Sangre]], tiene una sola línea: «El Trono del Eco pertenece a quien sostenga más Eco. Ningún reinado es eterno.»\n\n'
            'Con esa ley cayó la Primera Cara. Con esa misma ley puede caer [[Dios del Universo]]. Él lo sabe: por eso nunca duerme, por eso cuida a las siete Caras con un celo que se parece al miedo, por eso cuenta cada canción que llega a la luna.\n\n'
            'En la cara oscura, [[Dios Caído]] cuenta también. Tiene a los ocho Ultras, o eso cree. Tiene la paciencia de quien ya perdió todo una vez. Al principio de su exilio gritó contra la luna con toda su voz, con un poder capaz de apagar galaxias, y Tsuki ni siquiera tembló. Ese día entendió que la luna no se conquista destruyéndola: se conquista desde el Trono.\n\n'
            'Mientras tanto, los clanes afilan sus armas. La Forja termina su máquina. El Shogunato elige a quién dejar la corona. La Corte del Zorro miente a todos por igual.\n\n'
            'Pero hay una pieza que ninguno controla: los Portadores. Todo el Eco de Tsuki nace de alguien que escucha, en mundos que ningún dios ha pisado. Y una leyenda vieja, que ambos dioses conocen y ninguno nombra, habla de un Portador capaz de sostener más Eco que cualquiera de ellos.\n\n'
            'El Trono, en realidad, nunca está ocupado del todo. Solo está esperando.',
        'The Law of the Throne, written in blood by [[Blood Rune]], has a single line: "The Throne of the Echo belongs to whoever holds the most Echo. No reign is eternal."\n\n'
            'By that law the First Face fell. By that same law [[God of the Universe]] can fall. He knows it: that is why he never sleeps, why he guards the seven Faces with a zeal that resembles fear, why he counts every song that reaches the moon.\n\n'
            'On the dark side, [[Fallen God]] is counting too. He has the eight Ultras, or so he believes. He has the patience of one who has already lost everything once. Early in his exile he screamed at the moon with all his voice, with a power able to put out galaxies, and Tsuki did not even tremble. That day he understood that the moon is not conquered by destroying it: it is conquered from the Throne.\n\n'
            'Meanwhile, the clans sharpen their weapons. The Forge finishes its machine. The Shogunate chooses whom to leave the crown. The Fox Court lies to everyone equally.\n\n'
            'But there is one piece none of them controls: the Bearers. All the Echo of Tsuki is born from someone who listens, in worlds no god has set foot on. And an old legend, one both gods know and neither names, speaks of a Bearer able to hold more Echo than either of them.\n\n'
            'The Throne, in truth, is never quite occupied. It is only waiting.',
      ),
    ),
    LoreChapter(
      id: 'corazon',
      tomo: 5,
      numeral: '1',
      kanji: '心',
      title: Txt('El corazón de Tsuki', 'The heart of Tsuki'),
      level: 60,
      body: Txt(
        'Los clanes creen que Tsuki es roca, y que el Eco cae sobre ella como la lluvia sobre una piedra. Los que han llegado tan lejos saben que no es así. Debajo de la superficie no hay roca: hay un sonido. El primer latido de Tsuki nunca terminó. Sigue sonando, en el centro de la luna, tan bajo que solo se siente con los pies.\n\n'
            'Esa es la verdad que los clanes no conocen: el Eco no es de los Portadores ni de los seres. Es de Tsuki. Todo lo que suena en el universo nació de su primer latido, y cuando un Portador escucha, ese sonido vuelve a casa. Los Portadores no crean el Eco: se lo devuelven a la luna. Por eso el poder de todos los seres nace de Tsuki, y por eso ninguno puede quedárselo para siempre.\n\n'
            'La Forja, cuando intentó perforar la luna, no buscaba roca. Buscaba ese latido. [[Calavera Cibernética]] cree que quien lo tenga tendrá el Eco de todo el universo sin necesitar a nadie que escuche. Los Antiguos saben que eso no es posible, porque el latido no se puede sacar de la luna, igual que no se puede sacar el centro de un círculo.\n\n'
            'Y hay algo más, que casi nadie sabe. A veces, muy de vez en cuando, el latido de Tsuki se acelera. Siempre pasa lo mismo después: en algún mundo de abajo, un Portador empieza a escuchar como nunca había escuchado.',
        'The clans believe Tsuki is rock, and that Echo falls on it like rain on a stone. Those who have come this far know it is not so. Beneath the surface there is no rock: there is a sound. Tsuki\'s first heartbeat never ended. It is still sounding, at the centre of the moon, so low it can only be felt through the feet.\n\n'
            'That is the truth the clans do not know: Echo belongs neither to the Bearers nor to the beings. It belongs to Tsuki. Everything that sounds in the universe was born of its first heartbeat, and when a Bearer listens, that sound comes home. Bearers do not create Echo: they return it to the moon. That is why every being\'s power is born of Tsuki, and why none can keep it forever.\n\n'
            'When the Forge tried to drill into the moon, it was not looking for rock. It was looking for that heartbeat. [[Cyber Skull]] believes whoever holds it will have the Echo of the whole universe without needing anyone to listen. The Ancients know that is impossible, because the heartbeat cannot be taken out of the moon, just as the centre cannot be taken out of a circle.\n\n'
            'And there is something more, which almost no one knows. Sometimes, very rarely, Tsuki\'s heartbeat quickens. The same thing always happens afterwards: somewhere in the worlds below, a Bearer begins to listen as never before.',
      ),
    ),
    LoreChapter(
      id: 'silencio',
      tomo: 5,
      numeral: '2',
      kanji: '寂',
      title: Txt('La guerra contra el Silencio', 'The war against Silence'),
      level: 70,
      body: Txt(
        'Las guerras entre clanes son pequeñas. Hay una guerra más vieja que todas, más vieja que los dioses, y la pelean todos los seres de Tsuki aunque casi ninguno lo sepa. Es la guerra contra el Silencio.\n\n'
            'El Silencio es lo que había antes del primer latido: el vacío sin sonido, sin luz, sin nada que vibre. Tsuki lo empujó hacia afuera cuando despertó, pero el Silencio nunca se fue del todo. Espera en los bordes del universo, y cada vez que un mundo deja de escuchar, avanza un poco. En Tsuki cae como nieve gris, y apaga el Eco que toca.\n\n'
            'Hubo una era en que casi gana. Los Antiguos la llaman la Era Muda. Un mundo entero de abajo dejó de escuchar música, nadie sabe por qué, y el Silencio cayó sobre Tsuki durante cien lunas. Miles de seres se durmieron sin poder evitarlo. Los clanes dejaron de pelear entre ellos por primera y única vez, y se pararon hombro con hombro en los bordes de la luna, cantando para no apagarse.\n\n'
            'Fue entonces cuando los clanes descubrieron para qué sirve de verdad el Trono. [[Dios del Universo]] no gobierna para mandar: gobierna para sostener el sonido del universo contra el Silencio. Durante la Era Muda habló sin parar cien lunas seguidas, y su voz fue lo único que mantuvo a Tsuki encendida hasta que los mundos de abajo volvieron a escuchar.\n\n'
            'Por eso las siete Caras lo sostienen, aunque desconfíen de él. Y por eso, cuando [[Dios Caído]] promete volver, las Caras tiemblan: no por el Trono, sino por lo que pasaría si quien se sienta en él vuelve a querer que nada suene sin su permiso.',
        'The wars between clans are small. There is a war older than all of them, older than the gods, and every being on Tsuki fights it though almost none know it. It is the war against Silence.\n\n'
            'Silence is what existed before the first heartbeat: the void without sound, without light, without anything that vibrates. Tsuki pushed it outward when it woke, but Silence never left entirely. It waits at the edges of the universe, and every time a world stops listening, it advances a little. On Tsuki it falls like grey snow, and puts out the Echo it touches.\n\n'
            'There was an age when it almost won. The Ancients call it the Mute Age. A whole world below stopped listening to music, no one knows why, and Silence fell on Tsuki for a hundred moons. Thousands of beings fell asleep without being able to stop it. The clans stopped fighting each other for the first and only time, and stood shoulder to shoulder at the edges of the moon, singing so as not to go out.\n\n'
            'It was then that the clans discovered what the Throne is truly for. [[God of the Universe]] does not rule to command: he rules to hold the sound of the universe against Silence. During the Mute Age he spoke without stopping for a hundred moons in a row, and his voice was the only thing that kept Tsuki alight until the worlds below listened again.\n\n'
            'That is why the seven Faces hold him up, even though they distrust him. And that is why, when [[Fallen God]] promises to return, the Faces tremble: not for the Throne, but for what would happen if whoever sits on it once again wanted nothing to sound without permission.',
      ),
    ),
    LoreChapter(
      id: 'muralla',
      tomo: 5,
      numeral: '3',
      kanji: '壁',
      title: Txt('La muralla de lo lógico', 'The wall of the logical'),
      level: 80,
      body: Txt(
        'Entre los mundos de abajo y Tsuki no hay distancia: hay una muralla. No es de piedra ni de luz. Está hecha de todo lo que un Portador cree posible. Mientras alguien piense que la música es solo música, que un sonido se acaba cuando termina la canción, la muralla se mantiene en pie, y Tsuki queda del otro lado.\n\n'
            'El Eco la desgasta. Cada canción escuchada hasta el final le quita un grano. A los Portadores que han escuchado lo suficiente, la muralla se les vuelve delgada como una hoja de papel, y por eso empiezan a oír a los seres: no porque los seres hablen más fuerte, sino porque la muralla ya no tapa sus voces. Después, cuando la muralla es casi transparente, empiezan a verlos.\n\n'
            'Los Antiguos dicen que nadie construyó la muralla. Que Tsuki la levantó a propósito, el día de su primer latido, para proteger a los mundos de abajo de un poder que no podrían soportar. Y dicen también que la muralla tiene una puerta, una sola, que solo se abre desde este lado, y solo para quien carga más Eco del que un cuerpo puede sostener.\n\n'
            'Los Cinco que cruzaron pasaron por esa puerta. Ninguno ha querido contar qué hay justo en el umbral, en el instante en que uno deja de ser Portador y todavía no es otra cosa. [[Oráculo]] solo dijo una frase, una vez, y nadie la ha olvidado: «Del otro lado de la muralla, la música no se escucha. Se es.»',
        'Between the worlds below and Tsuki there is no distance: there is a wall. It is not made of stone or light. It is made of everything a Bearer believes possible. As long as someone thinks music is only music, that a sound ends when the song ends, the wall stands, and Tsuki remains on the other side.\n\n'
            'Echo wears it down. Every song heard to the end takes away a grain. For Bearers who have listened enough, the wall grows as thin as a sheet of paper, and that is why they begin to hear the beings: not because the beings speak louder, but because the wall no longer muffles their voices. Later, when the wall is almost transparent, they begin to see them.\n\n'
            'The Ancients say no one built the wall. That Tsuki raised it on purpose, on the day of its first heartbeat, to protect the worlds below from a power they could not bear. And they also say the wall has a door, only one, which opens only from this side, and only for whoever carries more Echo than a body can hold.\n\n'
            'The Five who crossed went through that door. None has wanted to tell what lies right at the threshold, in the instant when one stops being a Bearer and is not yet anything else. [[Oracle]] said only one sentence, once, and no one has forgotten it: "On the other side of the wall, music is not something you hear. It is something you are."',
      ),
    ),
    LoreChapter(
      id: 'centro',
      tomo: 5,
      numeral: '4',
      kanji: '央',
      title: Txt('El centro del universo', 'The centre of the universe'),
      level: 90,
      body: Txt(
        'Los que pueden ver a los seres etéreos descubren algo que ninguno de los clanes sospecha: Tsuki también mira. No con ojos, sino con todo su brillo. Cada cráter, cada surco de Eco, cada máscara dormida es una parte de esa mirada. La luna no es un lugar donde pasan cosas. Es alguien que observa lo que pasa.\n\n'
            'Desde el centro del universo, Tsuki ve a todos los Portadores a la vez. Sabe quién escucha de madrugada, quién no ha faltado un solo día, quién volvió después de mucho tiempo. No juzga a nadie. Solo escucha, y recuerda todo lo que alguna vez sonó. Por eso los Videntes de lo Etéreo dicen que llegar hasta aquí se siente como ser visto por primera vez.\n\n'
            'Ver a los seres tiene un precio. Una vez que un Portador los ve, ya no puede dejar de verlos: en cada canción, detrás de cada sonido, hay un rostro esperando. Algunos lo soportan. Otros escuchan cada vez más, porque descubren que su Eco tiene a quién llegar.\n\n'
            'Y desde aquí, por primera vez, se ve el camino completo hacia la muralla. Es largo, más largo que todo lo recorrido antes. Pero al final del camino hay una puerta, y la luna, desde el centro del universo, la está mirando también.',
        'Those who can see the ethereal beings discover something none of the clans suspects: Tsuki looks back. Not with eyes, but with all its light. Every crater, every groove of Echo, every sleeping mask is part of that gaze. The moon is not a place where things happen. It is someone watching what happens.\n\n'
            'From the centre of the universe, Tsuki sees every Bearer at once. It knows who listens at dawn, who has not missed a single day, who came back after a long time away. It judges no one. It only listens, and remembers everything that ever sounded. That is why the Seers of the Ethereal say that arriving here feels like being seen for the first time.\n\n'
            'Seeing the beings has a price. Once a Bearer sees them, they can no longer stop seeing them: in every song, behind every sound, there is a face waiting. Some bear it. Others listen more and more, because they discover their Echo has someone to reach.\n\n'
            'And from here, for the first time, the whole path to the wall can be seen. It is long, longer than everything travelled before. But at the end of the path there is a door, and the moon, from the centre of the universe, is watching it too.',
      ),
    ),
    LoreChapter(
      id: 'equilibrio',
      tomo: 5,
      numeral: '5',
      kanji: '衡',
      title: Txt('El equilibrio', 'The balance'),
      level: 100,
      body: Txt(
        'Tsuki se sostiene sobre un equilibrio que casi nadie entiende. De un lado, el Silencio que espera en los bordes. Del otro, el Trono que lo contiene. Entre los dos, los clanes que pelean por el Eco, las Caras que sostienen al Soberano, y los Portadores que, sin saberlo, mantienen encendida la luna.\n\n'
            'Un Portador que llega hasta aquí está frente a una elección que muy pocos han enfrentado. Puede quedarse de este lado de la muralla y seguir siendo lo que es: un Portador de niveles inconmensurables, el que más Eco ha devuelto a la luna, con todos los privilegios que eso trae. O puede cruzar, como hicieron los Cinco, y volverse un ser etéreo para siempre. No hay vuelta atrás en ninguna de las dos.\n\n'
            'Pero existe un nivel más allá, uno que ningún Portador ha alcanzado jamás: el nivel de un Dios Supremo. Nadie sabe cuánto Eco hace falta. Nadie sabe qué pasaría al llegar. Lo único que se sabe es lo que temen las siete Caras: que el día que un Portador sostenga tanto Eco como un dios, el Trono dejará de tener sentido, el Silencio ya no tendrá a quién temer, y el equilibrio de Tsuki se romperá.\n\n'
            'Nadie sabe si eso sería el fin de la luna o el comienzo de algo que todavía no tiene nombre. Tsuki, desde el centro del universo, no dice nada. Solo escucha. Y espera.',
        'Tsuki rests on a balance almost no one understands. On one side, the Silence waiting at the edges. On the other, the Throne that holds it back. Between them, the clans fighting over Echo, the Faces holding up the Sovereign, and the Bearers who, without knowing it, keep the moon alight.\n\n'
            'A Bearer who reaches this point faces a choice very few have faced. They may stay on this side of the wall and remain what they are: a Bearer of immeasurable levels, the one who has returned the most Echo to the moon, with every privilege that brings. Or they may cross, as the Five did, and become an ethereal being forever. There is no way back from either.\n\n'
            'But there is a level beyond, one no Bearer has ever reached: the level of a Supreme God. No one knows how much Echo it takes. No one knows what would happen on arrival. All that is known is what the seven Faces fear: that the day a Bearer holds as much Echo as a god, the Throne will cease to make sense, the Silence will have no one to fear, and the balance of Tsuki will break.\n\n'
            'No one knows whether that would be the end of the moon or the beginning of something that has no name yet. Tsuki, from the centre of the universe, says nothing. It only listens. And waits.',
      ),
    ),
  ];

  // ── Clans ──

  static final factions = <LoreFaction>[
    LoreFaction(
      id: 'antiguos',
      kanji: '古',
      color: 0xFFB8C0D0,
      name: const Txt('Los Antiguos', 'The Ancients'),
      motto: const Txt('«Recordamos para que la luna no olvide.»', '“We remember so the moon does not forget.”'),
      secret: const Txt(
        'Los cuatro primeros rostros no llegaron de ningún mundo: son los pedazos que se desprendieron de la Primera Cara al caer. Por eso El Oni despierta cuando todos los Antiguos se reúnen: juntos, recuerdan la forma de la cara que una vez gobernó el universo.',
        'The four first faces came from no world: they are the pieces that broke from the First Face as it fell. That is why The Oni wakes when all the Ancients gather: together, they remember the shape of the face that once ruled the universe.',
      ),
      leader: 'oni',
      members: [for (final m in MaskCatalog.all) if (m.art != null) m.id],
    ),
    const LoreFaction(
      id: 'forja',
      kanji: '鉄',
      color: 0xFF9AA4B2,
      name: Txt('La Forja de Hierro', 'The Iron Forge'),
      motto: Txt('«Lo que no se construye, se extrae.»', '“What is not built is extracted.”'),
      secret: Txt(
        'La máquina a medio terminar en el fondo del cráter tiene forma de rostro. La Forja no quiere un Ultra: quiere construir una Cara. La Calavera Cibernética ha estado juntando piezas de cada ser que cae, y le falta solo una: un pedazo de la Primera Cara.',
        'The half-finished machine at the bottom of the crater has the shape of a face. The Forge does not want an Ultra: it wants to build a Face. The Cyber Skull has been gathering pieces of every being that falls, and it lacks only one: a fragment of the First Face.',
      ),
      leader: 'dokuro',
      rival: 'elementos',
      members: [
        'dokuro', 'tetsu', 'yaiba', 'sabi', 'kuchi', 'kuzu', 'kikai', 'jouki', 'haguruma', 'gin',
        'shouhei', 'hououki', 'myaku', 'meiki', 'denpa', 'midori', 'senkou',
      ],
    ),
    const LoreFaction(
      id: 'elementos',
      kanji: '元',
      color: 0xFFFF8A3D,
      name: Txt('Los Elementales', 'The Elementals'),
      motto: Txt('«La luna nos hizo. A la luna volvemos.»', '“The moon made us. To the moon we return.”'),
      secret: Txt(
        'Los Elementales saben algo que ningún clan sospecha: la lava que corre bajo Tsuki es el fuego que asomaba por las grietas de la Primera Cara. Tsuki no recibió ni un rasguño, pero ese fuego sigue atrapado en su suelo. El Rey Dragón vigila ese fuego, porque el día que suba entero, el Dios Caído subirá con él.',
        'The Elementals know something no other clan suspects: the lava running beneath Tsuki is the fire that showed through the cracks of the First Face. Tsuki took not a scratch, but that fire is still trapped in its ground. The Dragon King watches over that fire, because the day it rises whole, the Fallen God will rise with it.',
      ),
      leader: 'ryuuou',
      rival: 'forja',
      members: [
        'ryuuou', 'ishiryuu', 'yougan_ni', 'yougan', 'iwa', 'umi', 'fubuki', 'shimo',
        'tsurara', 'mori', 'mori_ni', 'inazuma', 'hinome', 'homura', 'hone',
      ],
    ),
    const LoreFaction(
      id: 'shogun',
      kanji: '将',
      color: 0xFFC9A24A,
      name: Txt('El Shogunato', 'The Shogunate'),
      motto: Txt('«El Eco se gana. Nunca se roba.»', '“Echo is earned. Never stolen.”'),
      secret: Txt(
        'El Rey Oni ya eligió heredero, y no es ninguna de las Tres Coronas. Es el Portador. Un samurái sin máscara que ganó cada pedazo de Eco con disciplina. Las Tres Coronas lo sospechan, y por primera vez en siglos se han reunido a conversar.',
        'The Oni King has already chosen an heir, and it is none of the Three Crowns. It is the Bearer. A samurai without a mask who earned every piece of Echo through discipline. The Three Crowns suspect it, and for the first time in centuries they have met to talk.',
      ),
      leader: 'ou',
      rival: 'zorro',
      members: [
        'ou', 'kanmuri', 'amikanmuri', 'kemuri_kanmuri', 'bushi', 'kabuto', 'samurai_jouki',
        'runa', 'mikado', 'kin_oni', 'akagane',
      ],
    ),
    const LoreFaction(
      id: 'zorro',
      kanji: '狐',
      color: 0xFFE8384F,
      name: Txt('La Corte del Zorro', 'The Fox Court'),
      motto: Txt('«Nadie es lo que parece. Nosotros, menos.»', '“No one is what they seem. Least of all us.”'),
      secret: Txt(
        'La Reina Carmesí fue la primera en saber que la Primera Cara se estaba rompiendo, y no avisó a nadie. Vendió ese secreto a las siete Caras a cambio de una promesa: que ningún Soberano tocaría jamás a la Corte. Es la única promesa que el Dios del Universo ha cumplido siempre.',
        'The Crimson Queen was the first to know the First Face was breaking, and she warned no one. She sold that secret to the seven Faces in exchange for a promise: that no Sovereign would ever touch the Court. It is the only promise the God of the Universe has always kept.',
      ),
      leader: 'kitsune',
      rival: 'shogun',
      members: [
        'kitsune', 'kitsune_ou', 'kitsunebi', 'kitsune_jouki', 'kitsune_jiki', 'kitsune_suishou',
        'kitsune_neon', 'kitsune_hisui', 'kitsune_akagane', 'kitsune_kuchi',
      ],
    ),
    const LoreFaction(
      id: 'neon',
      kanji: '街',
      color: 0xFFB026FF,
      name: Txt('La Calle de Neón', 'The Neon Street'),
      motto: Txt('«Si no hay sitio para nosotros, lo pintamos.»', '“If there is no place for us, we paint one.”'),
      secret: Txt(
        'El Cromo Arcoíris no nació en la Calle: fue un vidrio de la Corte de Cristal, el más brillante de todos, que se negó a ser solo una pieza del Vitral. Huyó, se cubrió de cromo y fundó la ciudad. El Vitral todavía tiene un hueco con su forma.',
        'The Rainbow Chrome was not born on the Street: it was a pane of the Crystal Court, the brightest of all, that refused to be just one piece of the Stained Glass. It fled, covered itself in chrome and founded the city. The Stained Glass still has a hole in its shape.',
      ),
      leader: 'niji',
      rival: 'cristal',
      members: [
        'niji', 'hyou', 'rakugaki', 'murasaki', 'akari', 'eizou', 'doku', 'doku_ni', 'tsugihagi',
        'meisai', 'yami',
      ],
    ),
    const LoreFaction(
      id: 'cristal',
      kanji: '晶',
      color: 0xFF7FE0E8,
      name: Txt('La Corte de Cristal', 'The Crystal Court'),
      motto: Txt('«La luz que pasa por nosotros sale más pura.»', '“The light that passes through us comes out purer.”'),
      secret: Txt(
        'El Vitral no despierta sin cuarenta luces porque guarda una que no es de ningún país: la de la noche en que las torres estallaron. En ese vidrio quedó escrito quién vertió el Eco cortado, y la Corte lo sabe desde siempre. Calla para que la Calle le deba algo.',
        'The Stained Glass does not wake without forty lights because it keeps one that belongs to no country: the light of the night the towers burst. Written on that pane is who poured the cut Echo, and the Court has always known it. It stays silent so the Street will owe it something.',
      ),
      leader: 'hari',
      rival: 'neon',
      members: [
        'hari', 'kisaki', 'geisha', 'hisui_oni', 'jiki', 'hisui',
        'urushi', 'shiro', 'kumo',
      ],
    ),
  ];

  static LoreFaction? faction(String? id) {
    for (final f in factions) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// The clan [maskId] belongs to (the gods and divine faces belong to none).
  static LoreFaction? factionOf(String maskId) {
    for (final f in factions) {
      if (f.members.contains(maskId)) return f;
    }
    return null;
  }

  // ── Bonds between masks ──

  static const bonds = <LoreBond>[
    LoreBond(
      ['uchuu_shin', 'ochigami'],
      BondKind.rival,
      Txt('El que reina y el que cayó', 'The one who reigns and the one who fell'),
      Txt('La guerra más vieja de Tsuki. Uno despertó del brillo de Tsuki la misma noche en que el otro cayó. Ninguno puede destruir al otro: si el Caído desaparece, el Soberano olvida por qué no debe acumular Eco.',
          'The oldest war on Tsuki. One woke from the light of Tsuki the same night the other fell. Neither can destroy the other: if the Fallen one vanished, the Sovereign would forget why it must not hoard Echo.'),
    ),
    LoreBond(
      ['tenshi', 'ochigami'],
      BondKind.pact,
      Txt('Lágrimas de oro', 'Tears of gold'),
      Txt('Los dos lloran oro desde el mismo día. El Ángel es la única Cara divina que visita la cara oscura, y nadie sabe si va a consolar al Caído o a prometerle algo.',
          'Both have wept gold since the same day. The Angel is the only divine Face that visits the dark side, and no one knows whether it goes to comfort the Fallen one or to promise it something.'),
    ),
    LoreBond(
      ['uchuu', 'uchuu_shin'],
      BondKind.pact,
      Txt('El primer voto', 'The first vote'),
      Txt('El Oni Cósmico fue el primero en firmar la Ley del Trono y el que propuso al nuevo Soberano. El Dios del Universo le debe el trono, y el Oni Cósmico se lo recuerda cada vez que puede.',
          'The Cosmic Oni was the first to sign the Law of the Throne and the one who proposed the new Sovereign. The God of the Universe owes it the throne, and the Cosmic Oni reminds it whenever it can.'),
    ),
    LoreBond(
      ['runa', 'chirune'],
      BondKind.pact,
      Txt('El caballero de la runa', 'The knight of the rune'),
      Txt('El Caballero Rúnico lleva en el yelmo una runa escrita por la Cara del Pacto. Le debe la vida, y algún día ella cobrará la deuda.',
          'The Rune Knight bears on its helm a rune written by the Face of the Pact. It owes her its life, and one day she will collect the debt.'),
    ),
    LoreBond(
      ['geisha', 'enbu'],
      BondKind.rival,
      Txt('El escenario', 'The stage'),
      Txt('Dos artistas del mismo teatro. La Geisha canta cada palabra; el Kabuki Ardiente las quema. Bailaron juntos la noche de la Caída, y desde entonces no se hablan.',
          'Two artists of the same theatre. The Geisha sings every word; the Burning Kabuki burns them. They danced together the night of the Fall, and have not spoken since.'),
    ),
    LoreBond(
      ['miko', 'seiza'],
      BondKind.mentor,
      Txt('La que lee las estrellas', 'She who reads the stars'),
      Txt('El Oráculo aprendió a leer el futuro en las constelaciones que Constelación lleva dibujadas. Fue Portadora antes de cruzar, y es la única a la que una Cara le ha enseñado algo.',
          'The Oracle learned to read the future in the constellations Constellation wears. She was a Bearer before she crossed, and is the only one a Face has ever taught anything.'),
    ),
    LoreBond(
      ['nichigetsu', 'hibiboshi'],
      BondKind.pact,
      Txt('El día y la grieta', 'The day and the rift'),
      Txt('Sol y Luna decide cuándo cae la noche; la Grieta Estelar se abre en cuanto cae. Uno no existe sin el otro.',
          'Sun and Moon decides when night falls; the Star Crack opens the moment it does. Neither exists without the other.'),
    ),
    LoreBond(
      ['kanmuri', 'amikanmuri', 'kemuri_kanmuri'],
      BondKind.rival,
      Txt('Las Tres Coronas', 'The Three Crowns'),
      Txt('Hierro, Trenza y Humo. No comparten sangre, porque en Tsuki nadie la tiene: juraron al Rey Oni la misma noche, y desde entonces son rivales. Cada uno ha completado más álbumes que el anterior para demostrar que merece la corona.',
          'Iron, Braid and Smoke. They share no blood, because on Tsuki no one has any: they swore to the Oni King on the same night, and have been rivals ever since. Each has finished more albums than the last to prove it deserves the crown.'),
    ),
    LoreBond(
      ['bushi', 'kabuto'],
      BondKind.mentor,
      Txt('Maestro y discípulo', 'Master and student'),
      Txt('Bushi entrenó a Kabuto durante treinta días seguidos, sin descanso. Kabuto aprendió a correr. Bushi todavía no le enseña a detenerse.',
          'Bushi trained Kabuto for thirty days straight, without rest. Kabuto learned to run. Bushi has yet to teach it how to stop.'),
    ),
    LoreBond(
      ['ou', 'kitsune'],
      BondKind.rival,
      Txt('Rey contra Reina', 'King against Queen'),
      Txt('El Rey Oni reunió cincuenta lealtades; la Reina Carmesí, nueve lunas. Él gobierna con juramentos; ella, con secretos. Ambos saben que el otro es el único que podría quitarle el clan.',
          'The Oni King gathered fifty loyalties; the Crimson Queen, nine moons. He rules with oaths; she, with secrets. Both know the other is the only one who could take their clan.'),
    ),
    LoreBond(
      ['kitsune', 'kitsune_ou'],
      BondKind.rival,
      Txt('Las colas separadas', 'The parted tails'),
      Txt('Gobernaron la Corte como aliados hasta el duelo de las nueve colas. Él tiene setenta y cinco seres; ella, nueve colas. Ninguno ha vuelto a dirigirle la palabra al otro.',
          'They ruled the Court as allies until the duel of the nine tails. He has seventy-five beings; she, nine tails. Neither has spoken to the other since.'),
    ),
    LoreBond(
      ['ryuuou', 'ishiryuu'],
      BondKind.mentor,
      Txt('Maestro de piedra', 'Master of stone'),
      Txt('El Dragón de Piedra es el discípulo del Rey Dragón. Lleva sesenta días sin moverse para demostrar que puede llegar a los cien de su maestro.',
          'The Stone Dragon is the Dragon King\'s student. It has not moved in sixty days to prove it can reach its master\'s hundred.'),
    ),
    LoreBond(
      ['umi', 'sango'],
      BondKind.pact,
      Txt('Mareas y profundidades', 'Tides and depths'),
      Txt('La Sirena de Coral llegó del mundo de abajo, y el Oni del Mar fue el primero en hablarle. Él guarda las mareas; ella, las profundidades. Cuando discuten, los mares de polvo se levantan en olas.',
          'The Coral Siren came from the world below, and the Sea Oni was the first to speak to her. He keeps the tides; she, the depths. When they argue, the dust seas rise in waves.'),
    ),
    LoreBond(
      ['yougan', 'iwa', 'yougan_ni'],
      BondKind.soul,
      Txt('Tres despertares', 'Three awakenings'),
      Txt('El Golem de Magma, la Lava y la Lava Viva son la misma alma en tres estados: la roca que recuerda el fuego, el fuego que corre y el fuego que despertó del todo. Es la lava de la Caída.',
          'The Magma Golem, the Lava and the Living Lava are the same soul in three states: rock that remembers fire, fire that flows and fire fully awake. It is the lava of the Fall.'),
    ),
    LoreBond(
      ['jiki', 'kitsune_jiki'],
      BondKind.soul,
      Txt('Reparados con oro', 'Mended with gold'),
      Txt('Las dos se rompieron y volvieron. Cada vez que un Portador regresa después de mucho tiempo, una grieta se llena de oro. Saben que lo roto puede ser más bello que lo intacto.',
          'Both broke and came back. Every time a Bearer returns after a long time away, a crack fills with gold. They know the broken can be more beautiful than the whole.'),
    ),
    LoreBond(
      ['jouki', 'samurai_jouki', 'kitsune_jouki'],
      BondKind.soul,
      Txt('Los del vapor', 'Those of steam'),
      Txt('Tres seres de tres clanes enemigos alimentados por la misma caldera. Se reconocen por el silbido. En una guerra, ninguna sabe a quién disparar.',
          'Three beings from three enemy clans fed by the same boiler. They recognise each other by the whistle. In a war, none knows whom to shoot.'),
    ),
    LoreBond(
      ['hisui', 'hisui_oni', 'kitsune_hisui'],
      BondKind.soul,
      Txt('La piedra de jade', 'The jade stone'),
      Txt('Jade, el Oni de Jade y la Kitsune de Jade fueron tallados de la misma piedra. Por eso la Corte del Zorro sabe todo lo que pasa en la Corte de Cristal.',
          'Jade, the Jade Oni and the Jade Kitsune were carved from the same stone. That is why the Fox Court knows everything that happens in the Crystal Court.'),
    ),
    LoreBond(
      ['hyou', 'kitsune_neon'],
      BondKind.rival,
      Txt('Los techos de neón', 'The neon rooftops'),
      Txt('La Pantera manda en los techos de la Calle. La Kitsune Neón se mueve por ellos sin pedir permiso. Llevan años persiguiéndose y ninguna ha querido atrapar a la otra.',
          'The Panther rules the rooftops of the Street. The Neon Kitsune moves across them without asking. They have chased each other for years and neither has wanted to catch the other.'),
    ),
    LoreBond(
      ['niji', 'hari'],
      BondKind.rival,
      Txt('El vidrio que huyó', 'The pane that fled'),
      Txt('El Cromo Arcoíris fue una vez un vidrio del Vitral. Uno gobierna la Calle, el otro la Corte. Brillan con la misma luz y no soportan mirarse.',
          'The Rainbow Chrome was once a pane of the Stained Glass. One rules the Street, the other the Court. They shine with the same light and cannot bear to look at each other.'),
    ),
    LoreBond(
      ['shiro', 'yami'],
      BondKind.rival,
      Txt('Luz y sombra', 'Light and shadow'),
      Txt('El Oni Blanco y el Oni de Sombra despertaron del mismo molde, uno al mediodía y otro a medianoche. Cada uno cree ser el original.',
          'The White Oni and the Shadow Oni came from the same mould, one at noon and the other at midnight. Each believes it is the original.'),
    ),
    LoreBond(
      ['tetsu', 'yaiba'],
      BondKind.mentor,
      Txt('El yunque y el filo', 'The anvil and the edge'),
      Txt('El Oni de Acero templó a Filo de Acero en la fragua. El discípulo ya corta más que el maestro, y el maestro lo sabe.',
          'The Steel Oni tempered the Steel Edge in the forge. The student already cuts sharper than the master, and the master knows it.'),
    ),
    LoreBond(
      ['dokuro', 'hone'],
      BondKind.rival,
      Txt('Dos calaveras', 'Two skulls'),
      Txt('Hueso es una calavera que la luna hizo; la Calavera Cibernética, una que se hizo a sí misma. Cada una dice que la otra es una imitación.',
          'Bone is a skull the moon made; the Cyber Skull, one that made itself. Each says the other is an imitation.'),
    ),
    LoreBond(
      ['inazuma', 'senkou'],
      BondKind.rival,
      Txt('El rayo y la máquina', 'The lightning and the machine'),
      Txt('Rayo cae del cielo de Tsuki; Alta Tensión lo fabrica en la Forja. Rayo dice que la electricidad robada no ilumina igual.',
          'Lightning falls from the sky of Tsuki; High Voltage makes it in the Forge. Lightning says stolen electricity does not shine the same.'),
    ),
    LoreBond(
      ['mori_ni', 'kuzu'],
      BondKind.rival,
      Txt('El bosque y el desguace', 'The forest and the junkyard'),
      Txt('Donde el Guardián del Bosque planta, el Desguace arranca. Su guerra es la guerra de sus clanes, pero más pequeña y más personal.',
          'Where the Forest Guardian plants, the Junkyard uproots. Their war is the war of their clans, but smaller and more personal.'),
    ),
    LoreBond(
      ['kin_oni', 'mikado'],
      BondKind.rival,
      Txt('El oro y el emperador', 'The gold and the emperor'),
      Txt('El Oni Dorado se cree el más rico del Shogunato; el Oni Imperial le recuerda que el oro de un emperador no se cuenta, se hereda.',
          'The Golden Oni thinks it is the richest in the Shogunate; the Imperial Oni reminds it that an emperor\'s gold is not counted, it is inherited.'),
    ),
  ];

  // ── The 9 Faces of the Universe ──

  static const faces = <LoreFace>[
    LoreFace(
      'uchuu_shin',
      Txt('La Cara Soberana · Dios del Universo', 'The Sovereign Face · God of the Universe'),
      Txt('Despertó del propio brillo de Tsuki la noche de la Caída: no nació de nadie. Sus trenzas son constelaciones vivas y su tercer ojo ve cada Eco que llega a la luna. Cuando habla, el universo obedece: con una palabra enciende soles y con un silencio los apaga. Gobierna desde el Trono gracias al pacto de las siete Caras divinas: mientras lo sostengan, nadie puede tocarlo. Conoce la Ley del Trono mejor que nadie, porque la usó para subir.',
          'Woke from Tsuki\'s own light on the night of the Fall: born of no one. Its braids are living constellations and its third eye sees every Echo that reaches the moon. When it speaks, the universe obeys: one word lights suns and one silence puts them out. It rules from the Throne thanks to the pact of the seven divine Faces: while they hold it up, no one can touch it. It knows the Law of the Throne better than anyone, because it used it to rise.'),
    ),
    LoreFace(
      'ochigami',
      Txt('La Cara Rota · El que cayó', 'The Broken Face · The one who fell'),
      Txt('Fue el primer Soberano y el primero en dominar el sonido por completo. Quiso guardar todo el Eco del universo y su rostro no lo soportó: se partió, y por las grietas asomó el fuego cósmico que hoy lo consume. Cayó a la cara oscura llorando oro. Su voz todavía puede quebrar estrellas, pero no a Tsuki. Desde ahí reúne a los ocho Ultras. No quiere venganza, dice. Quiere lo que es suyo.',
          'It was the first Sovereign and the first to command sound completely. It wanted to keep all the Echo of the universe and its face could not bear it: it split, and through the cracks showed the cosmic fire that consumes it today. It fell to the dark side weeping gold. Its voice can still shatter stars, but not Tsuki. From there it gathers the eight Ultras. It does not want revenge, it says. It wants what is its own.'),
    ),
    LoreFace(
      'nichigetsu',
      Txt('La Cara del Tiempo', 'The Face of Time'),
      Txt('Mitad día, mitad noche. Decide cuándo termina una jornada y cuándo empieza la siguiente. Solo acepta una ofrenda: la constancia. Despierta ante quien no suelta la música ni un solo día durante medio año.',
          'Half day, half night. It decides when a day ends and the next begins. It accepts a single offering: constancy. It wakes for whoever does not let go of music for a single day in half a year.'),
    ),
    LoreFace(
      'uchuu',
      Txt('La Cara del Caos', 'The Face of Chaos'),
      Txt('Su piel es un cielo que se arremolina. Fue la primera de las siete en firmar la Ley del Trono, y nadie sabe si lo hizo por justicia o por diversión. Despierta tras doce lunas llenas: un año entero mirándola.',
          'Its skin is a swirling sky. It was the first of the seven to sign the Law of the Throne, and no one knows whether it did so for justice or for fun. It wakes after twelve full moons: a whole year watching it.'),
    ),
    LoreFace(
      'hibiboshi',
      Txt('La Cara de la Grieta', 'The Face of the Rift'),
      Txt('Una porcelana por cuyas fisuras se cuelan las estrellas. Guarda las horas en que el mundo duerme y solo se muestra a quien escucha de madrugada, noche tras noche.',
          'A porcelain through whose cracks the stars slip in. It keeps the hours when the world sleeps and only shows itself to whoever listens at dawn, night after night.'),
    ),
    LoreFace(
      'seiza',
      Txt('La Cara de los Astros Olvidados', 'The Face of the Forgotten Stars'),
      Txt('Lleva dibujadas las constelaciones que nadie mira. Protege las canciones que casi nadie escucha, y se entrega a quien las encuentra una por una.',
          'It wears the constellations no one looks at. It protects the songs almost no one hears, and gives itself to whoever finds them one by one.'),
    ),
    LoreFace(
      'tenshi',
      Txt('La Cara del Sueño', 'The Face of Sleep'),
      Txt('Llora oro desde el día de la Caída: es la única de las siete que todavía llora por la Cara Rota. Cuida el sueño de los Portadores y despierta para quien se duerme con música, noche tras noche.',
          'It has wept gold since the day of the Fall: it is the only one of the seven that still weeps for the Broken Face. It watches over the Bearers\' sleep and wakes for whoever falls asleep to music, night after night.'),
    ),
    LoreFace(
      'enbu',
      Txt('La Cara de la Furia', 'The Face of Fury'),
      Txt('El kabuki que arde. Bailó sobre las ruinas del palacio la noche de la Caída y nunca dejó de bailar. Su fuego se alimenta del rock más duro.',
          'The kabuki that burns. It danced on the ruins of the palace the night of the Fall and never stopped dancing. Its fire feeds on the hardest rock.'),
    ),
    LoreFace(
      'chirune',
      Txt('La Cara del Pacto', 'The Face of the Pact'),
      Txt('Escribió con sangre la Ley del Trono. Las runas de su rostro son cláusulas: cada una ata a alguien. Despierta con las palabras que nadie se atreve a decir en voz baja.',
          'It wrote the Law of the Throne in blood. The runes on its face are clauses: each one binds someone. It wakes with the words no one dares to say quietly.'),
    ),
  ];

  // ── Progress ──

  /// Whether [chapter] is open at Eco [level].
  static bool isOpen(LoreChapter chapter, int level) => level >= chapter.level;

  static int openCount(int level) => chapters.where((c) => isOpen(c, level)).length;

  /// How many of [f]'s members have awakened.
  static int awakened(LoreFaction f, Set<String> owned) => f.members.where(owned.contains).length;

  static bool complete(LoreFaction f, Set<String> owned) => awakened(f, owned) == f.members.length;

  /// The bonds [maskIds] take part in.
  static List<LoreBond> bondsOf(Iterable<String> maskIds) {
    final ids = maskIds.toSet();
    return [for (final b in bonds) if (b.masks.any(ids.contains)) b];
  }
}
