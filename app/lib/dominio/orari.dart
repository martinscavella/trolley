/// Gli orari delle tappe (04-itinerario.md, «Gli orari»): ogni tappa occupa
/// un pezzo della giornata, da quando comincia a quando finisce, e due tappe
/// non si sovrappongono. Le regole stanno qui, in un posto solo.
///
/// La capienza resta (giornate.dart): con le tappe che non si sovrappongono
/// e stanno dentro la finestra, la somma delle durate non può superarla. In
/// più, una giornata con abbastanza tempo libero può non avere un buco
/// abbastanza lungo: allora si propone di spostare in avanti le tappe dopo.
library;

import 'calendario.dart';
import 'giornate.dart';
import 'tappe.dart';

/// Ogni quanto si sceglie un orario: lo stesso passo del selettore.
const passoOrario = Duration(minutes: 5);

/// Da che ora si propone la prima tappa di una giornata intera: a
/// mezzanotte non comincia niente.
const primaOraProposta = Duration(hours: 9);

/// Un pezzo di giornata già preso da una tappa. [segnata] è una tappa fatta
/// o saltata: è andata com'è andata, e non si sposta da sola.
class Occupato<T> {
  const Occupato(
    this.chi, {
    required this.inizio,
    required this.durata,
    this.segnata = false,
  });

  final T chi;
  final Duration inizio;
  final Duration durata;
  final bool segnata;

  Duration get fine => inizio + durata;

  /// Toccarsi non è sovrapporsi: una che finisce alle 11 e una che comincia
  /// alle 11 vanno bene.
  bool siSovrapponeA(Duration inizio, Duration durata) =>
      this.inizio < inizio + durata && inizio < fine;

  @override
  String toString() => 'Occupato($chi, $inizio–$fine)';
}

/// Il primo orario del passo che non viene prima di [d].
Duration alPasso(Duration d) {
  final passo = passoOrario.inMinutes;
  final minuti = d.inMinutes;
  final resto = minuti % passo;
  return Duration(minutes: resto == 0 ? minuti : minuti + passo - resto);
}

/// Una tappa sulla linea del tempo. [proposto] vuol dire che l'orario non
/// l'ha scelto nessuno: la tappa è arrivata senza (da un itinerario
/// incollato, o da prima che l'orario ci fosse), e l'app l'ha messa in fila.
class Collocata<T> {
  const Collocata(
    this.tappa, {
    required this.inizio,
    required this.durata,
    required this.proposto,
  });

  final T tappa;
  final Duration inizio;
  final Duration durata;
  final bool proposto;

  Duration get fine => inizio + durata;
}

/// Una tappa da collocare: il suo orario, se ce l'ha, e quanto dura.
typedef DaCollocare<T> = ({T tappa, Duration? ora, Duration durata});

/// Le tappe di un giorno al loro posto, in ordine d'orario. Quelle con
/// l'orario stanno dove dice; quelle senza, prese nell'ordine in cui sono,
/// vanno ciascuna nel primo spazio libero dopo quella che le precede, dalla
/// prima ora proposta. Se lo spazio non c'è finiscono in fondo, e la
/// giornata le mostrerà fuori posto ([conflitti]).
///
/// A pari orario resta l'ordine di [inOrdine].
List<Collocata<T>> colloca<T>(
  FinestraGiorno finestra,
  List<DaCollocare<T>> inOrdine,
) {
  final prese = <Occupato<int>>[
    for (final (i, t) in inOrdine.indexed)
      if (t.ora != null) Occupato(i, inizio: t.ora!, durata: t.durata),
  ];
  final collocate = <(int, Collocata<T>)>[];
  var dopo = _primaOra(finestra, null);
  for (final (i, t) in inOrdine.indexed) {
    final ora = t.ora;
    if (ora != null) {
      collocate.add((
        i,
        Collocata(t.tappa, inizio: ora, durata: t.durata, proposto: false),
      ));
      dopo = ora + t.durata;
      continue;
    }
    final inizio =
        _primoBuco(finestra, prese, t.durata, da: dopo) ??
        _primoBuco(finestra, prese, t.durata, da: finestra.inizio) ??
        _inFondo(prese, dopo);
    prese.add(Occupato(i, inizio: inizio, durata: t.durata));
    collocate.add((
      i,
      Collocata(t.tappa, inizio: inizio, durata: t.durata, proposto: true),
    ));
    dopo = inizio + t.durata;
  }
  collocate.sort((a, b) {
    final perOra = a.$2.inizio.compareTo(b.$2.inizio);
    return perOra != 0 ? perOra : a.$1.compareTo(b.$1);
  });
  return [for (final (_, c) in collocate) c];
}

