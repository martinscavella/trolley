/// Misurazione (07-misurazione.md): l'unica verifica rimasta delle ipotesi.
///
/// Regole che questo file fa rispettare:
/// - gli eventi si scrivono in locale e partono a lotti quando c'è rete, con
///   l'orario in cui sono avvenuti;
/// - sono idempotenti: l'id nasce qui, e un lotto che riparte non duplica;
/// - se la persona ha rifiutato, **non si scrivono affatto**.
///
/// Azioni, mai contenuti: nelle proprietà non vanno testi, nomi di documenti,
/// coordinate. Chi aggiunge un evento lo aggiunge anche alla tabella di 07.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../dati/database.dart';

/// I nomi degli eventi, uno per riga della tabella di 07-misurazione.md.
abstract final class Eventi {
  static const invitoCreato = 'invito_creato';
  static const installazioneDaInvito = 'installazione_da_invito';
  static const viaggioCorrettoAperto = 'viaggio_corretto_aperto';
  static const viaggioCreato = 'viaggio_creato';
  static const ideaDefinita = 'idea_definita';
  static const primoElementoAggiunto = 'primo_elemento_aggiunto';
  static const funzioneUsataNelViaggio = 'funzione_usata_nel_viaggio';
  static const primoContributoInvitato = 'primo_contributo_invitato';
  static const tappaMarcata = 'tappa_marcata';
  static const aperturaSenzaRete = 'apertura_senza_rete';
  static const promptEsportato = 'prompt_esportato';
  static const incollatoRiuscito = 'incollato_riuscito';
  static const incollatoNonInterpretato = 'incollato_non_interpretato';
  static const conflittoMostrato = 'conflitto_mostrato';
  static const conflittoRisolto = 'conflitto_risolto';
  static const consumoMappe = 'consumo_mappe';
  static const viaggioPreparato = 'viaggio_preparato';
  static const permessoPosizione = 'permesso_posizione';
  static const viaggioChiuso = 'viaggio_chiuso';
}

class Misurazione {
  Misurazione(this._db, this._supabase, {required this.versioneApp});

  final DatabaseLocale _db;
  final SupabaseClient _supabase;
  final String versioneApp;

  /// Come in Archivio: `rest`, perché applica le opzioni del client.
  PostgrestClient get _server => _supabase.rest;

  static const _chiaveAttiva = 'misurazione_attiva';
  static const _dimensioneLotto = 200;

  Future<bool> get attiva async {
    final riga = await (_db.select(
      _db.impostazioni,
    )..where((i) => i.chiave.equals(_chiaveAttiva))).getSingleOrNull();
    return riga?.valore != 'no';
  }

  /// Rifiutare non toglie nessuna funzione. Gli eventi non ancora partiti si
  /// buttano: la scelta vale anche per ciò che è successo prima di farla.
  Future<void> imposta({required bool attiva}) async {
    await _db.transaction(() async {
      await _db
          .into(_db.impostazioni)
          .insertOnConflictUpdate(
            ImpostazioniCompanion.insert(
              chiave: _chiaveAttiva,
              valore: attiva ? 'si' : 'no',
            ),
          );
      if (!attiva) await _db.delete(_db.eventiInAttesa).go();
    });
  }

  Future<void> registra(
    String nome, [
    Map<String, Object?> proprieta = const {},
  ]) async {
    if (!await attiva) return;
    await _db
        .into(_db.eventiInAttesa)
        .insert(
          EventiInAttesaCompanion.insert(
            id: const Uuid().v4(),
            nome: nome,
            proprieta: jsonEncode(proprieta),
            avvenutoIl: DateTime.now().toUtc(),
          ),
        );
  }

  /// Registra [nome] una volta sola per [chiave] su questo telefono: gli
  /// eventi "primo…" non devono contarsi due volte se la persona toglie e
  /// rimette.
  Future<void> registraUnaVolta(
    String chiave,
    String nome, [
    Map<String, Object?> proprieta = const {},
  ]) async {
    final segno = 'evento:$chiave';
    final gia = await (_db.select(
      _db.impostazioni,
    )..where((i) => i.chiave.equals(segno))).getSingleOrNull();
    if (gia != null) return;
    await _db
        .into(_db.impostazioni)
        .insert(
          ImpostazioniCompanion.insert(
            chiave: segno,
            valore: DateTime.now().toUtc().toIso8601String(),
          ),
        );
    await registra(nome, proprieta);
  }

  /// Manda quello che c'è in attesa. Senza rete o senza profilo non fa niente e
  /// riproverà la volta dopo: un evento che non parte oggi parte domani.
  Future<void> invia() async {
    if (_supabase.auth.currentUser == null) return;
    try {
      while (true) {
        final lotto =
            await (_db.select(_db.eventiInAttesa)
                  ..orderBy([(e) => OrderingTerm.asc(e.avvenutoIl)])
                  ..limit(_dimensioneLotto))
                .get();
        if (lotto.isEmpty) return;

        await _server
            .from('evento')
            .upsert(
              [
                for (final e in lotto)
                  {
                    'id': e.id,
                    'nome': e.nome,
                    'proprieta': jsonDecode(e.proprieta),
                    'avvenuto_il': e.avvenutoIl.toUtc().toIso8601String(),
                    'versione_app': versioneApp,
                  },
              ],
              onConflict: 'id',
              ignoreDuplicates: true,
            );

        await (_db.delete(
          _db.eventiInAttesa,
        )..where((e) => e.id.isIn(lotto.map((e) => e.id)))).go();
      }
    } on Object {
      // Rete assente o profilo non ancora creato: gli eventi restano in coda.
    }
  }
}
