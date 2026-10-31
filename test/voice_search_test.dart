import 'package:flutter_test/flutter_test.dart';
import 'package:tsuki_tunes_mobile/data/datasources/voice_search_service.dart';

void main() {
  group('parseCommand', () {
    void expectCommand(String spoken, VoiceAction action, String query) {
      final c = VoiceSearchService.parseCommand(spoken);
      expect(c.action, action, reason: spoken);
      expect(c.query, query, reason: spoken);
    }

    test('play commands, longest phrase first', () {
      expectCommand('pon Chop Suey', VoiceAction.play, 'Chop Suey');
      expectCommand('Pon la canción Jefe', VoiceAction.play, 'Jefe');
      expectCommand('ponme algo de Deftones', VoiceAction.play, 'Deftones');
      expectCommand('quiero escuchar Los Bunkers', VoiceAction.play, 'Los Bunkers');
      expectCommand('reproduce Chancho en Piedra', VoiceAction.play, 'Chancho en Piedra');
      expectCommand('play the song Creep', VoiceAction.play, 'Creep');
    });

    test('search commands, with or without accents', () {
      expectCommand('búscame Mon Laferte', VoiceAction.search, 'Mon Laferte');
      expectCommand('buscame Mon Laferte', VoiceAction.search, 'Mon Laferte');
      expectCommand('busca Deftones', VoiceAction.search, 'Deftones');
      expectCommand('search for Tool', VoiceAction.search, 'Tool');
    });

    test('drops wake words, politeness and trailing punctuation', () {
      expectCommand('Oye pon Jefe por favor.', VoiceAction.play, 'Jefe');
      expectCommand('hey play Creep please', VoiceAction.play, 'Creep');
    });

    test('plain text is a search, keeping its accents', () {
      expectCommand('Canción de cuna', VoiceAction.search, 'Canción de cuna');
      expectCommand('   ', VoiceAction.search, '');
    });

    test('a bare command word is not a command', () {
      expectCommand('pon', VoiceAction.search, 'pon');
    });

    test('Japanese verb-final commands still work', () {
      expectCommand('Chop Sueyをかけて', VoiceAction.play, 'Chop Suey');
      expectCommand('Deftones探して', VoiceAction.search, 'Deftones');
    });
  });

  group('withoutArtistJoiner', () {
    test('drops the last "de"/"by" between song and artist', () {
      expect(VoiceSearchService.withoutArtistJoiner('Jefe de La Combo Tortuga'),
          'Jefe La Combo Tortuga');
      expect(VoiceSearchService.withoutArtistJoiner('Creep by Radiohead'),
          'Creep Radiohead');
    });

    test('null when there is nothing to drop', () {
      expect(VoiceSearchService.withoutArtistJoiner('Deftones'), isNull);
      expect(VoiceSearchService.withoutArtistJoiner('de'), isNull);
    });
  });

  group('pickLocale', () {
    const installed = ['en-US', 'es-ES', 'es-US', 'es-MX', 'ja-JP'];

    test("prefers the phone's own variant of the language", () {
      expect(VoiceSearchService.pickLocale('es', 'es-CL', installed), 'es-CL');
    });

    test('falls back to a Latin American variant, then any', () {
      expect(VoiceSearchService.pickLocale('es', 'en-US', installed), 'es-US');
      expect(VoiceSearchService.pickLocale('es', null, ['es-ES']), 'es-ES');
      expect(VoiceSearchService.pickLocale('es', null, ['es_AR']), 'es_AR');
    });

    test('null lets the recognizer choose', () {
      expect(VoiceSearchService.pickLocale('es', 'en-US', ['en-US']), isNull);
      expect(VoiceSearchService.pickLocale('ja', null, const []), isNull);
    });
  });

  test('error codes map to what the user can do about them', () {
    expect(VoiceSearchService.errorFromCode('error_no_match'), VoiceError.noMatch);
    expect(VoiceSearchService.errorFromCode('error_speech_timeout'),
        VoiceError.noMatch);
    expect(VoiceSearchService.errorFromCode('error_network'), VoiceError.network);
    expect(VoiceSearchService.errorFromCode('error_permission'),
        VoiceError.permission);
    expect(VoiceSearchService.errorFromCode('error_language_unavailable'),
        VoiceError.language);
    expect(VoiceSearchService.errorFromCode('error_busy'), VoiceError.busy);
    expect(VoiceSearchService.errorFromCode('error_client'), VoiceError.other);
  });
}
