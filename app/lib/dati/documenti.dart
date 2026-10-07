/// I documenti sul telefono (07-documenti.md, 03-documenti-sul-dispositivo.md,
/// ADR-008).
///
/// Esistono solo qui: un file nella cartella dei documenti dell'app e una riga
/// del database locale che dice che cos'è. Si leggono e si scrivono sempre,
/// anche senza rete, perché la rete non c'entra: questo file non parla con il
/// server e non deve mai farlo. Che non importi niente che ci parli lo prova
/// test/documenti_restano_qui_test.dart.
///
/// Le regole del capitolo 03 che si fanno rispettare qui:
/// - il file si copia sempre dentro l'app, mai un riferimento a un file altrui;
/// - si scrive per intero o per niente: lo spazio che finisce non lascia mezzi
///   documenti;
/// - si protegge con il codice di sblocco, e si controlla che lo sia;
/// - il percorso salvato è relativo alla cartella dell'app, mai assoluto;
/// - eliminare un documento elimina il file, non solo la riga.
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../dominio/calendario.dart';
import '../dominio/documenti.dart';
import 'acquisizione.dart';
import 'database.dart';
import 'errori.dart';
import 'file_del_telefono.dart';

class CartellaDocumenti {
  CartellaDocumenti(
    this._db, {
    required this.telefono,
    required this._cartellaApp,
    required this._io,
  });

  final DatabaseLocale _db;

  /// Protezione, pagine dei PDF, foto: le fa il telefono.
  final FileDelTelefono telefono;

  /// La cartella dell'app che entra nel backup: su iOS, Application Support.
  final Future<Directory> Function() _cartellaApp;

  /// Chi è entrato: ognuno vede solo i suoi.
  final String? Function() _io;

  /// Chi è entrato adesso.
  String? get io => _io();

  /// La sottocartella dei documenti, con dentro una cartella per viaggio.
  static const cartella = 'documenti';

  /// Un file a metà ha questo in fondo al nome: se resta, l'app si è fermata
  /// mentre lo scriveva, e si butta.
  static const _aMeta = '.parziale';

  // ─── Leggere ────────────────────────────────────────────────────────────

  /// I miei documenti di un viaggio. L'ordine dell'elenco lo decide il
  /// dominio (raggruppaDocumenti).
  Stream<List<Documento>> osserva(String viaggioId) {
    final io = _io();
    if (io == null) return Stream.value(const []);
    return (_db.select(_db.documenti)..where(
          (d) => d.viaggioId.equals(viaggioId) & d.proprietarioId.equals(io),
        ))
        .watch();
  }

  /// Un documento, finché c'è.
  Stream<Documento?> osservaDocumento(String id) => (_db.select(
    _db.documenti,
  )..where((d) => d.id.equals(id))).watchSingleOrNull();

  /// Quanti documenti miei ci sono su questo telefono, di tutti i viaggi.
  Stream<int> osservaQuanti() {
    final io = _io();
    if (io == null) return Stream.value(0);
    final quanti = _db.documenti.id.count();
    return (_db.selectOnly(_db.documenti)
          ..addColumns([quanti])
          ..where(_db.documenti.proprietarioId.equals(io)))
        .map((r) => r.read(quanti) ?? 0)
        .watchSingle();
  }

  /// Dove sta adesso il file di un documento.
  Future<File> file(Documento documento) async =>
      File(_unisci((await _cartellaApp()).path, documento.percorsoLocale));

  /// Le anteprime della prima pagina dei PDF, in memoria e solo in memoria
  /// (03, regola 3): le ultime, perché l'elenco non le ridisegni a ogni passo.
  final _anteprime = <String, Future<Uint8List>>{};
  static const _anteprimeTenute = 40;

