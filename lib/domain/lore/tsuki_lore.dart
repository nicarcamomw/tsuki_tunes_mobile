import '../../core/localization/app_language.dart';
import '../entities/oni_mask.dart';
import '../logic/eco_levels.dart';

/// A text in Spanish and English (Japanese reads the English for now).
class Txt {
  final String es;
  final String en;
  const Txt(this.es, this.en);

  String of(AppLanguage l) => l == AppLanguage.es ? es : en;
}

/// What opens a chapter of the lore.
enum LoreLock {
  /// Open from the start.
  free,

  /// [LoreChapter.need] masks awakened, any of them.
  masks,

  /// One mask of the chapter's clan.
  faction,

  /// One of the eight Ultras (UL, not divine).
  ultra,

  /// [LoreChapter.need] of the seven divine faces.
  divine,

  /// Eco level [LoreChapter.need].
  level,

  /// One of the two supreme gods.
  god,
}

/// A volume of the story. Only [TsukiLore.releasedTomos] are readable;
/// the rest show as coming soon and are released as updates.
class LoreTomo {
  final int number;
  final String numeral;
  final String kanji;
  final Txt title;
  const LoreTomo(this.number, this.numeral, this.kanji, this.title);
}

class LoreChapter {
  final String id;
  final int tomo;
  final String numeral;
  final String kanji;
  final Txt title;

  /// Paragraphs, separated by blank lines.
  final Txt body;
  final LoreLock lock;
  final int need;
  final String? factionId;

