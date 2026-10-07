/// Parla con il server e tiene aggiornata la copia locale.
///
/// Le schermate leggono **sempre** dalla copia (così leggere non richiede mai la
/// rete) e scrivono attraverso questo archivio. Le scritture che non sono uno dei
/// quattro gesti richiedono la rete e lo dicono con un [ErroreTrolley]. Quelle
/// riuscite ricevono dal server le righe che hanno scritto e le mettono nella
/// copia così come sono: la copia non resta indietro nemmeno se la rete cade un
/// istante dopo.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../dominio/calendario.dart';
import '../dominio/chiusura_account.dart';
import '../dominio/conflitti.dart';
import '../dominio/giornate.dart';
import '../dominio/liste.dart';
import '../dominio/periodo.dart';
import '../dominio/stato_viaggio.dart';
import '../dominio/tappe.dart';
import 'coda.dart';
import 'conflitti.dart';
import 'database.dart';
import 'destinazioni.dart';
import 'errori.dart';
import 'lettura.dart';
import 'rete.dart';

/// Quanto può essere lunga una nota: come sul server. Una risposta lunga di
/// un assistente ci sta comoda.
const lunghezzaMassimaNota = 20000;

/// Il nome di chi ha chiuso l'account, dove compare fra i compagni: i suoi
/// contributi restano nel viaggio, il suo nome no (06, «Conservazione»).
const nomeAccountChiuso = 'Account chiuso';

/// Un viaggio come compare nell'elenco: con i nomi di chi c'è.
class ViaggioInElenco {
  const ViaggioInElenco(this.viaggio, this.persone);

  final Viaggio viaggio;
  final List<String> persone;
}

/// Un link d'invito ancora valido: chi ne ha uno entra (03, casi limite).
class InvitoValido {
  const InvitoValido({required this.creatoDa, required this.creatoIl});

  final String creatoDa;
  final DateTime creatoIl;
}

/// Perché un viaggio non è più tra i propri.
enum MotivoUscita {
  /// Chi è responsabile del viaggio ti ha tolto.
  rimosso,

  /// Sei uscito, da un altro telefono.
  uscito,
}

/// Un viaggio sparito dal server mentre era su questo telefono: lo si dice,
/// invece di farlo sparire in silenzio (02, casi limite: rimosso mentre è
/// offline). Resta finché la persona non l'ha visto.
class ViaggioLasciato {
  const ViaggioLasciato({
    required this.viaggioId,
    required this.nome,
    required this.motivo,
    required this.gestiPersi,
  });

  final String viaggioId;

  /// La meta com'era sul telefono; `null` per un'idea senza meta.
  final String? nome;
  final MotivoUscita motivo;

  /// I gesti fatti senza rete che non sono arrivati e non arriveranno più.
  final int gestiPersi;
}

class Archivio {
  Archivio(this._db, this._supabase, {this.rete});

  final DatabaseLocale _db;
  final SupabaseClient _supabase;

  /// A cui dire com'è andata ogni chiamata (rete.dart).
  final Rete? rete;

  /// I gesti che si fanno anche senza rete (coda.dart).
  late final coda = Coda(_db, _supabase, rete: rete);

  String? get _io => _supabase.auth.currentUser?.id;

  /// Le tabelle e le funzioni del server. Si passa da `rest` perché
  /// `SupabaseClient.from` (supabase 2.16) non applica le opzioni del client:
  /// ritenterebbe da solo, contro configurazione.dart.
  PostgrestClient get _server => _supabase.rest;

  Future<T> _alServer<T>(
    Future<T> Function() chiamata, {
    Map<String, String> messaggi = const {},
  }) async {
    try {
      return await alServer(chiamata, messaggi: messaggi, rete: rete);
    } on ErroreTrolley catch (e) {
      // Qualcuno ha cambiato il viaggio nel frattempo: si riscarica, così la
      // persona vede la versione nuova prima di riprovare (02 §3).
      if (e.codice == CodiciServer.versioneSuperata) {
        await aggiornaCopia().catchError((_) {});
      }
      rethrow;
    }
  }

  // ─── Profilo ────────────────────────────────────────────────────────────

  /// Il proprio profilo dalla copia locale, se c'è.
  Future<Utente?> profiloLocale() async {
    final io = _io;
    if (io == null) return null;
    return (_db.select(
      _db.utenti,
    )..where((u) => u.id.equals(io))).getSingleOrNull();
  }

  /// Chiede al server il proprio profilo e lo mette nella copia.
  /// `null` se la persona ha un accesso ma non ha ancora un profilo.
  Future<Utente?> scaricaProfilo() async {
    final righe = await _alServer(
      () => _server.rpc<List<dynamic>>('mio_profilo'),
    );
    if (righe.isEmpty) return null;
    final riga = righe.single as Map<String, dynamic>;
    await _db.into(_db.utenti).insertOnConflictUpdate(_utente(riga));
    return profiloLocale();
  }

  /// Crea il profilo. L'età la controlla anche il server: qui la si controlla
  /// prima, nella schermata, per non far scrivere niente a chi non può entrare.
  Future<Utente> creaProfilo({
    required String nome,
    required DateTime dataNascita,
  }) async {
    await _alServer(
      () => _server.from('utente').insert({
        'id': _io,
        'nome': nome.trim(),
        'data_nascita': scriviData(dataNascita),
      }),
      messaggi: {
        CodiciServer.nonPermesso: 'Per usare Trolley servono 16 anni.',
      },
    );
    return (await scaricaProfilo())!;
  }

  // ─── I tuoi dati e chiudere l'account (U.1) ─────────────────────────────

  /// Tutto ciò che è proprio su Trolley, preso dal server (06, «Diritti delle
  /// persone»): il profilo, i viaggi come li si vede, i traguardi, le azioni
  /// misurate. Richiede la rete.
  Future<Map<String, dynamic>> iMieiDati() =>
      _alServer(() => _server.rpc<Map<String, dynamic>>('i_miei_dati'));

  /// I propri viaggi, con chi altro c'è ancora: quanto serve a dire che cosa
  /// succede chiudendo l'account (dominio/chiusura_account.dart). Dalla copia.
  Future<List<ViaggioDaChiudere<Viaggio>>> viaggiDaChiudereConLAccount() async {
    final io = _io;
    if (io == null) return const [];
    final miei = [
      for (final (p, v) in await mieiViaggi())
        if (p.stato == 'attivo' &&
            p.eliminatoIl == null &&
            v.eliminatoIl == null)
          (p, v),
    ];
    final altri =
        await (_db.select(_db.partecipazioni).join([
              leftOuterJoin(
                _db.utenti,
                _db.utenti.id.equalsExp(_db.partecipazioni.utenteId),
              ),
            ])..where(
              _db.partecipazioni.viaggioId.isIn([
                    for (final (_, v) in miei) v.id,
                  ]) &
                  _db.partecipazioni.utenteId.equals(io).not() &
                  _db.partecipazioni.stato.equals('attivo') &
                  _db.partecipazioni.eliminatoIl.isNull(),
            ))
            .get();
    return [
      for (final (p, v) in miei)
        (
          viaggio: v,
          responsabile: p.ruolo == 'creatore',
          altri: [
            for (final r in altri)
              if (r.readTable(_db.partecipazioni) case final q
                  when q.viaggioId == v.id)
                (
                  id: q.utenteId,
                  nome: r.readTableOrNull(_db.utenti)?.nome ?? '',
                  entrato:
                      DateTime.tryParse(q.creatoIl ?? '') ?? DateTime.utc(1970),
                ),
          ],
        ),
    ];
  }

  /// Chiude l'account sul server (chiudi_account), con la scelta della
  /// persona sulla misurazione, che sta sul telefono. Richiede la rete.
  /// Rimandata dopo una risposta persa non fa niente: è già chiuso.
  Future<void> chiudiAccount({required bool misurazione}) => _alServer(
    () => _server.rpc<dynamic>(
      'chiudi_account',
      params: {'p_misurazione': misurazione},
    ),
  );

  /// Dopo la chiusura dell'account la copia si svuota: viaggi, coda,
  /// impostazioni. I documenti no: i propri si tolgono prima, con i loro file
  /// (CartellaDocumenti.eliminaQuelliDi), e quelli di un altro account su
  /// questo telefono restano suoi.
  Future<void> svuotaLaCopia() => _db.transaction(() async {
    for (final tabella in _db.allTables) {
      if (tabella.actualTableName == _db.documenti.actualTableName) continue;
      await _db.delete(tabella).go();
    }
  });

  // ─── Copia di lettura ───────────────────────────────────────────────────

  /// Riscarica la copia (02 §1). Prima manda quello che è in coda, così la
  /// copia lo comprende; quello che non è partito ci si rimette sopra. Se
  /// qualcosa va storto la copia resta quella di prima: meglio vecchia e
  /// dichiarata tale che vuota.
  ///
  /// I viaggi e chi partecipa arrivano sempre tutti: sono l'elenco. Quello che
  /// c'è dentro — giorni, tappe, spese, cose da portare, note — è selettivo:
  /// senza [viaggioId], dei viaggi non ancora finiti (le idee archiviate
  /// comprese: pesano pochi byte, e così l'archivio si legge anche senza
  /// rete); con [viaggioId], di quel viaggio solo, com'è quando lo si apre. Un
  /// viaggio finito tiene la copia dell'ultima volta che lo si è aperto, e la
  /// dice con la sua età ([copiaDelViaggio]).
  Future<void> aggiornaCopia({String? viaggioId}) async {
    await coda.svuota();
    await mandaSulPosto().catchError((_) {});
    final io = _io;
    final oggi = DateTime.now();
    final (
      viaggi,
      lasciati,
      partecipazioni,
      utenti,
      giorni,
      tappe,
      spese,
      quote,
      voci,
      note,
      interi,
    ) = await _alServer(() async {
      // I viaggi da cui si è usciti o si è stati tolti: il viaggio non si
      // legge più, la propria partecipazione sì, e dice perché.
      // Future.wait, non `.wait`: senza rete arriva l'errore com'è, e
      // alServer lo riconosce.
      final [viaggi, lasciati] = await Future.wait([
        _server.from('viaggio').select().isFilter('eliminato_il', null),
        if (io == null)
          Future.value(<Map<String, dynamic>>[])
        else
          _server
              .from('partecipazione')
              .select('viaggio_id, stato')
              .eq('utente_id', io)
              .inFilter('stato', ['uscito', 'rimosso']),
      ]);
      final ids = [for (final v in viaggi) v['id'] as String];
      final interi = [
        for (final v in viaggi)
          if (viaggioId == null
              ? _statoDellaRiga(v, oggi).copiaSempreAggiornata
              : v['id'] == viaggioId)
            v['id'] as String,
      ];
      const nessuna = <Map<String, dynamic>>[];
      // Anche le tappe dei giorni usciti dalle date: sono da ricollocare.
      // Delle liste arrivano quelle del viaggio e le proprie personali: le
      // personali degli altri il server non le manda (05, regola 3).
      Future<List<Map<String, dynamic>>> dentro(String tabella) =>
          interi.isEmpty
          ? Future.value(nessuna)
          : _server
                .from(tabella)
                .select()
                .inFilter('viaggio_id', interi)
                .isFilter('eliminato_il', null);
      final (partecipazioni, giorni, tappe, spese, quote, voci, note) = await (
        ids.isEmpty
            ? Future.value(nessuna)
            : _server
                  .from('partecipazione')
                  .select()
                  .inFilter('viaggio_id', ids),
        dentro('giorno'),
        dentro('tappa'),
        dentro('spesa'),
        dentro('spesa_quota'),
        dentro('voce_lista'),
        dentro('nota'),
      ).wait;
      final utenti = partecipazioni.isEmpty
          ? nessuna
          : await _server
                .from('utente')
                .select('id, nome, versione, eliminato_il')
                .inFilter(
                  'id',
                  {for (final p in partecipazioni) p['utente_id'] as String}
                      .toList(),
                );
      return (
        viaggi,
        lasciati,
        partecipazioni,
        utenti,
        giorni,
        tappe,
        spese,
        quote,
        voci,
        note,
        interi.toSet(),
      );
    });

    final adesso = DateTime.now().toUtc();
    final visibili = {for (final v in viaggi) v['id'] as String};
    await _db.transaction(() async {
      await _segnaLasciati(
        visibili: visibili,
        lasciati: {
          for (final p in lasciati)
            p['viaggio_id'] as String: p['stato'] as String,
        },
      );
      await _db.delete(_db.viaggi).go();
      await _db.delete(_db.partecipazioni).go();
      // Di quello che c'è dentro si rifà solo quello che è arrivato, e si
      // butta quello dei viaggi che non ci sono più. Il resto resta com'era.
      Expression<bool> daRifare(GeneratedColumn<String> viaggio) =>
          viaggio.isIn(interi) | viaggio.isNotIn(visibili);
      await (_db.delete(_db.giorni)..where((r) => daRifare(r.viaggioId))).go();
      await (_db.delete(_db.tappe)..where((r) => daRifare(r.viaggioId))).go();
      await (_db.delete(_db.spese)..where((r) => daRifare(r.viaggioId))).go();
      await (_db.delete(
        _db.speseQuote,
      )..where((r) => daRifare(r.viaggioId))).go();
      await (_db.delete(
        _db.vociLista,
      )..where((r) => daRifare(r.viaggioId))).go();
      await (_db.delete(_db.note)..where((r) => daRifare(r.viaggioId))).go();
      await (_db.delete(_db.impostazioni)..where(
            (i) =>
                (i.chiave.like('$_copia%') | i.chiave.like('$_preparato%')) &
                i.chiave.isIn([
                  for (final id in visibili) ...[
                    '$_copia$id',
                    '$_preparato$id',
                  ],
                ]).not(),
          ))
          .go();
      // Il proprio profilo completo non si butta: dagli altri arriva solo il nome.
      await (_db.delete(
        _db.utenti,
      )..where((u) => u.id.equals(io ?? '').not())).go();

      await _db.batch((b) {
        b.insertAll(_db.viaggi, [for (final r in viaggi) _viaggio(r, adesso)]);
        b.insertAll(_db.partecipazioni, [
          for (final r in partecipazioni) _partecipazione(r, adesso),
        ]);
        b.insertAll(_db.giorni, [for (final r in giorni) _giorno(r, adesso)]);
        b.insertAll(_db.tappe, [for (final r in tappe) rigaTappa(r, adesso)]);
        b.insertAll(_db.spese, [for (final r in spese) rigaSpesa(r, adesso)]);
        b.insertAll(_db.speseQuote, [
          for (final r in quote) rigaQuota(r, adesso),
        ]);
        b.insertAll(_db.vociLista, [for (final r in voci) rigaVoce(r, adesso)]);
        b.insertAll(_db.note, [for (final r in note) _nota(r, adesso)]);
        b.insertAllOnConflictUpdate(_db.utenti, [
          for (final r in utenti)
            if (r['id'] != io) _utente(r, adesso),
        ]);
        b.insertAllOnConflictUpdate(_db.impostazioni, [
          for (final id in interi)
            ImpostazioniCompanion.insert(
              chiave: '$_copia$id',
              valore: adesso.toIso8601String(),
            ),
        ]);
      });
      await coda.riapplica();
    });
    await aggiornaTassi().catchError((_) {});
    await aggiornaConfigurazione().catchError((_) {});
    await aggiornaTraguardi().catchError((_) {});
  }

