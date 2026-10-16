/// I promemoria (14-notifiche.md; dominio/notifiche.dart): li calcola dalla
/// copia sul telefono ogni volta che cambia, e li consegna al telefono.
/// Partono anche senza rete, e niente di quello che dicono esce dal
/// telefono: negli eventi va solo il tipo.
library;

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;

import '../dominio/calendario.dart';
import '../dominio/liste.dart';
import '../dominio/notifiche.dart';
import '../dominio/partenza.dart';
import '../dominio/stato_viaggio.dart';
import '../dominio/tappe.dart';
import '../misurazione/misurazione.dart';
import 'database.dart';
import 'lettura.dart';
import 'notifiche.dart';

enum PermessoNotifiche {
  /// Arrivano.
  concesso,

  /// Il telefono non l'ha ancora chiesto: lo chiede la prima volta.
  daChiedere,

  /// Il telefono non le fa arrivare: si riaccendono dalle sue Impostazioni.
  negato,
}

class Promemoria {
  Promemoria(
    this._db, {
    required this._notifiche,
    required this._misurazione,
    required this._io,
    this._orologio = DateTime.now,
    this.attesa = const Duration(seconds: 1),
  });

  final DatabaseLocale _db;
  final Notifiche _notifiche;
  final Misurazione _misurazione;
  final String? Function() _io;
  final DateTime Function() _orologio;

  /// Quanto si aspetta, dopo che la copia è cambiata, prima di riprogrammare:
  /// una copia che si riscarica cambia molte righe in un colpo.
  final Duration attesa;

  static const _chieste = 'notifiche_chieste';
  static const _nonOra = 'notifiche_non_ora';
  static const _spenta = 'notifica_spenta:';
  static const _programmata = 'notifica_programmata:';
  static const _arrivata = 'notifica_arrivata:';

  /// Le arrivate più vecchie di così si dimenticano: le loro chiavi hanno
  /// date che non tornano.
  static const _ricordaArrivate = Duration(days: 400);

  StreamSubscription<Object?>? _ascolto;
  AppLifecycleListener? _ritorno;
  Timer? _rinvio;
  Future<void> _coda = Future.value();

