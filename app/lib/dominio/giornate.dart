/// Giorni del viaggio e capienza della giornata (01-modello-dati.md).
///
/// La capienza è `finestra_fine − finestra_inizio` e **non tiene conto degli
/// spostamenti** fra una tappa e l'altra: è una semplificazione dichiarata.
library;

import 'calendario.dart';

/// Una giornata intera: da mezzanotte a mezzanotte.
const inizioGiornata = Duration.zero;
const fineGiornata = Duration(hours: 24);

class FinestraGiorno {
  const FinestraGiorno({
    required this.data,
    required this.inizio,
    required this.fine,
  });

  /// Solo la data: ora, minuti e secondi sono sempre zero.
  final DateTime data;

  /// Orari come distanza dalla mezzanotte.
  final Duration inizio;
  final Duration fine;

  Duration get capienza => fine - inizio;

  @override
  bool operator ==(Object other) =>
      other is FinestraGiorno &&
      other.data == data &&
      other.inizio == inizio &&
      other.fine == fine;

  @override
  int get hashCode => Object.hash(data, inizio, fine);

  @override
  String toString() => 'FinestraGiorno($data, $inizio–$fine)';
}

/// I giorni di un viaggio definito, uno per data.
///
/// Il primo parte dall'ora d'arrivo, l'ultimo finisce all'ora di partenza, quelli
/// in mezzo sono giornate intere. Un viaggio di un giorno solo va dall'arrivo alla
/// partenza.
List<FinestraGiorno> generaGiorni({
  required DateTime dataInizio,
  required DateTime dataFine,
  required Duration oraArrivo,
  required Duration oraPartenza,
}) {
  final primo = soloData(dataInizio);
  final ultimo = soloData(dataFine);
  if (ultimo.isBefore(primo)) {
    throw ArgumentError('La data di fine viene prima di quella di inizio');
  }
  _controllaOra(oraArrivo, 'arrivo');
  _controllaOra(oraPartenza, 'partenza');

  final giorni = <FinestraGiorno>[];
  // Si avanza per giorno di calendario, non per 24 ore: con l'ora legale un giorno
  // può durarne 23 o 25.
  for (
    var data = primo;
    !data.isAfter(ultimo);
    data = DateTime.utc(data.year, data.month, data.day + 1)
  ) {
    final inizio = data == primo ? oraArrivo : inizioGiornata;
    final fine = data == ultimo ? oraPartenza : fineGiornata;
    if (fine <= inizio) {
      throw ArgumentError(
        'Il ${_testoData(data)} non resta tempo: la partenza '
        'non viene dopo l\'arrivo',
      );
    }
    giorni.add(FinestraGiorno(data: data, inizio: inizio, fine: fine));
  }
  return giorni;
}

/// Se una tappa di [nuovaMinuti] entra in una giornata che ha già [durateMinuti].
///
/// È l'unica regola dell'app che rifiuta un inserimento. Offline la tappa entra
/// comunque e si segnala come eccedente (02-sincronizzazione-e-offline.md §2).
bool entraNellaGiornata({
  required Duration capienza,
  required Iterable<int> durateMinuti,
  required int nuovaMinuti,
}) {
  final occupati = durateMinuti.fold<int>(0, (somma, d) => somma + d);
  return occupati + nuovaMinuti <= capienza.inMinutes;
}

/// Gli orari proposti finché la persona non dice altro: si arriva in
/// mattinata, si riparte nel tardo pomeriggio. Precompilati, mai chiesti a
/// vuoto (decisioni/prodotto.md, "Tetto strutturale alle tappe").
const arrivoProposto = Duration(hours: 10);
const partenzaProposta = Duration(hours: 18);

/// Lo scheletro di un viaggio definito (glossario): le date, l'ora in cui si
/// arriva il primo giorno e quella in cui si riparte l'ultimo. I giorni ne
/// discendono.
class Programma {
  const Programma({
    required this.inizio,
    required this.fine,
    required this.arrivo,
    required this.partenza,
  });

  final DateTime inizio;
  final DateTime fine;
  final Duration arrivo;
  final Duration partenza;

  int get durataGiorni => giorniDiCalendario(inizio, fine);

  /// Cosa non va, detto a chi lo sta scrivendo. `null` se sta in piedi.
  String? get problema {
    if (soloData(fine).isBefore(soloData(inizio))) {
      return 'L\'ultimo giorno viene prima del primo.';
    }
    if (durataGiorni == 1 && partenza <= arrivo) {
      return 'In un giorno solo si riparte dopo essere arrivati.';
    }
    if (partenza <= inizioGiornata) {
      return 'Ripartendo a mezzanotte l\'ultimo giorno non resta tempo: '
          'scegli un\'ora più tarda, o fai finire il viaggio il giorno prima.';
    }
    if (arrivo >= fineGiornata) {
      return 'Arrivando a mezzanotte il primo giorno non resta tempo.';
    }
    return null;
  }

  /// I giorni, uno per data. Solo per un programma senza [problema].
  List<FinestraGiorno> get giorni => generaGiorni(
    dataInizio: inizio,
    dataFine: fine,
    oraArrivo: arrivo,
    oraPartenza: partenza,
  );

  @override
  bool operator ==(Object other) =>
      other is Programma &&
      soloData(other.inizio) == soloData(inizio) &&
      soloData(other.fine) == soloData(fine) &&
      other.arrivo == arrivo &&
      other.partenza == partenza;

  @override
  int get hashCode =>
      Object.hash(soloData(inizio), soloData(fine), arrivo, partenza);
}

void _controllaOra(Duration ora, String nome) {
  if (ora < inizioGiornata || ora > fineGiornata) {
    throw ArgumentError('Ora di $nome fuori dalla giornata: $ora');
  }
}

String _testoData(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
