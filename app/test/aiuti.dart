/// Quello che serve a più test: una rete comandabile, un server finto in
/// memoria, e il modo di montare una schermata con i suoi servizi.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
import 'package:trolley/dati/acquisizione.dart';
import 'package:trolley/dati/archivio.dart';
import 'package:trolley/dati/database.dart';
import 'package:trolley/dati/destinazioni.dart';
import 'package:trolley/dati/documenti.dart';
import 'package:trolley/dati/errori.dart';
import 'package:trolley/dati/file_del_telefono.dart';
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
  'modificato_da': idDiProva,
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

/// Una riga di `tappa` come la restituisce il server.
Map<String, Object?> rigaDiTappa(
  String id, {
  required String viaggio,
  required String giorno,
  int ordine = 1,
  String titolo = 'Livraria Lello',
  String? tipo = 'visita',
  int durata = 90,
  String stato = 'da_fare',
  String creatoDa = idDiProva,
  int versione = 1,
}) => {
  'id': id,
  'viaggio_id': viaggio,
  'giorno_id': giorno,
  'ordine': ordine,
  'titolo': titolo,
  'luogo_nome': null,
  'lat': null,
  'lon': null,
  'durata_stimata_min': durata,
  'ora_inizio': null,
  'stato': stato,
  'marcata_il': null,
  'marcata_durante_il_viaggio': false,
  'eccedente': false,
  'tipo': tipo,
  'creato_da': creatoDa,
  'creato_il': _istante,
  'modificato_il': _istante,
  'modificato_da': creatoDa,
  'eliminato_il': null,
  'versione': versione,
};

/// Una riga di `spesa` come la restituisce il server.
Map<String, Object?> rigaDiSpesa(
  String id, {
  required String viaggio,
  String importo = '12.40',
  String valuta = 'EUR',
  required String data,
  String? descrizione = 'Pranzo',
  String pagante = idDiProva,
  String creatoDa = idDiProva,
  String creatoIl = _istante,
  int versione = 1,
}) => {
  'id': id,
  'viaggio_id': viaggio,
  'importo': num.parse(importo),
  'valuta': valuta,
  'tasso_usato': null,
  'tasso_al': null,
  'pagante_id': pagante,
  'data': data,
  'descrizione': descrizione,
  'rimborso': false,
  'creato_da': creatoDa,
  'creato_il': creatoIl,
  'modificato_il': creatoIl,
  'modificato_da': creatoDa,
  'eliminato_il': null,
  'versione': versione,
};

/// Una riga di `spesa_quota` come la restituisce il server.
Map<String, Object?> rigaDiQuota(
  String spesa, {
  required String viaggio,
  required String utente,
  required String quota,
}) => {
  'id': 'q-$spesa-$utente',
  'viaggio_id': viaggio,
  'spesa_id': spesa,
  'utente_id': utente,
  'quota': num.parse(quota),
  'creato_da': idDiProva,
  'creato_il': _istante,
  'modificato_il': _istante,
  'eliminato_il': null,
  'versione': 1,
};

/// Una riga di `voce_lista` come la restituisce il server.
Map<String, Object?> rigaDiVoce(
  String id, {
  required String viaggio,
  String testo = 'Passaporto',
  int quantita = 1,
  String tipo = 'personale',
  String proprietario = idDiProva,
  bool spuntata = false,
  String creatoDa = idDiProva,
  String creatoIl = _istante,
  int versione = 1,
}) => {
  'id': id,
  'viaggio_id': viaggio,
  'testo': testo,
  'quantita': quantita,
  'tipo': tipo,
  'proprietario_id': proprietario,
  'assegnato_a': null,
  'spuntata': spuntata,
  'creato_da': creatoDa,
  'creato_il': creatoIl,
  'modificato_il': creatoIl,
  'modificato_da': creatoDa,
  'eliminato_il': null,
  'versione': versione,
};

