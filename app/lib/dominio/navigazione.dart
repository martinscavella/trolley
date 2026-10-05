/// La navigazione verso una tappa (08-mappa.md, regola 2): il percorso a
/// piedi che dà il fornitore (ADR-006), e dove si è lungo quel percorso man
/// mano che ci si muove — quale svolta viene, fra quanti metri, quanto manca,
/// se si è usciti di strada, se si è arrivati.
///
/// La posizione resta qui: serve a disegnare e a guidare chi guarda, e al
/// fornitore va solo il punto di partenza quando si chiede un percorso
/// (regola 7, 06-privacy-e-conformita.md).
library;

import 'dart:math';

import 'mappa.dart';

/// Cosa si fa alla fine di un tratto.
enum Manovra {
  partenza,
  dritto,
  leggermenteADestra,
  aDestra,
  strettaADestra,
  leggermenteASinistra,
  aSinistra,
  strettaASinistra,
  inversione,
  tieniLaDestra,
  tieniLaSinistra,
  rotonda,
  mezzi,
  arrivo,
}

/// Un passo del percorso: dal punto [da] al punto [a] della linea, con
/// l'indicazione che si dà quando comincia.
class Passo {
  const Passo({
    required this.istruzione,
    required this.manovra,
    required this.da,
    required this.a,
    required this.metri,
  });

  /// Come la scrive il fornitore, in italiano: «Svolta a destra in Rua das
  /// Flores».
  final String istruzione;
  final Manovra manovra;
  final int da;
  final int a;
  final double metri;
}

/// Un percorso dal punto in cui si è alla tappa.
class Percorso {
  Percorso({
    required this.punti,
    required this.passi,
    required this.metri,
    required this.durata,
  }) : _progressivi = _progressiviDi(punti);

  /// La linea da disegnare, dall'inizio alla fine.
  final List<Coordinate> punti;
  final List<Passo> passi;
  final double metri;
  final Duration durata;

  /// Per ogni punto, quanti metri ci sono dall'inizio della linea.
  final List<double> _progressivi;

  double get _lunghezza => _progressivi.isEmpty ? 0 : _progressivi.last;

  static List<double> _progressiviDi(List<Coordinate> punti) {
    final progressivi = <double>[];
    var somma = 0.0;
    for (final (i, p) in punti.indexed) {
      if (i > 0) somma += distanzaInMetri(punti[i - 1], p);
      progressivi.add(somma);
    }
    return progressivi;
  }

  /// Dove si è lungo il percorso, stando in [posizione]. [giaFatti] sono i
  /// metri percorsi alla posizione di prima: si cerca da lì in avanti, così
  /// una strada che torna su sé stessa non fa tornare indietro.
  Avanzamento avanzamento(Coordinate posizione, {double giaFatti = 0}) {
    if (punti.length < 2) {
      final arrivo = punti.isEmpty ? posizione : punti.single;
      final scarto = distanzaInMetri(posizione, arrivo);
      return Avanzamento(
        fatti: 0,
        metriRimasti: scarto,
        tempoRimasto: Duration.zero,
        scarto: scarto,
        passo: passi.isEmpty ? null : 0,
        prossima: passi.isEmpty ? null : passi.last,
        metriAllaProssima: scarto,
      );
    }

    // Una proiezione piana attorno al punto: per pochi chilometri basta.
    final scalaLon = cos(posizione.lat * pi / 180) * 111320;
    const scalaLat = 110540.0;
    Point<double> piano(Coordinate c) => Point(
      (c.lon - posizione.lon) * scalaLon,
      (c.lat - posizione.lat) * scalaLat,
    );

    var migliore = (scarto: double.infinity, fatti: 0.0);
    final daDove = max(0.0, giaFatti - _tolleranzaIndietro);
    for (var i = 0; i + 1 < punti.length; i++) {
      if (_progressivi[i + 1] < daDove) continue;
      final a = piano(punti[i]);
      final b = piano(punti[i + 1]);
      final ab = b - a;
      final lunghezza2 = ab.x * ab.x + ab.y * ab.y;
      final t = lunghezza2 == 0
          ? 0.0
          : ((-a.x * ab.x - a.y * ab.y) / lunghezza2).clamp(0.0, 1.0);
      final vicino = Point(a.x + ab.x * t, a.y + ab.y * t);
      final scarto = vicino.magnitude;
      if (scarto < migliore.scarto) {
        migliore = (
          scarto: scarto,
          fatti: _progressivi[i] + (_progressivi[i + 1] - _progressivi[i]) * t,
        );
      }
    }

    final fatti = migliore.fatti;
    final rimasti = max(0.0, _lunghezza - fatti);
    final quota = _lunghezza == 0 ? 0.0 : rimasti / _lunghezza;

    // Il passo in corso è quello che contiene il punto raggiunto; la
    // prossima indicazione è quella del passo dopo.
    int? inCorso;
    for (final (i, p) in passi.indexed) {
      final fine = _progressivi[p.a.clamp(0, punti.length - 1)];
      if (fatti <= fine + 0.5) {
        inCorso = i;
        break;
      }
    }
    inCorso ??= passi.isEmpty ? null : passi.length - 1;
    final prossima = inCorso == null
        ? null
        : passi[min(inCorso + 1, passi.length - 1)];
    final fineDelPasso = inCorso == null
        ? _lunghezza
        : _progressivi[passi[inCorso].a.clamp(0, punti.length - 1)];

    return Avanzamento(
      fatti: fatti,
      metriRimasti: rimasti,
      tempoRimasto: Duration(seconds: (durata.inSeconds * quota).round()),
      scarto: migliore.scarto,
      passo: inCorso,
      prossima: prossima,
      metriAllaProssima: max(0.0, fineDelPasso - fatti),
    );
  }

