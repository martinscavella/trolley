/// Da dove arriva un documento nuovo (07-documenti.md, "Aggiungi documento"):
/// dalla scansione, dalle foto, dai file. Dietro un'interfaccia, come ogni cosa
/// che parla con un pezzo del sistema (04-integrazioni.md), così le prove la
/// sostituiscono.
///
/// Quello che arriva sta in una cartella temporanea dentro l'app: la scansione
/// non passa dal rullino, le foto e i file sono copie (03, regole 3 e 4). Le
/// copie temporanee si buttano con [Acquisizione.pulisci], appena il documento è
/// salvato o la persona ci ripensa.
library;

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';

import '../dominio/documenti.dart';
import 'errori.dart';

export '../dominio/documenti.dart' show Sorgente;

/// Un file appena arrivato, non ancora un documento.
class FileAcquisito {
  const FileAcquisito({
    required this.percorso,
    required this.sorgente,
    this.nome,
  });

  /// Dove l'ha messo il sistema: una cartella temporanea dell'app.
  final String percorso;
  final Sorgente sorgente;

  /// Il nome del file, se ne aveva uno: serve a proporre quello del documento.
  final String? nome;

  /// PDF o immagine, dal nome o dal percorso.
  FormatoDocumento? get formato => formatoDi(nome ?? percorso);
}

abstract interface class Acquisizione {
  /// Apre la scansione, le foto o i file. `null` se la persona ci ripensa.
  Future<FileAcquisito?> acquisisci(Sorgente sorgente);

  /// Butta le copie temporanee lasciate dalla scansione e dai selettori.
  Future<void> pulisci();
}

/// Il telefono vero: la fotocamera dei documenti di iOS per la scansione (le
/// pagine diventano un PDF), il selettore delle foto e quello dei file.
class AcquisizioneDelTelefono implements Acquisizione {
  const AcquisizioneDelTelefono();

  /// Le pagine di una scansione: abbastanza per un contratto d'affitto.
  static const pagineMassime = 30;

  @override
  Future<FileAcquisito?> acquisisci(Sorgente sorgente) async {
    try {
      switch (sorgente) {
        case Sorgente.scansione:
          final pagine = await CunningDocumentScanner.getPictures(
            noOfPages: pagineMassime,
            scannerSource: ScannerSource.camera,
            asPdf: true,
          );
          final percorso = pagine?.firstOrNull;
          return percorso == null
              ? null
              : FileAcquisito(percorso: percorso, sorgente: sorgente);
        case Sorgente.foto:
          return _daSelettore(
            await FilePicker.pickFile(type: FileType.image),
            sorgente,
          );
        case Sorgente.file:
          return _daSelettore(
            await FilePicker.pickFile(
              type: FileType.custom,
              allowedExtensions: [...estensioniPdf, ...estensioniImmagine],
            ),
            sorgente,
          );
      }
    } on CunningDocumentScannerException catch (e) {
      throw ErroreTrolley(switch (e.code) {
        'permission_denied' =>
          'Per scansionare serve la fotocamera. Puoi permetterlo da '
              'Impostazioni › Trolley › Fotocamera.',
        'UNAVAILABLE' =>
          'Questo telefono non può scansionare documenti: aggiungilo dalle '
              'foto o dai file.',
        _ => 'La scansione non è riuscita. Riprova.',
      });
    } on ErroreTrolley {
      rethrow;
    } on Exception {
      throw const ErroreTrolley('Il file non si è potuto aprire. Riprova.');
    }
  }

  FileAcquisito? _daSelettore(PlatformFile? scelto, Sorgente sorgente) {
    final percorso = scelto?.path;
    if (scelto == null || percorso == null) return null;
    return FileAcquisito(
      percorso: percorso,
      sorgente: sorgente,
      nome: scelto.name,
    );
  }

  @override
  Future<void> pulisci() async {
    // Ognuno butta le sue; se una non riesce, ci riprova la volta dopo.
    await Future.wait([
      CunningDocumentScanner.cleanCache().catchError((_) {}),
      FilePicker.clearTemporaryFiles().catchError((_) {}),
    ]);
  }
}
