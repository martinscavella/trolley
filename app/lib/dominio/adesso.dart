/// «Adesso», mentre il viaggio è in corso (09-durante-il-viaggio.md): cosa
/// succede adesso, cosa viene dopo e fra quanto, il documento di questo
/// momento. Le regole stanno qui, in un posto solo; la schermata le mostra.
///
/// Il programma non si riorganizza mai da solo e non rimprovera nessuno: se è
/// indietro rispetto all'orologio, si dice cosa resta (09, casi limite).
library;

/// Quando una tappa comincia e finisce nel programma della giornata, come
/// distanza dalla mezzanotte.
typedef Orario = ({Duration inizio, Duration fine});

/// Gli orari di una giornata, tappa per tappa, nell'ordine dato. Una tappa con
/// l'ora la tiene; le altre cominciano quando finisce quella prima, e la prima
/// all'inizio della giornata. Gli spostamenti non si contano, come nella
/// capienza (01-modello-dati.md).
List<Orario> orariDellaGiornata({
  required Duration inizioGiornata,
  required Iterable<({Duration? ora, Duration durata})> tappe,
}) {
  var cursore = inizioGiornata;
  return [
    for (final t in tappe)
      () {
        final inizio = t.ora ?? cursore;
        cursore = inizio + t.durata;
        return (inizio: inizio, fine: cursore);
      }(),
  ];
}

/// La tappa di adesso rispetto al suo orario.
enum Puntualita {
  /// Deve ancora cominciare: «alle 10:30».
  inArrivo,

  /// Il suo orario è adesso: «ora · 10:30–11:30».
  inCorso,

  /// Il suo orario è passato e non è segnata: «in programma dalle 10:30».
  indietro,
}

/// Una tappa della giornata con il suo orario.
typedef TappaConOrario<T> = ({T tappa, Orario orario});

/// Quello che «adesso» mostra di una giornata.
class Adesso<T> {
  const Adesso({
    required this.tappe,
    this.corrente,
    this.puntualita,
    this.dopo,
    this.traQuanto,
    this.restano = 0,
    this.finoAlle,
  });

  /// Quante tappe ha la giornata, segnate o no.
  final int tappe;

  /// La prima tappa ancora da fare: è quella di adesso, come la «prossima»
  /// della giornata. `null` se non ce ne sono più.
  final TappaConOrario<T>? corrente;
  final Puntualita? puntualita;

  /// La tappa da fare che viene dopo quella di adesso.
  final TappaConOrario<T>? dopo;

  /// Fra quanto comincia [dopo], se deve ancora cominciare.
  final Duration? traQuanto;

  /// Quante tappe da fare restano oggi, quella di adesso compresa.
  final int restano;

  /// Quando finisce, nel programma, l'ultima tappa da fare.
  final Duration? finoAlle;

  /// Una giornata senza tappe.
  bool get libera => tappe == 0;

  /// Una giornata con delle tappe, tutte segnate.
  bool get finita => tappe > 0 && corrente == null;
}

/// Cosa succede [adesso] in una giornata che comincia a [inizioGiornata], con
/// [tappe] nel loro ordine.
Adesso<T> cosaSuccedeAdesso<T>({
  required List<T> tappe,
  required Duration? Function(T) oraDi,
  required Duration Function(T) durataDi,
  required bool Function(T) daFare,
  required Duration inizioGiornata,
  required Duration adesso,
}) {
  final orari = orariDellaGiornata(
    inizioGiornata: inizioGiornata,
    tappe: [for (final t in tappe) (ora: oraDi(t), durata: durataDi(t))],
  );
  final daFareConOrario = [
    for (final (i, t) in tappe.indexed)
      if (daFare(t)) (tappa: t, orario: orari[i]),
  ];
  final corrente = daFareConOrario.firstOrNull;
  if (corrente == null) return Adesso(tappe: tappe.length);
  final dopo = daFareConOrario.skip(1).firstOrNull;
  final orario = corrente.orario;
  final puntualita = adesso < orario.inizio
      ? Puntualita.inArrivo
      : adesso < orario.fine
      ? Puntualita.inCorso
      : Puntualita.indietro;
  final traQuanto = dopo == null ? null : dopo.orario.inizio - adesso;
  return Adesso(
    tappe: tappe.length,
    corrente: corrente,
    puntualita: puntualita,
    dopo: dopo,
    traQuanto: traQuanto != null && traQuanto > Duration.zero
        ? traQuanto
        : null,
    restano: daFareConOrario.length,
    finoAlle: daFareConOrario.last.orario.fine,
  );
}

/// Per quanto un documento con l'ora resta «di adesso» dopo quell'ora: la
/// carta d'imbarco delle 7:05 serve ancora alle 7:40, non a mezzogiorno.
const tolleranzaDocumento = Duration(hours: 1);

/// Il documento di questo momento (09, regola 2), fra quelli di oggi già in
/// ordine (07, regola 5: prima quelli con l'ora, nell'ordine dell'ora). Il
/// primo con l'ora che non è passata da più di [tolleranzaDocumento]; se non
/// ce n'è, il primo di oggi senza ora. `null` se oggi non c'è niente che serva
/// adesso.
D? documentoDiAdesso<D>({
  required List<D> diOggi,
  required Duration? Function(D) oraDi,
  required Duration adesso,
}) {
  for (final d in diOggi) {
    final alle = oraDi(d);
    if (alle != null && alle + tolleranzaDocumento > adesso) return d;
  }
  return diOggi.where((d) => oraDi(d) == null).firstOrNull;
}

/// Quale viaggio apre «adesso» fra quelli in corso [inCorso] (09, regola 1 e
/// casi limite): l'unico, o quello scelto oggi se è ancora in corso. `null`
/// quando non ce n'è nessuno, o ce n'è più d'uno e oggi non si è scelto: la
/// persona sceglie, e la scelta vale fino a sera.
String? viaggioDiAdesso({
  required List<String> inCorso,
  required String? sceltoOggi,
}) {
  if (inCorso.length == 1) return inCorso.single;
  if (sceltoOggi != null && inCorso.contains(sceltoOggi)) return sceltoOggi;
  return null;
}
