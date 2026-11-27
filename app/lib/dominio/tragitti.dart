/// I tragitti fra le tappe e i loro mezzi (CR-07; 04, regole 34–39;
/// ADR-015).
///
/// Il mezzo sta nella tappa a cui si arriva: «come ci arrivi» dalla tappa
/// prima. Quanto ci vuole, sulla giornata, è una stima nostra: la distanza
/// in linea d'aria, allungata perché le strade non sono dritte, per la
/// velocità del mezzo. Si calcola senza rete e non costa niente; il tragitto
/// vero lo dice Google quando lo si apre, e non si tiene (le sue condizioni
/// non lo permettono).
library;

import 'mappa.dart';

/// Come si va da una tappa all'altra, nell'ordine in cui si sceglie.
enum Mezzo {
  aPiedi('a_piedi', 4.5, Duration.zero),
  bici('bici', 13, Duration.zero),
  mezzi('mezzi', 15, Duration(minutes: 8)),
  monopattino('monopattino', 13, Duration.zero),
  auto('auto', 22, Duration(minutes: 3)),
  taxi('taxi', 22, Duration(minutes: 3));

  const Mezzo(this.codice, this.kmOrari, this.inPiu);

  /// Come lo scrive il server.
  final String codice;

  /// La velocità media in città, porta a porta.
  final double kmOrari;

  /// Il tempo che non dipende dalla strada: aspettare il mezzo e arrivare
  /// alla fermata, partire e parcheggiare.
  final Duration inPiu;

  /// La guida dentro Trolley lo porta: tutti tranne i mezzi pubblici, che
  /// si aprono in Google Maps (tela, 172).
  bool get guidabile => this != Mezzo.mezzi;

  /// `null` se non è un mezzo noto: le tappe di prima della CR-07 non lo
  /// hanno.
  static Mezzo? leggi(String? testo) {
    for (final m in values) {
      if (m.codice == testo) return m;
    }
    return null;
  }

  /// Quanto ci vuole a stima per [metri] in linea d'aria: arrotondato ai
  /// cinque minuti in su, mai meno di cinque.
  Duration stima(double metri) {
    final minuti = metri * allungamento / 1000 / kmOrari * 60 + inPiu.inMinutes;
    final cinque = (minuti / 5).ceil() * 5;
    return Duration(minutes: cinque < 5 ? 5 : cinque);
  }
}

/// Quanto la strada è più lunga della linea d'aria, in città.
const allungamento = 1.3;

/// Una tappa vista dal tragitto: quando comincia e finisce, se è saltata,
/// come ci si arriva e dove sta.
typedef TappaDelTragitto = ({
  String id,
  Duration inizio,
  Duration fine,
  bool saltata,
  Mezzo? mezzo,
  Coordinate? posto,
});

/// Il tragitto da una tappa alla successiva dello stesso giorno.
class Tragitto {
  const Tragitto({
    required this.daId,
    required this.aId,
    required this.partenza,
    required this.arrivo,
    this.mezzo,
    this.metri,
  });

  /// La tappa da cui si parte e quella a cui si arriva, che tiene il mezzo.
  final String daId;
  final String aId;

  /// Quando finisce la prima, e quando comincia la seconda.
  final Duration partenza;
  final Duration arrivo;

  /// `null`: «Come ci vai?».
  final Mezzo? mezzo;

  /// In linea d'aria; `null` se una delle due non ha il posto.
  final double? metri;

  /// Il tempo libero fra le due.
  Duration get spazio => arrivo - partenza;

  /// Quanto ci vuole a stima con [m] (il mezzo scelto, se non lo si dice);
  /// `null` senza posto o senza mezzo.
  Duration? stima([Mezzo? m]) {
    final con = m ?? mezzo;
    if (con == null || metri == null) return null;
    return con.stima(metri!);
  }

  /// Con il mezzo scelto non ci si sta: la giornata lo colora, e non blocca
  /// niente (04, regola 36).
  bool get nonCiStai => (stima() ?? Duration.zero) > spazio;

  /// Il mezzo più veloce che ci sta, se non è già quello scelto. A pari
  /// tempo, il primo dell'elenco.
  Mezzo? get piuVeloce {
    if (metri == null) return null;
    Mezzo? migliore;
    for (final m in Mezzo.values) {
      if (m.stima(metri!) > spazio) continue;
      if (migliore == null || m.stima(metri!) < migliore.stima(metri!)) {
        migliore = m;
      }
    }
    return migliore == mezzo ? null : migliore;
  }

  /// A che ora potrebbe cominciare la tappa dopo, per arrivarci con il
  /// mezzo scelto: la fine della prima più il tragitto. `null` se ci si sta
  /// già, o se non si sa quanto ci vuole.
  Duration? get arrivoPossibile {
    final s = stima();
    if (s == null || s <= spazio) return null;
    return partenza + s;
  }
}

/// I tragitti di una giornata: fra ogni tappa e quella che viene dopo nel
/// tempo, tolte le saltate (si va dalla tappa prima). Due tappe che si
/// sovrappongono non hanno un tragitto fra loro: la giornata le mostra già.
List<Tragitto> tragittiDelGiorno(Iterable<TappaDelTragitto> tappe) {
  final inOrdine = [
    for (final t in tappe)
      if (!t.saltata) t,
  ]..sort((a, b) => a.inizio.compareTo(b.inizio));
  return [
    for (var i = 1; i < inOrdine.length; i++)
      if (inOrdine[i].inizio >= inOrdine[i - 1].fine)
        Tragitto(
          daId: inOrdine[i - 1].id,
          aId: inOrdine[i].id,
          partenza: inOrdine[i - 1].fine,
          arrivo: inOrdine[i].inizio,
          mezzo: inOrdine[i].mezzo,
          metri: switch ((inOrdine[i - 1].posto, inOrdine[i].posto)) {
            (final a?, final b?) => distanzaInMetri(a, b),
            _ => null,
          },
        ),
  ];
}
