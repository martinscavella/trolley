/// Mappe, percorsi e ricerca dei luoghi (04-integrazioni.md, ADR-006,
/// ADR-014) dietro questa interfaccia. La ricerca dei posti è di Google
/// Places (CR-06, passo 1); i riquadri e i percorsi sono ancora di Geoapify,
/// con i dati di OpenStreetMap, finché la mappa e la guida non passano a
/// Google. Nessuna schermata parla con loro: sostituirli è questo file.
///
/// Al fornitore non si parla dal telefono: tutto passa dalla funzione `mappe`
/// del nostro server (supabase/functions/mappe), che tiene la chiave e fa
/// rispettare il tetto per persona, per viaggio e per giorno (U.2). Per
/// questo ogni chiamata dice di quale viaggio è.
///
/// Cosa vede il fornitore: le zone di mappa che si guardano, il testo che si
/// cerca, e i due capi di un percorso — la posizione della persona solo
/// quando chiede di essere portata a una tappa (08, regola 7). Non sa chi è
/// né per quale viaggio, e non vede il telefono: vede il server.
///
/// Ogni chiamata si paga in crediti: i riquadri, le ricerche e i percorsi si
/// contano qui ([consumo]), con quelle che il tetto ha fermato, e le schermate
/// li registrano (07, `consumo_mappe`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

import '../dominio/mappa.dart';
import '../dominio/navigazione.dart';
import 'errori.dart';
import 'mappa_google.dart';

/// Lo stile dei riquadri, lo stesso della funzione `mappe` (ADR-006).
const stileRiquadri = 'klokantech-basic';

/// Un posto suggerito cercando: dove mettere una tappa. Di Google: il nome e
/// l'indirizzo si mostrano nell'elenco e non si tengono (ADR-014); dove sta
/// lo dice [Mappe.posto], quando lo si sceglie.
class Luogo {
  const Luogo({
    required this.id,
    required this.nome,
    this.indirizzo,
    this.tipo = TipoLuogo.posto,
  });

  /// Il `place_id` di Google: l'unica cosa del posto che la tappa tiene.
  final String id;

  /// «Livraria Lello», o la via se il posto non ha un nome.
  final String nome;

  /// «Rua das Carmelitas 144, Porto»; `null` se non c'è altro da dire.
  final String? indirizzo;
  final TipoLuogo tipo;
}

/// Un segno sulla mappa: dove sta, come si disegna, cosa fa toccarlo. Il
/// disegno è un nostro widget; la mappa di Google ne fa un'immagine.
class SegnoMappa {
  const SegnoMappa({
    required this.id,
    required this.posto,
    required this.disegno,
    required this.aspetto,
    this.lato = 48,
    this.onTap,
    this.sopra = false,
  });

  final String id;
  final Coordinate posto;
  final Widget disegno;

  /// Cosa cambia il disegno: due segni con lo stesso aspetto hanno la
  /// stessa immagine, che si fa una volta sola.
  final String aspetto;

  /// Il lato del quadrato del disegno, con il suo spazio per il dito.
  final double lato;
  final VoidCallback? onTap;

  /// Sopra gli altri: il segno scelto, la persona.
  final bool sopra;
}

/// Una linea sulla mappa: i tratti della giornata.
class LineaMappa {
  const LineaMappa({
    required this.id,
    required this.punti,
    required this.colore,
    this.spessore = 5,
  });

  final String id;
  final List<Coordinate> punti;
  final Color colore;
  final double spessore;
}

/// Comanda una mappa già pronta: inquadrare dei punti, andare in un posto.
abstract interface class ControlloMappa {
  /// Tutti i [punti] dentro, senza avvicinarsi oltre [zoomMassimo].
  Future<void> inquadra(List<Coordinate> punti, {double zoomMassimo = 16});

  /// Va in [posto], a [zoom].
  Future<void> vai(Coordinate posto, double zoom);
}

/// Che cosa si è trovato: un posto con un nome, un indirizzo, una zona.
enum TipoLuogo { posto, indirizzo, zona }

/// Dove sta un posto di Google, e il suo indirizzo: le coordinate si tengono
/// al massimo 30 giorni, l'indirizzo non si tiene (ADR-014).
class PostoTrovato {
  const PostoTrovato({required this.id, required this.posto, this.indirizzo});

