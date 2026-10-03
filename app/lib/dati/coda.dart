/// La coda di scrittura (02-sincronizzazione-e-offline.md §2): i gesti che si
/// fanno anche senza rete. Dalla fase 1.2 aggiungere una tappa e segnarla,
/// dalla 1.4 registrare una spesa, dalla 1.5 spuntare una voce: sono tutti e
/// quattro, e non ce ne saranno altri senza una decisione (02 §2).
///
/// Il gesto riesce subito: si scrive nella copia, si mette in coda, e
/// l'interfaccia si comporta come se fosse fatto — perché è fatto. Poi la coda
/// parte appena c'è rete: in ordine, senza duplicare, e senza fermarsi su
/// un'operazione che il server rifiuta, che dopo qualche tentativo si mette da
/// parte e si dice, con la scelta fra riprovare e scartare.
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dominio/calendario.dart';
import '../dominio/giornate.dart';
import '../dominio/tappe.dart';
import '../dominio/valute.dart';
import 'database.dart';
import 'errori.dart';
import 'rete.dart';

/// Una tappa nuova, come la scrive chi la aggiunge.
class NuovaTappa {
  const NuovaTappa({
    required this.id,
    required this.viaggioId,
    required this.giornoId,
    required this.ordine,
    required this.titolo,
    required this.tipo,
    required this.durata,
    this.ora,
    this.luogo,
  });

  /// Generato sul telefono: rimandarla non la aggiunge due volte.
  final String id;
  final String viaggioId;
  final String giornoId;
  final int ordine;
  final String titolo;
  final TipoTappa? tipo;
  final Duration durata;
  final Duration? ora;
  final String? luogo;

  /// La riga come la scrive il server.
  Map<String, Object?> get riga {
    final dove = luogo?.trim();
    return {
      'id': id,
      'viaggio_id': viaggioId,
      'giorno_id': giornoId,
      'ordine': ordine,
      'titolo': titolo.trim(),
      'tipo': tipo?.name,
      'durata_stimata_min': durata.inMinutes,
      'ora_inizio': ora == null ? null : scriviOra(ora!),
      'luogo_nome': dove == null || dove.isEmpty ? null : dove,
    };
  }
}

/// Una spesa nuova, come la registra chi l'ha fatta (06-spese.md).
class NuovaSpesa {
  const NuovaSpesa({
    required this.id,
    required this.viaggioId,
    required this.centesimi,
    required this.valuta,
    required this.paganteId,
    required this.data,
    this.descrizione,
    this.tassoUsato,
    this.tassoAl,
  });

  /// Generato sul telefono: rimandarla non la registra due volte.
  final String id;
  final String viaggioId;
  final int centesimi;
  final String valuta;
  final String paganteId;

  /// Il giorno in cui è stata fatta: arrivi quando arrivi, entra con questa
  /// data (06, casi limite).
  final DateTime data;
  final String? descrizione;

  /// Quanto valeva un euro in [valuta] quando è stata registrata, e quando
  /// quel tasso è arrivato: una conversione senza la sua data è una bugia
  /// (01-modello-dati.md). Nessuno dei due se il tasso non c'era.
  final String? tassoUsato;
  final DateTime? tassoAl;

  /// La riga come la scrive il server.
  Map<String, Object?> get riga {
    final cosa = descrizione?.trim();
    return {
      'id': id,
      'viaggio_id': viaggioId,
      'importo': importoPerIlServer(centesimi),
      'valuta': valuta,
      'pagante_id': paganteId,
      'data': scriviData(data),
      'descrizione': cosa == null || cosa.isEmpty ? null : cosa,
      'tasso_usato': tassoAl == null ? null : tassoUsato,
      'tasso_al': tassoUsato == null
          ? null
          : tassoAl?.toUtc().toIso8601String(),
    };
  }
}

/// Una riga di `spesa` del server, come va nella copia.
SpeseCompanion rigaSpesa(Map<String, dynamic> r, DateTime adesso) =>
    SpeseCompanion.insert(
      id: r['id'] as String,
      versione: r['versione'] as int,
      eliminatoIl: Value(r['eliminato_il'] as String?),
      scaricatoIl: adesso,
      viaggioId: r['viaggio_id'] as String,
      importo: '${r['importo']}',
      valuta: r['valuta'] as String,
      tassoUsato: Value(r['tasso_usato']?.toString()),
      tassoAl: Value(r['tasso_al'] as String?),
      paganteId: r['pagante_id'] as String,
      data: r['data'] as String,
      descrizione: Value(r['descrizione'] as String?),
      creatoDa: r['creato_da'] as String,
      creatoIl: r['creato_il'] as String,
    );

