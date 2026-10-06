/// La chiusura del viaggio (10-chiusura-e-ricordo.md; 02, regola 4): quando
/// si chiude, chi lo chiude prima, quanto vale, che cosa c'è di nuovo. Le
/// regole stanno qui; la verifica in dominio/verifica.dart, i traguardi in
/// dominio/traguardi.dart.
library;

import 'dart:math';

import 'calendario.dart';
import 'stato_viaggio.dart';

/// Se un viaggio va chiuso da solo: il server lo dice ancora definito, ma
/// l'ultimo giorno è passato (regola 1). Il primo telefono che lo vede lo
/// chiude.
bool daChiudereDaSolo({
  required String registrato,
  required DateTime? fine,
  required DateTime oggi,
}) =>
    (registrato == 'definito' || registrato == 'in_corso') &&
    fine != null &&
    soloData(oggi).isAfter(soloData(fine));

/// Se chi guarda può chiudere il viaggio prima della fine: solo mentre è in
/// corso, e solo chi ne è responsabile (02, regola 4).
bool siChiudeAMano({required StatoViaggio stato, required bool responsabile}) =>
    stato == StatoViaggio.inCorso && responsabile;

/// Il riepilogo si apre da solo per i viaggi finiti da poco: chi riapre l'app
/// dopo mesi non trova una fila di riepiloghi da chiudere.
const riepilogoDaSoloFinoA = Duration(days: 30);

bool riepilogoDaSolo({required DateTime fine, required DateTime oggi}) =>
    !soloData(oggi).isAfter(soloData(fine).add(riepilogoDaSoloFinoA));

/// I punti viaggio della North Star (glossario): 1, più 0,1 per ogni giorno
/// oltre il primo, fino a 2. Una gita vale 1,0, una settimana 1,6.
double puntiViaggio(int giorni) =>
    (min(2.0, 1 + 0.1 * max(0, giorni - 1)) * 10).round() / 10;

/// Un viaggio chiuso, quanto serve per dire che cosa c'è di nuovo.
typedef MetaChiusa = ({
  String id,
  DateTime inizio,
  String? paese,
  String? citta,
});

/// Che cosa ha portato di nuovo un viaggio rispetto ai viaggi chiusi prima
/// (10, regola 2): il paese, la città, o niente — e allora quante volte ci
/// si è stati.
class Novita {
  const Novita({
    required this.paeseNuovo,
    required this.cittaNuova,
    required this.volte,
  });

  final bool paeseNuovo;
  final bool cittaNuova;

  /// Quante volte si è stati in quella meta, questa compresa.
  final int volte;

  bool get niente => !paeseNuovo && !cittaNuova;
}

Novita novitaDelViaggio(MetaChiusa questo, Iterable<MetaChiusa> chiusi) {
  final prima = [
    for (final v in chiusi)
      if (v.id != questo.id && v.inizio.isBefore(questo.inizio)) v,
  ];
  final paese = questo.paese;
  final citta = questo.citta?.toLowerCase();
  bool stessaCitta(MetaChiusa v) =>
      citta != null && v.citta?.toLowerCase() == citta && v.paese == paese;
  final paeseNuovo = paese != null && !prima.any((v) => v.paese == paese);
  final cittaNuova = citta != null && !prima.any(stessaCitta);
  final volte =
      1 +
      prima
          .where((v) => citta != null ? stessaCitta(v) : v.paese == paese)
          .length;
  return Novita(paeseNuovo: paeseNuovo, cittaNuova: cittaNuova, volte: volte);
}

/// Dopo la chiusura il programma è finito: non si aggiungono tappe. Le spese
/// sì — quelle pagate al ritorno stanno «Dopo il viaggio» — e i saldi restano
/// finché non si chiudono.
bool tappeAggiungibili(StatoViaggio stato) => stato != StatoViaggio.chiuso;