  final String id;
  final Coordinate posto;
  final String? indirizzo;
}

/// Quanto si è chiesto al fornitore: i riquadri scaricati davvero (quelli
/// già in memoria non si pagano), le ricerche, i percorsi. E quante chiamate
/// il tetto ha fermato prima che arrivassero al fornitore.
class ConsumoMappe {
  const ConsumoMappe({
    this.riquadri = 0,
    this.ricerche = 0,
    this.dettagli = 0,
    this.percorsi = 0,
    this.fermati = 0,
  });

  final int riquadri;

  /// I suggerimenti chiesti scrivendo.
  final int ricerche;

  /// I posti chiesti a Google: quello scelto, o l'indirizzo di una tappa.
  final int dettagli;
  final int percorsi;
  final int fermati;

  bool get nullo =>
      riquadri == 0 &&
      ricerche == 0 &&
      dettagli == 0 &&
      percorsi == 0 &&
      fermati == 0;

  ConsumoMappe operator -(ConsumoMappe prima) => ConsumoMappe(
    riquadri: riquadri - prima.riquadri,
    ricerche: ricerche - prima.ricerche,
    dettagli: dettagli - prima.dettagli,
    percorsi: percorsi - prima.percorsi,
    fermati: fermati - prima.fermati,
  );

  /// Le proprietà dell'evento `consumo_mappe` (07): solo quante.
  Map<String, Object?> get proprieta => {
    'riquadri': riquadri,
    'ricerche': ricerche,
    'dettagli': dettagli,
    'percorsi': percorsi,
    'fermati': fermati,
  };
}

/// Ogni chiamata è per un viaggio, [viaggioId]: il tetto è per persona, per
/// viaggio e per giorno, e lo conta il server.
abstract interface class Mappe {
  /// Se il fornitore si può usare: senza la mappa degrada come senza rete,
  /// agli indirizzi da aprire nelle Mappe del telefono.
  bool get disponibili;

  /// Quanto si è chiesto da quando l'app è aperta.
  ConsumoMappe get consumo;

  /// I riquadri della mappa, da mettere sotto le tappe: per la navigazione,
  /// finché non passa a Google (CR-06, passo 4).
  Widget riquadri(BuildContext context, {required String viaggioId});

  /// La mappa del viaggio, con i suoi [segni] e le sue [linee] (CR-06,
  /// passo 2: la mappa di Google, sul telefono, che non si paga a
  /// riquadri). Comincia in [centro] a [zoom]; [margini] è lo spazio
  /// coperto da quello che le sta sopra, che la mappa lascia libero (anche
  /// per il marchio di Google). Quando è pronta dà il suo [ControlloMappa].
  Widget mappa(
    BuildContext context, {
    required String viaggioId,
    required List<SegnoMappa> segni,
    List<LineaMappa> linee = const [],
    required Coordinate centro,
    required double zoom,
    EdgeInsets margini = EdgeInsets.zero,
    required void Function(ControlloMappa controllo) onPronta,
    VoidCallback? onTocca,
  });

  /// Chi ringraziare sotto la mappa: lo chiedono il fornitore e i dati.
  String get attribuzione;

  /// Chi ringraziare sotto i posti trovati: «Google Maps», com'è, mai
  /// tradotto (condizioni di Google Places).
  String get attribuzioneRicerca;

  /// I posti che corrispondono a [testo], i più vicini a [vicinoA] prima.
  /// [sessione] lega i suggerimenti al posto che si sceglierà: per Google
  /// è una ricerca sola.
  Future<List<Luogo>> cerca(
    String testo, {
    required String viaggioId,
    Coordinate? vicinoA,
    String? sessione,
  });

  /// Dove sta il posto [id], e il suo indirizzo. Con la [sessione] della
  /// ricerca, quando lo si sceglie; senza, per mostrare l'indirizzo di una
  /// tappa.
  Future<PostoTrovato> posto(
    String id, {
    required String viaggioId,
    String? sessione,
  });

  /// Il percorso a piedi da [da] ad [a], con le indicazioni in italiano.
  Future<Percorso> percorsoAPiedi(
    Coordinate da,
    Coordinate a, {
    required String viaggioId,
  });
}

/// Il fornitore senza chiave: niente mappa, niente ricerca.
class MappeAssenti implements Mappe {
  const MappeAssenti();

  @override
  bool get disponibili => false;

