import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/chiusura_account.dart';

/// Che cosa succede ai propri viaggi chiudendo l'account (U.1): la regola di
/// chiudi_account, detta prima. Quella del server si prova in
/// supabase/tests/chiusura_account.sql.
void main() {
  Compagno compagno(String id, String nome, String entrato) =>
      (id: id, nome: nome, entrato: DateTime.parse(entrato));

  test('i viaggi in cui si è da soli si cancellano; da quelli con altri si '
      'esce', () {
    final esito = cosaSuccede<String>([
      (viaggio: 'Berlino', responsabile: true, altri: const []),
      (viaggio: 'idea', responsabile: true, altri: const []),
      (
        viaggio: 'Lisbona',
        responsabile: false,
        altri: [compagno('s', 'Sara', '2026-10-01T10:00:00Z')],
      ),
    ]);
    expect(esito.cancellati, ['Berlino', 'idea']);
    expect(esito.lasciati, ['Lisbona']);
    expect(esito.passaggi, isEmpty);
  });

  test('chi era responsabile lascia il ruolo a chi è entrato per primo', () {
    final esito = cosaSuccede<String>([
      (
        viaggio: 'Porto',
        responsabile: true,
        altri: [
          compagno('s', 'Sara', '2026-10-03T10:00:00Z'),
          compagno('m', 'Marco', '2026-10-01T10:00:00Z'),
        ],
      ),
    ]);
    expect(esito.lasciati, ['Porto']);
    expect(esito.passaggi.single.$1, 'Porto');
    expect(esito.passaggi.single.$2.nome, 'Marco');
  });

  test('entrati nello stesso momento, il ruolo va all\'id più piccolo, come '
      'sul server', () {
    final insieme = [
      compagno('b2', 'Bea', '2026-10-01T10:00:00Z'),
      compagno('a7', 'Aldo', '2026-10-01T10:00:00Z'),
    ];
    expect(erede(insieme).nome, 'Aldo');
    expect(erede(insieme.reversed.toList()).nome, 'Aldo');
  });
}
