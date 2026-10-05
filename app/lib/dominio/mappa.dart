/// La mappa (08-mappa.md): le tappe nell'ordine del programma, quale viaggio
/// e quale giorno si guardano, quanto sono lontane le cose. Le regole stanno
/// qui, in un posto solo; la schermata le disegna sopra i riquadri del
/// fornitore (ADR-006).
///
/// La mappa e l'itinerario sono due viste della stessa cosa (regola 5): i
/// numeri sono quelli della giornata, e una tappa senza un posto riconoscibile
/// resta nella numerazione anche se sulla mappa non c'è.
library;

import 'dart:math';

import 'calendario.dart';
import 'stato_viaggio.dart';
import 'tappe.dart';

/// Un punto sulla Terra, in gradi.
typedef Coordinate = ({double lat, double lon});

/// Le coordinate di una riga, se ci sono tutte e due e stanno sulla Terra.
Coordinate? coordinate(double? lat, double? lon) {
  if (lat == null || lon == null) return null;
  if (lat.abs() > 90 || lon.abs() > 180) return null;
  return (lat: lat, lon: lon);
}

const _raggioTerra = 6371008.8;

double _radianti(double gradi) => gradi * pi / 180;

/// Quanto sono lontani [a] e [b], in metri, lungo la superficie.
double distanzaInMetri(Coordinate a, Coordinate b) {
  final dLat = _radianti(b.lat - a.lat);
  final dLon = _radianti(b.lon - a.lon);
  final h =
      pow(sin(dLat / 2), 2) +
      cos(_radianti(a.lat)) * cos(_radianti(b.lat)) * pow(sin(dLon / 2), 2);
  return 2 * _raggioTerra * asin(sqrt(h.clamp(0, 1)));
}

/// Come appare una tappa sulla mappa (tela, 50): fatta, saltata, la prossima,
/// o una delle altre da fare.
enum SegnoTappa { daFare, prossima, fatta, saltata }

/// Una tappa sulla mappa della giornata.
class TappaSullaMappa<T> {
  const TappaSullaMappa({
    required this.tappa,
    required this.numero,
    required this.segno,
    required this.posto,
  });

  final T tappa;

  /// Il suo numero nella giornata, dall'1: lo stesso della giornata.
  final int numero;
  final SegnoTappa segno;

  /// Dove sta; `null` se non ha un posto riconoscibile.
  final Coordinate? posto;
}

/// Le tappe di una giornata, già nel loro ordine, come le mostra la mappa.
/// La prossima è la prima ancora da fare, e si indica solo [conProssima]:
/// mentre il viaggio è in corso e la giornata è oggi, come «Adesso».
List<TappaSullaMappa<T>> tappeSullaMappa<T>({
  required List<T> tappe,
  required StatoTappa Function(T) statoDi,
  required Coordinate? Function(T) postoDi,
  bool conProssima = false,
}) {
  var prossimaData = !conProssima;
  return [
    for (final (i, t) in tappe.indexed)
      TappaSullaMappa(
        tappa: t,
        numero: i + 1,
        posto: postoDi(t),
        segno: switch (statoDi(t)) {
          StatoTappa.completata => SegnoTappa.fatta,
          StatoTappa.saltata => SegnoTappa.saltata,
          StatoTappa.daFare when !prossimaData => () {
            prossimaData = true;
            return SegnoTappa.prossima;
          }(),
          StatoTappa.daFare => SegnoTappa.daFare,
        },
      ),
  ];
}

/// Un tratto fra due tappe che si seguono sulla mappa.
typedef Tratto = ({Coordinate da, Coordinate a, bool percorso});