  @override
  ConsumoMappe get consumo => const ConsumoMappe();

  @override
  Widget riquadri(BuildContext context, {required String viaggioId}) =>
      const SizedBox.shrink();

  @override
  Widget mappa(
    BuildContext context, {
    required String viaggioId,
    required List<SegnoMappa> segni,
    List<LineaMappa> linee = const [],
    required Coordinate centro,
    required double zoom,
    EdgeInsets margini = EdgeInsets.zero,
    required void Function(ControlloMappa controllo) onPronta,
    VoidCallback? onTocca,
  }) => const SizedBox.shrink();

  @override
  String get attribuzione => '';

  @override
  String get attribuzioneRicerca => '';

  @override
  Future<List<Luogo>> cerca(
    String testo, {
    required String viaggioId,
    Coordinate? vicinoA,
    String? sessione,
  }) => Future.error(const ErroreTrolley(_nonDisponibili));

  @override
  Future<PostoTrovato> posto(
    String id, {
    required String viaggioId,
    String? sessione,
  }) => Future.error(const ErroreTrolley(_nonDisponibili));

  @override
  Future<Percorso> percorsoAPiedi(
    Coordinate da,
    Coordinate a, {
    required String viaggioId,
  }) => Future.error(const ErroreTrolley(_nonDisponibili));
}

const _nonDisponibili = 'La mappa non è disponibile in questa versione.';
const _nonRisponde = 'La mappa non risponde. Riprova tra poco.';
const _senzaRete = ErroreTrolley(
  'Serve la connessione: senza, restano le Mappe del telefono.',
  serveLaRete: true,
);

/// Il tetto di oggi, per questo viaggio, è raggiunto (U.2): domani si
/// ricomincia, e intanto restano il nome scritto a mano e le Mappe del
/// telefono.
const _tettoRicerche = ErroreTrolley(
  'Per oggi, in questo viaggio, le ricerche sono finite: scrivi il posto a '
  'mano, o riprova domani.',
  codice: CodiciServer.tettoMappe,
);
const _tettoPercorsi = ErroreTrolley(
  'Per oggi, in questo viaggio, le strade calcolate sono finite.',
  codice: CodiciServer.tettoMappe,
);

/// La funzione `mappe` del nostro server: riquadri e percorsi di Geoapify,
/// posti di Google, dallo stesso posto. Le risposte sono quelle dei
/// fornitori, e si leggono qui.
class MappeGeoapify implements Mappe {
  MappeGeoapify({
    required this.indirizzo,
    required this.chiavePubblica,
    required this.accesso,
    http.Client? client,
    this._memoria,
  }) : _client = client ?? http.Client();

  /// Dove risponde la funzione: `https://<progetto>.supabase.co/functions/v1/mappe`.
  final String indirizzo;

  /// La chiave pubblicabile del progetto, che il server chiede a ogni
  /// richiesta.
  final String chiavePubblica;

  /// Il gettone d'accesso di chi è dentro, letto a ogni richiesta: scade e si
  /// rinnova.
  final String? Function() accesso;

  final http.Client _client;
  final MapCachingProvider? _memoria;

  var _riquadri = 0;
  var _ricerche = 0;
  var _dettagli = 0;
  var _percorsi = 0;
  var _fermati = 0;

  @override
  bool get disponibili => indirizzo.isNotEmpty;

  @override
  ConsumoMappe get consumo => ConsumoMappe(
    riquadri: _riquadri,
    ricerche: _ricerche,
    dettagli: _dettagli,
    percorsi: _percorsi,
    fermati: _fermati,
  );

  Map<String, String> _intestazioni() => {
    'apikey': chiavePubblica,
    if (accesso() case final gettone?) 'authorization': 'Bearer $gettone',
  };

  /// Uno solo per tutta l'app: tiene la connessione, conta, e mette
  /// l'accesso a ogni riquadro.
  late final _clientRiquadri = _AlServer(
    RetryClient(_client),
    _intestazioni,
    (stato) => stato == 429 ? _fermati++ : _riquadri++,
  );

  /// Il client con cui partono i riquadri, per le prove.
  @visibleForTesting
  http.Client get clientDeiRiquadri => _clientRiquadri;

