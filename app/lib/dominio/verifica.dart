/// La verifica del viaggio (02-il-viaggio.md, regole 7–9; glossario): le tre
/// condizioni, e quando si è «sul posto». Le regole stanno qui, in un posto
/// solo; la chiusura (fase 4.1) le usa per dire se un viaggio è verificato,
/// e quale condizione è mancata (07: `viaggio_chiuso`).
///
/// La posizione non lascia mai il telefono: il confronto con la meta si fa
/// qui, a livello di città o paese, e al server va solo l'esito (06).
library;

import 'mappa.dart';
import 'stato_viaggio.dart';
import 'tappe.dart';

/// Fin dove, dal centro della città della meta, si è ancora sul posto: la
/// periferia, l'aeroporto, la gita fuori porta. La regola guarda la città,
/// mai la via.
const raggioDellaMeta = 50000.0;

/// Le tre condizioni della regola 7.
enum CondizioneVerifica {
  /// Almeno una tappa per ogni giorno del viaggio.
  unaTappaPerGiorno,

  /// L'app aperta sul posto con la posizione attiva, almeno una volta mentre
  /// il viaggio era in corso; o la deroga amministrativa (regola 8).
  sulPosto,

  /// Tutte le tappe completate o saltate mentre il viaggio era in corso:
  /// segnarle dopo non vale.
  tappeSegnate,
}

/// Com'è andata la verifica di un viaggio, per una persona.
class EsitoVerifica {
  const EsitoVerifica(this.mancanti, {this.perDeroga = false});

  /// Le condizioni che non sono vere. Nessuna: verificato.
  final Set<CondizioneVerifica> mancanti;

  /// Il viaggio ha la deroga: è contrassegnato ed esce da ogni metrica, anche
  /// se qualcuno era davvero sul posto (02, regola 8; 07, regola 4).
  final bool perDeroga;

  bool get verificato => mancanti.isEmpty;
}

/// Una tappa come la guarda la verifica.
typedef TappaDaVerificare = ({
  String giornoId,
  StatoTappa stato,
  bool duranteIlViaggio,
});

/// La verifica di un viaggio per chi ha il telefono in mano: le tappe sono di
/// tutti, il posto è suo (regola 9: chi nega la posizione non avrà mai un
/// viaggio verificato, anche se un compagno era sul posto). Contano le tappe
/// dei [giorni] del viaggio: quelle da ricollocare no. Un viaggio importato
/// non è mai verificato (01, invariante 4).
EsitoVerifica verificaDelViaggio({
  required Iterable<String> giorni,
  required Iterable<TappaDaVerificare> tappe,
  required bool sulPosto,
  bool importato = false,
  bool perDeroga = false,
}) {
  if (importato) return EsitoVerifica(CondizioneVerifica.values.toSet());
  final delViaggio = giorni.toSet();
  final contate = [
    for (final t in tappe)
      if (delViaggio.contains(t.giornoId)) t,
  ];
  final conTappe = {for (final t in contate) t.giornoId};
  return EsitoVerifica({
    if (delViaggio.isEmpty || !delViaggio.every(conTappe.contains))
      CondizioneVerifica.unaTappaPerGiorno,
    if (!sulPosto && !perDeroga) CondizioneVerifica.sulPosto,
    if (contate.isEmpty ||
        !contate.every((t) => t.stato.segnata && t.duranteIlViaggio))
      CondizioneVerifica.tappeSegnate,
  }, perDeroga: perDeroga);
}

/// Se [qui] è sul posto: entro [raggioDellaMeta] dalla città della meta, o
/// nel paese della meta se la meta è un paese intero — o una città che
/// l'elenco non conosce, e di cui si sa solo il paese. Senza né l'una né
/// l'altro non si può dire, e non lo è.
bool sulPostoDellaMeta({
  required Coordinate qui,
  required Coordinate? citta,
  required String? paeseMeta,
  required String? paeseQui,
}) {
  if (citta != null) return distanzaInMetri(qui, citta) <= raggioDellaMeta;
  return paeseMeta != null && paeseQui == paeseMeta.toUpperCase();
}

/// Se adesso si guarda dov'è il telefono per la verifica: solo mentre il
/// viaggio è in corso, mai per uno importato, e finché questa persona non
/// risulta già sul posto — basta una volta.
bool siGuardaIlPosto({
  required StatoViaggio stato,
  required bool importato,
  required bool giaSulPosto,
}) => stato == StatoViaggio.inCorso && !importato && !giaSulPosto;
