/// Quello che serve a più test: una rete comandabile, un server finto in
/// memoria, e il modo di montare una schermata con i suoi servizi.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;
import 'package:trolley/aspetto/tema.dart';
import 'package:trolley/configurazione.dart';
import 'package:trolley/dati/archivio.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/destinazioni.dart';
import 'package:trolley/dati/rete.dart';
import 'package:trolley/invito/ingresso_da_invito.dart';
import 'package:trolley/misurazione/misurazione.dart';
import 'package:trolley/servizi.dart';

/// Una rete che si accende e si spegne dal test.
class ReteFinta implements Rete {
  ReteFinta({this._disponibile = true});

  bool _disponibile;
  final _cambi = StreamController<bool>.broadcast();

  @override
  bool get disponibile => _disponibile;

  set disponibile(bool valore) {
    if (valore == _disponibile) return;
    _disponibile = valore;
    _cambi.add(valore);
  }

  @override
  late final Stream<bool> cambi = _cambi.stream;

  @override
  void registraEsito({required bool raggiunto}) => disponibile = raggiunto;

  Future<void> chiudi() => _cambi.close();
}

/// Un ingresso da invito che si comanda dal test, al posto dei link veri.
class IngressoFinto implements IngressoDaInvito {
  final controllo = StreamController<String>.broadcast();

  @override
  Stream<String> get codici => controllo.stream;
}

const idDiProva = '11111111-1111-4111-8111-111111111111';
const _json = {'content-type': 'application/json; charset=utf-8'};
const _istante = '2026-09-30T20:45:18.123456+00:00';

/// Una riga di `viaggio` come la restituisce il server.
Map<String, Object?> rigaViaggio(
  String id, {
  String stato = 'idea',
  int versione = 1,
  String? citta = 'Porto',
  String? paese = 'PT',
  String? periodo,
  String? inizio,
  String? fine,
  String? arrivo,
  String? partenza,
  String creatoIl = _istante,
}) => {
  'id': id,
  'stato': stato,
  'destinazione_citta': citta,
  'destinazione_paese': paese,
  'periodo_approssimativo': periodo,
  'data_inizio': inizio,
  'data_fine': fine,
  'ora_arrivo': arrivo ?? (inizio == null ? null : '10:00:00'),
  'ora_partenza': partenza ?? (inizio == null ? null : '18:00:00'),
  'creatore_id': idDiProva,
  'importato': false,
  'verificato': false,
  'verifica_per_deroga': false,
  'creato_da': idDiProva,
  'creato_il': creatoIl,
  'modificato_il': creatoIl,
  'eliminato_il': null,
  'versione': versione,
};

Map<String, Object?> rigaGiorno(
  String viaggio,
  String data,
  String inizio,
  String fine, {
  String? id,
}) => {
  'id': id ?? 'g-$viaggio-$data',
  'viaggio_id': viaggio,
  'data': data,
  'finestra_inizio': inizio,
  'finestra_fine': fine,
  'creato_da': idDiProva,
  'creato_il': _istante,
  'modificato_il': _istante,
  'eliminato_il': null,
  'versione': 1,
};

Map<String, Object?> rigaPartecipazione(String viaggio) => {
  'id': 'p-$viaggio',
  'viaggio_id': viaggio,
  'utente_id': idDiProva,
  'ruolo': 'creatore',
  'stato': 'attivo',
  'creato_da': idDiProva,
  'creato_il': _istante,
  'modificato_il': _istante,
  'eliminato_il': null,
  'versione': 1,
};

/// Il server in memoria: le tabelle del viaggio e le funzioni che l'app
/// chiama, con il controllo di versione. Le regole di accesso non ci sono:
/// quelle si provano in supabase/tests, sul server vero.
class ServerFinto {
  ServerFinto([this.rete]);

  /// Se c'è, e dice che la rete manca, il server non risponde: come quando
  /// il telefono è offline.
  final ReteFinta? rete;

  final viaggi = <Map<String, Object?>>[];
  final giorni = <Map<String, Object?>>[];
  final partecipazioni = <Map<String, Object?>>[];
  final richieste = <http.Request>[];

  /// Percorsi con una risposta data dal test, che vince sulle altre.
  final percorsi = <String, Future<http.Response> Function(http.Request)>{};

  late final supabase = SupabaseClient(
    'http://localhost',
    'chiave-finta',
    httpClient: MockClient(_rispondi),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    postgrestOptions: opzioniDelServer,
  );

