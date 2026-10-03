import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/liste.dart';

VoceDaPortare<String> voce(String id, {bool spuntata = false, int minuto = 0}) =>
    VoceDaPortare(
      voce: id,
      id: id,
      spuntata: spuntata,
      creataIl: DateTime.utc(2026, 10, 3, 9, minuto),
    );

List<String> nomi(List<VoceDaPortare<String>> voci) => [
  for (final v in voci) v.voce,
];

void main() {
  test('nella 1.5 una voce nuova va nella lista personale', () {
    expect(listaDellaFase, TipoLista.personale);
    expect(TipoLista.personale.codice, 'personale');
    expect(TipoLista.viaggio.codice, 'viaggio');
  });

  test('il testo di una voce: senza spazi ai lati, mai vuoto, mai una nota', () {
    expect(testoVoce('  Passaporto '), 'Passaporto');
    expect(testoVoce('   '), isNull);
    expect(testoVoce(''), isNull);
    expect(testoVoce('x' * lunghezzaMassimaVoce), hasLength(200));
    expect(testoVoce('x' * (lunghezzaMassimaVoce + 1)), isNull);
  });

  test('quante: da 1 a 99, come sul server', () {
    expect(quantitaValida(0), 1);
    expect(quantitaValida(-3), 1);
    expect(quantitaValida(5), 5);
    expect(quantitaValida(120), 99);
  });

  test('prima quello che manca, poi quello in valigia, ciascuno nell\'ordine '
      'in cui è nato', () {
    final lista = ordinaVoci([
      voce('felpa', spuntata: true, minuto: 1),
      voce('caricabatterie', minuto: 4),
      voce('passaporto', minuto: 0),
      voce('spazzolino', spuntata: true, minuto: 3),
      voce('adattatore', minuto: 2),
    ]);
    expect(nomi(lista.daMettere), ['passaporto', 'adattatore', 'caricabatterie']);
    expect(nomi(lista.inValigia), ['felpa', 'spazzolino']);
    expect(lista.tutte, 5);
    expect(lista.fatte, 2);
    expect(lista.valigiaFatta, isFalse);
    expect(lista.prossima?.voce, 'passaporto');
  });

  test('una voce appena spuntata resta un attimo dov\'era, ma conta già', () {
    final voci = [
      voce('passaporto', spuntata: true, minuto: 0),
      voce('adattatore', minuto: 1),
    ];
    final trattenuta = ordinaVoci(voci, trattenute: {'passaporto'});
    expect(nomi(trattenuta.daMettere), ['passaporto', 'adattatore']);
    expect(trattenuta.inValigia, isEmpty);
    expect(trattenuta.fatte, 1);
    // La prossima è quella che manca davvero.
    expect(trattenuta.prossima?.voce, 'adattatore');

    final dopo = ordinaVoci(voci);
    expect(nomi(dopo.daMettere), ['adattatore']);
    expect(nomi(dopo.inValigia), ['passaporto']);
  });

  test('una voce a cui si toglie la spunta resta un attimo in valigia', () {
    final lista = ordinaVoci([
      voce('felpa', minuto: 0),
      voce('cuffie', spuntata: true, minuto: 1),
    ], trattenute: {'felpa'});
    expect(lista.daMettere, isEmpty);
    expect(nomi(lista.inValigia), ['felpa', 'cuffie']);
    expect(lista.fatte, 1);
  });

  test('tutto in valigia: è il momento del timbro; una lista vuota no', () {
    expect(
      ordinaVoci([
        voce('a', spuntata: true),
        voce('b', spuntata: true, minuto: 1),
      ]).valigiaFatta,
      isTrue,
    );
    expect(ordinaVoci(<VoceDaPortare<String>>[]).valigiaFatta, isFalse);
    expect(ordinaVoci(<VoceDaPortare<String>>[]).prossima, isNull);
  });

  test('due voci nate insieme stanno sempre nello stesso ordine', () {
    final a = ordinaVoci([voce('b'), voce('a')]);
    final b = ordinaVoci([voce('a'), voce('b')]);
    expect(nomi(a.daMettere), ['a', 'b']);
    expect(nomi(b.daMettere), ['a', 'b']);
  });
}
