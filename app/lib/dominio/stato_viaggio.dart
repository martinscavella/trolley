/// Gli stati del viaggio (00-panoramica.md, 02-il-viaggio.md), in un posto solo.
///
/// Sul server lo stato è scritto quando qualcuno lo cambia: idea, definito,
/// archiviato. "In corso" e "chiuso" invece li decide il calendario — il viaggio
/// diventa in corso da solo alla data di inizio, e chiuso dopo quella di fine —
/// quindi si ricavano qui dalle date, ogni volta che si guardano. Scriverli sul
/// server spetterà alla chiusura (fase 4.1), che ha conseguenze sue: verifica,
/// traguardi, riepilogo.
library;

import 'calendario.dart';
import 'periodo.dart';

enum StatoViaggio {
  idea,
  definito,
  inCorso,
  chiuso,
  archiviato;

  /// Ha i giorni, e con loro tutto ciò che ne ha bisogno: itinerario,
  /// documenti agganciati ai giorni, spese (regola 2).
  bool get haGiorni => this == definito || this == inCorso || this == chiuso;

  /// Si possono fissare o spostare le date. Anche mentre è in corso: il
  /// viaggio può durare più del previsto. Da chiuso no.
  bool get dateModificabili =>
      this == idea || this == definito || this == inCorso;

  /// Si torna a idea solo da definito: in corso il viaggio sta già succedendo.
  bool get puoTornareIdea => this == definito;
}

/// Lo stato di un viaggio a [oggi], dallo stato scritto sul server e dalle date.
StatoViaggio statoDelViaggio({
  required String registrato,
  required DateTime? inizio,
  required DateTime? fine,
  required DateTime oggi,
}) {
  switch (registrato) {
    case 'idea':
      return StatoViaggio.idea;
    case 'archiviato':
      return StatoViaggio.archiviato;
    case 'chiuso':
      return StatoViaggio.chiuso;
  }
  // Definito (o in corso, se un giorno verrà scritto): lo dice il calendario.
  // Il server non accetta un viaggio definito senza date.
  if (inizio == null || fine == null) return StatoViaggio.definito;
  final giorno = soloData(oggi);
  if (giorno.isBefore(soloData(inizio))) return StatoViaggio.definito;
  if (!giorno.isAfter(soloData(fine))) return StatoViaggio.inCorso;
  return StatoViaggio.chiuso;
}

// ─── Idee e archivio ──────────────────────────────────────────────────────

/// Senza un periodo indicato, un'idea resta viva dodici mesi dalla creazione
/// (02, regola 5).
const mesiSenzaPeriodo = 12;

/// Quanto prima della scadenza l'idea chiede "è ancora un'idea?", e quanto
/// tempo lascia dopo averlo chiesto prima di andare in archivio.
const preavvisoArchivio = Duration(days: 14);

/// L'ultimo giorno in cui un'idea è viva: la fine del suo periodo, oppure
/// dodici mesi dalla creazione se il periodo non c'è.
DateTime scadenzaIdea({
  required Periodo? periodo,
  required DateTime creataIl,
}) =>
    periodo?.ultimoGiorno ?? aggiungiMesi(soloData(creataIl), mesiSenzaPeriodo);

/// Da quando l'idea mostra il sollecito: nelle ultime due settimane, e dopo.
bool sollecitoDovuto({required DateTime scadenza, required DateTime oggi}) =>
    !soloData(oggi).isBefore(soloData(scadenza).subtract(preavvisoArchivio));

/// Se un'idea va in archivio adesso. Serve che il periodo sia passato, e che il
/// sollecito sia stato mostrato da almeno [preavvisoArchivio]: prima di
/// archiviare si avvisa, una volta sola (02, regola 6). Chi riapre l'app dopo
/// mesi vede prima il sollecito, e l'idea resta dov'è ancora per due settimane.
bool daArchiviare({
  required DateTime scadenza,
  required DateTime? sollecitataIl,
  required DateTime oggi,
}) {
  if (sollecitataIl == null) return false;
  final giorno = soloData(oggi);
  return giorno.isAfter(soloData(scadenza)) &&
      !giorno.isBefore(soloData(sollecitataIl).add(preavvisoArchivio));
}

/// Il giorno in cui un'idea sollecitata andrà in archivio se nessuno la tocca:
/// il giorno dopo la scadenza, ma mai prima di due settimane dal sollecito.
DateTime giornoDellArchivio({
  required DateTime scadenza,
  required DateTime sollecitataIl,
}) {
  final dopoLaScadenza = soloData(scadenza).add(const Duration(days: 1));
  final dopoIlPreavviso = soloData(sollecitataIl).add(preavvisoArchivio);
  return dopoLaScadenza.isAfter(dopoIlPreavviso)
      ? dopoLaScadenza
      : dopoIlPreavviso;
}
