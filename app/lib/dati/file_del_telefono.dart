/// Quello che il telefono fa sui file dei documenti e che Dart da solo non sa
/// fare (ADR-008): proteggerli e dire com'è rimasto, leggere le pagine di un PDF
/// in memoria, comprimere una foto. Su iOS è `DocumentiDelTelefono.swift`;
/// nelle prove, un finto.
///
/// Come il resto dei documenti, non parla con nessuno fuori dal telefono.
library;

import 'package:flutter/services.dart';

import 'errori.dart';

/// Com'è un file dopo averlo protetto.
class StatoFile {
  const StatoFile({required this.protezione, required this.nelBackup});

  /// La classe di protezione: `completa` vuol dire cifrato con il codice di
  /// sblocco e illeggibile a telefono bloccato.
  final String protezione;

  /// Se il backup di sistema lo porta sul telefono nuovo.
  final bool nelBackup;

  /// Quello che 03 chiede: cifrato, e nel backup.
  bool get comeDeveEssere => protezione == 'completa' && nelBackup;

  @override
  String toString() => 'StatoFile($protezione, nel backup: $nelBackup)';
}

abstract interface class FileDelTelefono {
  /// Protegge il file con la classe più forte e lo lascia nel backup. Dice
  /// com'è rimasto: chi la chiama controlla, non si fida.
  Future<StatoFile> proteggi(String percorso);

  /// Quante pagine ha un PDF. [ErroreTrolley] se non si legge o ha una password.
  Future<int> pagine(String percorso);

  /// La pagina [indice] (da 0) larga [larghezza] pixel, in PNG, in memoria.
  Future<Uint8List> pagina(
    String percorso, {
    required int indice,
    required int larghezza,
  });

  /// Da qualunque immagine (HEIC, PNG, JPEG) a un JPEG in [a], raddrizzato,
  /// senza metadati e con il lato lungo al più [lato] pixel.
  Future<void> comprimi({
    required String da,
    required String a,
    int lato = 2800,
    double qualita = 0.85,
  });

  /// Se il telefono ha un codice di sblocco: senza, la cifratura non lega
  /// niente, e chi lo trova apre i documenti.
  Future<bool> haCodiceDiSblocco();
}

/// Il telefono vero, attraverso il canale `trolley/documenti`.
class FileDelTelefonoNativo implements FileDelTelefono {
  const FileDelTelefonoNativo();

  static const _canale = MethodChannel('trolley/documenti');

  @override
  Future<StatoFile> proteggi(String percorso) async {
    final stato = await _chiama<Map<Object?, Object?>>('proteggi', {
      'percorso': percorso,
    });
    return StatoFile(
      protezione: stato['protezione'] as String? ?? 'nessuna',
      nelBackup: stato['nelBackup'] as bool? ?? false,
    );
  }

  @override
  Future<int> pagine(String percorso) =>
      _chiama<int>('pagine', {'percorso': percorso});

  @override
  Future<Uint8List> pagina(
    String percorso, {
    required int indice,
    required int larghezza,
  }) => _chiama<Uint8List>('pagina', {
    'percorso': percorso,
    'indice': indice,
    'larghezza': larghezza,
  });

  @override
  Future<void> comprimi({
    required String da,
    required String a,
    int lato = 2800,
    double qualita = 0.85,
  }) => _chiama<Object?>('comprimi', {
    'da': da,
    'a': a,
    'lato': lato,
    'qualita': qualita,
  });

  @override
  Future<bool> haCodiceDiSblocco() async {
    try {
      return await _chiama<bool>('codiceDiSblocco', const {});
    } on ErroreTrolley {
      // Se non si sa, non si spaventa nessuno.
      return true;
    }
  }

  static Future<T> _chiama<T>(String metodo, Map<String, Object?> argomenti) async {
    try {
      final risposta = await _canale.invokeMethod<T>(metodo, argomenti);
      if (risposta == null) throw const ErroreTrolley(_nonRiuscito);
      return risposta;
    } on PlatformException catch (e) {
      throw ErroreTrolley(_messaggi[e.code] ?? _nonRiuscito);
    } on MissingPluginException {
      // Solo iOS ha il canale, per ora (punti-aperti.md, 1.3).
      throw const ErroreTrolley(
        'Su questo telefono i documenti non funzionano ancora.',
      );
    }
  }

  static const _nonRiuscito = 'Il documento non si è potuto leggere. Riprova.';

  static const _messaggi = {
    'spazio_finito': messaggioSpazioFinito,
    'pdf_protetto':
        'Questo PDF è protetto da una password, e Trolley non riesce ad '
        'aprirlo. Salvane una copia senza password, o fanne uno screenshot.',
    'pdf_illeggibile': 'Questo file non è un PDF che si riesce ad aprire.',
    'immagine_illeggibile': 'Questa immagine non si riesce ad aprire.',
  };
}

/// Lo spazio sul telefono è finito: è il sistema, ma va detto in modo che si
/// capisca cosa fare (03, casi da gestire).
const messaggioSpazioFinito =
    'Il telefono non ha più spazio: libera un po\' di spazio e riprova. Il '
    'documento non è stato salvato.';