  static const _copia = 'copia:';

  /// Lo stato di un viaggio dalla sua riga del server, per decidere se la
  /// copia lo tiene intero.
  static StatoViaggio _statoDellaRiga(Map<String, dynamic> r, DateTime oggi) =>
      statoDelViaggio(
        registrato: r['stato'] as String,
        inizio: leggiData(r['data_inizio'] as String?),
        fine: leggiData(r['data_fine'] as String?),
        oggi: oggi,
      );

  /// Quando questo telefono ha scaricato l'ultima volta quello che c'è dentro
  /// il viaggio: giorni, tappe, spese, liste, note. `null` se non l'ha mai
  /// fatto — un viaggio finito che su questo telefono non si è mai aperto.
  Stream<DateTime?> osservaCopiaDelViaggio(String viaggioId) =>
      (_db.select(_db.impostazioni)
            ..where((i) => i.chiave.equals('$_copia$viaggioId')))
          .watchSingleOrNull()
          .map((r) => r == null ? null : DateTime.tryParse(r.valore));

  /// Come [osservaCopiaDelViaggio], una volta.
  Future<DateTime?> copiaDelViaggio(String viaggioId) async {
    final riga = await (_db.select(
      _db.impostazioni,
    )..where((i) => i.chiave.equals('$_copia$viaggioId'))).getSingleOrNull();
    return riga == null ? null : DateTime.tryParse(riga.valore);
  }

  /// Che cosa manca sul telefono di un viaggio aperto senza rete (07:
  /// `apertura_senza_rete`, H4): `viaggio` se non c'è; `contenuto` se è un
  /// viaggio finito di cui non si è mai scaricato quello che c'è dentro;
  /// `null` se c'è tutto.
  Future<String?> mancaDelViaggio(String viaggioId, DateTime oggi) async {
    final viaggio = await (_db.select(
      _db.viaggi,
    )..where((v) => v.id.equals(viaggioId))).getSingleOrNull();
    if (viaggio == null) return 'viaggio';
    if (viaggio.statoA(oggi).copiaSempreAggiornata) return null;
    if (await copiaDelViaggio(viaggioId) != null) return null;
    final giorni =
        await (_db.select(_db.giorni)
              ..where((g) => g.viaggioId.equals(viaggioId))
              ..limit(1))
            .get();
    return giorni.isEmpty ? 'contenuto' : null;
  }

  // ─── Sul posto ──────────────────────────────────────────────────────────

  static const _sulPosto = 'sul_posto:';

  /// Il viaggio, una volta, dalla copia.
  Future<Viaggio?> leggiViaggio(String id) =>
      (_db.select(_db.viaggi)..where((v) => v.id.equals(id))).getSingleOrNull();

  /// Se questa persona risulta sul posto nel viaggio (fase 3.4): per il
  /// server, o per questo telefono che deve ancora dirglielo.
  Future<bool> sulPosto(String viaggioId) async {
    final io = _io;
    if (io == null) return false;
    final mia =
        await (_db.select(_db.partecipazioni)..where(
              (p) => p.viaggioId.equals(viaggioId) & p.utenteId.equals(io),
            ))
            .getSingleOrNull();
    if (mia?.sulPostoIl != null) return true;
    final inAttesa = await (_db.select(
      _db.impostazioni,
    )..where((i) => i.chiave.equals('$_sulPosto$viaggioId'))).getSingleOrNull();
    return inAttesa != null;
  }

  /// Il telefono ha trovato la persona sul posto: lo ricorda, e lo dice al
  /// server appena può. Come gli eventi, parte anche giorni dopo, quando
  /// torna la rete; il server l'accetta fino al giorno dopo la fine.
  Future<void> ricordaSulPosto(String viaggioId) async {
    await _db
        .into(_db.impostazioni)
        .insertOnConflictUpdate(
          ImpostazioniCompanion.insert(
            chiave: '$_sulPosto$viaggioId',
            valore: DateTime.now().toUtc().toIso8601String(),
          ),
        );
    await mandaSulPosto().catchError((_) {});
  }

  /// Manda al server gli esiti «sul posto» che aspettano. Senza rete si
  /// ferma e riproverà; un viaggio che non è più in corso, o di cui non si
  /// fa più parte, non li vuole più, e si lasciano.
  Future<void> mandaSulPosto() async {
    final inAttesa = await (_db.select(
      _db.impostazioni,
    )..where((i) => i.chiave.like('$_sulPosto%'))).get();
    for (final r in inAttesa) {
      final viaggioId = r.chiave.substring(_sulPosto.length);
      try {
        final riga = await _alServer(
          () => _server.rpc<Map<String, dynamic>>(
            'segna_sul_posto',
            params: {'p_viaggio': viaggioId},
          ),
        );
        await _db
            .into(_db.partecipazioni)
            .insertOnConflictUpdate(
              _partecipazione(riga, DateTime.now().toUtc()),
            );
      } on ErroreTrolley catch (e) {
        if (e.serveLaRete) rethrow;
        if (e.codice != CodiciServer.nonInCorso &&
            e.codice != CodiciServer.nonTrovato) {
          continue;
        }
      }
      await (_db.delete(
        _db.impostazioni,
      )..where((i) => i.chiave.equals(r.chiave))).go();
    }
  }

  static const _nonOra = 'posizione_non_ora';
  static const _negataDetta = 'posizione_negata_detta';

  /// La persona ha detto «Non ora» alla posizione [oggi]: fino a domani non
  /// si richiede da sola (tela, 58).
  Future<void> posizioneNonOra(DateTime oggi) => _db
      .into(_db.impostazioni)
      .insertOnConflictUpdate(
        ImpostazioniCompanion.insert(chiave: _nonOra, valore: scriviData(oggi)),
      );

  Future<bool> posizioneNonOraOggi(DateTime oggi) async =>
      (await (_db.select(
        _db.impostazioni,
      )..where((i) => i.chiave.equals(_nonOra))).getSingleOrNull())?.valore ==
      scriviData(oggi);

  /// Se si è già detto, una volta, che senza posizione il viaggio non sarà
  /// verificato (tela, 59; 02, regola 9).
  Future<bool> posizioneNegataDetta() async =>
      await (_db.select(
        _db.impostazioni,
      )..where((i) => i.chiave.equals(_negataDetta))).getSingleOrNull() !=
      null;

  Future<void> segnaPosizioneNegataDetta() => _db
      .into(_db.impostazioni)
      .insertOnConflictUpdate(
        ImpostazioniCompanion.insert(chiave: _negataDetta, valore: '1'),
      );

  // ─── La chiusura ────────────────────────────────────────────────────────

  /// I giorni del viaggio, una volta, in ordine.
  Future<List<Giorno>> leggiGiorni(String viaggioId) =>
      (_db.select(_db.giorni)
            ..where(
              (g) => g.viaggioId.equals(viaggioId) & g.eliminatoIl.isNull(),
            )
            ..orderBy([(g) => OrderingTerm.asc(g.data)]))
          .get();

  /// Le tappe del viaggio, una volta.
  Future<List<Tappa>> leggiTappe(String viaggioId) =>
      (_db.select(_db.tappe)..where(
            (t) => t.viaggioId.equals(viaggioId) & t.eliminatoIl.isNull(),
          ))
          .get();

  /// Chi è nel viaggio adesso, una volta.
  Future<List<Partecipazione>> leggiPresenti(String viaggioId) =>
      (_db.select(_db.partecipazioni)..where(
            (p) =>
                p.viaggioId.equals(viaggioId) &
                p.stato.equals('attivo') &
                p.eliminatoIl.isNull(),
          ))
          .get();

  /// I propri traguardi, una volta.
  Future<List<TraguardoPreso>> leggiTraguardi() =>
      _db.select(_db.traguardi).get();

  /// La propria partecipazione a un viaggio, dalla copia.
  Future<Partecipazione?> miaPartecipazione(String viaggioId) async {
    final io = _io;
    if (io == null) return null;
    return (_db.select(_db.partecipazioni)
          ..where((p) => p.viaggioId.equals(viaggioId) & p.utenteId.equals(io)))
        .getSingleOrNull();
  }

  /// Le proprie partecipazioni, con il loro viaggio: per i traguardi, che si
  /// contano su tutti i viaggi verificati.
  Future<List<(Partecipazione, Viaggio)>> mieiViaggi() async {
    final query = _mieiViaggi();
    if (query == null) return const [];
    return _leggiMiei(await query.get());
  }

  /// Le stesse, osservate: il passaporto e il mappamondo cambiano quando un
  /// viaggio si chiude.
  Stream<List<(Partecipazione, Viaggio)>> osservaMieiViaggi() =>
      _mieiViaggi()?.watch().map(_leggiMiei) ?? Stream.value(const []);

  JoinedSelectStatement<HasResultSet, dynamic>? _mieiViaggi() {
    final io = _io;
    if (io == null) return null;
    return _db.select(_db.partecipazioni).join([
      innerJoin(
        _db.viaggi,
        _db.viaggi.id.equalsExp(_db.partecipazioni.viaggioId),
      ),
    ])..where(_db.partecipazioni.utenteId.equals(io));
  }

  List<(Partecipazione, Viaggio)> _leggiMiei(List<TypedResult> righe) => [
    for (final r in righe)
      (r.readTable(_db.partecipazioni), r.readTable(_db.viaggi)),
  ];

  /// Chiude il viaggio (10, regola 1; 02, regola 4): da solo dopo la fine,
  /// o prima a mano da chi ne è responsabile. Richiede la rete.
  Future<void> chiudiViaggio(String viaggioId) async {
    final riga = await _alServer(
      () => _server.rpc<Map<String, dynamic>>(
        'chiudi_viaggio',
        params: {'p_viaggio': viaggioId},
      ),
      messaggi: {
        CodiciServer.nonPermesso:
            'Solo chi è responsabile del viaggio lo chiude prima della fine.',
      },
    );
    await _db
        .into(_db.viaggi)
        .insertOnConflictUpdate(_viaggio(riga, DateTime.now().toUtc()));
  }

