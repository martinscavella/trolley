/// Parla con il server e tiene aggiornata la copia locale.
///
/// Le schermate leggono **sempre** dalla copia (così leggere non richiede mai la
/// rete) e scrivono attraverso questo archivio. Le scritture che non sono uno dei
/// quattro gesti richiedono la rete e lo dicono con un [ErroreTrolley]. Quelle
/// riuscite ricevono dal server le righe che hanno scritto e le mettono nella
/// copia così come sono: la copia non resta indietro nemmeno se la rete cade un
/// istante dopo.
library;

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../dominio/calendario.dart';
import '../dominio/giornate.dart';
import '../dominio/periodo.dart';
import '../dominio/stato_viaggio.dart';
import '../dominio/tappe.dart';
import 'coda.dart';
import 'database.dart';
import 'destinazioni.dart';
import 'errori.dart';
import 'lettura.dart';
import 'rete.dart';

/// Un viaggio come compare nell'elenco: con i nomi di chi c'è.
class ViaggioInElenco {
  const ViaggioInElenco(this.viaggio, this.persone);

  final Viaggio viaggio;
  final List<String> persone;
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

  // ─── Copia di lettura ───────────────────────────────────────────────────

  /// Riscarica la copia dei viaggi, con i loro giorni, le tappe e chi
  /// partecipa. Prima manda quello che è in coda, così la copia lo comprende;
  /// quello che non è partito ci si rimette sopra. Le idee archiviate ci sono
  /// anche loro: pesano pochi byte, e così l'archivio si legge anche senza
  /// rete. Se qualcosa va storto la copia resta quella di prima: meglio vecchia
  /// e dichiarata tale che vuota.
  Future<void> aggiornaCopia() async {
    await coda.svuota();
    final (viaggi, partecipazioni, utenti, giorni, tappe) = await _alServer(
      () async {
        final viaggi = await _server
            .from('viaggio')
            .select()
            .isFilter('eliminato_il', null);
        final ids = [for (final v in viaggi) v['id'] as String];
        if (ids.isEmpty) {
          return (
            viaggi,
            <Map<String, dynamic>>[],
            <Map<String, dynamic>>[],
            <Map<String, dynamic>>[],
            <Map<String, dynamic>>[],
          );
        }
        // Anche le tappe dei giorni usciti dalle date: sono da ricollocare.
        final (partecipazioni, giorni, tappe) = await (
          _server.from('partecipazione').select().inFilter('viaggio_id', ids),
          _server
              .from('giorno')
              .select()
              .inFilter('viaggio_id', ids)
              .isFilter('eliminato_il', null),
          _server
              .from('tappa')
              .select()
              .inFilter('viaggio_id', ids)
              .isFilter('eliminato_il', null),
        ).wait;
        final utenti = await _server
            .from('utente')
            .select('id, nome, versione, eliminato_il')
            .inFilter(
              'id',
              {for (final p in partecipazioni) p['utente_id'] as String}
                  .toList(),
            );
        return (viaggi, partecipazioni, utenti, giorni, tappe);
      },
    );

    final adesso = DateTime.now().toUtc();
    final io = _io;
    await _db.transaction(() async {
      await _db.delete(_db.viaggi).go();
      await _db.delete(_db.partecipazioni).go();
      await _db.delete(_db.giorni).go();
      await _db.delete(_db.tappe).go();
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
        b.insertAllOnConflictUpdate(_db.utenti, [
          for (final r in utenti)
            if (r['id'] != io) _utente(r, adesso),
        ]);
      });
      await coda.riapplica();
    });
  }

  /// Mette nella copia le righe di un viaggio restituite dal server dopo una
  /// scrittura: il viaggio, i suoi giorni attivi, chi partecipa.
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
          ..where(
            _db.viaggi.eliminatoIl.isNull() &
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

  /// Fissa o sposta le date. Un'idea diventa definita; i giorni che escono si
  /// marcano e tornano se le date tornano a comprenderli.
  Future<void> programma(Viaggio viaggio, Programma programma) async {
    final righe = await _alServer(
      () => _server.rpc<Map<String, dynamic>>(
        'programma_viaggio',
        params: {
          'p_viaggio': viaggio.id,
          'p_versione': viaggio.versione,
          ..._dateDelProgramma(programma),
          'p_giorni': _giorniPerIlServer(programma),
        },
      ),
    );
    await _nellaCopia(righe);
  }

  /// Da definito a idea: le date spariscono, quello che vi era agganciato resta
  /// e torna se si rifissano le stesse date (02, casi limite).
  Future<void> tornaIdea(Viaggio viaggio, {Periodo? periodo}) async {
    final righe = await _alServer(
      () => _server.rpc<Map<String, dynamic>>(
        'torna_idea',
        params: {
          'p_viaggio': viaggio.id,
          'p_versione': viaggio.versione,
          'p_periodo': periodo?.testo,
        },
      ),
    );
    await _nellaCopia(righe);
  }

  /// Cambia il periodo di un'idea.
  Future<void> cambiaPeriodo(Viaggio viaggio, Periodo? periodo) =>
      _aggiornaViaggio(viaggio, statoAtteso: 'idea', {
        'periodo_approssimativo': periodo?.testo,
      });

  /// Riprende un'idea dall'archivio, con un periodo nuovo: quello vecchio è
  /// passato (02, casi limite).
  Future<void> riprendi(Viaggio viaggio, Periodo? periodo) => _aggiornaViaggio(
    viaggio,
    statoAtteso: 'archiviato',
    {'stato': 'idea', 'periodo_approssimativo': periodo?.testo},
  );

  /// Aggiorna il viaggio solo se è ancora nello stato in cui la persona l'ha
  /// visto, con la versione su cui ha deciso.
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
      await aggiornaCopia().catchError((_) {});
      throw const ErroreTrolley(
        'Questo viaggio è cambiato nel frattempo. Ora vedi com\'è adesso.',
      );
    }
    await _db
        .into(_db.viaggi)
        .insertOnConflictUpdate(_viaggio(righe.single, DateTime.now().toUtc()));
  }

  /// Un nuovo codice d'invito per il viaggio.
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

  /// Entra nel viaggio del codice e restituisce il suo id.
  Future<String> accettaInvito(String codice) async {
    final viaggioId = await _alServer(
      () => _server.rpc<String>('accetta_invito', params: {'p_token': codice}),
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

  // ─── Tappe: le scritture che richiedono la rete ──────────────────────────

  /// Cambia una tappa: titolo, tipo, durata, ora, luogo, giorno. Con la
  /// versione su cui la persona ha deciso: se qualcuno l'ha cambiata nel
  /// frattempo si rifiuta, e la copia si riscarica (02 §3). Prima parte quello
  /// che è in coda, così la tappa ha la sua versione del server.
  Future<void> modificaTappa(Tappa tappa, Map<String, Object?> valori) async {
    await coda.svuota();
    final attuale =
        await (_db.select(
          _db.tappe,
        )..where((t) => t.id.equals(tappa.id))).getSingleOrNull() ??
        tappa;
    final righe = await _alServer(
      () => _server
          .from('tappa')
          .update({...valori, 'versione': attuale.versione})
          .eq('id', tappa.id)
          .select(),
    );
    if (righe.isEmpty) {
      await aggiornaCopia().catchError((_) {});
      throw const ErroreTrolley(
        'Questa tappa non è ancora arrivata sul server, o non c\'è più. Ora '
        'vedi la giornata com\'è adesso.',
      );
    }
    await coda.nellaCopia(righe.single);
  }

  /// Toglie una tappa: si marca, non si cancella (01-modello-dati.md).
  Future<void> togliTappa(Tappa tappa) => modificaTappa(tappa, {
    'eliminato_il': DateTime.now().toUtc().toIso8601String(),
  });

  /// Sposta una tappa in fondo a un altro giorno del viaggio.
  Future<void> spostaTappa(Tappa tappa, {required String giornoId}) async {
    final ordini =
        await (_db.select(_db.tappe)..where(
              (t) => t.giornoId.equals(giornoId) & t.eliminatoIl.isNull(),
            ))
            .get();
    await modificaTappa(tappa, {
      'giorno_id': giornoId,
      'ordine': ordineInFondo(ordini.map((t) => t.ordine)),
    });
  }

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
