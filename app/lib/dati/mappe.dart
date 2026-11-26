/// La mappa e la ricerca dei luoghi (04-integrazioni.md, ADR-006, ADR-014)
/// dietro questa interfaccia: tutto di Google (CR-06). La mappa è il Maps
/// SDK sul telefono, che non si paga a visualizzazione; la ricerca e le
/// schede dei posti sono Google Places. La guida è in `guida.dart`. Nessuna
/// schermata parla con Google: sostituirlo è questo file, `guida.dart` e
/// la funzione `mappe`.
///
/// A Places non si parla dal telefono: passa dalla funzione `mappe` del
/// nostro server (supabase/functions/mappe), che tiene la chiave e fa
/// rispettare il tetto per persona, per viaggio e per giorno (U.2). Per
/// questo ogni chiamata dice di quale viaggio è. Dallo stesso tetto passano
/// le destinazioni della guida, prima di partire ([guidaConsentita]).
///
/// Cosa vede Places: il testo che si cerca, e il posto scelto. Non sa chi
/// è né per quale viaggio, e non vede il telefono: vede il server.
///
/// Ogni chiamata si paga: le ricerche, i posti, le schede e le destinazioni
/// si contano qui ([consumo]), con quelle che il tetto ha fermato, e le
/// schermate li registrano (07, `consumo_mappe`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../dominio/apertura.dart';
import '../dominio/mappa.dart';
import 'errori.dart';
import 'mappa_google.dart';

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

/// La scheda di un posto di Google, per il dettaglio di una tappa (tela,
/// 161): si mostra senza mappa, e non si tiene (ADR-014).
class SchedaPosto {
  const SchedaPosto({
    required this.id,
    this.posto,
    this.indirizzo,
    this.orari,
    this.apertoOra,
    this.cambiaAlle,
    this.descrizione,
    this.scarto,
    this.chiusoPerSempre = false,
    this.chiusoPerOra = false,
  });

  final String id;
  final Coordinate? posto;

  /// Quanto l'ora del posto è avanti sul tempo universale.
  final Duration? scarto;
  final String? indirizzo;

  /// Gli orari della settimana, nell'ora del posto.
  final OrariDiApertura? orari;

  /// Se adesso è aperto; `null` se Google non lo sa.
  final bool? apertoOra;

  /// Quando chiude, se è aperto, o quando apre, se è chiuso: nell'ora del
  /// posto.
  final DateTime? cambiaAlle;

  /// Due righe su che cos'è, scritte da Google.
  final String? descrizione;
  final bool chiusoPerSempre;
  final bool chiusoPerOra;
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

  // Uguali se disegnano la stessa linea: la mappa non la ridisegna.
  @override
  bool operator ==(Object other) =>
      other is LineaMappa &&
      other.id == id &&
      other.colore == colore &&
      other.spessore == spessore &&
      listEquals(other.punti, punti);

  @override
  int get hashCode => Object.hash(id, colore, spessore, Object.hashAll(punti));
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

/// Quanto si è chiesto a Google: le ricerche, i posti, le schede, le
/// destinazioni della guida. E quante chiamate il tetto ha fermato prima
/// che arrivassero a Google.
class ConsumoMappe {
  const ConsumoMappe({
    this.ricerche = 0,
    this.dettagli = 0,
    this.schede = 0,
    this.destinazioni = 0,
    this.fermati = 0,
  });

  /// I suggerimenti chiesti scrivendo.
  final int ricerche;

  /// I posti chiesti a Google: quello scelto, o l'indirizzo di una tappa.
  final int dettagli;

  /// Le schede dei posti, con orari e descrizione: le chiamate più care.
  final int schede;

  /// Le guide partite verso una tappa: ognuna è una destinazione del
  /// Navigation SDK, che si paga.
  final int destinazioni;
  final int fermati;

  bool get nullo =>
      ricerche == 0 &&
      dettagli == 0 &&
      schede == 0 &&
      destinazioni == 0 &&
      fermati == 0;

