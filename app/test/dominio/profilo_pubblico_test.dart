import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/itinerario.dart';
import 'package:trolley/dominio/profilo_pubblico.dart';

/// Il profilo pubblico e la ricerca (5.3): i gusti come li vuole il server, i
/// viaggi in ordine, che cosa si ha in comune, che cosa si cerca.
void main() {
  Map<String, Object?> viaggio(
    String citta,
    String paese, {
    String? mese,
    String? periodo,
    int? giorni,
    bool verificato = false,
    bool importato = false,
  }) => {
    'citta': citta,
    'paese': paese,
    'mese': mese,
    'periodo': periodo,
    'giorni': giorni,
    'verificato': verificato,
    'importato': importato,
  };

  ProfiloPubblico teresa({
    List<String> gusti = const ['cibo', 'arte'],
    List<Map<String, Object?>>? viaggi,
  }) => ProfiloPubblico.daServer({
    'id': 't',
    'nome': 'Teresa',
    'dal': '2026-03-01',
    'gusti': gusti,
    'traguardi': 5,
    'viaggi':
        viaggi ??
        [
          viaggio('Lisbona', 'PT', mese: '2025-11-01', giorni: 4),
          viaggio(
            'Kyoto',
            'JP',
            mese: '2026-04-01',
            giorni: 9,
            verificato: true,
          ),
          viaggio(
            'Porto',
            'PT',
            periodo: 'agosto 2019',
            giorni: 5,
            importato: true,
          ),
          viaggio('Osaka', 'JP', mese: '2025-02-01', giorni: 3),
        ],
  });

  group('i gusti', () {
    test('si chiamano sul server come nella lista chiusa', () {
      expect(codiceGusto(Interesse.vitaNotturna), 'vita_notturna');
      expect(codiceGusto(Interesse.arte), 'arte');
      expect(gusti, Interesse.values);
    });

    test(
      'dal server, nell\'ordine della lista; un nome sconosciuto si salta',
      () {
        expect(gustiDa(['vita_notturna', 'cibo', 'religione', 'arte']), [
          Interesse.arte,
          Interesse.cibo,
          Interesse.vitaNotturna,
        ]);
        expect(gustiDa(null), isEmpty);
      },
    );

    test('con l\'articolo, dopo «ama»', () {
      expect(gustoConArticolo(Interesse.cibo), 'il cibo');
      expect(gustoConArticolo(Interesse.arte), 'l\'arte e i musei');
      expect(gustoConArticolo(Interesse.shopping), 'lo shopping');
    });
  });

  group('i viaggi sul profilo', () {
    test('dal più recente; un importato si mette al suo periodo', () {
      expect(
        [for (final v in teresa().viaggi) v.citta],
        ['Kyoto', 'Lisbona', 'Osaka', 'Porto'],
      );
    });

    test('di ciascuno la meta, il mese, i giorni; le date non ci sono', () {
      final kyoto = teresa().viaggi.first;
      expect(kyoto.mese, DateTime(2026, 4));
      expect(kyoto.giorni, 9);
      expect(kyoto.verificato, isTrue);
      expect(kyoto.sulProfilo, isTrue);
      final porto = teresa().viaggi.last;
      expect(porto.importato, isTrue);
      expect(porto.mese, isNull);
      expect(porto.periodo, 'agosto 2019');
    });

    test('i paesi una volta ciascuno', () {
      expect(teresa().paesi, ['JP', 'PT']);
    });

    test('il proprio profilo porta anche le scelte', () {
      final mio = ProfiloPubblico.daServer({
        'id': 'g',
        'nome': 'Giulia',
        'gusti': <String>[],
        'traguardi': 0,
        'viaggi': <Object>[],
        'attivo': false,
        'tutti_i_viaggi': [
          {
            ...viaggio('Atene', 'GR', mese: '2026-02-01', giorni: 3),
            'viaggio_id': 'a',
            'sul_profilo': false,
          },
        ],
      });
      expect(mio.attivo, isFalse);
      expect(mio.tuttiIViaggi.single.viaggioId, 'a');
      expect(mio.tuttiIViaggi.single.sulProfilo, isFalse);
      expect(mio.tuttiIViaggi.single.conSulProfilo(true).sulProfilo, isTrue);
    });
  });

  group('cosa avete in comune', () {
    test('i paesi visti da tutti e due e i gusti di tutti e due', () {
      final c = inComune(
        mieMete: [
          (citta: 'Tokyo', paese: 'JP'),
          (citta: 'Madrid', paese: 'ES'),
          (citta: 'Faro', paese: 'PT'),
        ],
        mieiGusti: {Interesse.cibo, Interesse.natura},
        altro: teresa(),
      );
      expect(c.paesi, ['JP', 'PT']);
      expect(c.gusti, [Interesse.cibo]);
      expect(quantiInComune(c), 3);
    });

    test('dell\'altro contano solo i viaggi sul suo profilo', () {
      final c = inComune(
        mieMete: [(citta: 'Atene', paese: 'GR')],
        mieiGusti: const {},
        altro: teresa(),
      );
      expect(quantiInComune(c), 0);
    });
  });

  group('cercare', () {
    test('senza meta né gusti non si cerca', () {
      expect(const Ricerca().vuota, isTrue);
      expect(const Ricerca(gusti: {Interesse.cibo}).vuota, isFalse);
    });

    test('i criteri si dicono senza dire quali', () {
      const meta = Ricerca(paese: 'JP', nomeMeta: 'Giappone');
      expect(meta.criteri, 'meta');
      expect(const Ricerca(gusti: {Interesse.cibo}).criteri, 'gusti');
      expect(meta.conGusti({Interesse.cibo}).criteri, 'entrambi');
      expect(meta.conMeta().vuota, isTrue);
    });

    test(
      'il viaggio nella meta: il più recente nel paese, o in quella città',
      () {
        expect(
          const Ricerca(paese: 'JP').viaggioNellaMeta(teresa())?.citta,
          'Kyoto',
        );
        expect(
          const Ricerca(
            paese: 'JP',
            citta: 'osaka',
          ).viaggioNellaMeta(teresa())?.citta,
          'Osaka',
        );
        expect(const Ricerca(paese: 'GR').viaggioNellaMeta(teresa()), isNull);
        expect(
          const Ricerca(gusti: {Interesse.cibo}).viaggioNellaMeta(teresa()),
          isNull,
        );
      },
    );

    test('i gusti cercati che piacciono anche all\'altro', () {
      const r = Ricerca(gusti: {Interesse.natura, Interesse.cibo});
      expect(r.gustiTrovati(teresa()), [Interesse.cibo]);
    });
  });
}
