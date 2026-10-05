import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/stato_viaggio.dart';
import 'package:trolley/dominio/tappe.dart';
import 'package:trolley/dominio/verifica.dart';

void main() {
  TappaDaVerificare tappa(
    String giorno, {
    StatoTappa stato = StatoTappa.completata,
    bool durante = true,
  }) => (giornoId: giorno, stato: stato, duranteIlViaggio: durante);

  group('le tre condizioni (02, regola 7)', () {
    test(
      'una tappa per giorno, sul posto, tutte segnate durante: verificato',
      () {
        final esito = verificaDelViaggio(
          giorni: ['g1', 'g2'],
          tappe: [
            tappa('g1'),
            tappa('g1', stato: StatoTappa.saltata),
            tappa('g2'),
          ],
          sulPosto: true,
        );
        expect(esito.verificato, isTrue);
        expect(esito.mancanti, isEmpty);
      },
    );

    test('un giorno senza tappe', () {
      final esito = verificaDelViaggio(
        giorni: ['g1', 'g2'],
        tappe: [tappa('g1')],
        sulPosto: true,
      );
      expect(esito.mancanti, {CondizioneVerifica.unaTappaPerGiorno});
    });

    test('una tappa non segnata, o segnata dopo la fine, non vale', () {
      expect(
        verificaDelViaggio(
          giorni: ['g1'],
          tappe: [
            tappa('g1'),
            tappa('g1', stato: StatoTappa.daFare),
          ],
          sulPosto: true,
        ).mancanti,
        {CondizioneVerifica.tappeSegnate},
      );
      expect(
        verificaDelViaggio(
          giorni: ['g1'],
          tappe: [tappa('g1', durante: false)],
          sulPosto: true,
        ).mancanti,
        {CondizioneVerifica.tappeSegnate},
      );
    });

    test('mai sul posto: non verificato, a meno della deroga, che però lo '
        'segna', () {
      final senza = verificaDelViaggio(
        giorni: ['g1'],
        tappe: [tappa('g1')],
        sulPosto: false,
      );
      expect(senza.mancanti, {CondizioneVerifica.sulPosto});

      final deroga = verificaDelViaggio(
        giorni: ['g1'],
        tappe: [tappa('g1')],
        sulPosto: false,
        perDeroga: true,
      );
      expect(deroga.verificato, isTrue);
      expect(deroga.perDeroga, isTrue);
    });

    test('le tappe da ricollocare, fuori dai giorni, non contano', () {
      final esito = verificaDelViaggio(
        giorni: ['g1'],
        tappe: [
          tappa('g1'),
          tappa('vecchio', stato: StatoTappa.daFare),
        ],
        sulPosto: true,
      );
      expect(esito.verificato, isTrue);
    });

    test('un viaggio senza tappe manca di tutte e due le condizioni delle '
        'tappe', () {
      expect(
        verificaDelViaggio(giorni: ['g1'], tappe: [], sulPosto: true).mancanti,
        {CondizioneVerifica.unaTappaPerGiorno, CondizioneVerifica.tappeSegnate},
      );
    });

    test('un viaggio importato non è mai verificato', () {
      final esito = verificaDelViaggio(
        giorni: ['g1'],
        tappe: [tappa('g1')],
        sulPosto: true,
        importato: true,
      );
      expect(esito.verificato, isFalse);
    });
  });

  group('sul posto', () {
    const porto = (lat: 41.1496, lon: -8.6110);

    test('nella città, fino a 50 km dal centro', () {
      expect(
        sulPostoDellaMeta(
          // Matosinhos, l'aeroporto di Porto.
          qui: (lat: 41.2481, lon: -8.6814),
          citta: porto,
          paeseMeta: 'PT',
          paeseQui: 'PT',
        ),
        isTrue,
      );
      expect(
        sulPostoDellaMeta(
          // Lisbona: lo stesso paese, ma non la città del viaggio.
          qui: (lat: 38.7223, lon: -9.1393),
          citta: porto,
          paeseMeta: 'PT',
          paeseQui: 'PT',
        ),
        isFalse,
      );
    });

    test('per un paese intero, o una città che l\'elenco non conosce, basta '
        'il paese', () {
      expect(
        sulPostoDellaMeta(
          qui: (lat: 38.7223, lon: -9.1393),
          citta: null,
          paeseMeta: 'pt',
          paeseQui: 'PT',
        ),
        isTrue,
      );
      expect(
        sulPostoDellaMeta(
          qui: (lat: 40.4168, lon: -3.7038),
          citta: null,
          paeseMeta: 'PT',
          paeseQui: 'ES',
        ),
        isFalse,
      );
      expect(
        sulPostoDellaMeta(
          qui: porto,
          citta: null,
          paeseMeta: null,
          paeseQui: 'PT',
        ),
        isFalse,
      );
    });

    test('si guarda solo mentre il viaggio è in corso, e finché non si è '
        'stati sul posto', () {
      expect(
        siGuardaIlPosto(
          stato: StatoViaggio.inCorso,
          importato: false,
          giaSulPosto: false,
        ),
        isTrue,
      );
      expect(
        siGuardaIlPosto(
          stato: StatoViaggio.inCorso,
          importato: false,
          giaSulPosto: true,
        ),
        isFalse,
      );
      for (final stato in [StatoViaggio.definito, StatoViaggio.chiuso]) {
        expect(
          siGuardaIlPosto(stato: stato, importato: false, giaSulPosto: false),
          isFalse,
        );
      }
      expect(
        siGuardaIlPosto(
          stato: StatoViaggio.inCorso,
          importato: true,
          giaSulPosto: false,
        ),
        isFalse,
      );
    });
  });
}
