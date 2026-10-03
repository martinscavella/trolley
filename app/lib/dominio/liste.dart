/// Le cose da portare (05-cose-da-portare.md): che cos'è una voce valida, in
/// che ordine si vede la lista, quanto è piena la valigia.
///
/// Nella 1.5 la lista è una, personale: la vede solo chi la scrive, anche
/// quando nel viaggio arriva qualcun altro (regole 1 e 3). La lista del
/// viaggio da dividere, e chi porta cosa, arrivano con la 2.4.
library;

/// Le due liste del modello dati (01-modello-dati.md, `voce_lista.tipo`).
enum TipoLista {
  /// La vedono tutti quelli del viaggio, e serve a dividersi le cose.
  viaggio,

  /// La vede solo chi la scrive, nemmeno il creatore del viaggio.
  personale;

  String get codice => name;
}

/// La lista in cui finisce una voce nuova. Una sola, per ora: chi scrive per
/// sé non deve scoprire dopo che altri leggono.
const listaDellaFase = TipoLista.personale;

/// Quanto può essere lungo il testo di una voce: una cosa da portare, non una
/// nota. Lo stesso limite c'è sul server.
const lunghezzaMassimaVoce = 200;

/// Quanti pezzi può avere una voce: cinque magliette sono una voce, non
/// cinque (05, schermate). Gli stessi limiti ci sono sul server.
const quantitaMinima = 1;
const quantitaMassima = 99;

/// Il testo di una voce come si salva: senza spazi ai lati. `null` se non
/// c'è niente da salvare o se è troppo lungo.
String? testoVoce(String scritto) {
  final testo = scritto.trim();
  if (testo.isEmpty || testo.length > lunghezzaMassimaVoce) return null;
  return testo;
}

/// Una quantità dentro i limiti.
int quantitaValida(int quante) => quante.clamp(quantitaMinima, quantitaMassima);

/// Una voce, quanto serve per metterla in ordine.
class VoceDaPortare<T> {
  const VoceDaPortare({
    required this.voce,
    required this.id,
    required this.spuntata,
    required this.creataIl,
  });

  final T voce;
  final String id;
  final bool spuntata;
  final DateTime creataIl;
}

/// La lista come si vede: prima quello che manca, poi quello che è già in
/// valigia. Le voci spuntate non spariscono, si spostano in fondo (regola 6).
class ListaOrdinata<T> {
  const ListaOrdinata(this.daMettere, this.inValigia);

  final List<VoceDaPortare<T>> daMettere;
  final List<VoceDaPortare<T>> inValigia;

  int get tutte => daMettere.length + inValigia.length;

  /// Quante sono in valigia, contando come sono adesso anche quelle appena
  /// toccate che restano un attimo al loro posto.
  int get fatte => [...daMettere, ...inValigia].where((v) => v.spuntata).length;

  /// Tutto in valigia: è il momento del timbro.
  bool get valigiaFatta => tutte > 0 && fatte == tutte;

  /// La prima che manca, per dire «Prossima: …».
  VoceDaPortare<T>? get prossima =>
      daMettere.where((v) => !v.spuntata).firstOrNull;
}

/// Mette in ordine le voci: in ciascun gruppo nell'ordine in cui sono nate,
/// così una voce aggiunta va in fondo a quelle da mettere e non salta in giro.
///
/// Le [trattenute] sono appena state spuntate, o la spunta è stata tolta:
/// restano un attimo dove erano prima del tocco, perché chi fa la valigia veda
/// che cosa ha toccato prima che la voce scenda (o risalga).
ListaOrdinata<T> ordinaVoci<T>(
  Iterable<VoceDaPortare<T>> voci, {
  Set<String> trattenute = const {},
}) {
  final ordinate = [...voci]
    ..sort((a, b) {
      final per = a.creataIl.compareTo(b.creataIl);
      return per != 0 ? per : a.id.compareTo(b.id);
    });
  // Un tocco cambia la spunta: finché è trattenuta, sta dove stava prima.
  bool inValigia(VoceDaPortare<T> v) =>
      trattenute.contains(v.id) ? !v.spuntata : v.spuntata;
  return ListaOrdinata(
    [
      for (final v in ordinate)
        if (!inValigia(v)) v,
    ],
    [
      for (final v in ordinate)
        if (inValigia(v)) v,
    ],
  );
}
