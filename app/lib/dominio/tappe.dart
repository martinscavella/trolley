/// Le tappe (04-itinerario.md, 01-modello-dati.md): i tipi con la durata che
/// propongono, gli stati, e le regole della capienza in un posto solo.
///
/// La capienza è l'unica regola dell'app che rifiuta un inserimento: una tappa
/// che non entra nella giornata non si aggiunge, e si propone cosa fare. Senza
/// rete invece entra lo stesso, e se al momento dell'invio la giornata nel
/// frattempo si è riempita resta segnalata come eccedente (02 §2).
library;

import 'calendario.dart';
import 'giornate.dart';
import 'stato_viaggio.dart';

/// Il tipo di una tappa. Serve a proporre la durata, precompilata e mai
/// chiesta a vuoto (decisioni/prodotto.md, "Tetto strutturale alle tappe"), e
/// a riconoscere la tappa a colpo d'occhio. Il nome è quello del server.
enum TipoTappa {
  visita(Duration(minutes: 90)),
  museo(Duration(hours: 2)),
  pasto(Duration(minutes: 90)),
  passeggiata(Duration(hours: 1)),
  spettacolo(Duration(hours: 2)),
  escursione(Duration(hours: 4)),
  pausa(Duration(minutes: 30)),
  altro(Duration(hours: 1));

  const TipoTappa(this.durataProposta);

  /// La durata con cui nasce una tappa di questo tipo: sempre correggibile.
  final Duration durataProposta;

  /// Come lo scrive il server. `null` se non è un tipo noto: le tappe che
  /// arriveranno da un itinerario incollato (1.6) possono non averlo.
  static TipoTappa? leggi(String? testo) {
    for (final t in values) {
      if (t.name == testo) return t;
    }
    return null;
  }
}

/// Lo stato di una tappa (04, regola 15).
enum StatoTappa {
  daFare('da_fare'),
  completata('completata'),
  saltata('saltata');

  const StatoTappa(this.codice);

  /// Come lo scrive il server.
  final String codice;

  /// Completata o saltata: per la verifica contano tutte e due (02 §2).
  bool get segnata => this != daFare;

  static StatoTappa leggi(String testo) {
    for (final s in values) {
      if (s.codice == testo) return s;
    }
    return daFare;
  }
}

/// Di quanto cresce o cala una durata a ogni tocco, e la più corta possibile.
const passoDurata = Duration(minutes: 15);
const durataMinima = Duration(minutes: 15);

Duration durataPiuLunga(Duration d) {
  final piu = d + passoDurata;
  return piu > fineGiornata ? fineGiornata : piu;
}

Duration durataPiuCorta(Duration d) {
  final meno = d - passoDurata;
  return meno < durataMinima ? durataMinima : meno;
}

/// Quanto tempo resta in una giornata di [capienza] che ha già tappe di
/// [durateMinuti]. Negativo se la giornata sfora.
Duration tempoLibero({
  required Duration capienza,
  required Iterable<int> durateMinuti,
}) =>
    capienza -
    Duration(minutes: durateMinuti.fold<int>(0, (somma, d) => somma + d));

/// L'ordine di una tappa che si aggiunge in fondo alla giornata.
int ordineInFondo(Iterable<int> ordini) =>
    ordini.fold<int>(0, (massimo, o) => o > massimo ? o : massimo) + 1;

/// Un altro giorno del viaggio in cui si potrebbe mettere una tappa.
typedef GiornoLibero<G> = ({G giorno, DateTime data, Duration libero});

/// Quello che si propone quando una tappa non entra (04, regola 4).
class Proposte<G> {
  const Proposte({required this.manca, this.accorciaA, this.altroGiorno});

  /// Quanto tempo manca perché entri così com'è.
  final Duration manca;

  /// Accorciarla al tempo che resta, se ne resta almeno [durataMinima].
  final Duration? accorciaA;

  /// Il giorno più vicino in cui entra così com'è.
  final GiornoLibero<G>? altroGiorno;
}

/// Una tappa di [durata] non entra nel giorno [data], che ha [libero]: si dice
/// quanto manca e si propone di accorciarla, di spostarla nel giorno più vicino
/// in cui entra (a pari distanza, quello dopo), o di togliere qualcosa.
Proposte<G> proposteSeNonEntra<G>({
  required Duration durata,
  required DateTime data,
  required Duration libero,
  required Iterable<GiornoLibero<G>> altriGiorni,
}) {
  final giorno = soloData(data);
  int distanza(GiornoLibero<G> g) =>
      soloData(g.data).difference(giorno).inDays.abs();
  final candidati =
      altriGiorni
          .where((g) => soloData(g.data) != giorno && g.libero >= durata)
          .toList()
        ..sort((a, b) {
          final perDistanza = distanza(a).compareTo(distanza(b));
          return perDistanza != 0 ? perDistanza : b.data.compareTo(a.data);
        });
  return Proposte(
    manca: durata - (libero.isNegative ? Duration.zero : libero),
    accorciaA: libero >= durataMinima ? libero : null,
    altroGiorno: candidati.firstOrNull,
  );
}

/// Le tappe si segnano dal primo giorno del viaggio: prima non c'è niente da
/// segnare (04, regola 16). Dopo la fine si può ancora, ma non conta per la
/// verifica (regola 17).
bool tappeSegnabili(StatoViaggio stato) =>
    stato == StatoViaggio.inCorso || stato == StatoViaggio.chiuso;

/// Segnata mentre il viaggio era in corso: è quello che conta per la verifica.
bool segnataDuranteIlViaggio(StatoViaggio stato) =>
    stato == StatoViaggio.inCorso;
