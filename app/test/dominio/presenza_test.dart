import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/collegamenti.dart';
import 'package:trolley/dominio/presenza.dart';
import 'package:trolley/dominio/stato_viaggio.dart';

/// Chi c'è in città (5.5): per quale viaggio si accende, quale schermata,
/// che cosa manda il server, e le parole delle date.
void main() {
  test('si accende per un viaggio in corso, non importato, con una città, in '
      'cui si è ancora', () {
    bool possibile({
      StatoViaggio stato = StatoViaggio.inCorso,
      bool importato = false,
      String? citta = 'Porto',
      bool partecipa = true,
    }) => presenzaPossibile(
      stato: stato,
      importato: importato,
      citta: citta,
      partecipa: partecipa,
    );
    expect(possibile(), isTrue);
    expect(possibile(stato: StatoViaggio.definito), isFalse);
    expect(possibile(stato: StatoViaggio.chiuso), isFalse);
    expect(possibile(importato: true), isFalse);
    expect(possibile(citta: null), isFalse);
    expect(possibile(citta: '  '), isFalse);
    expect(possibile(partecipa: false), isFalse);
  });

  test('quale schermata: accesa, poi sul posto, poi senza posizione', () {
    StatoPresenza stato({
      bool accesaQui = false,
      bool sulPosto = false,
      bool posizioneNegata = false,
    }) => statoPresenza(
      accesaQui: accesaQui,
      sulPosto: sulPosto,
      posizioneNegata: posizioneNegata,
    );
    expect(stato(), StatoPresenza.quandoSarai);
    expect(stato(posizioneNegata: true), StatoPresenza.senzaPosizione);
    expect(
      stato(sulPosto: true, posizioneNegata: true),
      StatoPresenza.accendibile,
    );
    expect(stato(accesaQui: true), StatoPresenza.accesa);
  });

  test('chi c\'è: la propria presenza e gli altri, con a che punto siete', () {
    final chi = ChiCeInCitta.daServer({
      'mia': {
        'viaggio_id': 'v',
        'citta': 'Porto',
        'paese': 'PT',
        'fino': '2026-10-18',
      },
      'altri': [
        {
          'id': 'a',
          'nome': 'Andrea',
          'dal': '2026-06-01',
          'gusti': ['cibo'],
          'traguardi': 3,
          'viaggi': <Object?>[],
          'collegamento': {'stato': 'inviata'},
        },
      ],
    });
    expect(chi.mia!.fino, DateTime.utc(2026, 10, 18));
    expect(chi.accesaPer('v'), isTrue);
    expect(chi.accesaPer('altro'), isFalse);
    expect(chi.altri.single.collegamento!.stato, StatoCollegamento.inviata);

    final nessuno = ChiCeInCitta.daServer({'mia': null, 'altri': <Object?>[]});
    expect(nessuno.mia, isNull);
    expect(nessuno.accesaPer('v'), isFalse);
  });

  test('le date: quando si spegne, e fino a quando nell\'interruttore', () {
    final oggi = DateTime(2026, 10, 15, 18);
    expect(fineInParole(DateTime(2026, 10, 15), oggi), 'oggi');
    expect(fineInParole(DateTime(2026, 10, 16), oggi), 'domani');
    expect(fineInParole(DateTime(2026, 10, 18), oggi), 'domenica 18');
    expect(finoA(DateTime(2026, 10, 15), oggi), 'fino a stasera');
    expect(finoA(DateTime(2026, 10, 16), oggi), 'fino a domani');
    expect(finoA(DateTime(2026, 10, 18), oggi), 'fino a domenica');
    expect(oltreATe(1), '1 viaggiatore, oltre a te');
    expect(oltreATe(3), '3 viaggiatori, oltre a te');
  });
}
