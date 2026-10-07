/// Che cosa succede ai propri viaggi chiudendo l'account (U.1; 01, casi
/// limite; 06, «Conservazione»). È la regola di `chiudi_account` sul server:
/// la decide il server, e qui la si scrive per dirla prima, con i numeri veri
/// (tela, 101).
///
/// - Un viaggio in cui si è rimasti i soli si cancella con tutto dentro: le
///   idee, i viaggi da soli, quelli passati.
/// - Da un viaggio con altri si esce: quello che si è aggiunto resta, e le
///   spese restano nei saldi.
/// - Se se ne era responsabili, il ruolo passa a chi è entrato per primo fra
///   quelli che restano; a pari momento, all'id più piccolo, come sul server.
library;

/// Un compagno di viaggio ancora dentro, quanto serve a sapere a chi passa
/// il ruolo.
typedef Compagno = ({String id, String nome, DateTime entrato});

/// Un proprio viaggio: se se ne è responsabili, e chi altro c'è ancora.
typedef ViaggioDaChiudere<T> = ({
  T viaggio,
  bool responsabile,
  List<Compagno> altri,
});

class ChiusuraAccount<T> {
  const ChiusuraAccount({
    required this.cancellati,
    required this.lasciati,
    required this.passaggi,
  });

  /// I viaggi in cui si è i soli: si cancellano.
  final List<T> cancellati;

  /// I viaggi con altri: si esce.
  final List<T> lasciati;

  /// Fra i lasciati, quelli di cui si era responsabili, con chi lo diventa.
  final List<(T, Compagno)> passaggi;
}

ChiusuraAccount<T> cosaSuccede<T>(Iterable<ViaggioDaChiudere<T>> viaggi) {
  final cancellati = <T>[];
  final lasciati = <T>[];
  final passaggi = <(T, Compagno)>[];
  for (final v in viaggi) {
    if (v.altri.isEmpty) {
      cancellati.add(v.viaggio);
      continue;
    }
    lasciati.add(v.viaggio);
    if (v.responsabile) passaggi.add((v.viaggio, erede(v.altri)));
  }
  return ChiusuraAccount(
    cancellati: cancellati,
    lasciati: lasciati,
    passaggi: passaggi,
  );
}

/// Chi prende il ruolo: chi è entrato per primo.
Compagno erede(List<Compagno> altri) => altri.reduce((a, b) {
  final prima = a.entrato.compareTo(b.entrato);
  if (prima != 0) return prima < 0 ? a : b;
  return a.id.compareTo(b.id) <= 0 ? a : b;
});