/// Dove vanno delle tappe nuove, nell'ordine dato, in una giornata che ha
/// già [occupati] (04, casi limite): quella con un'ora libera ci resta;
/// quella con un'ora presa va nel primo spazio libero dopo, ed è
/// [spostata]; quella senza ora va dopo quella che la precede, o dopo
/// l'ultima della giornata. Senza spazio resta all'ora che aveva, o in fondo:
/// la giornata la mostrerà fuori posto.
List<({Duration ora, bool spostata})> collocaNuove<T>(
  FinestraGiorno finestra,
  Iterable<Occupato<T>> occupati,
  List<({Duration? ora, Duration durata})> nuove,
) {
  final prese = <Occupato<Object?>>[
    for (final o in occupati)
      Occupato(o.chi, inizio: o.inizio, durata: o.durata),
  ];
  var dopo = prese.isEmpty
      ? _primaOra(finestra, null)
      : _inFondo(prese, finestra.inizio);
  final dove = <({Duration ora, bool spostata})>[];
  for (final n in nuove) {
    final voluta = n.ora;
    final ({Duration ora, bool spostata}) qui;
    if (voluta != null) {
      if (_libero(finestra, prese, voluta, n.durata)) {
        qui = (ora: voluta, spostata: false);
      } else {
        final altrove =
            _primoBuco(finestra, prese, n.durata, da: voluta) ??
            _primoBuco(finestra, prese, n.durata, da: finestra.inizio);
        qui = (ora: altrove ?? voluta, spostata: altrove != null);
      }
    } else {
      qui = (
        ora:
            _primoBuco(finestra, prese, n.durata, da: dopo) ??
            _primoBuco(finestra, prese, n.durata, da: finestra.inizio) ??
            _inFondo(prese, dopo),
        spostata: false,
      );
    }
    prese.add(Occupato(null, inizio: qui.ora, durata: n.durata));
    dove.add(qui);
    dopo = qui.ora + n.durata;
  }
  return dove;
}

/// Le tappe fuori posto: quelle che si sovrappongono a un'altra, o che
/// escono dalla giornata. Capita quando una tappa arriva senza rete mentre
/// un altro ha preso il suo orario, o quando le date si spostano: entra lo
/// stesso, e la giornata la mostra in rosso finché non si sistema.
Set<T> conflitti<T>(FinestraGiorno finestra, List<Collocata<T>> collocate) => {
  for (final (i, a) in collocate.indexed)
    if (a.inizio < finestra.inizio ||
        a.fine > finestra.fine ||
        collocate.indexed.any(
          (b) => b.$1 != i && a.inizio < b.$2.fine && b.$2.inizio < a.fine,
        ))
      a.tappa,
};

/// L'orario con cui nasce una tappa di [durata]: subito dopo l'ultima della
/// giornata; se lì non entra, il primo spazio libero dalla prima ora
/// proposta, poi da inizio giornata. `null` se non c'è uno spazio
/// abbastanza lungo.
Duration? oraProposta<T>(
  FinestraGiorno finestra,
  Iterable<Occupato<T>> occupati,
  Duration durata,
) {
  final lista = occupati.toList();
  if (lista.isNotEmpty) {
    final ultima = lista.map((o) => o.fine).reduce((a, b) => a > b ? a : b);
    final dopo = alPasso(ultima);
    if (_libero(finestra, lista, dopo, durata)) return dopo;
  }
  return _primoBuco(finestra, lista, durata, da: _primaOra(finestra, durata)) ??
      _primoBuco(finestra, lista, durata, da: finestra.inizio);
}

/// Perché una tappa non può stare a quell'orario.
sealed class ProblemaOrario<T> {
  const ProblemaOrario();
}

