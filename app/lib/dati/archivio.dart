/// Parla con il server e tiene aggiornata la copia locale.
///
/// Le schermate leggono **sempre** dalla copia (così leggere non richiede mai la
/// rete) e scrivono attraverso questo archivio. Le scritture che non sono uno dei
/// quattro gesti richiedono la rete e lo dicono con un [ErroreTrolley].
library;

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';
import 'errori.dart';

/// Un viaggio come compare nell'elenco: con i nomi di chi c'è.
class ViaggioInElenco {
  const ViaggioInElenco(this.viaggio, this.persone);

  final Viaggio viaggio;
  final List<String> persone;
}

class Archivio {
  Archivio(this._db, this._supabase);

  final DatabaseLocale _db;
  final SupabaseClient _supabase;

  String? get _io => _supabase.auth.currentUser?.id;

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
    final righe = await alServer(
      () => _supabase.rpc<List<dynamic>>('mio_profilo'),
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
    await alServer(
      () => _supabase.from('utente').insert({
        'id': _io,
        'nome': nome.trim(),
        'data_nascita': _data(dataNascita),
      }),
      messaggi: {
        CodiciServer.nonPermesso: 'Per usare Trolley servono 16 anni.',
      },
    );
    return (await scaricaProfilo())!;
  }

  // ─── Copia di lettura ───────────────────────────────────────────────────

  /// Riscarica la copia dei viaggi attivi. Se qualcosa va storto la copia resta
  /// quella di prima: meglio vecchia e dichiarata tale che vuota.
  Future<void> aggiornaCopia() async {
    final (viaggi, partecipazioni, utenti) = await alServer(() async {
      final viaggi = await _supabase
          .from('viaggio')
          .select()
          .isFilter('eliminato_il', null)
          .neq('stato', 'archiviato');
      final ids = [for (final v in viaggi) v['id'] as String];
      final partecipazioni = ids.isEmpty
          ? <Map<String, dynamic>>[]
          : await _supabase
                .from('partecipazione')
                .select()
                .inFilter('viaggio_id', ids);
      final utenti = partecipazioni.isEmpty
          ? <Map<String, dynamic>>[]
          : await _supabase
                .from('utente')
                .select('id, nome, versione, eliminato_il')
                .inFilter(
                  'id',
                  {for (final p in partecipazioni) p['utente_id'] as String}
                      .toList(),
                );
      return (viaggi, partecipazioni, utenti);
    });

    final adesso = DateTime.now().toUtc();
    final io = _io;
    await _db.transaction(() async {
      await _db.delete(_db.viaggi).go();
      await _db.delete(_db.partecipazioni).go();
      // Il proprio profilo completo non si butta: dagli altri arriva solo il nome.
      await (_db.delete(
        _db.utenti,
      )..where((u) => u.id.equals(io ?? '').not())).go();

      await _db.batch((b) {
        b.insertAll(_db.viaggi, [for (final r in viaggi) _viaggio(r, adesso)]);
        b.insertAll(_db.partecipazioni, [
          for (final r in partecipazioni) _partecipazione(r, adesso),
        ]);
        b.insertAllOnConflictUpdate(_db.utenti, [
          for (final r in utenti)
            if (r['id'] != io) _utente(r, adesso),
        ]);
      });
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
  /// creatore per primo.
  Stream<List<ViaggioInElenco>> osservaViaggiInElenco() {
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
          ..where(_db.viaggi.eliminatoIl.isNull())
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

  /// Chi partecipa, con il nome. Chi è uscito o è stato rimosso non compare qui,
  /// ma i suoi contributi restano nel viaggio.
  Stream<List<(Partecipazione, Utente?)>> osservaPartecipanti(
    String viaggioId,
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
                _db.partecipazioni.stato.equals('attivo'),
          )
          ..orderBy([OrderingTerm.asc(_db.partecipazioni.ruolo)]);
    return query.watch().map(
      (righe) => [
        for (final r in righe)
          (r.readTable(_db.partecipazioni), r.readTableOrNull(_db.utenti)),
      ],
    );
  }

  // ─── Scritture che richiedono la rete ───────────────────────────────────

  /// Un viaggio allo stato idea: basta una destinazione, anche vaga.
  Future<String> creaIdea({String? citta}) async {
    final id = const Uuid().v4();
    await alServer(
      () => _supabase.from('viaggio').insert({
        'id': id,
        'stato': 'idea',
        'destinazione_citta': (citta?.trim().isEmpty ?? true)
            ? null
            : citta!.trim(),
        'creatore_id': _io,
      }),
    );
    await aggiornaCopia();
    return id;
  }

  /// Un nuovo codice d'invito per il viaggio.
  Future<String> creaInvito(String viaggioId) async {
    final riga = await alServer(
      () => _supabase
          .from('invito')
          .insert({'id': const Uuid().v4(), 'viaggio_id': viaggioId})
          .select('token')
          .single(),
    );
    return riga['token'] as String;
  }

  /// Entra nel viaggio del codice e restituisce il suo id.
  Future<String> accettaInvito(String codice) async {
    final viaggioId = await alServer(
      () =>
          _supabase.rpc<String>('accetta_invito', params: {'p_token': codice}),
      messaggi: {
        CodiciServer.nonTrovato:
            'Questo codice non corrisponde a nessun viaggio. Controlla di averlo '
            'scritto bene, o chiedi un nuovo invito.',
        CodiciServer.nonPermesso:
            'Non puoi rientrare in questo viaggio con questo invito. '
            'Chiedi a chi l\'ha creato.',
      },
    );
    await aggiornaCopia();
    return viaggioId;
  }

  // ─── Traduzione delle righe ─────────────────────────────────────────────

  UtentiCompanion _utente(Map<String, dynamic> r, [DateTime? adesso]) =>
      UtentiCompanion.insert(
        id: r['id'] as String,
        nome: r['nome'] as String,
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
  );

  static String _data(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
