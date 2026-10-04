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
import '../dominio/giornate.dart';
import '../dominio/liste.dart';
import '../dominio/periodo.dart';
import '../dominio/stato_viaggio.dart';
import '../dominio/tappe.dart';
import 'coda.dart';
import 'database.dart';
import 'destinazioni.dart';
import 'errori.dart';
import 'lettura.dart';
import 'rete.dart';

/// Quanto può essere lunga una nota: come sul server. Una risposta lunga di
/// un assistente ci sta comoda.
const lunghezzaMassimaNota = 20000;

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

  // ─── Copia di lettura ───────────────────────────────────────────────────

  /// Riscarica la copia dei viaggi, con i loro giorni, le tappe, le spese, le
  /// cose da portare, le note e chi partecipa. Prima manda quello che è in coda, così la copia lo comprende;
  /// quello che non è partito ci si rimette sopra. Le idee archiviate ci sono
  /// anche loro: pesano pochi byte, e così l'archivio si legge anche senza
  /// rete. Se qualcosa va storto la copia resta quella di prima: meglio vecchia
  /// e dichiarata tale che vuota.
  Future<void> aggiornaCopia() async {
    await coda.svuota();
    final io = _io;
    final (
      viaggi,
      lasciati,
      partecipazioni,
      utenti,
      giorni,
      tappe,
      spese,
      voci,
      note,
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
      if (ids.isEmpty) {
        return (
          viaggi,
          lasciati,
          <Map<String, dynamic>>[],
          <Map<String, dynamic>>[],
          <Map<String, dynamic>>[],
          <Map<String, dynamic>>[],
          <Map<String, dynamic>>[],
          <Map<String, dynamic>>[],
          <Map<String, dynamic>>[],
        );
      }
      // Anche le tappe dei giorni usciti dalle date: sono da ricollocare.
      // Delle liste arrivano quelle del viaggio e le proprie personali: le
      // personali degli altri il server non le manda (05, regola 3).
      final (partecipazioni, giorni, tappe, spese, voci, note) = await (
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
        _server
            .from('spesa')
            .select()
            .inFilter('viaggio_id', ids)
            .isFilter('eliminato_il', null),
        _server
            .from('voce_lista')
            .select()
            .inFilter('viaggio_id', ids)
            .isFilter('eliminato_il', null),
        _server
            .from('nota')
            .select()
            .inFilter('viaggio_id', ids)
            .isFilter('eliminato_il', null),
      ).wait;
      final utenti = await _server
          .from('utente')
          .select('id, nome, versione, eliminato_il')
          .inFilter(
            'id',
            {for (final p in partecipazioni) p['utente_id'] as String}.toList(),
          );
      return (
        viaggi,
        lasciati,
        partecipazioni,
        utenti,
        giorni,
        tappe,
        spese,
        voci,
        note,
      );
    });

    final adesso = DateTime.now().toUtc();
    await _db.transaction(() async {
      await _segnaLasciati(
        visibili: {for (final v in viaggi) v['id'] as String},
        lasciati: {
          for (final p in lasciati)
            p['viaggio_id'] as String: p['stato'] as String,
        },
      );
      await _db.delete(_db.viaggi).go();
      await _db.delete(_db.partecipazioni).go();
      await _db.delete(_db.giorni).go();
      await _db.delete(_db.tappe).go();
      await _db.delete(_db.spese).go();
      await _db.delete(_db.vociLista).go();
      await _db.delete(_db.note).go();
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
        b.insertAll(_db.vociLista, [for (final r in voci) rigaVoce(r, adesso)]);
        b.insertAll(_db.note, [for (final r in note) _nota(r, adesso)]);
        b.insertAllOnConflictUpdate(_db.utenti, [
          for (final r in utenti)
            if (r['id'] != io) _utente(r, adesso),
        ]);
      });
      await coda.riapplica();
    });
    await aggiornaTassi().catchError((_) {});
    await aggiornaConfigurazione().catchError((_) {});
  }

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
  /// [durataTassi]. Senza rete restano gli ultimi: si usano dicendo di quando
  /// sono (06, regola 6).
  Future<void> aggiornaTassi({DateTime? adesso}) async {
    final ora = (adesso ?? DateTime.now()).toUtc();
    final ultimo = await (_db.selectOnly(
      _db.tassiCambio,
    )..addColumns([_db.tassiCambio.scaricatoIl.max()])).getSingle();
    final il = ultimo.read(_db.tassiCambio.scaricatoIl.max());
    if (il != null && ora.difference(il.toUtc()) < durataTassi) return;
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

  /// Le spese del viaggio, nell'ordine in cui sono state registrate.
  Stream<List<Spesa>> osservaSpese(String viaggioId) =>
      (_db.select(_db.spese)
            ..where(
              (s) => s.viaggioId.equals(viaggioId) & s.eliminatoIl.isNull(),
            )
            ..orderBy([(s) => OrderingTerm.asc(s.creatoIl)]))
          .watch();

  /// Le proprie cose da portare per il viaggio: la lista personale, che vede
  /// solo chi la scrive (05, regole 1 e 3). Nell'ordine in cui sono nate;
  /// quale prima e quale dopo lo decide il dominio (dominio/liste.dart).
  Stream<List<VoceLista>> osservaVoci(String viaggioId) {
    final io = _io;
    if (io == null) return Stream.value(const []);
    return (_db.select(_db.vociLista)
          ..where(
            (v) =>
                v.viaggioId.equals(viaggioId) &
                v.tipo.equals(TipoLista.personale.codice) &
                v.proprietarioId.equals(io) &
                v.eliminatoIl.isNull(),
          )
          ..orderBy([(v) => OrderingTerm.asc(v.creatoIl)]))
        .watch();
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
  /// sollecito dell'idea.
  Future<void> _dimenticaSegni(String viaggioId) =>
      (_db.delete(_db.impostazioni)..where(
            (i) => i.chiave.isIn([
              '$_benvenuto$viaggioId',
              _chiaveSollecito(viaggioId),
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
    await aggiornaCopia();
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

  // ─── Spese: le scritture che richiedono la rete ──────────────────────────

  /// Cambia una spesa: importo, valuta, descrizione, data. Con la versione su
  /// cui la persona ha deciso: sui soldi non si indovina, e se qualcuno l'ha
  /// cambiata nel frattempo si rifiuta e la copia si riscarica (06, casi
  /// limite). Prima parte quello che è in coda, così la spesa ha la sua
  /// versione del server.
  Future<void> modificaSpesa(Spesa spesa, Map<String, Object?> valori) async {
    await coda.svuota();
    final attuale =
        await (_db.select(
          _db.spese,
        )..where((s) => s.id.equals(spesa.id))).getSingleOrNull() ??
        spesa;
    if (attuale.versione == 0) {
      throw const ErroreTrolley(
        'Questa spesa non è ancora arrivata sul server: si potrà cambiare '
        'quando parte.',
      );
    }
    final righe = await _alServer(
      () => _server
          .from('spesa')
          .update({...valori, 'versione': attuale.versione})
          .eq('id', spesa.id)
          .select(),
    );
    if (righe.isEmpty) {
      await aggiornaCopia().catchError((_) {});
      throw const ErroreTrolley(
        'Questa spesa non c\'è più sul server. Ora vedi le spese come sono '
        'adesso.',
      );
    }
    await coda.nellaCopiaSpesa(righe.single);
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

  /// Aggiunge una voce alla propria lista. Richiede la rete: senza, le liste
  /// si leggono e si spuntano e basta (05, regola 5). L'id nasce qui, così
  /// una risposta persa per strada non la aggiunge due volte.
  Future<VoceLista> aggiungiVoce({
    required String viaggioId,
    required String testo,
    int quantita = 1,
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
              'tipo': listaDellaFase.codice,
              'proprietario_id': io,
              'creato_da': io,
            },
            onConflict: 'id',
            ignoreDuplicates: true,
          )
          .select(),
      messaggi: const {
        '42501':
            'Il server non l\'ha accettata: forse non fai più parte di questo '
            'viaggio.',
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

  /// Cambia una voce: il testo, quante. Con la versione su cui la persona ha
  /// deciso: due testi non si fondono mai, e se qualcuno l'ha cambiata nel
  /// frattempo si rifiuta e la copia si riscarica (02 §3). Prima parte quello
  /// che è in coda, così la voce ha la sua versione del server.
  Future<void> modificaVoce(VoceLista voce, Map<String, Object?> valori) async {
    await coda.svuota();
    final attuale =
        await (_db.select(
          _db.vociLista,
        )..where((v) => v.id.equals(voce.id))).getSingleOrNull() ??
        voce;
    final righe = await _alServer(
      () => _server
          .from('voce_lista')
          .update({...valori, 'versione': attuale.versione})
          .eq('id', voce.id)
          .select(),
      messaggi: const {
        CodiciServer.versioneSuperata:
            'Questa voce è appena cambiata su un altro telefono. Ora vedi '
            'com\'è adesso: controlla e riprova.',
      },
    );
    if (righe.isEmpty) {
      await aggiornaCopia().catchError((_) {});
      throw const ErroreTrolley(
        'Questa voce non c\'è più sul server. Ora vedi la lista com\'è adesso.',
      );
    }
    await coda.nellaCopiaVoce(righe.single);
  }

  /// Toglie una voce: si marca, non si cancella (01-modello-dati.md).
  Future<void> togliVoce(VoceLista voce) => modificaVoce(voce, {
    'eliminato_il': DateTime.now().toUtc().toIso8601String(),
  });

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
      await aggiornaCopia().catchError((_) {});
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