  List<http.Request> chiamate(String metodo, String percorso) => [
    for (final r in richieste)
      if (r.method == metodo && r.url.path == percorso) r,
  ];

  Future<http.Response> _rispondi(http.Request r) async {
    richieste.add(r);
    if (rete?.disponibile == false) {
      throw const SocketException('nessuna rete');
    }
    final chiave = '${r.method} ${r.url.path}';
    final data = await (percorsi[chiave]?.call(r) ?? _comeIlVero(r, chiave));
    // Il client di postgrest rilegge la richiesta dalla risposta.
    return http.Response(
      data.body,
      data.statusCode,
      headers: data.headers,
      request: r,
    );
  }

  Future<http.Response> _comeIlVero(http.Request r, String chiave) async {
    switch (chiave) {
      case 'GET /rest/v1/viaggio':
        return risposta(viaggi);
      case 'GET /rest/v1/partecipazione':
        return risposta(partecipazioni);
      case 'GET /rest/v1/giorno':
        return risposta([
          for (final g in giorni)
            if (g['eliminato_il'] == null) g,
        ]);
      case 'POST /rest/v1/rpc/crea_viaggio':
        final c = _corpo(r);
        final id = c['p_id'] as String;
        final conDate = c['p_data_inizio'] != null;
        viaggi.add(
          rigaViaggio(
            id,
            stato: conDate ? 'definito' : 'idea',
            citta: c['p_destinazione_citta'] as String?,
            paese: c['p_destinazione_paese'] as String?,
            periodo: conDate ? null : c['p_periodo'] as String?,
            inizio: c['p_data_inizio'] as String?,
            fine: c['p_data_fine'] as String?,
            arrivo: c['p_ora_arrivo'] as String?,
            partenza: c['p_ora_partenza'] as String?,
            creatoIl: DateTime.now().toUtc().toIso8601String(),
          ),
        );
        partecipazioni.add(rigaPartecipazione(id));
        _applicaGiorni(id, c['p_giorni'] as List);
        return risposta(_righe(id));
      case 'POST /rest/v1/rpc/programma_viaggio':
        final c = _corpo(r);
        final id = c['p_viaggio'] as String;
        final viaggio = _viaggio(id);
        if (viaggio == null) return _errore('TR404', 'viaggio non trovato');
        if (viaggio['versione'] != c['p_versione']) {
          return _errore('TR409', 'versione superata');
        }
        viaggio
          ..['stato'] =
              viaggio['stato'] == 'idea' || viaggio['stato'] == 'archiviato'
              ? 'definito'
              : viaggio['stato']
          ..['periodo_approssimativo'] = null
          ..['data_inizio'] = c['p_data_inizio']
          ..['data_fine'] = c['p_data_fine']
          ..['ora_arrivo'] = c['p_ora_arrivo']
          ..['ora_partenza'] = c['p_ora_partenza']
          ..['versione'] = (viaggio['versione']! as int) + 1;
        _applicaGiorni(id, c['p_giorni'] as List);
        return risposta(_righe(id));
      case 'POST /rest/v1/rpc/torna_idea':
        final c = _corpo(r);
        final id = c['p_viaggio'] as String;
        final viaggio = _viaggio(id);
        if (viaggio == null || viaggio['stato'] != 'definito') {
          return _errore('TR404', 'viaggio non trovato');
        }
        if (viaggio['versione'] != c['p_versione']) {
          return _errore('TR409', 'versione superata');
        }
        viaggio
          ..['stato'] = 'idea'
          ..['periodo_approssimativo'] = c['p_periodo']
          ..['data_inizio'] = null
          ..['data_fine'] = null
          ..['ora_arrivo'] = null
          ..['ora_partenza'] = null
          ..['versione'] = (viaggio['versione']! as int) + 1;
        _applicaGiorni(id, const []);
        return risposta(_righe(id));
      case 'PATCH /rest/v1/viaggio':
        final filtri = r.url.queryParameters;
        final id = filtri['id']!.replaceFirst('eq.', '');
        final stato = filtri['stato']?.replaceFirst('eq.', '');
        final viaggio = _viaggio(id);
        if (viaggio == null || (stato != null && viaggio['stato'] != stato)) {
          return risposta(const []);
        }
        final valori = _corpo(r);
        if (valori['versione'] != viaggio['versione']) {
          return _errore('TR409', 'versione superata');
        }
        viaggio
          ..addAll(valori)
          ..['versione'] = (valori['versione']! as int) + 1;
        return risposta([viaggio]);
      case 'POST /rest/v1/invito':
        return risposta([
          {'token': 'ABCD2345'},
        ], 201);
      case 'POST /rest/v1/evento':
        return http.Response('', 201);
    }
    return risposta(const []);
  }