  ConsumoMappe operator -(ConsumoMappe prima) => ConsumoMappe(
    ricerche: ricerche - prima.ricerche,
    dettagli: dettagli - prima.dettagli,
    schede: schede - prima.schede,
    destinazioni: destinazioni - prima.destinazioni,
    fermati: fermati - prima.fermati,
  );

  /// Le proprietà dell'evento `consumo_mappe` (07): solo quante.
  Map<String, Object?> get proprieta => {
    'ricerche': ricerche,
    'dettagli': dettagli,
    'schede': schede,
    'destinazioni': destinazioni,
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

  /// La mappa del viaggio, con i suoi [segni] e le sue [linee] (CR-06,
  /// passo 2: la mappa di Google, sul telefono, che non si paga a
  /// riquadri). Comincia in [centro] a [zoom]; [margini] è lo spazio
  /// coperto da quello che le sta sopra, che la mappa lascia libero (anche
  /// per il marchio di Google). [zonaDelLogo], se c'è, è dove va il
  /// marchio, nell'angolo in basso: i [margini] valgono allora solo per
  /// inquadrare. Quando è pronta dà il suo [ControlloMappa].
  /// Non [interattiva]: non si sposta col dito (la mini mappa della tappa,
  /// dentro una pagina che scorre).
  Widget mappa(
    BuildContext context, {
    required String viaggioId,
    required List<SegnoMappa> segni,
    List<LineaMappa> linee = const [],
    required Coordinate centro,
    required double zoom,
    EdgeInsets margini = EdgeInsets.zero,
    EdgeInsets? zonaDelLogo,
    bool interattiva = true,
    required void Function(ControlloMappa controllo) onPronta,
    VoidCallback? onTocca,
  });

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

  /// La scheda del posto [id]: indirizzo, orari, descrizione (tela, 161).
  Future<SchedaPosto> scheda(String id, {required String viaggioId});

  /// Se si può partire con la guida verso una tappa: il server conta la
  /// destinazione sul tetto di oggi (U.2), perché ognuna si paga. Lo dice
  /// con un errore: senza rete, o al tetto.
  Future<void> guidaConsentita({required String viaggioId});
}

/// Il fornitore senza chiave: niente mappa, niente ricerca.
class MappeAssenti implements Mappe {
  const MappeAssenti();

  @override
  bool get disponibili => false;

  @override
  ConsumoMappe get consumo => const ConsumoMappe();

  @override
  Widget mappa(
    BuildContext context, {
    required String viaggioId,
    required List<SegnoMappa> segni,
    List<LineaMappa> linee = const [],
    required Coordinate centro,
    required double zoom,
    EdgeInsets margini = EdgeInsets.zero,
    EdgeInsets? zonaDelLogo,
    bool interattiva = true,
    required void Function(ControlloMappa controllo) onPronta,
    VoidCallback? onTocca,
  }) => const SizedBox.shrink();

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
  Future<SchedaPosto> scheda(String id, {required String viaggioId}) =>
      Future.error(const ErroreTrolley(_nonDisponibili));

