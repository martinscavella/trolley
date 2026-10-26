/// Il budget (06-spese.md, regole 12–17): quanto si pensava di spendere, e a
/// che punto si è. Il viaggio si confronta con il totale delle spese,
/// ciascuno con la propria parte; i rimborsi non contano. Le regole stanno
/// qui, in un posto solo.
library;

import 'calendario.dart';

/// Un budget: un importo in centesimi, in una valuta.
class Budget {
  const Budget(this.centesimi, this.valuta);

  final int centesimi;
  final String valuta;

  /// Come lo tiene il telefono: «30000 EUR». `null` se non è un budget.
  static Budget? leggi(String? testo) {
    final parti = testo?.split(' ');
    if (parti == null || parti.length != 2) return null;
    final centesimi = int.tryParse(parti[0]);
    if (centesimi == null || centesimi <= 0) return null;
    return Budget(centesimi, parti[1]);
  }

  String get scritto => '$centesimi $valuta';

  @override
  bool operator ==(Object other) =>
      other is Budget && other.centesimi == centesimi && other.valuta == valuta;

  @override
  int get hashCode => Object.hash(centesimi, valuta);
}

/// Una spesa per il budget: il giorno, e quanto vale nella valuta della
/// persona (già convertita).
typedef SpesaPerBudget = ({DateTime data, int centesimi});

/// Dove si è rispetto ai giorni del viaggio.
enum FaseBudget { prima, durante, dopo }

/// Una colonna del budget: un giorno del viaggio, o tutte le spese di prima
/// di partire (`data` vuota) — il volo, l'acconto.
typedef ColonnaBudget = ({DateTime? data, int speso, bool futura});

class AndamentoBudget {
  const AndamentoBudget({
    required this.budget,
    required this.speso,
    required this.fase,
    required this.quotaDelGiorno,
    required this.ritmo,
    required this.giorniRestanti,
    required this.colonne,
  });

  /// Il budget e quanto si è speso, nella valuta della persona.
  final int budget;
  final int speso;
  final FaseBudget fase;

  /// Il budget diviso per i giorni del viaggio.
  final int quotaDelGiorno;

  /// Dove si dovrebbe essere oggi: la quota per i giorni già cominciati, più
  /// le spese di prima di partire, che contano tutte subito.
  final int ritmo;

  /// I giorni che restano, oggi compreso.
  final int giorniRestanti;
  final List<ColonnaBudget> colonne;

  int get restano => budget - speso;
  bool get oltre => speso > budget;

  /// Di quanto si è sopra (positivo) o sotto (negativo) il ritmo.
  int get rispettoAlRitmo => speso - ritmo;

  /// Quanto si può spendere al giorno, per i giorni che restano. `null`
  /// quando non ne restano, o il budget è già finito.
  int? get alGiorno =>
      giorniRestanti == 0 || restano <= 0 ? null : restano ~/ giorniRestanti;

  /// Quanto è speso, da 0 in su: 1 è tutto il budget.
  double get pieno => budget == 0 ? 0 : speso / budget;

  /// Dove sta la tacca di oggi, da 0 a 1.
  double get tacca => budget == 0 ? 0 : (ritmo / budget).clamp(0.0, 1.0);
}

AndamentoBudget andamentoBudget({
  required int budget,
  required Iterable<SpesaPerBudget> spese,
  required DateTime inizio,
  required DateTime fine,
  required DateTime oggi,
}) {
  final primo = soloData(inizio);
  final ultimo = soloData(fine);
  final giorno = soloData(oggi);
  final giorni = giorniDiCalendario(primo, ultimo);
  final fase = giorno.isBefore(primo)
      ? FaseBudget.prima
      : giorno.isAfter(ultimo)
      ? FaseBudget.dopo
      : FaseBudget.durante;
  final cominciati = switch (fase) {
    FaseBudget.prima => 0,
    FaseBudget.dopo => giorni,
    FaseBudget.durante => giorno.difference(primo).inDays + 1,
  };
  final quota = budget ~/ giorni;
  var prima = 0;
  var speso = 0;
  final perGiorno = <DateTime, int>{};
  for (final s in spese) {
    speso += s.centesimi;
    final d = soloData(s.data);
    if (d.isBefore(primo)) {
      prima += s.centesimi;
    } else {
      // Dopo la fine, con l'ultimo giorno: il conto del ristorante pagato a
      // mezzanotte passata è del viaggio.
      final dove = d.isAfter(ultimo) ? ultimo : d;
      perGiorno.update(
        dove,
        (n) => n + s.centesimi,
        ifAbsent: () => s.centesimi,
      );
    }
  }
  return AndamentoBudget(
    budget: budget,
    speso: speso,
    fase: fase,
    quotaDelGiorno: quota,
    ritmo: prima + quota * cominciati,
    giorniRestanti:
        giorni - (fase == FaseBudget.durante ? cominciati - 1 : cominciati),
    colonne: [
      if (prima > 0) (data: null, speso: prima, futura: false),
      for (var i = 0; i < giorni; i++)
        () {
          final d = DateTime.utc(primo.year, primo.month, primo.day + i);
          return (data: d, speso: perGiorno[d] ?? 0, futura: d.isAfter(giorno));
        }(),
    ],
  );
}
