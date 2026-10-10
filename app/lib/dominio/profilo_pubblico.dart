/// Il profilo pubblico e la ricerca (5.3; 11-community; tela, 73–75 e
/// 108–110): i gusti, i viaggi che stanno sul profilo, che cosa due persone
/// hanno in comune.
///
/// Chi vede chi, e quali viaggi ci stanno, lo decide il server
/// (profilo_pubblico.sql): qui si legge quello che manda e si calcola quanto
/// serve a mostrarlo. Le regole di 11 che vengono dalle valutazioni
/// d'impatto (5.2) stanno lì, non qui: un'interfaccia che nasconde da sola non
/// nasconde niente (05).
library;

import 'itinerario.dart';
import 'periodo.dart';
import 'ricordo.dart';
import 'testo.dart';

// ─── I gusti ───────────────────────────────────────────────────────────────

/// Cosa piace in viaggio: le voci dell'itinerario, una lista chiusa (M6).
/// Il server ha la stessa lista: una voce nuova va in tutti e due i posti, e
/// solo se non dice una religione, la salute, l'orientamento o la politica.
List<Interesse> get gusti => Interesse.values;

/// Il nome di un gusto sul server.
String codiceGusto(Interesse gusto) => switch (gusto) {
  Interesse.vitaNotturna => 'vita_notturna',
  _ => gusto.name,
};

/// I gusti come li manda il server, nell'ordine della lista. Un nome che
/// l'app non conosce — una voce arrivata con una versione più nuova — si
/// salta.
List<Interesse> gustiDa(Object? valore) {
  final codici = {
    if (valore is List)
      for (final c in valore)
        if (c is String) c,
  };
  return [
    for (final g in gusti)
      if (codici.contains(codiceGusto(g))) g,
  ];
}

/// Il gusto con l'articolo, dopo «ama»: «il cibo», «l'arte e i musei».
String gustoConArticolo(Interesse gusto) => switch (gusto) {
  Interesse.arte => 'l\'arte e i musei',
  Interesse.cibo => 'il cibo',
  Interesse.storia => 'la storia',
  Interesse.natura => 'la natura',
  Interesse.panorami => 'i panorami',
  Interesse.shopping => 'lo shopping',
  Interesse.vitaNotturna => 'la vita notturna',
};

// ─── I viaggi sul profilo ─────────────────────────────────────────────────

/// Un viaggio come sta sul profilo pubblico: la meta, il mese in cui è
/// cominciato, quanti giorni, se è verificato o importato (M5). Le date non
/// ci sono: il server non le manda.
class ViaggioPubblico {
  const ViaggioPubblico({
    required this.citta,
    required this.paese,
    required this.mese,
    required this.periodo,
    required this.giorni,
    required this.verificato,
    required this.importato,
    this.viaggioId,
    this.sulProfilo = true,
  });

  factory ViaggioPubblico.daServer(Map<String, dynamic> r) => ViaggioPubblico(
    citta: r['citta'] as String?,
    paese: r['paese'] as String?,
    mese: DateTime.tryParse(r['mese'] as String? ?? ''),
    periodo: r['periodo'] as String?,
    giorni: (r['giorni'] as num?)?.toInt(),
    verificato: r['verificato'] == true,
    importato: r['importato'] == true,
    viaggioId: r['viaggio_id'] as String?,
    sulProfilo: r['sul_profilo'] != false,
  );

  final String? citta;
  final String? paese;

  /// Il primo giorno del mese in cui è cominciato; `null` per un importato.
  final DateTime? mese;

  /// Quando è stato un importato, come lo si è scritto: `agosto 2019`.
  final String? periodo;

  /// Quanti giorni; per un importato, se la persona se lo ricorda.
  final int? giorni;
  final bool verificato;
  final bool importato;

  /// Solo nel proprio profilo (tela, 109): quale viaggio, e se ci sta.
  final String? viaggioId;
  final bool sulProfilo;

  Meta get meta => (citta: citta, paese: paese);

  /// Quando è cominciato, per metterlo in ordine: il mese, o l'inizio del
  /// periodo di un importato.
  DateTime? get inizio => mese ?? Periodo.leggi(periodo)?.primoGiorno;

  ViaggioPubblico conSulProfilo(bool sulProfilo) => ViaggioPubblico(
    citta: citta,
    paese: paese,
    mese: mese,
    periodo: periodo,
    giorni: giorni,
    verificato: verificato,
    importato: importato,
    viaggioId: viaggioId,
    sulProfilo: sulProfilo,
  );
}

/// I viaggi nell'ordine del passaporto: dal più recente. Quelli di cui non si
/// sa quando in fondo.
List<ViaggioPubblico> inOrdine(Iterable<ViaggioPubblico> viaggi) =>
    viaggi.toList()..sort((a, b) {
      final (x, y) = (a.inizio, b.inizio);
      if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
      return y.compareTo(x);
    });

// ─── Il profilo ───────────────────────────────────────────────────────────