  /// Scrive la propria verifica del viaggio chiuso, una volta. Richiede la
  /// rete.
  Future<void> segnaVerifica(
    String viaggioId, {
    required bool verificato,
  }) async {
    final riga = await _alServer(
      () => _server.rpc<Map<String, dynamic>>(
        'segna_verifica',
        params: {'p_viaggio': viaggioId, 'p_verificato': verificato},
      ),
    );
    await _db
        .into(_db.partecipazioni)
        .insertOnConflictUpdate(_partecipazione(riga, DateTime.now().toUtc()));
  }

  /// Prende i traguardi [tipi] con il viaggio verificato, e mette nella
  /// copia tutti i propri. Richiede la rete.
  Future<void> prendiTraguardi(String viaggioId, Iterable<String> tipi) async {
    final righe = await _alServer(
      () => _server.rpc<List<dynamic>>(
        'prendi_traguardi',
        params: {'p_viaggio': viaggioId, 'p_tipi': tipi.toList()},
      ),
    );
    await _traguardiNellaCopia(righe.cast<Map<String, dynamic>>());
  }

  /// Riscarica i propri traguardi. Senza rete restano quelli di prima.
  Future<void> aggiornaTraguardi() async {
    if (_io == null) return;
    final righe = await _alServer(
      () => _server.from('traguardo').select('id, tipo, viaggio_id, preso_il'),
    );
    await _traguardiNellaCopia(righe);
  }

  Future<void> _traguardiNellaCopia(List<Map<String, dynamic>> righe) {
    final adesso = DateTime.now().toUtc();
    return _db.transaction(() async {
      await _db.delete(_db.traguardi).go();
      await _db.batch(
        (b) => b.insertAll(_db.traguardi, [
          for (final r in righe)
            TraguardiCompanion.insert(
              id: r['id'] as String,
              tipo: r['tipo'] as String,
              viaggioId: r['viaggio_id'] as String,
              presoIl: r['preso_il'] as String,
              scaricatoIl: adesso,
            ),
        ]),
      );
    });
  }

  /// I propri traguardi, nell'ordine in cui si sono presi.
  Stream<List<TraguardoPreso>> osservaTraguardi() =>
      (_db.select(_db.traguardi)..orderBy([
            (t) => OrderingTerm.asc(t.presoIl),
            (t) => OrderingTerm.asc(t.tipo),
          ]))
          .watch();

  static const _riepilogoVisto = 'riepilogo_visto:';

  /// Il riepilogo di chiusura si apre da solo una volta per viaggio, su
  /// questo telefono.
  Future<bool> riepilogoVisto(String viaggioId) async =>
      await (_db.select(_db.impostazioni)
            ..where((i) => i.chiave.equals('$_riepilogoVisto$viaggioId')))
          .getSingleOrNull() !=
      null;

  Future<void> segnaRiepilogoVisto(String viaggioId) => _db
      .into(_db.impostazioni)
      .insertOnConflictUpdate(
        ImpostazioniCompanion.insert(
          chiave: '$_riepilogoVisto$viaggioId',
          valore: '1',
        ),
      );

  // ─── Il mappamondo ──────────────────────────────────────────────────────

  static const _scoperto = 'scoperto:';

  /// I paesi già grattati col dito (tela, 95–97), da chi ha il telefono in
  /// mano: si ricordano su questo telefono, come il riepilogo visto.
  Stream<Set<String>> osservaPaesiScoperti() {
    final prefisso = '$_scoperto$_io:';
    return (_db.select(
      _db.impostazioni,
    )..where((i) => i.chiave.like('$prefisso%'))).watch().map(
      (righe) => {for (final r in righe) r.chiave.substring(prefisso.length)},
    );
  }

  Future<void> segnaPaeseScoperto(String paese) => _db
      .into(_db.impostazioni)
      .insertOnConflictUpdate(
        ImpostazioniCompanion.insert(
          chiave: '$_scoperto$_io:$paese',
          valore: '1',
        ),
      );

  // ─── Prima di partire ───────────────────────────────────────────────────

  static const _preparato = 'preparato:';

  /// «Preparalo per l'uso senza rete» (09, regola 6; 02 §1): l'ultima versione
  /// di tutto il viaggio, e i tassi di cambio di adesso anche se quelli sul
  /// telefono sono di poche ore fa. Richiede la rete: senza, lo dice con un
  /// [ErroreTrolley] e il viaggio resta com'era. I tassi sono un di più: se
  /// non arrivano, restano gli ultimi, con la loro data.
  Future<void> preparaViaggio(String viaggioId) async {
    await aggiornaCopia(viaggioId: viaggioId);
    await aggiornaTassi(forza: true).catchError((_) {});
    await _db
        .into(_db.impostazioni)
        .insertOnConflictUpdate(
          ImpostazioniCompanion.insert(
            chiave: '$_preparato$viaggioId',
            valore: DateTime.now().toUtc().toIso8601String(),
          ),
        );
  }

  /// Quando la persona ha preparato il viaggio su questo telefono, se l'ha
  /// fatto.
  Stream<DateTime?> osservaPreparato(String viaggioId) =>
      (_db.select(_db.impostazioni)
            ..where((i) => i.chiave.equals('$_preparato$viaggioId')))
          .watchSingleOrNull()
          .map((r) => r == null ? null : DateTime.tryParse(r.valore));

  /// Riscarica la configurazione: poche righe, e cambiano senza un rilascio.
  /// Senza rete resta l'ultima.
  Future<void> aggiornaConfigurazione() async {
    final righe = await _alServer(
      () => _server.from('configurazione').select('chiave, valore'),
    );
    final adesso = DateTime.now().toUtc();
    await _db.transaction(() async {
      await _db.delete(_db.configurazioni).go();
      await _db.batch(
        (b) => b.insertAll(_db.configurazioni, [
          for (final r in righe)
            ConfigurazioniCompanion.insert(
              chiave: r['chiave'] as String,
              valore: jsonEncode(r['valore']),
              scaricatoIl: adesso,
            ),
        ]),
      );
    });
  }

  /// Da quanto tempo i tassi sul telefono bastano: il server li scarica due
  /// volte al giorno, e chiederli più spesso non porta niente di nuovo.
  static const durataTassi = Duration(hours: 6);

  /// Riscarica i tassi di cambio, se quelli sul telefono hanno più di
  /// [durataTassi] o se si [forza]. Senza rete restano gli ultimi: si usano
  /// dicendo di quando sono (06, regola 6).
  Future<void> aggiornaTassi({DateTime? adesso, bool forza = false}) async {
    final ora = (adesso ?? DateTime.now()).toUtc();
    final ultimo = await (_db.selectOnly(
      _db.tassiCambio,
    )..addColumns([_db.tassiCambio.scaricatoIl.max()])).getSingle();
    final il = ultimo.read(_db.tassiCambio.scaricatoIl.max());
    if (!forza && il != null && ora.difference(il.toUtc()) < durataTassi) {
      return;
    }
    final righe = await _alServer(
      () => _server.from('tasso_cambio').select('valuta, per_euro, del'),
    );
    if (righe.isEmpty) return;
    await _db.transaction(() async {
      await _db.delete(_db.tassiCambio).go();
      await _db.batch(
        (b) => b.insertAll(_db.tassiCambio, [
          for (final r in righe)
            TassiCambioCompanion.insert(
              valuta: (r['valuta'] as String).trim(),
              perEuro: '${r['per_euro']}',
              del: r['del'] as String,
              scaricatoIl: ora,
            ),
        ]),
      );
    });
  }

  /// Mette nella copia le righe di un viaggio restituite dal server dopo una
  /// scrittura: il viaggio, i suoi giorni attivi, chi partecipa e, se ci
  /// sono, le voci che la scrittura ha cambiato.
  Future<void> _nellaCopia(Map<String, dynamic> righe) async {
    final viaggio = righe['viaggio'] as Map<String, dynamic>;
    final id = viaggio['id'] as String;
    final adesso = DateTime.now().toUtc();
    await _db.transaction(() async {
      await _db
          .into(_db.viaggi)
          .insertOnConflictUpdate(_viaggio(viaggio, adesso));
      await (_db.delete(_db.giorni)..where((g) => g.viaggioId.equals(id))).go();
      await _db.batch((b) {
        b.insertAll(_db.giorni, [
          for (final r in righe['giorni'] as List)
            _giorno(r as Map<String, dynamic>, adesso),
        ]);
        b.insertAllOnConflictUpdate(_db.partecipazioni, [
          for (final r in (righe['partecipazioni'] as List?) ?? const [])
            _partecipazione(r as Map<String, dynamic>, adesso),
        ]);
      });
      for (final r in (righe['voci'] as List?) ?? const []) {
        await coda.nellaCopiaVoce(r as Map<String, dynamic>);
      }
    });
  }

  Stream<Utente?> osservaProfilo() {
    final io = _io;
    if (io == null) return Stream.value(null);
    return (_db.select(
      _db.utenti,
    )..where((u) => u.id.equals(io))).watchSingleOrNull();
  }

  /// I viaggi, dal più recente, ciascuno con i nomi di chi partecipa: il
  /// creatore per primo. Le idee archiviate stanno a parte: si chiedono con
  /// [archiviati].
  Stream<List<ViaggioInElenco>> osservaViaggiInElenco({
    bool archiviati = false,
  }) {
    final query =
        _db.select(_db.viaggi).join([
            leftOuterJoin(
              _db.partecipazioni,
              _db.partecipazioni.viaggioId.equalsExp(_db.viaggi.id) &
                  _db.partecipazioni.stato.equals('attivo'),
            ),
            leftOuterJoin(
              _db.utenti,
              _db.utenti.id.equalsExp(_db.partecipazioni.utenteId),
            ),
          ])
          // I viaggi passati stanno nel passaporto: non sono viaggi da fare,
          // né da mettere sulla mappa.
          ..where(
            _db.viaggi.eliminatoIl.isNull() &
                _db.viaggi.importato.equals(false) &
                (archiviati
                    ? _db.viaggi.stato.equals('archiviato')
                    : _db.viaggi.stato.equals('archiviato').not()),
          )
          ..orderBy([
            OrderingTerm.desc(_db.viaggi.creatoIl),
            OrderingTerm.asc(_db.partecipazioni.ruolo),
          ]);
    return query.watch().map((righe) {
      final perViaggio = <String, ViaggioInElenco>{};
      for (final r in righe) {
        final viaggio = r.readTable(_db.viaggi);
        final elenco = perViaggio.putIfAbsent(
          viaggio.id,
          () => ViaggioInElenco(viaggio, []),
        );
        final nome = r.readTableOrNull(_db.utenti)?.nome;
        if (nome != null) elenco.persone.add(nome);
      }
      return perViaggio.values.toList();
    });
  }

  Stream<Viaggio?> osservaViaggio(String id) => (_db.select(
    _db.viaggi,
  )..where((v) => v.id.equals(id))).watchSingleOrNull();

  /// I giorni del viaggio, in ordine.
  Stream<List<Giorno>> osservaGiorni(String viaggioId) =>
      (_db.select(_db.giorni)
            ..where(
              (g) => g.viaggioId.equals(viaggioId) & g.eliminatoIl.isNull(),
            )
            ..orderBy([(g) => OrderingTerm.asc(g.data)]))
          .watch();