  @override
  Future<void> guidaConsentita({required String viaggioId}) =>
      Future.error(const ErroreTrolley(_nonDisponibili));
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
const _tettoGuide = ErroreTrolley(
  'Per oggi, in questo viaggio, le guide sono finite.',
  codice: CodiciServer.tettoMappe,
);

/// La mappa di Google sul telefono, e la funzione `mappe` del nostro server
/// per i posti di Google e per contare le guide. Le risposte di Google si
/// leggono qui.
class MappeGoogle implements Mappe {
  MappeGoogle({
    required this.indirizzo,
    required this.chiavePubblica,
    required this.accesso,
    http.Client? client,
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

  var _ricerche = 0;
  var _dettagli = 0;
  var _schede = 0;
  var _destinazioni = 0;
  var _fermati = 0;

  @override
  bool get disponibili => indirizzo.isNotEmpty;

  @override
  ConsumoMappe get consumo => ConsumoMappe(
    ricerche: _ricerche,
    dettagli: _dettagli,
    schede: _schede,
    destinazioni: _destinazioni,
    fermati: _fermati,
  );

  Map<String, String> _intestazioni() => {
    'apikey': chiavePubblica,
    if (accesso() case final gettone?) 'authorization': 'Bearer $gettone',
  };

  @override
  Widget mappa(
    BuildContext context, {
    required String viaggioId,
    required List<SegnoMappa> segni,
    List<LineaMappa> linee = const [],
    required Coordinate centro,
    required double zoom,
    EdgeInsets margini = EdgeInsets.zero,
    EdgeInsets? zonaDelLogo,
    bool interattiva = true,
    required void Function(ControlloMappa controllo) onPronta,
    VoidCallback? onTocca,
  }) => MappaGoogle(
    segni: segni,
    linee: linee,
    centro: centro,
    zoom: zoom,
    margini: margini,
    zonaDelLogo: zonaDelLogo,
    interattiva: interattiva,
    onPronta: onPronta,
    onTocca: onTocca,
  );

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
  Future<SchedaPosto> scheda(String id, {required String viaggioId}) async {
    final json = await _chiedi(
      'scheda',
      viaggioId,
      {'id': id, 'lingua': 'it'},
      conta: () => _schede++,
      tetto: _tettoRicerche,
    );
    return schedaDaGoogle(json, id);
  }

  @override
  Future<void> guidaConsentita({required String viaggioId}) async {
    await _chiedi(
      'guida',
      viaggioId,
      const {},
      conta: () => _destinazioni++,
      tetto: _tettoGuide,
    );
  }

  /// Chiede alla funzione [cosa] — `cerca`, `posto`, `scheda` o `guida` —
  /// per il viaggio. I parametri vanno nel corpo, non nell'indirizzo: il
  /// testo cercato non finisce nei registri del server.
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

/// La scheda di un posto da una risposta di Google (`places/{id}` con
/// orari e descrizione). Le ore di [SchedaPosto.cambiaAlle] sono quelle del
/// posto: Google dà l'istante e lo scarto dal tempo universale.
SchedaPosto schedaDaGoogle(Map<String, dynamic> json, String id) {
  final dove = json['location'];
  final posto = dove is Map
      ? coordinate(
          (dove['latitude'] as num?)?.toDouble(),
          (dove['longitude'] as num?)?.toDouble(),
        )
      : null;
  final scarto = json['utcOffsetMinutes'];
  final adesso = json['currentOpeningHours'];
  bool? apertoOra;
  DateTime? cambiaAlle;
  if (adesso is Map) {
    final aperto = adesso['openNow'];
    if (aperto is bool) apertoOra = aperto;
    final istante = DateTime.tryParse(
      (aperto == true ? adesso['nextCloseTime'] : adesso['nextOpenTime'])
              as String? ??
          '',
    );
    if (istante != null && scarto is int) {
      cambiaAlle = istante.toUtc().add(Duration(minutes: scarto));
    }
  }
  final stato = json['businessStatus'];
  return SchedaPosto(
    id: _testo(json['id']) ?? id,
    posto: posto,
    indirizzo: _testo(json['formattedAddress']),
    orari: OrariDiApertura.daGoogle(json['regularOpeningHours']),
    apertoOra: apertoOra,
    cambiaAlle: cambiaAlle,
    descrizione: _testo((json['editorialSummary'] as Map?)?['text']),
    scarto: scarto is int ? Duration(minutes: scarto) : null,
    chiusoPerSempre: stato == 'CLOSED_PERMANENTLY',
    chiusoPerOra: stato == 'CLOSED_TEMPORARILY',
  );
}

String? _testo(Object? valore) {
  final t = valore is String ? valore.trim() : null;
  return t == null || t.isEmpty ? null : t;
}
