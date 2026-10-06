/// Il ricordo (10-chiusura-e-ricordo.md): il passaporto, tutti i viaggi
/// chiusi in ordine, e il mappamondo, i paesi e le città grattati. Il
/// mappamondo si gratta con qualunque viaggio chiuso, verificato o no,
/// importato compreso (regola 5): è il ricordo, non il merito. Niente dipende
/// dal piano (regola 7).
library;

import 'calendario.dart';
import 'periodo.dart';
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
/// [importato]: un viaggio passato, inserito come ricordo.
typedef Visita = ({String? paese, DateTime fine, bool importato});

/// I paesi nell'ordine in cui sono arrivati: dalla fine del primo viaggio in
/// ciascuno. Il settimo è «il tuo 7° paese».
List<String> paesiInOrdine(Iterable<Visita> visite) {
  final primo = _primeVisite(visite);
  return primo.keys.toList()
    ..sort((a, b) => primo[a]!.fine.compareTo(primo[b]!.fine));
}

/// I paesi da grattare col dito: arrivati con il primo viaggio in quel paese,
/// finito da poco, e non ancora scoperti su questo telefono. Nell'ordine in
/// cui sono arrivati. Un paese portato da un viaggio passato non si gratta:
/// grattare è il premio di un viaggio fatto, e chi riempie il passaporto il
/// primo giorno non trova una fila di patine (decisioni, fase 4.3).
List<String> daGrattare(
  Iterable<Visita> visite, {
  required Set<String> scoperti,
  required DateTime oggi,
}) {
  final primo = _primeVisite(visite);
  final da = soloData(oggi).subtract(daGrattareFinoA);
  return [
    for (final paese in paesiInOrdine(visite))
      if (primo[paese]! case (:final fine, :final importato)
          when !scoperti.contains(paese) && !importato && !fine.isBefore(da))
        paese,
  ];
}

/// Per ogni paese, quando è finito il primo viaggio lì, e se era passato.
Map<String, ({DateTime fine, bool importato})> _primeVisite(
  Iterable<Visita> visite,
) {
  final primo = <String, ({DateTime fine, bool importato})>{};
  for (final v in visite) {
    final paese = v.paese;
    if (paese == null) continue;
    final fine = soloData(v.fine);
    final prima = primo[paese];
    if (prima == null || fine.isBefore(prima.fine)) {
      primo[paese] = (fine: fine, importato: v.importato);
    }
  }
  return primo;
}

// ─── I viaggi passati (fase 4.3) ──────────────────────────────────────────

/// Quanti giorni al massimo si può dire che è durato un viaggio passato.
const giorniRicordatiMassimi = 365;

/// I giorni scritti a mano, se sono un numero; `null` se il campo è vuoto o
/// non lo è.
int? leggiGiorni(String testo) => int.tryParse(testo.trim());

/// Che cosa manca a un viaggio passato per essere aggiunto, detto alla
/// persona; `null` se si può. Il mese è quello in cui è cominciato, e non
/// può essere ancora da venire; i giorni sono facoltativi.
String? problemaViaggioPassato({
  required bool dove,
  required Periodo? quando,
  required String giorni,
  required DateTime oggi,
}) {
  if (!dove) return 'Scegli dove';
  if (quando == null) return 'Scegli quando';
  if (quando.primoGiorno.isAfter(DateTime.utc(oggi.year, oggi.month))) {
    return 'Un viaggio passato è cominciato in un mese già venuto';
  }
  if (giorni.trim().isEmpty) return null;
  final n = leggiGiorni(giorni);
  if (n == null || n < 1 || n > giorniRicordatiMassimi) {
    return 'I giorni vanno da 1 a $giorniRicordatiMassimi, o lascia vuoto';
  }
  return null;
}