/// Comincia prima che la giornata cominci: il primo giorno si arriva a
/// [inizio].
final class PrimaDellInizio<T> extends ProblemaOrario<T> {
  const PrimaDellInizio(this.inizio);
  final Duration inizio;
}

/// Finisce dopo la fine della giornata: la partenza dell'ultimo giorno, o
/// mezzanotte. Una tappa non attraversa la notte.
final class DopoLaFine<T> extends ProblemaOrario<T> {
  const DopoLaFine(this.fine);
  final Duration fine;
}

/// Si sovrappone a [con], in ordine d'orario.
final class Sovrapposta<T> extends ProblemaOrario<T> {
  const Sovrapposta(this.con);
  final List<Occupato<T>> con;
}

/// Che problema ha una tappa di [durata] alle [inizio], fra le [altre] del
/// giorno (lei esclusa). `null` se ci sta.
ProblemaOrario<T>? problemaOrario<T>(
  FinestraGiorno finestra,
  Iterable<Occupato<T>> altre,
  Duration inizio,
  Duration durata,
) {
  if (inizio < finestra.inizio) return PrimaDellInizio(finestra.inizio);
  if (inizio + durata > finestra.fine) return DopoLaFine(finestra.fine);
  final con = [
    for (final o in altre)
      if (o.siSovrapponeA(inizio, durata)) o,
  ]..sort((a, b) => a.inizio.compareTo(b.inizio));
  return con.isEmpty ? null : Sovrapposta(con);
}

/// Un altro giorno del viaggio, con le tappe che ha già.
typedef AltroGiorno<G, T> = ({
  G giorno,
  FinestraGiorno finestra,
  List<Occupato<T>> occupati,
});

/// Uno spostamento proposto: [chi] va alle [inizio].
typedef Spostamento<T> = ({T chi, Duration inizio});

/// Quello che si propone quando una tappa non può stare dove la si vuole
/// (04, «Gli orari», regola 6). Ogni proposta c'è solo se è possibile.
class ProposteOrario<G, T> {
  const ProposteOrario({
    required this.libero,
    this.orarioLibero,
    this.spostaDopo,
    this.accorciaA,
    this.altroGiorno,
  });

  /// Il tempo libero di tutta la giornata, senza la tappa.
  final Duration libero;

  /// L'orario libero più vicino a quello scelto in cui entra così com'è.
  final Duration? orarioLibero;

  /// Tenere l'orario scelto e spostare in avanti le tappe dopo, di quanto
  /// serve: chi va dove.
  final List<Spostamento<T>>? spostaDopo;

  /// Accorciarla a quello che resta da quell'orario alla tappa dopo.
  final Duration? accorciaA;

  /// Il giorno più vicino in cui entra così com'è, e a che ora.
  final ({G giorno, DateTime data, Duration ora})? altroGiorno;
}

ProposteOrario<G, T> proposteOrario<G, T>({
  required FinestraGiorno finestra,
  required List<Occupato<T>> altre,
  required Duration inizio,
  required Duration durata,
  Iterable<AltroGiorno<G, T>> altriGiorni = const [],
}) {
  final libero =
      finestra.capienza -
      altre.fold(Duration.zero, (somma, o) => somma + o.durata);
  return ProposteOrario(
    libero: libero,
    orarioLibero: _piuVicino(finestra, altre, inizio, durata),
    spostaDopo: _spostaDopo(finestra, altre, inizio, durata),
    accorciaA: _accorcia(finestra, altre, inizio, durata),
    altroGiorno: _altroGiorno(finestra.data, altriGiorni, inizio, durata),
  );
}

/// Il primo orario di una giornata da cui proporre: la prima ora proposta,
/// se la giornata comincia prima e (con una [durata]) la tappa ci sta;
/// altrimenti l'inizio della giornata.
Duration _primaOra(FinestraGiorno f, Duration? durata) {
  final inizio = alPasso(f.inizio);
  if (inizio >= primaOraProposta) return inizio;
  if (durata != null && primaOraProposta + durata > f.fine) return inizio;
  return primaOraProposta;
}

