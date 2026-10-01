/// Il periodo approssimativo di un'idea (02-il-viaggio.md, regole 1 e 5).
///
/// Si sceglie fra mesi e stagioni invece di scriverlo a mano: così l'app sa
/// quando è passato, e può mandare l'idea in archivio senza indovinare
/// (decisioni/prodotto.md, "Il periodo si sceglie"). Sul server resta testo,
/// nella forma in cui si legge: `agosto 2027`, `estate 2027`, `inverno 2027–28`.
/// Un testo che l'app non riconosce vale come nessun periodo indicato.
library;

import 'calendario.dart';

/// Le stagioni meteorologiche: tre mesi interi ciascuna, così un periodo
/// comincia e finisce sempre col mese. L'inverno comincia a dicembre e
/// prende il nome da due anni.
enum Stagione {
  primavera(3),
  estate(6),
  autunno(9),
  inverno(12);

  const Stagione(this.primoMese);

  final int primoMese;

  /// La stagione di una data, con l'anno in cui comincia: il 10 gennaio 2027
  /// è nell'inverno cominciato a dicembre 2026.
  static StagioneDi di(DateTime d) => switch (d.month) {
    3 || 4 || 5 => StagioneDi(d.year, primavera),
    6 || 7 || 8 => StagioneDi(d.year, estate),
    9 || 10 || 11 => StagioneDi(d.year, autunno),
    12 => StagioneDi(d.year, inverno),
    _ => StagioneDi(d.year - 1, inverno),
  };
}

sealed class Periodo {
  const Periodo();

  DateTime get primoGiorno;
  DateTime get ultimoGiorno;

  /// Come si scrive sul server, ed è anche come si legge.
  String get testo;

  /// Il periodo scritto in [testo], se l'app lo riconosce.
  static Periodo? leggi(String? testo) {
    final t = testo?.trim().toLowerCase();
    if (t == null || t.isEmpty) return null;

    final mese = RegExp(r'^([a-z]+) (\d{4})$').firstMatch(t);
    if (mese != null) {
      final indice = nomiDeiMesi.indexOf(mese[1]!);
      if (indice >= 0) return MeseDi(int.parse(mese[2]!), indice + 1);
      final stagione = Stagione.values
          .where((s) => s.name == mese[1] && s != Stagione.inverno)
          .firstOrNull;
      if (stagione != null) return StagioneDi(int.parse(mese[2]!), stagione);
    }

    final inverno = RegExp(r'^inverno (\d{4})[-–](\d{2})$').firstMatch(t);
    if (inverno != null) {
      final anno = int.parse(inverno[1]!);
      if ((anno + 1) % 100 == int.parse(inverno[2]!)) {
        return StagioneDi(anno, Stagione.inverno);
      }
    }
    return null;
  }

  /// I periodi che si propongono a partire da [oggi]: il mese in corso e gli
  /// undici dopo, la stagione in corso e le tre dopo.
  static List<MeseDi> mesiDa(DateTime oggi, {int quanti = 12}) => [
    for (var i = 0; i < quanti; i++)
      MeseDi.di(aggiungiMesi(DateTime.utc(oggi.year, oggi.month), i)),
  ];

  static List<StagioneDi> stagioniDa(DateTime oggi, {int quante = 4}) {
    final prima = Stagione.di(oggi);
    return [
      for (var i = 0; i < quante; i++)
        Stagione.di(aggiungiMesi(prima.primoGiorno, 3 * i)),
    ];
  }
}

final class MeseDi extends Periodo {
  const MeseDi(this.anno, this.mese);

  /// Il mese di una data.
  MeseDi.di(DateTime d) : this(d.year, d.month);

  final int anno;

  /// Da 1 a 12.
  final int mese;

  @override
  DateTime get primoGiorno => DateTime.utc(anno, mese);

  @override
  DateTime get ultimoGiorno => DateTime.utc(anno, mese + 1, 0);

  @override
  String get testo => '${nomiDeiMesi[mese - 1]} $anno';

  @override
  bool operator ==(Object other) =>
      other is MeseDi && other.anno == anno && other.mese == mese;

  @override
  int get hashCode => Object.hash(anno, mese);

  @override
  String toString() => testo;
}

final class StagioneDi extends Periodo {
  const StagioneDi(this.anno, this.stagione);

  /// L'anno in cui la stagione comincia.
  final int anno;
  final Stagione stagione;

  @override
  DateTime get primoGiorno => DateTime.utc(anno, stagione.primoMese);

  @override
  DateTime get ultimoGiorno => DateTime.utc(anno, stagione.primoMese + 3, 0);

  @override
  String get testo => stagione == Stagione.inverno
      ? 'inverno $anno–${((anno + 1) % 100).toString().padLeft(2, '0')}'
      : '${stagione.name} $anno';

  @override
  bool operator ==(Object other) =>
      other is StagioneDi && other.anno == anno && other.stagione == stagione;

  @override
  int get hashCode => Object.hash(anno, stagione);

  @override
  String toString() => testo;
}