  /// La memoria dei riquadri già visti, che non si scaricano (e non si
  /// pagano) due volte: una per tutti i viaggi, perché l'indirizzo di un
  /// riquadro non dice di quale viaggio è.
  late final _memoriaRiquadri =
      _memoria ??
      BuiltInMapCachingProvider.getOrCreateInstance(
        maxCacheSize: 200 * 1000 * 1000,
      );

  /// Un fornitore di riquadri per viaggio, che dice al server di quale.
  final _fornitori = <String, NetworkTileProvider>{};

  @override
  Widget riquadri(BuildContext context, {required String viaggioId}) =>
      TileLayer(
        // Lo stile lo sceglie il server (funzione `mappe`): qui il suo nome
        // serve solo a non riusare i riquadri salvati di quello di prima.
        urlTemplate:
            '$indirizzo/riquadro/{z}/{x}/{y}{r}.png?stile=$stileRiquadri',
        retinaMode: RetinaMode.isHighDensity(context),
        maxNativeZoom: 20,
        userAgentPackageName: 'com.aionlabs.trolley',
        tileProvider: _fornitori.putIfAbsent(
          viaggioId,
          () => NetworkTileProvider(
            httpClient: _clientRiquadri,
            headers: {'x-viaggio': viaggioId},
            cachingProvider: _memoriaRiquadri,
          ),
        ),
      );

  @override
  Widget mappa(
    BuildContext context, {
    required String viaggioId,
    required List<SegnoMappa> segni,
    List<LineaMappa> linee = const [],
    required Coordinate centro,
    required double zoom,
    EdgeInsets margini = EdgeInsets.zero,
    required void Function(ControlloMappa controllo) onPronta,
    VoidCallback? onTocca,
  }) => MappaGoogle(
    segni: segni,
    linee: linee,
    centro: centro,
    zoom: zoom,
    margini: margini,
    onPronta: onPronta,
    onTocca: onTocca,
  );

  @override
  String get attribuzione =>
      'Powered by Geoapify · © OpenMapTiles · © OpenStreetMap';

  @override
  String get attribuzioneRicerca => 'Google Maps';

  @override
  Future<List<Luogo>> cerca(
    String testo, {
    required String viaggioId,
    Coordinate? vicinoA,
    String? sessione,
  }) async {
    final cercato = testo.trim();
    if (cercato.isEmpty) return const [];
    // La vicinanza pesa, ma non chiude: una gita in giornata ci sta, e se
    // vicino non c'è niente si trova lontano.
    final json = await _chiedi(
      'cerca',
      viaggioId,
      {
        'testo': cercato,
        'lingua': 'it',
        'sessione': ?sessione,
        if (vicinoA != null) ...{
          'lat': vicinoA.lat,
          'lon': vicinoA.lon,
          'raggio': raggioDiRicerca,
        },
      },
      conta: () => _ricerche++,
      tetto: _tettoRicerche,
    );
    return luoghiDaGoogle(json);
  }

  /// Quanto lontano dalla zona del viaggio pesa la vicinanza: una gita in
  /// giornata ci sta.
  static const raggioDiRicerca = 40000.0;

  @override
  Future<PostoTrovato> posto(
    String id, {
    required String viaggioId,
    String? sessione,
  }) async {
    final json = await _chiedi(
      'posto',
      viaggioId,
      {'id': id, 'lingua': 'it', 'sessione': ?sessione},
      conta: () => _dettagli++,
      tetto: _tettoRicerche,
    );
    final trovato = postoDaGoogle(json, id);
    if (trovato == null) throw const ErroreTrolley(_nonRisponde);
    return trovato;
  }

  @override
  Future<Percorso> percorsoAPiedi(
    Coordinate da,
    Coordinate a, {
    required String viaggioId,
  }) async {
    final json = await _chiedi(
      'percorso',
      viaggioId,
      {
        'waypoints': '${da.lat},${da.lon}|${a.lat},${a.lon}',
        'mode': 'walk',
        'lang': 'it',
        // Senza, le indicazioni hanno il testo ma non il tipo di svolta.
        'details': 'instruction_details',
      },
      conta: () => _percorsi++,
      tetto: _tettoPercorsi,
    );
    final percorso = percorsoDaGeoapify(json);
    if (percorso == null) throw const ErroreTrolley(_nonRisponde);
    return percorso;
  }

