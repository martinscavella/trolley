import 'package:flutter_test/flutter_test.dart';
import 'package:trolley/dominio/adesso.dart';

/// Una tappa come la guarda «adesso».
typedef _Tappa = ({String nome, Duration? ora, int minuti, bool fatta});

_Tappa _t(String nome, int minuti, {Duration? ora, bool fatta = false}) =>
    (nome: nome, ora: ora, minuti: minuti, fatta: fatta);

/// Un documento come lo guarda «adesso».
typedef _Doc = ({String nome, Duration? ora});

Duration _alle(int ore, [int minuti = 0]) =>
    Duration(hours: ore, minutes: minuti);

Adesso<_Tappa> _adesso(
  List<_Tappa> tappe,
  Duration adesso, {
  Duration inizio = const Duration(hours: 9),
}) => cosaSuccedeAdesso<_Tappa>(
  tappe: tappe,
  oraDi: (t) => t.ora,
  durataDi: (t) => Duration(minutes: t.minuti),
  daFare: (t) => !t.fatta,
  inizioGiornata: inizio,
  adesso: adesso,
);

void main() {
  group('orari della giornata', () {
    test('le tappe senza ora si mettono una dopo l\'altra', () {
      final orari = orariDellaGiornata(
        inizioGiornata: _alle(10),
        tappe: [
          (ora: null, durata: _alle(1)),
          (ora: null, durata: _alle(1, 30)),
        ],
      );
      expect(orari, [
        (inizio: _alle(10), fine: _alle(11)),
        (inizio: _alle(11), fine: _alle(12, 30)),
      ]);
    });

    test('una tappa con l\'ora la tiene, e le altre vengono dopo di lei', () {
      final orari = orariDellaGiornata(
        inizioGiornata: _alle(9),
        tappe: [
          (ora: null, durata: _alle(1)),
          (ora: _alle(12), durata: _alle(1, 30)),
          (ora: null, durata: _alle(0, 30)),
        ],
      );
      expect(orari[1], (inizio: _alle(12), fine: _alle(13, 30)));
      expect(orari[2], (inizio: _alle(13, 30), fine: _alle(14)));
    });
  });

  group('cosa succede adesso', () {
    final giornata = [
      _t('Duomo', 60, fatta: true),
      _t('Livraria Lello', 60, ora: _alle(10, 30)),
      _t('Torre dos Clérigos', 90, ora: _alle(12)),
      _t('Cena', 90),
    ];

    test('la tappa di adesso è la prima da fare, e dopo viene la seguente', () {
      final a = _adesso(giornata, _alle(11, 5));
      expect(a.corrente?.tappa.nome, 'Livraria Lello');
      expect(a.corrente?.orario, (inizio: _alle(10, 30), fine: _alle(11, 30)));
      expect(a.puntualita, Puntualita.inCorso);
      expect(a.dopo?.tappa.nome, 'Torre dos Clérigos');
      expect(a.traQuanto, const Duration(minutes: 55));
      expect(a.restano, 3);
      expect(a.finoAlle, _alle(15));
      expect(a.libera, isFalse);
      expect(a.finita, isFalse);
    });

    test('prima del suo orario la tappa è in arrivo', () {
      expect(_adesso(giornata, _alle(10)).puntualita, Puntualita.inArrivo);
    });

    test('se il programma è indietro non si riorganizza niente: si dice cosa '
        'resta', () {
      final a = _adesso(giornata, _alle(12, 10));
      expect(a.corrente?.tappa.nome, 'Livraria Lello');
      expect(a.puntualita, Puntualita.indietro);
      // La torre doveva cominciare alle 12: non si dice «fra» un tempo passato.
      expect(a.traQuanto, isNull);
      expect(a.restano, 3);
      expect(a.finoAlle, _alle(15));
    });

    test('una tappa saltata o fatta non è più quella di adesso', () {
      final a = _adesso([
        _t('Duomo', 60, fatta: true),
        _t('Lello', 60, fatta: true),
        _t('Cena', 90),
      ], _alle(19));
      expect(a.corrente?.tappa.nome, 'Cena');
      expect(a.dopo, isNull);
      expect(a.traQuanto, isNull);
      expect(a.restano, 1);
    });

    test('una giornata senza tappe è libera', () {
      final a = _adesso(const [], _alle(11));
      expect(a.libera, isTrue);
      expect(a.finita, isFalse);
      expect(a.corrente, isNull);
    });

    test('una giornata con tutte le tappe segnate è finita', () {
      final a = _adesso([_t('Duomo', 60, fatta: true)], _alle(11));
      expect(a.finita, isTrue);
      expect(a.libera, isFalse);
      expect(a.restano, 0);
    });
  });

  group('il documento di adesso', () {
    _Doc? di(List<_Doc> oggi, Duration adesso) => documentoDiAdesso<_Doc>(
      diOggi: oggi,
      oraDi: (d) => d.ora,
      adesso: adesso,
    );

    final oggi = <_Doc>[
      (nome: 'Carta d\'imbarco', ora: _alle(7, 5)),
      (nome: 'Biglietto Lello', ora: _alle(10, 30)),
      (nome: 'Assicurazione', ora: null),
    ];

    test('è il primo con l\'ora che non è passata da più di un\'ora', () {
      expect(di(oggi, _alle(6))?.nome, 'Carta d\'imbarco');
      expect(di(oggi, _alle(8))?.nome, 'Carta d\'imbarco');
      expect(di(oggi, _alle(8, 6))?.nome, 'Biglietto Lello');
    });

    test('passati quelli con l\'ora, resta quello di oggi senza ora', () {
      expect(di(oggi, _alle(15))?.nome, 'Assicurazione');
    });

    test('senza documenti di oggi, o tutti passati, niente', () {
      expect(di(const [], _alle(10)), isNull);
      expect(di([(nome: 'Treno', ora: _alle(7))], _alle(12)), isNull);
    });
  });

  group('quale viaggio apre adesso', () {
    test('l\'unico in corso', () {
      expect(viaggioDiAdesso(inCorso: ['a'], sceltoOggi: null), 'a');
      expect(viaggioDiAdesso(inCorso: ['a'], sceltoOggi: 'b'), 'a');
    });

    test('con due, quello scelto oggi; se no si chiede', () {
      expect(viaggioDiAdesso(inCorso: ['a', 'b'], sceltoOggi: 'b'), 'b');
      expect(viaggioDiAdesso(inCorso: ['a', 'b'], sceltoOggi: null), isNull);
      expect(viaggioDiAdesso(inCorso: ['a', 'b'], sceltoOggi: 'c'), isNull);
    });

    test('nessuno in corso, niente', () {
      expect(viaggioDiAdesso(inCorso: const [], sceltoOggi: 'a'), isNull);
    });
  });
}