/// Una riga di `voce_lista` del server, come va nella copia.
VociListaCompanion rigaVoce(Map<String, dynamic> r, DateTime adesso) =>
    VociListaCompanion.insert(
      id: r['id'] as String,
      versione: r['versione'] as int,
      eliminatoIl: Value(r['eliminato_il'] as String?),
      scaricatoIl: adesso,
      viaggioId: r['viaggio_id'] as String,
      testo: r['testo'] as String,
      quantita: (r['quantita'] as int?) ?? 1,
      tipo: r['tipo'] as String,
      proprietarioId: r['proprietario_id'] as String,
      assegnatoA: Value(r['assegnato_a'] as String?),
      spuntata: r['spuntata'] as bool,
      creatoDa: r['creato_da'] as String,
      creatoIl: r['creato_il'] as String,
    );

/// Una riga di `tappa` del server, come va nella copia.
TappeCompanion rigaTappa(Map<String, dynamic> r, DateTime adesso) =>
    TappeCompanion.insert(
      id: r['id'] as String,
      versione: r['versione'] as int,
      eliminatoIl: Value(r['eliminato_il'] as String?),
      scaricatoIl: adesso,
      viaggioId: r['viaggio_id'] as String,
      giornoId: r['giorno_id'] as String,
      ordine: r['ordine'] as int,
      titolo: r['titolo'] as String,
      luogoNome: Value(r['luogo_nome'] as String?),
      lat: Value((r['lat'] as num?)?.toDouble()),
      lon: Value((r['lon'] as num?)?.toDouble()),
      durataStimataMin: r['durata_stimata_min'] as int,
      oraInizio: Value(r['ora_inizio'] as String?),
      stato: r['stato'] as String,
      marcataIl: Value(r['marcata_il'] as String?),
      marcataDuranteIlViaggio: r['marcata_durante_il_viaggio'] as bool,
      eccedente: r['eccedente'] as bool,
      tipo: Value(r['tipo'] as String?),
      creatoDa: r['creato_da'] as String,
      creatoIl: r['creato_il'] as String,
    );

class Coda {
  Coda(this._db, this._supabase, {this.rete});

  final DatabaseLocale _db;
  final SupabaseClient _supabase;

  /// A cui dire com'è andata ogni invio (rete.dart).
  final Rete? rete;

  /// Come in Archivio: `rest`, perché applica le opzioni del client.
  PostgrestClient get _server => _supabase.rest;

  /// Dopo quanti rifiuti del server un'operazione si mette da parte.
  static const tentativiMassimi = 3;

  /// L'invio in corso, se c'è: chi chiede di svuotare mentre parte aspetta
  /// quello, che ripassa la coda prima di finire.
  Future<void>? _invio;
  bool _ancora = false;

  // ─── I gesti ────────────────────────────────────────────────────────────

  /// Aggiunge una tappa: nella copia subito, al server appena si può. La
  /// capienza l'ha già controllata chi la aggiunge; al momento dell'invio si
  /// ricontrolla su quello che c'è sul server ([_inviaTappa]).
  Future<void> aggiungiTappa(NuovaTappa tappa) async {
    final carico = {
      ...tappa.riga,
      'creato_da': ?_supabase.auth.currentUser?.id,
    };
    await _metti(
      id: tappa.id,
      viaggioId: tappa.viaggioId,
      gesto: GestoOffline.aggiungiTappa,
      carico: carico,
    );
  }

  /// Segna una tappa completata o saltata, o la riporta da fare. Vince
  /// l'ultima che arriva: completata e saltata contano tutte e due come
  /// segnata, e la verifica non cambia (02 §2).
  Future<void> segnaTappa({
    required String tappaId,
    required String viaggioId,
    required StatoTappa stato,
    required bool duranteIlViaggio,
  }) => _metti(
    id: _nuovoId(),
    viaggioId: viaggioId,
    gesto: GestoOffline.marcaTappa,
    carico: {
      'tappa_id': tappaId,
      'stato': stato.codice,
      'marcata_il': stato.segnata
          ? DateTime.now().toUtc().toIso8601String()
          : null,
      'marcata_durante_il_viaggio': stato.segnata && duranteIlViaggio,
    },
  );