bool _libero<T>(
  FinestraGiorno f,
  List<Occupato<T>> occupati,
  Duration inizio,
  Duration durata,
) =>
    inizio >= f.inizio &&
    inizio + durata <= f.fine &&
    !occupati.any((o) => o.siSovrapponeA(inizio, durata));

/// I buchi della giornata: da dove a dove non c'è nessuna tappa.
List<(Duration, Duration)> _buchi<T>(
  FinestraGiorno f,
  List<Occupato<T>> occupati,
) {
  final ordinati = [...occupati]..sort((a, b) => a.inizio.compareTo(b.inizio));
  final buchi = <(Duration, Duration)>[];
  var da = f.inizio;
  for (final o in ordinati) {
    if (o.inizio > da) buchi.add((da, o.inizio < f.fine ? o.inizio : f.fine));
    if (o.fine > da) da = o.fine;
  }
  if (da < f.fine) buchi.add((da, f.fine));
  return buchi;
}

/// Il primo orario dal [da] in poi in cui una tappa di [durata] entra.
Duration? _primoBuco<T>(
  FinestraGiorno f,
  List<Occupato<T>> occupati,
  Duration durata, {
  required Duration da,
}) {
  for (final (a, b) in _buchi(f, occupati)) {
    final inizio = alPasso(a > da ? a : da);
    if (inizio + durata <= b) return inizio;
  }
  return null;
}

/// Dove va una tappa senza spazio: dopo l'ultima, o dove si era arrivati.
Duration _inFondo<T>(List<Occupato<T>> prese, Duration dopo) {
  var fine = dopo;
  for (final o in prese) {
    if (o.fine > fine) fine = o.fine;
  }
  return alPasso(fine);
}

/// L'orario libero più vicino a [voluto], prima o dopo; a pari distanza,
/// quello dopo.
Duration? _piuVicino<T>(
  FinestraGiorno f,
  List<Occupato<T>> occupati,
  Duration voluto,
  Duration durata,
) {
  Duration? migliore;
  Duration? distanza;
  for (final (a, b) in _buchi(f, occupati)) {
    final primo = alPasso(a);
    final ultimo = b - durata;
    if (ultimo < primo) continue;
    // Il più vicino al voluto dentro il buco, sul passo.
    var inizio = voluto < primo
        ? primo
        : voluto > ultimo
        ? ultimo
        : alPasso(voluto);
    if (inizio > ultimo) inizio = ultimo;
    final d = (inizio - voluto).abs();
    if (distanza == null ||
        d < distanza ||
        (d == distanza && inizio > migliore!)) {
      (migliore, distanza) = (inizio, d);
    }
  }
  return migliore;
}

/// Tenere [inizio] e spingere avanti le tappe che vengono dopo, finché non
/// toccano più. Non si può se una tappa cominciata prima occupa già
/// quell'orario, se una da spingere è segnata, o se una uscirebbe dalla
/// giornata.
List<Spostamento<T>>? _spostaDopo<T>(
  FinestraGiorno f,
  List<Occupato<T>> occupati,
  Duration inizio,
  Duration durata,
) {
  if (inizio < f.inizio || inizio + durata > f.fine) return null;
  if (occupati.any((o) => o.inizio < inizio && o.fine > inizio)) return null;
  final dopo = [
    for (final o in occupati)
      if (o.inizio >= inizio) o,
  ]..sort((a, b) => a.inizio.compareTo(b.inizio));
  final spostamenti = <Spostamento<T>>[];
  var cursore = inizio + durata;
  for (final o in dopo) {
    if (o.inizio >= cursore) break;
    if (o.segnata) return null;
    if (cursore + o.durata > f.fine) return null;
    spostamenti.add((chi: o.chi, inizio: cursore));
    cursore += o.durata;
  }
  return spostamenti.isEmpty ? null : spostamenti;
}

