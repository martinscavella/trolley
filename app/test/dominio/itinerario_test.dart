import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/giornate.dart';
import 'package:trolley/dominio/itinerario.dart';
import 'package:trolley/dominio/tappe.dart';

FinestraGiorno giorno(int d, {int da = 0, int a = 24}) => FinestraGiorno(
  data: DateTime.utc(2026, 10, d),
  inizio: Duration(hours: da),
  fine: Duration(hours: a),
);

final porto = Richiesta(
  destinazione: 'Porto, Portogallo',
  giorni: [
    GiornoDaChiedere(giorno(10, da: 10)),
    GiornoDaChiedere(
      giorno(11),
      presenti: [
        (titolo: 'Livraria Lello', durata: const Duration(minutes: 90)),
      ],
    ),
    GiornoDaChiedere(giorno(12, a: 18)),
  ],
  ritmo: RitmoDelViaggio.tranquillo,
  interessi: {Interesse.cibo, Interesse.arte},
  altro: '  niente salite ',
);

List<String> titoli(ItinerarioLetto letto) => [
  for (final g in letto.giorni)
    for (final t in g.tappe) t.titolo,
];

void main() {
  group('la richiesta', () {
    final testo = scriviRichiesta(porto);

    test('dice dove, quando e quanto tempo c\'è ogni giorno', () {
      expect(
        testo,
        startsWith(
          'Prepara un itinerario per un viaggio a Porto, Portogallo, dal 10 '
          'ottobre 2026 al 12 ottobre 2026.',
        ),
      );
      expect(
        testo,
        contains(
          '- Giorno 1, sabato 10 ottobre 2026: dalle 10:00, all\'arrivo',
        ),
      );
      expect(
        testo,
        contains('- Giorno 2, domenica 11 ottobre 2026: giornata intera'),
      );
      expect(
        testo,
        contains(
          '- Giorno 3, lunedì 12 ottobre 2026: fino alle 18:00, alla partenza',
        ),
      );
    });

    test('porta le preferenze e quello che c\'è già', () {
      expect(
        testo,
        contains('RitmoDelViaggio: tranquillo: poche tappe al giorno'),
      );
      // Nell'ordine dell'elenco, non in quello in cui si sono toccate.
      expect(testo, contains('Ci piacciono: arte e musei, cibo.'));
      expect(testo, contains('Da tenere presente: niente salite'));
      expect(testo, contains('- Giorno 2: Livraria Lello (90 min)'));
    });

    test(
      'chiede la risposta in un blocco di codice, nel formato che si legge',
      () {
        expect(
          testo,
          contains(
            '```\nTROLLEY ITINERARIO\nDESTINAZIONE: Porto, Portogallo\nGIORNO 1 · 2026-10-10\n',
          ),
        );
        expect(
          testo,
          contains(
            'visita, museo, pasto, passeggiata, spettacolo, escursione, pausa, altro',
          ),
        );
      },
    );

    test('senza preferenze non scrive righe vuote di senso', () {
      final semplice = scriviRichiesta(
        Richiesta(
          destinazione: 'Porto',
          giorni: [GiornoDaChiedere(giorno(10, da: 10, a: 18))],
        ),
      );
      expect(semplice, contains('il 10 ottobre 2026.'));
      expect(semplice, contains('dalle 10:00 alle 18:00'));
      expect(semplice, isNot(contains('Ci piacciono')));
      expect(semplice, isNot(contains('Già in programma')));
    });

    test(
      'incollare per sbaglio la richiesta stessa non aggiunge tappe finte',
      () {
        expect(leggiItinerario(testo).vuoto, isTrue);
      },
    );
  });

  group('la risposta', () {
    test('il formato chiesto, con le chiacchiere intorno', () {
      final letto = leggiItinerario('''
Ecco un itinerario per Porto! Ho cercato di non stancarvi.

```
TROLLEY ITINERARIO
DESTINAZIONE: Porto
GIORNO 1 · 2026-10-10
10:30 | Livraria Lello | visita | 60 | Rua das Carmelitas 144
12:00 | Pranzo al Mercado do Bolhão | pasto | 90 |
GIORNO 2 · 2026-10-11
09:30 | Cattedrale Sé | visita | 60 | Terreiro da Sé
```

Buon viaggio! Se volete posso aggiungere dei ristoranti.
''');
      expect(letto.destinazione, 'Porto');
      expect(letto.giorni, hasLength(2));
      expect(letto.giorni.first.numero, 1);
      expect(letto.giorni.first.data, DateTime.utc(2026, 10, 10));
      expect(titoli(letto), [
        'Livraria Lello',
        'Pranzo al Mercado do Bolhão',
        'Cattedrale Sé',
      ]);
      final lello = letto.giorni.first.tappe.first;
      expect(lello.ora, const Duration(hours: 10, minutes: 30));
      expect(lello.tipo, TipoTappa.visita);
      expect(lello.durata, const Duration(minutes: 60));
      expect(lello.luogo, 'Rua das Carmelitas 144');
      expect(letto.giorni.first.tappe[1].luogo, isNull);
      expect(letto.righeNonCapite, 0);
    });

    test('una tabella in markdown, con grassetti e intestazione', () {
      final letto = leggiItinerario('''
**Giorno 1 – venerdì 10 ottobre**

| Ora | Tappa | Tipo | Durata | Zona |
|-----|-------|------|--------|------|
| 10:30 | **Livraria Lello** | Visit | 1h | Baixa |
| 13.00 | Francesinha al Café Santiago | lunch | 1 h 30 | |
''');
      expect(titoli(letto), ['Livraria Lello', 'Francesinha al Café Santiago']);
      final [lello, pranzo] = letto.giorni.single.tappe;
      expect(lello.durata, const Duration(hours: 1));
      expect(lello.tipo, TipoTappa.visita);
      expect(pranzo.ora, const Duration(hours: 13));
      expect(pranzo.tipo, TipoTappa.pasto);
      expect(pranzo.durata, const Duration(minutes: 90));
      expect(letto.righeNonCapite, 0);
    });

    test('campi mancanti o in un altro ordine: il tipo dal nome, la durata '
        'dal tipo', () {
      final letto = leggiItinerario('''
GIORNO 1
- 10:00 | Pranzo da Gazela
- Museu Serralves | 2 ore | museo
* 16:00 | Passeggiata sulla Ribeira | 45'
''');
      final [gazela, serralves, ribeira] = letto.giorni.single.tappe;
      expect(gazela.tipo, TipoTappa.pasto);
      expect(gazela.durata, TipoTappa.pasto.durataProposta);
      expect(serralves.ora, isNull);
      expect(serralves.tipo, TipoTappa.museo);
      expect(serralves.durata, const Duration(hours: 2));
      expect(ribeira.tipo, TipoTappa.passeggiata);
      expect(ribeira.durata, const Duration(minutes: 45));
    });

    test('le durate scritte in tanti modi', () {
      Duration? durata(String scritta) =>
          leggiItinerario('GIORNO 1\n10:00 | Tappa | altro | $scritta')
              .giorni
              .single
              .tappe
              .single
              .durata;
      expect(durata('90'), const Duration(minutes: 90));
      expect(durata('90 min'), const Duration(minutes: 90));
      expect(durata('1h30'), const Duration(minutes: 90));
      expect(durata('1 h 30 min'), const Duration(minutes: 90));
      expect(durata('1,5 h'), const Duration(minutes: 90));
      expect(durata('1:30'), const Duration(minutes: 90));
      expect(durata('2 ore'), const Duration(hours: 2));
      expect(durata("mezz'ora"), const Duration(minutes: 30));
      // Troppo corta diventa il minimo; assurda non vale, e resta quella del tipo.
      expect(durata('5'), const Duration(minutes: 15));
      expect(durata('900'), TipoTappa.altro.durataProposta);
    });

    test('senza barre: un\'ora, il nome, e fra parentesi il resto', () {
      final letto = leggiItinerario('''
Giorno 1
10:30 Livraria Lello (visita, 60 min)
12:30 – Pranzo al mercato
''');
      final [lello, pranzo] = letto.giorni.single.tappe;
      expect(lello.titolo, 'Livraria Lello');
      expect(lello.durata, const Duration(minutes: 60));
      expect(pranzo.titolo, 'Pranzo al mercato');
      expect(pranzo.tipo, TipoTappa.pasto);
    });

    test('una risposta interrotta a metà blocco si legge fin dove arriva', () {
      final letto = leggiItinerario(
        'Ecco:\n```\nGIORNO 1 · 2026-10-10\n10:30 | Livraria Lello | visita | 60\n11:45 | Torre',
      );
      expect(titoli(letto), ['Livraria Lello', 'Torre']);
    });

    test('le righe che sembrano tappe e non si capiscono si contano', () {
      final letto = leggiItinerario('''
```
GIORNO 1
10:30 | Livraria Lello | visita | 60
| 60 | visita
11:00 |
```
''');
      expect(titoli(letto), ['Livraria Lello']);
      expect(letto.righeNonCapite, 2);
    });

    test('solo parole: nessuna tappa, e nessuna riga contata come tappa', () {
      final letto = leggiItinerario(
        'A Porto vi consiglio di visitare la Livraria Lello e di mangiare '
        'una francesinha. Buon viaggio!',
      );
      expect(letto.vuoto, isTrue);
      expect(letto.righeNonCapite, 0);
    });
  });

  group('dalla risposta al viaggio', () {
    final date = [
      DateTime.utc(2026, 10, 10),
      DateTime.utc(2026, 10, 11),
      DateTime.utc(2026, 10, 12),
    ];

    test('per data se corrisponde, altrimenti per numero; i giorni che il '
        'viaggio non ha si contano', () {
      final letto = leggiItinerario('''
GIORNO 1 · 2026-10-11
10:00 | A | visita | 60
GIORNO 3 · 2025-05-01
10:00 | B | visita | 60
GIORNO 7
10:00 | C | visita | 60
10:00 | D | visita | 60
''');
      final abbinato = abbinaAiGiorni(letto, date);
      expect(abbinato.perGiorno[0], isEmpty);
      expect([for (final t in abbinato.perGiorno[1]) t.titolo], ['A']);
      expect([for (final t in abbinato.perGiorno[2]) t.titolo], ['B']);
      expect(abbinato.fuoriDalViaggio, 2);
    });

    test('una risposta senza giorni va sul primo', () {
      final abbinato = abbinaAiGiorni(
        leggiItinerario('10:00 | A | visita | 60\n12:00 | B | pasto | 60'),
        date,
      );
      expect(abbinato.perGiorno[0], hasLength(2));
      expect(abbinato.fuoriDalViaggio, 0);
    });

    test('si sceglie nell\'ordine finché entra; il resto resta fuori', () {
      expect(
        sceltePerCapienza(
          libero: const Duration(hours: 4),
          durate: const [
            Duration(hours: 1),
            Duration(hours: 2),
            Duration(hours: 2),
            Duration(minutes: 45),
          ],
        ),
        {0, 1, 3},
      );
      expect(
        sceltePerCapienza(
          libero: Duration.zero,
          durate: const [Duration(hours: 1)],
        ),
        isEmpty,
      );
    });

    test('un\'altra destinazione si segnala; senza nome scritto no', () {
      expect(altraDestinazione('Lisbona', ['Porto', 'Portogallo']), isTrue);
      expect(
        altraDestinazione('Porto, Portogallo', ['Porto', 'Portogallo']),
        isFalse,
      );
      expect(altraDestinazione('porto', ['Porto', null]), isFalse);
      expect(altraDestinazione(null, ['Porto']), isFalse);
      expect(altraDestinazione('Lisbona', [null]), isFalse);
    });
  });
}