  /// Da qui i promemoria seguono la copia: cambia, e si riprogrammano. Anche
  /// quando l'app torna davanti, perché il tempo è passato.
  Future<void> avvia() async {
    _ascolto ??= _db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            _db.viaggi,
            _db.partecipazioni,
            _db.giorni,
            _db.tappe,
            _db.vociLista,
            _db.documenti,
            _db.traguardi,
          ]),
        )
        .listen((_) => _rinvia());
    _ritorno ??= AppLifecycleListener(onResume: _rinvia);
    await ripianifica();
  }

  void _rinvia() {
    _rinvio?.cancel();
    _rinvio = Timer(attesa, () => unawaited(ripianifica().catchError((_) {})));
  }

  Future<void> ferma() async {
    _rinvio?.cancel();
    _ritorno?.dispose();
    _ritorno = null;
    await _ascolto?.cancel();
    _ascolto = null;
  }

  /// Ricalcola i promemoria e li consegna al telefono. Una alla volta: due
  /// programmazioni sovrapposte si toglierebbero le notifiche a vicenda.
  Future<void> ripianifica() {
    final questa = _coda.then((_) => _ripianifica());
    _coda = questa.catchError((_) {});
    return questa;
  }

  Future<void> _ripianifica() async {
    final adesso = _orologio();
    final accese = await _notifiche.accese();

    // Quelle programmate l'altra volta che sono passate sono arrivate:
    // non ripartono, e si contano (07: `notifica_arrivata`).
    final programmate = await _valori(_programmata);
    final arrivate = {
      for (final MapEntry(:key, :value) in programmate.entries)
        if (DateTime.tryParse(value) case final quando?
            when !quando.isAfter(adesso.toUtc()))
          key: quando,
    };
    if (accese) {
      for (final chiave in arrivate.keys) {
        await _misurazione.registra(Eventi.notificaArrivata, {
          'tipo': chiave.split(':').first,
        });
      }
    }

    final io = _io();
    final piano = accese && io != null
        ? notificheDa(
            await _viaggi(io, adesso),
            adesso: adesso,
            spente: await spente(),
            arrivate: {...(await _valori(_arrivata)).keys, ...arrivate.keys},
          )
        : const <Notifica>[];
    await _notifiche.programma(piano);

    final dimentica = adesso.toUtc().subtract(_ricordaArrivate);
    await _db.transaction(() async {
      await (_db.delete(
        _db.impostazioni,
      )..where((i) => i.chiave.like('$_programmata%'))).go();
      await (_db.delete(_db.impostazioni)..where(
            (i) =>
                i.chiave.like('$_arrivata%') &
                i.valore.isSmallerThanValue(dimentica.toIso8601String()),
          ))
          .go();
      await _db.batch((b) {
        b.insertAllOnConflictUpdate(_db.impostazioni, [
          for (final MapEntry(:key, :value) in arrivate.entries)
            ImpostazioniCompanion.insert(
              chiave: '$_arrivata$key',
              valore: value.toIso8601String(),
            ),
          for (final n in piano)
            ImpostazioniCompanion.insert(
              chiave: '$_programmata${n.chiave}',
              valore: n.quando.toUtc().toIso8601String(),
            ),
        ]);
      });
    });
  }

  /// I viaggi di chi usa il telefono, con quello che serve ai promemoria:
  /// gli stessi conti di Prima di partire e della giornata.
  Future<List<ViaggioPerLeNotifiche>> _viaggi(
    String io,
    DateTime adesso,
  ) async {
    final righe =
        await (_db.select(_db.partecipazioni).join([
              innerJoin(
                _db.viaggi,
                _db.viaggi.id.equalsExp(_db.partecipazioni.viaggioId),
              ),
            ])..where(
              _db.partecipazioni.utenteId.equals(io) &
                  _db.partecipazioni.stato.equals('attivo') &
                  _db.partecipazioni.eliminatoIl.isNull() &
                  _db.viaggi.eliminatoIl.isNull(),
            ))
            .get();
    final viaggi = [for (final r in righe) r.readTable(_db.viaggi)];
    if (viaggi.isEmpty) return const [];
    final ids = [for (final v in viaggi) v.id];

    final giorni = await (_db.select(
      _db.giorni,
    )..where((g) => g.viaggioId.isIn(ids) & g.eliminatoIl.isNull())).get();
    final daFare =
        await (_db.select(_db.tappe)..where(
              (t) =>
                  t.viaggioId.isIn(ids) &
                  t.eliminatoIl.isNull() &
                  t.stato.equals(StatoTappa.daFare.codice),
            ))
            .get();
    final voci = await (_db.select(
      _db.vociLista,
    )..where((v) => v.viaggioId.isIn(ids) & v.eliminatoIl.isNull())).get();
    final presenti =
        await (_db.select(_db.partecipazioni)..where(
              (p) =>
                  p.viaggioId.isIn(ids) &
                  p.stato.equals('attivo') &
                  p.eliminatoIl.isNull(),
            ))
            .get();
    final documenti = await (_db.select(
      _db.documenti,
    )..where((d) => d.viaggioId.isIn(ids) & d.proprietarioId.equals(io))).get();
    final traguardi = await (_db.select(
      _db.traguardi,
    )..where((t) => t.viaggioId.isIn(ids))).get();

    Map<String, int> conta(Iterable<String> chiavi) {
      final conti = <String, int>{};
      for (final c in chiavi) {
        conti[c] = (conti[c] ?? 0) + 1;
      }
      return conti;
    }

    final daSegnare = conta(daFare.map((t) => t.giornoId));
    final documentiDel = conta(documenti.map((d) => d.viaggioId));
    final traguardiDel = conta(traguardi.map((t) => t.viaggioId));

    return [
      for (final v in viaggi)
        () {
          final dentro = {
            for (final p in presenti)
              if (p.viaggioId == v.id) p.utenteId,
          };
          final valigia = valigiaPrimaDiPartire([
            for (final x in voci)
              if (x.viaggioId == v.id)
                (
                  testo: x.testo,
                  spuntata: x.spuntata,
                  personale: x.tipo == TipoLista.personale.codice,
                  portaChi: chiLaPorta(x.assegnatoA, dentro),
                  creataIl: x.creata,
                ),
          ], io: io);
          return ViaggioPerLeNotifiche(
            id: v.id,
            stato: v.statoA(adesso),
            citta: v.destinazioneCitta,
            inizio: v.inizio,
            fine: v.fine,
            scadenza: v.statoA(adesso) == StatoViaggio.idea ? v.scadenza : null,
            importato: v.importato,
            mancano: valigia.mancano.length,
            diNessuno: valigia.diNessuno,
            documenti: documentiDel[v.id] ?? 0,
            traguardi: traguardiDel[v.id] ?? 0,
            giorni: [
              for (final g in giorni)
                if (g.viaggioId == v.id)
                  if (leggiData(g.data) case final data?)
                    (id: g.id, data: data, daSegnare: daSegnare[g.id] ?? 0),
            ],
          );
        }(),
    ];
  }

  // ─── Il permesso ────────────────────────────────────────────────────────

  Future<PermessoNotifiche> permesso() async {
    if (await _notifiche.accese()) return PermessoNotifiche.concesso;
    return await _valore(_chieste) == null
        ? PermessoNotifiche.daChiedere
        : PermessoNotifiche.negato;
  }

  /// Se il foglio del permesso (tela, 82) si propone da solo adesso.
  Future<bool> daProporre() async => permessoDaProporre(
    mai: await permesso() == PermessoNotifiche.daChiedere,
    nonOraIl: leggiData(await _valore(_nonOra)),
    oggi: _orologio(),
  );

  /// Lo chiede il telefono. [da]: `viaggio`, dal foglio che si propone
  /// quando un viaggio prende le date, o `impostazioni` (07:
  /// `permesso_notifiche`).
  Future<PermessoNotifiche> chiedi({required String da}) async {
    await _scrivi(_chieste, _orologio().toUtc().toIso8601String());
    final concesso = await _notifiche.chiedi();
    await _misurazione.registra(Eventi.permessoNotifiche, {
      'esito': concesso ? 'concesso' : 'negato',
      'da': da,
    });
    await ripianifica();
    return concesso ? PermessoNotifiche.concesso : PermessoNotifiche.negato;
  }

  /// «Non ora» sul foglio: si ripropone fra un mese (dominio/notifiche.dart).
  Future<void> nonOra() async {
    await _scrivi(_nonOra, scriviData(_orologio()));
    await _misurazione.registra(Eventi.permessoNotifiche, {
      'esito': 'non_ora',
      'da': 'viaggio',
    });
  }

  Future<void> apriImpostazioni() => _notifiche.apriImpostazioni();

  // ─── Una per una ────────────────────────────────────────────────────────

  /// I tipi spenti dalla persona (14, regola 2). Sono del telefono: le
  /// notifiche arrivano a lui.
  Future<Set<TipoNotifica>> spente() async => {
    for (final chiave in (await _valori(_spenta)).keys)
      ?TipoNotifica.leggi(chiave),
  };

  Future<void> imposta(TipoNotifica tipo, {required bool accesa}) async {
    if (accesa) {
      await (_db.delete(
        _db.impostazioni,
      )..where((i) => i.chiave.equals('$_spenta${tipo.codice}'))).go();
    } else {
      await _scrivi('$_spenta${tipo.codice}', '1');
    }
    await _misurazione.registra(Eventi.notificaImpostata, {
      'tipo': tipo.codice,
      'accesa': accesa,
    });
    await ripianifica();
  }

  // ─── Toccate ────────────────────────────────────────────────────────────

  /// Dove portano le notifiche toccate (07: `notifica_aperta`).
  Stream<DovePorta> get toccate => _notifiche.toccate.asyncMap((d) async {
    await _misurazione.registra(Eventi.notificaAperta, {'tipo': d.tipo.codice});
    return d;
  });

  // ─── Le impostazioni ────────────────────────────────────────────────────

  Future<String?> _valore(String chiave) async => (await (_db.select(
    _db.impostazioni,
  )..where((i) => i.chiave.equals(chiave))).getSingleOrNull())?.valore;

  /// Le righe che cominciano con [prefisso], senza il prefisso.
  Future<Map<String, String>> _valori(String prefisso) async => {
    for (final r in await (_db.select(
      _db.impostazioni,
    )..where((i) => i.chiave.like('$prefisso%'))).get())
      r.chiave.substring(prefisso.length): r.valore,
  };

  Future<void> _scrivi(String chiave, String valore) => _db
      .into(_db.impostazioni)
      .insertOnConflictUpdate(
        ImpostazioniCompanion.insert(chiave: chiave, valore: valore),
      );
}
