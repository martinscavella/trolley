# ADR-008 — Documenti sul telefono: dove, come si proteggono, come si leggono

**Stato**: accettata (fase 1.3, 3 ottobre 2026). Solo iOS: Android va scritto prima della sua prima build.

## Contesto

Il capitolo [03](../03-documenti-sul-dispositivo.md) chiede che i documenti non lascino mai il telefono, che stiano nel backup di sistema, che siano cifrati con il codice di sblocco, che non ne restino copie o anteprime fuori dal documento, e che queste proprietà siano **verificate** invece che date per scontate. Servono tre cose che Flutter da solo non fa: acquisire (scansione, foto, file), mostrare un PDF, impostare e leggere la protezione di un file.

## Decisione

**Dove.** In `Application Support/documenti/<viaggio>/<documento>.pdf|jpg`, non in `Documents/`: entra nel backup allo stesso modo, ma non è mai esposta nell'app File. Il database locale tiene solo l'indice (tabella `documento`, vedi [01](../01-modello-dati.md)) con il **percorso relativo**.

**Come si scrive.** Il file si copia (o si comprime) in un `.parziale`, si rinomina, si protegge, si controlla la protezione, e solo allora entra la riga. Qualunque errore lascia né file né riga; i `.parziale` rimasti si buttano all'avvio.

**Come si protegge.** Ogni file prende `FileProtectionType.complete`: cifrato con il codice di sblocco e illeggibile a telefono bloccato, più forte del predefinito. Il canale lo rilegge e Dart **rifiuta di salvare** se non è `completa` e dentro il backup. Se il telefono non ha un codice, l'elenco lo dice.

**Il canale nativo** `trolley/documenti` (`ios/Runner/DocumentiDelTelefono.swift`) fa quattro cose: protegge e rilegge lo stato di un file; conta e disegna le pagine di un PDF con CoreGraphics, **in memoria** (PNG restituito a Dart, mai scritto); comprime un'immagine in JPEG col lato lungo al più 2800 px, raddrizzata e senza metadati (il luogo dello scatto compreso); dice se c'è un codice di sblocco.

**L'acquisizione** sta dietro un'interfaccia (`lib/dati/acquisizione.dart`):
- scansione: `cunning_document_scanner`, con la fotocamera documenti di iOS; le pagine diventano un PDF. Scrive in `Library/Caches` dell'app, mai nel rullino;
- foto e file: `file_picker` (selettore foto di sistema, senza permesso; selettore dei file). Copie in `tmp/` dell'app.
Le copie temporanee si buttano a ogni foglio chiuso.

**Scartato `pdfx`**: su iOS scrive ogni pagina disegnata in `Documents/pdf_renderer_cache/` prima di passarla a Dart. Per un passaporto è proprio la copia che 03 vieta, e per di più dentro il backup.

## Come si verifica

- `test/documenti_restano_qui_test.dart`: i gesti senza rete sono i quattro; i file dei documenti importano solo da un elenco ammesso (niente rete); nessun file che parla col server importa i documenti; nessuno usa l'archivio di file di Supabase; nessuna migrazione crea un posto dove metterli.
- `test/dati/documenti_test.dart`: scrittura tutto o niente, disco pieno, PDF con password, protezione rifiutata, percorsi che reggono un contenitore spostato, eliminazione del file.
- `ios/RunnerTests/DocumentiDelTelefonoTests.swift`, **sull'iPhone vero** (`xcodebuild test … -destination 'platform=iOS,id=<UDID>' DEVELOPMENT_TEAM=KW7AX44FUN -allowProvisioningUpdates`): protezione `completa` e nel backup, pagine disegnate senza scrivere niente, foto ridotta e senza luogo. Passate il 3 ottobre 2026 su iPhone 18 Pro, iOS 27.0.1. Sul simulatore la protezione non esiste: lì non si verifica.

## Conseguenze

- Android non ha ancora il canale: aggiungere un documento lì dice che non funziona. Prima della prima build Android vanno scritti in Kotlin gli stessi quattro metodi (PdfRenderer, ImageDecoder) e va verificato il backup: l'Auto Backup di Android si ferma a 25 MB per app, quindi i documenti probabilmente **non** ci stanno, e va detto in modo diverso ([punti aperti](../../punti-aperti.md)).
- Due plugin in più da tenere aggiornati; il resto è codice nostro, piccolo e provato.
