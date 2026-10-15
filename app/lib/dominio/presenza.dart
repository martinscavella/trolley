/// Chi c'è in città (5.5; 11-community, regole 8–13; tela, 79–81, 117 e 118):
/// per quale viaggio si può accendere, quale schermata mostrare, e le parole
/// delle date.
///
/// Chi vede chi, e quando la presenza vale, lo decide il server
/// (presenza_in_citta.sql): qui si legge quello che manda. La città è la meta
/// del viaggio, mai la posizione del telefono.
library;

import 'calendario.dart';
import 'profilo_pubblico.dart';
import 'stato_viaggio.dart';

/// Ogni quanto, mentre la si guarda accesa, si chiede chi c'è: senza
/// notifiche, chi arriva compare così.
const intervalloPresenza = Duration(seconds: 30);

/// Se per un viaggio si può accendere la presenza: in corso, non importato,
/// con una città nella meta, e ci si è ancora dentro.
bool presenzaPossibile({
  required StatoViaggio stato,
  required bool importato,
  required String? citta,
  required bool partecipa,
}) =>
    stato == StatoViaggio.inCorso &&
    !importato &&
    (citta?.trim().isNotEmpty ?? false) &&
    partecipa;

/// Che cosa mostra «Chi c'è a Porto».
enum StatoPresenza {
  /// Il telefono non ha ancora trovato la persona sul posto (tela, 117; C1).
  quandoSarai,

  /// Come sopra, ma senza il permesso di posizione non succederà (118).
  senzaPosizione,

  /// Sul posto, spenta: si può accendere (79).
  accendibile,

  /// Accesa per questo viaggio (80 e 81).
  accesa,
}

/// Quale schermata, da quello che si sa: la propria presenza sul server, il
/// «sul posto» nella copia, il permesso di posizione.
StatoPresenza statoPresenza({
  required bool accesaQui,
  required bool sulPosto,
  required bool posizioneNegata,
}) {
  if (accesaQui) return StatoPresenza.accesa;
  if (sulPosto) return StatoPresenza.accendibile;
  if (posizioneNegata) return StatoPresenza.senzaPosizione;
  return StatoPresenza.quandoSarai;
}

/// La propria presenza, come la manda il server: fino a quando la legge solo
/// la persona (C2).
class PresenzaMia {
  const PresenzaMia({
    required this.viaggioId,
    required this.citta,
    required this.paese,
    required this.fino,
  });

  static PresenzaMia? daServer(Object? valore) {
    if (valore is! Map) return null;
    final fino = leggiData(valore['fino'] as String?);
    if (fino == null) return null;
    return PresenzaMia(
      viaggioId: valore['viaggio_id'] as String,
      citta: valore['citta'] as String,
      paese: valore['paese'] as String,
      fino: fino,
    );
  }

  final String viaggioId;
  final String citta;
  final String paese;

  /// L'ultimo giorno del viaggio.
  final DateTime fino;
}

/// Chi c'è: la propria presenza, se vale, e gli altri nella stessa città, in
/// ordine di nome (C8), con il loro profilo pubblico e a che punto siete.
class ChiCeInCitta {
  const ChiCeInCitta({this.mia, this.altri = const []});

  factory ChiCeInCitta.daServer(Map<String, dynamic> r) => ChiCeInCitta(
    mia: PresenzaMia.daServer(r['mia']),
    altri: [
      for (final p in (r['altri'] as List? ?? const []))
        ProfiloPubblico.daServer(p as Map<String, dynamic>),
    ],
  );

  final PresenzaMia? mia;
  final List<ProfiloPubblico> altri;

  /// Se è accesa proprio per [viaggioId]: accesa per un altro viaggio, qui
  /// si può accendere, e quella si spegne (C7).
  bool accesaPer(String viaggioId) => mia?.viaggioId == viaggioId;
}

/// Quando si spegne, per chi l'ha accesa: «oggi», «domani», «domenica 12».
String fineInParole(DateTime fine, DateTime oggi) {
  final giorni = soloData(fine).difference(soloData(oggi)).inDays;
  if (giorni <= 0) return 'oggi';
  if (giorni == 1) return 'domani';
  return '${nomiDeiGiorni[fine.weekday - 1]} ${fine.day}';
}

/// Per l'interruttore: «fino a domenica», «fino a domani», «fino a stasera».
String finoA(DateTime fine, DateTime oggi) {
  final giorni = soloData(fine).difference(soloData(oggi)).inDays;
  if (giorni <= 0) return 'fino a stasera';
  if (giorni == 1) return 'fino a domani';
  return 'fino a ${nomiDeiGiorni[fine.weekday - 1]}';
}

/// Sotto il titolo: «3 viaggiatori, oltre a te».
String oltreATe(int quanti) => quanti == 1
    ? '1 viaggiatore, oltre a te'
    : '$quanti viaggiatori, oltre a te';