  /// Le tappe del viaggio, di tutti i giorni, ciascuna nel suo ordine. A pari
  /// ordine — due telefoni che ne aggiungono una insieme — viene prima quella
  /// nata prima.
  Stream<List<Tappa>> osservaTappe(String viaggioId) =>
      (_db.select(_db.tappe)
            ..where(
              (t) => t.viaggioId.equals(viaggioId) & t.eliminatoIl.isNull(),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.ordine),
              (t) => OrderingTerm.asc(t.creatoIl),
            ]))
          .watch();

  /// Per viaggio, quante tappe ha e quante hanno un posto sulla mappa: lo
  /// dice la scelta del viaggio nella mappa (tela, 58).
  Stream<Map<String, ({int tappe, int conPosto})>> osservaTappeDeiViaggi() =>
      (_db.select(_db.tappe)..where((t) => t.eliminatoIl.isNull())).watch().map(
        (righe) {
          final conti = <String, ({int tappe, int conPosto})>{};
          for (final t in righe) {
            final c = conti[t.viaggioId] ?? (tappe: 0, conPosto: 0);
            conti[t.viaggioId] = (
              tappe: c.tappe + 1,
              conPosto: c.conPosto + (t.lat != null && t.lon != null ? 1 : 0),
            );
          }
          return conti;
        },
      );

  /// Le spese del viaggio, nell'ordine in cui sono state registrate.
  Stream<List<Spesa>> osservaSpese(String viaggioId) =>
      (_db.select(_db.spese)
            ..where(
              (s) => s.viaggioId.equals(viaggioId) & s.eliminatoIl.isNull(),
            )
            ..orderBy([(s) => OrderingTerm.asc(s.creatoIl)]))
          .watch();

  /// Per chi sono le spese del viaggio: le quote, nella valuta di ogni spesa.
  Stream<List<SpesaQuota>> osservaQuote(String viaggioId) =>
      (_db.select(_db.speseQuote)..where(
            (q) => q.viaggioId.equals(viaggioId) & q.eliminatoIl.isNull(),
          ))
          .watch();

  static const _dueSpese = 'due_spese:';

  /// Le coppie di spese che sembravano la stessa e che chi le ha registrate
  /// ha detto essere due: l'avviso non torna (06, casi limite). Restano su
  /// questo telefono: è una cosa che si dice a sé.
  Stream<Set<String>> osservaDueSpese() =>
      (_db.select(
        _db.impostazioni,
      )..where((i) => i.chiave.like('$_dueSpese%'))).watch().map(
        (righe) => {
          for (final r in righe) r.chiave.substring(_dueSpese.length),
        },
      );

  /// Segna che due spese simili sono due spese. [chiave] viene da
  /// `chiaveDueSpese`.
  Future<void> sonoDueSpese(String chiave) => _db
      .into(_db.impostazioni)
      .insertOnConflictUpdate(
        ImpostazioniCompanion.insert(chiave: '$_dueSpese$chiave', valore: 'si'),
      );

  /// Tutte le partecipazioni del viaggio, anche di chi è uscito: chi c'era
  /// quando una spesa senza quote è stata registrata (06, regola 10).
  Stream<List<Partecipazione>> osservaPresenze(String viaggioId) => (_db.select(
    _db.partecipazioni,
  )..where((p) => p.viaggioId.equals(viaggioId))).watch();

  /// Le cose da portare del viaggio che la persona vede: la lista del
  /// viaggio, di tutti, e la propria, che vede solo lei (05, regole 1 e 3).
  /// Le personali degli altri il server non le manda; se una fosse rimasta
  /// nella copia, qui non passa. Nell'ordine in cui sono nate; quale prima e
  /// quale dopo lo decide il dominio (dominio/liste.dart).
  Stream<List<VoceLista>> osservaVoci(String viaggioId) {
    final io = _io;
    if (io == null) return Stream.value(const []);
    return (_db.select(_db.vociLista)
          ..where(
            (v) =>
                v.viaggioId.equals(viaggioId) &
                (v.tipo.equals(TipoLista.viaggio.codice) |
                    v.proprietarioId.equals(io)) &
                v.eliminatoIl.isNull(),
          )
          ..orderBy([(v) => OrderingTerm.asc(v.creatoIl)]))
        .watch();
  }

  /// Una voce com'è nella copia, anche di un'altra lista; `null` se non c'è.
  Future<VoceLista?> leggiVoce(String id) => (_db.select(
    _db.vociLista,
  )..where((v) => v.id.equals(id))).getSingleOrNull();

  static const _vociLasciate = 'voci_lasciate:';

  /// Le voci tornate libere di cui la persona ha già visto l'avviso, su
  /// questo telefono (tela, 44: «Ho capito»).
  Stream<Set<String>> osservaVociLasciateViste(String viaggioId) =>
      _visteDa(viaggioId).watchSingleOrNull().map(_viste);

  /// L'avviso delle voci tornate libere è stato visto: quelle [ids] non lo
  /// fanno più tornare.
  Future<void> vociLasciateViste(String viaggioId, Iterable<String> ids) =>
      _db.transaction(() async {
        final viste = _viste(await _visteDa(viaggioId).getSingleOrNull());
        await _db
            .into(_db.impostazioni)
            .insertOnConflictUpdate(
              ImpostazioniCompanion.insert(
                chiave: '$_vociLasciate$viaggioId',
                valore: jsonEncode([
                  ...{...viste, ...ids},
                ]),
              ),
            );
      });

  SimpleSelectStatement<$ImpostazioniTable, Impostazione> _visteDa(
    String viaggioId,
  ) =>
      _db.select(_db.impostazioni)
        ..where((i) => i.chiave.equals('$_vociLasciate$viaggioId'));

  static Set<String> _viste(Impostazione? riga) {
    final ids = riga == null ? null : jsonDecode(riga.valore);
    return {
      if (ids is List)
        for (final id in ids)
          if (id is String) id,
    };
  }

  /// Le note del viaggio, dalla più recente.
  Stream<List<Nota>> osservaNote(String viaggioId) =>
      (_db.select(_db.note)
            ..where(
              (n) => n.viaggioId.equals(viaggioId) & n.eliminatoIl.isNull(),
            )
            ..orderBy([(n) => OrderingTerm.desc(n.creatoIl)]))
          .watch();

  Stream<Nota?> osservaNota(String id) =>
      (_db.select(_db.note)
            ..where((n) => n.id.equals(id) & n.eliminatoIl.isNull()))
          .watchSingleOrNull();

  /// I modelli da consigliare, come li dice la configurazione del server:
  /// una frase per riga. Vuoto finché non è mai arrivata (decisioni/prodotto.md,
  /// "Quali modelli suggerire": l'elenco non sta nel codice).
  Stream<List<String>> osservaModelliSuggeriti() =>
      (_db.select(_db.configurazioni)
            ..where((c) => c.chiave.equals('modelli_suggeriti')))
          .watchSingleOrNull()
          .map((riga) {
            final valore = riga == null ? null : jsonDecode(riga.valore);
            return [
              if (valore is List)
                for (final v in valore)
                  if (v is String && v.trim().isNotEmpty) v.trim(),
            ];
          });

  /// I nomi di tutti quelli che sono passati dal viaggio, anche chi è uscito:
  /// le sue spese restano, e restano sue (06, regola 10).
  Stream<Map<String, String>> osservaNomi(String viaggioId) {
    final query = _db.select(_db.partecipazioni).join([
      innerJoin(
        _db.utenti,
        _db.utenti.id.equalsExp(_db.partecipazioni.utenteId),
      ),
    ])..where(_db.partecipazioni.viaggioId.equals(viaggioId));
    return query.watch().map(
      (righe) => {
        for (final r in righe)
          r.readTable(_db.utenti).id: r.readTable(_db.utenti).nome,
      },
    );
  }

  /// Gli ultimi tassi noti, per valuta.
  Stream<List<TassoCambio>> osservaTassi() =>
      _db.select(_db.tassiCambio).watch();

  /// Il mio ruolo nel viaggio: `creatore` o `partecipante`.
  Future<String?> mioRuolo(String viaggioId) async {
    final io = _io;
    if (io == null) return null;
    final p =
        await (_db.select(_db.partecipazioni)..where(
              (p) => p.viaggioId.equals(viaggioId) & p.utenteId.equals(io),
            ))
            .getSingleOrNull();
    return p?.ruolo;
  }

  /// Chi sono, per riconoscere le proprie tappe.
  String? get io => _io;

  /// Chi partecipa, con il nome: chi è responsabile del viaggio per primo.
  /// Chi è uscito o è stato rimosso non compare qui ([osservaUsciti]), ma i
  /// suoi contributi restano nel viaggio.
  Stream<List<(Partecipazione, Utente?)>> osservaPartecipanti(
    String viaggioId,
  ) => _osservaPartecipazioni(viaggioId, const ['attivo']);

  /// Chi c'era e non c'è più: è uscito, o è stato tolto. Quello che ha
  /// aggiunto resta, con il suo nome (03, regola 8).
  Stream<List<(Partecipazione, Utente?)>> osservaUsciti(String viaggioId) =>
      _osservaPartecipazioni(viaggioId, const ['uscito', 'rimosso']);

  Stream<List<(Partecipazione, Utente?)>> _osservaPartecipazioni(
    String viaggioId,
    List<String> stati,
  ) {
    final query =
        _db.select(_db.partecipazioni).join([
            leftOuterJoin(
              _db.utenti,
              _db.utenti.id.equalsExp(_db.partecipazioni.utenteId),
            ),
          ])
          ..where(
            _db.partecipazioni.viaggioId.equals(viaggioId) &
                _db.partecipazioni.stato.isIn(stati),
          )
          ..orderBy([
            OrderingTerm.asc(_db.partecipazioni.ruolo),
            OrderingTerm.asc(_db.utenti.nome),
          ]);
    return query.watch().map(
      (righe) => [
        for (final r in righe)
          (r.readTable(_db.partecipazioni), r.readTableOrNull(_db.utenti)),
      ],
    );
  }

  // ─── Il primo minuto di chi entra da un invito ──────────────────────────

  static const _benvenuto = 'benvenuto:';

  /// Segna che la persona è appena entrata nel viaggio da un invito: la
  /// schermata del viaggio le dà il benvenuto e qualcosa di suo da fare (03,
  /// regola 9).
  Future<void> segnaBenvenuto(String viaggioId) => _db
      .into(_db.impostazioni)
      .insertOnConflictUpdate(
        ImpostazioniCompanion.insert(
          chiave: '$_benvenuto$viaggioId',
          valore: DateTime.now().toUtc().toIso8601String(),
        ),
      );

  Future<void> chiudiBenvenuto(String viaggioId) => (_db.delete(
    _db.impostazioni,
  )..where((i) => i.chiave.equals('$_benvenuto$viaggioId'))).go();

  /// Se il benvenuto va mostrato: la persona è entrata da un invito su questo
  /// telefono, non l'ha chiuso, e non ha ancora aggiunto niente di suo — una
  /// tappa, una spesa, una cosa da portare, un documento. Al primo
  /// contributo ha fatto il suo lavoro, e sparisce.
  Stream<bool> osservaBenvenuto(String viaggioId) {
    final io = _io;
    if (io == null) return Stream.value(false);
    return _db
        .customSelect(
          'SELECT EXISTS (SELECT 1 FROM impostazione WHERE chiave = ?1) '
          'AND NOT EXISTS (SELECT 1 FROM tappa WHERE viaggio_id = ?2 '
          '  AND creato_da = ?3 AND eliminato_il IS NULL) '
          'AND NOT EXISTS (SELECT 1 FROM spesa WHERE viaggio_id = ?2 '
          '  AND creato_da = ?3 AND eliminato_il IS NULL) '
          'AND NOT EXISTS (SELECT 1 FROM voce_lista WHERE viaggio_id = ?2 '
          '  AND proprietario_id = ?3 AND eliminato_il IS NULL) '
          'AND NOT EXISTS (SELECT 1 FROM documento WHERE viaggio_id = ?2 '
          '  AND proprietario_id = ?3) AS mostra',
          variables: [
            Variable.withString('$_benvenuto$viaggioId'),
            Variable.withString(viaggioId),
            Variable.withString(io),
          ],
          readsFrom: {
            _db.impostazioni,
            _db.tappe,
            _db.spese,
            _db.vociLista,
            _db.documenti,
          },
        )
        .watchSingle()
        .map((r) => r.read<bool>('mostra'));
  }

  // ─── I viaggi lasciati ──────────────────────────────────────────────────

  static const _lasciato = 'lasciato:';

  /// Per ogni viaggio che era sul telefono e che il server non manda più
  /// perché se ne è usciti o si è stati tolti, un avviso per l'elenco. I
  /// gesti in coda per quel viaggio non arriveranno più: si contano, lo si
  /// dice, e si tolgono invece di riprovarli per sempre (02, casi limite). Un
  /// viaggio in cui si è rientrati non ha più bisogno del suo avviso.
  Future<void> _segnaLasciati({
    required Set<String> visibili,
    required Map<String, String> lasciati,
  }) async {
    await (_db.delete(_db.impostazioni)..where(
          (i) => i.chiave.isIn([for (final id in visibili) '$_lasciato$id']),
        ))
        .go();
    final locali = await _db.select(_db.viaggi).get();
    for (final v in locali) {
      final stato = lasciati[v.id];
      if (visibili.contains(v.id) || stato == null) continue;
      final gestiPersi = await (_db.delete(
        _db.codaScrittura,
      )..where((o) => o.viaggioId.equals(v.id))).go();
      await _db
          .into(_db.impostazioni)
          .insertOnConflictUpdate(
            ImpostazioniCompanion.insert(
              chiave: '$_lasciato${v.id}',
              valore: jsonEncode({
                'nome': v.destinazione?.nome,
                'motivo': stato,
                'gesti_persi': gestiPersi,
              }),
            ),
          );
      await _dimenticaSegni(v.id);
    }
  }

  /// I viaggi lasciati di cui la persona non ha ancora visto l'avviso.
  Stream<List<ViaggioLasciato>> osservaViaggiLasciati() =>
      (_db.select(_db.impostazioni)
            ..where((i) => i.chiave.like('$_lasciato%'))
            ..orderBy([(i) => OrderingTerm.asc(i.chiave)]))
          .watch()
          .map((righe) => [for (final r in righe) ?_lasciatoDa(r)]);

  /// Toglie l'avviso: la persona l'ha visto.
  Future<void> dimenticaViaggioLasciato(String viaggioId) => (_db.delete(
    _db.impostazioni,
  )..where((i) => i.chiave.equals('$_lasciato$viaggioId'))).go();

  static ViaggioLasciato? _lasciatoDa(Impostazione riga) {
    final dati = jsonDecode(riga.valore);
    if (dati is! Map) return null;
    return ViaggioLasciato(
      viaggioId: riga.chiave.substring(_lasciato.length),
      nome: dati['nome'] as String?,
      motivo: dati['motivo'] == 'rimosso'
          ? MotivoUscita.rimosso
          : MotivoUscita.uscito,
      gestiPersi: (dati['gesti_persi'] as int?) ?? 0,
    );
  }

  /// Toglie dalla copia un viaggio da cui si è usciti, con tutto quello che
  /// gli era agganciato, i gesti ancora in coda e i segni di questo telefono.
  /// I documenti no: stanno in un'altra cartella, e li toglie chi chiama
  /// (dati/documenti.dart).
  Future<void> _togliDallaCopia(String viaggioId) => _db.transaction(() async {
    await (_db.delete(_db.viaggi)..where((v) => v.id.equals(viaggioId))).go();
    await (_db.delete(
      _db.partecipazioni,
    )..where((p) => p.viaggioId.equals(viaggioId))).go();
    await (_db.delete(
      _db.giorni,
    )..where((g) => g.viaggioId.equals(viaggioId))).go();
    await (_db.delete(
      _db.tappe,
    )..where((t) => t.viaggioId.equals(viaggioId))).go();
    await (_db.delete(
      _db.spese,
    )..where((s) => s.viaggioId.equals(viaggioId))).go();
    await (_db.delete(
      _db.speseQuote,
    )..where((q) => q.viaggioId.equals(viaggioId))).go();
    await (_db.delete(
      _db.vociLista,
    )..where((v) => v.viaggioId.equals(viaggioId))).go();
    await (_db.delete(
      _db.note,
    )..where((n) => n.viaggioId.equals(viaggioId))).go();
    await (_db.delete(
      _db.codaScrittura,
    )..where((o) => o.viaggioId.equals(viaggioId))).go();
    await _dimenticaSegni(viaggioId);
  });

  /// I segni di questo telefono legati a un viaggio: il benvenuto, il
  /// sollecito dell'idea, le voci tornate libere già viste, quando lo si è
  /// scaricato e preparato.
  Future<void> _dimenticaSegni(String viaggioId) =>
      (_db.delete(_db.impostazioni)..where(
            (i) => i.chiave.isIn([
              '$_benvenuto$viaggioId',
              '$_vociLasciate$viaggioId',
              _chiaveSollecito(viaggioId),
              '$_copia$viaggioId',
              '$_preparato$viaggioId',
              '$_sulPosto$viaggioId',
              '$_riepilogoVisto$viaggioId',
            ]),
          ))
          .go();

  // ─── Scritture che richiedono la rete ───────────────────────────────────

  /// Un viaggio nuovo. Con un [programma] nasce definito, con i suoi giorni;
  /// senza, è un'idea con il suo [periodo], anche nessuno (02, regola 1).
  Future<String> creaViaggio({
    required Destinazione destinazione,
    Periodo? periodo,
    Programma? programma,
  }) async {
    final id = const Uuid().v4();
    final righe = await _alServer(
      () => _server.rpc<Map<String, dynamic>>(
        'crea_viaggio',
        params: {
          'p_id': id,
          'p_destinazione_citta': destinazione.citta,
          'p_destinazione_paese': destinazione.paese,
          'p_periodo': programma == null ? periodo?.testo : null,
          ..._dateDelProgramma(programma),
          'p_giorni': programma == null
              ? const []
              : _giorniPerIlServer(programma),
        },
      ),
    );
    await _nellaCopia(righe);
    return id;
  }

  /// Un viaggio passato, inserito come ricordo (10, regole 5–6): nasce
  /// chiuso e importato, con il mese in cui è cominciato e i giorni se ci si
  /// ricorda. Non è un viaggio creato: non conta fra quelli (07, regola 4).
  Future<String> aggiungiViaggioPassato({
    required Destinazione destinazione,
    required Periodo quando,
    int? giorni,
  }) async {
    final id = const Uuid().v4();
    final righe = await _alServer(
      () => _server.rpc<Map<String, dynamic>>(
        'aggiungi_viaggio_passato',
        params: {
          'p_id': id,
          'p_destinazione_citta': destinazione.citta,
          'p_destinazione_paese': destinazione.paese,
          'p_periodo': quando.testo,
          'p_giorni': giorni,
        },
      ),
    );
    await _nellaCopia(righe);
    return id;
  }

  /// Cambia dove, quando e quanti giorni di un viaggio passato, sulla
  /// versione che la persona ha visto.
  Future<void> cambiaViaggioPassato(
    Viaggio viaggio, {
    required Destinazione destinazione,
    required Periodo quando,
    int? giorni,
  }) {
    assert(viaggio.importato, 'solo un viaggio passato si cambia così');
    return _aggiornaViaggio(viaggio, {
      'destinazione_citta': destinazione.citta,
      'destinazione_paese': destinazione.paese,
      'periodo_approssimativo': quando.testo,
      'giorni_ricordati': giorni,
    }, statoAtteso: 'chiuso');
  }

  /// Toglie un viaggio passato dal passaporto: lo si è aggiunto a mano, lo si
  /// toglie a mano. Si marca, come ogni cosa; un viaggio vero chiuso invece
  /// resta per sempre (10, regola 8).
  Future<void> togliViaggioPassato(Viaggio viaggio) {
    assert(viaggio.importato, 'solo un viaggio passato si toglie');
    return _aggiornaViaggio(viaggio, {
      'eliminato_il': DateTime.now().toUtc().toIso8601String(),
    }, statoAtteso: 'chiuso');
  }

  /// Fissa o sposta le date. Un'idea diventa definita; i giorni che escono si
  /// marcano e tornano se le date tornano a comprenderli. Con la versione su
  /// cui la persona ha deciso: se qualcuno ha cambiato le date nel frattempo,
  /// si mostrano le due versioni ([Conflitto]).
  Future<void> programma(Viaggio viaggio, Programma programma) => _quando(
    viaggio,
    (base) => {
      ...base,
      'stato': base['stato'] == 'idea' || base['stato'] == 'archiviato'
          ? 'definito'
          : base['stato'],
      'periodo_approssimativo': null,
      'data_inizio': scriviData(programma.inizio),
      'data_fine': scriviData(programma.fine),
      'ora_arrivo': scriviOra(programma.arrivo),
      'ora_partenza': scriviOra(programma.partenza),
    },
  );

  /// Da definito a idea: le date spariscono, quello che vi era agganciato resta
  /// e torna se si rifissano le stesse date (02, casi limite).
  Future<void> tornaIdea(Viaggio viaggio, {Periodo? periodo}) => _quando(
    viaggio,
    (base) => {
      ...base,
      'stato': 'idea',
      'periodo_approssimativo': periodo?.testo,
      'data_inizio': null,
      'data_fine': null,
      'ora_arrivo': null,
      'ora_partenza': null,
    },
  );

  /// Cambia il periodo di un'idea.
  Future<void> cambiaPeriodo(Viaggio viaggio, Periodo? periodo) => _quando(
    viaggio,
    (base) => {...base, 'periodo_approssimativo': periodo?.testo},
  );

  /// Riprende un'idea dall'archivio, con un periodo nuovo: quello vecchio è
  /// passato (02, casi limite).
  Future<void> riprendi(Viaggio viaggio, Periodo? periodo) => _quando(
    viaggio,
    (base) => {
      ...base,
      'stato': 'idea',
      'periodo_approssimativo': periodo?.testo,
    },
  );

  /// Cambia quando si parte: dal viaggio come la persona l'ha visto a [mia].
  Future<void> _quando(
    Viaggio viaggio,
    Map<String, Object?> Function(Map<String, Object?> base) mia,
  ) {
    final base = ritrattoViaggio(rigaDelViaggio(viaggio));
    return _conLaVersione(
      _viaggioVersionato(viaggio.id),
      riferimento: base,
      versione: viaggio.versione,
      mia: mia(base),
    );
  }

  /// Aggiorna il viaggio solo se è ancora nello stato in cui la persona l'ha
  /// visto, con la versione su cui ha deciso. Per le scritture che l'app fa da
  /// sé, come archiviare un'idea scaduta: lì non c'è nessuno a cui chiedere.
  Future<void> _aggiornaViaggio(
    Viaggio viaggio,
    Map<String, Object?> valori, {
    required String statoAtteso,
  }) async {
    final righe = await _alServer(
      () => _server
          .from('viaggio')
          .update({...valori, 'versione': viaggio.versione})
          .eq('id', viaggio.id)
          .eq('stato', statoAtteso)
          .select(),
    );
    if (righe.isEmpty) {
      await aggiornaCopia(viaggioId: viaggio.id).catchError((_) {});
      throw const ErroreTrolley(
        'Questo viaggio è cambiato nel frattempo. Ora vedi com\'è adesso.',
      );
    }
    await _db
        .into(_db.viaggi)
        .insertOnConflictUpdate(_viaggio(righe.single, DateTime.now().toUtc()));
  }

  /// Un nuovo codice d'invito per il viaggio. Ogni invito è un link nuovo:
  /// così chi è stato tolto può rientrare con uno creato dopo (03, regola 6).
  Future<String> creaInvito(String viaggioId) async {
    final riga = await _alServer(
      () => _server
          .from('invito')
          .insert({'id': const Uuid().v4(), 'viaggio_id': viaggioId})
          .select('token')
          .single(),
    );
    return riga['token'] as String;
  }

  /// Entra nel viaggio del codice. Dice anche se la persona c'era già: il
  /// secondo link riconosce chi è dentro e apre il viaggio (03, casi limite),
  /// senza contarlo come un arrivo nuovo.
  Future<({String viaggioId, bool giaDentro})> accettaInvito(
    String codice,
  ) async {
    final viaggioId = await _alServer(
      () => _server.rpc<String>('accetta_invito', params: {'p_token': codice}),
      messaggi: {
        CodiciServer.nonTrovato:
            'Questo codice non corrisponde a nessun viaggio, o è stato '
            'ritirato. Controlla di averlo scritto bene, o chiedi un nuovo '
            'invito.',
        CodiciServer.nonPermesso:
            'Non fai più parte di questo viaggio: per rientrare ti serve un '
            'invito nuovo di chi ne è responsabile.',
      },
    );
    final io = _io;
    final giaDentro =
        io != null &&
        await (_db.select(_db.partecipazioni)..where(
                  (p) =>
                      p.viaggioId.equals(viaggioId) &
                      p.utenteId.equals(io) &
                      p.stato.equals('attivo'),
                ))
                .getSingleOrNull() !=
            null;
    await aggiornaCopia(viaggioId: viaggioId);
    return (viaggioId: viaggioId, giaDentro: giaDentro);
  }

  /// I link d'invito ancora validi del viaggio, dal più recente: gli inviti
  /// in sospeso (03, schermate). Richiede la rete: non stanno nella copia.
  Future<List<InvitoValido>> invitiValidi(String viaggioId) async {
    final righe = await _alServer(
      () => _server
          .from('invito')
          .select('creato_da, creato_il')
          .eq('viaggio_id', viaggioId)
          .isFilter('eliminato_il', null)
          .order('creato_il'),
    );
    return [
      for (final r in righe)
        InvitoValido(
          creatoDa: r['creato_da'] as String,
          creatoIl: DateTime.parse(r['creato_il'] as String),
        ),
    ];
  }

  /// Ritira tutti i link d'invito ancora validi: chi non è ancora entrato
  /// avrà bisogno di uno nuovo. Per quando un link è finito nelle mani
  /// sbagliate (03, casi limite).
  Future<void> ritiraInviti(String viaggioId) => _alServer(
    () => _server
        .from('invito')
        .update({'eliminato_il': DateTime.now().toUtc().toIso8601String()})
        .eq('viaggio_id', viaggioId)
        .isFilter('eliminato_il', null),
  );

  // ─── Partecipanti: le scritture che richiedono la rete ──────────────────

  /// Esce dal viaggio (03, regola 7). Prima parte quello che è in coda, così
  /// i gesti fatti senza rete arrivano finché si è ancora dentro; poi il
  /// viaggio esce dalla copia. Quello che si è aggiunto resta agli altri.
  /// I documenti li toglie chi chiama: stanno in un'altra cartella.
  Future<void> esciDalViaggio(String viaggioId) async {
    await coda.svuota();
    await _sullaPartecipazione(
      () => _server.rpc<dynamic>(
        'esci_dal_viaggio',
        params: {'p_viaggio': viaggioId},
      ),
      messaggi: const {
        CodiciServer.primaPassaIlRuolo:
            'Prima di uscire rendi responsabile qualcun altro.',
        CodiciServer.nonTrovato: 'Non fai già più parte di questo viaggio.',
      },
    );
    await _togliDallaCopia(viaggioId);
  }

  /// Toglie qualcuno dal viaggio: solo chi ne è responsabile (03, regola 6).
  /// Il server ritira anche i link d'invito ancora validi.
  Future<void> togliPartecipante(String viaggioId, String utenteId) async {
    final righe = await _sullaPartecipazione(
      () => _server.rpc<Map<String, dynamic>>(
        'rimuovi_partecipante',
        params: {'p_viaggio': viaggioId, 'p_utente': utenteId},
      ),
    );
    await _nellaCopia(righe);
  }

  /// Passa il ruolo di responsabile del viaggio a un altro partecipante.
  Future<void> rendiResponsabile(String viaggioId, String utenteId) async {
    final righe = await _sullaPartecipazione(
      () => _server.rpc<Map<String, dynamic>>(
        'passa_il_ruolo',
        params: {'p_viaggio': viaggioId, 'p_a': utenteId},
      ),
    );
    await _nellaCopia(righe);
  }

  /// Una scrittura su chi partecipa. Se il server la rifiuta, qualcosa è
  /// cambiato nel frattempo — il ruolo è passato, la persona è già uscita —
  /// e la copia si riscarica, così la schermata mostra com'è adesso.
  Future<T> _sullaPartecipazione<T>(
    Future<T> Function() chiamata, {
    Map<String, String> messaggi = const {},
  }) async {
    try {
      return await _alServer(
        chiamata,
        messaggi: {
          CodiciServer.nonPermesso:
              'Solo chi è responsabile del viaggio può farlo. Ora vedi chi '
              'lo è.',
          CodiciServer.nonTrovato:
              'Questa persona non fa già più parte del viaggio.',
          ...messaggi,
        },
      );
    } on ErroreTrolley catch (e) {
      if (e.codice != null) await aggiornaCopia().catchError((_) {});
      rethrow;
    }
  }

  // ─── Tappe: le scritture che richiedono la rete ──────────────────────────

  /// Cambia una tappa: titolo, tipo, durata, ora, luogo, giorno. Con la
  /// versione che la persona ha visto: se qualcuno l'ha cambiata nel frattempo
  /// si mostrano le due versioni ([Conflitto], 02 §3). Prima parte quello che
  /// è in coda: una tappa aggiunta senza rete prende così la sua versione del
  /// server.
  Future<void> modificaTappa(Tappa tappa, Map<String, Object?> valori) async {
    await coda.svuota();
    final attuale = await (_db.select(
      _db.tappe,
    )..where((t) => t.id.equals(tappa.id))).getSingleOrNull();
    final vista = tappa.versione == 0 ? attuale ?? tappa : tappa;
    final riga = rigaDellaTappa(vista);
    await _conLaVersione(
      _tappaVersionata(tappa.id),
      riferimento: ritrattoTappa(riga),
      versione: vista.versione,
      mia: ritrattoTappa({...riga, ...valori}),
    );
  }

  /// Toglie una tappa: si marca, non si cancella (01-modello-dati.md).
  Future<void> togliTappa(Tappa tappa) => modificaTappa(tappa, {
    'eliminato_il': DateTime.now().toUtc().toIso8601String(),
  });

  /// Toglie più tappe del viaggio insieme: un giorno intero, tutto il
  /// viaggio (tela, 59 e 60). Si marcano, non si cancellano, in una scrittura
  /// sola. Senza versione: chi svuota ha deciso per tutte, anche per quelle
  /// che intanto qualcuno ha segnato o cambiato — e prima di farlo l'ha
  /// confermato vedendo quante sono. Prima parte la coda, così anche le tappe
  /// aggiunte senza rete sono sul server. Restituisce quante ne sono uscite.
  Future<int> togliTappe(String viaggioId, Iterable<String> ids) async {
    final elenco = ids.toSet().toList();
    if (elenco.isEmpty) return 0;
    await coda.svuota();
    final righe = await _alServer(
      () => _server
          .from('tappa')
          .update({'eliminato_il': DateTime.now().toUtc().toIso8601String()})
          .eq('viaggio_id', viaggioId)
          .inFilter('id', elenco)
          .select(),
    );
    await _db.transaction(() async {
      for (final r in righe) {
        await coda.nellaCopia(r);
      }
    });
    return righe.length;
  }

  /// Sposta una tappa in fondo a un altro giorno del viaggio.
  Future<void> spostaTappa(Tappa tappa, {required String giornoId}) =>
      modificaTappa(tappa, {'giorno_id': giornoId});

  /// Riordina le tappe di un giorno: [ids] nell'ordine voluto. Non porta la
  /// versione: due persone che riordinano la stessa giornata non sono un
  /// conflitto da mostrare, vince l'ultima.
  Future<void> ordinaTappe(String giornoId, List<String> ids) async {
    await coda.svuota();
    final righe = await _alServer(
      () => _server.rpc<List<dynamic>>(
        'ordina_tappe',
        params: {'p_giorno': giornoId, 'p_tappe': ids},
      ),
    );
    await _db.transaction(() async {
      for (final r in righe) {
        await coda.nellaCopia(r as Map<String, dynamic>);
      }
    });
  }

  // ─── Spese: le scritture che richiedono la rete ──────────────────────────

  /// Cambia una spesa: importo, valuta, descrizione, data, chi ha pagato e
  /// per chi (`quote`, come le scrive il server). Con la versione che la
  /// persona ha visto: sui soldi non si indovina, e se qualcuno l'ha cambiata
  /// nel frattempo si mostrano le due versioni (06, casi limite). Prima parte
  /// quello che è in coda, così la spesa ha la sua versione del server.
  Future<void> modificaSpesa(Spesa spesa, Map<String, Object?> valori) async {
    await coda.svuota();
    final attuale = await (_db.select(
      _db.spese,
    )..where((s) => s.id.equals(spesa.id))).getSingleOrNull();
    final vista = spesa.versione == 0 ? attuale ?? spesa : spesa;
    if (vista.versione == 0) {
      throw const ErroreTrolley(
        'Questa spesa non è ancora arrivata sul server: si potrà cambiare '
        'quando parte.',
      );
    }
    final quote = await (_db.select(
      _db.speseQuote,
    )..where((q) => q.spesaId.equals(spesa.id))).get();
    final riga = rigaDellaSpesa(vista, quote);
    await _conLaVersione(
      _spesaVersionata(spesa.id),
      riferimento: ritrattoSpesa(riga),
      versione: vista.versione,
      mia: ritrattoSpesa({...riga, ...valori}),
    );
  }

  /// Toglie una spesa: si marca, non si cancella (01-modello-dati.md).
  Future<void> togliSpesa(Spesa spesa) => modificaSpesa(spesa, {
    'eliminato_il': DateTime.now().toUtc().toIso8601String(),
  });

  /// Cambia la valuta in cui la persona vede le spese (06, regola 4). È del
  /// profilo, quindi vale su ogni telefono, e richiede la rete.
  Future<void> cambiaValuta(String codice) async {
    final io = _io;
    final profilo = await profiloLocale();
    if (io == null || profilo == null) return;
    // Il profilo intero si rilegge da mio_profilo: degli utenti si possono
    // leggere solo nome e versione (profilo_altrui_solo_nome.sql).
    await _alServer(
      () => _server
          .from('utente')
          .update({'valuta_predefinita': codice, 'versione': profilo.versione})
          .eq('id', io)
          .select('id'),
    );
    await scaricaProfilo();
  }

  // ─── Cose da portare: le scritture che richiedono la rete ─────────────────

  /// Aggiunge una voce a una delle due liste: la propria, o quella del
  /// viaggio, dove la può portare [portaChi]. Richiede la rete: senza, le
  /// liste si leggono e si spuntano e basta (05, regola 5). L'id nasce qui,
  /// così una risposta persa per strada non la aggiunge due volte.
  Future<VoceLista> aggiungiVoce({
    required String viaggioId,
    required String testo,
    int quantita = 1,
    TipoLista lista = TipoLista.personale,
    String? portaChi,
  }) async {
    final io = _io;
    final pulito = testoVoce(testo);
    if (io == null || pulito == null) {
      throw const ErroreTrolley('Scrivi che cosa portare.');
    }
    final id = const Uuid().v4();
    final righe = await _alServer(
      () => _server
          .from('voce_lista')
          .upsert(
            {
              'id': id,
              'viaggio_id': viaggioId,
              'testo': pulito,
              'quantita': quantitaValida(quantita),
              'tipo': lista.codice,
              'proprietario_id': io,
              'assegnato_a': lista == TipoLista.viaggio ? portaChi : null,
              'creato_da': io,
            },
            onConflict: 'id',
            ignoreDuplicates: true,
          )
          .select(),
      messaggi: const {
        '42501':
            'Il server non l\'ha accettata: forse non fai più parte di questo '
            'viaggio, o non ne fa più parte chi doveva portarla.',
      },
    );
    final riga =
        righe.firstOrNull ??
        (await _alServer(
          () => _server.from('voce_lista').select().eq('id', id),
        )).firstOrNull;
    if (riga == null) {
      throw const ErroreTrolley('La voce non è arrivata sul server. Riprova.');
    }
    await coda.nellaCopiaVoce(riga);
    return (await (_db.select(
      _db.vociLista,
    )..where((v) => v.id.equals(id))).getSingle());
  }

  /// Cambia una voce: il testo, quante, chi la porta. Con la versione che la
  /// persona ha visto: due testi non si fondono mai, e se qualcuno l'ha
  /// cambiata nel frattempo si mostrano le due versioni (02 §3). Prima parte
  /// quello che è in coda, così la voce ha la sua versione del server.
  Future<void> modificaVoce(VoceLista voce, Map<String, Object?> valori) async {
    await coda.svuota();
    final attuale = await (_db.select(
      _db.vociLista,
    )..where((v) => v.id.equals(voce.id))).getSingleOrNull();
    final vista = voce.versione == 0 ? attuale ?? voce : voce;
    final riga = rigaDellaVoce(vista);
    await _conLaVersione(
      _voceVersionata(voce.id),
      riferimento: ritrattoVoce(riga),
      versione: vista.versione,
      mia: ritrattoVoce({...riga, ...valori}),
    );
  }

  /// Toglie una voce: si marca, non si cancella (01-modello-dati.md).
  Future<void> togliVoce(VoceLista voce) => modificaVoce(voce, {
    'eliminato_il': DateTime.now().toUtc().toIso8601String(),
  });

  /// Sposta una voce nell'altra lista: da quella del viaggio alla propria, o
  /// il contrario (05, «Voce»). Sul server la voce si toglie da una lista e
  /// ne nasce una nuova nell'altra, insieme o niente (`sposta_voce`): chi
  /// aveva la vecchia la vede togliere. Si sposta com'è sul server: chi ha
  /// cambiato qualcosa nel foglio prima lo salva.
  ///
  /// Con la versione che la persona ha visto. Se intanto qualcuno l'ha
  /// cambiata — l'ha spuntata, l'ha riscritta — si guarda com'è adesso: se la
  /// si può ancora spostare si sposta quella, che non porta niente di scritto
  /// da chi sposta; se intanto l'ha presa un altro, resta dov'è.
  Future<VoceLista> spostaVoce(VoceLista voce) async {
    final io = _io;
    if (io == null) throw const ErroreTrolley('Serve l\'accesso.');
    await coda.svuota();
    final nuova = const Uuid().v4();
    final attuale = await (_db.select(
      _db.vociLista,
    )..where((v) => v.id.equals(voce.id))).getSingleOrNull();
    var versione = voce.versione == 0 ? attuale?.versione ?? 0 : voce.versione;
    final lista = TipoLista.values.byName(voce.tipo);
    Future<void> siPuoSpostare(
      String? assegnatoA, {
      bool intanto = false,
    }) async {
      final presenti = {
        for (final (p, _) in await osservaPartecipanti(voce.viaggioId).first)
          p.utenteId,
      };
      final porta = chiLaPorta(assegnatoA, presenti);
      if (siSposta(lista: lista, portaChi: porta, io: io)) return;
      final nome = (await osservaNomi(voce.viaggioId).first)[porta];
      throw ErroreTrolley(
        '${intanto ? 'Intanto l\'ha presa' : 'La porta'} '
        '${nome ?? 'qualcun altro'}: resta nella lista del viaggio.',
      );
    }

    await siPuoSpostare(attuale?.assegnatoA ?? voce.assegnatoA);
    for (var giro = 1; ; giro++) {
      try {
        final righe = await alServer(
          () => _server.rpc<Map<String, dynamic>>(
            'sposta_voce',
            params: {
              'p_voce': voce.id,
              'p_versione': versione,
              'p_nuova': nuova,
            },
          ),
          rete: rete,
        );
        await _db.transaction(() async {
          await coda.nellaCopiaVoce(righe['vecchia'] as Map<String, dynamic>);
          await coda.nellaCopiaVoce(righe['nuova'] as Map<String, dynamic>);
        });
        return (await (_db.select(
          _db.vociLista,
        )..where((v) => v.id.equals(nuova))).getSingle());
      } on ErroreTrolley catch (e) {
        if (e.codice == CodiciServer.nonTrovato) {
          await _nonCePiu(_voceVersionata(voce.id));
        }
        if (e.codice != CodiciServer.versioneSuperata || giro >= 3) rethrow;
        final adesso = await alServer(
          _rileggi('voce_lista', voce.id),
          rete: rete,
        );
        if (adesso == null || adesso['eliminato_il'] != null) {
          await _nonCePiu(_voceVersionata(voce.id));
        }
        await coda.nellaCopiaVoce(adesso);
        await siPuoSpostare(adesso['assegnato_a'] as String?, intanto: true);
        versione = adesso['versione']! as int;
      }
    }
  }

  // ─── Note: le scritture che richiedono la rete ───────────────────────────

  /// Salva una nota del viaggio. La risposta di un assistente si salva sempre,
  /// prima di provare a leggerla (04, regola 11). L'id nasce qui: una risposta
  /// persa per strada non la salva due volte.
  Future<Nota> salvaNota({
    required String viaggioId,
    required String testo,
    String origine = 'scritta',
  }) async {
    final io = _io;
    final pulito = testo.trim();
    if (io == null || pulito.isEmpty) {
      throw const ErroreTrolley('Non c\'è niente da salvare.');
    }
    if (pulito.length > lunghezzaMassimaNota) {
      throw const ErroreTrolley(
        'Questo testo è troppo lungo per una nota: incolla solo l\'itinerario.',
      );
    }
    final id = const Uuid().v4();
    final righe = await _alServer(
      () => _server
          .from('nota')
          .upsert(
            {
              'id': id,
              'viaggio_id': viaggioId,
              'testo': pulito,
              'origine': origine,
              'creato_da': io,
            },
            onConflict: 'id',
            ignoreDuplicates: true,
          )
          .select(),
    );
    final riga =
        righe.firstOrNull ??
        (await _alServer(() => _server.from('nota').select().eq('id', id)))
            .firstOrNull;
    if (riga == null) {
      throw const ErroreTrolley('La nota non è arrivata sul server. Riprova.');
    }
    await _nellaCopiaNota(riga);
    return (await (_db.select(
      _db.note,
    )..where((n) => n.id.equals(id))).getSingle());
  }

  /// Toglie una nota: si marca, non si cancella. Con la versione su cui la
  /// persona ha deciso.
  Future<void> togliNota(Nota nota) async {
    final righe = await _alServer(
      () => _server
          .from('nota')
          .update({
            'eliminato_il': DateTime.now().toUtc().toIso8601String(),
            'versione': nota.versione,
          })
          .eq('id', nota.id)
          .select(),
    );
    if (righe.isEmpty) {
      await aggiornaCopia(viaggioId: nota.viaggioId).catchError((_) {});
      return;
    }
    await _nellaCopiaNota(righe.single);
  }

  Future<void> _nellaCopiaNota(Map<String, dynamic> riga) async {
    if (riga['eliminato_il'] != null) {
      await (_db.delete(
        _db.note,
      )..where((n) => n.id.equals(riga['id'] as String))).go();
      return;
    }
    await _db
        .into(_db.note)
        .insertOnConflictUpdate(_nota(riga, DateTime.now().toUtc()));
  }

  // ─── Due versioni (02 §3) ───────────────────────────────────────────────

  /// «Tieni la tua»: la cosa diventa esattamente com'era la versione della
  /// persona, scritta sopra quella del server. Se nel frattempo è cambiata
  /// ancora, arriva un [Conflitto] nuovo.
  Future<void> tieniLaTua(Conflitto conflitto) => _conLaVersione(
    _versionata(conflitto.cosa, conflitto.id),
    riferimento: conflitto.loro,
    versione: conflitto.versioneLoro,
    mia: conflitto.mia,
  );

  /// «Tienile tutte e due»: quella del server resta com'è, e la propria
  /// diventa una voce nuova, nella stessa lista dell'altra. Solo dove due
  /// versioni possono convivere.
  Future<void> tieniTutteEDue(Conflitto conflitto) async {
    if (!conflitto.possonoConvivere) {
      throw const ErroreTrolley('Qui si sceglie una delle due versioni.');
    }
    final altra = await (_db.select(
      _db.vociLista,
    )..where((v) => v.id.equals(conflitto.id))).getSingleOrNull();
    final lista = altra == null
        ? TipoLista.personale
        : TipoLista.values.byName(altra.tipo);
    await aggiungiVoce(
      viaggioId: conflitto.viaggioId,
      testo: conflitto.mia['testo']! as String,
      quantita: conflitto.mia['quantita']! as int,
      lista: lista,
      portaChi: conflitto.mia['assegnato_a'] as String?,
    );
  }

  /// Scrive [mia] sopra la versione [versione], che allora era [riferimento].
  /// Se nel frattempo qualcuno l'ha cambiata il server rifiuta (TR409), e si
  /// guarda com'è adesso: se dice già quello che si voleva, è fatta; se l'altro
  /// non ha toccato niente di quello che si cambia qui (ha segnato la tappa,
  /// spuntato la voce, riordinato la giornata) si riscrive sulla versione
  /// nuova; altrimenti si lancia un [Conflitto] e sceglie la persona. In ogni
  /// caso la copia ha la versione del server.
  Future<void> _conLaVersione(
    _Versionata cosa, {
    required Map<String, Object?> riferimento,
    required int versione,
    required Map<String, Object?> mia,
  }) async {
    var rif = riferimento;
    var ver = versione;
    // Ogni giro riprova solo se qualcuno ha appena scritto: tre bastano, e
    // oltre è meglio chiedere che girare.
    for (var giro = 1; ; giro++) {
      final bool scritta;
      try {
        scritta = await alServer(() => cosa.scrivi(mia, rif, ver), rete: rete);
      } on ErroreTrolley catch (e) {
        if (e.codice == CodiciServer.nonTrovato) await _nonCePiu(cosa);
        if (e.codice != CodiciServer.versioneSuperata) rethrow;
        final adesso = await alServer(cosa.rileggi, rete: rete);
        if (adesso == null) await _nonCePiu(cosa);
        await cosa.nellaCopia(adesso);
        final loro = cosa.ritratto(adesso);
        switch (confronta(base: rif, mia: mia, loro: loro)) {
          case EsitoConfronto.uguali:
            return;
          case EsitoConfronto.nienteInComune when giro < 3:
            rif = loro;
            ver = adesso['versione']! as int;
            continue;
          case _:
            throw Conflitto(
              cosa: cosa.cosa,
              id: cosa.id,
              viaggioId: (adesso['viaggio_id'] ?? adesso['id'])! as String,
              mia: mia,
              loro: loro,
              versioneLoro: adesso['versione']! as int,
              autoreId: adesso['modificato_da'] as String?,
              salvataIl: DateTime.tryParse('${adesso['modificato_il']}'),
            );
        }
      }
      if (!scritta) await _nonCePiu(cosa);
      return;
    }
  }

  Future<Never> _nonCePiu(_Versionata cosa) async {
    // Anche se il viaggio è finito, e la copia non lo riscarica da sola.
    final viaggioId = await _viaggioDi(cosa.cosa, cosa.id);
    await aggiornaCopia(viaggioId: viaggioId).catchError((_) {});
    throw ErroreTrolley(cosa.nonCePiu);
  }

  /// Il viaggio di una cosa che sta nella copia.
  Future<String?> _viaggioDi(CosaInConflitto cosa, String id) async =>
      switch (cosa) {
        CosaInConflitto.viaggio => id,
        CosaInConflitto.tappa => (await (_db.select(
          _db.tappe,
        )..where((t) => t.id.equals(id))).getSingleOrNull())?.viaggioId,
        CosaInConflitto.spesa => (await (_db.select(
          _db.spese,
        )..where((t) => t.id.equals(id))).getSingleOrNull())?.viaggioId,
        CosaInConflitto.voce => (await (_db.select(
          _db.vociLista,
        )..where((t) => t.id.equals(id))).getSingleOrNull())?.viaggioId,
      };

  _Versionata _versionata(CosaInConflitto cosa, String id) => switch (cosa) {
    CosaInConflitto.viaggio => _viaggioVersionato(id),
    CosaInConflitto.tappa => _tappaVersionata(id),
    CosaInConflitto.spesa => _spesaVersionata(id),
    CosaInConflitto.voce => _voceVersionata(id),
  };

  /// La riga di una tabella del viaggio com'è adesso sul server, anche tolta.
  Future<Map<String, dynamic>?> Function() _rileggi(
    String tabella,
    String id,
  ) =>
      () async =>
          (await _server.from(tabella).select().eq('id', id)).firstOrNull;

  /// Aggiorna una riga di [tabella] con i campi in cui [mia] e il riferimento
  /// non coincidono, e la mette nella copia.
  Future<bool> _aggiornaRiga(
    String tabella,
    String id,
    Map<String, Object?> valori,
    int versione,
    Future<void> Function(Map<String, dynamic>) nellaCopia,
  ) async {
    final righe = await _server
        .from(tabella)
        .update({...valori, 'versione': versione})
        .eq('id', id)
        .select();
    if (righe.isEmpty) return false;
    await nellaCopia(righe.single);
    return true;
  }

  _Versionata _tappaVersionata(String id) => _Versionata(
    cosa: CosaInConflitto.tappa,
    id: id,
    ritratto: ritrattoTappa,
    rileggi: _rileggi('tappa', id),
    nellaCopia: coda.nellaCopia,
    scrivi: (mia, rif, versione) async {
      final campi = campiDiversi(mia, rif);
      final giorno = mia['giorno_id']! as String;
      // In un altro giorno va in fondo: l'ordine non è una scelta da
      // confrontare, segue il giorno.
      final ordine = campi.contains('giorno_id')
          ? ordineInFondo(
              (await (_db.select(_db.tappe)..where(
                        (t) =>
                            t.giornoId.equals(giorno) &
                            t.id.equals(id).not() &
                            t.eliminatoIl.isNull(),
                      ))
                      .get())
                  .map((t) => t.ordine),
            )
          : null;
      return _aggiornaRiga(
        'tappa',
        id,
        {...perIlServer(mia, campi), 'ordine': ?ordine},
        versione,
        coda.nellaCopia,
      );
    },
    nonCePiu:
        'Questa tappa non è ancora arrivata sul server, o non c\'è più. Ora '
        'vedi la giornata com\'è adesso.',
  );

  /// Una spesa con le sue quote: si scrivono insieme, o niente
  /// (`cambia_spesa`), e si rileggono insieme.
  _Versionata _spesaVersionata(String id) => _Versionata(
    cosa: CosaInConflitto.spesa,
    id: id,
    ritratto: ritrattoSpesa,
    rileggi: () async {
      final [spese, quote] = await Future.wait([
        _server.from('spesa').select().eq('id', id),
        _server
            .from('spesa_quota')
            .select()
            .eq('spesa_id', id)
            .isFilter('eliminato_il', null),
      ]);
      final spesa = spese.firstOrNull;
      return spesa == null ? null : {...spesa, 'quote': quote};
    },
    nellaCopia: (riga) => coda.nellaCopiaRigheSpesa({
      'spesa': {...riga}..remove('quote'),
      'quote': riga['quote'],
    }),
    scrivi: (mia, rif, versione) async {
      final campi = campiDiversi(mia, rif);
      final righe = await _server.rpc<Map<String, dynamic>?>(
        'cambia_spesa',
        params: {
          'p_spesa': id,
          'p_versione': versione,
          'p_valori': perIlServer(mia, campi),
          'p_quote': campi.contains('quote')
              ? righeQuote(leggiQuote(mia['quote']))
              : null,
        },
      );
      if (righe == null || righe['spesa'] == null) return false;
      await coda.nellaCopiaRigheSpesa(righe);
      return true;
    },
    nonCePiu:
        'Questa spesa non c\'è più sul server. Ora vedi le spese come sono '
        'adesso.',
  );

  _Versionata _voceVersionata(String id) => _Versionata(
    cosa: CosaInConflitto.voce,
    id: id,
    ritratto: ritrattoVoce,
    rileggi: _rileggi('voce_lista', id),
    nellaCopia: coda.nellaCopiaVoce,
    scrivi: (mia, rif, versione) => _aggiornaRiga(
      'voce_lista',
      id,
      perIlServer(mia, campiDiversi(mia, rif)),
      versione,
      coda.nellaCopiaVoce,
    ),
    nonCePiu:
        'Questa voce non c\'è più sul server. Ora vedi la lista com\'è adesso.',
  );

  /// Quando si parte. Si scrive con la funzione che porta il viaggio dove lo
  /// vuole la persona: con le date `programma_viaggio`, che sistema anche i
  /// giorni; da definito a idea `torna_idea`; fra idee, periodo e stato.
  _Versionata _viaggioVersionato(String id) => _Versionata(
    cosa: CosaInConflitto.viaggio,
    id: id,
    ritratto: ritrattoViaggio,
    rileggi: _rileggi('viaggio', id),
    // Le date cambiate si portano dietro i giorni: si riscarica il viaggio.
    nellaCopia: (_) => aggiornaCopia(viaggioId: id).catchError((_) {}),
    scrivi: (mia, rif, versione) async {
      final inizio = leggiData(mia['data_inizio'] as String?);
      final fine = leggiData(mia['data_fine'] as String?);
      final arrivo = leggiOra(mia['ora_arrivo'] as String?);
      final partenza = leggiOra(mia['ora_partenza'] as String?);
      if (inizio != null &&
          fine != null &&
          arrivo != null &&
          partenza != null) {
        final programma = Programma(
          inizio: inizio,
          fine: fine,
          arrivo: arrivo,
          partenza: partenza,
        );
        await _nellaCopia(
          await _server.rpc<Map<String, dynamic>>(
            'programma_viaggio',
            params: {
              'p_viaggio': id,
              'p_versione': versione,
              ..._dateDelProgramma(programma),
              'p_giorni': _giorniPerIlServer(programma),
            },
          ),
        );
        return true;
      }
      if (rif['stato'] == 'definito') {
        await _nellaCopia(
          await _server.rpc<Map<String, dynamic>>(
            'torna_idea',
            params: {
              'p_viaggio': id,
              'p_versione': versione,
              'p_periodo': mia['periodo_approssimativo'],
            },
          ),
        );
        return true;
      }
      final righe = await _server
          .from('viaggio')
          .update({
            'stato': mia['stato'],
            'periodo_approssimativo': mia['periodo_approssimativo'],
            'versione': versione,
          })
          .eq('id', id)
          .select();
      if (righe.isEmpty) return false;
      await _db
          .into(_db.viaggi)
          .insertOnConflictUpdate(
            _viaggio(righe.single, DateTime.now().toUtc()),
          );
      return true;
    },
    nonCePiu:
        'Questo viaggio non c\'è più. Ora vedi i tuoi viaggi come sono adesso.',
  );

  // ─── Adesso ─────────────────────────────────────────────────────────────

  static const _sceltoOggi = 'adesso_scelto';

  /// Il viaggio scelto oggi fra due in corso, su questo telefono: la scelta
  /// vale fino a sera (09, casi limite). `null` se oggi non si è scelto.
  Future<String?> viaggioSceltoOggi(DateTime oggi) async {
    final riga = await (_db.select(
      _db.impostazioni,
    )..where((i) => i.chiave.equals(_sceltoOggi))).getSingleOrNull();
    final parti = (riga?.valore ?? '').split('|');
    if (parti.length != 2 || parti.first != scriviData(oggi)) return null;
    return parti.last;
  }

  Future<void> scegliViaggioDiOggi(String viaggioId, DateTime oggi) => _db
      .into(_db.impostazioni)
      .insertOnConflictUpdate(
        ImpostazioniCompanion.insert(
          chiave: _sceltoOggi,
          valore: '${scriviData(oggi)}|$viaggioId',
        ),
      );

  // ─── Idee e archivio ────────────────────────────────────────────────────

  /// Il giorno in cui questo telefono ha mostrato il sollecito "è ancora
  /// un'idea?" per la scadenza attuale dell'idea, se l'ha mostrato. Una scadenza
  /// nuova (un periodo cambiato) vuole un sollecito nuovo.
  Future<DateTime?> sollecitataIl(Viaggio idea) async {
    final riga =
        await (_db.select(_db.impostazioni)
              ..where((i) => i.chiave.equals(_chiaveSollecito(idea.id))))
            .getSingleOrNull();
    final parti = (riga?.valore ?? '').split('|');
    if (parti.length != 2 || parti.first != scriviData(idea.scadenza)) {
      return null;
    }
    return leggiData(parti.last);
  }

  /// Segna che il sollecito è stato mostrato [il], se non lo era già.
  Future<void> segnaSollecitata(Viaggio idea, DateTime il) async {
    if (await sollecitataIl(idea) != null) return;
    await _db
        .into(_db.impostazioni)
        .insertOnConflictUpdate(
          ImpostazioniCompanion.insert(
            chiave: _chiaveSollecito(idea.id),
            valore: '${scriviData(idea.scadenza)}|${scriviData(il)}',
          ),
        );
  }

  /// Manda in archivio le idee il cui periodo è passato, se il sollecito c'è
  /// stato (02, regole 5 e 6). Restituisce quelle archiviate, per dirlo.
  /// Senza rete non fa niente: riproverà.
  Future<List<Viaggio>> archiviaIdeeScadute(DateTime oggi) async {
    final idee = await (_db.select(
      _db.viaggi,
    )..where((v) => v.stato.equals('idea') & v.eliminatoIl.isNull())).get();
    final archiviate = <Viaggio>[];
    for (final idea in idee) {
      if (!daArchiviare(
        scadenza: idea.scadenza,
        sollecitataIl: await sollecitataIl(idea),
        oggi: oggi,
      )) {
        continue;
      }
      try {
        await _aggiornaViaggio(idea, statoAtteso: 'idea', {
          'stato': 'archiviato',
        });
        archiviate.add(idea);
      } on ErroreTrolley catch (e) {
        if (e.serveLaRete) break;
        // Cambiata nel frattempo: il suo destino si rivaluta con i dati nuovi.
      }
    }
    return archiviate;
  }

  static String _chiaveSollecito(String viaggioId) => 'sollecito:$viaggioId';

  // ─── Traduzione delle righe ─────────────────────────────────────────────

  static Map<String, String?> _dateDelProgramma(Programma? p) => {
    'p_data_inizio': p == null ? null : scriviData(p.inizio),
    'p_data_fine': p == null ? null : scriviData(p.fine),
    'p_ora_arrivo': p == null ? null : scriviOra(p.arrivo),
    'p_ora_partenza': p == null ? null : scriviOra(p.partenza),
  };

  /// I giorni come li applica il server. L'id conta solo per le date nuove: una
  /// data che il viaggio ha già avuto riprende la sua riga.
  static List<Map<String, String>> _giorniPerIlServer(Programma p) => [
    for (final g in p.giorni)
      {
        'id': const Uuid().v4(),
        'data': scriviData(g.data),
        'inizio': scriviOra(g.inizio),
        'fine': scriviOra(g.fine),
      },
  ];

  UtentiCompanion _utente(Map<String, dynamic> r, [DateTime? adesso]) =>
      UtentiCompanion.insert(
        id: r['id'] as String,
        // Di chi ha chiuso l'account il server non ha più il nome.
        nome: r['nome'] as String? ?? nomeAccountChiuso,
        versione: r['versione'] as int,
        eliminatoIl: Value(r['eliminato_il'] as String?),
        scaricatoIl: adesso ?? DateTime.now().toUtc(),
        dataNascita: Value(r['data_nascita'] as String?),
        valutaPredefinita: Value(r['valuta_predefinita'] as String?),
      );

  ViaggiCompanion _viaggio(Map<String, dynamic> r, DateTime adesso) =>
      ViaggiCompanion.insert(
        id: r['id'] as String,
        versione: r['versione'] as int,
        eliminatoIl: Value(r['eliminato_il'] as String?),
        scaricatoIl: adesso,
        stato: r['stato'] as String,
        destinazioneCitta: Value(r['destinazione_citta'] as String?),
        destinazionePaese: Value(r['destinazione_paese'] as String?),
        periodoApprossimativo: Value(r['periodo_approssimativo'] as String?),
        dataInizio: Value(r['data_inizio'] as String?),
        dataFine: Value(r['data_fine'] as String?),
        oraArrivo: Value(r['ora_arrivo'] as String?),
        oraPartenza: Value(r['ora_partenza'] as String?),
        creatoreId: r['creatore_id'] as String,
        importato: r['importato'] as bool,
        verificato: r['verificato'] as bool,
        giorniRicordati: Value(r['giorni_ricordati'] as int?),
        verificaPerDeroga: Value((r['verifica_per_deroga'] as bool?) ?? false),
        creatoIl: r['creato_il'] as String,
      );

  PartecipazioniCompanion _partecipazione(
    Map<String, dynamic> r,
    DateTime adesso,
  ) => PartecipazioniCompanion.insert(
    id: r['id'] as String,
    versione: r['versione'] as int,
    eliminatoIl: Value(r['eliminato_il'] as String?),
    scaricatoIl: adesso,
    viaggioId: r['viaggio_id'] as String,
    utenteId: r['utente_id'] as String,
    ruolo: r['ruolo'] as String,
    stato: r['stato'] as String,
    creatoIl: Value(r['creato_il'] as String?),
    modificatoIl: Value(r['modificato_il'] as String?),
    sulPostoIl: Value(r['sul_posto_il'] as String?),
    verificato: Value(r['verificato'] as bool?),
  );

  NoteCompanion _nota(Map<String, dynamic> r, DateTime adesso) =>
      NoteCompanion.insert(
        id: r['id'] as String,
        versione: r['versione'] as int,
        eliminatoIl: Value(r['eliminato_il'] as String?),
        scaricatoIl: adesso,
        viaggioId: r['viaggio_id'] as String,
        testo: r['testo'] as String,
        origine: r['origine'] as String,
        creatoDa: r['creato_da'] as String,
        creatoIl: r['creato_il'] as String,
      );

  GiorniCompanion _giorno(Map<String, dynamic> r, DateTime adesso) =>
      GiorniCompanion.insert(
        id: r['id'] as String,
        versione: r['versione'] as int,
        eliminatoIl: Value(r['eliminato_il'] as String?),
        scaricatoIl: adesso,
        viaggioId: r['viaggio_id'] as String,
        data: r['data'] as String,
        finestraInizio: r['finestra_inizio'] as String,
        finestraFine: r['finestra_fine'] as String,
      );
}

/// Una cosa che si scrive con la versione: come scriverla, come rileggerla,
/// come farne un ritratto per il confronto.
class _Versionata {
  const _Versionata({
    required this.cosa,
    required this.id,
    required this.ritratto,
    required this.rileggi,
    required this.nellaCopia,
    required this.scrivi,
    required this.nonCePiu,
  });

  final CosaInConflitto cosa;
  final String id;
  final Map<String, Object?> Function(Map<String, Object?> riga) ritratto;

  /// La riga com'è adesso sul server; `null` se non la si legge più.
  final Future<Map<String, dynamic>?> Function() rileggi;

  /// Mette nella copia una riga riletta dopo un rifiuto.
  final Future<void> Function(Map<String, dynamic> riga) nellaCopia;

  /// Scrive [mia] sopra la versione [versione], che era [riferimento], e
  /// mette nella copia quello che il server ha scritto. `false` se la cosa
  /// sul server non c'è.
  final Future<bool> Function(
    Map<String, Object?> mia,
    Map<String, Object?> riferimento,
    int versione,
  )
  scrivi;

  /// Cosa dire se la cosa sul server non c'è più.
  final String nonCePiu;
}
