import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/conflitti.dart';

void main() {
  const base = {
    'titolo': 'Torre',
    'ora_inizio': '11:00:00',
    campoEliminato: false,
  };

  group('confronta', () {
    test(
      'se l\'altro ha scritto la stessa cosa, non c\'è niente da scegliere',
      () {
        final mia = {...base, 'ora_inizio': '11:30:00'};
        expect(
          confronta(base: base, mia: mia, loro: mia),
          EsitoConfronto.uguali,
        );
      },
    );

    test('se l\'altro non ha toccato quello che si cambia qui, si riscrive '
        'senza chiedere', () {
      // Ha segnato la tappa: lo stato non sta nel ritratto.
      expect(
        confronta(
          base: base,
          mia: {...base, 'titolo': 'Torre dos Clérigos'},
          loro: base,
        ),
        EsitoConfronto.nienteInComune,
      );
    });

    test('se l\'altro ha cambiato lo stesso campo, due versioni', () {
      expect(
        confronta(
          base: base,
          mia: {...base, 'ora_inizio': '11:30:00'},
          loro: {...base, 'ora_inizio': '12:00:00'},
        ),
        EsitoConfronto.dueVersioni,
      );
    });

    test('anche su campi diversi: unirli darebbe una versione che nessuno ha '
        'visto', () {
      expect(
        confronta(
          base: base,
          mia: {...base, 'titolo': 'Torre dos Clérigos'},
          loro: {...base, 'ora_inizio': '12:00:00'},
        ),
        EsitoConfronto.dueVersioni,
      );
    });

    test('tolta dall\'altro mentre la si cambiava: due versioni', () {
      expect(
        confronta(
          base: base,
          mia: {...base, 'titolo': 'Torre dos Clérigos'},
          loro: {...base, campoEliminato: true},
        ),
        EsitoConfronto.dueVersioni,
      );
    });

    test(
      'togliendola, se l\'altro l\'aveva solo segnata si toglie lo stesso',
      () {
        expect(
          confronta(
            base: base,
            mia: {...base, campoEliminato: true},
            loro: base,
          ),
          EsitoConfronto.nienteInComune,
        );
      },
    );

    test('togliendola, se l\'altro l\'aveva cambiata si guarda prima', () {
      expect(
        confronta(
          base: base,
          mia: {...base, campoEliminato: true},
          loro: {...base, 'titolo': 'Torre e chiesa'},
        ),
        EsitoConfronto.dueVersioni,
      );
    });

    test('tolta da tutti e due: è tolta', () {
      expect(
        confronta(
          base: base,
          mia: {...base, campoEliminato: true},
          loro: {...base, 'titolo': 'Altro', campoEliminato: true},
        ),
        EsitoConfronto.uguali,
      );
    });
  });

  test('i campi diversi, e solo quelli', () {
    expect(
      campiDiversi(base, {
        ...base,
        'ora_inizio': '12:00:00',
        campoEliminato: true,
      }),
      {'ora_inizio', campoEliminato},
    );
    expect(campiDiversi(base, base), isEmpty);
  });

  test('convivono solo due voci, e solo se nessuna è tolta', () {
    expect(convivono(divisibile: true, mia: base, loro: base), isTrue);
    expect(convivono(divisibile: false, mia: base, loro: base), isFalse);
    expect(
      convivono(
        divisibile: true,
        mia: base,
        loro: {...base, campoEliminato: true},
      ),
      isFalse,
    );
  });
}
