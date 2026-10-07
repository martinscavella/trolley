/// Mappe, percorsi e ricerca dei luoghi (04-integrazioni.md, ADR-006): un
/// fornitore solo — Geoapify, con i dati di OpenStreetMap — dietro questa
/// interfaccia. Nessuna schermata parla con lui: sostituirlo è questo file.
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

/// Un posto trovato cercando: dove mettere una tappa.
class Luogo {
  const Luogo({
    required this.nome,
    required this.posto,
    this.indirizzo,
    this.tipo = TipoLuogo.posto,
  });

  /// «Livraria Lello», o la via se il posto non ha un nome.
  final String nome;

  /// «Rua das Carmelitas 144, Porto»; `null` se non c'è altro da dire.
  final String? indirizzo;
  final Coordinate posto;
  final TipoLuogo tipo;

  /// Cosa scrivere nella tappa come «Dove»: l'indirizzo se il nome è già il
  /// titolo della tappa, altrimenti il nome con l'indirizzo.
  String dove({String? titolo}) {
    final i = indirizzo;
    if (i == null || i.isEmpty) return nome;
    final stesso =
        titolo != null && titolo.trim().toLowerCase() == nome.toLowerCase();
    return stesso || i.startsWith(nome) ? i : '$nome, $i';
  }
}

/// Che cosa si è trovato: un posto con un nome, un indirizzo, una zona.
enum TipoLuogo { posto, indirizzo, zona }

/// Quanto si è chiesto al fornitore: i riquadri scaricati davvero (quelli
/// già in memoria non si pagano), le ricerche, i percorsi. E quante chiamate
/// il tetto ha fermato prima che arrivassero al fornitore.
class ConsumoMappe {
  const ConsumoMappe({
    this.riquadri = 0,
    this.ricerche = 0,
    this.percorsi = 0,
    this.fermati = 0,
  });

  final int riquadri;
  final int ricerche;
  final int percorsi;
  final int fermati;

  bool get nullo =>
      riquadri == 0 && ricerche == 0 && percorsi == 0 && fermati == 0;

  ConsumoMappe operator -(ConsumoMappe prima) => ConsumoMappe(
    riquadri: riquadri - prima.riquadri,
    ricerche: ricerche - prima.ricerche,
    percorsi: percorsi - prima.percorsi,
    fermati: fermati - prima.fermati,
  );

  /// Le proprietà dell'evento `consumo_mappe` (07): solo quante.
  Map<String, Object?> get proprieta => {
    'riquadri': riquadri,
    'ricerche': ricerche,
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

  /// I riquadri della mappa, da mettere sotto le tappe.
  Widget riquadri(BuildContext context, {required String viaggioId});

  /// Chi ringraziare sotto la mappa: lo chiedono il fornitore e i dati.
  String get attribuzione;

  /// I posti che corrispondono a [testo], i più vicini a [vicinoA] prima.
  Future<List<Luogo>> cerca(
    String testo, {
    required String viaggioId,
    Coordinate? vicinoA,
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
  String get attribuzione => '';

  @override
  Future<List<Luogo>> cerca(
    String testo, {
    required String viaggioId,
    Coordinate? vicinoA,
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

/// Geoapify, attraverso la funzione `mappe` del nostro server: riquadri,
/// ricerca e percorsi dallo stesso posto. Le risposte sono quelle di
/// Geoapify, e si leggono qui.
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
  var _percorsi = 0;
  var _fermati = 0;

  @override
  bool get disponibili => indirizzo.isNotEmpty;

  @override
  ConsumoMappe get consumo => ConsumoMappe(
    riquadri: _riquadri,
    ricerche: _ricerche,
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
        urlTemplate: '$indirizzo/riquadro/{z}/{x}/{y}{r}.png',
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
  String get attribuzione =>
      'Powered by Geoapify · © OpenMapTiles · © OpenStreetMap';

  @override
  Future<List<Luogo>> cerca(
    String testo, {
    required String viaggioId,
    Coordinate? vicinoA,
  }) async {
    final cercato = testo.trim();
    if (cercato.isEmpty) return const [];
    Future<List<Luogo>> chiedi({required bool soloQui}) async {
      final json = await _chiedi(
        'cerca',
        viaggioId,
        {
          'text': cercato,
          'lang': 'it',
          'limit': '8',
          'format': 'json',
          if (vicinoA != null) ...{
            'bias': 'proximity:${vicinoA.lon},${vicinoA.lat}',
            if (soloQui)
              'filter':
                  'circle:${vicinoA.lon},${vicinoA.lat},${raggioDiRicerca.round()}',
          },
        },
        conta: () => _ricerche++,
        tetto: _tettoRicerche,
      );
      return luoghiDaGeoapify(json);
    }

    // La vicinanza da sola pesa poco: «majestic» darebbe gli Stati Uniti
    // prima del caffè di Porto. Si cerca nella zona del viaggio, e solo se
    // lì non c'è niente, ovunque (una ricerca in più).
    if (vicinoA == null) return chiedi(soloQui: false);
    final qui = await chiedi(soloQui: true);
    return qui.isNotEmpty ? qui : chiedi(soloQui: false);
  }

  /// Quanto lontano dalla zona del viaggio si cerca prima: una gita in
  /// giornata ci sta.
  static const raggioDiRicerca = 40000.0;

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
    Map<String, String> parametri, {
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

/// I posti di una risposta di Geoapify (`/v1/geocode/autocomplete`,
/// `format=json`). Quelli senza coordinate si scartano.
List<Luogo> luoghiDaGeoapify(Map<String, dynamic> json) {
  final risultati = json['results'];
  if (risultati is! List) return const [];
  final luoghi = <Luogo>[];
  for (final r in risultati.whereType<Map<String, dynamic>>()) {
    final posto = coordinate(
      (r['lat'] as num?)?.toDouble(),
      (r['lon'] as num?)?.toDouble(),
    );
    if (posto == null) continue;
    final tipo = switch (r['result_type']) {
      'amenity' => TipoLuogo.posto,
      'building' || 'street' => TipoLuogo.indirizzo,
      _ => TipoLuogo.zona,
    };
    final via = _testo(r['street']);
    final civico = _testo(r['housenumber']);
    final citta =
        _testo(r['city']) ?? _testo(r['town']) ?? _testo(r['village']);
    final strada = via == null ? null : [via, ?civico].join(' ');
    final nome =
        _testo(r['name']) ??
        strada ??
        _testo(r['address_line1']) ??
        _testo(r['formatted']);
    if (nome == null) continue;
    final indirizzo = [
      if (strada != null && strada != nome) strada,
      if (citta != null && citta != nome) citta,
    ].join(', ');
    final paese = _testo(r['country']);
    final dove = indirizzo.isNotEmpty
        ? indirizzo
        : (paese != null && paese != nome ? paese : null);
    // Lo stesso posto con più ingressi: uno basta.
    if (luoghi.any((l) => l.nome == nome && l.indirizzo == dove)) continue;
    luoghi.add(Luogo(nome: nome, indirizzo: dove, posto: posto, tipo: tipo));
  }
  return luoghi;
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