/// Accorciarla a quello che resta da [inizio] alla tappa dopo, o alla fine
/// della giornata, se è almeno la durata più corta.
Duration? _accorcia<T>(
  FinestraGiorno f,
  List<Occupato<T>> occupati,
  Duration inizio,
  Duration durata,
) {
  if (inizio < f.inizio) return null;
  if (occupati.any((o) => o.inizio <= inizio && o.fine > inizio)) return null;
  var fino = f.fine;
  for (final o in occupati) {
    if (o.inizio > inizio && o.inizio < fino) fino = o.inizio;
  }
  final resta = fino - inizio;
  final minuti = resta.inMinutes - resta.inMinutes % passoOrario.inMinutes;
  final a = Duration(minutes: minuti);
  return a >= durataMinima && a < durata ? a : null;
}

/// Il giorno più vicino a [data] in cui la tappa entra così com'è: alla
/// stessa ora, se lì è libera, altrimenti all'orario proposto. A pari
/// distanza, il giorno dopo.
({G giorno, DateTime data, Duration ora})? _altroGiorno<G, T>(
  DateTime data,
  Iterable<AltroGiorno<G, T>> altri,
  Duration inizio,
  Duration durata,
) {
  final giorno = soloData(data);
  int distanza(AltroGiorno<G, T> g) =>
      soloData(g.finestra.data).difference(giorno).inDays.abs();
  final candidati =
      [
        for (final g in altri)
          if (soloData(g.finestra.data) != giorno) g,
      ]..sort((a, b) {
        final perDistanza = distanza(a).compareTo(distanza(b));
        return perDistanza != 0
            ? perDistanza
            : b.finestra.data.compareTo(a.finestra.data);
      });
  for (final g in candidati) {
    final ora = _libero(g.finestra, g.occupati, inizio, durata)
        ? inizio
        : oraProposta(g.finestra, g.occupati, durata);
    if (ora != null) {
      return (giorno: g.giorno, data: g.finestra.data, ora: ora);
    }
  }
  return null;
}

/// Un giorno dove rimandare una tappa saltata (04, regole 31–33), e a che
/// ora ci andrebbe. Senza [ora] non entra così com'è.
class Rimando<G> {
  const Rimando({
    required this.giorno,
    required this.data,
    required this.ora,
    required this.oggi,
  });

  final G giorno;
  final DateTime data;
  final Duration? ora;

  /// È il giorno di adesso: l'ora è la prima libera da adesso in poi.
  final bool oggi;

  bool get entra => ora != null;
}

/// Dove si può rimandare una tappa di [durata] (04, regola 32): i giorni del
/// viaggio da oggi in poi, nell'ordine. Oggi, il primo spazio libero da
/// [adesso] in poi; gli altri giorni, l'orario proposto (regola 19). Nel
/// giorno [daDove] in cui la tappa era, rimandare è più tardi: si cerca dalla
/// fine del suo posto. Nei [giorni] non c'è la tappa stessa. I giorni passati
/// non ci sono: si rimanda solo in avanti.
List<Rimando<G>> doveRimandare<G, T>({
  required Iterable<AltroGiorno<G, T>> giorni,
  required DateTime adesso,
  required Duration durata,
  ({DateTime data, Duration fine})? daDove,
}) {
  final oggi = soloData(adesso);
  final ora = Duration(hours: adesso.hour, minutes: adesso.minute);
  final dopo = [
    for (final g in giorni)
      if (!soloData(g.finestra.data).isBefore(oggi)) g,
  ]..sort((a, b) => a.finestra.data.compareTo(b.finestra.data));
  Rimando<G> rimando(AltroGiorno<G, T> g) {
    final data = soloData(g.finestra.data);
    final eOggi = data == oggi;
    // Da dove si comincia a cercare: adesso, oggi; la fine del suo posto,
    // nel giorno in cui era. Gli altri giorni, l'orario proposto.
    Duration? da;
    if (eOggi) da = ora;
    if (daDove != null && soloData(daDove.data) == data) {
      da = da == null || daDove.fine > da ? daDove.fine : da;
    }
    return Rimando(
      giorno: g.giorno,
      data: g.finestra.data,
      oggi: eOggi,
      ora: da == null
          ? oraProposta(g.finestra, g.occupati, durata)
          : _primoBuco(
              g.finestra,
              g.occupati,
              durata,
              da: alPasso(da > g.finestra.inizio ? da : g.finestra.inizio),
            ),
    );
  }

  return [for (final g in dopo) rimando(g)];
}