/// Una riga di `nota` come la restituisce il server.
Map<String, Object?> rigaDiNota(
  String id, {
  required String viaggio,
  String testo = 'GIORNO 1\n10:30 | Livraria Lello | visita | 60',
  String origine = 'incollata',
  String creatoDa = idDiProva,
  String creatoIl = _istante,
  int versione = 1,
}) => {
  'id': id,
  'viaggio_id': viaggio,
  'testo': testo,
  'origine': origine,
  'creato_da': creatoDa,
  'creato_il': creatoIl,
  'modificato_il': creatoIl,
  'modificato_da': creatoDa,
  'eliminato_il': null,
  'versione': versione,
};

/// Una riga di `tasso_cambio`: quanto vale un euro in [valuta].
Map<String, Object?> rigaTasso(String valuta, num perEuro, String del) => {
  'valuta': valuta,
  'per_euro': perEuro,
  'del': del,
};

/// Una riga di `partecipazione`: senza altro, chi è entrato ha creato il
/// viaggio.
Map<String, Object?> rigaPartecipazione(
  String viaggio, {
  String utente = idDiProva,
  String ruolo = 'creatore',
  String stato = 'attivo',
}) => {
  'id': utente == idDiProva ? 'p-$viaggio' : 'p-$viaggio-$utente',
  'viaggio_id': viaggio,
  'utente_id': utente,
  'ruolo': ruolo,
  'stato': stato,
  'creato_da': utente,
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
  final tappe = <Map<String, Object?>>[];
  final spese = <Map<String, Object?>>[];

  /// Le righe di `spesa_quota`: `id`, `viaggio_id`, `spesa_id`, `utente_id`,
  /// `quota`, `eliminato_il`, `versione`.
  final quote = <Map<String, Object?>>[];
  final voci = <Map<String, Object?>>[];
  final note = <Map<String, Object?>>[];
  final tassi = <Map<String, Object?>>[];

  /// I link d'invito: `token`, `viaggio_id`, `creato_da`, `creato_il`,
  /// `eliminato_il`.
  final inviti = <Map<String, Object?>>[];

  /// La configurazione, come la scrive chi gestisce il progetto.
  final configurazione = <Map<String, Object?>>[
    {
      'chiave': 'modelli_suggeriti',
      'valore': [
        'Claude Sonnet 5 o superiore',
        'il modello di punta di ChatGPT',
      ],
    },
  ];

  /// Il proprio profilo intero, come lo dà mio_profilo; `null` se non c'è.
  Map<String, Object?>? profilo;

  /// Gli altri: degli altri il server manda solo il nome.
  final utenti = <Map<String, Object?>>[];
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
        // Chi è uscito o è stato tolto non legge più il viaggio.
        return risposta(
          _filtra([
            for (final v in viaggi)
              if (!partecipazioni.any(
                (p) =>
                    p['viaggio_id'] == v['id'] &&
                    p['utente_id'] == idDiProva &&
                    p['stato'] != 'attivo',
              ))
                v,
          ], r.url.queryParameters),
        );
      case 'GET /rest/v1/partecipazione':
        return risposta(_filtra(partecipazioni, r.url.queryParameters));
      case 'GET /rest/v1/invito':
        return risposta(_filtra(inviti, r.url.queryParameters));
      case 'PATCH /rest/v1/invito':
        final valori = _corpo(r);
        for (final i in _filtra(inviti, r.url.queryParameters)) {
          i.addAll(valori);
        }
        return http.Response('', 204);
      case 'POST /rest/v1/rpc/accetta_invito':
        final invito = inviti
            .where(
              (i) =>
                  i['token'] == _corpo(r)['p_token'] &&
                  i['eliminato_il'] == null,
            )
            .firstOrNull;
        if (invito == null) return _errore('TR404', 'invito non valido');
        final viaggio = invito['viaggio_id']! as String;
        final mia = _partecipazione(viaggio, idDiProva);
        if (mia == null) {
          partecipazioni.add(
            rigaPartecipazione(viaggio, ruolo: 'partecipante'),
          );
        } else if (mia['stato'] == 'rimosso') {
          return _errore('TR403', 'rimosso dal viaggio');
        } else {
          mia['stato'] = 'attivo';
        }
        return risposta(viaggio);
      case 'POST /rest/v1/rpc/esci_dal_viaggio':
        final mia = _partecipazione(_corpo(r)['p_viaggio'], idDiProva);
        if (mia == null || mia['stato'] != 'attivo') {
          return _errore('TR404', 'non partecipi');
        }
        if (mia['ruolo'] == 'creatore') {
          return _errore('TR412', 'prima passa il ruolo');
        }
        mia['stato'] = 'uscito';
        return http.Response('', 204);
      case 'POST /rest/v1/rpc/rimuovi_partecipante':
      case 'POST /rest/v1/rpc/passa_il_ruolo':
        final c = _corpo(r);
        final viaggio = c['p_viaggio'] as String;
        final mia = _partecipazione(viaggio, idDiProva);
        if (mia == null ||
            mia['ruolo'] != 'creatore' ||
            mia['stato'] != 'attivo') {
          return _errore('TR403', 'non responsabile');
        }
        final altra = _partecipazione(viaggio, c['p_utente'] ?? c['p_a']);
        if (altra == null ||
            altra['ruolo'] != 'partecipante' ||
            altra['stato'] != 'attivo') {
          return _errore('TR404', 'non partecipa');
        }
        if (chiave.endsWith('rimuovi_partecipante')) {
          altra['stato'] = 'rimosso';
          for (final i in inviti) {
            if (i['viaggio_id'] == viaggio) i['eliminato_il'] ??= _istante;
          }
        } else {
          mia['ruolo'] = 'partecipante';
          altra['ruolo'] = 'creatore';
          _viaggio(viaggio)!
            ..['creatore_id'] = altra['utente_id']
            ..['versione'] = (_viaggio(viaggio)!['versione']! as int) + 1;
        }
        return risposta(_righe(viaggio));
      case 'GET /rest/v1/utente':
        return risposta(_filtra(utenti, r.url.queryParameters));
      case 'GET /rest/v1/giorno':
        return risposta(_filtra(giorni, r.url.queryParameters));
      case 'GET /rest/v1/tappa':
        return risposta(_filtra(tappe, r.url.queryParameters));
      case 'POST /rest/v1/tappa':
        // Come `upsert(ignoreDuplicates: true)`: rimandata, non si duplica.
        final ignora = (r.headers['prefer'] ?? r.headers['Prefer'] ?? '')
            .contains('ignore-duplicates');
        final corpo = jsonDecode(r.body);
        final scritte = <Map<String, Object?>>[];
        for (final c in (corpo is List ? corpo : [corpo]).cast<Map>()) {
          if (tappe.any((t) => t['id'] == c['id'])) {
            if (ignora) continue;
            return _errore('23505', 'tappa già presente');
          }
          final riga = {
            ...rigaDiTappa(
              c['id'] as String,
              viaggio: c['viaggio_id'] as String,
              giorno: c['giorno_id'] as String,
            ),
            ...c.cast<String, Object?>(),
          };
          tappe.add(riga);
          scritte.add(riga);
        }
        return risposta(scritte, 201);
      case 'PATCH /rest/v1/tappa':
        final trovate = _filtra(tappe, r.url.queryParameters);
        if (trovate.isEmpty) return risposta(const []);
        final tappa = trovate.single;
        final valori = _corpo(r);
        if (valori.containsKey('versione') &&
            valori['versione'] != tappa['versione']) {
          return _errore('TR409', 'versione superata');
        }
        tappa
          ..addAll(valori)
          ..['versione'] = (tappa['versione']! as int) + 1
          ..['modificato_da'] = idDiProva;
        // Senza versione passa sempre, e il trigger la fa avanzare lo stesso.
        return risposta([tappa]);
      case 'GET /rest/v1/spesa':
        return risposta(_filtra(spese, r.url.queryParameters));
      case 'POST /rest/v1/spesa':
        final ignora = (r.headers['prefer'] ?? r.headers['Prefer'] ?? '')
            .contains('ignore-duplicates');
        final c = _corpo(r);
        if (spese.any((x) => x['id'] == c['id'])) {
          if (ignora) return risposta(const [], 201);
          return _errore('23505', 'spesa già presente');
        }
        final riga = {
          ...rigaDiSpesa(
            c['id'] as String,
            viaggio: c['viaggio_id'] as String,
            data: c['data'] as String,
          ),
          ...c,
          'importo': num.parse(c['importo'] as String),
          'creato_il': DateTime.now().toUtc().toIso8601String(),
        };
        spese.add(riga);
        return risposta([riga], 201);
      case 'PATCH /rest/v1/spesa':
        final trovate = _filtra(spese, r.url.queryParameters);
        if (trovate.isEmpty) return risposta(const []);
        final spesa = trovate.single;
        final valori = _corpo(r);
        if (valori.containsKey('versione') &&
            valori['versione'] != spesa['versione']) {
          return _errore('TR409', 'versione superata');
        }
        spesa
          ..addAll(valori)
          ..['versione'] = (spesa['versione']! as int) + 1
          ..['modificato_da'] = idDiProva;
        return risposta([spesa]);
      case 'GET /rest/v1/spesa_quota':
        return risposta(_filtra(quote, r.url.queryParameters));
      case 'POST /rest/v1/rpc/registra_spesa':
        // Come la funzione vera: spesa e quote insieme, e rimandata non si
        // duplica.
        final c = _corpo(r);
        final p = (c['p_spesa'] as Map).cast<String, Object?>();
        final id = p['id']! as String;
        if (!spese.any((x) => x['id'] == id)) {
          spese.add({
            ...rigaDiSpesa(
              id,
              viaggio: p['viaggio_id']! as String,
              data: p['data']! as String,
            ),
            ...p,
            'importo': num.parse(p['importo']! as String),
            'rimborso': p['rimborso'] == true,
            'creato_il': DateTime.now().toUtc().toIso8601String(),
          });
          for (final q in (c['p_quote'] as List? ?? const [])) {
            final quota = (q as Map).cast<String, Object?>();
            quote.add(
              rigaDiQuota(
                id,
                viaggio: p['viaggio_id']! as String,
                utente: quota['utente_id']! as String,
                quota: quota['quota']! as String,
              ),
            );
          }
        }
        return risposta(_righeDellaSpesa(id));
      case 'POST /rest/v1/rpc/cambia_spesa':
        final c = _corpo(r);
        final id = c['p_spesa']! as String;
        final spesa = spese.where((x) => x['id'] == id).firstOrNull;
        if (spesa == null) return _errore('TR404', 'spesa non trovata');
        if (spesa['versione'] != c['p_versione']) {
          return _errore('TR409', 'versione superata');
        }
        final valori = (c['p_valori'] as Map).cast<String, Object?>();
        spesa
          ..addAll(valori)
          ..['versione'] = (spesa['versione']! as int) + 1
          ..['modificato_da'] = idDiProva;
        if (valori['importo'] case final String importo) {
          spesa['importo'] = num.parse(importo);
        }
        if (c['p_quote'] case final List nuove) {
          final per = {
            for (final q in nuove.cast<Map>())
              q['utente_id'] as String: q['quota'] as String,
          };
          for (final q in quote.where((q) => q['spesa_id'] == id)) {
            final nuova = per.remove(q['utente_id']);
            q
              ..['quota'] = nuova == null ? q['quota'] : num.parse(nuova)
              ..['eliminato_il'] = nuova == null ? _istante : null;
          }
          for (final MapEntry(key: utente, value: quota) in per.entries) {
            quote.add(
              rigaDiQuota(
                id,
                viaggio: spesa['viaggio_id']! as String,
                utente: utente,
                quota: quota,
              ),
            );
          }
        }
        return risposta(_righeDellaSpesa(id));
      case 'GET /rest/v1/voce_lista':
        return risposta(_filtra(voci, r.url.queryParameters));
      case 'POST /rest/v1/voce_lista':
        final ignora = (r.headers['prefer'] ?? r.headers['Prefer'] ?? '')
            .contains('ignore-duplicates');
        final c = _corpo(r);
        if (voci.any((x) => x['id'] == c['id'])) {
          if (ignora) return risposta(const [], 201);
          return _errore('23505', 'voce già presente');
        }
        final riga = {
          ...rigaDiVoce(c['id'] as String, viaggio: c['viaggio_id'] as String),
          ...c,
          'creato_il': DateTime.now().toUtc().toIso8601String(),
        };
        voci.add(riga);
        return risposta([riga], 201);
      case 'PATCH /rest/v1/voce_lista':
        final trovate = _filtra(voci, r.url.queryParameters);
        if (trovate.isEmpty) return risposta(const []);
        final voce = trovate.single;
        final valori = _corpo(r);
        if (valori.containsKey('versione') &&
            valori['versione'] != voce['versione']) {
          return _errore('TR409', 'versione superata');
        }
        voce
          ..addAll(valori)
          ..['versione'] = (voce['versione']! as int) + 1
          ..['modificato_da'] = idDiProva;
        return risposta([voce]);
      case 'GET /rest/v1/nota':
        return risposta(_filtra(note, r.url.queryParameters));
      case 'POST /rest/v1/nota':
        final ignora = (r.headers['prefer'] ?? r.headers['Prefer'] ?? '')
            .contains('ignore-duplicates');
        final c = _corpo(r);
        if (note.any((x) => x['id'] == c['id'])) {
          if (ignora) return risposta(const [], 201);
          return _errore('23505', 'nota già presente');
        }
        final riga = {
          ...rigaDiNota(c['id'] as String, viaggio: c['viaggio_id'] as String),
          ...c,
          'creato_il': DateTime.now().toUtc().toIso8601String(),
        };
        note.add(riga);
        return risposta([riga], 201);
      case 'PATCH /rest/v1/nota':
        final trovate = _filtra(note, r.url.queryParameters);
        if (trovate.isEmpty) return risposta(const []);
        final nota = trovate.single;
        final valori = _corpo(r);
        if (valori.containsKey('versione') &&
            valori['versione'] != nota['versione']) {
          return _errore('TR409', 'versione superata');
        }
        nota
          ..addAll(valori)
          ..['versione'] = (nota['versione']! as int) + 1
          ..['modificato_da'] = idDiProva;
        return risposta([nota]);
      case 'GET /rest/v1/configurazione':
        return risposta(configurazione);
      case 'GET /rest/v1/tasso_cambio':
        return risposta(tassi);
      case 'POST /rest/v1/rpc/mio_profilo':
        return risposta([?profilo]);
      case 'PATCH /rest/v1/utente':
        final p = profilo;
        if (p == null) return risposta(const []);
        final valori = _corpo(r);
        if (valori['versione'] != p['versione']) {
          return _errore('TR409', 'versione superata');
        }
        p
          ..addAll(valori)
          ..['versione'] = (valori['versione']! as int) + 1;
        return risposta([
          {'id': p['id']},
        ]);
      case 'POST /rest/v1/rpc/ordina_tappe':
        final c = _corpo(r);
        final ordinate = <Map<String, Object?>>[];
        for (final (i, id) in (c['p_tappe'] as List).indexed) {
          final tappa = tappe
              .where(
                (t) =>
                    t['id'] == id &&
                    t['giorno_id'] == c['p_giorno'] &&
                    t['eliminato_il'] == null,
              )
              .firstOrNull;
          if (tappa == null) continue;
          tappa
            ..['ordine'] = i + 1
            ..['versione'] = (tappa['versione']! as int) + 1;
          ordinate.add(tappa);
        }
        return risposta(ordinate);
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
          ..['versione'] = (valori['versione']! as int) + 1
          ..['modificato_da'] = idDiProva;
        return risposta([viaggio]);
      case 'POST /rest/v1/invito':
        final token = 'ABCD${2345 + inviti.length}';
        inviti.add({
          'token': token,
          'viaggio_id': _corpo(r)['viaggio_id'],
          'creato_da': idDiProva,
          'creato_il': DateTime.now().toUtc().toIso8601String(),
          'eliminato_il': null,
        });
        // L'app lo chiede con `.single()`: un oggetto, non un elenco.
        return risposta({'token': token}, 201);
      case 'POST /rest/v1/evento':
        return http.Response('', 201);
    }
    return risposta(const []);
  }

  /// I filtri di PostgREST che l'app usa: `eq`, `neq`, `is.null`, `in`.
  static List<Map<String, Object?>> _filtra(
    List<Map<String, Object?>> righe,
    Map<String, String> filtri,
  ) => [
    for (final riga in righe)
      if (filtri.entries.every((f) => _passa(riga, f.key, f.value))) riga,
  ];

  static bool _passa(Map<String, Object?> riga, String colonna, String filtro) {
    if (!riga.containsKey(colonna)) return true;
    final valore = riga[colonna];
    if (filtro == 'is.null') return valore == null;
    if (filtro.startsWith('eq.')) return '$valore' == filtro.substring(3);
    if (filtro.startsWith('neq.')) return '$valore' != filtro.substring(4);
    if (filtro.startsWith('in.(')) {
      return filtro
          .substring(4, filtro.length - 1)
          .split(',')
          .map((v) => v.replaceAll('"', ''))
          .contains('$valore');
    }
    return true;
  }

  Map<String, Object?> _righeDellaSpesa(String id) => {
    'spesa': spese.where((x) => x['id'] == id).firstOrNull,
    'quote': [
      for (final q in quote)
        if (q['spesa_id'] == id && q['eliminato_il'] == null) q,
    ],
  };

  Map<String, Object?>? _viaggio(String id) =>
      viaggi.where((v) => v['id'] == id).firstOrNull;

  Map<String, Object?>? _partecipazione(Object? viaggio, Object? utente) =>
      partecipazioni
          .where((p) => p['viaggio_id'] == viaggio && p['utente_id'] == utente)
          .firstOrNull;

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

