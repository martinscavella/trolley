/// Le spese (06-spese.md): quando si registrano, come si raggruppano, quanto
/// fanno in tutto.
///
/// Il totale si fa nella valuta della persona con l'ultimo tasso noto, e
/// quello che non si può convertire resta a parte nella sua valuta: sommare
/// dirham e euro senza un tasso sarebbe inventarlo (06, casi limite).
library;

import 'calendario.dart';
import 'stato_viaggio.dart';
import 'valute.dart';

/// Le spese esistono solo da quando il viaggio ha le date (06, regola 1).
bool speseAmmesse(StatoViaggio stato) => stato.haGiorni;

/// Quanto può essere lunga la descrizione di una spesa.
const lunghezzaMassimaDescrizione = 80;

/// Una spesa, quanto serve per raggrupparla e sommarla.
class VoceSpesa<T> {
  const VoceSpesa({
    required this.spesa,
    required this.centesimi,
    required this.valuta,
    required this.data,
    required this.creataIl,
  });

  final T spesa;
  final int centesimi;
  final String valuta;
  final DateTime data;
  final DateTime creataIl;
}

/// Dove sta un gruppo nell'elenco.
enum TipoGruppoSpese {
  /// Dopo la fine del viaggio: in cima, è il più recente.
  dopo,

  /// Un giorno, dentro le date o in mezzo.
  giorno,

  /// Prima di partire: il volo, l'acconto. In fondo, tutte insieme.
  prima,
}

class GruppoSpese<T> {
  const GruppoSpese(this.tipo, this.data, this.spese);

  final TipoGruppoSpese tipo;

  /// Il giorno, per [TipoGruppoSpese.giorno].
  final DateTime? data;
  final List<VoceSpesa<T>> spese;
}

/// Le spese in gruppi, dalla più recente: i giorni uno per uno, prima e dopo
/// il viaggio tutte insieme. Dentro un gruppo, l'ultima registrata in cima.
List<GruppoSpese<T>> raggruppaSpese<T>(
  List<VoceSpesa<T>> spese, {
  required DateTime? inizio,
  required DateTime? fine,
}) {
  final primo = inizio == null ? null : soloData(inizio);
  final ultimo = fine == null ? null : soloData(fine);
  final dopo = <VoceSpesa<T>>[];
  final prima = <VoceSpesa<T>>[];
  final perGiorno = <DateTime, List<VoceSpesa<T>>>{};
  for (final s in spese) {
    final d = soloData(s.data);
    if (ultimo != null && d.isAfter(ultimo)) {
      dopo.add(s);
    } else if (primo != null && d.isBefore(primo)) {
      prima.add(s);
    } else {
      perGiorno.putIfAbsent(d, () => []).add(s);
    }
  }
  int recenti(VoceSpesa<T> a, VoceSpesa<T> b) {
    final perData = b.data.compareTo(a.data);
    return perData != 0 ? perData : b.creataIl.compareTo(a.creataIl);
  }

  final giorni = perGiorno.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    if (dopo.isNotEmpty)
      GruppoSpese(TipoGruppoSpese.dopo, null, dopo..sort(recenti)),
    for (final g in giorni)
      GruppoSpese(TipoGruppoSpese.giorno, g, perGiorno[g]!..sort(recenti)),
    if (prima.isNotEmpty)
      GruppoSpese(TipoGruppoSpese.prima, null, prima..sort(recenti)),
  ];
}

/// Il totale di un insieme di spese nella valuta della persona.
class Totale {
  const Totale({required this.centesimi, required this.nonConvertite});

  /// Quello che si è potuto convertire, nella valuta della persona.
  final int centesimi;

  /// Per valuta, quello che non si è potuto convertire perché il tasso non
  /// c'è. Vuoto quasi sempre.
  final Map<String, int> nonConvertite;

  bool get completo => nonConvertite.isEmpty;
}

Totale totaleSpese(
  Iterable<VoceSpesa<Object?>> spese, {
  required String mia,
  required Map<String, double> perEuro,
}) {
  var centesimi = 0;
  final nonConvertite = <String, int>{};
  for (final s in spese) {
    final convertita = converti(
      s.centesimi,
      da: s.valuta,
      a: mia,
      perEuro: perEuro,
    );
    if (convertita == null) {
      nonConvertite.update(
        s.valuta,
        (n) => n + s.centesimi,
        ifAbsent: () => s.centesimi,
      );
    } else {
      centesimi += convertita;
    }
  }
  return Totale(centesimi: centesimi, nonConvertite: nonConvertite);
}

/// Le valute da proporre registrando una spesa, senza aprire l'elenco: la
/// propria, quella del posto, e quelle già usate nel viaggio, la più recente
/// prima. Al massimo [quante].
List<String> valuteProposte({
  required String mia,
  required String? delPosto,
  required Iterable<String> usate,
  int quante = 4,
}) {
  final proposte = <String>[mia];
  if (delPosto != null && !proposte.contains(delPosto)) proposte.add(delPosto);
  for (final v in usate) {
    if (proposte.length >= quante) break;
    if (!proposte.contains(v)) proposte.add(v);
  }
  return proposte;
}