  /// Quanto si può tornare indietro rispetto alla posizione di prima: il GPS
  /// sbanda, e una persona può girarsi.
  static const _tolleranzaIndietro = 40.0;
}

/// Dove si è lungo un percorso.
class Avanzamento {
  const Avanzamento({
    required this.fatti,
    required this.metriRimasti,
    required this.tempoRimasto,
    required this.scarto,
    required this.passo,
    required this.prossima,
    required this.metriAllaProssima,
  });

  /// Quanti metri del percorso sono alle spalle.
  final double fatti;
  final double metriRimasti;
  final Duration tempoRimasto;

  /// Quanto si è lontani dalla linea, in metri.
  final double scarto;

  /// Il passo che si sta facendo.
  final int? passo;

  /// L'indicazione da dare adesso: quella che viene alla fine del passo.
  final Passo? prossima;
  final double metriAllaProssima;

  /// Fuori dal percorso: il GPS di una città sbaglia di qualche decina di
  /// metri, quindi solo oltre questa distanza.
  bool get fuoriStrada => scarto > sogliaFuoriStrada;
}

const sogliaFuoriStrada = 50.0;

/// Arrivati: abbastanza vicini alla tappa da proporre di segnarla (tela, 52).
const sogliaArrivo = 35.0;

bool arrivato({required Coordinate posizione, required Coordinate tappa}) =>
    distanzaInMetri(posizione, tappa) <= sogliaArrivo;

/// Quante volte, in una navigazione, si chiede un percorso nuovo perché si è
/// usciti di strada. Ogni percorso si paga (ADR-006): oltre, si consegna
/// alle Mappe del telefono invece di insistere.
const ricalcoliMassimi = 8;

/// Fra un ricalcolo e l'altro: chi cammina e sbaglia una via non ne paga
/// cinque.
const attesaFraRicalcoli = Duration(seconds: 20);

/// Quante posizioni di fila fuori strada prima di ricalcolare: una sola può
/// essere il GPS che sbanda.
const fuoriStradaDiFila = 2;

enum Ricalcolo { no, si, basta }

/// Se chiedere un percorso nuovo: dopo [fuori] posizioni di fila fuori
/// strada, non prima di [attesaFraRicalcoli] dall'[ultimo], e non oltre
/// [ricalcoliMassimi] in tutto.
Ricalcolo vaRicalcolato({
  required int fuori,
  required int fatti,
  required DateTime? ultimo,
  required DateTime adesso,
}) {
  if (fuori < fuoriStradaDiFila) return Ricalcolo.no;
  if (fatti >= ricalcoliMassimi) return Ricalcolo.basta;
  if (ultimo != null && adesso.difference(ultimo) < attesaFraRicalcoli) {
    return Ricalcolo.no;
  }
  return Ricalcolo.si;
}