/// Il telefono finto per i documenti: protegge come gli si dice, conta le
/// pagine, "comprime" copiando, e disegna ogni pagina come un pixel bianco.
class TelefonoFinto implements FileDelTelefono {
  /// Come resta un file protetto: si cambia per provare il rifiuto.
  StatoFile stato = const StatoFile(protezione: 'completa', nelBackup: true);
  final protetti = <String>[];
  final compressi = <String>[];
  int pagineDeiPdf = 2;

  /// Lanciato contando le pagine: un PDF con la password, per esempio.
  ErroreTrolley? erroreDelPdf;

  /// Comprimere trova il disco pieno.
  bool discoPieno = false;
  bool codiceDiSblocco = true;

  @override
  Future<StatoFile> proteggi(String percorso) async {
    protetti.add(percorso);
    return stato;
  }

  @override
  Future<int> pagine(String percorso) async {
    if (erroreDelPdf case final errore?) throw errore;
    return pagineDeiPdf;
  }

  @override
  Future<Uint8List> pagina(
    String percorso, {
    required int indice,
    required int larghezza,
  }) async => pixelBianco;

  @override
  Future<void> comprimi({
    required String da,
    required String a,
    int lato = 2800,
    double qualita = 0.85,
  }) async {
    if (discoPieno) {
      // Come lo dice il sistema: a metà file.
      await File(a).writeAsString('meta');
      throw FileSystemException(
        'No space left on device',
        a,
        const OSError('No space left on device', 28),
      );
    }
    compressi.add(da);
    await File(da).copy(a);
  }