/// Un profilo com'è sulla parte pubblica (tela, 73), o il proprio con le
/// scelte dei viaggi (tela, 75 e 109).
class ProfiloPubblico {
  const ProfiloPubblico({
    required this.id,
    required this.nome,
    required this.dal,
    required this.gusti,
    required this.traguardi,
    required this.viaggi,
    this.attivo,
    this.tuttiIViaggi = const [],
  });

  factory ProfiloPubblico.daServer(Map<String, dynamic> r) => ProfiloPubblico(
    id: r['id'] as String,
    nome: r['nome'] as String? ?? '',
    dal: DateTime.tryParse(r['dal'] as String? ?? ''),
    gusti: gustiDa(r['gusti']),
    traguardi: (r['traguardi'] as num?)?.toInt() ?? 0,
    viaggi: inOrdine([
      for (final v in (r['viaggi'] as List? ?? const []))
        ViaggioPubblico.daServer(v as Map<String, dynamic>),
    ]),
    attivo: r['attivo'] as bool?,
    tuttiIViaggi: inOrdine([
      for (final v in (r['tutti_i_viaggi'] as List? ?? const []))
        ViaggioPubblico.daServer(v as Map<String, dynamic>),
    ]),
  );

  final String id;
  final String nome;

  /// Da quando è su Trolley: il mese.
  final DateTime? dal;
  final List<Interesse> gusti;
  final int traguardi;

  /// I viaggi sul profilo, dal più recente.
  final List<ViaggioPubblico> viaggi;

  /// Solo il proprio: se è acceso, e tutti i viaggi che ci possono stare.
  final bool? attivo;
  final List<ViaggioPubblico> tuttiIViaggi;

  /// I paesi dei viaggi sul profilo, una volta ciascuno, dal più recente.
  List<String> get paesi => paesiGrattati(viaggi.map((v) => v.meta));
}

// ─── Cosa avete in comune ─────────────────────────────────────────────────

/// I paesi visti da tutti e due e i gusti di tutti e due (tela, 73 e 74).
typedef InComune = ({List<String> paesi, List<Interesse> gusti});

/// Che cosa [altro] ha in comune con chi guarda, che ha visto [mieMete] —
/// tutti i suoi viaggi chiusi: lo sa solo il suo telefono — e a cui piace
/// [mieiGusti]. Dell'altro contano solo i viaggi sul suo profilo.
InComune inComune({
  required Iterable<Meta> mieMete,
  required Set<Interesse> mieiGusti,
  required ProfiloPubblico altro,
}) {
  final miei = paesiGrattati(mieMete).toSet();
  return (
    paesi: [
      for (final p in altro.paesi)
        if (miei.contains(p)) p,
    ],
    gusti: [
      for (final g in altro.gusti)
        if (mieiGusti.contains(g)) g,
    ],
  );
}

int quantiInComune(InComune c) => c.paesi.length + c.gusti.length;

// ─── Cercare ──────────────────────────────────────────────────────────────

/// Che cosa si cerca (tela, 74): una meta — un paese, o una città di quel
/// paese — e i gusti. Mai un nome (M2).
class Ricerca {
  const Ricerca({this.paese, this.citta, this.nomeMeta, this.gusti = const {}});

  /// Il codice del paese della meta.
  final String? paese;

  /// La città, se la meta è una città.
  final String? citta;

  /// Come si mostra la meta: «Kyoto», «Giappone».
  final String? nomeMeta;
  final Set<Interesse> gusti;

  /// Senza meta né gusti non si cerca: non si vede nessuno (M2).
  bool get vuota => paese == null && gusti.isEmpty;

  /// Per `viaggiatori_cercati` (07): che criteri, mai quali.
  String get criteri => switch ((paese != null, gusti.isNotEmpty)) {
    (true, true) => 'entrambi',
    (true, false) => 'meta',
    _ => 'gusti',
  };

  Ricerca conMeta({String? paese, String? citta, String? nome}) =>
      Ricerca(paese: paese, citta: citta, nomeMeta: nome, gusti: gusti);

  Ricerca conGusti(Set<Interesse> gusti) =>
      Ricerca(paese: paese, citta: citta, nomeMeta: nomeMeta, gusti: gusti);

  /// Il viaggio di [profilo] che risponde alla meta: il più recente nel
  /// paese, o in quella città.
  ViaggioPubblico? viaggioNellaMeta(ProfiloPubblico profilo) {
    if (paese == null) return null;
    final citta = this.citta;
    for (final v in profilo.viaggi) {
      if (v.paese != paese) continue;
      if (citta == null || normalizza(v.citta ?? '') == normalizza(citta)) {
        return v;
      }
    }
    return null;
  }

  /// I gusti cercati che piacciono anche a [profilo], nell'ordine della
  /// lista.
  List<Interesse> gustiTrovati(ProfiloPubblico profilo) => [
    for (final g in profilo.gusti)
      if (gusti.contains(g)) g,
  ];
}