  /// Registra una spesa: nella copia subito, al server appena si può. È il
  /// gesto del mercato, e non conosce conflitti: due spese sono due spese
  /// (02 §2).
  Future<void> registraSpesa(NuovaSpesa spesa) => _metti(
    id: spesa.id,
    viaggioId: spesa.viaggioId,
    gesto: GestoOffline.registraSpesa,
    carico: {...spesa.riga, 'creato_da': ?_supabase.auth.currentUser?.id},
  );

  /// Spunta una voce, o le toglie la spunta. Spuntato è spuntato, chiunque
  /// l'abbia fatto, e vince l'ultima che arriva: non porta la versione, e non
  /// conosce conflitti (02 §2). Il testo resta qui, solo per dire quale voce
  /// non è arrivata.
  Future<void> spuntaVoce({
    required String voceId,
    required String viaggioId,
    required bool spuntata,
    required String testo,
  }) => _metti(
    id: _nuovoId(),
    viaggioId: viaggioId,
    gesto: GestoOffline.spuntaVoce,
    carico: {'voce_id': voceId, 'spuntata': spuntata, 'testo': testo},
  );

  Future<void> _metti({
    required String id,
    required String viaggioId,
    required GestoOffline gesto,
    required Map<String, Object?> carico,
  }) async {
    final creataIl = DateTime.now().toUtc();
    await _db.transaction(() async {
      await _db
          .into(_db.codaScrittura)
          .insert(
            CodaScritturaCompanion.insert(
              id: id,
              viaggioId: viaggioId,
              gesto: gesto,
              carico: jsonEncode(carico),
              creataIl: creataIl,
            ),
          );
      await _applica(gesto, carico, creataIl);
    });
    if (rete?.disponibile ?? true) unawaited(svuota());
  }

  static var _contatore = 0;

  /// Un id per un'operazione: basta che non si ripeta su questo telefono.
  static String _nuovoId() =>
      'op-${DateTime.now().microsecondsSinceEpoch}-${_contatore++}';

  // ─── L'invio ────────────────────────────────────────────────────────────

  /// Manda quello che c'è in coda, nell'ordine in cui è stato fatto. Senza rete
  /// si ferma e riproverà: quando torna, quando si riapre l'app, al prossimo
  /// gesto. Un'operazione che il server rifiuta ferma solo quelle dietro di lei
  /// nello stesso viaggio, e dopo [tentativiMassimi] volte si mette da parte.
  Future<void> svuota() {
    final invio = _invio;
    if (invio != null) {
      _ancora = true;
      return invio;
    }
    return _invio = _svuota().whenComplete(() => _invio = null);
  }

  Future<void> _svuota() async {
    try {
      do {
        _ancora = false;
        final operazioni =
            await (_db.select(_db.codaScrittura)
                  ..where((o) => o.messaDaParte.equals(false))
                  ..orderBy([(o) => OrderingTerm.asc(o.rowId)]))
                .get();
        // Aggiungere una tappa e poi segnarla non può arrivare al contrario.
        final fermi = <String>{};
        for (final op in operazioni) {
          if (fermi.contains(op.viaggioId)) continue;
          try {
            await _invia(op);
            await (_db.delete(
              _db.codaScrittura,
            )..where((o) => o.id.equals(op.id))).go();
          } on ErroreTrolley catch (e) {
            if (e.serveLaRete) return;
            final daParte = await _rifiutata(op, e.messaggio);
            if (!daParte) fermi.add(op.viaggioId);
          } on Object {
            final daParte = await _rifiutata(op, _nonCapita);
            if (!daParte) fermi.add(op.viaggioId);
          }
        }
      } while (_ancora);
    } finally {
      // La copia ha preso le righe del server: quello che resta in coda le
      // ricopre di nuovo.
      await riapplica();
    }
  }

  /// Conta un rifiuto. `true` se l'operazione è andata da parte.
  Future<bool> _rifiutata(OperazioneInCoda op, String perche) async {
    final tentativi = op.tentativi + 1;
    final daParte = tentativi >= tentativiMassimi;
    await (_db.update(
      _db.codaScrittura,
    )..where((o) => o.id.equals(op.id))).write(
      CodaScritturaCompanion(
        tentativi: Value(tentativi),
        ultimoErrore: Value(perche),
        messaDaParte: Value(daParte),
      ),
    );
    return daParte;
  }