  @override
  Future<bool> haCodiceDiSblocco() async => codiceDiSblocco;
}

/// Un PNG di un pixel bianco: quello che "disegna" il telefono finto.
final pixelBianco = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC',
);

/// Un'acquisizione finta: invece di aprire la fotocamera o i selettori crea
/// un file nella sua cartella, come farebbe il sistema.
class AcquisizioneFinta implements Acquisizione {
  AcquisizioneFinta(this.cartella);

  final Directory cartella;

  /// Il nome del file che arriva da ciascuna sorgente; `null` per una persona
  /// che ci ripensa.
  final nomi = <Sorgente, String?>{
    Sorgente.scansione: 'DOCUMENT_SCAN_20261003-101500.pdf',
    Sorgente.foto: 'IMG_0042.HEIC',
    Sorgente.file: 'Carta imbarco.pdf',
  };
  final chieste = <Sorgente>[];
  int pulizie = 0;

  @override
  Future<FileAcquisito?> acquisisci(Sorgente sorgente) async {
    chieste.add(sorgente);
    final nome = nomi[sorgente];
    if (nome == null) return null;
    final file = File('${cartella.path}/$nome');
    await file.writeAsString('contenuto di $nome');
    return FileAcquisito(
      percorso: file.path,
      sorgente: sorgente,
      nome: sorgente == Sorgente.scansione ? null : nome,
    );
  }

