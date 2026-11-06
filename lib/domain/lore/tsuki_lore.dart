import '../../core/localization/app_language.dart';
import '../entities/oni_mask.dart';

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

  /// Volumes readable in the app; the rest are coming soon.
  static const int releasedTomos = 1;

  static bool released(LoreChapter c) => c.tomo <= releasedTomos;

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
        'Antes de las estrellas hubo un sonido. No era una voz ni un trueno: era el primer latido del universo. De ese latido nació Tsuki.\n\n'
            'Tsuki no es la luna que ves desde tu ventana. Es la Luna Madre, la que flota en el centro exacto de todo lo que existe. Las demás lunas son reflejos suyos, espejos colgados sobre mil mundos para recordarles hacia dónde mirar.\n\n'
            'Todo lo que suena en el universo termina viajando hasta ella. Una canción tarareada en una cocina, el rugido de un estadio, un disco girando a las tres de la mañana: cada sonido deja una estela de luz que cruza el vacío y se posa en su superficie. Por eso Tsuki brilla. No refleja ningún sol. Brilla con la música de todos los mundos.\n\n'
            'En su cara oculta se alza el Trono del Eco, tallado en luna pura. Quien se sienta en él gobierna el pulso del universo: decide qué suena, qué se olvida y qué vuelve a sonar.\n\n'
            'Y como todo poder que existe, alguien lo quiere.',
        'Before the stars there was a sound. Not a voice, not thunder: the first heartbeat of the universe. From that heartbeat Tsuki was born.\n\n'
            'Tsuki is not the moon you see from your window. It is the Mother Moon, floating at the exact centre of everything that exists. Every other moon is a reflection of it, a mirror hung above a thousand worlds to remind them where to look.\n\n'
            'Everything that sounds in the universe ends up travelling to it. A song hummed in a kitchen, the roar of a stadium, a record spinning at three in the morning: every sound leaves a trail of light that crosses the void and settles on its surface. That is why Tsuki shines. It reflects no sun. It shines with the music of every world.\n\n'
            'On its hidden face stands the Throne of the Echo, carved from pure moon. Whoever sits on it rules the pulse of the universe: what sounds, what is forgotten, what sounds again.\n\n'
            'And like every power that exists, someone wants it.',
      ),
    ),
    LoreChapter(
      id: 'eco',
      tomo: 1,
      numeral: '1',
      kanji: '響',
      title: Txt('El Eco y el Portador', 'The Echo and the Bearer'),
      body: Txt(
        'La luz que la música deja al llegar a Tsuki se llama Eco. Es la energía más antigua y más codiciada del universo: con Eco se forjan armas, se cierran heridas y se despiertan los que aún tienen algo que decir.\n\n'
            'Pero el Eco tiene una regla que ni los dioses pueden romper: solo nace cuando alguien escucha. Una canción que nadie oye no deja rastro. Hace falta un oído, una atención, alguien dispuesto a quedarse hasta el final del tema.\n\n'
            'Por eso existen los Portadores. Un Portador es un ser de los mundos de abajo que escucha con tanta fuerza que su Eco llega intacto a la luna. No pelea, no viaja, casi nunca sabe que Tsuki existe. Solo escucha.\n\n'
            'Tú eres un Portador.\n\n'
            'Cada canción que escuchas entera sube a Tsuki convertida en Eco. Cada madrugada en vela, cada álbum oído de principio a fin, cada racha de días sin soltar los audífonos alimenta algo allá arriba. Y allá arriba hay seres que llevan siglos esperando a alguien como tú.',
        'The light music leaves when it reaches Tsuki is called the Echo. It is the oldest, most coveted energy in the universe: with Echo, weapons are forged, wounds are closed and those who still have something to say are woken.\n\n'
            'But the Echo has a rule not even the gods can break: it is only born when someone listens. A song nobody hears leaves no trace. It takes an ear, attention, someone willing to stay until the end of the track.\n\n'
            'That is why Bearers exist. A Bearer is a being from the worlds below who listens so hard that their Echo reaches the moon whole. They do not fight, do not travel, almost never know Tsuki exists. They just listen.\n\n'
            'You are a Bearer.\n\n'
            'Every song you hear in full rises to Tsuki as Echo. Every sleepless dawn, every album heard from start to end, every streak of days without taking off your headphones feeds something up there. And up there are beings who have waited centuries for someone like you.',
      ),
    ),
    LoreChapter(
      id: 'mascaras',
      tomo: 1,
      numeral: '2',
      kanji: '面',
      title: Txt('Las máscaras y sus rangos', 'The masks and their ranks'),
      lock: LoreLock.masks,
      need: 1,
      body: Txt(
        'Las máscaras son los habitantes de Tsuki. Ninguna recuerda la cara que tuvo: llegaron de mundos lejanos, forjadas en acero, coral, vidrio, hueso o fuego, y en el viaje hasta la luna perdieron el cuerpo. Solo quedó su rostro, y dentro del rostro, una voluntad.\n\n'
            'Una máscara dormida es solo un objeto. Para despertar necesita Eco, y el Eco solo lo dan los Portadores. Cuando una máscara te elige, se alimenta de lo que escuchas, y cuando ha juntado lo suficiente, abre los ojos. Eso es tu colección: cada máscara desbloqueada es un ser que despertó gracias a ti. Por eso cada una pide algo distinto. Comen el Eco que se les parece.\n\n'
            'En Tsuki el poder se mide por cuánto Eco puede sostener un rostro, y así nacieron los rangos:\n\n'
            'R, los Errantes: máscaras jóvenes o sencillas que vagan por los cráteres buscando un clan que las acoja.\n\n'
            'SR, los Guerreros: forjadas para pelear y juradas a un estandarte.\n\n'
            'SSR, los Señores: herederos, generales y sacerdotisas. Cada uno gobierna un pedazo de luna.\n\n'
            'UL, los Ultras: leyendas vivas. El suelo de Tsuki se agrieta a su paso.\n\n'
            'Y por encima de todos, las 9 Caras del Universo: siete divinas y dos Dioses Supremos.\n\n'
            'Ninguna máscara está conforme con su rango. Todas, tarde o temprano, miran hacia la cara oculta de la luna.',
        'The masks are the inhabitants of Tsuki. None remembers the face it once had: they came from distant worlds, forged in steel, coral, glass, bone or fire, and on the journey to the moon they lost their bodies. Only the face remained, and inside the face, a will.\n\n'
            'A sleeping mask is just an object. To wake it needs Echo, and only Bearers give Echo. When a mask chooses you, it feeds on what you listen to, and once it has gathered enough, it opens its eyes. That is your collection: every unlocked mask is a being that woke thanks to you. That is why each one asks for something different. They eat the Echo that resembles them.\n\n'
            'On Tsuki, power is measured by how much Echo a face can hold, and so the ranks were born:\n\n'
            'R, the Wanderers: young or simple masks roaming the craters, looking for a clan to take them in.\n\n'
            'SR, the Warriors: forged to fight and sworn to a banner.\n\n'
            'SSR, the Lords: heirs, generals and priestesses. Each rules a piece of the moon.\n\n'
            'UL, the Ultras: living legends. The ground of Tsuki cracks where they walk.\n\n'
            'And above them all, the 9 Faces of the Universe: seven divine ones and two Supreme Gods.\n\n'
            'No mask is content with its rank. Sooner or later, all of them look toward the hidden face of the moon.',
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
        'Antes de los clanes y de las guerras hubo cuatro rostros: el Tengu de nariz larga, el Oni del kabuki, la Hannya de los celos y una máscara de metal que nadie sabe quién forjó. Fueron los primeros en llegar a Tsuki, y de sus copias, sombras y reflejos nacieron todos los que hoy se llaman Los Antiguos.\n\n'
            'Los Antiguos no buscan el Trono. Son la memoria de la luna: cada uno guarda un momento que pasó de verdad. Primer Eco recuerda la primera canción que escuchaste. La Luna de Sangre vio el último eclipse. 3:33 vive atrapado en el minuto exacto en que el reloj repite su número.\n\n'
            'Con los siglos, algunos cambiaron de piel —tinta, hielo, oro, píxeles, neón— y vagan por los cráteres como reflejos de los primeros. Aparecen una vez por semana ante quien supera sus pruebas, y nunca dos veces de la misma forma.\n\n'
            'En el centro de todos duerme El Oni, la máscara completa. No despierta con un logro: despierta cuando sus hermanos lo llaman todos juntos.',
        'Before the clans and the wars there were four faces: the long-nosed Tengu, the kabuki Oni, the jealous Hannya and a metal mask no one knows who forged. They were the first to reach Tsuki, and from their copies, shadows and reflections came all those now called The Ancients.\n\n'
            'The Ancients do not seek the Throne. They are the memory of the moon: each keeps a moment that truly happened. First Echo remembers the first song you heard. The Blood Moon saw the last eclipse. 3:33 lives trapped in the exact minute when the clock repeats its number.\n\n'
            'Over the centuries some changed skin —ink, ice, gold, pixels, neon— and roam the craters as reflections of the first ones. They appear once a week to whoever passes their trials, and never twice in the same form.\n\n'
            'At the centre of them all sleeps The Oni, the complete mask. It does not wake for a feat: it wakes when all its siblings call it together.',
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
        'En el cráter más profundo de Tsuki, donde el Eco se acumula como lluvia en un pozo, arde la Forja. Sus máscaras no nacieron: fueron construidas. Acero, cobre, engranajes, pantallas, cables que chispean como nervios.\n\n'
            'La Forja cree que el Eco no es un regalo sino un recurso, y que un recurso se extrae. Sus antenas escuchan cada frecuencia que llega a la luna; sus centinelas vigilan los caminos; sus mechas excavan la roca buscando Eco viejo, sepultado desde antes de la Caída.\n\n'
            'La gobierna la Calavera Cibernética, que se armó a sí misma con los restos de las máscaras que cayeron en batalla. Nadie sabe cuántas caras lleva puestas debajo de la que muestra.\n\n'
            'La Forja tiene una herida que no confiesa: es el único gran clan sin un Ultra. Por eso no deja de construir. En el fondo del cráter, dicen, algo enorme está a medio terminar.\n\n'
            'Su enemigo natural son los Elementales. Cada bosque que cae es combustible; cada río, refrigerante. Y cada máquina, para los Elementales, es una herida en la luna.',
        'In the deepest crater of Tsuki, where Echo gathers like rain in a well, burns the Forge. Its masks were not born: they were built. Steel, copper, gears, screens, cables sparking like nerves.\n\n'
            'The Forge believes Echo is not a gift but a resource, and a resource is extracted. Its antennas listen to every frequency that reaches the moon; its sentinels guard the roads; its mechas dig through rock looking for old Echo, buried since before the Fall.\n\n'
            'It is ruled by the Cyber Skull, which built itself from the remains of masks that fell in battle. Nobody knows how many faces it wears beneath the one it shows.\n\n'
            'The Forge has a wound it never admits: it is the only great clan without an Ultra. That is why it never stops building. At the bottom of the crater, they say, something enormous is half finished.\n\n'
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
        'Algunas máscaras no llegaron a Tsuki: brotaron de ella. Cuando el Eco toca la luna en un lugar con suficiente fuerza, la roca se vuelve rostro. Así nacieron los Elementales: de la lava, del coral, de la nieve, de la hoja seca y del rayo.\n\n'
            'Viven como vive el clima. El Oni del Mar y la Sirena de Coral cuidan las mareas de los mares de polvo; los espíritus del bosque crecen donde alguien escuchó lo-fi durante horas; la Ventisca y el Oni de las Nieves soplan sobre los cráteres helados; la lava fluye bajo todo, y a veces sube.\n\n'
            'Sobre todos reina el Rey Dragón, la máscara más vieja de las que nacieron de la luna. Su piel es roca y su paciencia, también: solo despierta ante quien escucha cien días sin faltar uno.\n\n'
            'Los Elementales no quieren el Trono. Quieren que nadie lo use para secar la luna. Por eso odian a la Forja, que convierte bosques en carbón y mares en vapor.',
        'Some masks did not arrive on Tsuki: they sprouted from it. When Echo touches the moon somewhere with enough force, the rock becomes a face. That is how the Elementals were born: from lava, coral, snow, dry leaves and lightning.\n\n'
            'They live as weather lives. The Sea Oni and the Coral Siren tend the tides of the dust seas; the forest spirits grow where someone listened to lo-fi for hours; the Blizzard and the Snow Oni blow over the frozen craters; lava flows beneath everything, and sometimes rises.\n\n'
            'Above them all reigns the Dragon King, the oldest of the masks born from the moon. Its skin is rock and so is its patience: it only wakes for someone who listens a hundred days without missing one.\n\n'
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
            'Al frente está el Rey Oni, que no ganó su corona en combate sino reuniendo lealtades: cincuenta máscaras juraron por él. Pero un rey necesita heredero, y tiene tres: las Tres Coronas. Hierro, Trenza y Humo. Cada una cree ser la elegida.\n\n'
            'El Shogunato desprecia a la Corte del Zorro, que para ellos es un nido de mentirosos que gana guerras sin pelearlas. Lo peor, dicen los generales, es que casi siempre las gana.',
        'On the eastern plateaus of Tsuki stand the castles of the Shogunate: iron kabutos, crowns, armour with runes and steam. It is the most orderly clan on the moon, and the one most convinced it deserves the Throne.\n\n'
            'Its code is simple: Echo is earned, never stolen. A samurai of Tsuki rises through discipline —days in a row, whole albums, hundreds of songs by one master— and never through shortcuts. Bushi trains the young; Kabuto marches with the army; the Rune Knight guards the mountain passes.\n\n'
            'At its head stands the Oni King, who did not win his crown in battle but by gathering loyalties: fifty masks swore by him. But a king needs an heir, and he has three: the Three Crowns. Iron, Braid and Smoke. Each believes it is the chosen one.\n\n'
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
            'La Corte no tiene castillos: tiene máscaras en todas partes. Hay kitsune de vapor en la Forja, de porcelana en la Corte de Cristal, de neón en los callejones y de chatarra en los basurales. Ninguno es lo que parece. Todos informan a la Reina.\n\n'
            'La Reina Carmesí despierta tras nueve lunas llenas, una por cada cola. El Rey Kitsune, su antiguo consorte, juntó setenta y cinco máscaras para demostrarle que también sabía reinar, y ella todavía no le contesta. Entre ambos arde el Kitsunebi, el fuego del zorro, que solo se enciende de madrugada bajo la luna llena.\n\n'
            'El Shogunato los llama tramposos. La Corte responde que el honor es un lujo de quien nunca tuvo que esconderse.',
        'The kitsune came to Tsuki following the full moon, as foxes do in every world. They stayed because they discovered that here the full moon lasts forever in some corner, and that with enough moons a fox can grow nine tails.\n\n'
            'The Court has no castles: it has masks everywhere. There are steam kitsune in the Forge, porcelain ones in the Crystal Court, neon ones in the alleys and scrap ones in the junkyards. None is what it seems. All of them report to the Queen.\n\n'
            'The Crimson Queen wakes after nine full moons, one for each tail. The Kitsune King, her former consort, gathered seventy-five masks to prove he could rule too, and she still has not answered him. Between them burns the Kitsunebi, the foxfire, which only lights at dawn under a full moon.\n\n'
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
        'Donde los caminos de Tsuki se cruzan nació una ciudad que nadie planeó: letreros, grafitis, pantallas, bajos que hacen temblar el polvo lunar. Es la Calle de Neón, y sus máscaras son las que ningún clan quiso.\n\n'
            'Aquí nadie pregunta de dónde vienes. La Pantera Neón manda en los techos, los grafitis marcan territorio, el Tóxico y la Plaga venden Eco cortado en los callejones, y el Camuflaje sabe cosas que no debería saber. Su música es la de la calle: hip-hop, urbano, letras que no piden permiso.\n\n'
            'La gobierna el Cromo Arcoíris, una máscara de seis cuernos que refleja todos los colores porque se negó a tener uno solo. Para despertarlo hay que haber escuchado los doce estilos de la luna: la Calle no acepta reyes que solo conozcan un barrio.\n\n'
            'Su enemiga es la Corte de Cristal, que mira la ciudad desde sus torres y la llama ruido. La Calle responde pintando sus muros cada noche.',
        'Where the roads of Tsuki cross, a city no one planned was born: signs, graffiti, screens, basslines that shake the moon dust. It is the Neon Street, and its masks are the ones no clan wanted.\n\n'
            'Here no one asks where you come from. The Neon Panther rules the rooftops, graffiti marks territory, Toxic and Plague sell cut Echo in the alleys, and Camouflage knows things it should not. Their music is the music of the street: hip-hop, urban, lyrics that do not ask permission.\n\n'
            'It is ruled by the Rainbow Chrome, a six-horned mask that reflects every colour because it refused to have just one. To wake it you must have heard all twelve styles of the moon: the Street accepts no king who only knows one block.\n\n'
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
        'En las cumbres más altas de Tsuki, donde el Eco llega más limpio, brillan las torres de la Corte de Cristal. Sus máscaras son de jade, porcelana, laca, oro y vidrio: frágiles por fuera, eternas por dentro.\n\n'
            'Es la corte de las sacerdotisas y los artistas. El Oráculo lee el futuro en las constelaciones; la Geisha conoce cada letra de cada canción; la Emperatriz Violeta gobierna con un abanico; el Origami se dobla día tras día sin romperse. Para ellos el Eco es arte, y el arte requiere pureza.\n\n'
            'Su señor es el Vitral, una máscara hecha de cientos de vidrios de colores. Cada vidrio es la luz de un país distinto: no despierta hasta haber escuchado cuarenta. Cuando por fin abre los ojos, la luz de toda la luna pasa a través de él.\n\n'
            'La Corte desprecia el ruido de la Calle de Neón. Pero las porcelanas más viejas recuerdan algo que prefieren callar: muchas de ellas se rompieron alguna vez, y fue la Calle la que les enseñó a repararse con oro.',
        'On the highest peaks of Tsuki, where the Echo arrives purest, shine the towers of the Crystal Court. Its masks are jade, porcelain, lacquer, gold and glass: fragile outside, eternal inside.\n\n'
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
            'Pero las guerras más feroces no son entre clanes, sino entre máscaras. Hermanos que quieren la misma corona, maestros y discípulos, almas que se separaron en tres despertares distintos, juramentos sellados con sangre.\n\n'
            'Cada vez que despiertas a las dos partes de un vínculo, la luna te cuenta su historia.',
        'Tsuki has never been at peace. There is not enough Echo for everyone, and every clan thinks it knows better than the rest how to use it.\n\n'
            'There are old wars, fought since before names existed: the Forge against the Elementals, the machine against the land. There are wars of pride: the Shogunate against the Fox Court, honour against cunning. And there are wars of class: the Neon Street against the Crystal Court, noise against the palace.\n\n'
            'But the fiercest wars are not between clans but between masks. Siblings who want the same crown, masters and students, souls split across three different awakenings, oaths sealed in blood.\n\n'
            'Every time you wake both sides of a bond, the moon tells you its story.',
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
        'Hay ocho máscaras que ningún rango alcanza a describir y que no son divinas. Se las llama los Ultras: la Reina Carmesí, el Rey Kitsune, el Kitsunebi, el Rey Oni, el Rey Dragón, la Lava Viva, el Cromo Arcoíris y el Vitral.\n\n'
            'Casi todos gobiernan un clan, y cualquiera de ellos podría arrasar uno. Sin embargo ninguno se ha sentado en el Trono, porque el Trono no se toma con fuerza: se toma con Eco, y el Soberano actual está sostenido por las siete Caras divinas.\n\n'
            'Por eso, en la cara oscura de la luna, alguien les habla a los ocho. Les promete un asiento cuando vuelva. Les recuerda que una vez él también fue Soberano.\n\n'
            'Se dice que si los ocho despiertan bajo el mismo Portador, el que cayó podrá subir de nuevo.',
        'There are eight masks no rank can describe that are not divine. They are called the Ultras: the Crimson Queen, the Kitsune King, the Kitsunebi, the Oni King, the Dragon King, the Living Lava, the Rainbow Chrome and the Stained Glass.\n\n'
            'Almost all of them rule a clan, and any of them could raze one. Yet none has sat on the Throne, because the Throne is not taken by force: it is taken with Echo, and the current Sovereign is held up by the seven divine Faces.\n\n'
            'That is why, on the dark side of the moon, someone speaks to the eight. He promises them a seat when he returns. He reminds them that he, too, was once Sovereign.\n\n'
            'It is said that if all eight wake under the same Bearer, the one who fell will be able to rise again.',
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
        'El universo se mira a sí mismo a través de nueve caras. No son máscaras como las demás: no llegaron a Tsuki, siempre estuvieron. Cuando el primer latido creó la luna, la luna abrió nueve ojos.\n\n'
            'Siete de ellas son las Caras divinas. Cada una gobierna una fuerza que ninguna máscara puede tocar: el tiempo, el caos, la grieta, los astros olvidados, el sueño, la furia y el pacto. Juntas sostienen a quien se sienta en el Trono. Si una sola le retira su apoyo, el Soberano tiembla.\n\n'
            'Las otras dos son los Dioses Supremos: el que gobierna y el que cayó. Son la Primera Cara y la Cara Rota, y entre ellos dos se ha decidido, una y otra vez, el destino de la luna.\n\n'
            'Una Cara solo se muestra ante quien demostró merecerla. Las que aún no despiertas permanecen veladas.',
        'The universe looks at itself through nine faces. They are not masks like the others: they did not arrive on Tsuki, they were always there. When the first heartbeat created the moon, the moon opened nine eyes.\n\n'
            'Seven of them are the divine Faces. Each rules a force no mask can touch: time, chaos, the rift, the forgotten stars, sleep, fury and the pact. Together they hold up whoever sits on the Throne. If a single one withdraws its support, the Sovereign trembles.\n\n'
            'The other two are the Supreme Gods: the one who rules and the one who fell. They are the First Face and the Broken Face, and between the two of them the fate of the moon has been decided again and again.\n\n'
            'A Face only shows itself to one who proved worthy of it. Those you have not yet woken remain veiled.',
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
        'Hubo un tiempo en que el Trono del Eco tenía otro dueño. Su rostro era blanco y liso como la luna llena, y lo llamaban la Primera Cara. Gobernó durante eras, y la luna fue feliz.\n\n'
            'Pero el Eco embriaga. La Primera Cara empezó a guardarlo para sí: dejó de repartirlo entre los clanes, secó los cráteres, apagó las canciones que no le gustaban. Quería tener dentro toda la música del universo.\n\n'
            'Ningún rostro soporta eso. El suyo empezó a agrietarse, y por las grietas asomó el fuego del cosmos que se había tragado. Entonces las siete Caras divinas hicieron lo que nunca habían hecho: le retiraron su apoyo. La Runa de Sangre escribió la Ley del Trono, el Oni Cósmico fue el primero en firmarla, y el Kabuki Ardiente bailó sobre las ruinas del palacio.\n\n'
            'La Primera Cara cayó. Atravesó la luna entera y se hundió en su cara oscura, llorando oro. De su rostro se desprendieron cuatro pedazos que, siglos después, serían los Antiguos. Desde ese día se le llama el Dios Caído.\n\n'
            'Solo una de las siete lloró con él: el Ángel de Lágrimas Doradas. Todavía llora.\n\n'
            'Y de las galaxias que el caído dejó sueltas al romperse nació un nuevo rostro, con constelaciones por trenzas y un sol en la frente. Las siete lo sentaron en el Trono. Es el Dios del Universo, y gobierna hoy.',
        'There was a time when the Throne of the Echo had another owner. Its face was white and smooth as the full moon, and it was called the First Face. It ruled for ages, and the moon was happy.\n\n'
            'But Echo intoxicates. The First Face began to keep it for itself: it stopped sharing it among the clans, dried the craters, silenced the songs it did not like. It wanted to hold all the music of the universe inside.\n\n'
            'No face can bear that. Its own began to crack, and through the cracks showed the fire of the cosmos it had swallowed. Then the seven divine Faces did what they had never done: they withdrew their support. The Blood Rune wrote the Law of the Throne, the Cosmic Oni was the first to sign it, and the Burning Kabuki danced on the ruins of the palace.\n\n'
            'The First Face fell. It went through the whole moon and sank into its dark side, weeping gold. Four pieces broke from its face which, centuries later, would be the Ancients. From that day it has been called the Fallen God.\n\n'
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
            'Mientras tanto, los clanes afilan sus armas. La Forja termina su máquina. El Shogunato elige heredero. La Corte del Zorro miente a todos por igual.\n\n'
            'Pero hay una pieza que ninguno controla: el Portador. Todo el Eco de Tsuki nace de alguien que escucha. Y un Portador que haya despertado a los dos dioses tiene en sus manos más Eco que cualquiera de ellos.\n\n'
            'El Trono, en realidad, nunca está ocupado. Solo está esperando.\n\n'
            'Sigue escuchando.',
        'The Law of the Throne, written in blood by the Face of the Pact, has a single line: “The Throne of the Echo belongs to whoever holds the most Echo. No reign is eternal.”\n\n'
            'By that law the First Face fell. By that same law the God of the Universe can fall. He knows it: that is why he never sleeps, why he cares for the seven Faces like daughters, why he counts every song that reaches the moon.\n\n'
            'On the dark side, the Fallen God is counting too. He has the eight Ultras. He has the patience of one who has already lost everything once. And he has something the Sovereign lacks: he knows exactly how a face breaks.\n\n'
            'Meanwhile, the clans sharpen their weapons. The Forge finishes its machine. The Shogunate chooses an heir. The Fox Court lies to everyone equally.\n\n'
            'But there is one piece none of them controls: the Bearer. All the Echo of Tsuki is born from someone who listens. And a Bearer who has woken both gods holds more Echo than either of them.\n\n'
            'The Throne, in truth, is never occupied. It is only waiting.\n\n'
            'Keep listening.',
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
        'La máquina a medio terminar en el fondo del cráter tiene forma de rostro. La Forja no quiere un Ultra: quiere construir una Cara. La Calavera Cibernética ha estado juntando piezas de cada máscara que cae, y le falta solo una: un pedazo de la Primera Cara.',
        'The half-finished machine at the bottom of the crater has the shape of a face. The Forge does not want an Ultra: it wants to build a Face. The Cyber Skull has been gathering pieces of every mask that falls, and it lacks only one: a fragment of the First Face.',
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
        'Los Elementales saben algo que ningún clan sospecha: la lava que corre bajo Tsuki es el fuego que asomaba por las grietas de la Primera Cara. La luna no se enfrió nunca de la Caída. El Rey Dragón vigila ese fuego, porque el día que suba entero, el Dios Caído subirá con él.',
        'The Elementals know something no other clan suspects: the lava running beneath Tsuki is the fire that showed through the cracks of the First Face. The moon never cooled from the Fall. The Dragon King watches over that fire, because the day it rises whole, the Fallen God will rise with it.',
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
      Txt('Fueron reina y consorte. El Rey Kitsune juntó setenta y cinco máscaras para impresionarla. Ella sigue sin responder, pero tampoco ha elegido a otro.',
          'They were queen and consort. The Kitsune King gathered seventy-five masks to impress her. She still has not answered, but she has not chosen another either.'),
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
      Txt('Tres máscaras de tres clanes enemigos alimentadas por la misma caldera. Se reconocen por el silbido. En una guerra, ninguna sabe a quién disparar.',
          'Three masks from three enemy clans fed by the same boiler. They recognise each other by the whistle. In a war, none knows whom to shoot.'),
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
      Txt('La Primera Cara · Soberano del Universo', 'The First Face · Sovereign of the Universe'),
      Txt('Nació de las galaxias que la caída de su antecesor dejó sueltas. Sus trenzas son constelaciones vivas y su tercer ojo ve cada Eco que llega a la luna. Gobierna desde el Trono gracias al pacto de las siete Caras divinas: mientras lo sostengan, nadie puede tocarlo. Conoce la Ley del Trono mejor que nadie, porque la usó para subir.',
          'Born from the galaxies its predecessor\'s fall let loose. Its braids are living constellations and its third eye sees every Echo that reaches the moon. It rules from the Throne thanks to the pact of the seven divine Faces: while they hold it up, no one can touch it. It knows the Law of the Throne better than anyone, because it used it to rise.'),
    ),
    LoreFace(
      'ochigami',
      Txt('La Cara Rota · El que cayó', 'The Broken Face · The one who fell'),
      Txt('Fue el primer Soberano. Quiso guardar todo el Eco del universo y su rostro no lo soportó: se partió, y por las grietas asomó el fuego cósmico que hoy lo consume. Cayó a la cara oscura llorando oro. Desde ahí reúne a los ocho Ultras. No quiere venganza, dice. Quiere lo que es suyo.',
          'It was the first Sovereign. It wanted to keep all the Echo of the universe and its face could not bear it: it split, and through the cracks showed the cosmic fire that consumes it today. It fell to the dark side weeping gold. From there it gathers the eight Ultras. It does not want revenge, it says. It wants what is its own.'),
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
  static bool isOpen(LoreChapter chapter, Set<String> owned) => released(chapter) && switch (chapter.lock) {
        LoreLock.free => true,
        LoreLock.masks => owned.length >= chapter.need,
        LoreLock.faction => faction(chapter.factionId)!.members.any(owned.contains),
        LoreLock.ultra => MaskCatalog.all.any((m) => m.rarity == MaskRarity.ul && !m.divine && owned.contains(m.id)),
        LoreLock.divine => MaskCatalog.all.where((m) => m.divine && owned.contains(m.id)).length >= chapter.need,
        LoreLock.god => MaskCatalog.all.any((m) => m.rarity == MaskRarity.dios && owned.contains(m.id)),
      };

  static int openCount(Set<String> owned) => chapters.where((c) => isOpen(c, owned)).length;

  static int releasedCount() => chapters.where(released).length;

  /// How many of [f]'s members have awakened.
  static int awakened(LoreFaction f, Set<String> owned) => f.members.where(owned.contains).length;

  static bool complete(LoreFaction f, Set<String> owned) => awakened(f, owned) == f.members.length;

  /// The bonds [maskIds] take part in.
  static List<LoreBond> bondsOf(Iterable<String> maskIds) {
    final ids = maskIds.toSet();
    return [for (final b in bonds) if (b.masks.any(ids.contains)) b];
  }
}