  Map<String, Object?>? _viaggio(String id) =>
      viaggi.where((v) => v['id'] == id).firstOrNull;

  /// Come privato.applica_giorni: i giorni che escono si marcano, quelli
  /// che tornano riprendono la loro riga.
  void _applicaGiorni(String viaggio, List<dynamic> nuovi) {
    final date = {for (final n in nuovi) (n as Map)['data']};
    for (final g in giorni.where((g) => g['viaggio_id'] == viaggio)) {
      if (!date.contains(g['data'])) g['eliminato_il'] ??= _istante;
    }
    for (final n in nuovi.cast<Map<String, dynamic>>()) {
      final esistente = giorni
          .where((g) => g['viaggio_id'] == viaggio && g['data'] == n['data'])
          .firstOrNull;
      if (esistente == null) {
        giorni.add(
          rigaGiorno(viaggio, n['data'], n['inizio'], n['fine'], id: n['id']),
        );
      } else {
        esistente
          ..['finestra_inizio'] = n['inizio']
          ..['finestra_fine'] = n['fine']
          ..['eliminato_il'] = null;
      }
    }
  }

  Map<String, Object?> _righe(String viaggio) => {
    'viaggio': _viaggio(viaggio),
    'giorni': [
      for (final g in giorni)
        if (g['viaggio_id'] == viaggio && g['eliminato_il'] == null) g,
    ]..sort((a, b) => (a['data']! as String).compareTo(b['data']! as String)),
    'partecipazioni': [
      for (final p in partecipazioni)
        if (p['viaggio_id'] == viaggio) p,
    ],
  };

  static Map<String, dynamic> _corpo(http.Request r) =>
      jsonDecode(r.body) as Map<String, dynamic>;

  static http.Response _errore(String codice, String messaggio) => risposta({
    'code': codice,
    'message': messaggio,
    'details': null,
    'hint': null,
  }, 400);
}

http.Response risposta(Object? corpo, [int stato = 200]) =>
    http.Response(jsonEncode(corpo), stato, headers: _json);

Map<String, dynamic> corpoDi(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

/// Tutto quello che serve a una schermata per funzionare in un test: il
/// database in memoria, il server finto, la rete comandabile.
class Ambiente {
  // Nei test dei widget i flussi osservati si chiudono subito, invece che con
  // un timer che il test troverebbe ancora in sospeso.
  Ambiente()
    : db = DatabaseLocale(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );

  final DatabaseLocale db;
  final rete = ReteFinta();
  late final server = ServerFinto(rete);
  final ingresso = IngressoFinto();
  late final archivio = Archivio(db, server.supabase, rete: rete);
  late final misurazione = Misurazione(
    db,
    server.supabase,
    versioneApp: 'prova',
  );

  Widget servizi(Widget figlio) => Servizi(
    db: db,
    supabase: server.supabase,
    archivio: archivio,
    misurazione: misurazione,
    ingresso: ingresso,
    rete: rete,
    child: figlio,
  );

  /// L'elenco vero delle destinazioni, letto dal file.
  static final elenco = ElencoDestinazioni.daTesto(
    File('assets/destinazioni.tsv').readAsStringSync(),
  );

  /// Monta [schermata] come la mostrerebbe l'app, con "Riduci movimento":
  /// senza animazioni infinite, e con la prova che si legge anche così.
  Future<void> monta(WidgetTester tester, Widget schermata) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    // Il cursore di un campo col fuoco lampeggia per sempre: il test non si
    // assesterebbe mai.
    EditableText.debugDeterministicCursor = true;
    ElencoDestinazioni.usa(elenco);
    addTearDown(() => EditableText.debugDeterministicCursor = false);
    await tester.pumpWidget(
      servizi(
        AdaptiveApp(
          title: 'Trolley',
          themeMode: ThemeMode.light,
          materialLightTheme: temaMaterialChiaro,
          materialDarkTheme: temaMaterialScuro,
          cupertinoLightTheme: temaCupertinoChiaro,
          cupertinoDarkTheme: temaCupertinoScuro,
          locale: const Locale('it'),
          supportedLocales: const [Locale('it')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: schermata,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Gli eventi di misurazione in attesa, per nome.
  Future<List<EventoInAttesa>> eventi(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.eventiInAttesa).get()))!;

  Future<void> chiudi() async {
    await rete.chiudi();
    await ingresso.controllo.close();
    await db.close();
  }
}
