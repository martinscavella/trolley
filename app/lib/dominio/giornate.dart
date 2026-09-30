/// Giorni del viaggio e capienza della giornata (01-modello-dati.md).
///
/// La capienza è `finestra_fine − finestra_inizio` e **non tiene conto degli
/// spostamenti** fra una tappa e l'altra: è una semplificazione dichiarata.
library;

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
  final primo = _soloData(dataInizio);
  final ultimo = _soloData(dataFine);
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

DateTime _soloData(DateTime d) => DateTime.utc(d.year, d.month, d.day);

void _controllaOra(Duration ora, String nome) {
  if (ora < inizioGiornata || ora > fineGiornata) {
    throw ArgumentError('Ora di $nome fuori dalla giornata: $ora');
  }
}

String _testoData(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