/// I tratti che collegano le tappe nell'ordine della giornata. Una tappa senza
/// posto si salta: la linea va da quella prima a quella dopo. Un tratto è
/// già percorso quando la tappa da cui parte è segnata, come nella giornata.
List<Tratto> trattiDellaGiornata<T>(List<TappaSullaMappa<T>> tappe) {
  final conPosto = [
    for (final t in tappe)
      if (t.posto != null) t,
  ];
  return [
    for (var i = 0; i + 1 < conPosto.length; i++)
      (
        da: conPosto[i].posto!,
        a: conPosto[i + 1].posto!,
        percorso:
            conPosto[i].segno == SegnoTappa.fatta ||
            conPosto[i].segno == SegnoTappa.saltata,
      ),
  ];
}

/// Quale giorno mostra la mappa quando si apre: oggi se il viaggio lo
/// comprende, il primo se deve ancora cominciare, l'ultimo se è finito.
/// `null` se non ha giorni.
G? giornoDellaMappa<G>({
  required List<G> giorni,
  required DateTime Function(G) dataDi,
  required DateTime oggi,
}) {
  if (giorni.isEmpty) return null;
  final giorno = soloData(oggi);
  for (final g in giorni) {
    if (soloData(dataDi(g)) == giorno) return g;
  }
  return soloData(dataDi(giorni.first)).isAfter(giorno)
      ? giorni.first
      : giorni.last;
}

/// I viaggi che si possono mettere sulla mappa, come li propone la scelta
/// in alto (tela, 58): quelli in corso, poi quelli in programma dal più
/// vicino, poi quelli conclusi dal più recente. Le idee no: non hanno tappe.
({List<V> inCorso, List<V> inProgramma, List<V> conclusi}) viaggiDellaMappa<V>({
  required List<V> viaggi,
  required StatoViaggio Function(V) statoDi,
  required DateTime? Function(V) inizioDi,
}) {
  List<V> conStato(StatoViaggio s) => [
    for (final v in viaggi)
      if (statoDi(v) == s && inizioDi(v) != null) v,
  ];
  return (
    inCorso: conStato(StatoViaggio.inCorso)
      ..sort((a, b) => inizioDi(a)!.compareTo(inizioDi(b)!)),
    inProgramma: conStato(StatoViaggio.definito)
      ..sort((a, b) => inizioDi(a)!.compareTo(inizioDi(b)!)),
    conclusi: conStato(StatoViaggio.chiuso)
      ..sort((a, b) => inizioDi(b)!.compareTo(inizioDi(a)!)),
  );
}

/// Quale viaggio apre «Mappa» dall'elenco dei viaggi: quello in corso — fra
/// due, quello scelto oggi —, altrimenti il prossimo in programma, altrimenti
/// l'ultimo finito. Si cambia dall'alto. `null` se non c'è nessun viaggio con
/// le date.
String? viaggioPerLaMappa<V>({
  required List<V> viaggi,
  required String Function(V) idDi,
  required StatoViaggio Function(V) statoDi,
  required DateTime? Function(V) inizioDi,
  String? sceltoOggi,
}) {
  final (:inCorso, :inProgramma, :conclusi) = viaggiDellaMappa(
    viaggi: viaggi,
    statoDi: statoDi,
    inizioDi: inizioDi,
  );
  if (inCorso.isNotEmpty) {
    final scelto = inCorso.where((v) => idDi(v) == sceltoOggi).firstOrNull;
    return idDi(scelto ?? inCorso.first);
  }
  if (inProgramma.isNotEmpty) return idDi(inProgramma.first);
  return conclusi.isEmpty ? null : idDi(conclusi.first);
}

/// Il riquadro che contiene tutti i [punti]: sud-ovest e nord-est.
({Coordinate sudOvest, Coordinate nordEst})? riquadroDi(
  Iterable<Coordinate> punti,
) {
  if (punti.isEmpty) return null;
  var (s, o, n, e) = (90.0, 180.0, -90.0, -180.0);
  for (final p in punti) {
    s = min(s, p.lat);
    n = max(n, p.lat);
    o = min(o, p.lon);
    e = max(e, p.lon);
  }
  return (sudOvest: (lat: s, lon: o), nordEst: (lat: n, lon: e));
}