  Future<void> _invia(OperazioneInCoda op) {
    final carico = jsonDecode(op.carico) as Map<String, dynamic>;
    return switch (op.gesto) {
      GestoOffline.aggiungiTappa => _inviaTappa(carico),
      GestoOffline.marcaTappa => _inviaSegno(carico),
      GestoOffline.registraSpesa => _inviaSpesa(carico),
      GestoOffline.spuntaVoce => _inviaSpunta(carico),
    };
  }

  Future<T> _alServer<T>(Future<T> Function() chiamata) => alServer(
    chiamata,
    rete: rete,
    messaggi: const {
      '42501':
          'Il server non l\'ha accettata: forse non fai più parte di questo '
          'viaggio.',
      '23503': 'Il giorno di questa tappa non fa più parte del viaggio.',
    },
  );

  /// La capienza si ricontrolla su quello che c'è adesso sul server: se nel
  /// frattempo altri hanno riempito la giornata, la tappa entra lo stesso ma
  /// segnalata come eccedente (02 §2). Rimandata, non si duplica.
  Future<void> _inviaTappa(Map<String, dynamic> carico) async {
    final id = carico['id'] as String;
    final giornoId = carico['giorno_id'] as String;
    final (giorni, altre) = await _alServer(
      () async => (
        await _server
            .from('giorno')
            .select('finestra_inizio, finestra_fine')
            .eq('id', giornoId),
        await _server
            .from('tappa')
            .select('durata_stimata_min')
            .eq('giorno_id', giornoId)
            .isFilter('eliminato_il', null)
            .neq('id', id),
      ),
    );
    var eccedente = false;
    final giorno = giorni.firstOrNull;
    if (giorno != null) {
      final capienza =
          (leggiOra(giorno['finestra_fine'] as String?) ?? fineGiornata) -
          (leggiOra(giorno['finestra_inizio'] as String?) ?? inizioGiornata);
      eccedente = !entraNellaGiornata(
        capienza: capienza,
        durateMinuti: [for (final t in altre) t['durata_stimata_min'] as int],
        nuovaMinuti: carico['durata_stimata_min'] as int,
      );
    }
    final scritte = await _alServer(
      () => _server
          .from('tappa')
          .upsert(
            {...carico, 'eccedente': eccedente},
            onConflict: 'id',
            ignoreDuplicates: true,
          )
          .select(),
    );
    // Già arrivata un'altra volta: si prende com'è sul server.
    final riga =
        scritte.firstOrNull ??
        (await _alServer(() => _server.from('tappa').select().eq('id', id)))
            .firstOrNull;
    if (riga != null) await nellaCopia(riga);
  }

  Future<void> _inviaSegno(Map<String, dynamic> carico) async {
    final scritte = await _alServer(
      () => _server
          .from('tappa')
          .update({
            'stato': carico['stato'],
            'marcata_il': carico['marcata_il'],
            'marcata_durante_il_viaggio': carico['marcata_durante_il_viaggio'],
          })
          .eq('id', carico['tappa_id'] as String)
          .select(),
    );
    if (scritte.isEmpty) {
      throw const ErroreTrolley(
        'Questa tappa non c\'è sul server: forse qualcuno l\'ha tolta.',
      );
    }
    await nellaCopia(scritte.single);
  }

  Future<void> _inviaSpunta(Map<String, dynamic> carico) async {
    final scritte = await _alServer(
      () => _server
          .from('voce_lista')
          .update({'spuntata': carico['spuntata']})
          .eq('id', carico['voce_id'] as String)
          .select(),
    );
    if (scritte.isEmpty) {
      throw const ErroreTrolley(
        'Questa voce non c\'è sul server: forse è stata tolta da un altro '
        'telefono.',
      );
    }
    await nellaCopiaVoce(scritte.single);
  }

  /// Rimandata, non si duplica: se c'è già, vale la riga del server.
  Future<void> _inviaSpesa(Map<String, dynamic> carico) async {
    final id = carico['id'] as String;
    final scritte = await _alServer(
      () => _server
          .from('spesa')
          .upsert(carico, onConflict: 'id', ignoreDuplicates: true)
          .select(),
    );
    final riga =
        scritte.firstOrNull ??
        (await _alServer(() => _server.from('spesa').select().eq('id', id)))
            .firstOrNull;
    if (riga != null) await nellaCopiaSpesa(riga);
  }

  static const _nonCapita =
      'Il server ha risposto in un modo che l\'app non capisce.';

  // ─── La copia ───────────────────────────────────────────────────────────

