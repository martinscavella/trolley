import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/documenti.dart';

/// Un documento come lo vede la regola dell'ordine.
typedef _Doc = ({String nome, String? giorno, Duration? ora, int creato});

void main() {
  group('formato', () {
    test('un PDF e le immagini si riconoscono dall\'estensione', () {
      expect(formatoDi('Carta imbarco.PDF'), FormatoDocumento.pdf);
      expect(formatoDi('IMG_1234.HEIC'), FormatoDocumento.immagine);
      expect(formatoDi('biglietto.jpeg'), FormatoDocumento.immagine);
      expect(formatoDi('screenshot.png'), FormatoDocumento.immagine);
    });

    test('il resto non si aggiunge', () {
      expect(formatoDi('prenotazione.docx'), isNull);
      expect(formatoDi('senza-estensione'), isNull);
      expect(formatoDi('archivio.pdf.zip'), isNull);
    });
  });

  group('nome proposto', () {
    test('dal nome del file, leggibile', () {
      expect(nomeProposto('carta_imbarco-MXP.pdf'), 'Carta imbarco MXP');
      expect(nomeProposto('Prenotazione hotel.pdf'), 'Prenotazione hotel');
    });

    test('i nomi di macchina non si propongono', () {
      expect(nomeProposto('IMG_1234.HEIC'), isNull);
      expect(nomeProposto('DOCUMENT_SCAN_20261003-101500.pdf'), isNull);
      expect(nomeProposto('3F2504E0-4F89-11D3-9A0C-0305E82C3301.jpeg'), isNull);
      expect(nomeProposto('.pdf'), isNull);
      expect(nomeProposto(null), isNull);
    });

    test('un nome lunghissimo si accorcia', () {
      final lungo = '${'a' * 100}.pdf';
      expect(nomeProposto(lungo)!.length, lunghezzaMassimaNome);
    });
  });

  group('l\'ordine dell\'elenco', () {
    final giorni = {
      'g10': DateTime.utc(2026, 10, 10),
      'g11': DateTime.utc(2026, 10, 11),
      'g12': DateTime.utc(2026, 10, 12),
      'g13': DateTime.utc(2026, 10, 13),
    };

    List<GruppoDocumenti<_Doc>> ordina(List<_Doc> documenti, DateTime oggi) =>
        raggruppaDocumenti<_Doc>(
          documenti: documenti,
          giornoDi: (d) => d.giorno,
          oraDi: (d) => d.ora,
          creatoDi: (d) => DateTime.utc(2026, 9, 1, 0, d.creato),
          giorni: giorni,
          oggi: oggi,
        );

    List<String> nomi(List<GruppoDocumenti<_Doc>> gruppi) => [
      for (final g in gruppi)
        '${g.tipo.name}: ${g.documenti.map((d) => d.nome).join(', ')}',
    ];

    final documenti = <_Doc>[
      (nome: 'Ritorno', giorno: 'g13', ora: const Duration(hours: 18), creato: 1),
      (nome: 'Passaporto', giorno: null, ora: null, creato: 2),
      (nome: 'Museo', giorno: 'g11', ora: const Duration(hours: 10), creato: 3),
      (nome: 'Hotel', giorno: 'g10', ora: null, creato: 4),
      (nome: 'Imbarco', giorno: 'g10', ora: const Duration(hours: 7), creato: 5),
      (nome: 'Treno', giorno: 'g12', ora: const Duration(hours: 9), creato: 6),
    ];

    test('il primo giorno: oggi, domani, tutto il viaggio, poi gli altri '
        'giorni', () {
      expect(nomi(ordina(documenti, DateTime(2026, 10, 10, 6, 30))), [
        'oggi: Imbarco, Hotel',
        'domani: Museo',
        'tuttoIlViaggio: Passaporto',
        'giorno: Treno',
        'giorno: Ritorno',
      ]);
    });

    test('a metà viaggio i giorni passati vanno in fondo', () {
      expect(nomi(ordina(documenti, DateTime(2026, 10, 12, 8))), [
        'oggi: Treno',
        'domani: Ritorno',
        'tuttoIlViaggio: Passaporto',
        'passato: Imbarco, Hotel',
        'passato: Museo',
      ]);
    });

    test('prima della partenza non ci sono né oggi né domani', () {
      expect(nomi(ordina(documenti, DateTime(2026, 9, 20))), [
        'tuttoIlViaggio: Passaporto',
        'giorno: Imbarco, Hotel',
        'giorno: Museo',
        'giorno: Treno',
        'giorno: Ritorno',
      ]);
    });

    test('la vigilia, il primo giorno è domani', () {
      expect(nomi(ordina(documenti, DateTime(2026, 10, 9, 22))).first,
          'domani: Imbarco, Hotel');
    });

    test('un documento di un giorno che non c\'è più vale per tutto il '
        'viaggio', () {
      final gruppi = ordina([
        (nome: 'Vecchio', giorno: 'g09', ora: const Duration(hours: 8), creato: 1),
      ], DateTime(2026, 10, 10));
      expect(nomi(gruppi), ['tuttoIlViaggio: Vecchio']);
    });

    test('a pari ora, il più vecchio prima', () {
      final gruppi = ordina([
        (nome: 'Secondo', giorno: 'g10', ora: null, creato: 9),
        (nome: 'Primo', giorno: 'g10', ora: null, creato: 1),
      ], DateTime(2026, 10, 10));
      expect(nomi(gruppi), ['oggi: Primo, Secondo']);
    });

    test('nella schermata del viaggio: tutti quelli di oggi', () {
      final tanti = [
        for (var i = 0; i < 5; i++)
          (nome: 'Oggi $i', giorno: 'g10', ora: null, creato: i),
        (nome: 'Passaporto', giorno: null, ora: null, creato: 9),
      ];
      final inVista = documentiDaTenereInVista(
        ordina(tanti, DateTime(2026, 10, 10)),
      );
      expect(inVista.map((d) => d.nome), [
        'Oggi 0',
        'Oggi 1',
        'Oggi 2',
        'Oggi 3',
        'Oggi 4',
      ]);
    });

    test('nella schermata del viaggio, senza documenti di oggi: i primi tre, '
        'senza i giorni passati', () {
      final inVista = documentiDaTenereInVista(
        ordina(documenti, DateTime(2026, 9, 20)),
      );
      expect(inVista.map((d) => d.nome), ['Passaporto', 'Imbarco', 'Hotel']);

      final dopo = documentiDaTenereInVista(
        ordina([
          (nome: 'Passato', giorno: 'g10', ora: null, creato: 1),
        ], DateTime(2026, 10, 12)),
      );
      expect(dopo, isEmpty);
    });
  });
}