  /// Chiede alla funzione [cosa] — `cerca` o `percorso` — per il viaggio. I
  /// parametri vanno nel corpo, non nell'indirizzo: il testo cercato e i
  /// capi di un percorso non finiscono nei registri del server.
  Future<Map<String, dynamic>> _chiedi(
    String cosa,
    String viaggioId,
    Map<String, Object> parametri, {
    required void Function() conta,
    required ErroreTrolley tetto,
  }) async {
    final http.Response risposta;
    try {
      risposta = await _client
          .post(
            Uri.parse('$indirizzo/$cosa'),
            headers: {..._intestazioni(), 'content-type': 'application/json'},
            body: jsonEncode({'viaggio': viaggioId, 'parametri': parametri}),
          )
          .timeout(const Duration(seconds: 10));
    } on SocketException {
      throw _senzaRete;
    } on TimeoutException {
      throw _senzaRete;
    } on http.ClientException {
      throw _senzaRete;
    }
    if (risposta.statusCode == 429) {
      _fermati++;
      throw tetto;
    }
    conta();
    if (risposta.statusCode != 200) throw const ErroreTrolley(_nonRisponde);
    final corpo = jsonDecode(utf8.decode(risposta.bodyBytes));
    if (corpo is! Map<String, dynamic>) {
      throw const ErroreTrolley(_nonRisponde);
    }
    return corpo;
  }
}

/// Il client dei riquadri: mette l'accesso a ogni richiesta, e conta quelle
/// che tornano — fermate dal tetto (429) o arrivate al fornitore.
class _AlServer extends http.BaseClient {
  _AlServer(this._dentro, this._intestazioni, this._conta);

  final http.Client _dentro;
  final Map<String, String> Function() _intestazioni;
  final void Function(int stato) _conta;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers.addAll(_intestazioni());
    final risposta = await _dentro.send(request);
    _conta(risposta.statusCode);
    return risposta;
  }

  @override
  void close() => _dentro.close();
}

/// I posti di una risposta di Google (`places:autocomplete`). Le ricerche
/// suggerite, senza un posto, si scartano.
List<Luogo> luoghiDaGoogle(Map<String, dynamic> json) {
  final suggerimenti = json['suggestions'];
  if (suggerimenti is! List) return const [];
  final luoghi = <Luogo>[];
  for (final s in suggerimenti.whereType<Map<String, dynamic>>()) {
    final p = s['placePrediction'];
    if (p is! Map<String, dynamic>) continue;
    final id = _testo(p['placeId']);
    final formato = p['structuredFormat'];
    if (id == null || formato is! Map<String, dynamic>) continue;
    final nome = _testo((formato['mainText'] as Map?)?['text']);
    if (nome == null) continue;
    final indirizzo = _testo((formato['secondaryText'] as Map?)?['text']);
    final tipi = (p['types'] as List?)?.whereType<String>().toSet() ?? {};
    if (luoghi.any((l) => l.id == id)) continue;
    luoghi.add(
      Luogo(id: id, nome: nome, indirizzo: indirizzo, tipo: tipoDaGoogle(tipi)),
    );
  }
  return luoghi;
}

/// Che cosa è un posto, dai tipi di Google: una zona (città, quartiere,
/// regione), un indirizzo (una via, un civico), o un posto con un nome.
TipoLuogo tipoDaGoogle(Set<String> tipi) {
  const zone = {
    'locality',
    'sublocality',
    'neighborhood',
    'administrative_area_level_1',
    'administrative_area_level_2',
    'administrative_area_level_3',
    'country',
    'postal_code',
    'political',
  };
  const indirizzi = {
    'route',
    'street_address',
    'premise',
    'subpremise',
    'intersection',
    'plus_code',
  };
  if (tipi.contains('establishment') || tipi.contains('point_of_interest')) {
    return TipoLuogo.posto;
  }
  if (tipi.any(indirizzi.contains)) return TipoLuogo.indirizzo;
  if (tipi.any(zone.contains)) return TipoLuogo.zona;
  return TipoLuogo.posto;
}

/// Dove sta il posto di una risposta di Google (`places/{id}`); `null` se
/// non ha coordinate.
PostoTrovato? postoDaGoogle(Map<String, dynamic> json, String id) {
  final dove = json['location'];
  if (dove is! Map) return null;
  final posto = coordinate(
    (dove['latitude'] as num?)?.toDouble(),
    (dove['longitude'] as num?)?.toDouble(),
  );
  if (posto == null) return null;
  return PostoTrovato(
    id: _testo(json['id']) ?? id,
    posto: posto,
    indirizzo: _testo(json['formattedAddress']),
  );
}