  /// Mette nella copia una tappa come l'ha scritta il server. Tolta, esce.
  Future<void> nellaCopia(Map<String, dynamic> riga) async {
    if (riga['eliminato_il'] != null) {
      await (_db.delete(
        _db.tappe,
      )..where((t) => t.id.equals(riga['id'] as String))).go();
      return;
    }
    await _db
        .into(_db.tappe)
        .insertOnConflictUpdate(rigaTappa(riga, DateTime.now().toUtc()));
  }

  /// Mette nella copia una spesa come l'ha scritta il server. Tolta, esce.
  Future<void> nellaCopiaSpesa(Map<String, dynamic> riga) async {
    if (riga['eliminato_il'] != null) {
      await (_db.delete(
        _db.spese,
      )..where((s) => s.id.equals(riga['id'] as String))).go();
      return;
    }
    await _db
        .into(_db.spese)
        .insertOnConflictUpdate(rigaSpesa(riga, DateTime.now().toUtc()));
  }

  /// Mette nella copia una voce come l'ha scritta il server. Tolta, esce.
  Future<void> nellaCopiaVoce(Map<String, dynamic> riga) async {
    if (riga['eliminato_il'] != null) {
      await (_db.delete(
        _db.vociLista,
      )..where((v) => v.id.equals(riga['id'] as String))).go();
      return;
    }
    await _db
        .into(_db.vociLista)
        .insertOnConflictUpdate(rigaVoce(riga, DateTime.now().toUtc()));
  }

  /// Rimette nella copia quello che è ancora in coda, sopra le righe arrivate
  /// dal server: una tappa aggiunta offline non sparisce quando la copia si
  /// riscarica, e una segnata resta segnata.
  Future<void> riapplica() async {
    final operazioni = await (_db.select(
      _db.codaScrittura,
    )..orderBy([(o) => OrderingTerm.asc(o.rowId)])).get();
    for (final op in operazioni) {
      await _applica(
        op.gesto,
        jsonDecode(op.carico) as Map<String, dynamic>,
        op.creataIl,
      );
    }
  }

