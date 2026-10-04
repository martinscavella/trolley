/// Le cose da portare (05-cose-da-portare.md): che cos'è una voce valida, in
/// che ordine si vede la lista, quanto è piena la valigia, chi porta cosa.
///
/// Le liste sono due: quella del viaggio, che vedono tutti e serve a dividersi
/// le cose, e quella personale, che vede solo chi la scrive (regole 1–3).
library;

/// Le due liste del modello dati (01-modello-dati.md, `voce_lista.tipo`).
enum TipoLista {
  /// La vedono tutti quelli del viaggio, e serve a dividersi le cose.
  viaggio,

  /// La vede solo chi la scrive, nemmeno il creatore del viaggio.
  personale;

  String get codice => name;
}

/// Se si vedono tutte e due le liste, con il selettore: quando nel viaggio
/// c'è qualcun altro, o quando la lista del viaggio ha già delle voci, che
/// non spariscono perché gli altri sono usciti. Da soli c'è la propria, e
/// basta: chi scrive per sé non deve scoprire dopo che altri leggono.
bool dueListe({required bool conAltri, required bool vociDelViaggio}) =>
    conAltri || vociDelViaggio;

/// Chi porta una voce del viaggio: qualcuno che è nel viaggio adesso, o
/// nessuno. Il server libera le voci di chi esce; se la copia è indietro, una
/// voce di chi non c'è più si vede già libera.
String? chiLaPorta(String? assegnatoA, Set<String> presenti) =>
    assegnatoA != null && presenti.contains(assegnatoA) ? assegnatoA : null;

/// Una voce del viaggio si sposta fra le proprie solo se è libera o la porti
/// tu: quella che porta un altro gli sparirebbe di mano. Una propria si
/// sposta sempre nella lista del viaggio.
bool siSposta({
  required TipoLista lista,
  required String? portaChi,
  required String io,
}) => lista == TipoLista.personale || portaChi == null || portaChi == io;

/// Che cosa rimette da mettere «…» in alto, per rifare la valigia al
/// ritorno: della propria lista tutto; di quella del viaggio solo quello che
/// porti tu, perché le altre spunte sono le valigie degli altri.
bool siRimetteDaMettere({
  required TipoLista lista,
  required bool spuntata,
  required String? portaChi,
  required String io,
}) => spuntata && (lista == TipoLista.personale || portaChi == io);

/// Le voci del viaggio tornate libere perché chi le portava l'ha lasciato,
/// per persona e nell'ordine in cui sono nate: l'avviso in cima alla lista
/// (05, casi limite; tela, 44). Le [viste] l'avviso le ha già dette.
Map<String, List<T>> vociLasciate<T>(
  Iterable<VoceLasciata<T>> voci, {
  Set<String> viste = const {},
}) {
  final ordinate = [...voci]
    ..sort((a, b) {
      final per = a.creataIl.compareTo(b.creataIl);
      return per != 0 ? per : a.id.compareTo(b.id);
    });
  final perChi = <String, List<T>>{};
  for (final v in ordinate) {
    if (v.lasciataDa == null || v.portaChi != null || viste.contains(v.id)) {
      continue;
    }
    (perChi[v.lasciataDa!] ??= []).add(v.voce);
  }
  return perChi;
}

/// Una voce del viaggio, quanto serve per dire se è tornata libera.
class VoceLasciata<T> {
  const VoceLasciata({
    required this.voce,
    required this.id,
    required this.lasciataDa,
    required this.portaChi,
    required this.creataIl,
  });

  final T voce;
  final String id;

  /// Chi la portava quando ha lasciato il viaggio; `null` se nessuno.
  final String? lasciataDa;

  /// Chi la porta adesso: presa da qualcuno, non è più tornata libera.
  final String? portaChi;
  final DateTime creataIl;
}

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
