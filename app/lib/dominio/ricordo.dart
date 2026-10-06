/// Il ricordo (10-chiusura-e-ricordo.md): il passaporto, tutti i viaggi
/// chiusi in ordine, e il mappamondo, i paesi e le città grattati. Il
/// mappamondo si gratta con qualunque viaggio chiuso, verificato o no (regola
/// 5): è il ricordo, non il merito. Niente dipende dal piano (regola 7).
library;

import 'calendario.dart';
import 'stato_viaggio.dart';
import 'testo.dart';

/// Se un viaggio sta nel passaporto di chi guarda: chiuso, verificato o no,
/// e suo — non uno da cui è uscito (regola 4).
bool nelPassaporto({
  required StatoViaggio stato,
  required String partecipazione,
  required bool eliminato,
}) => stato == StatoViaggio.chiuso && partecipazione == 'attivo' && !eliminato;

/// Le pagine del passaporto: i viaggi per anno d'inizio, dal più recente.
List<(int, List<T>)> perAnno<T>(
  Iterable<T> viaggi,
  DateTime Function(T) inizio,
) {
  final ordinati = viaggi.toList()
    ..sort((a, b) => inizio(b).compareTo(inizio(a)));
  final pagine = <(int, List<T>)>[];
  for (final v in ordinati) {
    final anno = inizio(v).year;
    if (pagine.isEmpty || pagine.last.$1 != anno) pagine.add((anno, []));
    pagine.last.$2.add(v);
  }
  return pagine;
}

/// La meta di un viaggio, quanto serve al mappamondo.
typedef Meta = ({String? citta, String? paese});

/// Una città sul mappamondo: il nome senza maiuscole né accenti, e il paese.
/// Senza paese non c'è (ADR-005: chi la scrive a mano lo sa già quando la
/// sceglie).
String? chiaveCitta(Meta meta) {
  final (citta, paese) = (meta.citta, meta.paese);
  if (citta == null || paese == null) return null;
  final nome = normalizza(citta);
  return nome.isEmpty ? null : '$nome|$paese';
}

/// I paesi grattati, una volta ciascuno, nell'ordine delle mete.
List<String> paesiGrattati(Iterable<Meta> mete) =>
    {for (final m in mete) ?m.paese}.toList();

/// Le città grattate, una volta ciascuna, con il nome della prima meta che
/// la nomina.
List<Meta> cittaGrattate(Iterable<Meta> mete) {
  final viste = <String>{};
  return [
    for (final m in mete)
      if (chiaveCitta(m) case final chiave? when viste.add(chiave)) m,
  ];
}

/// Per quanto tempo un paese nuovo aspetta di essere grattato col dito (tela,
/// 95–97): un mese dalla fine del viaggio che l'ha portato, come il riepilogo
/// che si apre da solo. Dopo è sul mappamondo e basta: chi reinstalla l'app,
/// o la riapre dopo mesi, non trova una fila di paesi da grattare.
const daGrattareFinoA = Duration(days: 30);

/// Un viaggio chiuso, quanto serve per sapere quando è arrivato un paese.
typedef Visita = ({String? paese, DateTime fine});

/// I paesi nell'ordine in cui sono arrivati: dalla fine del primo viaggio in
/// ciascuno. Il settimo è «il tuo 7° paese».
List<String> paesiInOrdine(Iterable<Visita> visite) {
  final primo = _primeVisite(visite);
  return primo.keys.toList()..sort((a, b) => primo[a]!.compareTo(primo[b]!));
}

/// I paesi da grattare col dito: arrivati con il primo viaggio in quel paese,
/// finito da poco, e non ancora scoperti su questo telefono. Nell'ordine in
/// cui sono arrivati.
List<String> daGrattare(
  Iterable<Visita> visite, {
  required Set<String> scoperti,
  required DateTime oggi,
}) {
  final primo = _primeVisite(visite);
  final da = soloData(oggi).subtract(daGrattareFinoA);
  return [
    for (final paese in paesiInOrdine(visite))
      if (!scoperti.contains(paese) && !primo[paese]!.isBefore(da)) paese,
  ];
}

Map<String, DateTime> _primeVisite(Iterable<Visita> visite) {
  final primo = <String, DateTime>{};
  for (final v in visite) {
    final paese = v.paese;
    if (paese == null) continue;
    final fine = soloData(v.fine);
    final prima = primo[paese];
    if (prima == null || fine.isBefore(prima)) primo[paese] = fine;
  }
  return primo;
}