  @override
  Future<void> pulisci() async => pulizie++;
}

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

  /// La cartella dell'app per i documenti, e quella dove "arrivano" i file.
  late final cartella = Directory.systemTemp.createTempSync('trolley-prova');
  final telefono = TelefonoFinto();
  late final documenti = CartellaDocumenti(
    db,
    telefono: telefono,
    cartellaApp: () async => Directory('${cartella.path}/app')..createSync(),
    io: () => server.supabase.auth.currentUser?.id ?? idDiProva,
  );
  late final acquisizione = AcquisizioneFinta(
    Directory('${cartella.path}/arrivi')..createSync(),
  );

  Widget servizi(Widget figlio) => Servizi(
    db: db,
    supabase: server.supabase,
    archivio: archivio,
    misurazione: misurazione,
    ingresso: ingresso,
    rete: rete,
    documenti: documenti,
    acquisizione: acquisizione,
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

  /// Entra come [idDiProva], col suo profilo nella copia e sul server: chi
  /// registra una spesa ne è il pagante, e serve sapere chi è.
  /// Nei test dei widget va passato il [tester], perché si parla col server.
  Future<void> accedi({WidgetTester? tester, String valuta = 'EUR'}) async {
    server.profilo = {
      'id': idDiProva,
      'nome': 'Giulia',
      'data_nascita': '1995-04-02',
      'valuta_predefinita': valuta,
      'telefono_verificato': false,
      'profilo_pubblico_attivo': false,
      'interno': false,
      'eliminato_il': null,
      'versione': 1,
    };
    Future<void> entra() async {
      await server.supabase.auth.recoverSession(
        jsonEncode({
          'access_token': 'token-finto',
          'token_type': 'bearer',
          'expires_in': 3600,
          'expires_at':
              DateTime.now()
                  .add(const Duration(days: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'refresh_token': 'rinnovo-finto',
          'user': {
            'id': idDiProva,
            'aud': 'authenticated',
            'app_metadata': <String, Object?>{},
            'user_metadata': <String, Object?>{},
            'created_at': _istante,
          },
        }),
      );
      await archivio.scaricaProfilo();
    }

    await (tester == null ? entra() : tester.runAsync(entra));
  }

  /// Gli eventi di misurazione in attesa, per nome.
  Future<List<EventoInAttesa>> eventi(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.eventiInAttesa).get()))!;

  Future<void> chiudi() async {
    await rete.chiudi();
    await ingresso.controllo.close();
    await db.close();
    if (cartella.existsSync()) cartella.deleteSync(recursive: true);
  }
}