  Future<void> _applica(
    GestoOffline gesto,
    Map<String, Object?> c,
    DateTime creataIl,
  ) async {
    switch (gesto) {
      case GestoOffline.aggiungiTappa:
        // Se il server l'ha già, vale la sua riga.
        await _db
            .into(_db.tappe)
            .insert(
              TappeCompanion.insert(
                id: c['id']! as String,
                versione: 0,
                scaricatoIl: DateTime.now().toUtc(),
                viaggioId: c['viaggio_id']! as String,
                giornoId: c['giorno_id']! as String,
                ordine: c['ordine']! as int,
                titolo: c['titolo']! as String,
                luogoNome: Value(c['luogo_nome'] as String?),
                durataStimataMin: c['durata_stimata_min']! as int,
                oraInizio: Value(c['ora_inizio'] as String?),
                stato: StatoTappa.daFare.codice,
                marcataDuranteIlViaggio: false,
                eccedente: false,
                tipo: Value(c['tipo'] as String?),
                creatoDa: (c['creato_da'] as String?) ?? '',
                creatoIl: creataIl.toUtc().toIso8601String(),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      case GestoOffline.marcaTappa:
        await (_db.update(
          _db.tappe,
        )..where((t) => t.id.equals(c['tappa_id']! as String))).write(
          TappeCompanion(
            stato: Value(c['stato']! as String),
            marcataIl: Value(c['marcata_il'] as String?),
            marcataDuranteIlViaggio: Value(
              c['marcata_durante_il_viaggio']! as bool,
            ),
          ),
        );
      case GestoOffline.registraSpesa:
        await _db
            .into(_db.spese)
            .insert(
              SpeseCompanion.insert(
                id: c['id']! as String,
                versione: 0,
                scaricatoIl: DateTime.now().toUtc(),
                viaggioId: c['viaggio_id']! as String,
                importo: c['importo']! as String,
                valuta: c['valuta']! as String,
                tassoUsato: Value(c['tasso_usato'] as String?),
                tassoAl: Value(c['tasso_al'] as String?),
                paganteId: c['pagante_id']! as String,
                data: c['data']! as String,
                descrizione: Value(c['descrizione'] as String?),
                creatoDa: (c['creato_da'] as String?) ?? '',
                creatoIl: creataIl.toUtc().toIso8601String(),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      case GestoOffline.spuntaVoce:
        await (_db.update(_db.vociLista)
              ..where((v) => v.id.equals(c['voce_id']! as String)))
            .write(VociListaCompanion(spuntata: Value(c['spuntata']! as bool)));
    }
  }

  // ─── Quello che si vede ─────────────────────────────────────────────────

  /// Le operazioni ancora in coda per un viaggio, nell'ordine in cui sono
  /// state fatte.
  Stream<List<OperazioneInCoda>> osserva(String viaggioId) =>
      (_db.select(_db.codaScrittura)
            ..where((o) => o.viaggioId.equals(viaggioId))
            ..orderBy([(o) => OrderingTerm.asc(o.rowId)]))
          .watch();

  /// La tappa a cui si riferisce un'operazione.
  static String? tappaDi(OperazioneInCoda op) {
    final carico = jsonDecode(op.carico) as Map<String, dynamic>;
    return switch (op.gesto) {
      GestoOffline.aggiungiTappa => carico['id'] as String?,
      GestoOffline.marcaTappa => carico['tappa_id'] as String?,
      _ => null,
    };
  }

  /// Il titolo della tappa di un'aggiunta, per dire quale non è partita.
  static String? titoloDi(OperazioneInCoda op) =>
      op.gesto == GestoOffline.aggiungiTappa
      ? (jsonDecode(op.carico) as Map<String, dynamic>)['titolo'] as String?
      : null;

  /// La voce a cui si riferisce un'operazione.
  static String? voceDi(OperazioneInCoda op) =>
      op.gesto == GestoOffline.spuntaVoce
      ? (jsonDecode(op.carico) as Map<String, dynamic>)['voce_id'] as String?
      : null;

  /// La spesa a cui si riferisce un'operazione: ancora in coda vuol dire che
  /// non è arrivata, e l'elenco lo dice.
  static String? spesaDi(OperazioneInCoda op) =>
      op.gesto == GestoOffline.registraSpesa
      ? (jsonDecode(op.carico) as Map<String, dynamic>)['id'] as String?
      : null;

  /// Che cosa non è arrivato, in una frase: «Taxi» non è arrivata.
  static String cosaNonEArrivato(OperazioneInCoda op) {
    final carico = jsonDecode(op.carico) as Map<String, dynamic>;
    return switch (op.gesto) {
      GestoOffline.aggiungiTappa => '«${carico['titolo']}» non è arrivata.',
      GestoOffline.marcaTappa => 'Un segno su una tappa non è arrivato.',
      GestoOffline.registraSpesa => switch (carico['descrizione']) {
        final String cosa => 'La spesa «$cosa» non è arrivata.',
        _ =>
          'Una spesa di ${scriviImporto(centesimiDa(carico['importo'] as String), carico['valuta'] as String)} '
              'non è arrivata.',
      },
      GestoOffline.spuntaVoce => switch (carico['testo']) {
        final String testo when carico['spuntata'] == true =>
          'La spunta di «$testo» non è arrivata.',
        final String testo => 'La spunta tolta a «$testo» non è arrivata.',
        _ => 'Una spunta non è arrivata.',
      },
    };
  }

  /// Rimette in fila un'operazione messa da parte.
  Future<void> riprova(String id) async {
    await (_db.update(_db.codaScrittura)..where((o) => o.id.equals(id))).write(
      const CodaScritturaCompanion(
        tentativi: Value(0),
        messaDaParte: Value(false),
      ),
    );
    await svuota();
  }

  /// Rinuncia a un'operazione messa da parte. Una tappa o una spesa che non è
  /// mai arrivata esce anche dalla copia; un segno o una spunta torna com'è sul
  /// server alla prossima copia.
  Future<void> scarta(String id) async {
    final op = await (_db.select(
      _db.codaScrittura,
    )..where((o) => o.id.equals(id))).getSingleOrNull();
    if (op == null) return;
    await _db.transaction(() async {
      await (_db.delete(_db.codaScrittura)..where((o) => o.id.equals(id))).go();
      if (op.gesto == GestoOffline.aggiungiTappa) {
        final tappa = tappaDi(op);
        await (_db.delete(
          _db.tappe,
        )..where((t) => t.id.equals(tappa ?? '') & t.versione.equals(0))).go();
      }
      if (op.gesto == GestoOffline.registraSpesa) {
        await (_db.delete(_db.spese)..where(
              (s) => s.id.equals(spesaDi(op) ?? '') & s.versione.equals(0),
            ))
            .go();
      }
    });
  }
}