  const LoreChapter({
    required this.id,
    required this.tomo,
    required this.numeral,
    required this.kanji,
    required this.title,
    required this.body,
    this.lock = LoreLock.free,
    this.need = 1,
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

enum BondKind { rival, family, mentor, soul, pact }

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
  ];

  /// Whether [c]'s volume is open at Eco [level] (volume I always is).
  static bool released(LoreChapter c, int level) => EcoLevels.tomoOpen(c.tomo, level);

  static List<LoreChapter> chaptersOf(int tomo) => [for (final c in chapters) if (c.tomo == tomo) c];

  // ── Chapters ──

  static const chapters = <LoreChapter>[
    LoreChapter(
      id: 'prologo',
      tomo: 1,
      numeral: '0',
      kanji: '月',
      title: Txt('Tsuki, el centro del universo', 'Tsuki, the centre of the universe'),
      body: Txt(
        'Esta es la historia que cuentan los seres etéreos más viejos, la que se susurra en los cráteres cuando la luna está llena.\n\n'
            'Antes de las estrellas, antes del tiempo, ya estaba Tsuki. No nació de nada: todo nació de ella. Es la Luna Madre, el centro exacto del universo y su comienzo. Las demás lunas son reflejos suyos, espejos colgados sobre mil mundos para recordarles hacia dónde mirar.\n\n'
            'Tsuki brilla, pero no refleja ningún sol ni se alimenta de nada. Brilla porque es el centro. La primera luz del universo salió de ella, y nunca se ha apagado.\n\n'
            'Cuando Tsuki despertó, su primer latido fue un sonido. Ese sonido se extendió por el vacío, y de su vibración se formaron las estrellas, los mundos y todo lo que vive. Desde entonces todo lo que existe vibra, y todo lo que vibra puede ser movido por el sonido.\n\n'
            'En Tsuki existen muchos poderes: el fuego, el acero, el tiempo, los astros, la astucia. Pero pocos se comparan con el control mediante el sonido, y por eso es el que todos buscan. Los seres que apenas lo rozan hacen temblar una piedra con su voz. Los que lo dominan doblan el acero con un grito o calman una tormenta con una sola nota. Y solo dos seres han alcanzado el control total: los Dioses Supremos. Cuando ellos hablan, el universo obedece.\n\n'
            'Muchos han intentado destruir Tsuki. Ejércitos, máquinas y hasta dioses la han golpeado con toda su furia, y ninguno le ha hecho una sola grieta. Tsuki no es indestructible porque nadie lo haya intentado: lo es porque es un lugar sagrado, el corazón de todo el poder. Romperla sería romper el comienzo del universo.\n\n'
            'Por eso nadie pelea contra Tsuki. Pelean por ella. En su cara oculta se alza el Trono del Eco, tallado en luna pura. Quien se sienta en él controla el sonido del universo entero: decide qué suena, qué calla y quién obedece.\n\n'
            'Y como todo poder que existe, alguien lo quiere.',
        'This is the story the oldest ethereal beings tell, the one whispered in the craters when the moon is full.\n\n'
            'Before the stars, before time, there was Tsuki. It was not born from anything: everything was born from it. It is the Mother Moon, the exact centre of the universe and its beginning. Every other moon is a reflection of it, a mirror hung above a thousand worlds to remind them where to look.\n\n'
            'Tsuki shines, but it reflects no sun and feeds on nothing. It shines because it is the centre. The first light of the universe came from it, and it has never gone out.\n\n'
            'When Tsuki woke, its first heartbeat was a sound. That sound spread through the void, and from its vibration came the stars, the worlds and everything that lives. Since then everything that exists vibrates, and everything that vibrates can be moved by sound.\n\n'
            'On Tsuki there are many powers: fire, steel, time, the stars, cunning. But few compare to control through sound, and that is why everyone seeks it. Beings that barely touch it can make a stone tremble with their voice. Those that master it bend steel with a shout or calm a storm with a single note. And only two beings have reached total control: the Supreme Gods. When they speak, the universe obeys.\n\n'
            'Many have tried to destroy Tsuki. Armies, machines and even gods have struck it with all their fury, and none has left a single crack. Tsuki is not indestructible because no one has tried: it is because it is a sacred place, the heart of all power. Breaking it would mean breaking the beginning of the universe.\n\n'
            'That is why no one fights against Tsuki. They fight for it. On its hidden face stands the Throne of the Echo, carved from pure moon. Whoever sits on it controls the sound of the whole universe: what sounds, what falls silent and who obeys.\n\n'
            'And like every power that exists, someone wants it.',
      ),
    ),
    LoreChapter(
      id: 'eco',
      tomo: 1,
      numeral: '1',
      kanji: '響',
      title: Txt('El Eco', 'The Echo'),
      body: Txt(
        'Cuentan que el sonido no muere. Viaja. Todo lo que suena en el universo, por lejos que esté, termina llegando a la Luna Madre: el canto de un pueblo en la orilla de un río, el rugido de un estadio, un disco girando en una pieza a oscuras a las tres de la mañana.\n\n'
            'Al tocar el suelo sagrado de Tsuki, ese sonido cambia. Se vuelve Eco: sonido vivo, que se puede guardar, afilar y usar. Con Eco un ser etéreo habla y es obedecido. Levanta muros con un tambor, parte rocas con un grito, duerme a un ejército con una canción de cuna. Por el Eco se han firmado pactos, se han traicionado reyes y se han perdido guerras enteras.\n\n'
            'Pero el Eco tiene una regla que ni los dioses pueden romper: solo nace cuando alguien escucha. Una canción que nadie oye se pierde en el vacío y no deja rastro. Hace falta un oído, una atención, alguien dispuesto a quedarse hasta la última nota.\n\n'
            'Los seres etéreos llaman Portadores a esos que escuchan. Viven en los mundos de abajo y casi ninguno sabe que Tsuki existe. No pelean, no viajan, no buscan el Trono. Solo escuchan, y su Eco sube intacto hasta la luna.\n\n'
            'Ningún ser etéreo ha visto nunca a un Portador. Solo sienten su Eco llegar, noche tras noche, como lluvia sobre los cráteres. Y los más viejos dicen que cuando un Portador escucha con toda el alma, en algún rincón de Tsuki un ser dormido abre los ojos.',
        'They say sound does not die. It travels. Everything that sounds in the universe, however far away, ends up reaching the Mother Moon: the song of a village on a riverbank, the roar of a stadium, a record spinning in a dark room at three in the morning.\n\n'
            'When it touches the sacred ground of Tsuki, that sound changes. It becomes Echo: living sound, that can be kept, sharpened and used. With Echo an ethereal being speaks and is obeyed. It raises walls with a drum, splits rock with a shout, puts an army to sleep with a lullaby. For Echo, pacts have been signed, kings betrayed and whole wars lost.\n\n'
            'But Echo has a rule not even the gods can break: it is only born when someone listens. A song nobody hears is lost in the void and leaves no trace. It takes an ear, attention, someone willing to stay until the last note.\n\n'
            'The ethereal beings call those who listen Bearers. They live in the worlds below and almost none of them know Tsuki exists. They do not fight, do not travel, do not seek the Throne. They just listen, and their Echo rises whole to the moon.\n\n'
            'No ethereal being has ever seen a Bearer. They only feel their Echo arrive, night after night, like rain on the craters. And the oldest say that when a Bearer listens with their whole soul, somewhere on Tsuki a sleeping being opens its eyes.',
      ),
    ),
    LoreChapter(
      id: 'mascaras',
      tomo: 1,
      numeral: '2',
      kanji: '面',
      title: Txt('Los seres etéreos y sus rangos', 'The ethereal beings and their ranks'),
      lock: LoreLock.masks,
      need: 1,
      body: Txt(
        'Los seres etéreos son los habitantes de Tsuki. Ninguno recuerda la cara que tuvo. Llegaron de mundos lejanos, atraídos por la luz de la Luna Madre como polillas por una vela, y en el viaje perdieron el cuerpo. Solo quedó su rostro, una máscara forjada en acero, coral, vidrio, hueso o fuego, y dentro de la máscara, una voluntad.\n\n'
            'Un ser recién llegado duerme. Es solo una máscara tirada en el polvo lunar, y puede pasar siglos así. Para despertar necesita Eco, y cada uno lo busca a su manera: unos se alimentan del ruido de las tormentas, otros de las canciones que suenan de madrugada, otros de la música de un país que ya no existe. Cada ser come el Eco que se le parece.\n\n'
            'Con el tiempo, Tsuki aprendió a medir a sus habitantes por cuánto Eco puede sostener un rostro, y así nacieron los rangos:\n\n'
            'R, los Errantes: seres jóvenes o sencillos cuya voz apenas mueve el polvo. Vagan por los cráteres buscando un clan que los acoja.\n\n'
            'SR, los Guerreros: su grito es un arma. Forjados para pelear y jurados a un estandarte.\n\n'
            'SSR, los Señores: herederos, generales y sacerdotisas. Con su voz mandan ejércitos, y cada uno gobierna un pedazo de luna.\n\n'
            'UL, los Ultras: leyendas vivas. Cuando hablan, los cráteres tiemblan, y hasta los Señores bajan la mirada.\n\n'
            'Y por encima de todos, las 9 Caras del Universo: siete divinas y dos Dioses Supremos, los únicos que dominan el sonido por completo. De ellas casi no se habla, y nunca en voz alta.\n\n'
            'Ningún ser está conforme con su rango. Todos, tarde o temprano, miran hacia la cara oculta de la luna.',
        'The ethereal beings are the inhabitants of Tsuki. None remembers the face it once had. They came from distant worlds, drawn by the light of the Mother Moon like moths to a candle, and on the journey they lost their bodies. Only the face remained, a mask forged in steel, coral, glass, bone or fire, and inside the mask, a will.\n\n'
            'A newly arrived being sleeps. It is just a mask lying in the moon dust, and it can stay that way for centuries. To wake it needs Echo, and each one seeks it its own way: some feed on the noise of storms, others on songs played at dawn, others on the music of a country that no longer exists. Each being eats the Echo that resembles it.\n\n'
            'In time, Tsuki learned to measure its inhabitants by how much Echo a face can hold, and so the ranks were born:\n\n'
            'R, the Wanderers: young or simple beings whose voice barely stirs the dust. They roam the craters, looking for a clan to take them in.\n\n'
            'SR, the Warriors: their shout is a weapon. Forged to fight and sworn to a banner.\n\n'
            'SSR, the Lords: heirs, generals and priestesses. Their voice commands armies, and each rules a piece of the moon.\n\n'
            'UL, the Ultras: living legends. When they speak, the craters tremble, and even the Lords lower their eyes.\n\n'
            'And above them all, the 9 Faces of the Universe: seven divine ones and two Supreme Gods, the only ones who command sound completely. They are hardly spoken of, and never aloud.\n\n'
            'No being is content with its rank. Sooner or later, all of them look toward the hidden face of the moon.',
      ),
    ),
    LoreChapter(
      id: 'antiguos',
      tomo: 1,
      numeral: '3',
      kanji: '古',
      title: Txt('Los Antiguos', 'The Ancients'),
      lock: LoreLock.faction,
      factionId: 'antiguos',
      body: Txt(
        'Antes de los clanes y de las guerras hubo cuatro rostros: el Tengu de nariz larga, el Oni del kabuki, la Hannya de los celos y una máscara de metal que nadie sabe quién forjó. Fueron los primeros en despertar en Tsuki, y nadie recuerda de dónde vinieron. De sus copias, sombras y reflejos nacieron todos los que hoy se llaman Los Antiguos.\n\n'
            'Los Antiguos no buscan el Trono. Son la memoria de la luna: cada uno guarda un momento que pasó de verdad. Primer Eco recuerda la primera canción que sonó sobre Tsuki. La Luna de Sangre vio el último eclipse. 3:33 vive atrapado en el minuto exacto en que el reloj repite su número.\n\n'
            'Con los siglos, algunos cambiaron de piel (tinta, hielo, oro, píxeles, neón) y vagan por los cráteres como reflejos de los primeros. Aparecen y desaparecen con las semanas, y nunca dos veces de la misma forma.\n\n'
            'En el centro de todos duerme El Oni, la máscara completa. Dicen que no despierta por ninguna hazaña, sino cuando sus hermanos lo llaman todos juntos. Y dicen también que los cuatro primeros rostros saben algo de su origen que han jurado no contar jamás.',
        'Before the clans and the wars there were four faces: the long-nosed Tengu, the kabuki Oni, the jealous Hannya and a metal mask no one knows who forged. They were the first to wake on Tsuki, and no one remembers where they came from. From their copies, shadows and reflections came all those now called The Ancients.\n\n'
            'The Ancients do not seek the Throne. They are the memory of the moon: each keeps a moment that truly happened. First Echo remembers the first song ever heard on Tsuki. The Blood Moon saw the last eclipse. 3:33 lives trapped in the exact minute when the clock repeats its number.\n\n'
            'Over the centuries some changed skin (ink, ice, gold, pixels, neon) and roam the craters as reflections of the first ones. They come and go with the weeks, and never twice in the same form.\n\n'
            'At the centre of them all sleeps The Oni, the complete mask. They say it does not wake for any feat, but when all its siblings call it together. And they also say the four first faces know something about their origin that they have sworn never to tell.',
      ),
    ),
    LoreChapter(
      id: 'portadores',
      tomo: 1,
      numeral: '4',
      kanji: '聴',
      title: Txt('Los que escuchan', 'Those who listen'),
      lock: LoreLock.level,
      need: 5,
      body: Txt(
        'Los seres etéreos no pueden ver a los Portadores, y los Portadores no pueden ver a los seres etéreos. Así ha sido siempre. Pero el Eco cambia a quien lo carga, y hubo Portadores que cargaron tanto que la regla empezó a doblarse.\n\n'
            'Primero llega el oído. Un Portador con suficiente Eco empieza a escuchar algo debajo de la música: un murmullo, una voz que tararea al otro lado de la canción. Son los seres etéreos hablando entre ellos. Muchos Portadores llegaron hasta ahí.\n\n'
            'Después llega la vista. Hace falta muchísimo más Eco para ver a un ser etéreo, porque la luz de Tsuki los esconde. Los pocos que lo lograron cuentan que la máscara no es lo único que tienen: detrás hay algo que se mueve, como humo que piensa.\n\n'
            'Y al final está el cruce. Un Portador que ha juntado más Eco del que un cuerpo puede sostener puede elegir dejarlo todo y volverse un ser etéreo. Recibe su propia máscara, una que no se parece a ninguna otra, porque lleva dentro todo lo que escuchó. Se cuentan con los dedos de una mano los que se atrevieron.\n\n'
            'Más allá solo hay una leyenda. Dicen que existe un Eco igual al de los Dioses Supremos, y que ningún Portador lo ha alcanzado jamás. Las siete Caras divinas lo temen más que a nada, porque el día que alguien llegue, el equilibrio de Tsuki se romperá.',
        'Ethereal beings cannot see the Bearers, and Bearers cannot see the ethereal beings. It has always been so. But Echo changes whoever carries it, and there have been Bearers who carried so much that the rule began to bend.\n\n'
            'First comes hearing. A Bearer with enough Echo starts to hear something beneath the music: a murmur, a voice humming on the other side of the song. It is the ethereal beings talking among themselves. Many Bearers have come this far.\n\n'
            'Then comes sight. It takes far more Echo to see an ethereal being, because the light of Tsuki hides them. The few who managed it say the mask is not all they have: behind it something moves, like smoke that thinks.\n\n'
            'And at the end is the crossing. A Bearer who has gathered more Echo than a body can hold may choose to leave everything behind and become an ethereal being. They receive a mask of their own, one like no other, because it carries everything they ever heard. Those who dared can be counted on one hand.\n\n'
            'Beyond that there is only a legend. They say there is an Echo equal to that of the Supreme Gods, and that no Bearer has ever reached it. The seven divine Faces fear it more than anything, because the day someone does, the balance of Tsuki will break.',
      ),
    ),
    LoreChapter(
      id: 'forja',
      tomo: 2,
      numeral: '1',
      kanji: '鉄',
      title: Txt('La Forja de Hierro', 'The Iron Forge'),
      lock: LoreLock.faction,
      factionId: 'forja',
      body: Txt(
        'En el cráter más profundo de Tsuki, donde el Eco se acumula como lluvia en un pozo, arde la Forja. Sus seres no nacieron: fueron construidos. Acero, cobre, engranajes, pantallas, cables que chispean como nervios.\n\n'
            'La Forja cree que el Eco no es un regalo sino un recurso, y que un recurso se extrae. Sus antenas escuchan cada frecuencia que llega a la luna; sus centinelas vigilan los caminos; sus mechas excavan la roca buscando Eco viejo, sepultado desde antes de la Caída.\n\n'
            'La gobierna la Calavera Cibernética, que se armó a sí misma con los restos de los seres que cayeron en batalla. Nadie sabe cuántas caras lleva puestas debajo de la que muestra.\n\n'
            'La Forja tiene una herida que no confiesa: es el único gran clan sin un Ultra. Por eso no deja de construir. Una vez intentó perforar el corazón de Tsuki para robar su poder de raíz: todas sus brocas se partieron y la luna ni lo notó. Desde entonces, en el fondo del cráter, dicen, algo enorme está a medio terminar.\n\n'
            'Su enemigo natural son los Elementales. Cada bosque que cae es combustible; cada río, refrigerante. Y cada máquina, para los Elementales, es una herida en la luna.',
        'In the deepest crater of Tsuki, where Echo gathers like rain in a well, burns the Forge. Its beings were not born: they were built. Steel, copper, gears, screens, cables sparking like nerves.\n\n'
            'The Forge believes Echo is not a gift but a resource, and a resource is extracted. Its antennas listen to every frequency that reaches the moon; its sentinels guard the roads; its mechas dig through rock looking for old Echo, buried since before the Fall.\n\n'
            'It is ruled by the Cyber Skull, which built itself from the remains of beings that fell in battle. Nobody knows how many faces it wears beneath the one it shows.\n\n'
            'The Forge has a wound it never admits: it is the only great clan without an Ultra. That is why it never stops building. Once it tried to drill into the heart of Tsuki to steal its power at the root: every drill broke and the moon did not even notice. Since then, at the bottom of the crater, they say, something enormous is half finished.\n\n'
            'Its natural enemy is the Elementals. Every fallen forest is fuel; every river, coolant. And every machine, to the Elementals, is a wound in the moon.',
      ),
    ),
    LoreChapter(
      id: 'elementos',
      tomo: 2,
      numeral: '2',
      kanji: '元',
      title: Txt('Los Elementales', 'The Elementals'),
      lock: LoreLock.faction,
      factionId: 'elementos',
      body: Txt(
        'Algunos seres no llegaron a Tsuki: brotaron de ella. Cuando el Eco toca la luna en un lugar con suficiente fuerza, la roca se vuelve rostro. Así nacieron los Elementales: de la lava, del coral, de la nieve, de la hoja seca y del rayo.\n\n'
            'Viven como vive el clima. El Oni del Mar y la Sirena de Coral cuidan las mareas de los mares de polvo; los espíritus del bosque crecen donde alguien escuchó lo-fi durante horas; la Ventisca y el Oni de las Nieves soplan sobre los cráteres helados; la lava fluye bajo todo, y a veces sube.\n\n'
            'Sobre todos reina el Rey Dragón, el ser más viejo de los que nacieron de la luna. Su piel es roca y su paciencia, también: solo despierta ante quien escucha cien días sin faltar uno.\n\n'
            'Los Elementales no quieren el Trono. Quieren que nadie lo use para secar la luna. Por eso odian a la Forja, que convierte bosques en carbón y mares en vapor.',
        'Some beings did not arrive on Tsuki: they sprouted from it. When Echo touches the moon somewhere with enough force, the rock becomes a face. That is how the Elementals were born: from lava, coral, snow, dry leaves and lightning.\n\n'
            'They live as weather lives. The Sea Oni and the Coral Siren tend the tides of the dust seas; the forest spirits grow where someone listened to lo-fi for hours; the Blizzard and the Snow Oni blow over the frozen craters; lava flows beneath everything, and sometimes rises.\n\n'
            'Above them all reigns the Dragon King, the oldest of the beings born from the moon. Its skin is rock and so is its patience: it only wakes for someone who listens a hundred days without missing one.\n\n'
            'The Elementals do not want the Throne. They want no one to use it to dry the moon. That is why they hate the Forge, which turns forests into coal and seas into steam.',
      ),
    ),
    LoreChapter(
      id: 'shogun',
      tomo: 2,
      numeral: '3',
      kanji: '将',
      title: Txt('El Shogunato', 'The Shogunate'),
      lock: LoreLock.faction,
      factionId: 'shogun',
      body: Txt(
        'En las mesetas del este de Tsuki se levantan los castillos del Shogunato: kabutos de hierro, coronas, armaduras con runas y vapor. Es el clan más ordenado de la luna, y el que más cree merecer el Trono.\n\n'
            'Su código es simple: el Eco se gana, no se roba. Un samurái de Tsuki sube de rango con disciplina —días seguidos, álbumes completos, cientos de canciones de un mismo maestro— y nunca con atajos. Bushi entrena a los jóvenes; Kabuto marcha con el ejército; el Caballero Rúnico guarda los pasos de montaña.\n\n'
            'Al frente está el Rey Oni, que no ganó su corona en combate sino reuniendo lealtades: cincuenta seres juraron por él. Pero un rey necesita heredero, y tiene tres: las Tres Coronas. Hierro, Trenza y Humo. Cada una cree ser la elegida.\n\n'
            'El Shogunato desprecia a la Corte del Zorro, que para ellos es un nido de mentirosos que gana guerras sin pelearlas. Lo peor, dicen los generales, es que casi siempre las gana.',
        'On the eastern plateaus of Tsuki stand the castles of the Shogunate: iron kabutos, crowns, armour with runes and steam. It is the most orderly clan on the moon, and the one most convinced it deserves the Throne.\n\n'
            'Its code is simple: Echo is earned, never stolen. A samurai of Tsuki rises through discipline —days in a row, whole albums, hundreds of songs by one master— and never through shortcuts. Bushi trains the young; Kabuto marches with the army; the Rune Knight guards the mountain passes.\n\n'
            'At its head stands the Oni King, who did not win his crown in battle but by gathering loyalties: fifty beings swore by him. But a king needs an heir, and he has three: the Three Crowns. Iron, Braid and Smoke. Each believes it is the chosen one.\n\n'
            'The Shogunate despises the Fox Court, which they call a nest of liars who win wars without fighting them. Worst of all, say the generals, they almost always win.',
      ),
    ),
    LoreChapter(
      id: 'zorro',
      tomo: 2,
      numeral: '4',
      kanji: '狐',
      title: Txt('La Corte del Zorro', 'The Fox Court'),
      lock: LoreLock.faction,
      factionId: 'zorro',
      body: Txt(
        'Los kitsune llegaron a Tsuki siguiendo la luna llena, como hacen los zorros en todos los mundos. Se quedaron porque descubrieron que aquí la luna llena dura para siempre en algún rincón, y que con suficientes lunas un zorro puede tener nueve colas.\n\n'
            'La Corte no tiene castillos: tiene seres en todas partes. Hay kitsune de vapor en la Forja, de porcelana en la Corte de Cristal, de neón en los callejones y de chatarra en los basurales. Ninguno es lo que parece. Todos informan a la Reina.\n\n'
            'La Reina Carmesí despierta tras nueve lunas llenas, una por cada cola. El Rey Kitsune, su antiguo consorte, juntó setenta y cinco seres para demostrarle que también sabía reinar, y ella todavía no le contesta. Entre ambos arde el Kitsunebi, el fuego del zorro, que solo se enciende de madrugada bajo la luna llena.\n\n'
            'El Shogunato los llama tramposos. La Corte responde que el honor es un lujo de quien nunca tuvo que esconderse.',
        'The kitsune came to Tsuki following the full moon, as foxes do in every world. They stayed because they discovered that here the full moon lasts forever in some corner, and that with enough moons a fox can grow nine tails.\n\n'
            'The Court has no castles: it has beings everywhere. There are steam kitsune in the Forge, porcelain ones in the Crystal Court, neon ones in the alleys and scrap ones in the junkyards. None is what it seems. All of them report to the Queen.\n\n'
            'The Crimson Queen wakes after nine full moons, one for each tail. The Kitsune King, her former consort, gathered seventy-five beings to prove he could rule too, and she still has not answered him. Between them burns the Kitsunebi, the foxfire, which only lights at dawn under a full moon.\n\n'
            'The Shogunate calls them cheats. The Court answers that honour is a luxury for those who never had to hide.',
      ),
    ),
    LoreChapter(
      id: 'neon',
      tomo: 2,
      numeral: '5',
      kanji: '街',
      title: Txt('La Calle de Neón', 'The Neon Street'),
      lock: LoreLock.faction,
      factionId: 'neon',
      body: Txt(
        'Donde los caminos de Tsuki se cruzan nació una ciudad que nadie planeó: letreros, grafitis, pantallas, bajos que hacen temblar el polvo lunar. Es la Calle de Neón, y sus seres son los que ningún clan quiso.\n\n'
            'Aquí nadie pregunta de dónde vienes. La Pantera Neón manda en los techos, los grafitis marcan territorio, el Tóxico y la Plaga venden Eco cortado en los callejones, y el Camuflaje sabe cosas que no debería saber. Su música es la de la calle: hip-hop, urbano, letras que no piden permiso.\n\n'
            'La gobierna el Cromo Arcoíris, una máscara de seis cuernos que refleja todos los colores porque se negó a tener uno solo. Para despertarlo hay que haber escuchado los doce estilos de la luna: la Calle no acepta reyes que solo conozcan un barrio.\n\n'
            'Su enemiga es la Corte de Cristal, que mira la ciudad desde sus torres y la llama ruido. La Calle responde pintando sus muros cada noche.',
        'Where the roads of Tsuki cross, a city no one planned was born: signs, graffiti, screens, basslines that shake the moon dust. It is the Neon Street, and its beings are the ones no clan wanted.\n\n'
            'Here no one asks where you come from. The Neon Panther rules the rooftops, graffiti marks territory, Toxic and Plague sell cut Echo in the alleys, and Camouflage knows things it should not. Their music is the music of the street: hip-hop, urban, lyrics that do not ask permission.\n\n'
            'It is ruled by the Rainbow Chrome, a six-horned mask that reflects every colour because it refused to have just one. It only wakes for one who has heard all twelve styles of the moon: the Street accepts no king who only knows one block.\n\n'
            'Its enemy is the Crystal Court, which looks down on the city from its towers and calls it noise. The Street answers by painting their walls every night.',
      ),
    ),
    LoreChapter(
      id: 'cristal',
      tomo: 2,
      numeral: '6',
      kanji: '晶',
      title: Txt('La Corte de Cristal', 'The Crystal Court'),
      lock: LoreLock.faction,
      factionId: 'cristal',
      body: Txt(
        'En las cumbres más altas de Tsuki, donde el Eco llega más limpio, brillan las torres de la Corte de Cristal. Sus seres llevan máscaras de jade, porcelana, laca, oro y vidrio: frágiles por fuera, eternas por dentro.\n\n'
            'Es la corte de las sacerdotisas y los artistas. El Oráculo lee el futuro en las constelaciones; la Geisha conoce cada letra de cada canción; la Emperatriz Violeta gobierna con un abanico; el Origami se dobla día tras día sin romperse. Para ellos el Eco es arte, y el arte requiere pureza.\n\n'
            'Su señor es el Vitral, una máscara hecha de cientos de vidrios de colores. Cada vidrio es la luz de un país distinto: no despierta hasta haber escuchado cuarenta. Cuando por fin abre los ojos, la luz de toda la luna pasa a través de él.\n\n'
            'La Corte desprecia el ruido de la Calle de Neón. Pero las porcelanas más viejas recuerdan algo que prefieren callar: muchas de ellas se rompieron alguna vez, y fue la Calle la que les enseñó a repararse con oro.',
        'On the highest peaks of Tsuki, where the Echo arrives purest, shine the towers of the Crystal Court. Its beings wear masks of jade, porcelain, lacquer, gold and glass: fragile outside, eternal inside.\n\n'
            'It is the court of priestesses and artists. The Oracle reads the future in the constellations; the Geisha knows every word of every song; the Violet Empress rules with a fan; Origami folds itself day after day without tearing. To them, Echo is art, and art demands purity.\n\n'
            'Their lord is the Stained Glass, a mask made of hundreds of coloured panes. Each pane is the light of a different country: it will not wake until it has heard forty. When it finally opens its eyes, the light of the whole moon passes through it.\n\n'
            'The Court despises the noise of the Neon Street. But the oldest porcelains remember something they would rather not say: many of them broke once, and it was the Street that taught them to mend themselves with gold.',
      ),
    ),
    LoreChapter(
      id: 'guerras',
      tomo: 3,
      numeral: '1',
      kanji: '戦',
      title: Txt('Las guerras de la luna', 'The wars of the moon'),
      lock: LoreLock.masks,
      need: 20,
      body: Txt(
        'Tsuki nunca ha estado en paz. El Eco no alcanza para todos, y cada clan cree saber mejor que los demás cómo usarlo.\n\n'
            'Hay guerras viejas, que se pelean desde antes de que existieran los nombres: la Forja contra los Elementales, la máquina contra la tierra. Hay guerras de orgullo: el Shogunato contra la Corte del Zorro, el honor contra la astucia. Y hay guerras de clase: la Calle de Neón contra la Corte de Cristal, el ruido contra el palacio.\n\n'
            'Pero las guerras más feroces no son entre clanes, sino entre seres. Hermanos que quieren la misma corona, maestros y discípulos, almas que se separaron en tres despertares distintos, juramentos sellados con sangre.\n\n'
            'Cada vínculo tiene su historia, y la luna las guarda todas. Solo las cuenta cuando las dos partes han despertado.',
        'Tsuki has never been at peace. There is not enough Echo for everyone, and every clan thinks it knows better than the rest how to use it.\n\n'
            'There are old wars, fought since before names existed: the Forge against the Elementals, the machine against the land. There are wars of pride: the Shogunate against the Fox Court, honour against cunning. And there are wars of class: the Neon Street against the Crystal Court, noise against the palace.\n\n'
            'But the fiercest wars are not between clans but between beings. Siblings who want the same crown, masters and students, souls split across three different awakenings, oaths sealed in blood.\n\n'
            'Every bond has its story, and the moon keeps them all. It only tells them once both sides have woken.',
      ),
    ),
    LoreChapter(
      id: 'ultras',
      tomo: 3,
      numeral: '2',
      kanji: '極',
      title: Txt('Los Ocho Ultras', 'The Eight Ultras'),
      lock: LoreLock.ultra,
      body: Txt(
        'Hay ocho seres que ningún rango alcanza a describir y que no son divinas. Se las llama los Ultras: la Reina Carmesí, el Rey Kitsune, el Kitsunebi, el Rey Oni, el Rey Dragón, la Lava Viva, el Cromo Arcoíris y el Vitral.\n\n'
            'Casi todos gobiernan un clan, y cualquiera de ellos podría arrasar uno. Sin embargo ninguno se ha sentado en el Trono, porque el Trono no se toma con fuerza: se toma con Eco, y el Soberano actual está sostenido por las siete Caras divinas.\n\n'
            'Por eso, en la cara oscura de la luna, alguien les habla a los ocho. Les promete un asiento cuando vuelva. Les recuerda que una vez él también fue Soberano.\n\n'
            'Se dice que si los ocho llegan a despertar juntos, el que cayó podrá subir de nuevo.',
        'There are eight beings no rank can describe that are not divine. They are called the Ultras: the Crimson Queen, the Kitsune King, the Kitsunebi, the Oni King, the Dragon King, the Living Lava, the Rainbow Chrome and the Stained Glass.\n\n'
            'Almost all of them rule a clan, and any of them could raze one. Yet none has sat on the Throne, because the Throne is not taken by force: it is taken with Echo, and the current Sovereign is held up by the seven divine Faces.\n\n'
            'That is why, on the dark side of the moon, someone speaks to the eight. He promises them a seat when he returns. He reminds them that he, too, was once Sovereign.\n\n'
            'It is said that if all eight ever wake together, the one who fell will be able to rise again.',
      ),
    ),
    LoreChapter(
      id: 'caras',
      tomo: 4,
      numeral: '1',
      kanji: '九',
      title: Txt('Las 9 Caras del Universo', 'The 9 Faces of the Universe'),
      lock: LoreLock.divine,
      need: 1,
      body: Txt(
        'El universo se mira a sí mismo a través de nueve caras. No son seres como los demás: no llegaron a Tsuki, siempre estuvieron. Cuando Tsuki dio su primer latido, abrió nueve ojos.\n\n'
            'Siete de ellas son las Caras divinas. Cada una gobierna una fuerza que ningún ser puede tocar: el tiempo, el caos, la grieta, los astros olvidados, el sueño, la furia y el pacto. Juntas sostienen a quien se sienta en el Trono. Si una sola le retira su apoyo, el Soberano tiembla.\n\n'
            'Las otras dos son los Dioses Supremos: el que gobierna y el que cayó, la Cara Soberana y la Cara Rota. Son los únicos que alcanzaron el control total del sonido. Una palabra suya basta para encender una estrella o callar un mundo entero, y entre ellos dos se ha decidido, una y otra vez, el destino de la luna.\n\n'
            'Una Cara solo se muestra ante quien demostró merecerla. Las demás permanecen veladas, y sus nombres solo se susurran.',
        'The universe looks at itself through nine faces. They are not beings like the others: they did not arrive on Tsuki, they were always there. When Tsuki gave its first heartbeat, it opened nine eyes.\n\n'
            'Seven of them are the divine Faces. Each rules a force no being can touch: time, chaos, the rift, the forgotten stars, sleep, fury and the pact. Together they hold up whoever sits on the Throne. If a single one withdraws its support, the Sovereign trembles.\n\n'
            'The other two are the Supreme Gods: the one who rules and the one who fell, the Sovereign Face and the Broken Face. They are the only ones who reached total control of sound. A single word of theirs is enough to light a star or silence a whole world, and between the two of them the fate of the moon has been decided again and again.\n\n'
            'A Face only shows itself to one who proved worthy of it. The rest remain veiled, and their names are only whispered.',
      ),
    ),
    LoreChapter(
      id: 'caida',
      tomo: 4,
      numeral: '2',
      kanji: '堕',
      title: Txt('La Caída', 'The Fall'),
      lock: LoreLock.divine,
      need: 3,
      body: Txt(
        'Hubo un tiempo en que el Trono del Eco tenía otro dueño. Su rostro era blanco y liso como la luna llena, y lo llamaban la Primera Cara. Fue la primera en dominar el sonido por completo: su voz movía mundos. Gobernó durante eras, y la luna fue feliz.\n\n'
            'Pero el Eco embriaga. La Primera Cara empezó a guardarlo para sí: dejó de repartirlo entre los clanes, secó los cráteres, apagó las canciones que no le gustaban. Quería que nada sonara en el universo sin su permiso.\n\n'
            'Ningún rostro soporta eso. El suyo empezó a agrietarse, y por las grietas asomó el fuego del cosmos que se había tragado. Entonces las siete Caras divinas hicieron lo que nunca habían hecho: le retiraron su apoyo. La Runa de Sangre escribió la Ley del Trono, el Oni Cósmico fue el primero en firmarla, y el Kabuki Ardiente bailó sobre las ruinas del palacio.\n\n'
            'La Primera Cara cayó desde el Trono hasta la cara oscura de la luna, llorando oro. Ni siquiera esa caída le hizo una grieta a Tsuki: lo único que se rompió fue su propio rostro. De su rostro se desprendieron cuatro pedazos que, siglos después, serían los Antiguos. Desde ese día se le llama el Dios Caído.\n\n'
            'Solo una de las siete lloró con él: el Ángel de Lágrimas Doradas. Todavía llora.\n\n'
            'Y de las galaxias que el caído dejó sueltas al romperse nació un nuevo rostro, con constelaciones por trenzas y un sol en la frente. Las siete lo sentaron en el Trono. Es el Dios del Universo, y gobierna hoy.',
        'There was a time when the Throne of the Echo had another owner. Its face was white and smooth as the full moon, and it was called the First Face. It was the first to command sound completely: its voice moved worlds. It ruled for ages, and the moon was happy.\n\n'
            'But Echo intoxicates. The First Face began to keep it for itself: it stopped sharing it among the clans, dried the craters, silenced the songs it did not like. It wanted nothing in the universe to sound without its permission.\n\n'
            'No face can bear that. Its own began to crack, and through the cracks showed the fire of the cosmos it had swallowed. Then the seven divine Faces did what they had never done: they withdrew their support. The Blood Rune wrote the Law of the Throne, the Cosmic Oni was the first to sign it, and the Burning Kabuki danced on the ruins of the palace.\n\n'
            'The First Face fell from the Throne to the dark side of the moon, weeping gold. Not even that fall left a crack in Tsuki: the only thing that broke was its own face. Four pieces broke from its face which, centuries later, would be the Ancients. From that day it has been called the Fallen God.\n\n'
            'Only one of the seven wept with it: the Angel of Golden Tears. It weeps still.\n\n'
            'And from the galaxies the fallen one let loose when it broke, a new face was born, with constellations for braids and a sun on its brow. The seven sat it on the Throne. It is the God of the Universe, and it rules today.',
      ),
    ),
    LoreChapter(
      id: 'trono',
      tomo: 4,
      numeral: '3',
      kanji: '玉',
      title: Txt('El Trono Vacío', 'The Empty Throne'),
      lock: LoreLock.god,
      body: Txt(
        'La Ley del Trono, escrita con sangre por la Cara del Pacto, tiene una sola línea: «El Trono del Eco pertenece a quien sostenga más Eco. Ningún reinado es eterno.»\n\n'
            'Con esa ley cayó la Primera Cara. Con esa misma ley puede caer el Dios del Universo. Él lo sabe: por eso nunca duerme, por eso cuida a las siete Caras como a hijas, por eso cuenta cada canción que llega a la luna.\n\n'
            'En la cara oscura, el Dios Caído cuenta también. Tiene a los ocho Ultras. Tiene la paciencia de quien ya perdió todo una vez. Y tiene algo que el Soberano no tiene: sabe exactamente cómo se rompe un rostro.\n\n'
            'Al principio de su exilio gritó contra la luna con toda su voz, con un poder capaz de apagar galaxias. Tsuki ni siquiera tembló. Ese día entendió que la luna no se conquista destruyéndola: se conquista desde el Trono.\n\n'
            'Mientras tanto, los clanes afilan sus armas. La Forja termina su máquina. El Shogunato elige heredero. La Corte del Zorro miente a todos por igual.\n\n'
            'Pero hay una pieza que ninguno controla: los Portadores. Todo el Eco de Tsuki nace de alguien que escucha, en mundos que ningún dios ha pisado. Y una leyenda vieja, que ambos dioses conocen y ninguno nombra, habla de un Portador capaz de despertar a los dos, y de sostener más Eco que cualquiera de ellos.\n\n'
            'El Trono, en realidad, nunca está ocupado. Solo está esperando.\n\n'
            'Y en algún mundo de abajo, alguien sigue escuchando.',
        'The Law of the Throne, written in blood by the Face of the Pact, has a single line: “The Throne of the Echo belongs to whoever holds the most Echo. No reign is eternal.”\n\n'
            'By that law the First Face fell. By that same law the God of the Universe can fall. He knows it: that is why he never sleeps, why he cares for the seven Faces like daughters, why he counts every song that reaches the moon.\n\n'
            'On the dark side, the Fallen God is counting too. He has the eight Ultras. He has the patience of one who has already lost everything once. And he has something the Sovereign lacks: he knows exactly how a face breaks.\n\n'
            'Early in his exile he screamed at the moon with all his voice, with a power able to put out galaxies. Tsuki did not even tremble. That day he understood that the moon is not conquered by destroying it: it is conquered from the Throne.\n\n'
            'Meanwhile, the clans sharpen their weapons. The Forge finishes its machine. The Shogunate chooses an heir. The Fox Court lies to everyone equally.\n\n'
            'But there is one piece none of them controls: the Bearers. All the Echo of Tsuki is born from someone who listens, in worlds no god has set foot on. And an old legend, one both gods know and neither names, speaks of a Bearer able to wake them both, and to hold more Echo than either of them.\n\n'
            'The Throne, in truth, is never occupied. It is only waiting.\n\n'
            'And somewhere in the worlds below, someone is still listening.',
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
        'ryuuou', 'ishiryuu', 'yougan_ni', 'yougan', 'iwa', 'umi', 'sango', 'fubuki', 'shimo',
        'tsurara', 'mori', 'mori_ni', 'aki', 'inazuma', 'hinome', 'homura', 'hone',
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
        'El Oráculo de la Corte ya vio el final de la historia en las estrellas, y lo escribió en un vidrio que nadie puede leer. Solo dijo una frase en voz alta: «El próximo Soberano no tendrá rostro.»',
        'The Court\'s Oracle has already seen the end of the story in the stars, and wrote it on a pane no one can read. It only said one sentence aloud: “The next Sovereign will have no face.”',
      ),
      leader: 'hari',
      rival: 'neon',
      members: [
        'hari', 'kisaki', 'miko', 'geisha', 'origami', 'hisui_oni', 'jiki', 'suishou', 'hisui',
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
      Txt('La guerra más vieja de Tsuki. Uno nació de las galaxias que el otro soltó al romperse. Ninguno puede destruir al otro: si el Caído desaparece, el Soberano olvida por qué no debe acumular Eco.',
          'The oldest war on Tsuki. One was born from the galaxies the other let loose when it broke. Neither can destroy the other: if the Fallen one vanished, the Sovereign would forget why it must not hoard Echo.'),
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
      Txt('El Oráculo aprendió a leer el futuro en las constelaciones que Constelación lleva dibujadas. Es la única mortal a la que una Cara le ha enseñado algo.',
          'The Oracle learned to read the future in the constellations Constellation wears. She is the only mortal a Face has ever taught anything.'),
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
      BondKind.family,
      Txt('Las Tres Coronas', 'The Three Crowns'),
      Txt('Hierro, Trenza y Humo. Hermanos, herederos del Rey Oni, y rivales desde que aprendieron a contar. Cada uno ha completado más álbumes que el anterior para demostrar que merece la corona.',
          'Iron, Braid and Smoke. Siblings, heirs of the Oni King, and rivals since they learned to count. Each has finished more albums than the last to prove it deserves the crown.'),
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
      BondKind.family,
      Txt('Las colas separadas', 'The parted tails'),
      Txt('Fueron reina y consorte. El Rey Kitsune juntó setenta y cinco seres para impresionarla. Ella sigue sin responder, pero tampoco ha elegido a otro.',
          'They were queen and consort. The Kitsune King gathered seventy-five beings to impress her. She still has not answered, but she has not chosen another either.'),
    ),
    LoreBond(
      ['ryuuou', 'ishiryuu'],
      BondKind.family,
      Txt('Padre de piedra', 'Father of stone'),
      Txt('El Dragón de Piedra es hijo del Rey Dragón. Lleva sesenta días sin moverse para demostrar que puede llegar a los cien de su padre.',
          'The Stone Dragon is the Dragon King\'s child. It has not moved in sixty days to prove it can reach its father\'s hundred.'),
    ),
    LoreBond(
      ['umi', 'sango'],
      BondKind.family,
      Txt('Hermanas del mar', 'Sisters of the sea'),
      Txt('El Oni del Mar guarda las mareas; la Sirena de Coral, las profundidades. Cuando discuten, los mares de polvo de Tsuki se levantan en olas.',
          'The Sea Oni keeps the tides; the Coral Siren, the depths. When they argue, the dust seas of Tsuki rise in waves.'),
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
      Txt('Los hijos del vapor', 'The children of steam'),
      Txt('Tres seres de tres clanes enemigos alimentados por la misma caldera. Se reconocen por el silbido. En una guerra, ninguna sabe a quién disparar.',
          'Three beings from three enemy clans fed by the same boiler. They recognise each other by the whistle. In a war, none knows whom to shoot.'),
    ),
    LoreBond(
      ['hisui', 'hisui_oni', 'kitsune_hisui'],
      BondKind.family,
      Txt('La familia de jade', 'The jade family'),
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
      Txt('El Oni Blanco y el Oni de Sombra nacieron del mismo molde, uno al mediodía y otro a medianoche. Cada uno cree ser el original.',
          'The White Oni and the Shadow Oni came from the same mould, one at noon and the other at midnight. Each believes it is the original.'),
    ),
    LoreBond(
      ['tetsu', 'yaiba'],
      BondKind.mentor,
      Txt('El yunque y el filo', 'The anvil and the edge'),
      Txt('El Oni de Acero forjó a Filo de Acero con sus propias manos. El discípulo ya corta más que el maestro, y el maestro lo sabe.',
          'The Steel Oni forged the Steel Edge with its own hands. The student already cuts sharper than the master, and the master knows it.'),
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
      Txt('Nació de las galaxias que la caída de su antecesor dejó sueltas. Sus trenzas son constelaciones vivas y su tercer ojo ve cada Eco que llega a la luna. Cuando habla, el universo obedece: con una palabra enciende soles y con un silencio los apaga. Gobierna desde el Trono gracias al pacto de las siete Caras divinas: mientras lo sostengan, nadie puede tocarlo. Conoce la Ley del Trono mejor que nadie, porque la usó para subir.',
          'Born from the galaxies its predecessor\'s fall let loose. Its braids are living constellations and its third eye sees every Echo that reaches the moon. When it speaks, the universe obeys: one word lights suns and one silence puts them out. It rules from the Throne thanks to the pact of the seven divine Faces: while they hold it up, no one can touch it. It knows the Law of the Throne better than anyone, because it used it to rise.'),
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
      Txt('Llora oro desde el día de la Caída: es la única de las siete que todavía ama a la Cara Rota. Cuida el sueño de los Portadores y despierta para quien se duerme con música, noche tras noche.',
          'It has wept gold since the day of the Fall: it is the only one of the seven that still loves the Broken Face. It watches over the Bearers\' sleep and wakes for whoever falls asleep to music, night after night.'),
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

  /// Whether [chapter] is open to someone with the [owned] masks.
  static bool isOpen(LoreChapter chapter, Set<String> owned, {required int level}) =>
      released(chapter, level) &&
      switch (chapter.lock) {
        LoreLock.free => true,
        LoreLock.masks => owned.length >= chapter.need,
        LoreLock.faction => faction(chapter.factionId)!.members.any(owned.contains),
        LoreLock.ultra => MaskCatalog.all.any((m) => m.rarity == MaskRarity.ul && !m.divine && owned.contains(m.id)),
        LoreLock.divine => MaskCatalog.all.where((m) => m.divine && owned.contains(m.id)).length >= chapter.need,
        LoreLock.level => level >= chapter.need,
        LoreLock.god => MaskCatalog.all.any((m) => m.rarity == MaskRarity.dios && owned.contains(m.id)),
      };

  static int openCount(Set<String> owned, {required int level}) =>
      chapters.where((c) => isOpen(c, owned, level: level)).length;

  static int releasedCount(int level) => chapters.where((c) => released(c, level)).length;

  /// How many of [f]'s members have awakened.
  static int awakened(LoreFaction f, Set<String> owned) => f.members.where(owned.contains).length;

  static bool complete(LoreFaction f, Set<String> owned) => awakened(f, owned) == f.members.length;

  /// The bonds [maskIds] take part in.
  static List<LoreBond> bondsOf(Iterable<String> maskIds) {
    final ids = maskIds.toSet();
    return [for (final b in bonds) if (b.masks.any(ids.contains)) b];
  }
}