  /// La prima pagina di un PDF, larga [larghezza] pixel.
  Future<Uint8List> anteprima(Documento documento, {required int larghezza}) {
    final chiave = '${documento.id}:$larghezza';
    final pronta = _anteprime.remove(chiave);
    if (pronta != null) return _anteprime[chiave] = pronta;
    final nuova = file(documento).then(
      (f) => telefono.pagina(f.path, indice: 0, larghezza: larghezza),
    );
    _anteprime[chiave] = nuova;
    // Un'anteprima che non riesce si riprova la volta dopo.
    nuova.catchError((_) {
      _anteprime.remove(chiave);
      return Uint8List(0);
    });
    while (_anteprime.length > _anteprimeTenute) {
      _anteprime.remove(_anteprime.keys.first);
    }
    return nuova;
  }

  // ─── Scrivere ───────────────────────────────────────────────────────────

  /// Fa di un file appena arrivato un documento del viaggio: lo copia (o, se è
  /// un'immagine, lo comprime) dentro la cartella del viaggio, lo protegge,
  /// controlla che sia protetto, e solo allora lo mette nell'elenco. Se
  /// qualcosa va storto non resta niente: né il file né la riga.
  Future<Documento> aggiungi({
    required String viaggioId,
    required String? giornoId,
    required Duration? ora,
    required String nome,
    required FileAcquisito sorgente,
  }) async {
    final io = _io();
    if (io == null) {
      throw const ErroreTrolley('Per aggiungere un documento serve l\'accesso.');
    }
    final formato = sorgente.formato;
    if (formato == null) {
      throw const ErroreTrolley(
        'Questo file non si può aggiungere: servono un PDF o un\'immagine.',
      );
    }
    final id = const Uuid().v4();
    final relativo = [
      cartella,
      viaggioId,
      '$id.${formato == FormatoDocumento.pdf ? 'pdf' : 'jpg'}',
    ].join('/');
    final destinazione = File(_unisci((await _cartellaApp()).path, relativo));
    final aMeta = File('${destinazione.path}$_aMeta');

    try {
      await destinazione.parent.create(recursive: true);
      int? pagine;
      if (formato == FormatoDocumento.pdf) {
        // Prima di copiare: un PDF con la password non si aggiunge.
        pagine = await telefono.pagine(sorgente.percorso);
        await File(sorgente.percorso).copy(aMeta.path);
      } else {
        await telefono.comprimi(da: sorgente.percorso, a: aMeta.path);
      }
      await aMeta.rename(destinazione.path);
      final stato = await telefono.proteggi(destinazione.path);
      if (!stato.comeDeveEssere) {
        throw ErroreTrolley(
          'Il telefono non ha protetto il documento come deve ($stato): non '
          'è stato salvato.',
        );
      }
      final riga = DocumentiCompanion.insert(
        id: id,
        viaggioId: viaggioId,
        giornoId: Value(giornoId),
        ora: Value(ora == null ? null : scriviOra(ora)),
        nome: nome.trim(),
        percorsoLocale: relativo,
        formato: formato.name,
        pagine: Value(pagine),
        sorgente: sorgente.sorgente.name,
        proprietarioId: io,
        creatoIl: DateTime.now().toUtc(),
      );
      await _db.into(_db.documenti).insert(riga);
      return await (_db.select(
        _db.documenti,
      )..where((d) => d.id.equals(id))).getSingle();
    } on Object catch (e) {
      await _butta(aMeta);
      await _butta(destinazione);
      if (e is FileSystemException) throw erroreDelDisco(e);
      rethrow;
    }
  }

  /// Cambia nome, giorno e ora. Solo la riga: il file resta quello.
  Future<void> modifica(
    Documento documento, {
    required String nome,
    required String? giornoId,
    required Duration? ora,
  }) =>
      (_db.update(
        _db.documenti,
      )..where((d) => d.id.equals(documento.id))).write(
        DocumentiCompanion(
          nome: Value(nome.trim()),
          giornoId: Value(giornoId),
          ora: Value(ora == null ? null : scriviOra(ora)),
        ),
      );