String? _testo(Object? valore) {
  final t = valore is String ? valore.trim() : null;
  return t == null || t.isEmpty ? null : t;
}

/// Il percorso di una risposta di Geoapify (`/v1/routing`, GeoJSON). Le
/// tappe intermedie non ci sono: un tratto solo, dal punto in cui si è alla
/// tappa. `null` se la risposta non ha un percorso.
Percorso? percorsoDaGeoapify(Map<String, dynamic> json) {
  final caratteristiche = json['features'];
  if (caratteristiche is! List || caratteristiche.isEmpty) return null;
  final primo = caratteristiche.first;
  if (primo is! Map<String, dynamic>) return null;
  final proprieta = primo['properties'];
  final geometria = primo['geometry'];
  if (proprieta is! Map<String, dynamic> || geometria is! Map) return null;

  // Una linea per ogni tratto fra due punti di passaggio; gli indici dei
  // passi contano dall'inizio della loro linea.
  final linee = switch (geometria['type']) {
    'MultiLineString' => geometria['coordinates'] as List? ?? const [],
    'LineString' => [geometria['coordinates']],
    _ => const [],
  };
  final punti = <Coordinate>[];
  final inizioLinea = <int>[];
  for (final linea in linee) {
    inizioLinea.add(punti.length);
    for (final c in (linea as List? ?? const [])) {
      if (c is List && c.length >= 2) {
        final p = coordinate(
          (c[1] as num).toDouble(),
          (c[0] as num).toDouble(),
        );
        if (p != null) punti.add(p);
      }
    }
  }
  if (punti.length < 2) return null;

  final passi = <Passo>[];
  final tratti = proprieta['legs'] as List? ?? const [];
  for (final (i, tratto) in tratti.indexed) {
    final scarto = i < inizioLinea.length ? inizioLinea[i] : 0;
    for (final s in ((tratto as Map)['steps'] as List? ?? const [])) {
      final passo = s as Map;
      final istruzione = passo['instruction'] as Map? ?? const {};
      passi.add(
        Passo(
          istruzione: _testo(istruzione['text']) ?? '',
          manovra: manovraDaGeoapify(istruzione['type'] as String?),
          da: scarto + ((passo['from_index'] as num?)?.toInt() ?? 0),
          a: scarto + ((passo['to_index'] as num?)?.toInt() ?? 0),
          metri: (passo['distance'] as num?)?.toDouble() ?? 0,
        ),
      );
    }
  }

  return Percorso(
    punti: punti,
    passi: passi,
    metri: (proprieta['distance'] as num?)?.toDouble() ?? 0,
    durata: Duration(seconds: ((proprieta['time'] as num?) ?? 0).round()),
  );
}

/// I tipi di indicazione di Geoapify, nelle manovre dell'app.
Manovra manovraDaGeoapify(String? tipo) => switch (tipo) {
  'StartAt' || 'StartAtRight' || 'StartAtLeft' => Manovra.partenza,
  'DestinationReached' ||
  'DestinationReachedRight' ||
  'DestinationReachedLeft' => Manovra.arrivo,
  'SlightRight' => Manovra.leggermenteADestra,
  'Right' || 'ExitRight' => Manovra.aDestra,
  'SharpRight' => Manovra.strettaADestra,
  'SlightLeft' => Manovra.leggermenteASinistra,
  'Left' || 'ExitLeft' => Manovra.aSinistra,
  'SharpLeft' => Manovra.strettaASinistra,
  'TurnAroundRight' || 'TurnAroundLeft' => Manovra.inversione,
  'StayRight' || 'MergeRight' => Manovra.tieniLaDestra,
  'StayLeft' || 'MergeLeft' => Manovra.tieniLaSinistra,
  'Roundabout' => Manovra.rotonda,
  'FerryEnter' ||
  'FerryExit' ||
  'Transit' ||
  'TransitTransfer' ||
  'TransitRemainOn' ||
  'TransitConnectionStart' ||
  'TransitConnectionTransfer' ||
  'TransitConnectionDestination' ||
  'PostTransitConnectionDestination' => Manovra.mezzi,
  _ => Manovra.dritto,
};