  /// Elimina il documento: prima il file, poi la riga (03, regola 5). Se il
  /// file non si riesce a cancellare la riga resta, così si può riprovare.
  Future<void> elimina(Documento documento) async {
    final f = await file(documento);
    try {
      await f.delete();
    } on PathNotFoundException {
      // Già andato: resta da togliere la riga.
    } on FileSystemException catch (e) {
      throw erroreDelDisco(e);
    }
    _anteprime.removeWhere((chiave, _) => chiave.startsWith('${documento.id}:'));
    await (_db.delete(
      _db.documenti,
    )..where((d) => d.id.equals(documento.id))).go();
  }

  /// Toglie dal telefono tutti i documenti di un viaggio, di chiunque siano:
  /// la cartella e le righe (03, regola 5). Per quando il viaggio esce dal
  /// telefono.
  Future<void> eliminaViaggio(String viaggioId) async {
    final cartellaViaggio = Directory(
      _unisci((await _cartellaApp()).path, '$cartella/$viaggioId'),
    );
    if (await cartellaViaggio.exists()) {
      await cartellaViaggio.delete(recursive: true);
    }
    _anteprime.clear();
    await (_db.delete(
      _db.documenti,
    )..where((d) => d.viaggioId.equals(viaggioId))).go();
  }

  /// Toglie dal telefono tutti i documenti di [proprietario], di ogni viaggio,
  /// file e righe: per chi chiude l'account (U.1). Quelli di un altro account
  /// su questo telefono restano. Restituisce quanti ne ha tolti.
  Future<int> eliminaQuelliDi(String proprietario) async {
    final suoi = await (_db.select(
      _db.documenti,
    )..where((d) => d.proprietarioId.equals(proprietario))).get();
    for (final d in suoi) {
      await elimina(d);
    }
    return suoi.length;
  }

  /// Se a chi è entrato si è già detto, aggiungendo il primo documento, che i
  /// documenti stanno solo su questo telefono (07, regola 7): si dice una volta.
  Future<bool> avvisoGiaDato() async {
    final riga = await (_db.select(
      _db.impostazioni,
    )..where((i) => i.chiave.equals(_chiaveAvviso))).getSingleOrNull();
    return riga != null;
  }

  Future<void> segnaAvvisoDato() => _db
      .into(_db.impostazioni)
      .insertOnConflictUpdate(
        ImpostazioniCompanion.insert(
          chiave: _chiaveAvviso,
          valore: DateTime.now().toUtc().toIso8601String(),
        ),
      );

  String get _chiaveAvviso => 'documenti:avviso_dato:${_io() ?? ''}';

  /// Butta i file rimasti a metà da un'aggiunta interrotta. Si chiama
  /// all'avvio.
  Future<void> pulisci() async {
    final radice = Directory(_unisci((await _cartellaApp()).path, cartella));
    if (!await radice.exists()) return;
    await for (final voce in radice.list(recursive: true)) {
      if (voce is File && voce.path.endsWith(_aMeta)) await _butta(voce);
    }
  }

  static Future<void> _butta(File f) async {
    try {
      await f.delete();
    } on FileSystemException {
      // Non c'era.
    }
  }

  /// La cartella dell'app e un percorso relativo, con le barre del telefono.
  static String _unisci(String base, String relativo) =>
      '$base${Platform.pathSeparator}${relativo.replaceAll('/', Platform.pathSeparator)}';
}

/// Un errore del disco detto alla persona (03, casi da gestire): lo spazio
/// finito ha la sua frase, il resto una generica.
ErroreTrolley erroreDelDisco(FileSystemException e) => ErroreTrolley(
  // ENOSPC: 28 su iOS e Android.
  e.osError?.errorCode == 28
      ? messaggioSpazioFinito
      : 'Il documento non si è potuto salvare. Riprova.',
);
